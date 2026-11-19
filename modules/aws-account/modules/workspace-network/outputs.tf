output "vpc_id" {
  value = data.aws_vpc.this.id
}

output "vpc_cidr" {
  value = data.aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "All subnets of this workspace (existing + created)"
  value       = terraform_data.checks.output
}

output "availability_zones" {
  value = local.subnet_azs
}

output "security_group_id" {
  value = local.security_group_id
}
