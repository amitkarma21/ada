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

dirs=(--source-dir force-app)
if find demo-app -type f 2>/dev/null | grep -q .; then dirs+=(--source-dir demo-app); fi
if find force-app -type f 2>/dev/null | grep -q .; then
  echo "Deploying..."
  sf project deploy start "${dirs[@]}" --target-org "$ALIAS" --wait 30
fi

if find force-app -name "ADA_Admin.permissionset-meta.xml" | grep -q .; then
  sf org assign permset --name ADA_Admin --target-org "$ALIAS" || true
fi

if [[ -f scripts/e2e/seed.apex ]]; then
  echo "Seeding demo and canary data..."
  sf apex run --file scripts/e2e/seed.apex --target-org "$ALIAS" >/dev/null
fi

cat <<'EOF'

Scratch org ready. Human checklist (docs/SETUP.md §7):
  [ ] Authorise External Credential ADA_Self_Tooling (Setup → Named Credentials → External Credentials)
  [ ] Paste the Groq key into ADA_LLM (when step 1.6 is done)
  [ ] Paste the Azure DevOps PAT into ADA_AzureDevOps (when step 2.1 is done)
  [ ] Assign ADA_User to the demo restricted user
  [ ] Phase 3: Deliverability = All email; email approval response enabled
EOF
