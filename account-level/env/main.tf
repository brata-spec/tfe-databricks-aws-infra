###############################################################################
# account-level/env  ->  TFE workspaces
#     dpl-account-dev   (-var-file=dev.tfvars,  tracks develop)
#     dpl-account-prod  (-var-file=prod.tfvars, tracks main, manual apply)
#
# Everything ONE environment needs in its AWS account (modules/aws-account):
#   VPC foundation, root bucket + storage configuration, and per team:
#   subnets, security group, cross-account role, credential + network configuration.
#
# Downstream: run triggers to dpl-ws-*-<env>; state shared with dpl-ws-*-<env>.
###############################################################################

resource "terraform_data" "team_check" {
  input = sort(keys(var.teams))
  lifecycle {
    precondition {
      condition     = length(setsubtract(var.expected_teams, keys(var.teams))) == 0
      error_message = "${var.environment}.tfvars has no network for team(s): ${join(", ", setsubtract(var.expected_teams, keys(var.teams)))}. Add them under teams = { ... }."
    }
  }
}

module "aws_account" {
  source = "../../modules/aws-account"

  environment           = var.environment
  aws_account_id        = var.aws_account_id
  databricks_account_id = var.databricks_account_id
  name_prefix           = var.name_prefix
  region                = var.region
  network               = var.network
  root_storage          = var.root_storage
  teams                 = var.teams
  tags                  = var.tags

  depends_on = [terraform_data.team_check]
}
