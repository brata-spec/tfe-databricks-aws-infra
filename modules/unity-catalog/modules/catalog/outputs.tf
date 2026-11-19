output "catalogs" {
  description = "catalog => managed storage root"
  value       = { for k, c in databricks_catalog.this : k => c.storage_root }
}

output "schemas" {
  value = keys(databricks_schema.this)
}

output "shared_with" {
  description = "catalog/team => consumer workspace id (read-only binding)"
  value       = { for k, b in databricks_workspace_binding.consumer : k => b.workspace_id }
}
