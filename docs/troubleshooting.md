# Troubleshooting

## Plan errors from the dependency guards (expected, and safe)

These stop a run at **plan**, before anything is created.

| Message | Cause | Fix |
|---|---|---|
| `Team 'x' is not in dpl-account-global outputs` | team added to `tfe/` but global not applied | start a run on `dpl-account-global` |
| `Team 'x' has no network in dpl-account-<env>` | account layer not applied, or team missing in `<env>.tfvars` | add the team to `account-level/env/<env>.tfvars`, then apply `dpl-account-<env>` |
| `<env>.tfvars has no network for team(s): x` | `tfe/` knows the team, the account tfvars doesn't | same as above |
| `Group(s) not managed by dpl-account-global: …` | `extra_workspace_groups` names a group without a YAML | add `account-level/global/teams/<team>/<group>.yaml` (PR into `main`) first |
| `Empty or invalid YAML: teams/…` | YAML syntax error or empty file | fix the file (`environment:` is required) |
| `teams/<folder> must be a team from tfe/ or 'platform'` | folder name isn't a team | rename the folder, or add the team in `tfe/` first |
| `environment must be one of dev/prod …` / `workspace_permission must be ADMIN or USER` | invalid value in a group YAML | fix the value |
| `cannot find user …` (global plan) | a user in `members.users` doesn't exist in the Databricks account | add the user in Account Console (or SCIM) first, or fix the spelling |
| check warning `Group YAML files grant on catalog(s) this team does not define` | `catalog_grants` names a catalog not in the team's uc tfvars | fix the catalog name, or add the catalog |
| `schema_grants reference schemas not defined in the catalog` | a YAML grants on a schema the catalog doesn't have | add the schema in uc tfvars, or fix the YAML |
| `dpl-ws-x-<env> has no workspace yet` | uc ran before ws | apply `dpl-ws-x-<env>`; its trigger re-queues uc |
| `owner_group '…' is not managed by dpl-account-global` | typo or missing group | fix `owner_group` or add the group |
| `Running in AWS account A, but <env> must be B` / `AWS credentials point at …` | wrong variable set attached | check `aws_attachments` in `tfe/`, re-apply `tfe/` |
| check warning `Read-only share pending for: cat/team` | consumer team's workspace not applied yet | run the producer's uc workspace again later |
| check warning `Grant principal(s) not managed …` | grant to a group global doesn't know (typo?) or to an SP | fix the name; SPs are fine |

## Credentials

| Message | Fix |
|---|---|
| `AccessDenied … AssumeRoleWithWebIdentity` | Trust subject mismatch. The org name is case-sensitive (`Dataops-specs`), and so is the project (`databricks-platform`). The workspace must be `dpl-account-<env>` or `dpl-uc-*-<env>`. Compare with `terraform output trusted_subjects` in `bootstrap/aws-oidc`. |
| `No valid credential sources found` (AWS) | The workspace has no `dpl-aws-<env>` set. Only account and uc workspaces should have one. |
| `explicit deny in a service control policy` | The AWS Organization SCP blocks the action in that account (common in PROD). Ask the org admin. |
| `cannot authenticate … default auth` (Databricks) | `DATABRICKS_CLIENT_SECRET` isn't pasted (step 6), or it was rotated. Re-paste it in `dpl-databricks`. |
| `User does not have CREATE STORAGE CREDENTIAL on Metastore` | getting-started step 9 (metastore grant to `dpl-platform-admins`) |
| `PERMISSION_DENIED` on a new workspace right after creation | Permission propagation. Re-run; if it happens repeatedly, raise `time_sleep.workspace_ready` to `120s`. |

## TFE / VCS

| Symptom | Fix |
|---|---|
| `tfe_github_app_installation` not found | Install the HCP Terraform GitHub App on `brata-spec` and authorize your user (getting-started step 3), or use `oauth_token_id`. |
| Workspace creation fails: branch not found | Push `develop` before applying `tfe/`. |
| No run after a merge | The changed file isn't in the workspace's trigger paths (see workflow.md §2), or the workspace tracks the other branch. |
| A PR shows no plan for a workspace | PR plans only run for workspaces tracking the PR's **base** branch. |
| `Given variables file ../x/dev.tfvars does not exist` | Team folder or file missing; `validate.sh` catches it. |
| `Value for undeclared variable` warnings | Harmless: variable-set values a root doesn't use. |
| Both layers ran at once and the lower one failed | The PR touched two layers. Discard the failed run; the run trigger queues a good one. Next time, split the PR. |

## Databricks

| Symptom | Fix |
|---|---|
| Workspace stays `PROVISIONING`, then fails on the network | Subnets need a NAT route (private route tables in `dev.tfvars`) and two different AZs; the SG must allow all traffic within itself. |
| `Metastore … not found` | Name in `global.tfvars` ≠ the name in Account Console → Catalog. |
| Plan wants to **replace** a workspace | `workspace_name` or a network/credential change Databricks can't do in place. Stop and investigate: replacement deletes the workspace. |
| Schema can't be deleted | `force_destroy = false` protects schemas with tables. Empty it first. |

---

## What was validated, and what wasn't

Checked in a sandbox with OpenTofu 1.10 and Databricks provider 1.83, with `required_version` temporarily relaxed. Your run of `scripts/validate.sh` with Terraform 1.11 is the real check.

| Check | Result |
|---|---|
| `fmt` on every file | clean |
| `validate` of the Databricks-only roots and modules (`account-level/global`, `workspace-level/root` (time_sleep stubbed), `metastore`, `user-management`, `databricks-workspace`, `workspace-assignment`, `cluster-policies`, `unity-catalog/modules/catalog`) | valid |
| Every Databricks resource and data block (34) against the provider 1.83 schema | 0 problems |
| Static wiring of all 19 roots and modules (module args vs variables, required inputs, outputs used, `var.`, `local.`, `data.` references) | 0 problems |
| Group YAMLs: all 13 parsed; workspace permissions and catalog grants per team and environment produced as expected; empty file, unknown folder, bad environment and bad permission each rejected at plan | pass |
| YAML catalog grants merged with tfvars grants (union per principal, catalog and schema level), then converted into the catalog module's types for all 4 team/env combinations | pass |
| Every workspace's values type-checked the way TFE passes them (`-var-file` from the working directory, plus TFE variables), including the conversion into `catalog`, `cluster-policies`, `workspace-assignment` and `user-management` types | 11/11 pass; a bad value is rejected |
| `tfe/` mapping evaluated | 11 VCS workspaces, 12 run triggers, state sharing, var files, branches and AWS attachments exactly as in tfe-workspaces.md |
| `validate.sh` consistency checks and the one-layer-per-PR check | pass; a 2-layer change is rejected |
| **Not run here:** `validate` of roots and modules using the AWS, tfe, tls or time providers (not downloadable in the sandbox), and any plan or apply against real accounts | run `scripts/validate.sh`, then follow getting-started.md |
