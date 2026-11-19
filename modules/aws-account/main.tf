###############################################################################
# aws-account: everything ONE environment needs in its AWS account, registered
# with the Databricks account. Called by account-level/env (one TFE workspace per
# environment: dpl-account-dev / dpl-account-prod).
#
#   environment-wide:  VPC foundation (existing or new)
#                      root S3 bucket -> Databricks storage configuration (shared)
#   per team:          subnets + security group          (./modules/workspace-network)
#                      cross-account role, restricted    (./modules/cross-account-role)
#                      Databricks credential + network configuration
#
# The workspace layer (workspace-level/root) only consumes the configuration IDs.
###############################################################################

data "aws_caller_identity" "current" {}

locals {
  prefix = "${var.name_prefix}-${var.environment}" # dpl-dev
}

resource "terraform_data" "account_guard" {
  input = data.aws_caller_identity.current.account_id
  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.aws_account_id
      error_message = "Running in AWS account ${data.aws_caller_identity.current.account_id}, but ${var.environment} must be ${var.aws_account_id}. Check TFC_AWS_PLAN_ROLE_ARN / TFC_AWS_APPLY_ROLE_ARN in the dpl-aws-${var.environment} variable set."
    }
  }
}

# --- Network foundation (once per environment) ------------------------------------

module "network" {
  source = "./modules/network-foundation"

  name     = local.prefix
  region   = var.region
  mode     = var.network.mode
  existing = var.network.existing
  create   = var.network.create
}

# --- Root storage (shared by the environment's workspaces) -------------------------

module "root_storage" {
  source = "./modules/root-storage"

  bucket_name = "${local.prefix}-root-${var.aws_account_id}"
  kms_key_arn = var.root_storage.kms_key_arn
  versioning  = var.root_storage.versioning
  depends_on  = [terraform_data.account_guard]
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${local.prefix}-root-storage"
  bucket_name                = module.root_storage.bucket_name
}

# --- Per workspace: network + cross-account role ------------------------------------

module "workspace_network" {
  source   = "./modules/workspace-network"
  for_each = var.teams

  name                        = "${local.prefix}-${each.key}"
  vpc_id                      = module.network.vpc_id
  subnet_ids                  = each.value.subnet_ids
  new_subnets                 = each.value.new_subnets
  route_table_ids             = { for az in keys(each.value.new_subnets) : az => module.network.private_route_table_ids[az] }
  security_group_id           = each.value.security_group_id
  endpoint_security_group_ids = module.network.endpoint_security_group_ids
}

module "cross_account_role" {
  source   = "./modules/cross-account-role"
  for_each = var.teams

  name                  = "${local.prefix}-${each.key}-crossaccount"
  databricks_account_id = var.databricks_account_id
  aws_account_id        = var.aws_account_id
  region                = var.region
  vpc_id                = module.network.vpc_id
  security_group_id     = module.workspace_network[each.key].security_group_id
}

resource "databricks_mws_credentials" "this" {
  for_each         = var.teams
  credentials_name = "${local.prefix}-${each.key}-credentials"
  role_arn         = module.cross_account_role[each.key].role_arn
}

resource "databricks_mws_networks" "this" {
  for_each           = var.teams
  account_id         = var.databricks_account_id
  network_name       = "${local.prefix}-${each.key}-network"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.workspace_network[each.key].subnet_ids
  security_group_ids = [module.workspace_network[each.key].security_group_id]
}

resource "terraform_data" "workspace_checks" {
  input = keys(var.teams)
  lifecycle {
    precondition {
      condition = alltrue([for t, w in var.teams : alltrue([
        for az in keys(w.new_subnets) : contains(keys(module.network.private_route_table_ids), az)
      ])])
      error_message = "Every AZ in teams.*.new_subnets needs a private route table in the network foundation."
    }
  }
}
