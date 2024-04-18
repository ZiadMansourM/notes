# Data Source: aws_caller_identity
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}


# Resource: helm_release
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release

resource "helm_release" "kube_prometheus_stack" {
  name             = "monitoring"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "58.1.3"
  timeout          = 300
  atomic           = true
  create_namespace = true

  values = [
    "${file("files/kube-prometheus-stack-values.yaml")}"
  ]
}

# Resource: kubernetes_namespace_v1
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1
resource "kubernetes_namespace_v1" "ingress-nginx" {
  metadata {
    name = "ingress-nginx"

    labels = {
      monitoring : "prometheus"
    }
  }
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace_v1.ingress-nginx.metadata.0.name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.10.0"
  timeout    = 300
  atomic     = true

  values = [
    "${file("files/ingress-nginx-values.yaml")}"
  ]
}

resource "kubernetes_namespace_v1" "cert-manager" {
  metadata {
    name = "cert-manager"

    labels = {
      monitoring : "prometheus"
    }
  }
}

# Create a public hosted zone in Route53
resource "aws_route53_zone" "k8s" {
  name = "k8s.sreboy.com"
}

output "ns_records" {
  description = "The name servers for the hosted zone"
  value       = aws_route53_zone.k8s.name_servers
}

output "issuer_url_oidc" {
  description = "Issuer URL for the OpenID Connect identity provider."
  value       = data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer

}

# Create OpenID Connect Provider
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url = data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.aws_eks_cluster.cluster.identity.0.oidc.0.thumbprint
  ]
}

# Create IAM policy
resource "aws_iam_policy" "cert_manager_route53_access" {
  name        = "CertManagerRoute53Access"
  description = "Policy for cert-manager to manage Route53 hosted zone"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/${aws_route53_zone.k8s.zone_id}"
    }
  ]
}
EOF

  # [1]: The first Statement is to be able to get the current state 
  # of the request, to find out if dns record changes have been 
  # propagated to all route53 dns servers. 
  # [2]: The second statement one to update dns records such as txt 
  # for acme challange. We need to replace `<id>` with the hosted zone id.
}

# Create IAM role
resource "aws_iam_role" "cert_manager_acme" {
  name               = "cert-manager-acme"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.eks_oidc.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${replace(data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer, "https://", "")}:sub": "system:serviceaccount:cert-manager:cert-manager"
        }
      }
    }
  ]
}
EOF
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "cert_manager_acme" {
  role       = aws_iam_role.cert_manager_acme.name
  policy_arn = aws_iam_policy.cert_manager_route53_access.arn
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace_v1.cert-manager.metadata.name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.14.4"
  timeout    = 300
  atomic     = true

  depends_on = [
    aws_iam_role_policy_attachment.cert_manager_acme
  ]

  values = [
    <<YAML
installCRDs: true
# Helm chart will create the following CRDs:
# - Issuer
# - ClusterIssuer
# - Certificate
# - CertificateRequest
# - Order
# - Challenge


# Enable prometheus metrics, and create a service
# monitor object
prometheus:
  enabled: true
  servicemonitor:
    enabled: true
    prometheusInstance: monitor


# DNS-01 Route53
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.cert_manager_acme.arn}
extraArgs:
# You need to provide the following to be able to use the IAM role.
# If you are using cluster issuer you need to replace it with:
# `--cluster-issuer-ambient-credentials`
- --issuer-ambient-credentials
    YAML
  ]
}
