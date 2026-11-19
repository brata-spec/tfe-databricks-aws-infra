variable "name" {
  description = "Workspace name, e.g. dpl-dev-de"
  type        = string
}

variable "databricks_account_id" {
  type = string
}

variable "region" {
  type = string
}

variable "credentials_id" {
  type = string
}

variable "storage_configuration_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "metastore_id" {
  type = string
}

variable "tags" {
  description = "Custom tags on Databricks-launched AWS resources"
  type        = map(string)
  default     = {}
}
