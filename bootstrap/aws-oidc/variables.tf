variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "aws_account_id" {
  description = "Account you must be signed in to (guard against the wrong profile)"
  type        = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "dpl"
}

variable "tfe_hostname" {
  type    = string
  default = "app.terraform.io"
}

variable "tfe_organization" {
  description = "Exact (case-sensitive) organization name - it is part of the trust subject"
  type        = string
}

variable "tfe_project" {
  description = "Project holding the platform workspaces (part of the trust subject)"
  type        = string
  default     = "databricks-platform"
}

variable "oidc_audience" {
  description = "Audience HCP Terraform puts in AWS tokens (default for TFC_AWS_* dynamic credentials)"
  type        = string
  default     = "aws.workload.identity"
}

variable "create_oidc_provider" {
  description = "false if the TFE hostname is already an IAM OIDC provider in this account"
  type        = bool
  default     = true
}
