###############################################################################
# workspace-level/root  ->  TFE workspaces dpl-ws-<team>-<env>
#   ONE root for every team; values come from workspace-level/<team>/<env>.tfvars
#   (TF_CLI_ARGS_plan=-var-file=../<team>/<env>.tfvars). team and environment are
#   set by tfe/ as workspace variables.
#
# Upstream (read through remote state; order enforced by run triggers):
#   dpl-account-global   metastore ID, group names
#   dpl-account-<env>    this team's credential / network configuration
# Downstream: run trigger to dpl-uc-<team>-<env>; state shared with dpl-uc-*-<env>.
###############################################################################

data "terraform_remote_state" "global" {
  backend = "remote"
  config = {
    hostname     = var.tfe_hostname
    organization = var.tfe_organization
    workspaces   = { name = "${var.tfe_workspace_prefix}-account-global" }
  }
}

data "terraform_remote_state" "account" {
  backend = "remote"
  config = {
    hostname     = var.tfe_hostname
    organization = var.tfe_organization
    workspaces   = { name = "${var.tfe_workspace_prefix}-account-${var.environment}" }
  }
}

locals {
  name    = "${var.name_prefix}-${var.environment}-${var.team}" # dpl-dev-de
  global  = data.terraform_remote_state.global.outputs
  account = data.terraform_remote_state.account.outputs

  net         = try(local.account.teams[var.team], null)
  known_group = try(keys(local.global.groups), [])

  # Workspace access comes from the group YAML files in account-level/global/teams/
  # (workspace_permission): this team's groups for this environment + platform groups.
  # extra_workspace_groups in the team's tfvars adds groups of OTHER teams (e.g. a reviewer group).
  workspace_groups = merge(
    try(local.global.workspace_permissions[var.team][var.environment], {}),
    var.extra_workspace_groups,
  )
  missing_groups = [for g in keys(local.workspace_groups) : g if !contains(local.known_group, g)]
}

# --- Dependency checks: fail at PLAN, before anything is created --------------------

resource "terraform_data" "checks" {
  input = local.name
  lifecycle {
    precondition {
      condition     = contains(try(local.global.teams, []), var.team)
      error_message = "Team '${var.team}' is not in ${var.tfe_workspace_prefix}-account-global outputs. Add it to the team list in tfe/ and apply ${var.tfe_workspace_prefix}-account-global first."
    }
    precondition {
      condition     = local.net != null
      error_message = "Team '${var.team}' has no network in ${var.tfe_workspace_prefix}-account-${var.environment}. Add it to account-level/env/${var.environment}.tfvars and apply that workspace first."
    }
    precondition {
      condition     = try(local.account.environment, "") == var.environment
      error_message = "${var.tfe_workspace_prefix}-account-${var.environment} reports environment '${try(local.account.environment, "none")}'."
    }
    precondition {
      condition     = length(local.missing_groups) == 0
      error_message = "Group(s) not managed by ${var.tfe_workspace_prefix}-account-global: ${join(", ", local.missing_groups)}. Add them to account-level/global first."
    }
  }
}

# --- Workspace -------------------------------------------------------------------

module "workspace" {
  source = "../../modules/databricks-workspace"

  name                  = coalesce(var.workspace_name, local.name)
  databricks_account_id = var.databricks_account_id
  # try(): if an upstream is missing, the precondition above reports it instead of an attribute error
  region                   = try(local.account.region, null)
  credentials_id           = try(local.net.credentials_id, null)
  storage_configuration_id = try(local.account.storage_configuration_id, null)
  network_id               = try(local.net.network_id, null)
  metastore_id             = try(local.global.metastore_id, null)
  tags                     = merge(var.tags, { Team = var.team, Environment = var.environment })

  depends_on = [terraform_data.checks]
}

module "assignment" {
  source = "../../modules/workspace-assignment"

  workspace_id       = module.workspace.workspace_id
  groups             = local.workspace_groups
  service_principals = { (var.deployer_application_id) = "ADMIN" } # the unity-catalog layer manages the workspace as this SP
}

# A new workspace needs a moment before the SP's ADMIN assignment works on its API.
resource "time_sleep" "workspace_ready" {
  create_duration = "60s"
  triggers = {
    workspace_id = module.workspace.workspace_id
  }
  depends_on = [module.assignment]
}

# --- Optional, per team: only when the team's tfvars sets cluster_policies -------------

module "cluster_policies" {
  source = "../../modules/cluster-policies"
  count  = length(var.cluster_policies) > 0 ? 1 : 0
  providers = {
    databricks = databricks.workspace
  }

  name_prefix = "${local.name}-"
  policies    = var.cluster_policies

  depends_on = [time_sleep.workspace_ready]
}
