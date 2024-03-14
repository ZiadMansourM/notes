---
sidebar_position: 1
title: Remote State
description: "Terraform Remote State"
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

Goal is to configure Terraform to store state remotely, with the following features:
- [ ] Locking: Prevent concurrent runs.
- [ ] Versioning: Store state history.
- [ ] Encryption: Encrypt state at rest.

## S3 DynamoDB

```hcl title="variables.tf"
variable "region" {
    description = "AWS default region"
    default     = "eu-central-1"
}

```hcl title="providers.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

```hcl title="s3-dynamodb-state.tf"
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "sreboy-terraform-remote-state-bucket"
  
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  lifecycle_rule {
    id      = "retain-latest-4"
    enabled = true

    noncurrent_version_transitions { 
      newer_noncurrent_versions = 4 
    } 
  }
}

resource "aws_dynamodb_table" "terraform_state_locks" {
  name           = "terraform-locks"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

```hcl title="backend.tf"
terraform {
    backend "s3" {
        bucket         = aws_s3_bucket.terraform_state_bucket.bucket
        key            = "tut_project/prod/terraform.tfstate"
        region         = var.region
        dynamodb_table = aws_dynamodb_table.terraform_state_locks.name
    }

    # no need for it as we have implicit dependency but extra safe guard
    depends_on = [
        aws_s3_bucket.terraform_state_bucket,
        aws_dynamodb_table.terraform_state_locks
    ]
}
```

### Add it to a module

<details>
<summary>click me</summary>

1. Create a new directory `modules/remote-state` and add the following files:
    - `variables.tf`
    - `providers.tf`
    - `s3-dynamodb-state.tf`
    - `backend.tf`
2. Copy the following content to the respective files:

```hcl title="variables.tf"
variable "region" {
    description = "AWS default region"
    default     = "eu-central-1"
}

variable "bucket_name" {
    description = "Name of the S3 bucket to store the state"
    default     = "sreboy-terraform-remote-state-bucket"
}

variable "dynamodb_table_name" {
    description = "Name of the DynamoDB table to store the locks"
    default     = "terraform-locks"
}

variable "bucket_key" {
    description = "Key to store the state in the S3 bucket"
}
```

```hcl title="providers.tf"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

```hcl title="s3-dynamodb-state.tf"
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = var.bucket_name
  
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  lifecycle_rule {
    id      = "retain-latest-4"
    enabled = true

    noncurrent_version_transitions { 
      newer_noncurrent_versions = 4 
    }
  }
}

resource "aws_dynamodb_table" "terraform_state_locks" {
  name           = var.dynamodb_table_name
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

```hcl title="backend.tf"
terraform {
  backend "s3" {
    bucket         = aws_s3_bucket.terraform_state_bucket.bucket
    key            = var.bucket_key
    region         = var.region
    dynamodb_table = aws_dynamodb_table.terraform_state_locks.name
  }

  # no need for it as we have implicit dependency but extra safe guard
  depends_on = [
    aws_s3_bucket.terraform_state_bucket,
    aws_dynamodb_table.terraform_state_locks
  ]
}
```

3. Add the module to the root module `main.tf`:

```hcl title="main.tf"
module "tut_remote_state_prod" {
  source = "./modules/remote-state"
  region = var.region
  bucket_name = var.bucket_name
  dynamodb_table_name = var.dynamodb_table_name
  bucket_key = "tut_project/prod/terraform.tfstate"
}
```

</details>




