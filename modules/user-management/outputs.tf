output "group_ids" {
  description = "group display name => group ID"
  value       = local.group_ids
}

output "deployer_service_principal_id" {
  value = var.deployer_application_id == null ? null : data.databricks_service_principal.deployer[0].id
}
