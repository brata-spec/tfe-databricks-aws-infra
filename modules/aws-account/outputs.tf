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
  value = module.network.vpc_id
}

output "root_bucket" {
  value = module.root_storage.bucket_name
}

output "storage_configuration_id" {
  value = databricks_mws_storage_configurations.this.storage_configuration_id
}

output "teams" {
  description = "team => Databricks configuration IDs for the workspace layer (workspace-level/root)"
  value = {
    for t in keys(var.teams) : t => {
      credentials_id         = databricks_mws_credentials.this[t].credentials_id
      network_id             = databricks_mws_networks.this[t].network_id
      subnet_ids             = module.workspace_network[t].subnet_ids
      availability_zones     = module.workspace_network[t].availability_zones
      security_group_id      = module.workspace_network[t].security_group_id
      cross_account_role_arn = module.cross_account_role[t].role_arn
    }
  }
}
