# unity-catalog -> TFE workspace dpl-uc-ae-dev   (workspace dpl-dev-ae)
# Owner: AE team + platform (CODEOWNERS). team / environment are set by tfe/.

owner_group = "dpl-platform-admins"

catalogs = {
  dpl_dev_ae = {
    comment = "AE - dev"
    schemas = {
      bronze = { comment = "Raw ingested data" }
      silver = { comment = "Cleaned and conformed" }
      gold   = { comment = "Business-ready" }
    }
    # Initial grants come from the group YAML files (catalog_grants) in
    # account-level/global/teams/ae/dpl-dev-ae-*.yaml. Add grants here only for
    # principals without a YAML (e.g. a pipeline service principal):
    # grants = { "<application-id>" = ["USE_CATALOG", "USE_SCHEMA", "MODIFY", "SELECT"] }
  }
}

tags = {
  CostCenter = "analytics-engineering"
}
