# workspace-level -> TFE workspace dpl-ws-ae-dev   (workspace dpl-dev-ae)
# Owner: AE team + platform (CODEOWNERS). team / environment are set by tfe/.
#
# Access: workspace_permission in account-level/global/teams/ae/dpl-dev-ae-*.yaml
# (+ teams/platform/*.yaml). extra_workspace_groups is only for groups of OTHER teams.
# No cluster_policies: the optional module is not used for AE.

extra_workspace_groups = {}

tags = {
  CostCenter = "analytics-engineering"
}
