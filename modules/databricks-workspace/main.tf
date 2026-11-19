###############################################################################
# databricks-workspace: one Databricks workspace (account provider)
#   workspace (from the credential / storage / network configuration IDs that
#   account-level/env created) -> Unity Catalog metastore assignment
#
# Who may use the workspace is handled by modules/workspace-assignment.
###############################################################################

resource "databricks_mws_workspaces" "this" {
  account_id     = var.databricks_account_id
  workspace_name = var.name
  aws_region     = var.region

  credentials_id           = var.credentials_id
  storage_configuration_id = var.storage_configuration_id
  network_id               = var.network_id
  custom_tags              = var.tags

  timeouts {
    create = "30m"
  }
}

resource "databricks_metastore_assignment" "this" {
  metastore_id = var.metastore_id
  workspace_id = databricks_mws_workspaces.this.workspace_id
}
