#!/usr/bin/env bash
# Sets up the ADA_LLM Named Credential and turns the LLM provider on in the dev org.
#   scripts/setup-llm.sh [org-alias]
# Env: ADA_LLM_BASE_URL (default Groq's OpenAI-compatible endpoint), ADA_LLM_MODEL (asked if unset).
# The API key is never passed to this script: paste it in the org (printed at the end).
# Renders the templates into setup/rendered/ (git-ignored), deploys them, assigns the access
# permission set, and writes ADA_Setting Default with provider OpenAICompatible and the model.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ORG="${1:-ada-dev}"
BASE_URL="${ADA_LLM_BASE_URL:-https://api.groq.com/openai/v1}"
MODEL="${ADA_LLM_MODEL:-}"
if [[ -z "$MODEL" ]]; then read -rp "Model id, NOT the API key (from the provider's model list, must support JSON output): " MODEL; fi
[[ -n "$MODEL" ]] || { echo "A model id is required." >&2; exit 1; }
if [[ "$MODEL" == gsk_* || "$MODEL" == sk-* || "${#MODEL}" -gt 80 ]]; then
  echo "That looks like an API key, not a model id (for example llama-3.3-70b-versatile). Nothing was deployed." >&2
  exit 1
fi

rm -rf setup/rendered
mkdir -p setup/rendered
cp -R setup/llm-template/main setup/rendered/main

BASE_URL="$BASE_URL" MODEL="$MODEL" node -e "
const fs=require('fs'),path=require('path');
const walk=d=>fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(d,e.name)):[path.join(d,e.name)]);
const esc=v=>v.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
for(const f of walk('setup/rendered')){
  let t=fs.readFileSync(f,'utf8');
  t=t.split('__LLM_BASE_URL__').join(esc(process.env.BASE_URL));
  fs.writeFileSync(f,t);
}
const src='force-app/main/default/customMetadata/ADA_Setting.Default.md-meta.xml';
let s=fs.readFileSync(src,'utf8');
s=s.replace('<value xsi:type=\"xsd:string\">Template</value>','<value xsi:type=\"xsd:string\">OpenAICompatible</value>');
const model='    <values>\n        <field>LLM_Model__c</field>\n        <value xsi:type=\"xsd:string\">'+esc(process.env.MODEL)+'</value>\n    </values>\n';
s=s.replace('</CustomMetadata>',model+'</CustomMetadata>');
const out='setup/rendered/main/default/customMetadata';
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(out+'/ADA_Setting.Default.md-meta.xml',s);
"

sf project deploy start --source-dir setup/rendered --target-org "$ORG" --wait 30
rm -rf setup/rendered
sf org assign permset --name ADA_LLM_Access --target-org "$ORG" || true

cat <<EOF2

Last step (human): paste the API key into the org.
  Setup > Named Credentials > External Credentials > ADA LLM > Principals > ADA_LLM_Principal
  > add an Authentication Parameter named ApiKey with your key as the value.
Then run (this calls the real service):
  LIVE=1 scripts/verify.sh live
EOF2
