# ADA build progress

Status values: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`, `REOPENED`.
Claude Code updates this file at every step (see `CLAUDE.md`, the build loop).

## Steps

| Step | Title | Tags | Gate | Status | Evidence (log, tests, coverage) |
| --- | --- | --- | --- | --- | --- |
| 0.1 | Accounts and tools | HUMAN | doctor | DONE | doctor PASS, `.verify/20261026-162142-doctor`. Groq key, Azure DevOps and ServiceNow deferred (needed from 1.6 / phase 2). Dev Hub alias `ada-devhub` -> AdminBot username. |
| 0.2 | Project scaffold | | static | DONE | static PASS `.verify/20261027-220419-static` (code-analyzer skipped: no package source yet). `ada-dev` scratch org created by `scripts/new-scratch-org.sh`. CI run 40493548233 green. |
| 0.3 | Demo org and golden set | | unit | DONE | unit PASS `.verify/20261027-222502-unit` on a fresh `ada-dev` built by `scripts/new-scratch-org.sh`; 4 Apex tests pass; no package classes yet so coverage n/a. Golden set: 8 real cases (VALIDATION_RULE x3, FLOW, APEX, DUPLICATE_RULE, REQUIRED_FIELD, ACCESS) + 3 UNKNOWN. CI run 40496190202 green. |
| 1.1 | Data model and settings | security | unit | DONE | unit PASS `.verify/20261027-225529-unit`: 22 Apex tests pass, package coverage 100% (3 classes with executable lines), Code Analyzer clean. CI run 40499960671 green. |
| 1.2 | Self-org Tooling API access | HUMAN, security | unit + smoke | DONE | unit PASS `.verify/20261028-090656-unit` (38 tests, 97.7%, dev org). Smoke PASS in dev org: `ADA_TOOLING_OK: ADA_Demo_CloseDate_Future,ADA_Demo_Close_Reason,ADA_Demo_Large_Deal_Description`. |
| 1.3 | Metadata index | security | e2e | DONE | `.verify/20261028-105900-e2e` |
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

### 1.3 Metadata index
Plan:
- Sources found by probing the dev org: Tooling `ValidationRule` (list has message, object, active, date; formula needs a single-record `Metadata` query), data API `FlowDefinitionView` (object, trigger type, active version id, date; Tooling `Flow` has no trigger fields), Tooling `ApexTrigger` (+ `Body`) and `ApexClass` (`Body`, for handler classes the triggers call). `DuplicateRule` is **not** a Tooling or Apex-SOQL object; it is only readable through the data API (`/services/data/vNN/query`), so `ADA_ToolingClient` gains `queryData`.
- Pure helpers first (tests first): `ADA_FormulaMasker` (strings -> `TEXT_n`, 15/18-char ids -> `ID_n`), `ADA_MessageNormaliser`, `ADA_ObjectIndexStore` (user mode, implements `ADA_IMetadataIndexStore`).
- `ADA_MetadataIndexer`: `discover()` (list callouts, then DML of list-only rows, stale deletes) returns the work items whose source date changed; `runChunk(items, budget)` does one metadata callout per item up to a budget, then DML. Required-field rows come from Schema describe (no callout).
- `ADA_MetadataIndexJob` (Queueable + Schedulable): first run discovers, every run processes a chunk and chains the rest through a test-replaceable enqueuer. `runNow()` / `schedule()` for the manual and nightly paths.
- Tests: masker, normaliser, store (runAs ADA_User), indexer with router mock (150 rules split in chunks of 70 across two limit contexts, never over budget; second run with nothing changed makes zero metadata callouts; stale rows removed), job (enqueue, schedule, 401 aborts).
- `scripts/e2e/index-smoke-*.apex` (markers `ADA_INDEX_OK` / `ADA_INDEX_FAIL`), run through `verify.sh e2e`.
Result: `e2e` PASS, `.verify/20261028-105900-e2e`. 93 Apex tests, 0 failing, package coverage 98.0%, lowest class `ADA_MetadataIndexJob` 95%. The dev org index holds all 3 demo rules, the demo flow, trigger and duplicate rule, plus required-field rows; a second discovery wants zero fetches and writes nothing. Golden set still skipped (needs 1.4).
Deviations / findings:
- Smoke is three files (`index-smoke-1-discover`, `-2-fetch`, `-3-verify`), not one: each stage ends in DML and a callout after DML in the same transaction is rejected. `verify.sh` loops over `index-smoke-*.apex`.
- A class cannot be both `Queueable` and `Schedulable` (`System.enqueueJob` rejects it), so the nightly trigger is the inner class `ADA_MetadataIndexJob.Nightly`.
- Reserved Apex identifiers hit: `trigger`, `inner`, `end`. A parameter named `flow` shadows the `FLOW` constant (Apex is case-insensitive).
- Tests that make callouts call `Test.startTest()` before `System.runAs`; otherwise set-up data counts as uncommitted work and the callout fails.
- Change detection treated `''` and `null` as different, so every nightly run rewrote trigger rows with no messages. Found by the smoke run; fixed with `sameText` and covered by a unit test.
- Managed-package flows have non-ID version ids and no modified date; they are skipped (only unmanaged active record-triggered flows are indexed).
- Page-layout required fields are not in the schema and are not indexed (documented in the class).
Self-review (security; subagent reviewers unavailable): every callout goes through `ADA_ToolingClient` and `ADA_HttpGateway` (`callout:` only); source ids are checked against `[A-Za-z0-9]{15,18}` before they enter dynamic SOQL and class names are escaped; all index SOQL/DML is user mode and the job refuses callers without create/update/delete on the index; formulas are stored masked (`TEXT_n`, `ID_n`) and a test asserts no literal survives; nothing leaves the org apart from metadata queries to the org itself; callouts always precede DML in each transaction and chunks stay under the 100 callout limit with headroom (80).

### Process change 2026-10-28: dev org instead of scratch orgs (D-12)
Human request after repeated scratch-org friction. `ada-dev` is now an alias for the Developer Edition org that is also the Dev Hub (`ada-devhub`); the old scratch org was deleted. `scripts/setup-dev-org.sh` deploys, assigns permission sets and seeds (re-runnable). `verify.sh` `require_org` refuses any org whose `OrganizationType` is not Developer Edition. `unit` PASS against the dev org: `.verify/20261028-090656-unit` (38 tests, 97.7%). Scratch orgs stay only for the optional CI org job and the phase 4 `package` gate. Demo metadata (Case flow and trigger, validation rules, duplicate rule) is now live in the dev org.

### 1.2 Self-org Tooling API access
Plan:
- `ADA_HttpGateway` (minimal now: only `callout:` endpoints allowed; PII last-line check is added in 1.5) is the only class that sends HTTP, so `ADA_ToolingClient` goes through it.
- `ADA_ToolingClient.query(soql)` over `callout:ADA_Self_Tooling`, follows `nextRecordsUrl` (only `/services/data/` paths, page cap), clear errors: 401 -> "Run the ADA setup to reconnect", 400 -> API error message, 5xx, malformed JSON. No `getSessionId`.
- Mocked unit tests: success, paging, 401, 400, 500, malformed JSON, bad next URL, gateway rejects non-Named-Credential endpoints.
- `setup/self-tooling-template/` (outside the package directories): AuthProvider template, External Credential, Named Credential, access permission set, plus `scripts/setup-self-tooling.sh` that takes the connected app key/secret from a hidden prompt (never written to the repo).
- `scripts/e2e/tooling-smoke.apex` prints `ADA_TOOLING_OK|<rule names>` for Opportunity.
- HUMAN: create the connected app, run the script, click Authenticate. Stop there and list exact actions.
Result so far: code and tests done, unit gate PASS (38 tests, 97.7% coverage, lowest class ADA_ToolingClient 96%). Setup deploy validated against ada-dev with dummy key/secret (4 components created, permission set assigned). Smoke PASS after the human Authenticate in the dev org.
Deviations / findings:
- Gateway method is `execute`, not `send`, because the invariant grep `\.send\(` flags every caller.
- ExternalCredential: `parameterGroup` is allowed only on NamedPrincipal/PerUserPrincipal parameters (and Scope), not on the AuthProvider parameter.
- Setup templates live in `setup/` (a non-default package directory, never deployed by the gate or packaged); rendered copies go to git-ignored `setup/rendered/` and are deleted after deploy.
- Dummy-credential AuthProvider blocks a redeploy with a real secret ("Consumer Secret update is not allowed"): delete NamedCredential, ExternalCredential, AuthProvider (in that order) first. `sf project delete source` also deletes the local template files; restore them with `git checkout`.
- External Client Apps lock PKCE on and this org cannot create classic Connected Apps, so the AuthProvider template sets `isPkceEnabled` true (fixes "missing required code challenge").
- The smoke script first queried only Opportunity rules but `ADA_Demo_Close_Reason` is a Case rule; it now queries `ValidationName LIKE 'ADA_Demo%'`.
- `redirect_uri_mismatch` came from the External Client App's callback URL not matching the dev org's; fixed on the app, no code change.
- The first Authenticate attempt targeted a scratch org; the work moved to the dev org (D-12), where the credential must be set up again.
Self-review (security): only `callout:` endpoints pass the gateway; no `getSessionId`; `nextRecordsUrl` must start with `/services/data/`; page cap 25; error messages never echo the response body except the 400 errorCode/message; key/secret come from a hidden prompt or env and never reach the repo.
Reviewers: step-reviewer / security-reviewer unavailable (model 404), self-reviewed.

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
