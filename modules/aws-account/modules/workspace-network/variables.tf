variable "name" {
  description = "Resource name prefix for this workspace, e.g. dbx-dev-de"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC (from CloudOps)"
  type        = string
}

variable "subnet_ids" {
  description = "Existing private subnets for THIS workspace, one per AZ (at least 2 AZs), /17 to /26, not shared with other workspaces"
  type        = list(string)
  default     = []
}

variable "new_subnets" {
  description = "Subnets to create in free VPC space instead: AZ => CIDR, e.g. { \"us-east-1a\" = \"10.20.0.0/21\" }"
  type        = map(string)
  default     = {}
}

variable "route_table_ids" {
  description = "For new_subnets: AZ => existing route table to associate (the client's private route with NAT/TGW egress)"
  type        = map(string)
  default     = {}
}

variable "security_group_id" {
  description = "Existing security group to use. null = create a dedicated one with the Databricks rules."
  type        = string
  default     = null
}

variable "endpoint_security_group_ids" {
  description = "Security groups of EXISTING VPC interface endpoints (STS, Kinesis) to open on 443 for this workspace's SG"
  type        = list(string)
  default     = []
}
