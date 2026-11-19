# unity-catalog -> TFE workspace dpl-uc-de-dev   (workspace dpl-dev-de)
# Owner: DE team + platform (CODEOWNERS). team / environment are set by tfe/.
# Creates: S3 bucket dpl-dev-de-uc-<account>, IAM role, storage credential, external
# location, and the catalogs below (managed storage under that location).

owner_group = "dpl-platform-admins" # owns credential, location, catalogs, schemas

catalogs = {
  dpl_dev_de = {
    comment = "DE - dev"
    schemas = {
      bronze = { comment = "Raw ingested data" }
      silver = { comment = "Cleaned and conformed" }
      gold   = { comment = "Business-ready" }
    }
    # Initial grants come from the group YAML files (catalog_grants) in
    # account-level/global/teams/de/dpl-dev-de-*.yaml. Add grants here only for
    # principals without a YAML (e.g. a pipeline service principal):
    # grants = { "<application-id>" = ["USE_CATALOG", "USE_SCHEMA", "MODIFY", "SELECT"] }
    # AE reads DE's gold layer: read-only binding of this catalog to the AE dev workspace
    consumers = {
      ae = { groups = ["dpl-dev-ae-engineers", "dpl-dev-ae-analysts"], schemas = ["gold"] }
    }
  }
}

tags = {
  CostCenter = "data-engineering"
}
