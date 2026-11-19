variable "groups" {
  description = "Account group display name => settings"
  type = map(object({
    create        = optional(bool, true)              # false = group exists already (IdP / SCIM); only look it up
    account_admin = optional(bool, false)             # grant the account_admin role
    members = optional(object({                       # used only when manage_members = true
      users              = optional(list(string), []) # user names (emails); users must already exist in the account
      service_principals = optional(list(string), []) # application (client) IDs
      groups             = optional(list(string), []) # other groups from var.groups (nested)
    }), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.groups) : can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{1,99}$", k))])
    error_message = "Group names: letters, digits, '.', '_' and '-' (2-100 characters)."
  }
}

variable "manage_members" {
  description = "true = Terraform manages group membership. Keep false when an IdP (SCIM) syncs members."
  type        = bool
  default     = false
}

variable "deployer_application_id" {
  description = "Application (client) ID of the Terraform deployer service principal; null to skip"
  type        = string
  default     = null
}

variable "deployer_groups" {
  description = "Groups the deployer service principal joins (always managed, independent of manage_members)"
  type        = list(string)
  default     = []
}
