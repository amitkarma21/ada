#!/usr/bin/env bash
# Creates (or replaces) a scratch org, deploys the package and demo, seeds canary data and
# prints the human checklist. Usage: scripts/new-scratch-org.sh [alias] [days]
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ALIAS="${1:-ada-dev}"
DAYS="${2:-7}"
DEVHUB="${ADA_DEVHUB:-ada-devhub}"

if sf org display --target-org "$ALIAS" >/dev/null 2>&1; then
  echo "Deleting existing scratch org '${ALIAS}'..."
  sf org delete scratch --target-org "$ALIAS" --no-prompt || true
fi

echo "Creating scratch org '${ALIAS}' for ${DAYS} days..."
sf org create scratch --definition-file config/project-scratch-def.json --alias "$ALIAS" \
  --duration-days "$DAYS" --target-dev-hub "$DEVHUB" --set-default --wait 15

dirs=()
for d in force-app demo-app; do
  if find "$d" -type f ! -name .gitkeep 2>/dev/null | grep -q .; then dirs+=(--source-dir "$d"); fi
done
if [[ "${#dirs[@]}" -gt 0 ]]; then
  echo "Deploying..."
  sf project deploy start "${dirs[@]}" --target-org "$ALIAS" --wait 30
fi

if find force-app -name "ADA_Admin.permissionset-meta.xml" | grep -q .; then
  sf org assign permset --name ADA_Admin --target-org "$ALIAS" || true
fi

if find demo-app -name "ADA_Demo_Notes_Editor.permissionset-meta.xml" | grep -q .; then
  # New custom fields are invisible to everyone until a permission set grants them, and the seed needs it.
  sf org assign permset --name ADA_Demo_Notes_Editor --target-org "$ALIAS" || true
fi

if [[ -f scripts/e2e/seed.apex ]]; then
  echo "Seeding demo and canary data..."
  # A fresh permission set assignment can take a few seconds to reach field-level security.
  seeded=0
  for attempt in 1 2 3 4; do
    if sf apex run --file scripts/e2e/seed.apex --target-org "$ALIAS" >/tmp/ada-seed.log 2>&1; then
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

Scratch org ready. Human checklist (docs/SETUP.md §7):
  [ ] Authorise External Credential ADA_Self_Tooling (Setup → Named Credentials → External Credentials)
  [ ] Paste the Groq key into ADA_LLM (when step 1.6 is done)
  [ ] Paste the Azure DevOps PAT into ADA_AzureDevOps (when step 2.1 is done)
  [ ] Assign ADA_User to the demo restricted user
  [ ] Phase 3: Deliverability = All email; email approval response enabled
EOF
