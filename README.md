# ADA: Admin Deflection Agent

A Lightning utility-bar panel that explains Salesforce errors. A user pastes the message they got
("DD-204: Deal Desk check failed (policy RV-7)"), and ADA finds the validation rule, flow or other
component behind it in **your org's own metadata**, then explains in plain English what it checks and
which field to change. Admins get a dashboard of the errors people ask about most.

It is a Salesforce package with no vendor backend, no Agentforce licence and **no record values
leaving the org**.

> **Status: work in progress.** Everything below runs from source in a Developer Edition org or
> sandbox. It is **not on AppExchange yet**: the namespace, managed package and Security Review are
> still ahead (steps 4.1 to 4.3 in [`PROGRESS.md`](PROGRESS.md)). Setup is manual for now, there is no
> install wizard.

## What works today

- Diagnosis of validation rules, required fields, duplicate rules, access errors, flows (custom
  errors and unhandled faults) and Apex trigger messages, matched in Apex, not by the LLM.
- Plain-English explanations that cite the rule or flow they are based on, with a confidence score and
  an honest "not sure" below the threshold (0.8 by default).
- Up to 3 follow-up questions per session.
- Works with **no LLM at all** (Template mode, the default). Optionally connect any OpenAI-compatible
  endpoint for richer explanations.
- Bug reports by email, with a preview of the exact payload before anything is sent.
- An action log and an "ADA Errors and Deflection" dashboard (counts and names only).

Not built yet: email-approved access requests (phase 3), the setup wizard, packaging. The Azure
DevOps target exists and is tested but is not wired to the UI (see D-16 in
[`docs/DECISIONS.md`](docs/DECISIONS.md)).

## What leaves the org

Only metadata and the user's own question, through one class (`ADA_HttpGateway`) and typed payload
builders, with formula literals masked (`TEXT_n`, `ID_n`) and a PII gate on user text. Never field
values, record names or amounts. The full contract is in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) section 4, and every payload is stored in
`ADA_Action_Log__c`. Read the limits of the PII gate in D-15 and D-17 before using it with real data.

## Prerequisites

- A free [Developer Edition org](https://developer.salesforce.com/signup) (the setup script refuses
  other org types, because it deploys metadata and seeds data)
- Node.js LTS and npm
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`npm install --global @salesforce/cli`)
- Git and a bash shell (macOS or Linux; on Windows use WSL)
- Optional, for the static gate: Java 11+, Python 3.10+ and `sf plugins install code-analyzer`
- Optional, for richer explanations: an API key for an OpenAI-compatible provider (the build used
  Groq's free tier). Check the provider's data terms first.

## Install in a Developer Edition org

```bash
git clone https://github.com/amitkarma21/ada.git
cd ada
npm install
sf org login web --alias ada-dev
```

**1. Deploy and seed.** This deploys `force-app` (the package) and `demo-app` (demo rules, flow,
trigger, fields, the "ADA Demo" app), assigns `ADA_Admin` and `ADA_Demo_Notes_Editor` to you and
seeds demo data. It is safe to run again.

```bash
scripts/setup-dev-org.sh ada-dev
sf org assign permset --name ADA_Demo_Deal_Desk --target-org ada-dev
```

**2. Give ADA read access to your org's metadata (once per org).** ADA reads rules and flows through
the Tooling API, using a Named Credential that points back at the same org.

1. `scripts/setup-self-tooling.sh ada-dev --callback` prints a callback URL.
2. In Setup, open External Client App Manager and create an app with OAuth enabled, that callback URL,
   and scopes `api` and `refresh_token`. Leave PKCE on. Copy its consumer key and secret.
3. `scripts/setup-self-tooling.sh ada-dev` and paste the key and secret at the hidden prompts. They
   go into the org, never into a file in this repo.
4. Setup, Named Credentials, External Credentials, `ADA Self Tooling`, Principals,
   `ADA_Tooling_Principal`, Authenticate (as an admin).

**3. Build the metadata index.** In the Developer Console, Execute Anonymous:

```apex
ADA_MetadataIndexJob.runNow();
// optional nightly refresh:
// System.schedule(ADA_MetadataIndexJob.SCHEDULE_NAME, ADA_MetadataIndexJob.NIGHTLY_CRON, new ADA_MetadataIndexJob.Nightly());
```

When the queueable chain finishes, `SELECT COUNT() FROM ADA_Metadata_Index__c` should be greater
than zero. Re-run it after you add or change validation rules or flows.

**4. (Optional) Connect an LLM.** Skip this and ADA answers from templates.

```bash
ADA_LLM_MODEL=<model id from your provider> scripts/setup-llm.sh ada-dev
# other providers: ADA_LLM_BASE_URL=https://your-provider/v1 ADA_LLM_MODEL=... scripts/setup-llm.sh ada-dev
```

Then paste the API key in Setup, External Credentials, `ADA LLM`, Principals, `ADA_LLM_Principal`, as
an authentication parameter named `ApiKey`. The key is never passed to a script.

**5. Open it.** Switch to the **ADA Demo** app and click **ADA Help** in the utility bar. To use ADA
outside the demo app, add the `adaHelpPanel` component to your own app's utility bar and assign the
`ADA_User` permission set to your users (`ADA_Analytics` for the dashboard audience).

## Reproduce the demo from the video

The Deal Desk scenario lives in `demo-app/`: a validation rule `ADA_Demo_Deal_Desk_Gate` that hides
two checks behind one error code.

1. Make sure step 3 has been run after the deploy, so the rule is indexed.
2. Create an Opportunity: Amount `62000`, Discount (%) `25`, Deal Desk Approval Ref `DD-APR-4471`,
   Description empty, any open stage. (The page layout and the `ADA_Demo_Deal_Desk` permission set
   make the two custom fields visible.)
3. Change the Stage to **Closed Won** and save. You get `DD-204: Deal Desk check failed (policy RV-7).`
4. Open **ADA Help**, paste the message, click **Diagnose**, then ask "I have the approval reference
   already, so what else could block closing this deal?".
5. Add a Description and save again: the deal closes.

Template mode explains the rule from its message and, where it can parse it, its formula. With an LLM connected the wording is richer.

## Run the tests

```bash
npm install
npm run test:unit            # Lightning Web Component Jest tests, no org needed
npm run verify:static        # formatting, lint, Jest, invariant checks, Code Analyzer
npm run verify:unit          # static + deploy + all Apex tests + coverage (uses org alias ada-dev)
npm run verify:e2e           # unit + golden set of captured real errors
```

Set `ADA_ORG` to use a different org alias. The `e2e` gate resets the LLM setting to Template, so run
`scripts/setup-llm.sh` again afterwards if you were using a model. Evidence for every step is in
[`PROGRESS.md`](PROGRESS.md) (372 Apex tests, 97% coverage, 14 golden cases, 53 Jest tests at the
last step).

## Repository layout

| Path                      | What it is                                                               |
| ------------------------- | ------------------------------------------------------------------------ |
| `force-app/main/default/` | The package: Apex (`ADA_*`), LWCs, objects, permission sets, reports     |
| `demo-app/main/default/`  | Unpackaged demo: validation rules, flow, trigger, fields, "ADA Demo" app |
| `setup/`                  | Templates for the Named Credentials, rendered by the setup scripts       |
| `scripts/`                | Setup scripts and the `verify.sh` quality gates                          |
| `test-data/`              | Golden set of real error messages and the egress canary values           |
| `docs/`                   | Architecture, decisions, plan, test strategy, setup notes                |
| `.claude/`, `CLAUDE.md`   | The rules and skills used to build this step by step with Claude Code    |

## How it was built

Step by step with Claude Code, with a test gate after every step and evidence recorded in
[`PROGRESS.md`](PROGRESS.md). [`CLAUDE.md`](CLAUDE.md) holds the invariants the build must never
break (no record values out, one gateway for HTTP, callouts only through Named Credentials).
[`docs/DECISIONS.md`](docs/DECISIONS.md) records each design decision with its reasoning.

## Known limits

- The PII gate scrubs patterns and Account and Contact names, not every kind of free text.
- Masked formulas still show the structure of your business rules to the LLM. Use Template mode if
  that is confidential.
- Errors built at runtime inside Apex or a managed package, with no matching message in metadata, come
  back as "not sure". That is deliberate.
- Free LLM tiers have rate limits and terms that change.
