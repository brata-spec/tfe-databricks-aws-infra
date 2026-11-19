###############################################################################
# cross-account-role: the IAM role the Databricks control plane assumes to run
# clusters in this AWS account. One per workspace, because the "restricted"
# policy pins it to one VPC + one security group (Databricks does not allow a
# security-group-restricted role to be reused by other workspaces).
#
# Trust: Databricks' AWS account, ExternalId = your Databricks account ID.
###############################################################################

data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

data "databricks_aws_crossaccount_policy" "this" {
  policy_type       = "restricted"
  aws_account_id    = var.aws_account_id
  region            = var.region
  vpc_id            = var.vpc_id
  security_group_id = var.security_group_id
}

resource "aws_iam_role" "this" {
  name               = var.name
  description        = "Databricks cross-account role (${var.name})"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "this" {
  name   = "databricks-crossaccount"
  role   = aws_iam_role.this.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

# IAM is eventually consistent; Databricks validates the role when the
# credential configuration is created.
resource "time_sleep" "propagation" {
  depends_on      = [aws_iam_role_policy.this]
  create_duration = "30s"
}
