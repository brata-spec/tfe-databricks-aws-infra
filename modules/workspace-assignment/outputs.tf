output "assignments" {
  description = "principal => permission"
  value       = { for k, a in databricks_mws_permission_assignment.this : k => a.permissions[0] }
}
