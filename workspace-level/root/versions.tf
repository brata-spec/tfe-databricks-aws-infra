terraform {
  required_version = ">= 1.11.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.83.0, < 2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
  }
  # No backend block: TFE workspaces dpl-ws-<team>-<env> store the state.
}
