#!/usr/bin/env bash
# Sets up the ADA_Self_Tooling Named Credential in a scratch org.
#   scripts/setup-self-tooling.sh [org-alias] [--callback]
# --callback  print the connected app callback URL and exit (do this first).
# Otherwise it asks for the connected app consumer key and secret (hidden prompt, or the
# ADA_TOOLING_CLIENT_ID / ADA_TOOLING_CLIENT_SECRET environment variables), renders the
# templates into setup/rendered/ (git-ignored), deploys them, and assigns the access permission set.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ORG="ada-dev"
CALLBACK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --callback) CALLBACK_ONLY=1 ;;
    *) ORG="$arg" ;;
  esac
done

ORG_URL="$(sf org display --target-org "$ORG" --json | node -e "
let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{console.log(JSON.parse(s).result.instanceUrl.replace(/\/\$/,''))})")"
CALLBACK="${ORG_URL}/services/authcallback/ADA_Self_Tooling_Provider"

if [[ "$CALLBACK_ONLY" == 1 ]]; then
  echo "Callback URL for the connected app: ${CALLBACK}"
  exit 0
fi

KEY="${ADA_TOOLING_CLIENT_ID:-}"
SECRET="${ADA_TOOLING_CLIENT_SECRET:-}"
if [[ -z "$KEY" ]]; then read -rsp "Connected app Consumer Key: " KEY; echo; fi
if [[ -z "$SECRET" ]]; then read -rsp "Connected app Consumer Secret: " SECRET; echo; fi
[[ -n "$KEY" && -n "$SECRET" ]] || { echo "Key and secret are required." >&2; exit 1; }

rm -rf setup/rendered
mkdir -p setup/rendered
cp -R setup/self-tooling-template/main setup/rendered/main

ORG_URL="$ORG_URL" KEY="$KEY" SECRET="$SECRET" node -e "
const fs=require('fs'),path=require('path');
const walk=d=>fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(d,e.name)):[path.join(d,e.name)]);
for(const f of walk('setup/rendered')){
  let t=fs.readFileSync(f,'utf8');
  const esc=v=>v.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  t=t.split('__ORG_URL__').join(process.env.ORG_URL).split('__CONSUMER_KEY__').join(esc(process.env.KEY)).split('__CONSUMER_SECRET__').join(esc(process.env.SECRET));
  fs.writeFileSync(f,t);
}"

sf project deploy start --source-dir setup/rendered --target-org "$ORG" --wait 30
rm -rf setup/rendered
sf org assign permset --name ADA_Self_Tooling_Access --target-org "$ORG" || true

cat <<EOF

Last step (human): in the org go to Setup > Named Credentials > External Credentials >
ADA Self Tooling > Principals > ADA_Tooling_Principal > Authenticate, and log in as the org admin.
Then run:
  node scripts/lib/run-apex-markers.mjs --org ${ORG} --file scripts/e2e/tooling-smoke.apex \\
    --expect ADA_TOOLING_OK --fail-on ADA_TOOLING_FAIL
EOF
