# ADA build progress

Status values: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`, `REOPENED`.
Claude Code updates this file at every step (see `CLAUDE.md`, the build loop).

## Steps

| Step | Title | Tags | Gate | Status | Evidence (log, tests, coverage) |
| --- | --- | --- | --- | --- | --- |
| 0.1 | Accounts and tools | HUMAN | doctor | DONE | doctor PASS, `.verify/20261026-162142-doctor`. Groq key, Azure DevOps and ServiceNow deferred (needed from 1.6 / phase 2). Dev Hub alias `ada-devhub` -> AdminBot username. |
| 0.2 | Project scaffold | | static | DONE | static PASS `.verify/20261027-220419-static` (code-analyzer skipped: no package source yet). `ada-dev` scratch org created by `scripts/new-scratch-org.sh`. CI run 40493548233 green. |
| 0.3 | Demo org and golden set | | unit | DONE | unit PASS `.verify/20261027-222502-unit` on a fresh `ada-dev` built by `scripts/new-scratch-org.sh`; 4 Apex tests pass; no package classes yet so coverage n/a. Golden set: 8 real cases (VALIDATION_RULE x3, FLOW, APEX, DUPLICATE_RULE, REQUIRED_FIELD, ACCESS) + 3 UNKNOWN. CI run 40496190202 green. |
| 1.1 | Data model and settings | security | unit | TODO | |
| 1.2 | Self-org Tooling API access | HUMAN, security | unit + smoke | TODO | |
| 1.3 | Metadata index | security | e2e | TODO | |
| 1.4 | Classifier and matchers | | e2e | TODO | |
| 1.5 | PII gate, HTTP gateway, payload builders | security | unit | TODO | |
| 1.6 | LLM providers | security | unit (+ live) | TODO | |
| 1.7 | Agent controller and session | security | unit | TODO | |
| 1.8 | Help panel (LWC) | | unit | TODO | |
| 2.1 | Azure DevOps target | security | unit | TODO | |
| 2.2 | Confirm-then-create flow | | e2e + live | TODO | |
| 3.1 | Access checker and allowlist | security | unit | TODO | |
| 3.2 | Approval process | HUMAN | unit + manual | TODO | |
| 3.3 | Request flow end to end | | e2e (+ live) | TODO | |
| 4.1 | Namespace | HUMAN | unit | TODO | |
| 4.2 | Managed package and setup wizard | | package | TODO | |
| 4.3 | Security review readiness | security | package + e2e | TODO | |

## Step notes

<!-- For each step: plan bullets, attempts, deviations, reviewer verdicts. Newest first. -->

### 0.3 Demo org and golden set
Plan:
- All metadata in `demo-app/` only: 3 validation rules, notes field + permission set + group, Case flow with Custom Error, Case trigger + test, Account duplicate rule (custom matching rule), ADA Demo app with utility bar.
- `scripts/e2e/seed.apex` (canary values) and `scripts/e2e/capture-golden.apex` (`Database.insert/update(..., false)`, prints `ADA_GOLDEN|` lines).
- Deploy to `ada-dev`, run `capture-golden.mjs`, add the access case by hand from an Apex test using `System.runAs`.
- Gate `unit`; then CI.

Deviations / findings:
- The platform HTML-escapes `|` as `&#124;` in debug logs and the CLI echoes the submitted source; `extractMarkers` now decodes entities and skips `Execute Anonymous:` lines. Without this no marker is ever found.
- New custom fields are invisible even to the admin until a permission set grants them, so `new-scratch-org.sh` assigns `ADA_Demo_Notes_Editor` before seeding (seed retries up to 4 times for propagation delay and now fails loudly).
- `new-scratch-org.sh` and `verify.sh unit` only deployed when `force-app/` had files; both now deploy whichever of `force-app` / `demo-app` has real files.
- Duplicate rule `sortOrder` is 2 because the standard Account duplicate rule holds 1. Matching rule file must be `Account.matchingRule-meta.xml` with a plain inner fullName.
- Access case wording captured with a `System.runAs` test (`ADA_Demo_AccessErrorTest`): `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY`, "Operation failed due to fields being inaccessible on Sobject Opportunity, check errors on Exception or Result!  fieldNames: ADA_Demo_Internal_Notes__c" (note the double space). The test asserts it exactly, so a platform wording change fails the gate.
- Flow rule is a before-save Custom Error flow, so its message is a `FIELD_CUSTOM_VALIDATION_EXCEPTION` just like validation rules and the trigger; the classifier must tell them apart from the index, not the status code.
- Utility bar uses the stock To Do List component as a placeholder; the ADA help panel replaces it in step 1.8.
- step-reviewer subagent failed again (model 404). Diff self-reviewed; run the reviewer once it works.

### 0.2 Project scaffold
Plan:
- `npm install --save-dev` the dev dependencies from the plan; commit `package-lock.json` (CI's first run failed only because the lock file was missing).
- Add the ESLint config matching the installed `@salesforce/eslint-config-lwc`, scoped to LWC folders.
- Set `sourceApiVersion` to the latest the CLI supports; `chmod +x` scripts.
- Check `sf code-analyzer run --help` flags against `verify.sh`.
- Gate `static`, push, CI green; then `scripts/new-scratch-org.sh` creates `ada-dev`.
Note: first CI run (40273841586) failed with "Dependencies lock file is not found". Expected before this step.
Deviations / findings:
- Local npm 10.9.0 crashes resolving `@salesforce/sfdx-lwc-jest` ("Cannot read properties of null (reading 'edgesOut')"). Installed with `npx -y npm@11` instead (CI uses npm 11). Lock file was produced by npm 11.
- `eslint.config.js` added (flat config, ESLint 9, `configs.recommended` scoped to LWC folders). Checked it fires on `eval` and `debugger` in a temporary LWC (removed afterwards).
- `sourceApiVersion` 65.0 -> 68.0 (latest the Dev Hub reports).
- `verify.sh`: `sfdx-lwc-jest` rejects `--passWithNoTests`, so it is now passed after a second `--`. Intent of the gate unchanged.
- `force-app/` and `demo-app/` did not exist in the repo. Added `.gitkeep` placeholders; `verify.sh` `has_files` and `new-scratch-org.sh` ignore them.
- Code Analyzer flags (`--workspace`, `--rule-selector`, `--severity-threshold`, `--output-file`) match `sf code-analyzer run --help` (plugin 5.16.0). Not exercised until there is package source.
- step-reviewer subagent failed to start (model 404 error from the tool). Diff self-reviewed instead; re-run the reviewer when it works.

## Blockers

<!-- BLOCKED steps: what failed, evidence, options, what the human needs to decide. -->

## Phase log

| Phase | Gate report | Result | Human approval |
| --- | --- | --- | --- |
| 0 | `docs/reports/phase-0.md` | awaiting human approval | |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
