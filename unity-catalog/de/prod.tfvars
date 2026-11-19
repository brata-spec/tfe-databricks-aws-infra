# unity-catalog -> TFE workspace dpl-uc-de-prod   (workspace dpl-prod-de)
# Owner: DE team; PROD changes also need platform approval (CODEOWNERS).

owner_group = "dpl-platform-admins"

catalogs = {
  dpl_prod_de = {
    comment = "DE - prod"
    schemas = {
      bronze = { comment = "Raw ingested data" }
      silver = { comment = "Cleaned and conformed" }
      gold   = { comment = "Business-ready" }
    }
    # Initial grants come from the group YAML files (catalog_grants) in
    # account-level/global/teams/de/dpl-prod-de-*.yaml. Add grants here only for
    # principals without a YAML (e.g. a pipeline service principal):
    # grants = { "<application-id>" = ["USE_CATALOG", "USE_SCHEMA", "MODIFY", "SELECT"] }
    consumers = {
      ae = { groups = ["dpl-prod-ae-engineers", "dpl-prod-ae-analysts"], schemas = ["gold"] }
    }
  }
}

tags = {
  CostCenter = "data-engineering"
}
