# workspace-level -> TFE workspace dpl-ws-de-dev   (workspace dpl-dev-de)
# Owner: DE team + platform (CODEOWNERS). team / environment are set by tfe/.
#
# Access: workspace_permission in account-level/global/teams/de/dpl-dev-de-*.yaml
# (+ teams/platform/*.yaml). extra_workspace_groups is only for groups of OTHER teams.

extra_workspace_groups = {}

# Optional feature, DE only: other teams leave cluster_policies unset and get nothing.
cluster_policies = {
  job-compute = {
    description           = "Job clusters for DE pipelines"
    max_clusters_per_user = 5
    can_use               = ["dpl-dev-de-engineers"]
    definition = {
      "cluster_type"                = { type = "fixed", value = "job" }
      "spark_version"               = { type = "unlimited", defaultValue = "auto:latest-lts" }
      "node_type_id"                = { type = "allowlist", values = ["m5d.large", "m5d.xlarge"], defaultValue = "m5d.large" }
      "autoscale.max_workers"       = { type = "range", maxValue = 4, defaultValue = 2 }
      "data_security_mode"          = { type = "fixed", value = "SINGLE_USER" }
      "custom_tags.Team"            = { type = "fixed", value = "de" }
      "aws_attributes.availability" = { type = "fixed", value = "SPOT_WITH_FALLBACK" }
    }
  }
}

tags = {
  CostCenter = "data-engineering"
}
