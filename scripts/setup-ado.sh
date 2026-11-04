#!/usr/bin/env bash
# Sets up the ADA_AzureDevOps Named Credential and turns Azure DevOps on in the dev org.
#   scripts/setup-ado.sh [org-alias]
# Env: ADA_ADO_ORG (Azure DevOps organisation name), ADA_ADO_PROJECT, ADA_ADO_AREA_PATH (optional),
#      ADA_ADO_WORK_ITEM_TYPE (default Bug), ADA_DRY_RUN=1 to validate without deploying.
# The personal access token is never passed to this script: paste it in the org (printed at the end).
# Keeps the org's current LLM provider and model when it rewrites ADA_Setting Default.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ORG="${1:-ada-dev}"
ADO_ORG="${ADA_ADO_ORG:-}"
PROJECT="${ADA_ADO_PROJECT:-}"
AREA="${ADA_ADO_AREA_PATH:-}"
TYPE="${ADA_ADO_WORK_ITEM_TYPE:-Bug}"
if [[ -z "$ADO_ORG" ]]; then read -rp "Azure DevOps organisation name (the part after dev.azure.com/): " ADO_ORG; fi
if [[ -z "$PROJECT" ]]; then read -rp "Azure DevOps project name: " PROJECT; fi
[[ "$ADO_ORG" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || { echo "That is not a valid organisation name (letters, digits, . _ - only). Nothing was deployed." >&2; exit 1; }
[[ -n "$PROJECT" ]] || { echo "A project name is required." >&2; exit 1; }
if [[ "${#PROJECT}" -gt 64 || "${#ADO_ORG}" -gt 64 || "${#TYPE}" -gt 64 || "${#AREA}" -gt 255 || "$ADO_ORG" == *https* ]]; then
  echo "A value looks wrong (too long, or a URL or token instead of a name). Nothing was deployed." >&2; exit 1
fi

CURRENT="$(sf data query -o "$ORG" -q "SELECT LLM_Provider__c, LLM_Model__c FROM ADA_Setting__mdt WHERE DeveloperName='Default'" --json 2>/dev/null || echo '{}')"

rm -rf setup/rendered
mkdir -p setup/rendered
cp -R setup/ado-template/main setup/rendered/main

ADO_ORG="$ADO_ORG" PROJECT="$PROJECT" AREA="$AREA" TYPE="$TYPE" CURRENT="$CURRENT" node -e "
const fs=require('fs'),path=require('path');
const walk=d=>fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(d,e.name)):[path.join(d,e.name)]);
const esc=v=>v.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
for(const f of walk('setup/rendered')){
  let t=fs.readFileSync(f,'utf8');
  t=t.split('__ADO_ORG__').join(esc(process.env.ADO_ORG));
  fs.writeFileSync(f,t);
}
let s=fs.readFileSync('force-app/main/default/customMetadata/ADA_Setting.Default.md-meta.xml','utf8');
const val=(f,t,v)=>'    <values>\n        <field>'+f+'</field>\n        <value xsi:type=\"xsd:'+t+'\">'+esc(v)+'</value>\n    </values>\n';
s=s.replace('<field>ADO_Enabled__c</field>\n        <value xsi:type=\"xsd:boolean\">false</value>','<field>ADO_Enabled__c</field>\n        <value xsi:type=\"xsd:boolean\">true</value>');
s=s.replace('<value xsi:type=\"xsd:string\">Bug</value>','<value xsi:type=\"xsd:string\">'+esc(process.env.TYPE)+'</value>');
let extra=val('ADO_Project__c','string',process.env.PROJECT);
if(process.env.AREA) extra+=val('ADO_Area_Path__c','string',process.env.AREA);
let row={};
try{row=(JSON.parse(process.env.CURRENT).result.records||[])[0]||{};}catch(e){}
if(row.LLM_Provider__c){
  s=s.replace('<value xsi:type=\"xsd:string\">Template</value>','<value xsi:type=\"xsd:string\">'+esc(row.LLM_Provider__c)+'</value>');
}
if(row.LLM_Model__c) extra+=val('LLM_Model__c','string',row.LLM_Model__c);
s=s.replace('</CustomMetadata>',extra+'</CustomMetadata>');
const out='setup/rendered/main/default/customMetadata';
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(out+'/ADA_Setting.Default.md-meta.xml',s);
"

DRY=()
[[ "${ADA_DRY_RUN:-0}" == "1" ]] && DRY=(--dry-run)
sf project deploy start --source-dir setup/rendered --target-org "$ORG" --wait 30 "${DRY[@]}"
rm -rf setup/rendered
if [[ "${ADA_DRY_RUN:-0}" != "1" ]]; then
  sf org assign permset --name ADA_ADO_Access --target-org "$ORG" || true
fi

cat <<EOF2

Last step (human): paste the access token into the org.
  Azure DevOps > User settings > Personal access tokens > New token
  (scope: Work Items, Read & write; shortest expiry you can live with).
  Setup > Named Credentials > External Credentials > ADA Azure DevOps > Principals
  > ADA_AzureDevOps_Principal > add Username = ada and Password = your token.
Then ask for the live check (step 2.2).
EOF2
