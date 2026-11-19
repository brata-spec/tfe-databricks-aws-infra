# workspace-level -> TFE workspace dpl-ws-ae-prod   (workspace dpl-prod-ae)
# Owner: AE team; PROD changes also need platform approval (CODEOWNERS).
#
# Access: workspace_permission in account-level/global/teams/ae/dpl-prod-ae-*.yaml
# (+ teams/platform/*.yaml). extra_workspace_groups is only for groups of OTHER teams.
# No cluster_policies: the optional module is not used for AE.

extra_workspace_groups = {}

tags = {
  CostCenter = "analytics-engineering"
}
