###############################################################################
# workspace-assignment: give account-level principals access to ONE workspace
# (identity federation, account provider).
#
#   groups             group display name => "ADMIN" | "USER"
#   service_principals SP application ID  => "ADMIN" | "USER"
#
# Principal IDs are resolved by name here, so callers only pass names. Groups
# are created by account-level/global (modules/user-management); a name that
# does not exist fails at plan with "group not found".
###############################################################################

data "databricks_group" "this" {
  for_each     = var.groups
  display_name = each.key
}

data "databricks_service_principal" "this" {
  for_each       = var.service_principals
  application_id = each.key
}

locals {
  assignments = merge(
    { for name, perm in var.groups : "group:${name}" => { id = data.databricks_group.this[name].id, perm = perm } },
    { for app, perm in var.service_principals : "sp:${app}" => { id = data.databricks_service_principal.this[app].id, perm = perm } },
  )
}

resource "databricks_mws_permission_assignment" "this" {
  for_each     = local.assignments
  workspace_id = var.workspace_id
  principal_id = each.value.id
  permissions  = [each.value.perm]
}
