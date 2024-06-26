terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_iam_saml_provider" "aws-client-vpn" {
  name                   = "aws-client-vpn"
  saml_metadata_document = file("${path.module}/metadata/aws-client-vpn.xml")
}

resource "aws_iam_saml_provider" "aws-client-vpn-self-service" {
  name                   = "aws-client-vpn-self-service"
  saml_metadata_document = file("${path.module}/metadata/aws-client-vpn-self-service.xml")
}


