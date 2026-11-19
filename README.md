# dataops-databricks-platform

Databricks on AWS, deployed by **Terraform Enterprise / HCP Terraform** (organization `Dataops-specs`) from GitHub, VCS-driven. No GitHub Actions, no S3 backend, no long-lived AWS keys.

Three layers, **one shared root per layer**, and teams only edit `.tfvars` files.

```
dataops-databricks-platform/
├── modules/                          reusable, never run directly
│   ├── aws-account/                  VPC (existing or new), root bucket, per-team subnets/SG/cross-account role
│   │   └── modules/                  network-foundation, workspace-network, root-storage, cross-account-role
│   ├── metastore/                    create or look up the regional Unity Catalog metastore
│   ├── user-management/              account groups, account admins, deployer membership, optional members
│   ├── databricks-workspace/         workspace + metastore assignment
│   ├── workspace-assignment/         groups / service principals -> workspace (ADMIN | USER)
│   ├── cluster-policies/             optional per team (feature-flag example)
│   └── unity-catalog/                UC bucket, IAM role, credential, external location, catalogs, schemas, grants
│       └── modules/                  storage, catalog
│
├── account-level/                    LAYER 1
│   ├── global/                       dpl-account-global   metastore + groups (shared by DEV and PROD)
│   │   ├── global.tfvars
│   │   └── teams/                    ONE YAML PER GROUP: members, workspace permission, catalog grants
│   │       ├── platform/dpl-platform-admins.yaml
│   │       ├── de/dpl-dev-de-engineers.yaml ...
│   │       └── ae/dpl-dev-ae-analysts.yaml ...
│   └── env/                          dpl-account-dev / dpl-account-prod   one AWS account each
│       ├── dev.tfvars                existing DEV VPC vpc-03950e5934415cd3c
│       └── prod.tfvars               new PROD VPC
│
├── workspace-level/                  LAYER 2
│   ├── root/                         ONE root for all teams -> dpl-ws-<team>-<env>
│   ├── ae/  dev.tfvars prod.tfvars
│   └── de/  dev.tfvars prod.tfvars   (DE also enables cluster policies)
│
├── unity-catalog/                    LAYER 3
│   ├── root/                         ONE root for all teams -> dpl-uc-<team>-<env>
│   ├── ae/  dev.tfvars prod.tfvars
│   └── de/  dev.tfvars prod.tfvars   (DE shares its gold schema with AE)
│
├── tfe/                              creates every TFE workspace, variable set, run trigger, state-sharing rule
├── bootstrap/aws-oidc/               OIDC trust + plan/apply roles, once per AWS account
├── scripts/validate.sh               fmt, validate, consistency, one-layer-per-PR
├── .github/                          CODEOWNERS, PR template
└── docs/
```

## TFE workspaces (2 teams -> 11)

| Workspace | Layer | Working dir | Var file | Branch | Apply | AWS creds |
|---|---|---|---|---|---|---|
| `dpl-account-global` | 1 | `account-level/global` | `global.tfvars` | `main` | manual | none |
| `dpl-account-dev` | 1 | `account-level/env` | `dev.tfvars` | `develop` | manual | DEV |
| `dpl-account-prod` | 1 | `account-level/env` | `prod.tfvars` | `main` | manual | PROD |
| `dpl-ws-<team>-dev` | 2 | `workspace-level/root` | `../<team>/dev.tfvars` | `develop` | auto | none |
| `dpl-ws-<team>-prod` | 2 | `workspace-level/root` | `../<team>/prod.tfvars` | `main` | manual | none |
| `dpl-uc-<team>-dev` | 3 | `unity-catalog/root` | `../<team>/dev.tfvars` | `develop` | auto | DEV |
| `dpl-uc-<team>-prod` | 3 | `unity-catalog/root` | `../<team>/prod.tfvars` | `main` | manual | PROD |

Formula: `3 + 4 x teams`. Each workspace has its own state in TFE.

## Order

```
dpl-account-global ─┐
                    ├─► dpl-ws-<team>-<env> ──► dpl-uc-<team>-<env>
dpl-account-<env> ──┘
```

Run triggers queue the next layer after a successful apply. Remote state and preconditions make an out-of-order run fail at **plan**, before anything is created. See [docs/workflow.md](docs/workflow.md).

## Docs

| Doc | For |
|---|---|
| [docs/getting-started.md](docs/getting-started.md) | First-time setup, step by step (GitHub, TFE, AWS OIDC, first deploy) |
| [docs/workflow.md](docs/workflow.md) | Branches, PRs, promotion, and 14 day-to-day scenarios |
| [docs/architecture.md](docs/architecture.md) | Layers, state, credentials, identities, naming |
| [docs/tfe-workspaces.md](docs/tfe-workspaces.md) | Every workspace, trigger, variable and sharing rule `tfe/` creates |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common errors, and what was validated |

## Rules

1. Teams edit only their group YAMLs (`account-level/global/teams/<team>/*.yaml`), `workspace-level/<team>/*.tfvars` and `unity-catalog/<team>/*.tfvars`.
2. One layer per PR (`./scripts/validate.sh --pr <base>`).
3. `account-level/global` changes (including group YAMLs) go to `main` first, then `main` is merged back into `develop`.
4. PROD is confirmed top-down: account -> workspace -> unity-catalog.
5. Secrets live only in the TFE UI (`DATABRICKS_CLIENT_SECRET`). AWS uses OIDC.
