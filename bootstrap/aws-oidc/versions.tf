terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.72.0, < 7.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }

  # State lives in TFE; execution is LOCAL (your admin AWS sign-in).
  # Select the workspace with environment variables before `terraform init`:
  #   TF_CLOUD_ORGANIZATION=Dataops-specs   TF_WORKSPACE=dpl-bootstrap-aws-dev | dpl-bootstrap-aws-prod
  cloud {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "databricks-platform"
      Environment = var.environment
      Layer       = "bootstrap"
      ManagedBy   = "terraform-local"
      Repo        = "dataops-databricks-platform"
    }
  }
}
