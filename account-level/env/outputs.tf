# Read by dpl-ws-*-<env> through terraform_remote_state.

output "environment" {
  value = var.environment
}

output "aws_account_id" {
  value = var.aws_account_id
}

output "region" {
  value = var.region
}

output "vpc_id" {
  value = module.aws_account.vpc_id
}

output "root_bucket" {
  value = module.aws_account.root_bucket
}

output "storage_configuration_id" {
  value = module.aws_account.storage_configuration_id
}

output "teams" {
  description = "team => credentials_id, network_id, subnet_ids, availability_zones, security_group_id, cross_account_role_arn"
  value       = module.aws_account.teams
}
