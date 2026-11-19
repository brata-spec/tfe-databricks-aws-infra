terraform {
  required_version = ">= 1.11.0"
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.63.0, < 1.0.0"
    }
  }

  # State in HCP Terraform / TFE, LOCAL execution. Create workspace dpl-tfe-admin by hand
  # (CLI-driven, Settings -> General -> Execution Mode: Local) - see docs/getting-started.md.
  cloud {
    organization = "Dataops-specs"
    workspaces {
      name = "dpl-tfe-admin"
    }
  }
}

# Auth: your user token from `terraform login` (or TFE_TOKEN). Never committed.
provider "tfe" {
  hostname     = var.tfe_hostname
  organization = var.tfe_organization
}
