###############################################################################
# unity-catalog: everything Unity Catalog needs for ONE team in ONE environment
# (workspace-level Databricks provider + AWS provider of that environment).
#
#   ./modules/storage   S3 bucket, IAM role, storage credential, external location
#   ./modules/catalog   catalogs (ISOLATED, managed storage under the external
#                       location) -> schemas -> grants -> read-only consumer bindings
#
# Called by unity-catalog/root (TFE workspaces dpl-uc-<team>-<env>).
###############################################################################

module "storage" {
  source = "./modules/storage"

  prefix         = var.prefix
  aws_account_id = var.aws_account_id
  owner          = var.owner
  kms_key_arn    = var.kms_key_arn
  tags           = var.tags
}

module "catalog" {
  source = "./modules/catalog"

  team                   = var.team
  environment            = var.environment
  owner                  = var.owner
  storage_url            = module.storage.storage_url
  catalogs               = var.catalogs
  consumer_workspace_ids = var.consumer_workspace_ids
}
