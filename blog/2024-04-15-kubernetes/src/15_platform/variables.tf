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
