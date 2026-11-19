output "bucket" {
  value = aws_s3_bucket.uc.bucket
}

output "iam_role_arn" {
  value = aws_iam_role.uc.arn
}

output "storage_credential" {
  value = databricks_storage_credential.this.name
}

output "external_location" {
  value = databricks_external_location.root.name
}

output "storage_url" {
  description = "s3:// root for managed catalog storage (available once the external location exists)"
  value       = databricks_external_location.root.url
}
