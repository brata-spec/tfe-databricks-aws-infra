variable "workspace_id" {
  description = "Databricks workspace ID (number)"
  type        = number
}

variable "groups" {
  description = "Account group display name => ADMIN | USER"
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for p in values(var.groups) : contains(["ADMIN", "USER"], p)])
    error_message = "Workspace permission must be ADMIN or USER."
  }
}

variable "service_principals" {
  description = "Service principal application (client) ID => ADMIN | USER"
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for p in values(var.service_principals) : contains(["ADMIN", "USER"], p)])
    error_message = "Workspace permission must be ADMIN or USER."
  }
}
