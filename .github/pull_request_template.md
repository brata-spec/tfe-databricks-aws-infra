## What changes

<!-- one line: e.g. "DE dev: add silver schema grant for analysts" -->

## Layer (tick ONE - see docs/workflow.md)

- [ ] account-global  (`account-level/global` incl. `teams/*/*.yaml` groups, `modules/metastore`, `modules/user-management`) -> PR into **main**
- [ ] account         (`account-level/env`, `modules/aws-account`)
- [ ] workspace       (`workspace-level/`, `modules/databricks-workspace|workspace-assignment|cluster-policies`)
- [ ] unity-catalog   (`unity-catalog/`, `modules/unity-catalog`)
- [ ] tfe / bootstrap (applied locally by the platform team)

## Checks

- [ ] `./scripts/validate.sh --pr <base>` passes
- [ ] TFE speculative plans reviewed (status checks on this PR)
- [ ] Other teams' plans show **no changes** (if shared code changed)
