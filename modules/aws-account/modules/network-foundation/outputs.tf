output "vpc_id" {
  value = local.create ? aws_vpc.this[0].id : data.aws_vpc.existing[0].id
}

output "vpc_cidr" {
  value = local.create ? aws_vpc.this[0].cidr_block : data.aws_vpc.existing[0].cidr_block
}

output "private_route_table_ids" {
  description = "AZ => private route table (NAT egress + S3 gateway endpoint)"
  value       = local.create ? { for az, rt in aws_route_table.private : az => rt.id } : var.existing.private_route_table_ids
}

output "endpoint_security_group_ids" {
  description = "SGs of interface endpoints that only accept listed SGs (existing VPCs). Created endpoints allow the whole VPC CIDR."
  value       = local.create ? [] : var.existing.endpoint_security_group_ids
}
