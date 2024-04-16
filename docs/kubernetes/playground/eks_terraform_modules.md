---
sidebar_position: 4
title: EKS Terraform Modules
description: Provision EKS with Terraform Modules
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

We will deploy [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) on a production grade and HA EKS cluster using Terraform modules.

## Layers
1. Foundation Layer:
    - [ ] VPC.
    - [ ] Subnets.
    - [ ] IAM.
    - [ ] DNS.
    - [ ] Cluster.
    - [ ] NAT.
2. Platform:
    - [ ] Ingress.
    - [ ] External Secret Operator.
    - [ ] Cert Manger.
    - [ ] ArgoCD.
    - [ ] Cluster Autoscaling.
3. Observability:
    - [ ] Prometheus.
    - [ ] Logging Loki.
    - [ ] Grafana.
    - [ ] Pixie, Tempo, OpenTelemetry.

...
You can find more in [here](https://github.com/stakpak/reference-kubernetes-platform-series).

## Prerequisites
- Download aws cli.
- Configure Remote State [reference](https://notes.sreboy.com/docs/terraform/playground/remote-state).


## 00. Foundation
Providers used:
- [aws](https://registry.terraform.io/providers/hashicorp/aws/latest).
- [kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest).

```hcl title="00_foundation/providers.tf"
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.45.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.29.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-bucket-goviolin-eks"
    key    = "aws/00_foundation"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "kubernetes" {
    host = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)

    exec {
      # Some cloud providers have short-lived authentication tokens that can expire relatively quickly. To ensure the Kubernetes provider is receiving valid credentials, an exec-based plugin can be used to fetch a new token before each Terraform operation.
      
      api_version = "client.authentication.k8s.io/v1alpha1"
      command = "aws"
      args = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name]
    }
}
```

```hcl title="00_foundation/main.tf"
locals {
  cluster_name = "eks-cluster-production"
  tags = {
    author = "ziadh"
    "karpenter.sh/discovery" = local.cluster_name
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.7.1"

  name = local.cluster_name
  cidr = "10.0.0.0/16"

  azs = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  intra_subnets = ["10.0.51.0/24", "10.0.52.0/24", "10.0.53.0/24"]

  enable_nat_gateway = true

  tags = local.tags
}

module "cluster" {
  source = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name = local.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  vpc_id = module.vpc.vpc_id
  subnets_ids = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    default = {
        iam_role_name = "node-${local.cluster_name}"
        iam_role_use_name_prefix = false
        iam_role_additional_policies = {
            AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        }
    }

    # valid options: AL2_x86_64, BOTTLEROCKET_x86_64
    ami_type = "BOTTLEROCKET_x86_64"
    platform = "bottlerocket"

    min_size = 2
    desired_size = 2
    max_size = 2

    instance_types = ["t3.medium"]
  }

  tags = local.tags
}

variable "domain" {
  description = "AWS Route53 hosted zone domain name"
  type        = string
  default = "sreboy.com"
}

data "aws_route53_zone" "default" {
  name = "goviolin.k8s.sreboy.com."
}

module "cert_manager_irsa_role" {
  # IRSA: IAM Role for Service Account
  # https://cert-manager.io/docs/configuration/acme/dns01/route53/#set-up-an-iam-role
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.39.0"

  role_name = "cert-manager-irsa-role"
  attach_cert_manager_policy = true
  cert_manager_hosted_zone_arns = [data.aws_route53_zone.default.arn]

  oidc_providers = {
    ex = {
      provider_arn = module.cluster.oidc_provider_arn
      # In the `kube-system` namespace, the service account name is `cert-manager`
      namespace_service_accounts = ["kube-system:cert-manager"]  
    }
  }
  
  tags = local.tags
}

module "external_secrets_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.39.0"

  role_name                           = "secret-store"
  attach_external_secrets_policy      = true
  external_secrets_ssm_parameter_arns = ["arn:aws:ssm:*:*:parameter/${local.cluster_name}-*"]

  oidc_providers = {
    ex = {
      provider_arn               = module.cluster.oidc_provider_arn
      # In the `external-secrets` namespace, the service account name is `secret-store`
      namespace_service_accounts = ["external-secrets:secret-store"]
    }
  }

  tags = local.tags
}
```

## 10_platform
```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-cluster-production

kubectl get nodes
```

```hcl title="10_platform/providers.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
  }
  backend "s3" {
    bucket = "terraform-k8s-platform-podcast-xyz"
    key    = "aws/10_platform"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_eks_cluster" "cluster" {
  name = "eks-cluster-production"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "eks-cluster-production"
}

provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  token = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint
    token = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}
```

```hcl title="10_platform/main.tf"
resource "helm_release" "eso" {
  name = "external-secrets"
  namespace = "external-secrets"
  repository = "https://external-secrets.io"
  chart = "external-secrets"
  version = "0.9.15-2"
  timeout = 300
  atomic = true
  create_namespace = true
}

resource "helm_release" "certm" {
  name = "cert-manager"
  namespace = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  version = "1.14.4"
  timeout = 300
  atomic = true
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

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
    prometheusInstance: lesson-083 # Has to match the label on Prometheus Object


# DNS-01 Route53
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/cert-manager-acme
extraArgs:
- --issuer-ambient-credentials
    YAML
  ]
}

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

resource "helm_release" "argocd" {
  name = "argo-cd"
  namespace = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  version = "6.7.12"
  timeout = 300
  atomic = true
  create_namespace = true

  values = [
    <<YAML
nameOverride: argo-cd
redis-ha:
  enabled: false
controller:
  replicas: 1
repoServer:
  replicas: 1
applicationSet:
  replicaCount: 1
    YAML
  ]
}
```

### Test
```bash
kubectl -n external-secrets get deploy

kubectl -n ingress-nginx get deploy
```

## 15_platform

In this layer we target:
- [ ] Configure DNS records, create a record in the hosted zone we have. We want Rout53 to point to our ingress. So, fetch the external domain of the ingress and then create record that points to it.
- [ ] Configure Cert Manager to Create TLS certificates.
- [ ] Configure Secret Manager. External secret operator to be able to fetch certificates from parameter store. Fist create sa.
- [ ] Create Cluster Secret Store.

```bash
kubectl get svc -n ingress-nginx
```


```hcl title="15_platform/providers.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
  }
  backend "s3" {
    bucket = "terraform-k8s-platform-podcast-xyz"
    key    = "aws/15_platform"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_eks_cluster" "cluster" {
  name = "eks-cluster-production"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "eks-cluster-production"
}

provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  token = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint
    token = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}
```

```hcl title="15_platform/main.tf"
data "kubernetes_service_v1" "ingress_service" {
  metadata {
    name = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}

data "aws_route53_zone" "default" {
  name = "goviolin.k8s.sreboy.com."
}

resource "aws_route53_record" "ingress_record" {
  zone_id = data.aws_route53_zone.default.zone_id
  name    = "goviolin.k8s.sreboy.com"
  type    = "CNAME"
  ttl     = "300"
  records = [
    data.kubernetes_service_v1.ingress_service.status.0.load_balancer.0.ingress.0.hostname
  ]
}

resource "kubernetes_manifest" "cert_issuer" {
  manifest = yamldecode(<<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ziadh@sreboy.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
  YAML
  )

  depends_on = [
    aws_route53_record.ingress_record
  ]
}

data "aws_caller_identity" "current" {}

resource "kubernetes_service_account_v1" "secret_store" {
  metadata {
    namespace = "external-secrets"
    name = "secret-store"
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::$(data.aws_caller_identity.current.account_id):role/secret-store"
    }
  }
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = yamldecode(<<YAML
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-store
spec:
  provider:
    aws:
      service: ParameterStore
      region: eu-central-1
      auth:
        serviceAccountRef:
          name: secret-store
          namespace: external-secrets
  YAML
  )

  depends_on = [
    kubernetes_service_account_v1.secret_store
  ]
}
```

```bash
kubectl get ClusterSecretStore
```

## 100_app
- [ ] Create ArgoCD custom resource.

```hcl title="100_app/providers.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
  }
  backend "s3" {
    bucket = "terraform-k8s-platform-podcast-xyz"
    key    = "aws/100_app"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_eks_cluster" "cluster" {
  name = "eks-cluster-production"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "eks-cluster-production"
}

provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  token = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint
    token = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}
```

```hcl title="100_app/main.tf"
resource "kubernetes_namespace_v1" "onlineboutique" {
  metadata {
    name = "onlineboutique"
  }
}

# Reference: https://github.com/GoogleCloudPlatform/microservices-demo/tree/main
resource "kubernetes_manifest" "app_chart" {
  manifest = yamldecode(<<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: onlineboutique
  namespace: argo-cd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  source:
    repoURL: us-docker.pkg.dev//online-boutique-ci/charts
    chart: onlineboutique
    targetRevision: 0.8.1
    helm:
      releaseName: onlineboutique
      values: |
        frontend:
          externalService: false
  destination:
    namespace: onlineboutique
    server: https://kubernetes.default.svc
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
  YAML
  )

  depends_on = [
    kubernetes_namespace_v1.onlineboutique
  ]
}

resource "kubernetes_ingress_v1" "frontend" {
  metadata {
    name = "frontend"
    namespace = "onlineboutique"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = [
        "app.guku.io",
      ]
      secret_name = "app-guku-io-tls"
    }
    rule {
      host = "app.guku.io"
      http {
        paths {
          backend {
            service {
              name = "frontend"
              port = {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_manifest.app_chart,
    kube_namespace_v1.onlineboutique
  ]
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = yamldecode(<<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: onlineboutique-custom-secret
  namespace: onlineboutique
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-store
    kind: ClusterSecretStore
  target:
    name: onlineboutique-custom-secret
  data:
  - secretKey: THE_ANSWER
    remoteRef:
      key: cluster-prod-k8s-platform-tutorial-secret
  YAML
  )

  depends_on = [
    kubernetes_namespace_v1.onlineboutique
  ]
}
```

```bash
kubectl -n onlineboutique get secret

kubectl -n onlineboutique get externalsecret

kubectl -n onlineboutique get secret onlineboutique-custom-secret -o jsonpath='{.data.THE_ANSWER}' | base64 -d


kubectl -n argo-cd get svc

kubectl -n argo-cd port-forward svc/argo-cd-server 8080:80
```


## REFERENCES
- [IP addresses per network interface per instance type](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html#AvailableIpPerENI)
- [Dealing with pod density limitations on EKS worker nodes](https://swarup-karavadi.medium.com/dealing-with-pod-density-limitations-on-eks-worker-nodes-137a12c8b218)





    