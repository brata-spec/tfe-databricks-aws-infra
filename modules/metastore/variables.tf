variable "create" {
  description = "true = create the metastore; false = use the existing one called name"
  type        = bool
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "owner" {
  description = "Owner when created (a group)"
  type        = string
}

variable "storage_root" {
  description = "Optional metastore-level managed storage (s3://...). Leave null to use catalog-level storage."
  type        = string
  default     = null
}
