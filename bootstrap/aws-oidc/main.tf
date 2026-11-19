###############################################################################
# bootstrap/aws-oidc: run ONCE per AWS account, locally, by an AWS admin.
#
#   - HCP Terraform / TFE as an OIDC identity provider (var.tfe_hostname)
#   - <prefix>-<env>-tfe-plan   read-only, trusted for run_phase:plan
#   - <prefix>-<env>-tfe-apply  deploy rights, trusted for run_phase:apply
#
# Trust is limited to one project and to the ONLY workspaces that touch AWS:
#   <prefix>-account-<env>   account level of this environment
#   <prefix>-uc-*-<env>      unity-catalog layer of this environment's teams
#   organization:<org>:project:<project>:workspace:<name>:run_phase:<plan|apply>
# dpl-account-global and dpl-ws-* never get AWS credentials, and a DEV workspace
# can never assume a PROD role (different account AND workspace name).
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "terraform_data" "account_guard" {
  input = data.aws_caller_identity.current.account_id
  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.aws_account_id
      error_message = "Signed in to ${data.aws_caller_identity.current.account_id}, but ${var.environment} is ${var.aws_account_id}. Set AWS_PROFILE to the right account."
    }
  }
}

locals {
  prefix   = "${var.name_prefix}-${var.environment}" # dpl-dev
  provider = "https://${var.tfe_hostname}"
  arn_iam  = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}"
  sub_scope = [
    for ws in ["${var.name_prefix}-account-${var.environment}", "${var.name_prefix}-uc-*-${var.environment}"] :
    "organization:${var.tfe_organization}:project:${var.tfe_project}:workspace:${ws}"
  ]
}

# --- OIDC provider (one per AWS account per TFE hostname) ----------------------

data "tls_certificate" "tfe" {
  count = var.create_oidc_provider ? 1 : 0
  url   = local.provider
}

resource "aws_iam_openid_connect_provider" "tfe" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = local.provider
  client_id_list  = [var.oidc_audience]
  thumbprint_list = [data.tls_certificate.tfe[0].certificates[0].sha1_fingerprint]
  depends_on      = [terraform_data.account_guard]
}

data "aws_iam_openid_connect_provider" "tfe" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.provider
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.tfe[0].arn : data.aws_iam_openid_connect_provider.tfe[0].arn
}

data "aws_iam_policy_document" "trust" {
  for_each = toset(["plan", "apply"])
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.tfe_hostname}:aud"
      values   = [var.oidc_audience]
    }
    condition {
      test     = "StringLike"
      variable = "${var.tfe_hostname}:sub"
      values   = [for scope in local.sub_scope : "${scope}:run_phase:${each.key}"]
    }
  }
}

# --- Plan role: read-only ----------------------------------------------------------

resource "aws_iam_role" "plan" {
  name                 = "${local.prefix}-tfe-plan"
  description          = "TFE plan phase: ${var.name_prefix}-account-${var.environment} + ${var.name_prefix}-uc-*-${var.environment} (read-only)"
  assume_role_policy   = data.aws_iam_policy_document.trust["plan"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}

# --- Apply role: deploy, limited to this environment's names ------------------------

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "Networking"
    actions   = ["ec2:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid = "IamRolesAndPoliciesWithPrefix"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
    ]
    resources = ["${local.arn_iam}:role/${local.prefix}-*"]
  }

  statement {
    sid       = "PassOnlyPrefixedRoles"
    actions   = ["iam:PassRole"]
    resources = ["${local.arn_iam}:role/${local.prefix}-*"]
  }

  statement {
    sid       = "S3BucketsWithPrefix"
    actions   = ["s3:*"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${local.prefix}-*", "arn:${data.aws_partition.current.partition}:s3:::${local.prefix}-*/*"]
  }

  statement {
    sid       = "Identity"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "apply" {
  name                 = "${local.prefix}-tfe-apply"
  description          = "TFE apply phase: ${var.name_prefix}-account-${var.environment} + ${var.name_prefix}-uc-*-${var.environment}"
  assume_role_policy   = data.aws_iam_policy_document.trust["apply"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply_deploy" {
  name   = "databricks-platform-deploy"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.deploy.json
}

# apply also refreshes state, which needs read access to everything it manages
resource "aws_iam_role_policy_attachment" "apply_readonly" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}
