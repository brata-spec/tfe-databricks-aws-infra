variable "prefix" {
  description = "Resource prefix, e.g. dpl-dev-de"
  type        = string
}

variable "team" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "owner" {
  description = "Default owner of the credential, external location, catalogs and schemas (a group)"
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for the UC bucket. null = SSE-S3."
  type        = string
  default     = null
}

variable "catalogs" {
  description = "Catalog definitions; see ./modules/catalog/variables.tf"
  type        = any
  default     = {}
}

variable "consumer_workspace_ids" {
  description = "team => workspace ID of every team named in a catalog's consumers"
  type        = map(number)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
