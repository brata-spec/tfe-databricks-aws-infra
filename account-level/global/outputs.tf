# Read by dpl-ws-* and dpl-uc-* through terraform_remote_state.

output "metastore_id" {
  value = module.metastore.metastore_id
}

output "region" {
  value = var.region
}

output "teams" {
  value = var.teams
}

output "environments" {
  value = var.environments
}

output "team_groups" {
  description = "team => env => [group names] (from teams/<team>/*.yaml)"
  value       = local.team_groups
}

output "workspace_permissions" {
  description = "team => env => { group => ADMIN | USER }  - applied by dpl-ws-<team>-<env>"
  value       = local.workspace_permissions
}

output "catalog_grants" {
  description = "team => env => [ { group, catalog, privileges, schemas } ]  - applied by dpl-uc-<team>-<env>"
  value       = local.catalog_grants
}

output "groups" {
  description = "group name => group ID (every group managed or looked up here)"
  value       = module.user_management.group_ids
}

output "deployer_application_id" {
  value = var.deployer_application_id
}
