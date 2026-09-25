terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.14, < 7.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.5, < 4.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = var.name
      ManagedBy = "Terraform"
      Purpose   = "SIT internship demonstration"
    }
  }
}
