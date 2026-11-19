output "metastore_id" {
  value = var.create ? databricks_metastore.this[0].id : data.databricks_metastore.existing[0].metastore_id
}
