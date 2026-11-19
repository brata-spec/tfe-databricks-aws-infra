###############################################################################
# unity-catalog/root  ->  TFE workspaces dpl-uc-<team>-<env>
#   ONE root for every team; values come from unity-catalog/<team>/<env>.tfvars
#   (TF_CLI_ARGS_plan=-var-file=../<team>/<env>.tfvars). team and environment are
#   set by tfe/ as workspace variables.
#
# Upstream (read through remote state; order enforced by run triggers):
#   dpl-ws-<team>-<env>       workspace URL / ID, AWS account
#   dpl-account-global        group names (owner check)
#   dpl-ws-<consumer>-<env>   workspace ID of every team this team shares a catalog with
###############################################################################

data "terraform_remote_state" "workspace" {
  backend = "remote"
  config = {
    hostname     = var.tfe_hostname
    organization = var.tfe_organization
    workspaces   = { name = "${var.tfe_workspace_prefix}-ws-${var.team}-${var.environment}" }
  }
  # Not applied yet -> placeholders, so the precondition below gives a clear message.
  defaults = {
    workspace_url = "https://workspace-not-created-yet.invalid"
  }
}

data "terraform_remote_state" "global" {
  backend = "remote"
  config = {
    hostname     = var.tfe_hostname
    organization = var.tfe_organization
    workspaces   = { name = "${var.tfe_workspace_prefix}-account-global" }
  }
}

locals {
  name   = "${var.name_prefix}-${var.environment}-${var.team}" # dpl-dev-de
  ws     = data.terraform_remote_state.workspace.outputs
  groups = try(keys(data.terraform_remote_state.global.outputs.groups), [])

  # Initial grants from the group YAML files (account-level/global/teams/<team>/*.yaml,
  # catalog_grants), merged with any grants in this team's tfvars.
  yaml_grants         = try(data.terraform_remote_state.global.outputs.catalog_grants[var.team][var.environment], [])
  yaml_grant_catalogs = distinct([for g in local.yaml_grants : g.catalog])
  unknown_catalogs    = [for c in local.yaml_grant_catalogs : c if !contains(keys(var.catalogs), c)]

  catalogs = {
    for cat, c in var.catalogs : cat => merge(c, {
      grants = merge(
        try(c.grants, {}),
        { for g in local.yaml_grants : g.group => distinct(concat(try(c.grants[g.group], []), g.privileges)) if g.catalog == cat && length(g.privileges) > 0 },
      )
      schema_grants = {
        for sch in distinct(concat(keys(try(c.schema_grants, {})), flatten([for g in local.yaml_grants : keys(g.schemas) if g.catalog == cat]))) : sch => merge(
          try(c.schema_grants[sch], {}),
          { for g in local.yaml_grants : g.group => distinct(concat(try(c.schema_grants[sch][g.group], []), g.schemas[sch])) if g.catalog == cat && contains(keys(g.schemas), sch) },
        )
      }
    })
  }

  consumer_teams = toset(distinct(flatten([
    for c in values(var.catalogs) : [for t in keys(try(c.consumers, {})) : t if t != var.team]
  ])))

  # every principal used in grants that is neither a managed group nor a user (e-mail)
  principals = distinct(concat(
    flatten([for c in values(local.catalogs) : keys(c.grants)]),
    flatten([for c in values(local.catalogs) : [for s in values(c.schema_grants) : keys(s)]]),
    flatten([for c in values(var.catalogs) : [for cons in values(try(c.consumers, {})) : cons.groups]]),
  ))
  unknown_principals = [for p in local.principals : p if !contains(local.groups, p) && !strcontains(p, "@")]
}

# A consumer workspace that has not been applied yet returns workspace_id = 0:
# the read-only binding waits (check warning) and is added on a later run.
data "terraform_remote_state" "consumer" {
  for_each = local.consumer_teams
  backend  = "remote"
  config = {
    hostname     = var.tfe_hostname
    organization = var.tfe_organization
    workspaces   = { name = "${var.tfe_workspace_prefix}-ws-${each.key}-${var.environment}" }
  }
  defaults = { workspace_id = 0 }
}

data "aws_caller_identity" "current" {}

# --- Dependency checks: fail at PLAN, before anything is created --------------------

resource "terraform_data" "checks" {
  input = local.name
  lifecycle {
    precondition {
      condition     = try(local.ws.workspace_id, null) != null && try(local.ws.team, "") == var.team && try(local.ws.environment, "") == var.environment
      error_message = "${var.tfe_workspace_prefix}-ws-${var.team}-${var.environment} has no workspace yet (or reports another team/env). Apply the workspace layer first."
    }
    precondition {
      condition     = data.aws_caller_identity.current.account_id == try(local.ws.aws_account_id, "")
      error_message = "AWS credentials point at ${data.aws_caller_identity.current.account_id}, but ${var.environment} is ${try(local.ws.aws_account_id, "unknown")}. Check the dpl-aws-${var.environment} variable set."
    }
    precondition {
      condition     = contains(local.groups, var.owner_group)
      error_message = "owner_group '${var.owner_group}' is not managed by ${var.tfe_workspace_prefix}-account-global."
    }
  }
}

check "yaml_grant_catalogs" {
  assert {
    condition     = length(local.unknown_catalogs) == 0
    error_message = "Group YAML files grant on catalog(s) this team does not define in ${var.environment}.tfvars: ${join(", ", local.unknown_catalogs)} (ignored)."
  }
}

check "grant_principals" {
  assert {
    condition     = length(local.unknown_principals) == 0
    error_message = "Grant principal(s) not managed by ${var.tfe_workspace_prefix}-account-global (fine for service principals; a typo otherwise): ${join(", ", local.unknown_principals)}"
  }
}

# --- Unity Catalog ------------------------------------------------------------------

module "unity_catalog" {
  source = "../../modules/unity-catalog"

  prefix                 = local.name
  team                   = var.team
  environment            = var.environment
  aws_account_id         = try(local.ws.aws_account_id, null)
  owner                  = var.owner_group
  kms_key_arn            = var.kms_key_arn
  catalogs               = local.catalogs
  consumer_workspace_ids = { for t, s in data.terraform_remote_state.consumer : t => s.outputs.workspace_id }
  tags                   = var.tags

  depends_on = [terraform_data.checks]
}
