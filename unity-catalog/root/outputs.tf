output "team" {
  value = var.team
}

output "environment" {
  value = var.environment
}

output "workspace_url" {
  value = local.ws.workspace_url
}

output "uc_bucket" {
  value = module.unity_catalog.bucket
}

output "storage_credential" {
  value = module.unity_catalog.storage_credential
}

output "external_location" {
  value = module.unity_catalog.external_location
}

output "catalogs" {
  value = module.unity_catalog.catalogs
}

output "shared_with" {
  value = module.unity_catalog.shared_with
}
