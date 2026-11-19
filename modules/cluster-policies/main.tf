###############################################################################
# cluster-policies: cluster policies in ONE workspace (workspace provider)
# and the groups allowed to use each policy.
#
# Optional per team: the workspace layer only calls this module when the
# team's tfvars sets cluster_policies, so a team that sets nothing gets nothing.
###############################################################################

resource "databricks_cluster_policy" "this" {
  for_each              = var.policies
  name                  = "${var.name_prefix}${each.key}"
  description           = try(each.value.description, null)
  definition            = jsonencode(each.value.definition)
  max_clusters_per_user = try(each.value.max_clusters_per_user, null)
}

resource "databricks_permissions" "this" {
  for_each          = { for k, p in var.policies : k => toset(try(p.can_use, [])) if length(try(p.can_use, [])) > 0 }
  cluster_policy_id = databricks_cluster_policy.this[each.key].id

  dynamic "access_control" {
    for_each = each.value
    content {
      group_name       = access_control.value
      permission_level = "CAN_USE"
    }
  }
}
