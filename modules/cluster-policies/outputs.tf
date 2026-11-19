output "policy_ids" {
  description = "policy key => policy ID"
  value       = { for k, p in databricks_cluster_policy.this : k => p.id }
}
