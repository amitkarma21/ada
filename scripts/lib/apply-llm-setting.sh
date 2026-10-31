#!/usr/bin/env bash
# Deploys ADA_Setting Default with provider OpenAICompatible and the given model (dev org only).
# The unit gate deploys the repo default (Template) over it, so the live gate calls this.
#   scripts/lib/apply-llm-setting.sh <org-alias> <model-id>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
ORG="${1:?org alias}"
MODEL="${2:?model id}"
if [[ "$MODEL" == gsk_* || "$MODEL" == sk-* || "${#MODEL}" -gt 80 ]]; then
  echo "That looks like an API key, not a model id." >&2; exit 1
fi
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT
mkdir -p "$DIR/main/default/customMetadata"
MODEL="$MODEL" node -e "
const fs=require('fs');
const esc=v=>v.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
let s=fs.readFileSync('force-app/main/default/customMetadata/ADA_Setting.Default.md-meta.xml','utf8');
s=s.replace('<value xsi:type=\"xsd:string\">Template</value>','<value xsi:type=\"xsd:string\">OpenAICompatible</value>');
s=s.replace('</CustomMetadata>','    <values>\n        <field>LLM_Model__c</field>\n        <value xsi:type=\"xsd:string\">'+esc(process.env.MODEL)+'</value>\n    </values>\n</CustomMetadata>');
fs.writeFileSync('$DIR/main/default/customMetadata/ADA_Setting.Default.md-meta.xml',s);
"
sf project deploy start --source-dir "$DIR/main" --target-org "$ORG" --wait 10
