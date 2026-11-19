output "workspaces" {
  description = "name => working dir | var files | branch | auto apply | AWS"
  value = {
    for k, w in local.platform : k => "${w.dir} | ${join(" ", w.varfiles)} | ${w.branch} | auto_apply=${w.auto_apply} | aws=${coalesce(w.aws_env, "none")}"
  }
}

output "run_triggers" {
  description = "upstream>downstream"
  value       = keys(local.run_triggers)
}

output "state_sharing" {
  description = "producer => consumers"
  value       = local.state_consumers
}

output "next_steps" {
  value = [
    "1. Paste DATABRICKS_CLIENT_SECRET in variable set ${var.prefix}-databricks (UI).",
    "2. Run bootstrap/aws-oidc for each AWS account (workspaces ${var.prefix}-bootstrap-aws-<env>).",
    "3. Queue ${local.global_name}, then ${var.prefix}-account-dev; run triggers do the rest.",
  ]
}
