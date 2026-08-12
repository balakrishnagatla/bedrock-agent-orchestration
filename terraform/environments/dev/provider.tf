terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.15.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }

  assume_role {
    role_arn = var.deployment_role_arn
  }
}

provider "awscc" {
  region = var.aws_region

  assume_role {
    role_arn = var.deployment_role_arn
  }
}
