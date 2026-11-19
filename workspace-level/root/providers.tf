# No AWS provider: everything AWS-side was created by account-level/env.
# Auth for both Databricks providers: DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET (dpl-databricks).

provider "databricks" {
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}

# Workspace API of the workspace created in this run - used only by optional,
# workspace-scoped features (cluster policies). The deployer SP is made ADMIN of
# the workspace by module.assignment before anything uses this provider.
# On the very first plan the URL is unknown; Terraform plans the dependent
# resources as "to create" and connects once the workspace exists.
provider "databricks" {
  alias = "workspace"
  host  = module.workspace.workspace_url
}
