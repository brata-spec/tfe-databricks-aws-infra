variable "prefix" {
  description = "Resource prefix, e.g. dpl-dev-de"
  type        = string
}

variable "aws_account_id" {
  type = string
}

variable "owner" {
  description = "Owner of the storage credential and external location (a group)"
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for the bucket. null = SSE-S3."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
