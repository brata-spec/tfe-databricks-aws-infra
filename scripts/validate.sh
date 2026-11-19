#!/usr/bin/env bash
###############################################################################
# scripts/validate.sh - run before every push (Git Bash on Windows works).
#
#   ./scripts/validate.sh                 fmt + validate + consistency checks
#   ./scripts/validate.sh --pr develop    ... plus "one layer per PR" against a base branch
#
# Needs terraform >= 1.11 on PATH. No credentials needed (init -backend=false).
###############################################################################
set -uo pipefail
cd "$(dirname "$0")/.."

TF=${TF:-terraform}
BASE=""
[[ "${1:-}" == "--pr" ]] && BASE="${2:?usage: --pr <base-branch>}"

fail=0
ok()   { printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
step() { printf '\n== %s\n' "$1"; }

# --- 1. Formatting ------------------------------------------------------------------
step "terraform fmt"
if $TF fmt -check -recursive >/dev/null; then ok "formatted"; else bad "run: terraform fmt -recursive"; $TF fmt -check -recursive; fi

# --- 2. Validate every root and module ----------------------------------------------
step "terraform validate"
dirs=(account-level/global account-level/env workspace-level/root unity-catalog/root tfe bootstrap/aws-oidc)
while IFS= read -r d; do dirs+=("$d"); done < <(find modules -name versions.tf -exec dirname {} \; | sort)
for d in "${dirs[@]}"; do
  out=$(cd "$d" && $TF init -backend=false -input=false -no-color >/dev/null 2>&1 && $TF validate -no-color 2>&1)
  if [[ $? -eq 0 ]]; then ok "$d"; else bad "$d"; echo "$out" | sed 's/^/       /'; fi
done

# --- 3. Consistency between tfe/, tfvars and folders --------------------------------
step "teams and environments"
if [[ -f tfe/terraform.tfvars ]] && grep -qE '^teams\s*=' tfe/terraform.tfvars; then
  teams_src=tfe/terraform.tfvars
  teams=$(grep -E '^teams\s*=' tfe/terraform.tfvars | grep -oE '"[a-z][a-z0-9]*"' | tr -d '"' | sort -u)
else
  teams_src=tfe/variables.tf
  teams=$(awk '/variable "teams"/,/^}/' tfe/variables.tf | grep -E '^\s*default' | grep -oE '"[a-z][a-z0-9]*"' | tr -d '"' | sort -u)
fi
envs="dev prod"
echo "  teams (from $teams_src): $(echo $teams)"

for t in $teams; do
  for e in $envs; do
    for layer in workspace-level unity-catalog; do
      f="$layer/$t/$e.tfvars"
      [[ -f "$f" ]] && ok "$f" || bad "$f missing"
    done
    grep -qE "^\s+$t\s*=\s*\{" "account-level/env/$e.tfvars" \
      && ok "account-level/env/$e.tfvars has network for $t" \
      || bad "account-level/env/$e.tfvars has no network for team $t"
  done
done

# team folders that tfe/ does not know about
for layer in workspace-level unity-catalog; do
  for d in "$layer"/*/; do
    t=$(basename "$d"); [[ "$t" == root ]] && continue
    echo "$teams" | grep -qx "$t" || bad "$layer/$t exists but team '$t' is not in $teams_src"
  done
done

step "group YAML files (account-level/global/teams)"
G=account-level/global/teams
for d in "$G"/*/; do
  f=$(basename "$d")
  [[ "$f" == platform ]] || echo "$teams" | grep -qx "$f" || bad "$G/$f: folder is not a team in $teams_src (or 'platform')"
done
for t in $teams; do
  for e in $envs; do
    n=$(grep -lE "^environment:\s*$e\s*$" "$G/$t"/*.yaml 2>/dev/null | wc -l)
    [[ $n -gt 0 ]] && ok "$G/$t: $n group(s) for $e" || bad "$G/$t: no group YAML with 'environment: $e'"
  done
done
for y in "$G"/*/*.yaml; do
  b=$(basename "$y" .yaml)
  [[ "$b" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{1,99}$ ]] || bad "$y: file name is not a valid group name"
  grep -qE '^environment:' "$y" || bad "$y: missing 'environment:'"
done
dups=$(for y in "$G"/*/*.yaml; do basename "$y"; done | sort | uniq -d)
[[ -z "$dups" ]] || bad "same group file in two folders: $dups"

step "values that only tfe/ may set"
hits=$(grep -nE '^\s*(team|environment|aws_account_id|teams|expected_teams)\s*=' \
  workspace-level/*/*.tfvars unity-catalog/*/*.tfvars account-level/*/*.tfvars 2>/dev/null \
  | grep -vE 'account-level/env/[a-z]+\.tfvars:[0-9]+:\s+teams\s*=|account-level/env/[a-z]+\.tfvars:[0-9]+:teams\s*=' || true)
if [[ -z "$hits" ]]; then ok "none in tfvars"; else bad "set these in tfe/, not in tfvars:"; echo "$hits" | sed 's/^/       /'; fi

# --- 4. One layer per PR -------------------------------------------------------------
if [[ -n "$BASE" ]]; then
  step "one layer per PR (against $BASE)"
  layers=$(git diff --name-only "origin/$BASE...HEAD" 2>/dev/null || git diff --name-only "$BASE...HEAD")
  layers=$(echo "$layers" | awk -F/ '
    /^account-level\/global\//                         {print "account-global"; next}
    /^modules\/(metastore|user-management)\//          {print "account-global"; next}
    /^account-level\/env\//                            {print "account"; next}
    /^modules\/aws-account\//                          {print "account"; next}
    /^workspace-level\//                               {print "workspace"; next}
    /^modules\/(databricks-workspace|workspace-assignment|cluster-policies)\// {print "workspace"; next}
    /^unity-catalog\//                                 {print "unity-catalog"; next}
    /^modules\/unity-catalog\//                        {print "unity-catalog"; next}
    /^tfe\//                                           {print "tfe-admin"; next}
    /^bootstrap\//                                     {print "bootstrap"; next}' | sort -u)
  n=$(echo "$layers" | grep -c . || true)
  if [[ $n -le 1 ]]; then ok "layers touched: ${layers:-none}"; else bad "PR touches $n layers: $(echo $layers) - split it (see docs/workflow.md)"; fi
fi

echo
[[ $fail -eq 0 ]] && echo "All checks passed." || echo "Some checks FAILED."
exit $fail
