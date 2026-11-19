# account-level/global -> TFE workspace dpl-account-global
# Owner: platform team (CODEOWNERS). Teams are NOT listed here - tfe/ sets var.teams.

name_prefix = "dpl"
region      = "us-east-1"

# One metastore per region per Databricks account. You already have one in us-east-1:
# look it up instead of creating a second.
metastore = {
  create = false
  name   = "metastore-us-east-1" # exact name shown in Account Console -> Catalog
}

# Groups are NOT listed here: one YAML file per group under teams/<team>/ and teams/platform/
# (members, workspace permission, initial catalog grants). See teams/README.md.

# true = Terraform owns membership (members: in each YAML). Users must already exist in the
# Databricks account (Account Console or SCIM). Set false if an IdP syncs members.
manage_members = true

# The Terraform service principal (dpl-tfe-deployer) is always a platform admin.
deployer_groups = ["dpl-platform-admins"]
