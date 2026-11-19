# TFE wiring (what `tfe/` creates)

Everything here is generated from `tfe/variables.tf`: the environments (account, branch, apply mode) and `teams`. Don't change these settings in the UI. Change `tfe/` and apply it, so the wiring stays reviewable.

## Workspaces

| Workspace | Project | Working dir | `TF_CLI_ARGS_plan` | Branch | Auto-apply (VCS / run trigger) | Destroy plans | Variable sets |
|---|---|---|---|---|---|---|---|
| `dpl-account-global` | databricks-platform | `account-level/global` | `-var-file=global.tfvars` | `main` | no / no | no | dpl-databricks |
| `dpl-account-dev` | databricks-platform | `account-level/env` | `-var-file=dev.tfvars` | `develop` | no / no | no | dpl-databricks, dpl-aws-dev |
| `dpl-account-prod` | databricks-platform | `account-level/env` | `-var-file=prod.tfvars` | `main` | no / no | no | dpl-databricks, dpl-aws-prod |
| `dpl-ws-<t>-dev` | databricks-platform | `workspace-level/root` | `-var-file=../<t>/dev.tfvars` | `develop` | yes / yes | yes | dpl-databricks |
| `dpl-ws-<t>-prod` | databricks-platform | `workspace-level/root` | `-var-file=../<t>/prod.tfvars` | `main` | no / no | no | dpl-databricks |
| `dpl-uc-<t>-dev` | databricks-platform | `unity-catalog/root` | `-var-file=../<t>/dev.tfvars` | `develop` | yes / yes | yes | dpl-databricks, dpl-aws-dev |
| `dpl-uc-<t>-prod` | databricks-platform | `unity-catalog/root` | `-var-file=../<t>/prod.tfvars` | `main` | no / no | no | dpl-databricks, dpl-aws-prod |
| `dpl-bootstrap-aws-<env>` | databricks-platform-admin | local execution | | | | | |
| `dpl-tfe-admin` | Default (made by hand) | local execution | | | | | |

Settings common to all VCS workspaces:
- `file_triggers_enabled = true` with the trigger paths listed in [workflow.md](workflow.md#2-life-of-a-change);
- `queue_all_runs = false`;
- `speculative_enabled = true`;
- `execution_mode = remote`;
- Terraform `~> 1.11.0`.

### Why `TF_CLI_ARGS_plan` and not `_apply`

TFE applies the saved plan, so values only have to reach the plan step. Adding `-var-file` to apply would make it fail. Paths are relative to the working directory, which is why the team files use `../<team>/<env>.tfvars`.

## Workspace variables

| Variable | Category | Set on | Value |
|---|---|---|---|
| `teams` | terraform, HCL | `dpl-account-global` | `["ae","de"]` |
| `environments` | terraform, HCL | `dpl-account-global` | `["dev","prod"]` |
| `environment` | terraform | `dpl-account-<env>`, `dpl-ws-*`, `dpl-uc-*` | `dev` / `prod` |
| `aws_account_id` | terraform | `dpl-account-<env>` | `473640421776` / `283923227867` |
| `expected_teams` | terraform, HCL | `dpl-account-<env>` | `["ae","de"]` |
| `team` | terraform | `dpl-ws-*`, `dpl-uc-*` | `ae` / `de` |
| `TF_CLI_ARGS_plan` | env | every VCS workspace | see above |

These are never put in tfvars, and `validate.sh` fails if they are. A copied tfvars file can't point at the wrong team or account.

## Variable sets

| Set | Attached to | Variables |
|---|---|---|
| `dpl-databricks` | project `databricks-platform` | terraform: `tfe_organization`, `tfe_hostname`, `tfe_workspace_prefix`, `databricks_account_id`, `deployer_application_id` · env: `DATABRICKS_CLIENT_ID`, `DATABRICKS_AUTH_TYPE=oauth-m2m`, `DATABRICKS_CLIENT_SECRET` (sensitive, pasted in UI) |
| `dpl-aws-dev` | `dpl-account-dev`, `dpl-uc-*-dev` | env: `TFC_AWS_PROVIDER_AUTH=true`, `TFC_AWS_PLAN_ROLE_ARN=…:role/dpl-dev-tfe-plan`, `TFC_AWS_APPLY_ROLE_ARN=…:role/dpl-dev-tfe-apply` |
| `dpl-aws-prod` | `dpl-account-prod`, `dpl-uc-*-prod` | same for `283923227867` |

Roots that don't declare a variable from a set, e.g. `account-level/env` and `deployer_application_id`, only log a warning. That's harmless.

## Run triggers (12 with 2 teams)

| Source (upstream) | Target (downstream) |
|---|---|
| `dpl-account-global` | every `dpl-ws-*` (dev and prod) |
| `dpl-account-<env>` | `dpl-ws-*-<env>` |
| `dpl-ws-<t>-<env>` | `dpl-uc-<t>-<env>` |

- `dpl-account-global → dpl-ws-*` is direct, not through `dpl-account-<env>`. A group change doesn't change the account layer, and an apply with no changes doesn't fire triggers.
- A workspace can have at most 20 sources; here each has 1 or 2.

## Remote state sharing

| Producer | Consumers |
|---|---|
| `dpl-account-global` | every `dpl-ws-*`, every `dpl-uc-*` |
| `dpl-account-<env>` | `dpl-ws-*-<env>` |
| `dpl-ws-<t>-<env>` | every `dpl-uc-*-<env>` (own team + catalog shares) |

## Check it

```powershell
cd tfe
terraform output workspaces
terraform output run_triggers
terraform output state_sharing
```

In the UI:
- A triggered run says **"Triggered by run trigger from dpl-account-dev"**.
- **Settings → Run Triggers** lists the sources.
- **Settings → General → Remote state sharing** lists the consumers.

## Limits to know

- **HCP Free:** 500 managed resources and 1 concurrent run. This platform with 2 teams is about 250 resources.
- **Terraform Enterprise:** concurrency comes from your license and agent pools.
- **Fan-out:** an `dpl-account-global` apply queues 2 × teams ws runs, then the uc runs. On 1 concurrent run, that's a serial queue.
