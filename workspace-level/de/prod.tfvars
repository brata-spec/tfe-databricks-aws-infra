# workspace-level -> TFE workspace dpl-ws-de-prod   (workspace dpl-prod-de)
# Owner: DE team; PROD changes also need platform approval (CODEOWNERS).
#
# Access: workspace_permission in account-level/global/teams/de/dpl-prod-de-*.yaml
# (+ teams/platform/*.yaml). extra_workspace_groups is only for groups of OTHER teams.

extra_workspace_groups = {}

# Optional feature, DE only: other teams leave cluster_policies unset and get nothing.
cluster_policies = {
  job-compute = {
    description           = "Job clusters for DE pipelines"
    max_clusters_per_user = 10
    can_use               = ["dpl-prod-de-engineers"]
    definition = {
      "cluster_type"                = { type = "fixed", value = "job" }
      "spark_version"               = { type = "unlimited", defaultValue = "auto:latest-lts" }
      "node_type_id"                = { type = "allowlist", values = ["m5d.xlarge", "m5d.2xlarge"], defaultValue = "m5d.xlarge" }
      "autoscale.max_workers"       = { type = "range", maxValue = 10, defaultValue = 4 }
      "data_security_mode"          = { type = "fixed", value = "SINGLE_USER" }
      "custom_tags.Team"            = { type = "fixed", value = "de" }
      "aws_attributes.availability" = { type = "fixed", value = "ON_DEMAND" }
    }
  }
}

tags = {
  CostCenter = "data-engineering"
}
