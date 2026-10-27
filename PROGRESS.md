# ADA build progress

Status values: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`, `REOPENED`.
Claude Code updates this file at every step (see `CLAUDE.md`, the build loop).

## Steps

| Step | Title | Tags | Gate | Status | Evidence (log, tests, coverage) |
| --- | --- | --- | --- | --- | --- |
| 0.1 | Accounts and tools | HUMAN | doctor | DONE | doctor PASS, `.verify/20261026-162142-doctor`. Groq key, Azure DevOps and ServiceNow deferred (needed from 1.6 / phase 2). Dev Hub alias `ada-devhub` -> AdminBot username. |
| 0.2 | Project scaffold | | static | DONE | static PASS `.verify/20261027-220419-static` (code-analyzer skipped: no package source yet). `ada-dev` scratch org created by `scripts/new-scratch-org.sh`. CI run 40493548233 green. |
| 0.3 | Demo org and golden set | | unit | DONE | unit PASS `.verify/20261027-222502-unit` on a fresh `ada-dev` built by `scripts/new-scratch-org.sh`; 4 Apex tests pass; no package classes yet so coverage n/a. Golden set: 8 real cases (VALIDATION_RULE x3, FLOW, APEX, DUPLICATE_RULE, REQUIRED_FIELD, ACCESS) + 3 UNKNOWN. CI run 40496190202 green. |
| 1.1 | Data model and settings | security | unit | DONE | unit PASS `.verify/20261027-225529-unit`: 22 Apex tests pass, package coverage 100% (3 classes with executable lines), Code Analyzer clean. |
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

### 1.1 Data model and settings
Result: DONE. Objects, fields, three CMDTs (+ `Default` setting record, Template provider), `ADA_User` / `ADA_Admin` permission sets, enums `ADA_ErrorType` / `ADA_SuggestedAction`, DTOs `ADA_Diagnosis` / `ADA_Explanation` / `ADA_ActionResult`, interfaces `ADA_ILlmProvider` / `ADA_IMetadataIndexStore` / `ADA_IActionTarget`. Tests: `ADA_PermissionsTest` (runAs), `ADA_SchemaTest` (index holds only the ARCHITECTURE §1 fields, no lookups, idempotency key unique), `ADA_SettingTest`, `ADA_DtoTest`.
Deviations / findings:
- Tests were written after the metadata was generated, not before (generator output deployed first to flush out metadata errors). Tests then drove the fixes below.
- Objects: sharing, bulk API and streaming API must be enabled together, so all three are on (sharing is needed for Private OWD). Index OWD is `Read`.
- Permission set elements of one type must be contiguous (duplicate `objectPermissions` error).
- CMDT access in a permission set is `customMetadataTypeAccesses`; `objectPermissions` on `__mdt` is silently dropped, and the first `adminSeesEverythingAndManagesIt` run proved it (settings not accessible to the admin).
- `Database.insert(..., AccessLevel.USER_MODE)` without create permission throws `System.TypeException` ("DML operation INSERT not allowed"), not `DmlException`.
- `check-coverage.mjs` counted enums/interfaces (0 executable lines) as 0% and failed the per-class minimum; types with `totalLines` 0 are now skipped. Thresholds unchanged.
- Property declarations with `{ get; set; }` count as lines; the DTO test exercises them.
- Package source may not contain `ADA_Demo` or a literal URL, even in tests (invariant checks).
- Reviewers: step-reviewer / security-reviewer not available through the Task tool (model 404 again). Self-review for the security tag:
  - Logs and requests are Private OWD; `ADA_User` can create and read own, cannot edit or delete logs, cannot set Status / Approver / ServiceNow fields on a request (field-level, tested). `ADA_Admin` has view/modify all and CMDT access (tested).
  - Index is read-only to `ADA_User` (create/update/delete denied, tested) and holds no record data fields (tested).
  - Open point for 1.7: `ADA_User` can create log rows directly, so a user could forge audit rows via API. `ADA_ActionLogger` should write logs and the object-level create permission should then be removed from `ADA_User`.
  - Open point for 3.1: `Justification__c` must pass the PII gate before insert.
- CLAUDE.md gained an "Environment notes" section with the commands and quirks needed on this machine.

Plan:
- Objects `ADA_Metadata_Index__c`, `ADA_Action_Log__c`, `ADA_Access_Request__c` (logs and requests Private OWD, index Read) with the ARCHITECTURE §1 fields; CMDTs `ADA_Setting__mdt` (+ `Default` record, Template), `ADA_Allowed_Permission__mdt`, `ADA_Pii_Pattern__mdt`.
- Permission sets `ADA_User` (create logs/requests, read own, read index; no CMDT access) and `ADA_Admin` (full CRUD, view/modify all, read CMDTs). `ADA_User` gets read-only on Status/Approver/ServiceNow fields of access requests so users can't approve themselves.
- Apex: `ADA_ErrorType`, `ADA_SuggestedAction` enums; DTOs `ADA_Diagnosis`, `ADA_Explanation`, `ADA_ActionResult`; interfaces `ADA_ILlmProvider`, `ADA_IMetadataIndexStore`, `ADA_IActionTarget`.
- Tests first: `ADA_PermissionsTest` (runAs), `ADA_SchemaTest` (index has only the listed fields, no lookups), `ADA_SettingTest`, DTO tests.
- Gate `unit`, then step-reviewer + security-reviewer, CI.

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
| 0 | `docs/reports/phase-0.md` | PASS | "go" (2026-10-27) |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
