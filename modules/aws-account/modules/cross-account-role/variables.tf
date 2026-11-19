variable "name" {
  description = "Role name, e.g. dpl-dev-de-crossaccount"
  type        = string
}

variable "databricks_account_id" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "security_group_id" {
  description = "The workspace's security group (the policy is restricted to it)"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
