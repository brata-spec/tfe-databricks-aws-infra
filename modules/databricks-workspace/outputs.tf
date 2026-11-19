output "workspace_id" {
  value = databricks_mws_workspaces.this.workspace_id
}

output "workspace_url" {
  value = databricks_mws_workspaces.this.workspace_url
}

output "workspace_name" {
  value = databricks_mws_workspaces.this.workspace_name
}

output "metastore_assignment_id" {
  description = "Use as a dependency: Unity Catalog objects need the assignment to exist"
  value       = databricks_metastore_assignment.this.id
}
