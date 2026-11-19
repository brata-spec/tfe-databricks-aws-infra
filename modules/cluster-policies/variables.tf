variable "name_prefix" {
  description = "Prepended to every policy name, e.g. \"dpl-dev-de-\""
  type        = string
  default     = ""
}

# type = any (not map(object)) so each policy definition can have its own shape.
# Each entry:
#   description           = optional string
#   definition            = Databricks policy definition written as an HCL object
#   max_clusters_per_user = optional number
#   can_use               = optional list of group names (CAN_USE)
variable "policies" {
  description = "policy key => { description, definition, max_clusters_per_user, can_use }"
  type        = any
  default     = {}
  validation {
    condition     = alltrue([for k, p in var.policies : can(p.definition)])
    error_message = "Every cluster policy needs a definition."
  }
}
