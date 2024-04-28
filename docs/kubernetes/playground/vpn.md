---
sidebar_position: 6
title: AWS Client VPN
description: Secure EKS with AWS Client VPN
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

```tf title="main.tf"
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  private_key_pem       = tls_private_key.this.private_key_pem
  validity_period_hours = 43800 # 5 years
  early_renewal_hours   = 168   # Generate new cert if Terraform is run within 1 week of expiry

  subject {
    common_name = "vpn.digital.canada.ca"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "ipsec_end_system",
    "ipsec_tunnel",
    "any_extended",
    "cert_signing",
  ]
}

resource "aws_acm_certificate" "this" {
  private_key      = tls_private_key.this.private_key_pem
  certificate_body = tls_self_signed_cert.this.cert_pem
}
```


```tf title="main.tf"
resource "aws_iam_saml_provider" "aws-client-vpn" {
  name                   = "aws-client-vpn"
  saml_metadata_document = file("${path.module}/metadata/aws-client-vpn.xml")
}

resource "aws_iam_saml_provider" "aws-client-vpn-self-service" {
  name                   = "aws-client-vpn-self-service"
  saml_metadata_document = file("${path.module}/metadata/aws-client-vpn-self-service.xml")
}
```


```tf title="main.tf"
resource "aws_security_group" "postgresql_cluster" {
  name        = "test_database"
  description = "Test database security group"
  vpc_id      = module.test_vpc.vpc_id
}

resource "aws_security_group_rule" "postgresql_cluster_ingress_vpn" {
  description              = "Ingress from VPN task to database"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.postgresql_cluster.id
  source_security_group_id = aws_security_group.this.id
}
```

```tf title="main.tf"
resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = var.endpoint_name
  vpc_id                 = module.test_vpc.vpc_id
  server_certificate_arn = aws_acm_certificate.this.arn
  client_cidr_block      = var.endpoint_cidr_block

  session_timeout_hours = 8
  split_tunnel          = true
  self_service_portal   = "enabled"
  transport_protocol    = "udp"
  security_group_ids    = [aws_security_group.this.id]
  dns_servers           = [cidrhost(module.test_vpc.cidr_block, 2)]
  
  authentication_options {
    type                           = "federated-authentication"
    saml_provider_arn              = aws_iam_saml_provider.aws-client-vpn.arn
    self_service_saml_provider_arn = aws_iam_saml_provider.aws-client-vpn-self-service.arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.this.name
  }

  client_login_banner_options {
    enabled     = true
    banner_text = "This is a private network. Take care when connecting."
  }
}
```

```tf title="main.tf"
#
# Associate subnets and authorize access
# To save costs, the VPN endpoint is only associated with on availability zone's subnets.
# The resources to access through the VPN must be in these subnets.
#
data "aws_subnet" "private" {
  for_each = toset(module.test_vpc.private_subnet_ids)
  id       = each.key
}

locals {
  availability_zone_subnet_ids = {
    for s in data.aws_subnet.private : s.availability_zone => s.id...
  }
  availability_zone_subnet_cidr_blocks = {
    for s in data.aws_subnet.private : s.availability_zone => s.cidr_block...
  }
}
```

```tf title="main.tf"
resource "aws_ec2_client_vpn_network_association" "this_private_subnets" {
  for_each               = toset(local.availability_zone_subnet_ids[var.availability_zone])
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = each.value
}

resource "aws_ec2_client_vpn_authorization_rule" "this_internal_dns" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = "${cidrhost(module.test_vpc.cidr_block, 2)}/32"
  authorize_all_groups   = true
  description            = "Authorization for ${var.endpoint_name} to DNS"
}

resource "aws_ec2_client_vpn_authorization_rule" "this_private_subnets" {
  for_each               = toset(local.availability_zone_subnet_cidr_blocks[var.availability_zone])
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = each.value
  access_group_id        = var.access_group_id
  description            = "Rule name: ${each.value}"
}

#
# VPN security group
#
resource "aws_security_group" "this" {
  name        = "client-vpn-endpoint-${var.endpoint_name}"
  description = "Egress All. Used for other groups where VPN access is required."
  vpc_id      = module.test_vpc.vpc_id
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

#
# Connection logging
#
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/client-vpn-endpoint/${var.endpoint_name}"
  retention_in_days = 14
}
```

## VPN For EKS
The above was just example code from Github. Now we will create a VPN for our EKS cluster.

```tf title="main.tf"
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}
```

### Step One: Create and configure the Client VPN SAML applications in AWS IAM Identity Center

Create two custom SAML 2.0 applications in AWS IAM Identity Center. One will be the IdP for the Client VPN software, the other will be a self-service portal that allows users to download their Client VPN software and client configuration file.

#### First:
aws-client-vpn
- AWS Client VPN: the IdP for the Client VPN software.
- `Application ACS URL`: http://127.0.0.1:35001
- `Application SAML audience`: urn:amazon:webservices:clientvpn

#### Second:
aws-client-vpn-self-service
- AWS Client VPN Self-Service: the self-service portal that allows users to download their Client VPN software and client configuration file.


```tf title="main.tf"
resource "aws_iam_saml_provider" "aws-client-vpn" {
  name                   = "aws-client-vpn"
} 
```

## Issue

I have used this tool: https://www.samltool.com/sp_metadata.php
```
Good evening Mr. Heard,
Hope you are enjoying your evening ^^

I came across this amazing repo, thank you for your efforts, while trying to use terraform to configure `AWS client VPN using AWS IAM Identity Center as the IdP`.

I have been through the hole process using ClickOps or the Console.

### My Question

I used to add the `Application Metadata` manually, as the docs mentioned **If you don’t have a metadata file, you can manually type your metadata values and enter the following values**:
#### E.g. for `aws-client-vpn`
- `Application ACS URL`: http://127.0.0.1:35001
- `Application SAML audience`: urn:amazon:webservices:clientvpn
#### E.g. for `aws-client-vpn-self-service`
- `Application ACS URL`: https://self-service.clientvpn.amazonaws.com/api/auth/sso/saml
- `Application SAML audience`: urn:amazon:webservices:clientvpn

But the terraform code is:
resource "aws_iam_saml_provider" "aws-client-vpn" {
  name                   = "aws-client-vpn"
  saml_metadata_document = file("${path.module}/metadata/aws-client-vpn.xml")
}

resource "aws_iam_saml_provider" "aws-client-vpn-self-service" {
  name                   = "aws-client-vpn-self-service"
  saml_metadata_document = file("${path.module}/metadata/aws-client-vpn-self-service.xml")
}

You mentioned in the repo `You will need to add the AWS SSO SAML Application metadata files to the terraform/metadata directory.`

How can I generate the `aws-client-vpn.xml` or `aws-client-vpn-self-service.xml` ?  Or are there any sample or docs referring to the structure of the file ? Would I need to create the files manually of I should get them from somewhere ?

Thank you in advance ^^
```

## Implementation
1. Use this [tool](https://www.samltool.com/sp_metadata.php) to generate the metadata for the two SAML provider.
    - For `aws-client-vpn` gen `aws-client-vpn.xml`: 
        - ***EntityId***: `urn:amazon:webservices:clientvpn`.
        - ***Attribute Consume Service Endpoint (HTTP-POST)***: `http://127.0.0.1:35001`.
    - For `aws-client-vpn-self-service` gen `aws-client-vpn-self-service.xml`:
        - ***EntityId***: `urn:amazon:webservices:clientvpn`.
        - ***Attribute Consume Service Endpoint (HTTP-POST)***: `https://self-service.clientvpn.amazonaws.com/api/auth/sso/saml`.
2. Use `aws_iam_saml_provider` terraform resource to create the two SAML providers.
3. Add attributes mappings according to the following table:
User attribute in the application | Maps to this string value or user attribute in AWS IAM Identity Center | Format 
:--: | :--: | :--:
Subject | ${user:email} | emailAddress 
Name | ${user:email} | unspecified 
FirstName | ${user:givenName} | unspecified
LastName | ${user:familyName} | unspecified
memberOf | ${user:groups} | unspecified
4. Assign `admins` group to both SAML providers.
5. Download the idp metadata.
// The rest can be automated
6. Navigate to IAM/Identity Providers and add two new providers:
    - Choose SAMl and name it `aws-client-vpn`. Then upload the idp metadata file.
    - Choose SAMl and name it `aws-client-vpn-self-service`. Then upload the idp metadata file.
7. Import a CA certificate into AWS Certificate Manager (ACM).
```bash
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass

# Navigate to certificate manger, import:
# Certificate body: server.crt
# Certificate private key: server.key
# Certificate chain: ca.crt
```
8. Create a Client VPN endpoint.
    - Under VPC/Client VPN endpoints, create a new endpoint.
    - Name: `demo-vpn-endpoint`.
    - Client IPv4 CIDR: `172.16.0.0/16`.
    - Server certificate: `server.crt`.
    - Select `Use user-based authentication` and `Federated authentication`. Then select `aws-client-vpn` and `aws-client-vpn-self-service`.
    - Select VPC id which will be associated with this endpoint.
    - ***Select the security group***.
    - Enable ***self-service portal*** and ***split-tunnel***.
9. Associate the endpoint with the two private subnets.
10. Add Authorization rules for the endpoint.
    - Add Destination Network: `10.0.128.0/17`. That contains the two private subnets CIDRs. Or include the whole VPC CIDR block `10.0.0.0/16`.
    - Allow access to users in a specific group. Access Group ID: `admins`.
11. Copy the `Self Service Portal URL` from the endpoint details. And navigate back to: `IAM/Identity Center`:
    - Click on applications then `aws-client-vpn-self-service`. Action/Edit Configuration.
    - Under Application Properties, paste the URL in the `Application start URL`.

## REFERENCES
- [Authenticate AWS Client VPN users with AWS IAM Identity Center](https://aws.amazon.com/blogs/security/authenticate-aws-client-vpn-users-with-aws-single-sign-on/).