###############################################################################
# metastore: the ONE Unity Catalog metastore for a region (account provider).
# create = true builds it; false looks up an existing one by name. DEV and PROD
# workspaces in the same region are both assigned to it (workspace layer).
#
# No metastore-level storage by default: Databricks recommends managed storage
# at catalog level (each team's catalog gets its own bucket).
###############################################################################

resource "databricks_metastore" "this" {
  count         = var.create ? 1 : 0
  name          = var.name
  region        = var.region
  owner         = var.owner
  storage_root  = var.storage_root
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

data "databricks_metastore" "existing" {
  count = var.create ? 0 : 1
  name  = var.name
}
