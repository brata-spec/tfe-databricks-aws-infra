# AWS: dynamic credentials from the dpl-aws-<env> variable set
# (TFC_AWS_PROVIDER_AUTH + TFC_AWS_PLAN_ROLE_ARN / TFC_AWS_APPLY_ROLE_ARN).
# Each TFE workspace (dpl-account-dev, dpl-account-prod) reaches exactly ONE AWS account.
provider "aws" {
  region = var.region
  default_tags {
    tags = merge(var.tags, {
      Project     = "databricks-platform"
      Environment = var.environment
      Layer       = "account"
      ManagedBy   = "terraform"
    })
  }
}

# Databricks ACCOUNT API. Auth: DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET (dpl-databricks).
provider "databricks" {
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}
