# Read by dpl-uc-*-<env> through terraform_remote_state.

output "team" {
  value = var.team
}

output "environment" {
  value = var.environment
}

output "aws_account_id" {
  value = try(local.account.aws_account_id, null)
}

output "region" {
  value = try(local.account.region, null)
}

output "workspace_id" {
  value = module.workspace.workspace_id
}

output "workspace_url" {
  value = module.workspace.workspace_url
}

output "workspace_name" {
  value = module.workspace.workspace_name
}

output "metastore_id" {
  value = try(local.global.metastore_id, null)
}

output "workspace_groups" {
  description = "group => workspace permission"
  value       = local.workspace_groups
}

output "cluster_policies" {
  value = length(module.cluster_policies) > 0 ? module.cluster_policies[0].policy_ids : {}
}
