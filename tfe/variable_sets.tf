# --- dpl-databricks: every platform workspace (project level) -----------------------------

resource "tfe_variable_set" "databricks" {
  name        = "${var.prefix}-databricks"
  description = "Databricks deployer service principal + TFE coordinates for remote state"
}

resource "tfe_project_variable_set" "databricks" {
  project_id      = tfe_project.platform.id
  variable_set_id = tfe_variable_set.databricks.id
}

locals {
  databricks_terraform = {
    tfe_organization        = var.tfe_organization
    tfe_hostname            = var.tfe_hostname
    tfe_workspace_prefix    = var.prefix
    databricks_account_id   = var.databricks_account_id
    deployer_application_id = var.deployer_application_id
  }
  databricks_env = {
    DATABRICKS_CLIENT_ID = var.deployer_application_id
    DATABRICKS_AUTH_TYPE = "oauth-m2m"
  }
}

resource "tfe_variable" "databricks_terraform" {
  for_each        = local.databricks_terraform
  variable_set_id = tfe_variable_set.databricks.id
  category        = "terraform"
  key             = each.key
  value           = each.value
}

resource "tfe_variable" "databricks_env" {
  for_each        = local.databricks_env
  variable_set_id = tfe_variable_set.databricks.id
  category        = "env"
  key             = each.key
  value           = each.value
}

# The secret never passes through Terraform or Git: created with a placeholder, you paste
# the real value in the UI (Settings -> Variable sets -> dpl-databricks -> DATABRICKS_CLIENT_SECRET).
resource "tfe_variable" "databricks_client_secret" {
  variable_set_id = tfe_variable_set.databricks.id
  category        = "env"
  key             = "DATABRICKS_CLIENT_SECRET"
  value           = "set-in-ui"
  sensitive       = true
  description     = "OAuth secret of the deployer service principal. Paste in the UI."

  lifecycle {
    ignore_changes = [value]
  }
}

# --- dpl-aws-<env>: AWS dynamic credentials, only for workspaces that touch AWS --------------
# (dpl-account-<env> and dpl-uc-*-<env>; dpl-account-global and dpl-ws-* get no AWS access)

resource "tfe_variable_set" "aws" {
  for_each    = local.envs
  name        = "${var.prefix}-aws-${each.key}"
  description = "AWS ${each.value.aws_account_id}: dynamic credentials (OIDC) for ${each.key}"
}

locals {
  aws_vars = merge([for e, cfg in local.envs : {
    "${e}/TFC_AWS_PROVIDER_AUTH"  = { env = e, key = "TFC_AWS_PROVIDER_AUTH", value = "true" }
    "${e}/TFC_AWS_PLAN_ROLE_ARN"  = { env = e, key = "TFC_AWS_PLAN_ROLE_ARN", value = "arn:aws:iam::${cfg.aws_account_id}:role/${var.prefix}-${e}-tfe-plan" }
    "${e}/TFC_AWS_APPLY_ROLE_ARN" = { env = e, key = "TFC_AWS_APPLY_ROLE_ARN", value = "arn:aws:iam::${cfg.aws_account_id}:role/${var.prefix}-${e}-tfe-apply" }
  }]...)

  aws_attachments = { for k, w in local.platform : k => w.aws_env if w.aws_env != null }
}

resource "tfe_variable" "aws" {
  for_each        = local.aws_vars
  variable_set_id = tfe_variable_set.aws[each.value.env].id
  category        = "env"
  key             = each.value.key
  value           = each.value.value
}

resource "tfe_workspace_variable_set" "aws" {
  for_each        = local.aws_attachments
  workspace_id    = tfe_workspace.platform[each.key].id
  variable_set_id = tfe_variable_set.aws[each.value].id
}
