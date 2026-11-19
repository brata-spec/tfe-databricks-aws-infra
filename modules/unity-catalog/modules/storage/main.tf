###############################################################################
# storage: Unity Catalog storage for one team in one environment
# (AWS provider of the environment's account + workspace-level Databricks provider)
#
#   S3 bucket <prefix>-uc-<account>  +  IAM role <prefix>-uc-access
#   storage credential + external location  (ISOLATED: bound to this workspace)
#
# Why this is not in the account layer: the role's trust policy needs the
# storage credential's external ID, which only exists after the credential is
# created through the metastore. Keeping bucket, role and credential together
# avoids a dependency loop between two states.
###############################################################################

locals {
  role_name = "${var.prefix}-uc-access"
  role_arn  = "arn:aws:iam::${var.aws_account_id}:role/${local.role_name}"
  bucket    = "${var.prefix}-uc-${var.aws_account_id}"
}

# --- Bucket ----------------------------------------------------------------------

resource "aws_s3_bucket" "uc" {
  bucket        = local.bucket
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "uc" {
  bucket                  = aws_s3_bucket.uc.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "uc" {
  bucket = aws_s3_bucket.uc.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uc" {
  bucket = aws_s3_bucket.uc.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# --- Storage credential + IAM role ----------------------------------------------
# Credential first (role ARN is a known string) so its external_id can go into
# the role's trust policy; validation is skipped until the role exists.

resource "databricks_storage_credential" "this" {
  name            = "${var.prefix}-uc-credential"
  comment         = "Unity Catalog access to s3://${local.bucket}"
  owner           = var.owner
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  skip_validation = true

  aws_iam_role {
    role_arn = local.role_arn
  }
}

data "databricks_aws_unity_catalog_assume_role_policy" "this" {
  aws_account_id = var.aws_account_id
  role_name      = local.role_name
  external_id    = databricks_storage_credential.this.aws_iam_role[0].external_id
}

data "databricks_aws_unity_catalog_policy" "this" {
  aws_account_id = var.aws_account_id
  bucket_name    = aws_s3_bucket.uc.bucket
  role_name      = local.role_name
  kms_name       = var.kms_key_arn
}

resource "aws_iam_role" "uc" {
  name               = local.role_name
  description        = "Unity Catalog storage access for ${var.prefix}"
  assume_role_policy = data.databricks_aws_unity_catalog_assume_role_policy.this.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "uc" {
  name   = "unity-catalog-access"
  role   = aws_iam_role.uc.id
  policy = data.databricks_aws_unity_catalog_policy.this.json
}

resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role_policy.uc]
  create_duration = "30s"
}

resource "databricks_external_location" "root" {
  name            = "${var.prefix}-uc-root"
  url             = "s3://${local.bucket}"
  credential_name = databricks_storage_credential.this.name
  owner           = var.owner
  isolation_mode  = "ISOLATION_MODE_ISOLATED"
  comment         = "Root of ${var.prefix} Unity Catalog storage"
  depends_on      = [time_sleep.iam_propagation]
}
