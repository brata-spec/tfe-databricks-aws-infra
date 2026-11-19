# unity-catalog -> TFE workspace dpl-uc-ae-prod   (workspace dpl-prod-ae)
# Owner: AE team; PROD changes also need platform approval (CODEOWNERS).

owner_group = "dpl-platform-admins"

catalogs = {
  dpl_prod_ae = {
    comment = "AE - prod"
    schemas = {
      bronze = { comment = "Raw ingested data" }
      silver = { comment = "Cleaned and conformed" }
      gold   = { comment = "Business-ready" }
    }
    # Initial grants come from the group YAML files (catalog_grants) in
    # account-level/global/teams/ae/dpl-prod-ae-*.yaml. Add grants here only for
    # principals without a YAML (e.g. a pipeline service principal):
    # grants = { "<application-id>" = ["USE_CATALOG", "USE_SCHEMA", "MODIFY", "SELECT"] }
  }
}

tags = {
  CostCenter = "analytics-engineering"
}
