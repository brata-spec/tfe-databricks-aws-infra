###############################################################################
# account-level/global  ->  TFE workspace dpl-account-global (tracks main, manual apply)
#
# Databricks objects that exist ONCE for the whole platform, shared by DEV and PROD:
#   - the regional Unity Catalog metastore (create or look up)
#   - account groups, ONE YAML FILE PER GROUP:  teams/<team>/<group-name>.yaml
#                                               teams/platform/<group-name>.yaml
#       group + members                -> created here (modules/user-management)
#       workspace_permission           -> published as output, applied by dpl-ws-<team>-<env>
#       catalog_grants                 -> published as output, applied by dpl-uc-<team>-<env>
#   - the deployer service principal's group membership
#
# Downstream: run triggers to every dpl-ws-* workspace; state shared with
# dpl-ws-* and dpl-uc-*.
###############################################################################

locals {
  # --- Read teams/<team>/<group>.yaml ---------------------------------------------------
  group_files = fileset("${path.module}/teams", "*/*.yaml")

  groups_raw = {
    for f in local.group_files : trimsuffix(basename(f), ".yaml") => {
      file = "teams/${f}"
      team = dirname(f)
      doc  = try(yamldecode(file("${path.module}/teams/${f}")), null)
    }
  }

  # Normalised: every group has every field, with defaults
  groups = {
    for name, g in local.groups_raw : name => {
      file                 = g.file
      team                 = g.team
      platform             = g.team == "platform"
      environment          = try(tostring(g.doc.environment), g.team == "platform" ? "all" : null)
      create               = try(tobool(g.doc.create), true)
      account_admin        = try(tobool(g.doc.account_admin), false)
      workspace_permission = try(upper(tostring(g.doc.workspace_permission)), null)
      members = {
        users              = [for u in try(tolist(g.doc.members.users), []) : tostring(u)]
        service_principals = [for s in try(tolist(g.doc.members.service_principals), []) : tostring(s)]
        groups             = [for c in try(tolist(g.doc.members.groups), []) : tostring(c)]
      }
      catalog_grants = {
        for cat, cg in try(g.doc.catalog_grants, {}) : cat => {
          privileges = [for p in try(tolist(cg.privileges), []) : upper(tostring(p))]
          schemas    = { for s, ps in try(cg.schemas, {}) : s => [for p in ps : upper(tostring(p))] }
        }
      }
    }
  }

  # --- What the lower layers apply --------------------------------------------------------
  # team => env => [group names]
  team_groups = {
    for team in var.teams : team => {
      for env in var.environments : env => sort([for n, g in local.groups : n if g.team == team && g.environment == env])
    }
  }

  # team => env => { group => ADMIN | USER }   (team's own groups + platform groups everywhere)
  workspace_permissions = {
    for team in var.teams : team => {
      for env in var.environments : env => merge(
        { for n, g in local.groups : n => g.workspace_permission if g.platform && g.workspace_permission != null && contains(["all", env], g.environment) },
        { for n, g in local.groups : n => g.workspace_permission if g.team == team && g.environment == env && g.workspace_permission != null },
      )
    }
  }

  # team => env => [ { group, catalog, privileges, schemas } ]
  catalog_grants = {
    for team in var.teams : team => {
      for env in var.environments : env => flatten([
        for n, g in local.groups : [
          for cat, cg in g.catalog_grants : { group = n, catalog = cat, privileges = cg.privileges, schemas = cg.schemas }
        ] if g.team == team && g.environment == env
      ])
    }
  }

  # --- Checks ---------------------------------------------------------------------------
  bad_yaml        = [for n, g in local.groups_raw : g.file if g.doc == null]
  unknown_folders = distinct([for n, g in local.groups : g.team if !g.platform && !contains(var.teams, g.team)])
  bad_env         = [for n, g in local.groups : g.file if !(g.platform ? contains(concat(["all"], var.environments), coalesce(g.environment, "x")) : contains(var.environments, coalesce(g.environment, "x")))]
  bad_permission  = [for n, g in local.groups : g.file if g.workspace_permission != null && !contains(["ADMIN", "USER"], coalesce(g.workspace_permission, "x"))]
}

resource "terraform_data" "group_files" {
  input = sort(keys(local.groups))
  lifecycle {
    precondition {
      condition     = length(local.bad_yaml) == 0
      error_message = "Empty or invalid YAML: ${join(", ", local.bad_yaml)}"
    }
    precondition {
      condition     = length(local.unknown_folders) == 0
      error_message = "teams/<folder> must be a team from tfe/ or 'platform'. Unknown: ${join(", ", local.unknown_folders)}"
    }
    precondition {
      condition     = length(local.bad_env) == 0
      error_message = "environment must be one of ${join("/", var.environments)} (or 'all' under teams/platform): ${join(", ", local.bad_env)}"
    }
    precondition {
      condition     = length(local.bad_permission) == 0
      error_message = "workspace_permission must be ADMIN or USER: ${join(", ", local.bad_permission)}"
    }
  }
}

module "metastore" {
  source = "../../modules/metastore"

  create       = var.metastore.create
  name         = var.metastore.name
  region       = var.region
  owner        = var.metastore.owner
  storage_root = var.metastore.storage_root
}

module "user_management" {
  source = "../../modules/user-management"

  groups = {
    for n, g in local.groups : n => { create = g.create, account_admin = g.account_admin, members = g.members }
  }
  manage_members          = var.manage_members
  deployer_application_id = var.deployer_application_id
  deployer_groups         = var.deployer_groups

  depends_on = [terraform_data.group_files]
}
