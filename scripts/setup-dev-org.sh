#!/usr/bin/env bash
# Deploys the package and demo into the dev org (Developer Edition, alias ada-dev), assigns the
# permission sets, seeds demo and canary data and prints the human checklist.
# Safe to run again. Usage: scripts/setup-dev-org.sh [org-alias]
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ORG="${1:-ada-dev}"

sf org display --target-org "$ORG" >/dev/null 2>&1 || { echo "Org '${ORG}' not found (sf alias set ${ORG}=<username>)."; exit 1; }
if [[ "$(sf data query --target-org "$ORG" --query "SELECT OrganizationType FROM Organization" --json | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).result.records[0].OrganizationType))")" != "Developer Edition" ]]; then
  echo "'${ORG}' must be a Developer Edition org; this script deploys metadata and seeds data."; exit 1
fi

dirs=()
for d in force-app demo-app; do
  if find "$d" -type f ! -name .gitkeep 2>/dev/null | grep -q .; then dirs+=(--source-dir "$d"); fi
done
if [[ "${#dirs[@]}" -gt 0 ]]; then
  echo "Deploying to ${ORG}..."
  sf project deploy start "${dirs[@]}" --target-org "$ORG" --wait 30
fi

if find force-app -name "ADA_Admin.permissionset-meta.xml" | grep -q .; then
  sf org assign permset --name ADA_Admin --target-org "$ORG" || true
fi

if find demo-app -name "ADA_Demo_Notes_Editor.permissionset-meta.xml" | grep -q .; then
  sf org assign permset --name ADA_Demo_Notes_Editor --target-org "$ORG" || true
fi

if [[ -f scripts/e2e/seed.apex ]]; then
  echo "Seeding demo and canary data..."
  seeded=0
  for attempt in 1 2 3 4; do
    if sf apex run --file scripts/e2e/seed.apex --target-org "$ORG" >/tmp/ada-seed.log 2>&1; then
      seeded=1
      break
    fi
    sleep 5
  done
  if [[ "$seeded" != 1 ]]; then
    echo "Seeding failed:"
    tail -n 20 /tmp/ada-seed.log
    exit 1
  fi
fi

cat <<'EOF'

Dev org ready. Human checklist (docs/SETUP.md §7):
  [ ] scripts/setup-self-tooling.sh, then Authenticate ADA_Self_Tooling (once per org)
  [ ] Paste the Groq key into ADA_LLM (when step 1.6 is done)
  [ ] Paste the Azure DevOps PAT into ADA_AzureDevOps (when step 2.1 is done)
  [ ] Assign ADA_User to the demo restricted user
  [ ] Phase 3: Deliverability = All email; email approval response enabled
EOF
