# --- Set by tfe/ (workspace variables) and the variable sets -------------------------

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

# --- unity-catalog/<team>/<env>.tfvars ------------------------------------------------

variable "name_prefix" {
  type    = string
  default = "dpl"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "owner_group" {
  description = "Owns the storage credential, external location, catalogs and schemas. Must be a group the deployer SP belongs to."
  type        = string
  default     = "dpl-platform-admins"
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for the UC bucket; null = SSE-S3"
  type        = string
  default     = null
}

variable "catalogs" {
  description = <<-EOT
    catalog name => {
      comment, owner, properties,
      schemas       = { name => { comment, owner } }
      grants        = { principal => [catalog privileges] }
      schema_grants = { schema => { principal => [privileges] } }
      consumers     = { other_team => { groups = [...], schemas = [...] } }   # read-only share, same env
    }
  EOT
  type        = any
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
