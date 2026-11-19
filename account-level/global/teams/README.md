# Account groups: one YAML file per group

```
teams/
├── platform/dpl-platform-admins.yaml      platform-wide group (environment: all)
├── de/dpl-dev-de-admins.yaml              file name = group name
├── de/dpl-dev-de-engineers.yaml
└── ...
```

`dpl-account-global` reads every `teams/<folder>/*.yaml`:

| Field | Required | Meaning | Applied by |
|---|---|---|---|
| *(file name)* | yes | group display name in the Databricks account | `dpl-account-global` |
| `environment` | yes | `dev` / `prod` (`all` allowed under `platform/`) | |
| `create` | no (true) | `false` = group already exists (e.g. synced from Entra ID); only look it up | `dpl-account-global` |
| `account_admin` | no (false) | grant the Databricks **account admin** role | `dpl-account-global` |
| `members.users` | no | user names (e-mails); users must already exist in the account | `dpl-account-global` (when `manage_members = true`) |
| `members.service_principals` | no | application (client) IDs | `dpl-account-global` |
| `members.groups` | no | nested groups (must have their own YAML) | `dpl-account-global` |
| `workspace_permission` | no | `ADMIN` / `USER` on the team's workspace in that environment. Under `platform/`: on **every** workspace | `dpl-ws-<team>-<env>` |
| `catalog_grants.<catalog>.privileges` | no | catalog privileges, e.g. `[USE_CATALOG]` | `dpl-uc-<team>-<env>` |
| `catalog_grants.<catalog>.schemas.<schema>` | no | schema privileges, e.g. `[USE_SCHEMA, SELECT]` | `dpl-uc-<team>-<env>` |

The folder is the team: a group in `teams/de/` can only get access to DE's workspace and
DE's catalogs. Cross-team, read-only access is set by the **producing** team with
`consumers` in `unity-catalog/<team>/<env>.tfvars`.

**Flow:** PR into `main` -> confirm `dpl-account-global` (group + members) -> run triggers
re-run `dpl-ws-*` (workspace permission). Catalog grants appear on the team's next
`dpl-uc-<team>-<env>` run (start one, or it happens with the next catalog change).

**Renaming a file renames the group = destroy + create.** Add the new file first, move
references, then delete the old file.
