# AWS: dynamic credentials from the dpl-aws-<env> variable set (this env's account only).
provider "aws" {
  region = var.region
  default_tags {
    tags = merge(var.tags, {
      Project     = "databricks-platform"
      Environment = var.environment
      Team        = var.team
      Layer       = "unity-catalog"
      ManagedBy   = "terraform"
    })
  }
}

# Workspace API of this team's workspace. The URL comes from the workspace layer's
# state, so it is already known at plan time (no "unknown host" on first runs).
# Auth: DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET (dpl-databricks); the deployer
# SP is ADMIN of the workspace (workspace-level/root, module.assignment).
provider "databricks" {
  host = data.terraform_remote_state.workspace.outputs.workspace_url
}
