# --- Set by tfe/ (workspace variables) and the dpl-databricks / dpl-platform variable sets

variable "team" {
  description = "Team key, e.g. de (TFE workspace variable)"
  type        = string
}

variable "environment" {
  description = "dev | prod (TFE workspace variable)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "databricks_account_id" {
  type = string
}

variable "deployer_application_id" {
  description = "Deployer service principal application ID; made ADMIN of the workspace"
  type        = string
}

variable "tfe_hostname" {
  type    = string
  default = "app.terraform.io"
}

variable "tfe_organization" {
  type = string
}

variable "tfe_workspace_prefix" {
  type    = string
  default = "dpl"
}

# --- workspace-level/<team>/<env>.tfvars ------------------------------------------------

variable "name_prefix" {
  type    = string
  default = "dpl"
}

variable "workspace_name" {
  description = "Override the workspace name (default <prefix>-<env>-<team>). Changing it after creation REPLACES the workspace."
  type        = string
  default     = null
}

variable "extra_workspace_groups" {
  description = "Groups NOT owned by this team => ADMIN | USER (must have a YAML in account-level/global/teams/). Own groups: set workspace_permission in their YAML."
  type        = map(string)
  default     = {}
}

variable "cluster_policies" {
  description = "Optional feature: cluster policies for this workspace (see modules/cluster-policies). Empty = module not used."
  type        = any
  default     = {}
}

variable "tags" {
  description = "Custom tags on Databricks-launched AWS resources"
  type        = map(string)
  default     = {}
}
