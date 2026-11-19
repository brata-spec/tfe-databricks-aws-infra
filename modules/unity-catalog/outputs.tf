output "bucket" {
  value = module.storage.bucket
}

output "iam_role_arn" {
  value = module.storage.iam_role_arn
}

output "storage_credential" {
  value = module.storage.storage_credential
}

output "external_location" {
  value = module.storage.external_location
}

output "catalogs" {
  description = "catalog => managed storage root"
  value       = module.catalog.catalogs
}

output "schemas" {
  value = module.catalog.schemas
}

output "shared_with" {
  value = module.catalog.shared_with
}
