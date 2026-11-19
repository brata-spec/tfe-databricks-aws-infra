###############################################################################
# tfe/: the TFE / HCP Terraform side of the platform, as code.
# Run locally by the platform team after every change to teams or environments.
#
#   workspace                     working dir            var file               branch
#   dpl-account-global            account-level/global   global.tfvars          main
#   dpl-account-<env>             account-level/env      <env>.tfvars           env branch
#   dpl-ws-<team>-<env>           workspace-level/root   ../<team>/<env>.tfvars env branch
#   dpl-uc-<team>-<env>           unity-catalog/root     ../<team>/<env>.tfvars env branch
#
#   run triggers   global -> ws-*    account-<env> -> ws-*-<env>    ws-<t>-<env> -> uc-<t>-<env>
#   state sharing  global -> ws-*, uc-*    account-<env> -> ws-*-<env>    ws-*-<env> -> uc-*-<env>
###############################################################################

locals {
  p    = var.prefix
  envs = var.environments

  global_name = "${local.p}-account-global"

  global = {
    (local.global_name) = {
      layer      = "global", env = null, team = null, aws_env = null
      dir        = "account-level/global"
      varfiles   = ["global.tfvars"]
      branch     = var.global_branch
      auto_apply = false
      paths      = ["account-level/global/**/*", "modules/metastore/**/*", "modules/user-management/**/*"]
      vars       = { teams = { value = jsonencode(var.teams), hcl = true }, environments = { value = jsonencode(keys(local.envs)), hcl = true } }
    }
  }

  account = {
    for e, cfg in local.envs : "${local.p}-account-${e}" => {
      layer      = "account", env = e, team = null, aws_env = e
      dir        = "account-level/env"
      varfiles   = ["${e}.tfvars"]
      branch     = cfg.branch
      auto_apply = coalesce(cfg.account_auto_apply, false)
      paths      = ["account-level/env/*.tf", "account-level/env/${e}.tfvars", "modules/aws-account/**/*"]
      vars = {
        environment    = { value = e, hcl = false }
        aws_account_id = { value = cfg.aws_account_id, hcl = false }
        expected_teams = { value = jsonencode(var.teams), hcl = true }
      }
    }
  }

  ws = merge([for e, cfg in local.envs : {
    for t in var.teams : "${local.p}-ws-${t}-${e}" => {
      layer      = "workspace", env = e, team = t, aws_env = null # no AWS access needed
      dir        = "workspace-level/root"
      varfiles   = ["../${t}/${e}.tfvars"]
      branch     = cfg.branch
      auto_apply = cfg.auto_apply
      paths = [
        "workspace-level/root/**/*", "workspace-level/${t}/${e}.tfvars",
        "modules/databricks-workspace/**/*", "modules/workspace-assignment/**/*", "modules/cluster-policies/**/*",
      ]
      vars = { team = { value = t, hcl = false }, environment = { value = e, hcl = false } }
    }
  }]...)

  uc = merge([for e, cfg in local.envs : {
    for t in var.teams : "${local.p}-uc-${t}-${e}" => {
      layer      = "unity-catalog", env = e, team = t, aws_env = e
      dir        = "unity-catalog/root"
      varfiles   = ["../${t}/${e}.tfvars"]
      branch     = cfg.branch
      auto_apply = cfg.auto_apply
      paths      = ["unity-catalog/root/**/*", "unity-catalog/${t}/${e}.tfvars", "modules/unity-catalog/**/*"]
      vars       = { team = { value = t, hcl = false }, environment = { value = e, hcl = false } }
    }
  }]...)

  platform = merge(local.global, local.account, local.ws, local.uc)

  # --- Order: downstream <- upstream ------------------------------------------------
  run_triggers = merge(
    { for k, w in local.ws : "${local.global_name}>${k}" => { up = local.global_name, down = k } },
    { for k, w in local.ws : "${local.p}-account-${w.env}>${k}" => { up = "${local.p}-account-${w.env}", down = k } },
    { for k, w in local.uc : "${local.p}-ws-${w.team}-${w.env}>${k}" => { up = "${local.p}-ws-${w.team}-${w.env}", down = k } },
  )

  # --- Who may read whose state: producer => consumers -------------------------------
  state_consumers = merge(
    { (local.global_name) = concat(keys(local.ws), keys(local.uc)) },
    { for k, a in local.account : k => [for w, ws in local.ws : w if ws.env == a.env] },
    { for k, w in local.ws : k => [for u, uc in local.uc : u if uc.env == w.env] }, # own uc + consumers' uc
  )

  workspace_variables = merge([
    for ws, w in local.platform : { for key, v in w.vars : "${ws}/${key}" => merge(v, { ws = ws, key = key }) }
  ]...)
}

# --- Projects ----------------------------------------------------------------------------

resource "tfe_project" "platform" {
  name        = var.project
  description = "Databricks on AWS: account-level, workspace-level and unity-catalog layers"
}

resource "tfe_project" "admin" {
  name        = var.admin_project
  description = "Local-execution workspaces: TFE admin and AWS OIDC bootstrap"
}

data "tfe_github_app_installation" "this" {
  count = var.github_app_installation_name == null ? 0 : 1
  name  = var.github_app_installation_name
}

# --- Platform workspaces (VCS-driven) ------------------------------------------------------

resource "tfe_workspace" "platform" {
  for_each = local.platform

  name              = each.key
  project_id        = tfe_project.platform.id
  description       = each.value.team == null ? "${each.value.layer} layer${each.value.env == null ? " (shared by DEV and PROD)" : " | ${each.value.env}"}" : "${each.value.layer} layer | team ${each.value.team} | ${each.value.env}"
  terraform_version = var.terraform_version
  working_directory = each.value.dir

  # Runs only when files that affect this workspace change
  file_triggers_enabled = true
  trigger_patterns      = each.value.paths
  queue_all_runs        = false
  speculative_enabled   = true # plans on pull requests into the tracked branch

  # DEV: apply automatically (VCS and run triggers). PROD and global: a person confirms.
  auto_apply             = each.value.auto_apply
  auto_apply_run_trigger = each.value.auto_apply

  # Destroy plans only where nothing shared or production lives
  allow_destroy_plan = each.value.env == "dev" && each.value.layer != "account"

  vcs_repo {
    identifier                 = var.github_repository
    branch                     = each.value.branch
    github_app_installation_id = var.github_app_installation_name == null ? null : data.tfe_github_app_installation.this[0].id
    oauth_token_id             = var.oauth_token_id
  }
}

resource "tfe_workspace_settings" "platform" {
  for_each                  = local.platform
  workspace_id              = tfe_workspace.platform[each.key].id
  execution_mode            = "remote"
  global_remote_state       = false
  remote_state_consumer_ids = [for c in lookup(local.state_consumers, each.key, []) : tfe_workspace.platform[c].id]
}

# Values file(s), relative to the working directory. Plan only: the apply uses the saved plan.
resource "tfe_variable" "var_file" {
  for_each     = local.platform
  workspace_id = tfe_workspace.platform[each.key].id
  category     = "env"
  key          = "TF_CLI_ARGS_plan"
  value        = join(" ", [for f in each.value.varfiles : "-var-file=${f}"])
  description  = "Values files for this workspace"
}

# team / environment / account ID / team list: set here, never in the tfvars files
resource "tfe_variable" "workspace" {
  for_each     = local.workspace_variables
  workspace_id = tfe_workspace.platform[each.value.ws].id
  category     = "terraform"
  key          = each.value.key
  value        = each.value.value
  hcl          = each.value.hcl
}

resource "tfe_run_trigger" "this" {
  for_each      = local.run_triggers
  workspace_id  = tfe_workspace.platform[each.value.down].id
  sourceable_id = tfe_workspace.platform[each.value.up].id
}

# --- Local-execution workspaces (state only) --------------------------------------------------

resource "tfe_workspace" "bootstrap" {
  for_each          = local.envs
  name              = "${local.p}-bootstrap-aws-${each.key}"
  project_id        = tfe_project.admin.id
  description       = "AWS OIDC provider + TFE plan/apply roles in ${each.value.aws_account_id} (bootstrap/aws-oidc, run locally)"
  terraform_version = var.terraform_version
}

resource "tfe_workspace_settings" "bootstrap" {
  for_each       = local.envs
  workspace_id   = tfe_workspace.bootstrap[each.key].id
  execution_mode = "local"
}
