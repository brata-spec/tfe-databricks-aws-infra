# Databricks ACCOUNT API only - this layer touches no AWS account.
# Auth: DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET from the dpl-databricks variable set.
provider "databricks" {
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}
