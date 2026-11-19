variable "bucket_name" {
  description = "Globally unique bucket name, e.g. dpl-dev-root-<aws account id>"
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key. null = SSE-S3."
  type        = string
  default     = null
}

variable "versioning" {
  description = "Keep previous object versions (expired after noncurrent_version_days)"
  type        = bool
  default     = true
}

variable "noncurrent_version_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
