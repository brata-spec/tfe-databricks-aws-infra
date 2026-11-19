variable "tfe_hostname" {
  description = "app.terraform.io for HCP Terraform; your TFE hostname for Terraform Enterprise"
  type        = string
  default     = "app.terraform.io"
}

variable "tfe_organization" {
  type    = string
  default = "Dataops-specs"
}

variable "project" {
  description = "Project for the VCS workspaces (part of every AWS trust subject)"
  type        = string
  default     = "databricks-platform"
}

variable "admin_project" {
  description = "Project for the local-execution admin / bootstrap workspaces"
  type        = string
  default     = "databricks-platform-admin"
}

variable "prefix" {
  description = "Prefix of workspace names AND of every AWS/Databricks resource"
  type        = string
  default     = "dpl"
}

variable "terraform_version" {
  description = "Terraform version constraint for the workspaces"
  type        = string
  default     = "~> 1.11.0"
}

# --- GitHub (VCS-driven) ----------------------------------------------------------------

variable "github_repository" {
  description = "owner/repo"
  type        = string
  default     = "brata-spec/dataops-databricks-platform"
}

variable "github_app_installation_name" {
  description = "HCP Terraform GitHub App installation (your GitHub user/org). null = use oauth_token_id (TFE with an OAuth VCS provider)."
  type        = string
  default     = "brata-spec"
}

variable "oauth_token_id" {
  description = "VCS OAuth token ID (ot-...) when the GitHub App is not used"
  type        = string
  default     = null
}

variable "global_branch" {
  description = "Branch dpl-account-global tracks (shared by all environments)"
  type        = string
  default     = "main"
}

# --- Environments and teams ------------------------------------------------------------

variable "environments" {
  description = "env => AWS account, tracked branch, apply behaviour"
  type = map(object({
    aws_account_id     = string
    branch             = string
    auto_apply         = bool           # ws / uc workspaces (VCS + run-triggered runs)
    account_auto_apply = optional(bool) # dpl-account-<env>; default false
  }))
  default = {
    dev  = { aws_account_id = "473640421776", branch = "develop", auto_apply = true }
    prod = { aws_account_id = "283923227867", branch = "main", auto_apply = false }
  }
  validation {
    condition     = alltrue([for e in keys(var.environments) : contains(["dev", "prod"], e)])
    error_message = "Environments are dev and prod."
  }
}

variable "teams" {
  description = "Team keys. Adding one creates 4 workspaces (ws/uc x dev/prod) - see docs/workflow.md"
  type        = list(string)
  default     = ["ae", "de"]
}

# --- Databricks (non-secret; the secret is pasted in the UI) ----------------------------

variable "databricks_account_id" {
  type = string
}

variable "deployer_application_id" {
  description = "Application (client) ID of the deployer service principal dpl-tfe-deployer"
  type        = string
}
