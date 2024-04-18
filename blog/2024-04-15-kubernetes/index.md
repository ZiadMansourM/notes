---
slug: eks-cluster
title: EKS Cluster
authors: [ziadh]
tags: [kubernetes, eks, terraform, cert-manager, ingress]
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

In this blog we will go through the deployment of the [GoViolin](https://github.com/ZiadMansourM/GoViolin) App. We will aim to deploy a production grade and HA EKS cluster with the following steps:
- [ ] Dockerize the GoViolin App.
    - [ ] Utilize multi-stage builds.
    - [ ] Build a minimal image.
    - [ ] Support Multi-Architecture.
- [ ] Provision the EKS cluster using Terraform.
    - [ ] Use Terraform resources.
    - [ ] Use Terraform modules.
- [ ] Add Cert-Manager and Ingress Controller.
- [ ] Deploy the GoViolin App.
- [ ] Expose Prometheus and Grafana.
    - [ ] Expose them to the internet.
    - [ ] Expose them internally and use VPN connection.


## Dockerize GoViolin
This app is written in ***Go***. It doesn't have any database dependencies and it's a simple app that serves a webpage with static content.

### How to run app locally

<Tabs>

<TabItem value="Method One">

```bash
go run $(ls -1 *.go | grep -v _test.go)
```

</TabItem>

<TabItem value="Method Two">

```bash
go run main.go home.go scale.go duet.go
```

</TabItem>

<TabItem value="Method Three">

```bash
go build -o main
./main
```

</TabItem>

</Tabs>


### Dockerfile
We aim for our docker image to be as minimal as possible. So we will use `multi-stage` builds to achieve this. Also, supporting amd64 and arm64 architectures is a must for our app. Check REFERENCES section for useful resources. In summary, we aim for a `multi-stage` and `multi-platform` Docker image.

```Dockerfile
FROM --platform=$BUILDPLATFORM golang:1.21.5 AS builder

WORKDIR /app

COPY go.mod go.sum /app/

RUN go mod download

COPY . .

ARG TARGETOS TARGETARCH

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o main

FROM --platform=$TARGETPLATFORM scratch
WORKDIR /app
COPY --from=builder /app/ /app/

EXPOSE 8080

LABEL org.opencontainers.image.tags="ziadmmh/goviolin:v0.0.1,ziadmmh/goviolin:latest"
LABEL org.opencontainers.image.authors="ziadmansour.4.9.2000@gmail.com"

CMD ["/app/main"]
```

:::warning Enable Containerd Image Store
The term multi-platform image refers to a bundle of images for multiple different architectures. Out of the box, the default builder for Docker Desktop doesn't support building multi-platform images.

Enabling the containerd image store lets you build multi-platform images and load them to your local image store.

<hr/>

The containerd image store is ***NOT*** enabled by default. To enable the feature for Docker Desktop:

1. Navigate to Settings in Docker Desktop.
2. In the General tab, check Use containerd for pulling and storing images.
3. Select Apply & Restart.
> To disable the containerd image store, clear the Use containerd for pulling and storing images checkbox.

:::

```bash title="Check Containerd Image Store is Enabled"
docker info -f '{{ .DriverStatus }}'
[[driver-type io.containerd.snapshotter.v1]]
```

### Build Image

<Tabs>

<TabItem value="Containerd Image Store">

```bash
docker build --platform linux/arm64,linux/amd64 --progress plain -t ziadmmh/goviolin:v0.0.2 --push .
```

</TabItem>

<TabItem value="Docker Buildx">

```bash
docker buildx build --platform linux/arm64,linux/amd64 --progress plain -t ziadmmh/goviolin:v0.0.2 --push .
```

</TabItem>

</Tabs>

### GitHub Actions
This is a dummy GitHub Actions workflow that builds and pushes the image to Docker Hub [Repository](https://hub.docker.com/repository/docker/ziadmmh/goviolin/general).

```yaml
name: Test, Build, and Push Multi-Arch Image

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Run Go Tests
        run: go test ./...

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      
      - name: Extract metadata from Dockerfile
        run: echo "TAGS=$(awk '/^LABEL org.opencontainers.image.tags/{gsub(/"/,"",$2); gsub(".*=",""); print }' Dockerfile)" >> $GITHUB_ENV

      - name: Build and Push Multi-Arch Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          tags: ${{ env.TAGS }}
          push: true
```

## EKS Cluster
- [ ] Provision: 
    1. `VPC`.
    2. `Internet Gw`.
    3. `Subnets`.
    4. `Elastic IPs`.
    5. `NAT Gateway`.
    6. `Route Tables`, `Route Tables Association`.
    7. `eks-cluster-role`, `eks-cluster-role-attachment` then `EKS Cluster`.
    8. `eks-node-group-general-role` and its Three different `eks-node-group-general-role-attachment`. Then `aws_eks_node_group`.
- [ ] Install `CertManager`, `Ingress`, `Prometheus`, and `Grafana`. Configure `IAM` roles and `DNS` needed for them.
- [ ] Deploy GoViolin App.

### Pre-requisites
First make sure you downloaded `aws-cli` and created `terraform` user with ***programmatic access*** from the AWS Console.

#### Install AWS CLI
Follow the following link to download the latest aws-cli version compatible with your operating system:
- [Install or update to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

```bash
aws --version
aws-cli/2.15.38 Python/3.11.8 Darwin/23.4.0 exe/x86_64 prompt/off
```

#### Create Terraform User
1. Open AWS Console then navigate to `IAM` Service.
2. Click on `Users` then `Create User`.
3. Name user `terraform`.
4. Click `Next` then `Add user to group` and name it `admin-access-automated-tools`. Attach the `AdministratorAccess` Policy then click `Create user group`. `Next` again, and finally `Create User`.
5. Navigate to `terraform` user and select `Security Credentials` tab.
6. Click `Create access key` and Select under use case `Command Line Interface (CLI)`.
7. Read `Alternatives recommended` if you are okay check I understand and click `Create`.
8. Provide a description e.g. `Terraform Programmatic Access` then `Create access key`.
9. Download `.csv` file and store it in a ***safe*** place.

:::tip Access key best practices
- Never store your access key in plain text, in a code repository, or in code.
- Disable or delete access key when no longer needed.
- Enable least-privilege permissions.
- Rotate access keys regularly.
- For more details about managing access keys, see the [best practices for managing AWS access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#securing_access-keys).
:::

```bash
cat $PATH_TO_CREDENTIALS_FILE/terraform_accessKeys.csv

# Enter region: eu-central-1
# Enter output format: json
aws configure --profile terraform

# To verify
cat ~/.aws/config
cat ~/.aws/credentials
```

### 00_Foundation
This module provisions the `VPC`, `Subnets`, `NAT Gateway`, and `EKS Cluster`. It also configures the `IAM` roles and `DNS`.

We will be using the following Terraform providers:
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

```hcl title="variables.tf"
variable "region" {
  description = "The AWS region to deploy the resources."
  type        = string
  default     = "eu-central-1"
}

variable "profile" {
  description = "The AWS profile to use."
  type        = string
  default     = "terraform"
}

```


```hcl title="providers.tf"
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.45.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

```

```hcl title="main.tf"
locals {
  cluster_name = "eks-cluster-production"
  tags = {
    author                   = "ziadh"
    "karpenter.sh/discovery" = local.cluster_name
  }
}


# Resource: aws_vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
# https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  # Makes instances shared on the host.
  instance_tenancy = "default"

  # Required for EKS:
  # 1. Enable DNS support in the VPC.
  # 2. Enable DNS hostnames in the VPC.
  enable_dns_support   = true
  enable_dns_hostnames = true

  # Additional Arguments:
  assign_generated_ipv6_cidr_block = false

  tags = merge(local.tags, { Name = "eks-vpc" })
}


# Resource: aws_internet_gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, { Name = "eks-igw" })
}


# Resource: aws_subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
# Divide the VPC into 4 subnets:
# https://www.davidc.net/sites/default/subnets/subnets.html

resource "aws_subnet" "public_1" {
  vpc_id = aws_vpc.main.id

  cidr_block        = "10.0.0.0/18"
  availability_zone = "eu-central-1a"

  # Required for EKS: Instances launched into the subnet
  # should be assigned a public IP address.
  map_public_ip_on_launch = true

  tags = merge(
    local.tags,
    {
      Name                                          = "public-eu-central-1a"
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                      = "1"
    }
  )
}

resource "aws_subnet" "public_2" {
  vpc_id = aws_vpc.main.id

  cidr_block        = "10.0.64.0/18"
  availability_zone = "eu-central-1b"

  # Required for EKS: Instances launched into the subnet
  # should be assigned a public IP address.
  map_public_ip_on_launch = true

  tags = merge(
    local.tags,
    {
      Name                                          = "public-eu-central-1b"
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                      = "1"
    }
  )
}

resource "aws_subnet" "private_1" {
  vpc_id = aws_vpc.main.id

  cidr_block        = "10.0.128.0/18"
  availability_zone = "eu-central-1a"

  tags = merge(
    local.tags,
    {
      Name                                          = "private-eu-central-1a"
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"             = "1"
    }
  )
}

resource "aws_subnet" "private_2" {
  vpc_id = aws_vpc.main.id

  cidr_block        = "10.0.192.0/18"
  availability_zone = "eu-central-1b"

  tags = merge(
    local.tags,
    {
      Name                                          = "private-eu-central-1b"
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"             = "1"
    }
  )
}


# Resource: aws_eip
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip

resource "aws_eip" "nat_1" {
  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "nat_2" {
  depends_on = [aws_internet_gateway.main]
}


# Resource: aws_nat_gateway
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway

resource "aws_nat_gateway" "gw_1" {
  subnet_id     = aws_subnet.public_1.id
  allocation_id = aws_eip.nat_1.id

  tags = merge(local.tags, { Name = "eks-nat-gw-1" })
}

resource "aws_nat_gateway" "gw_2" {
  subnet_id     = aws_subnet.public_2.id
  allocation_id = aws_eip.nat_2.id

  tags = merge(local.tags, { Name = "eks-nat-gw-2" })
}


# Resource: aws_route_table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags, { Name = "eks-public-rt" })
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw_1.id
  }

  tags = merge(local.tags, { Name = "eks-private-rt-1" })
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw_2.id
  }

  tags = merge(local.tags, { Name = "eks-private-rt-2" })
}


# Resource: aws_route_table_association
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}


# Resource: aws_iam_role
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster"

  assume_role_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY
}


# Resource: aws_iam_role_policy_attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  # https://github.com/SummitRoute/aws_managed_policies/blob/master/policies/AmazonEKSClusterPolicy
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

  role = aws_iam_role.eks_cluster.name
}


# Resource: aws_eks_cluster
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster
resource "aws_eks_cluster" "eks" {
  name = local.cluster_name

  # Amazon Resource Name (ARN) of the IAM role that provides permission for
  # the kubernetes control plane to make calls to aws API operations on your 
  # behalf.
  role_arn = aws_iam_role.eks_cluster.arn

  # Desired Kubernetes master version
  version = "1.29"

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true

    # Must be in at least two subnets in two different
    # availability zones.
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_cluster_policy
  ]

  tags = local.tags
}


# Resource: aws_iam_role
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "node_group_general" {
  name = "eks-node-group-general"

  assume_role_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY
}


# Resource: aws_iam_role_policy_attachment
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy_general" {
  # https://github.com/SummitRoute/aws_managed_policies/blob/master/policies/AmazonEKSWorkerNodePolicy
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

  role = aws_iam_role.node_group_general.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy_general" {
  # https://github.com/SummitRoute/aws_managed_policies/blob/master/policies/AmazonEKS_CNI_Policy
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

  role = aws_iam_role.node_group_general.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only_general" {
  # https://github.com/SummitRoute/aws_managed_policies/blob/master/policies/AmazonEC2ContainerRegistryReadOnly
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

  role = aws_iam_role.node_group_general.name
}


# Resource: aws_eks_node_group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
resource "aws_eks_node_group" "nodes_general" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "nodes-general-group"
  node_role_arn   = aws_iam_role.node_group_general.arn

  # Identifiers of EC2 subnets to associate with the EKS Node Group.
  # These subnets must have the following resource tags:
  # - kubernetes.io/cluster/CLUSTER_NAME
  # Where CLUSTER_NAME is replaced with the name of the EKS cluster.
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  # Valid Values: AL2_x86_64, BOTTLEROCKET_x86_64
  # Ref: https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html#API_Nodegroup_Contents
  ami_type = "BOTTLEROCKET_x86_64"

  # Valid Values: ON_DEMAND, SPOT
  capacity_type = "ON_DEMAND"

  disk_size = 20 # GiB

  # Force version update if existing Pods are unable to be drained
  # due to a pod disruption budget issue.
  force_update_version = false

  # Docs: https://aws.amazon.com/ec2/instance-types/
  instance_types = ["t3.medium"]

  labels = {
    role = "nodes-general"
  }

  # If not specified, then inherited from the EKS master plane.
  version = "1.29"

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy_general,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy_general,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only_general
  ]

  tags = local.tags
}

```

### Test
```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply

rm ~/.kube/config

aws eks --region eu-central-1 update-kubeconfig --name eks-cluster-production --profile terraform

kubectl get nodes,svc
```

### 10_Platform
In this section we will provision:
- Kube-Prometheus-Stack.
- Ingress-Nginx.
- Cert-Manager.

```hcl title="variables.tf"
variable "region" {
  description = "The AWS region to deploy the resources."
  type        = string
  default     = "eu-central-1"
}

variable "profile" {
  description = "The AWS profile to use."
  type        = string
  default     = "terraform"
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "eks-cluster-production"
}

```

```hcl title="providers.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.45.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.29.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.13.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  token = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}

```


```bash
# ----> [1]: Kube Prometheus Stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo kube-prometheus-stack --max-col-width 23
# Release name: monitoring
# Helm chart name: kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack \
--values prometheus-values.yaml \
--version 58.1.3 \
--namespace monitoring \
--create-namespace


# ----> [2]: Ingress-Nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo ingress-nginx --max-col-width 23
helm install ingress-nginx ingress-nginx/ingress-nginx \
--values ingress-values.yaml \
--version 4.10.0 \
--namespace ingress-nginx \
--create-namespace


# ----> [3]: Cert-Manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo cert-manager --max-col-width 23
helm install cert-manager jetstack/cert-manager \
--values cert-manager-values.yaml \
--version 1.14.4 \
--namespace cert-manager \
--create-namespace
```


#### Temp Steps:
1. Delegate a subdomain to Route53. `*.monitoring.devopsbyexample.io`.
  1. Create a public hosted zone in Route53.
    - Domain Name: `monitoring.devopsbyexample.io`.
    - Type: `Public Hosted Zone`.
    - Click `Create`.
  2. Create an NS record in Namecheap.
  3. Test a subdomain `test.monitoring.devopsbyexample.io` in Route53 and try to resolve it with `dig +short test.monitoring.devopsbyexample.io`. Value could be: `10.10.10.10`.
2. We will use IRSA: ***IAM Roles for Service Accounts*** to allow the `cert-manager` to manage the `Route53` hosted zone. 
  1. Create OpenID Connect Provider first:
    - Open eks service in AWS Console. Then under clusters select the cluster.
    - Under `Configuration` tab, Copy the `OpenID Connect Provider URL`.
    - Navigate to IAM Service then `Identity Providers`. Select `Add provider`.
    - Select `OpenID Connect`, paste url and `Get thumbprint`.
    - Under Audience: `sts.amazonaws.com`.
    - Click `Add provider`.
  2. Create an IAM policy. Name the policy `CertManagerRoute53Access`.
  ```json
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
            "Resource": "arn:aws:route53:::hostedzone/<id>"
        }
    ]
  }
  ```
  3. Craete an IAM role and associate it with the kubernetes service account. Under `Roles` click `Create role`.
    - Select type of trusted entity to be `Web identity`.
    - Choose the identity provider created in step 1.
    - For Audience: `sts.amazonaws.com`.
    - Click next for permissions and attach `CertManagerRoute53Access` policy.
    - Name the role `cert-manager-acme`.
  4. To allow only our cert-manager kubernetes account to assume this role, we need to update `Trust Relationship` of the `cert-manager-acme` role. Click edit Trust Relationships:
    - First we need the name of the service account attached to the cert-manager.
    - Run `kubectl -n cert-manager get sa cert-manager` called `cert-083-cert-manager`.
    - Update the trust relationship to be:
    <Tabs>

    <TabItem value="Before">

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Federated": <OIDC_PROVIDER_ARN>
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "oidc.eks.eu-central-1.amazonaws.com/id/<CLUSTER_ID>:aud": "sts.amazonaws.com"
            }
          }
        }
      ]
    }
    ```

    </TabItem>

    <TabItem value="After">

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Federated": <OIDC_PROVIDER_ARN>
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "oidc.eks.eu-central-1.amazonaws.com/id/<CLUSTER_ID>:sub": "system:serviceaccount:cert-manager:cert-083-cert-manager"
            }
          }
        }
      ]
    }
    ```

    </TabItem>

    </Tabs>
    


## REFERENCES
- [Faster Multi-Platform Builds: Dockerfile Cross-Compilation Guide](https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/)
- [containerd image store](https://docs.docker.com/desktop/containerd/)
- [Install or update to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Amazon EKS VPC and subnet requirements and considerations](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html)