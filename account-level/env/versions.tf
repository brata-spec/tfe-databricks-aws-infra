terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.72.0, < 7.0.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.83.0, < 2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
  }
  # No backend block: TFE workspaces dpl-account-dev / dpl-account-prod store the state.
}
