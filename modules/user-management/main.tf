###############################################################################
# user-management: Databricks ACCOUNT-level identities (account provider).
# Called ONLY by account-level/global, so every group has exactly one owner.
#
#   groups            create (default) or look up an existing group by name
#                     (create = false, e.g. a group synced from Entra ID / Okta)
#   account admins    account_admin role for groups that set account_admin = true
#   deployer          the Terraform service principal joins deployer_groups
#   members           users / service principals / groups per group, ONLY when
#                     manage_members = true (leave false when an IdP / SCIM owns
#                     membership, or Terraform and the IdP will fight)
#
# Renaming a group = destroy + create: its workspace assignments and Unity
# Catalog grants disappear until the downstream layers re-apply. Treat names as
# permanent.
###############################################################################

locals {
  create = { for name, g in var.groups : name => g if g.create }
  lookup = { for name, g in var.groups : name => g if !g.create }
}

resource "databricks_group" "this" {
  for_each     = local.create
  display_name = each.key
  # Account groups carry no workspace entitlements; access comes from
  # workspace assignments (modules/workspace-assignment).
}

data "databricks_group" "existing" {
  for_each     = local.lookup
  display_name = each.key
}

locals {
  group_ids = merge(
    { for name, g in databricks_group.this : name => g.id },
    { for name, g in data.databricks_group.existing : name => g.id },
  )
}

# --- Account admin role ---------------------------------------------------------------

resource "databricks_group_role" "account_admin" {
  for_each = { for name, g in var.groups : name => g if g.account_admin }
  group_id = local.group_ids[each.key]
  role     = "account_admin"
}

# --- Deployer service principal -------------------------------------------------------

data "databricks_service_principal" "deployer" {
  count          = var.deployer_application_id == null ? 0 : 1
  application_id = var.deployer_application_id
}

resource "databricks_group_member" "deployer" {
  for_each  = var.deployer_application_id == null ? toset([]) : toset(var.deployer_groups)
  group_id  = local.group_ids[each.value]
  member_id = data.databricks_service_principal.deployer[0].id
}

# --- Optional membership (only when Terraform owns membership) -----------------------

locals {
  member_users = var.manage_members ? merge([
    for name, g in var.groups : { for u in g.members.users : "${name}/user:${u}" => { group = name, user = u } }
  ]...) : {}
  member_sps = var.manage_members ? merge([
    for name, g in var.groups : { for s in g.members.service_principals : "${name}/sp:${s}" => { group = name, sp = s } }
  ]...) : {}
  member_groups = var.manage_members ? merge([
    for name, g in var.groups : { for c in g.members.groups : "${name}/group:${c}" => { group = name, child = c } }
  ]...) : {}
}

data "databricks_user" "member" {
  for_each  = toset([for m in values(local.member_users) : m.user])
  user_name = each.value
}

data "databricks_service_principal" "member" {
  for_each       = toset([for m in values(local.member_sps) : m.sp])
  application_id = each.value
}

resource "databricks_group_member" "user" {
  for_each  = local.member_users
  group_id  = local.group_ids[each.value.group]
  member_id = data.databricks_user.member[each.value.user].id
}

resource "databricks_group_member" "service_principal" {
  for_each  = local.member_sps
  group_id  = local.group_ids[each.value.group]
  member_id = data.databricks_service_principal.member[each.value.sp].id
}

resource "databricks_group_member" "group" {
  for_each  = local.member_groups
  group_id  = local.group_ids[each.value.group]
  member_id = local.group_ids[each.value.child]
}

resource "terraform_data" "checks" {
  input = keys(var.groups)
  lifecycle {
    precondition {
      condition     = alltrue([for g in var.deployer_groups : contains(keys(var.groups), g)])
      error_message = "deployer_groups must be groups defined in var.groups."
    }
    precondition {
      condition     = alltrue([for m in values(local.member_groups) : contains(keys(var.groups), m.child)])
      error_message = "members.groups may only reference groups defined in var.groups."
    }
  }
}
