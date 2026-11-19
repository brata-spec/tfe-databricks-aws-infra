# --- Set by the TFE admin config / variable sets ---------------------------------

variable "databricks_account_id" {
  description = "Databricks account ID (dpl-databricks variable set)"
  type        = string
}

variable "deployer_application_id" {
  description = "Application (client) ID of the deployer service principal (dpl-databricks variable set)"
  type        = string
}

variable "teams" {
  description = "Team keys, e.g. [\"ae\", \"de\"]. Set by tfe/ on this workspace - do not put it in global.tfvars."
  type        = list(string)
  validation {
    condition     = alltrue([for t in var.teams : can(regex("^[a-z][a-z0-9]{1,9}$", t))])
    error_message = "Team keys: lowercase letters/digits, 2-10 characters."
  }
}

variable "environments" {
  description = "Environments that get team groups. Set by tfe/."
  type        = list(string)
  default     = ["dev", "prod"]
}

# --- global.tfvars ----------------------------------------------------------------

variable "name_prefix" {
  type    = string
  default = "dpl"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "metastore" {
  description = "create = false looks up an existing metastore by name (one per region per Databricks account)"
  type = object({
    create       = bool
    name         = string
    owner        = optional(string)
    storage_root = optional(string)
  })
}

variable "manage_members" {
  description = "true = Terraform manages membership from the members: block of each group YAML. Set false when an IdP syncs members (SCIM)."
  type        = bool
  default     = false
}

variable "deployer_groups" {
  description = "Groups the deployer service principal joins"
  type        = list(string)
  default     = []
}
