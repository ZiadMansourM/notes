# Data Source: aws_caller_identity
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}


# Resource: helm_release
# https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release

resource "helm_release" "ingress" {
  name = "ingress-nginx"
  namespace = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  version = "4.10.0"
  timeout = 300
  atomic = true
  create_namespace = true

  values = [
    <<YAML
controller:
  podSecurityContext:
    runAsNonRoot: true
  service:
    enableHttp: true
    enableHttps: true
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
    YAML
  ]
}

# Install Prometheus
# Install Grafana
# Configure serviceAccount and Role or Policy for Cert-Manager

resource "helm_release" "cert-manager" {
  name = "cert-manager"
  namespace = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.14.4"
  timeout = 300
  atomic = true
  create_namespace = true

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
    prometheusInstance:  # Has to match the label on Prometheus Object


# DNS-01 Route53
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$(data.aws_caller_identity.current.account_id):role/cert-manager-acme
extraArgs:
- --issuer-ambient-credentials
    YAML
  ]
}