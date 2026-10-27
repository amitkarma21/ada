# Setup — free accounts and tools

Everything here is free. Your Claude subscription covers Claude Code for the build; the app's
runtime LLM uses Groq's free tier, and you can switch providers later without code changes.
Free-tier limits and terms change, so check each one when you sign up.

Never commit keys, tokens or passwords. They go into Salesforce External Credentials or GitHub
Actions secrets only.

## 1. Tools on your machine

- Node.js LTS and npm
- Git and the GitHub CLI (`gh auth login`)
- Salesforce CLI: `npm install --global @salesforce/cli`, then `sf plugins install code-analyzer`
  (Code Analyzer needs Java 11+ and Python 3.10+ for some engines; install them if it says so)
- VS Code with the Salesforce Extension Pack (optional but useful)
- Claude Code, signed in with your Claude subscription

## 2. Salesforce Developer Edition as Dev Hub

1. Sign up for a free Developer Edition org at developer.salesforce.com/signup.
2. Setup → Dev Hub → enable Dev Hub. (Also enable "Unlocked Packages and Second-Generation
   Managed Packages".)
3. `sf org login web --set-default-dev-hub --alias ada-devhub`
4. Later (phase 4) you'll register a namespace in a **second** free Developer Edition org and
   link it to this Dev Hub.

## 3. GitHub

1. Create a private repo (for example `ada`), copy this kit into it, push.
2. For CI's org jobs (optional until phase 1 ends), create a certificate and an External Client
   App in the Dev Hub for JWT login, then add repo secrets `SF_DEVHUB_USERNAME`,
   `SF_DEVHUB_CLIENT_ID` and `SF_DEVHUB_JWT_KEY` (the private key text). Claude Code can walk
   you through this when CI org jobs are switched on.

## 4. Groq (runtime LLM during the build)

1. Sign up at console.groq.com (free tier, no card; may ask for phone verification).
2. Create an API key. In Data Controls, turn on Zero Data Retention if offered.
3. Pick a model from the console's model list that supports JSON output; note its ID for
   `ADA_Setting__mdt.LLM_Model__c`.
4. In the scratch org (step 1.6): Setup → Named Credentials → External Credentials →
   `ADA_LLM` → principal → paste the key. Assign the principal through the `ADA_User`
   permission set.

Why Groq: its terms say inputs and outputs aren't used for training and zero data retention is
available. Google's free Gemini tier, by contrast, uses free-tier prompts to improve its products
and allows human review, which conflicts with this app's promise. See `docs/DECISIONS.md` D-04.

## 5. Azure DevOps (bug target)

1. Create a free Azure DevOps organisation at dev.azure.com (free for the first 5 Basic users).
2. Create a project `ADA-Test` using the Basic or Agile process.
3. Create a personal access token with **Work Items: Read & write** only, short expiry.
4. Store it in the `ADA_AzureDevOps` External Credential in the dev org (step 2.1).

## 6. ServiceNow developer instance (optional fulfilment target)

1. Sign up at developer.servicenow.com and request a free Personal Developer Instance.
2. Create a catalog item "Salesforce access" with variables for permission, requester and
   justification; note its sys_id for `ADA_Setting__mdt.ServiceNow_Catalog_Item__c`.
3. Use a dedicated integration user with only the roles needed to order that item.
4. Instances sleep when idle and are reclaimed after long inactivity; wake it before live tests.

## 7. Dev org human steps

Building happens in the Developer Edition org (alias `ada-dev`, same org as the Dev Hub, D-12).
Once per org (and again if the org is ever reset):

1. Self-org Tooling API access:
   1. `scripts/setup-self-tooling.sh <org> --callback` prints the callback URL.
   2. In the org create an External Client App (Setup → External Client App Manager → New) with
      OAuth enabled, that callback URL and scopes `api` and `refresh_token`. Leave PKCE on (it
      is locked on; the provider template sends PKCE). Copy its consumer key and secret.
   3. `scripts/setup-self-tooling.sh <org>` and paste the key and secret at the hidden prompts.
   4. Authorise `ADA_Self_Tooling`: Setup → Named Credentials → External Credentials →
      `ADA Self Tooling` → Principals → `ADA_Tooling_Principal` → Authenticate, as the org admin.
   5. Check: `node scripts/lib/run-apex-markers.mjs --org <org> --file scripts/e2e/tooling-smoke.apex --expect ADA_TOOLING_OK --fail-on ADA_TOOLING_FAIL`.
2. Paste the Groq key and (when needed) the Azure DevOps PAT into their External Credentials.
3. Assign `ADA_Admin` to yourself and `ADA_User` to the demo restricted user.
4. For phase 3: Setup → Deliverability → All email; enable email approval response.

`scripts/setup-dev-org.sh` deploys, seeds and prints this checklist at the end.
