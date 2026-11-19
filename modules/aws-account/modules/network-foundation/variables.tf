variable "name" {
  description = "Name prefix, e.g. dpl-dev"
  type        = string
}

variable "region" {
  type = string
}

variable "mode" {
  description = "existing = use a VPC owned by CloudOps; create = build one"
  type        = string
  validation {
    condition     = contains(["existing", "create"], var.mode)
    error_message = "mode must be \"existing\" or \"create\"."
  }
}

variable "existing" {
  description = "For mode = existing"
  type = object({
    vpc_id                      = optional(string)
    private_route_table_ids     = optional(map(string), {})  # AZ => route table with NAT/TGW egress
    endpoint_security_group_ids = optional(list(string), []) # SGs of existing STS/Kinesis interface endpoints
  })
  default = {}
}

variable "create" {
  description = "For mode = create"
  type = object({
    vpc_cidr              = optional(string)
    azs                   = optional(list(string), [])
    public_subnet_cidr    = optional(string)
    interface_endpoints   = optional(bool, false)     # STS + Kinesis endpoints (cost ~ per AZ per hour)
    endpoint_subnet_cidrs = optional(map(string), {}) # AZ => small CIDR (/28) when interface_endpoints = true
  })
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
