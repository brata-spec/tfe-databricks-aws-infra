variable "environment" {
  description = "dev | prod"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "aws_account_id" {
  description = "The AWS account this environment MUST run in. Guarded against the provider's actual credentials."
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
}

variable "name_prefix" {
  type    = string
  default = "dpl"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "network" {
  description = "VPC foundation; see ./modules/network-foundation"
  type = object({
    mode = string
    existing = optional(object({
      vpc_id                      = optional(string)
      private_route_table_ids     = optional(map(string), {})
      endpoint_security_group_ids = optional(list(string), [])
    }), {})
    create = optional(object({
      vpc_cidr              = optional(string)
      azs                   = optional(list(string), [])
      public_subnet_cidr    = optional(string)
      interface_endpoints   = optional(bool, false)
      endpoint_subnet_cidrs = optional(map(string), {})
    }), {})
  })
}

variable "root_storage" {
  type = object({
    kms_key_arn = optional(string)
    versioning  = optional(bool, true)
  })
  default = {}
}

variable "teams" {
  description = "team => network of that team's workspace in this environment (2 AZs, never shared)"
  type = map(object({
    new_subnets       = optional(map(string), {})  # AZ => CIDR, created here
    subnet_ids        = optional(list(string), []) # or existing subnets
    security_group_id = optional(string)           # null = create a dedicated SG
  }))
  validation {
    condition     = alltrue([for k in keys(var.teams) : can(regex("^[a-z][a-z0-9]{1,9}$", k))])
    error_message = "Team keys: lowercase letters/digits, 2-10 characters."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
