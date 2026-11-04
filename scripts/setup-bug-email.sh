#!/usr/bin/env bash
# Sets the address that receives ADA bug reports (ADA_Setting Default, Bug_Report_Email__c).
#   scripts/setup-bug-email.sh [org-alias]
# Env: ADA_BUG_EMAIL (the address), ADA_DRY_RUN=1 to validate without deploying.
# Keeps the org's current LLM provider and model when it rewrites ADA_Setting Default.
# Email only leaves the org when Setup > Email > Deliverability is set to "All email".
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ORG="${1:-ada-dev}"
ADDRESS="${ADA_BUG_EMAIL:-}"
if [[ -z "$ADDRESS" ]]; then read -rp "Address that should receive ADA bug reports: " ADDRESS; fi
if [[ ! "$ADDRESS" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ || "${#ADDRESS}" -gt 254 ]]; then
  echo "That is not a single email address. Nothing was deployed." >&2; exit 1
fi

CURRENT="$(sf data query -o "$ORG" -q "SELECT LLM_Provider__c, LLM_Model__c FROM ADA_Setting__mdt WHERE DeveloperName='Default'" --json 2>/dev/null || echo '{}')"

rm -rf setup/rendered
mkdir -p setup/rendered/main/default/customMetadata

ADDRESS="$ADDRESS" CURRENT="$CURRENT" node -e "
const fs=require('fs');
const esc=v=>v.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const val=(f,t,v)=>'    <values>\n        <field>'+f+'</field>\n        <value xsi:type=\"xsd:'+t+'\">'+esc(v)+'</value>\n    </values>\n';
let s=fs.readFileSync('force-app/main/default/customMetadata/ADA_Setting.Default.md-meta.xml','utf8');
let extra=val('Bug_Report_Email__c','string',process.env.ADDRESS);
let row={};
try{row=(JSON.parse(process.env.CURRENT).result.records||[])[0]||{};}catch(e){}
if(row.LLM_Provider__c){
  s=s.replace('<value xsi:type=\"xsd:string\">Template</value>','<value xsi:type=\"xsd:string\">'+esc(row.LLM_Provider__c)+'</value>');
}
if(row.LLM_Model__c) extra+=val('LLM_Model__c','string',row.LLM_Model__c);
s=s.replace('</CustomMetadata>',extra+'</CustomMetadata>');
fs.writeFileSync('setup/rendered/main/default/customMetadata/ADA_Setting.Default.md-meta.xml',s);
"

DRY=()
[[ "${ADA_DRY_RUN:-0}" == "1" ]] && DRY=(--dry-run)
sf project deploy start --source-dir setup/rendered --target-org "$ORG" --wait 10 "${DRY[@]}"
rm -rf setup/rendered
echo
echo "Bug reports will go to ${ADDRESS}."
echo "If nothing arrives: Setup > Email > Deliverability > Access level = All email."
