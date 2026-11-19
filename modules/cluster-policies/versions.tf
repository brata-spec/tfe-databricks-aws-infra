terraform {
  required_version = ">= 1.11.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.83.0, < 2.0.0"
    }
  }
}
