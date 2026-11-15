# ADA build progress

Status values: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`, `REOPENED`.
Claude Code updates this file at every step (see `CLAUDE.md`, the build loop).

## Steps

| Step  | Title                                    | Tags            | Gate          | Status | Evidence (log, tests, coverage)                                                                                                                                                                                                                                                                          |
| ----- | ---------------------------------------- | --------------- | ------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0.1   | Accounts and tools                       | HUMAN           | doctor        | DONE   | doctor PASS, `.verify/20261026-162142-doctor`. Groq key, Azure DevOps and ServiceNow deferred (needed from 1.6 / phase 2). Dev Hub alias `ada-devhub` -> AdminBot username.                                                                                                                              |
| 0.2   | Project scaffold                         |                 | static        | DONE   | static PASS `.verify/20261027-220419-static` (code-analyzer skipped: no package source yet). `ada-dev` scratch org created by `scripts/new-scratch-org.sh`. CI run 40493548233 green.                                                                                                                    |
| 0.3   | Demo org and golden set                  |                 | unit          | DONE   | unit PASS `.verify/20261027-222502-unit` on a fresh `ada-dev` built by `scripts/new-scratch-org.sh`; 4 Apex tests pass; no package classes yet so coverage n/a. Golden set: 8 real cases (VALIDATION_RULE x3, FLOW, APEX, DUPLICATE_RULE, REQUIRED_FIELD, ACCESS) + 3 UNKNOWN. CI run 40496190202 green. |
| 1.1   | Data model and settings                  | security        | unit          | DONE   | unit PASS `.verify/20261027-225529-unit`: 22 Apex tests pass, package coverage 100% (3 classes with executable lines), Code Analyzer clean. CI run 40499960671 green.                                                                                                                                    |
| 1.2   | Self-org Tooling API access              | HUMAN, security | unit + smoke  | DONE   | unit PASS `.verify/20261028-090656-unit` (38 tests, 97.7%, dev org). Smoke PASS in dev org: `ADA_TOOLING_OK: ADA_Demo_CloseDate_Future,ADA_Demo_Close_Reason,ADA_Demo_Large_Deal_Description`.                                                                                                           |
| 1.3   | Metadata index                           | security        | e2e           | DONE   | `.verify/20261028-105900-e2e`                                                                                                                                                                                                                                                                            |
| 1.4   | Classifier and matchers                  |                 | e2e           | DONE   | `.verify/20261031-171625-e2e`                                                                                                                                                                                                                                                                            |
| 1.5   | PII gate, HTTP gateway, payload builders | security        | unit          | DONE   | `.verify/20261031-184350-unit`                                                                                                                                                                                                                                                                           |
| 1.6   | LLM providers                            | security        | unit (+ live) | DONE   | unit `.verify/20261031-192535-unit`; live PASS `.verify/20261031-195113-live`                                                                                                                                                                                                                            |
| 1.7   | Agent controller and session             | security        | unit          | DONE   | `.verify/20261101-174416-unit`                                                                                                                                                                                                                                                                           |
| 1.8   | Help panel (LWC)                         |                 | unit          | DONE   | unit PASS `.verify/20261101-235419-unit`; explanation quality improved (D-14). Human ran the demo in the dev org and said the answer is better (2026-11-04); further improvements to follow.                                                                                                             |
| 2.1   | Azure DevOps target                      | security        | unit          | DONE   | unit PASS `.verify/20261104-203113-unit` (294 tests, 97.1%). No real Azure DevOps call yet; that needs the human's org, project and token (see note).                                                                                                                                                    |
| 2.2   | Confirm-then-create flow                 |                 | e2e           | DONE   | e2e PASS `.verify/20261104-210830-e2e` (317 Apex tests, 97.1%, golden 11/11, Jest 45). Bug report goes by email (D-16); not yet sent to a real inbox (needs the human's address, see note).                                                                                                              |
| 2.5.1 | Flow fault matching                      |                 | e2e           | DONE   | e2e PASS `.verify/20261105-212332-e2e` (334 Apex tests, 97.2%, golden 14/14, Jest 45).                                                                                                                                                                                                                   |
| 2.5.2 | Flow explainer                           | security        | e2e           | DONE   | e2e PASS `.verify/20261106-211656-e2e` (354 Apex tests, 97.0%, golden 14/14).                                                                                                                                                                                                                            |
| 2.5.3 | Error dashboard                          |                 | e2e           | DONE   | e2e PASS `.verify/20261106-214308-e2e` (354 Apex tests, 97.0%, golden 14/14).                                                                                                                                                                                                                            |
| 2.6.1 | Unknown-error queue                      | security        | e2e           | DONE   | e2e `.verify/20261115-134233-e2e` PASS (366 Apex tests, 97.0%, golden 14/14). Anonymous `Error_Sample__c` on not-confident rows only, owner and admin read, none for analytics; admin list view and report; static check 9; D-17                                                                         |
| 2.6.2 | Cited answers                            |                 | e2e           | DONE   | e2e PASS `.verify/20261115-135106-e2e` (366 Apex tests, 97.0%, golden 14/14, Jest 47). `ExplanationView.sources` (rule or flow, object, last changed) on both paths, shown as "Based on" in the card.                                                                                                    |
| 2.6.3 | Follow-up questions                      | security        | e2e           | DONE   | e2e PASS `.verify/20261115-141048-e2e` (372 Apex tests, 97.0%, golden 14/14, Jest 53). `askFollowUp`: question through the builder and PII gate, max 3 per session, each logged as step `FollowUp`; Template says ask your admin. No new field in the LLM body.                                          |
| 3.1   | Access checker and allowlist             | security        | unit          | TODO   |                                                                                                                                                                                                                                                                                                          |
| 3.2   | Approval process                         | HUMAN           | unit + manual | TODO   |                                                                                                                                                                                                                                                                                                          |
| 3.3   | Request flow end to end                  |                 | e2e (+ live)  | TODO   |                                                                                                                                                                                                                                                                                                          |
| 4.1   | Namespace                                | HUMAN           | unit          | TODO   |                                                                                                                                                                                                                                                                                                          |
| 4.2   | Managed package and setup wizard         |                 | package       | TODO   |                                                                                                                                                                                                                                                                                                          |
| 4.3   | Security review readiness                | security        | package + e2e | TODO   |                                                                                                                                                                                                                                                                                                          |

## Step notes

<!-- For each step: plan bullets, attempts, deviations, reviewer verdicts. Newest first. -->

### 2.5.3 Error dashboard

- Plan: tests first (log carries the object; analytics permission set sees all rows but no payloads), then fields, reports, dashboard.
- Built: `ADA_Action_Log__c` gets `Object_Api_Name__c` (set by `ADA_AgentController.entryFor`) and three formula counts (`Asked_Count__c`, `Solved_Count__c`, `Unknown_Count__c`). Report type `ADA_Action_Logs` lists only metadata columns (no payload, result, link or key columns). Four reports in folder `ADA Reports`: top errors by component, errors by object, errors by week, and deflection/unknown rate by week (solved over asked, unknown over asked). Dashboard `ADA Errors and Deflection` in folder `ADA Dashboards`.
- Access: new permission set `ADA_Analytics` (read all log rows, metadata fields only, Run Reports). `ADA_User` and `ADA_Admin` get the new object field.
- Invariant: new static check 8 fails the gate if a report, report type or dashboard names a payload, result, link, session or key column.
- Gotchas: reports on a custom report type use `ADA_Action_Logs__c`, `Object$Field` columns and `Object.Field:SUM` in summary formulas; the dashboard needs `autoselectColumnsFromReport=false`, `axisBinding`, and indicator colours on metrics.
- Gate note: ran e2e with the live LLM setting in the org first (ADA_SettingTest); redeployed the default and passed. Review: reviewer subagents unavailable; self-review (only counts and API names are reported).
- Slice 1 complete. Stopping for human review. Demo: paste a flow fault, see the flow named and explained; open the ADA Errors and Deflection dashboard.

### 2.5.2 Flow explainer

- Plan: tests first (`ADA_FlowOutlineTest`, 17 tests), then the outline reader, indexer, payload, template and prompt.
- Built: `ADA_FlowOutline` reads a flow's start element (trigger type, create/update/delete, filters, filter logic) into plain words (`Flow_Runs_When__c`) and a masked entry condition (`Formula_Masked__c`, written with `&&`/`||` so `ADA_FormulaReader` can describe it). Literals go through `ADA_FormulaMasker`; no filter value is stored.
- Re-index: a Flow row with a blank `Flow_Runs_When__c` is queued again, so flows indexed before this step are filled in on the next run.
- LLM contract: new field `flowRunsWhen` (pattern-scrubbed, clipped); `ARCHITECTURE` section 4, `ALLOWED`/`CONTRACT` sets and the canary extras updated together. The cache `VERSION` is now 3.
- Run-time faults: `ADA_Diagnosis.runtimeFault` (kept in the session snapshot). For a fault the flow's own custom messages are not quoted, since they do not apply; the template says the flow hit an error and suggests a report to the admin team.
- Template: `ADA_TemplateProvider.flow` states when the flow runs and what it needs to start.
- Prompt: new "How to read a flow" paragraph.
- Gate note: the first e2e run failed on three tests (schema allow-list, a query missing the new field, a DML-then-callout in a new test); fixed. Review: reviewer subagents unavailable (404); manual self-review (the new field holds metadata only).

### 2.5.1 Flow fault matching

- Plan: tests first (`ADA_FlowErrorMatcherTest`, 16 tests), then the matcher, then three golden cases.
- Built: `ADA_FlowErrorMatcher` still matches a flow's own custom error against the index first. If that is not a near-exact match and the message uses Salesforce's flow-fault wording (unhandled fault, `FLOW_ELEMENT_ERROR`, "error element X (FlowRecordUpdate)", "the flow tried to/failed to", "flow interview", "flow API name"), it answers FLOW at 0.9.
- Naming the flow: only by API name (whole token) or a label of two or more words, active flows only; the longer name wins and a tie names nothing.
- The failing step's name and kind go into the description; nothing after the step in the message is copied (it can hold record values).
- Golden: added `case-flow-fault-unhandled`, `case-flow-fault-named-step`, `unknown-flow-word-1` ("Cash flow must be positive." stays UNKNOWN).
- Gate note: the first e2e run failed only because the org still had the live LLM setting (`ADA_SettingTest` expects Template); redeploying the default setting fixed it.

### 2.2 Confirm-then-create flow (email, D-16)

- Change of plan: the user chose email over Azure DevOps for "raise a bug" (D-16). The Azure DevOps target (2.1) stays built and tested but is not wired in. The plan's `live` gate for 2.2 is replaced by `e2e` because a live send needs the human's address.
- Plan: tests first for each piece. `ADA_EmailTarget` (13 tests), `ADA_ActionLogger.findSuccess`, `proposeAction` with notes and `confirmAction` in `ADA_AgentController`, then LWC `adaActionPreview` and the help panel, then the egress canary.
- Built: one plain-text email to `Bug_Report_Email__c`; the recipient is not user-controlled; the subject is one line (no header injection); the PII check runs on subject and body before sending and a hit is Blocked with kinds only. Idempotency key `<session>:RAISE_BUG`: a second confirm returns "already sent". Only a success stores the key, so a failed send can be retried.
- LWC: `adaActionPreview` shows the exact report, a notes box (2000 chars), "Update preview" and "Send to my admin team". Confirm is disabled while the notes differ from the preview, while busy, and after a success. Server text is shown as text only.
- Finding: a session key that began with digits could match the phone pattern and block a report. `ADA_AgentSession.newKey()` now always starts with a letter (test added).
- Invariant check: the `.send(` grep flagged the email `Sender.send`; the interface method is now `deliver` (the invariant is unchanged).
- Review: reviewer subagents unavailable (404); manual security self-review (recipient fixed, no record values in the body, canary tests for the email path green).
- Limits: no dedupe by rule and no link back in the report (D-16). Needs Deliverability = All email.
- HUMAN to do: `ADA_BUG_EMAIL=you@example.com scripts/setup-bug-email.sh ada-dev`, set Setup > Email > Deliverability to All email, then try the panel on a "not sure" error.

### 2.1 Azure DevOps target

- Plan: tests first (`ADA_AzureDevOpsTargetTest`, 16 tests, with `ADA_AdoTestSupport`), then `ADA_AzureDevOpsTarget`, then the ADO path in the egress canary.
- Built: WIQL search on the tag `ADA-rule:<api name>` limited to open items (a hit links the existing item), then a JSON Patch create. Errors 401/203, 403, 404, 429, 400 and other statuses give plain messages; server text is never echoed. Notes are HTML-escaped (`<script>` is neutralised). Returned links must be `https://`. A rule name outside `[A-Za-z0-9_]{1,80}` is refused before any callout.
- Credential: Basic-auth External Credential, token pasted by the human (D-15). `scripts/setup-ado.sh` renders `setup/ado-template`, writes the ADO settings, keeps the org's LLM settings and assigns `ADA_ADO_Access`. Dry run validated 4 components against ada-dev; not deployed.
- Finding: the PII gate does not recognise record names other than Account and Contact (for example an Opportunity name typed into notes). This is a known limit (D-15); the control is the payload preview in 2.2.
- Static gate: the invariant check flagged URL literals and an `ADA_Demo` name in test support; fixed by renaming and by the `ada-allow-url` marker on https scheme checks and test fixtures. Code Analyzer flagged an empty catch block; restructured.
- Review: the reviewer subagents are unavailable (404), so a manual security self-review was done (callouts only through the gateway, no secrets, no record values in payloads, canary green).
- HUMAN for the live check in 2.2: create an Azure DevOps org, a test project and a token (Work Items read and write), run `scripts/setup-ado.sh`, then paste the token into the `ADA_AzureDevOps_Principal` (Username `ada`, Password = the token).

### 1.8 Help panel (LWC)

Plan:

- `adaHelpPanel` (container, owns state and Apex calls) and `adaDiagnosisCard` (presentation only). States: idle, diagnosing, explained, lowConfidence, error. Flow: paste error, "Diagnose" calls `diagnose`, then `explain` runs straight away when confident; low confidence shows the "not sure" text and a "Prepare a report for my admin" button that calls `proposeAction('RAISE_BUG')` and shows the payload preview (confirm and create come in 2.2). Feedback buttons call `recordFeedback` once.
- Record id: `@api recordId` (record pages) else `CurrentPageReference` `attributes.recordId` (utility bar). All server text (summary, steps, headline, errors) is bound with `{}` into text nodes, never `lwc:dom="manual"` / `innerHTML`.
- Accessibility: labelled textarea, native buttons (keyboard), `role="alert"` for errors, `aria-live="polite"` status region, card as a labelled region, focus returns to the result heading.
- Finding while reading: `ADA_User` / `ADA_Admin` have no Apex class access, so the panel could not call the controller. Add `classAccesses` for `ADA_AgentController` to both and test it through `SetupEntityAccess`.
- Utility bar in `demo-app` gets `c:adaHelpPanel` in place of the stock To Do List. `docs/reports/demo-phase-1.md` has the manual checklist.
- Tests first (Jest): each state, labels, keyboard (Enter/Space activation via native button click, focus), double-click guard, one feedback only, error from Apex, XSS string rendered as text, no `img` in the DOM.
  Result: unit PASS, `.verify/20261101-202524-unit`. 255 Apex tests, 0 failing, package coverage 97.9%, lowest class `ADA_ExplanationService` 92%; 27 Jest tests (2 suites) pass; ESLint and Prettier clean. NOT yet DONE: the acceptance criterion "manual demo passes in the dev org" needs the human to run `docs/reports/demo-phase-1.md` (the gate redeployed the panel and utility bar to `ada-dev`).
  Explanation quality (demo feedback, D-14): the first demo answer was generic. Template ignored `extras` and the LLM payload had no rule message. Now `ADA_FormulaReader` turns the masked condition into plain-English conditions and field-specific fixes (never inventing masked values; unreadable parts say "another condition set by your admin"), `ADA_TemplateProvider` quotes the rule message and describes the condition (all / any / one), `ruleMessage` joins the LLM body (PII-scrubbed, clipped, documented in ARCHITECTURE §4), the prompt was rewritten for business users, and `ADA_ExplanationCache` carries a VERSION so old answers are misses. Result: unit PASS `.verify/20261101-235419-unit`, 277 Apex tests, 0 failing, coverage 97.2%, lowest class `ADA_ExplanationService` 92%. Live Groq (`openai/gpt-oss-120b`, `scripts/e2e/live-llm.apex` now sends the rule message): all three rules gave specific answers, e.g. "an open opportunity cannot have a Close Date earlier than today... Set the Close Date to today or a future date. / If the opportunity should be closed, change its stage..." The full `live` gate stalled twice at RunLocalTests (empty `apex-tests.json`, org-side queue), so the live script was run directly; the unit part of that gate had passed.
  Deviations / findings:
- Jest tests sit inside the component folders, and deploy rejected them (`LWC1702` on `createElement`, `LWC1503` on `CurrentPageReference`). The repo had no `.forceignore`; added one excluding `**/__tests__/**` (also keeps tests out of the managed package).
- ESLint `@lwc/lwc/no-async-operation` and `no-unexpected-wire-adapter-usages` are turned off for `__tests__` only (the tests use `setTimeout` to flush promises and `CurrentPageReference.emit`). Component code keeps both rules. No test was weakened; Prettier only reformatted the test files.
- Utility bar item: LWC properties must be `<type>decorator</type>`; `icon` and `label` are accepted, `panelBodyHeight` / `panelBodyWidth` are rejected for an LWC (found by four deploy attempts, so past the three-attempt rule; each had a different cause and the last was settled from the docs). The panel uses the default utility panel size.
- Card shows the report button only for low confidence (plan); a confident answer offers feedback only. `proposeAction` sends only the session key and `RAISE_BUG`; the preview is the server's `payloadJson` rendered in a `<pre>` text node.
- Focus moves to the result heading through `focusHeading()` after the diagnosis is rendered (`renderedCallback`), not asserted in Jest beyond the `tabindex="-1"` heading.
- Self-review (reviewers unavailable): no `innerHTML`, `lwc:dom`, `eval` in component code; all server text bound as text nodes; the client sends only the record id, error text, session key, action name and feedback flag; errors shown are the controller's `AuraHandledException` message or a fixed generic string (raw error objects are never shown).

### 1.7 Agent controller and session

Plan:

- `ADA_ActionLogger`: the only writer of `ADA_Action_Log__c`. Inner `without sharing` writer inserts in system mode (owner = the running user), so `ADA_User` loses object-level create on the log (closes the 1.2 open point: no forged audit rows through the API). `ADA_PermissionsTest` is reworked to write through the logger. An entry with an idempotency key returns the existing row instead of inserting again (feedback double click).
- `ADA_AgentSession`: server-side state. The `Diagnose` row holds a snapshot of the diagnosis (no error text, no record values) in `Result__c`; `load(key)` reads it in user mode with an `OwnerId = UserInfo.getUserId()` filter, so another user (even an admin with view-all) gets "session not found". Keys are random 128-bit hex. The client only ever sends the key.
- `ADA_AgentController` (`@AuraEnabled`, each call is its own transaction): `diagnose(errorText, recordId)` (no callout; blank text rejected, object from the record id prefix), `explain(sessionKey, userQuestion)` (session reload, extras from the index row and Schema labels, `ADA_ExplanationService`, then log; low confidence short-circuits to the "not sure" answer with no callout), `proposeAction(sessionKey, actionType)` (no callout; payload from `ADA_PayloadBuilder.forWorkItem`; logs `Propose`), `recordFeedback(sessionKey, solved)`. Low confidence offers only `RAISE_BUG`.
- Explain log row: `Target_System__c = LLM` and `Payload_Sent__c` = the exact body when a call was made; `Status__c` Success / Fallback / Blocked; blocked kinds and fallback reason go in `Result__c`.
- Scope decisions: `REQUEST_ACCESS` is not offered until 3.1 (nothing to propose yet); the work-item payload carries no error text (the user's own notes, PII-gated, join it at confirm in 2.2), so nothing rendered by the platform is ever stored or sent.
- Tests first: logger, session (two-user), controller full path with mocks (diagnose, startTest, explain, propose, feedback), low confidence, blocked and fallback rows, forged key and forged client state, payload builder for work items, egress canary extended.
  Result: unit PASS, `.verify/20261101-174416-unit`. 254 Apex tests, 0 failing, package coverage 97.9%, lowest class `ADA_ExplanationService` 92%.
  Deviations / findings:
- Session state is the snapshot in the `Diagnose` row's `Result__c` (diagnosis fields only, no error text), read in user mode with an owner filter; an admin with view-all still gets "Session not found" (tested). Keys are 128-bit random hex; anything else is rejected before SOQL.
- `ADA_User` no longer has create on `ADA_Action_Log__c` (and log fields are read-only): rows come only from `ADA_ActionLogger` (system-mode inner writer, row owned by the caller). A direct insert is denied (tested). Closes the 1.2 open point.
- Feedback is idempotent per session (`<key>:Feedback`); a second click returns the first row.
- `proposeAction` accepts only `RAISE_BUG` for now; the payload (`ADA_PayloadBuilder.forWorkItem`) holds title, description (metadata, confidence, session) and tags, no error text. User notes join at confirm (2.2) and are PII-scrubbed in the builder already.
- Callout-before-DML in tests: `diagnose` writes a row, so tests call `explain` inside `Test.startTest()` (separate transaction, as with real LWC calls). In production each call is its own transaction; `explain` makes its callout before the log insert.
- Apex: a parameter named `json` shadows the `JSON` class; renamed `stored`.
- Not done: the egress canary was not extended with a controller flow; `explain` goes through `ADA_ExplanationService`, already canary-tested, and the controller tests assert the scrubbed question and logged body. Revisit in 2.2 when confirm is added.
- Reviewers unavailable; self-review: all SOQL user mode except the logger's owner-scoped idempotency lookup and insert (system mode by design, scoped to the caller, no user-supplied values besides the key as a bind); the client sends only a key, question and action name, each validated server-side; LLM text never drives actions.

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

### 1.6 LLM providers

Plan:

- `ADA_ILlmProvider.explain(diagnosis, extras)` (extras carry the masked formula, labels and question the diagnosis does not hold) and `lastPayload()` (the exact body sent, for the `Explain` log row in 1.7). Implementations: `ADA_TemplateProvider` (deterministic text per error type, default and fallback) and `ADA_OpenAiCompatibleProvider` (`POST callout:ADA_LLM/chat/completions`, temperature 0, token cap, JSON mode, timeout from settings).
- `ADA_PromptBuilder`: system prompt in static resource `ADA_Explain_Prompt` (built-in constant if the resource is missing); the user message is exactly `ADA_PayloadBuilder.toJson(forLlm(...))`. Snapshot test: user message keys equal the contract fields.
- `ADA_LlmResponseValidator`: strict parse of the OpenAI envelope and of `{explanation <= 1200, fixSteps <= 5, suggestedAction in NONE|RAISE_BUG|REQUEST_ACCESS}`; extra or missing fields, wrong types, links and over-length text are rejected. The model's suggested action is advisory; the controller never acts on it.
- `ADA_ExplanationCache`: two new fields on `ADA_Metadata_Index__c` (`Explanation_Json__c`, `Explained_For__c`), valid only while `Explained_For__c = Source_Last_Modified__c` and the locale matches. Skipped when the user typed a question. The write is system mode (shared metadata-derived text, two fields only) because end users cannot edit the index.
- `ADA_LlmProviderFactory` (reads `ADA_Setting__mdt` Default; Template unless `OpenAICompatible` with a model) and `ADA_ExplanationService.explain` (cache, provider, validate, otherwise Template; returns an `Outcome` with the explanation, payload sent, cached flag, fallback reason, blocked kinds).
- Named Credential decision (D-13): one `ADA_LLM` credential created at setup from `setup/llm-template` (base URL chosen at setup) rather than one per provider. `scripts/setup-llm.sh` deploys it and sets provider + model; the human pastes the API key into the principal.
- Egress canary test gains the explain flow. Live smoke `scripts/e2e/live-llm.apex` (three golden cases).
- Verify with `unit`; `live` needs the Groq key.
  Result: `unit` PASS, `.verify/20261031-192535-unit`. 222 Apex tests, 0 failing, package coverage 98.2% across 32 classes, lowest class `ADA_ExplanationService` 92%. Code Analyzer clean. Egress canary now also covers explain (no canary in the model request; the logged payload is the scrubbed body). Live smoke not run: needs the Groq key (see below).
  Deviations / findings (self-review; reviewers unavailable):
- `ADA_ILlmProvider.explain` takes `(diagnosis, extras)` and adds `lastPayload()` (the exact body sent, for the Explain log row in 1.7). `ADA_Explanation` gained `suggestedAction` (advisory only; the controller never acts on it).
- Cache writes happen in a `without sharing` inner class of `ADA_ExplanationCache`: the index has Read sharing, so even system mode could not update it for a normal user (found by test). It only updates the two cache fields on a row that was read in user mode. Cache is skipped when the user typed a question, and keyed on `Source_Last_Modified__c` plus locale. Added fields `Explanation_Json__c`, `Explained_For__c` to the index, ARCHITECTURE and both permission sets (the schema test allow-list is updated).
- Validator rejects extra or missing keys, wrong types, empty or over-length text, links, and any action outside NONE / RAISE_BUG / REQUEST_ACCESS. Template fallback covers invalid JSON, 429, other non-2xx, timeouts and blocked payloads.
- D-13: one `ADA_LLM` credential, URL set at setup. `scripts/setup-llm.sh` deploys it and turns the provider on; `scripts/e2e/live-llm.apex` is the live smoke (three golden cases).
- Not done: `ADA_AnthropicProvider` (later).
- Live: `llama-3.3-70b-versatile` is no longer offered to this Groq account (404 `model_not_found`; found by listing `/models` through the credential), so the build model is `openai/gpt-oss-120b`. The unit gate redeploys the repo default setting (Template) over the org's, so the live gate now applies the LLM setting itself (`scripts/lib/apply-llm-setting.sh`, override with `ADA_LLM_MODEL`). Live result: three golden validation rules each returned a valid, accurate explanation from Groq (masked `TEXT_1` appears in one answer, a cosmetic point for the prompt in 1.8). The first key was typed as the model id by mistake and revoked by the human.

### 1.5 PII gate, HTTP gateway, payload builders

Plan:

- `ADA_Pii_Pattern__mdt` records shipped with the package: `Email`, `Phone_AU`, `Tax_File_Number`, `Card_Number` (regex in `Regex__c`, 255 chars max). `ADA_PiiGate` applies active patterns in a fixed order (by developer name, so card, email, phone, TFN); `Card_Number` hits must pass a Luhn check and `Tax_File_Number` hits the TFN weighted checksum, so phone-like rule numbers are not scrubbed. Unknown admin-added patterns redact as `[REDACTED]`.
- Name lookup: runs of capitalised words in the text (all 1 to 4 word sub-runs, capped at 40 candidates) are matched exactly against Account and Contact names with two user-mode queries; hits become `[NAME]`. Limitation to document: lower-case typing of a name is not caught.
- API: `ADA_PiiGate.scrub(text)` returns text + the kinds found; `detect(text)` is pattern-only (no SOQL) for the gateway's last-line check.
- `ADA_HttpGateway.execute` blocks any request whose body trips `detect` and throws `ADA_BlockedRequestException` (the `Blocked` action-log row is written by the logger in 1.7; the exception carries the kinds).
- `ADA_PayloadBuilder.forLlm(ADA_Diagnosis, Extras)` returns a typed body with exactly the ARCHITECTURE §4 LLM fields; free text (labels, description, user question) goes through `scrub`, the formula is re-masked, lists and lengths are capped. No other class builds an LLM body.
- `ADA_EgressCanaryTest`: seeds the canary Account, Contact, Opportunity, Case and a case comment from `test-data/canaries.json`, runs diagnose, builds the LLM payload with a user question that contains the canary name and email, sends through the gateway with a capturing mock, and asserts no canary value is in any recorded endpoint, header or body. Later steps add their flow to this test: explain (1.6), propose and confirm (1.9, 1.10).
- Verify with `unit` (static checks already ban `new Http()` / `.send(` outside the gateway).
  Result: `unit` PASS, `.verify/20261031-184350-unit`. 179 Apex tests, 0 failing, package coverage 98.2% across 25 classes, lowest class `ADA_MetadataIndexJob` 95%. Code Analyzer clean. `ADA_EgressCanaryTest` passes: no canary value in any recorded endpoint, header or body.
  Deviations / findings (self-review; reviewers unavailable):
- Email regex bounds the local part to 64 characters (RFC limit); the unbounded form hit "Regex too complicated" on long text with no `@`. A longer local part is still redacted from its last 64 characters.
- Phone_AU accepts a separator after `+61`. Phone numbers are not mistaken for TFNs (test).
- A body with no text (`setBody` not called) passes the gateway; a blocked body throws `ADA_BlockedRequestException` with `kinds`. The `Blocked` log row comes with the logger in 1.7.
- Name lookup only catches capitalised names that exactly match an Account or Contact name (documented limitation). `ADA_PiiGate` skips invalid admin regexes rather than failing.
- Object, field and permission labels are scrubbed by pattern only (no SOQL), free text also by name.

### 1.4 Classifier and matchers

Plan:

- `ADA_IMatcher` (`ADA_Diagnosis match(ADA_ErrorContext)`, null = no signal) and `ADA_ErrorContext` (object, raw message, normalised message, index rows by type from an injected `ADA_IMetadataIndexStore`, loaded once).
- `ADA_TextMatch`: score a normalised message against an index template (exact = 1, `{}` wildcard parts matched in order with a minimum amount of literal text, otherwise word-overlap above 0.85). Shared by the validation rule, flow and Apex matchers.
- Six matchers in the order of ARCHITECTURE §3: `ADA_RequiredFieldMatcher`, `ADA_ValidationRuleMatcher`, `ADA_DuplicateRuleMatcher`, `ADA_AccessChecker`, `ADA_FlowErrorMatcher`, `ADA_ApexErrorMatcher`. Each: positive, negative, near-miss and two-candidate-tie tests (tie drops confidence below the threshold).
- `ADA_ErrorClassifier` runs the matchers in order; the first result at or above the threshold wins; if another matcher is also confident the winner is capped below the threshold (ambiguous across types). `ADA_DiagnosisService.diagnose(object, message)` reads the threshold from `ADA_Setting__mdt` Default; `diagnoseForHarness` returns the map for the golden runner (no DML, no callouts).
- Verify: `e2e` gate (golden set >= 95%, zero confident wrong) and log the CPU time of one diagnosis.
  Result: `e2e` PASS, `.verify/20261031-171625-e2e`. 151 Apex tests, 0 failing, package coverage 98.4%, lowest class `ADA_MetadataIndexJob` 95%. Golden set 11/11 (100%, min 95%), 0 confident wrong; the three made-up messages score 0.00 (Unknown). CPU time of one diagnosis in the dev org: 3 to 8 ms (limit 500 ms).
  Deviations / findings:
- The scoring rule is not "word overlap above 0.85". `ADA_TextMatch` requires every template word to appear in order (recall cubed), tolerates extra message words (merged values) with a mild penalty, caps approximate matches at 0.95 so an exact match always outranks them, and refuses templates under 3 words unless the text is identical. A one-word change in a 10-word message drops below 0.6, so near-misses are never confident (unit tests prove it).
- Templates lose their `{}` / merge-field positions when normalised, so wildcard matching is by the in-order rule above, not by position.
- Ties: two candidates within 0.05 cap the answer at 0.5. The configured threshold is clamped to 0.6..1 (default 0.8 if unset) so a tie can never count as confident.
- Classifier: if two matchers are confident the first is held at threshold - 0.01 (ambiguous, ADA will not guess). A blank object or message is Unknown. With no confident matcher the closest candidate is returned with its low confidence; callers must use `isConfident`.
- `ADA_AccessChecker` reads the message (status wording and `fieldNames:`); it does not yet cross-check `UserRecordAccess` or describe permissions. It only uses a deferred describe to fetch the field label. Added `ADA_Diagnosis.capConfidence`.
- Duplicate rule rows carry no message, so the matcher keys on the platform wording (`DUPLICATES_DETECTED`, "use one of these records", "creating a duplicate record"). With several active rules the type is confident but the component stays unnamed; with none indexed it is held at 0.6.
- `diagnoseForHarness` is `public`, not `global`; a namespaced org would need `global` for the golden runner (revisit at the phase 4 package gate). It also returns `cpuMs`.
- Code Analyzer flagged `describeSObjects(..., Schema.SObjectDescribeOptions.DEFERRED)` as eager; the rule only accepts the unprefixed `SObjectDescribeOptions.DEFERRED` on `getDescribe`.
  Self-review (security): matchers and classifier do no DML and no callouts; the index is read once per diagnosis through the user-mode store; raw messages are capped at 4000 characters and parsed with fixed regexes, and field names pulled from messages must match `[A-Za-z0-9_]+` before they are returned; the harness returns only type, component name, confidence, threshold and CPU time. Reviewers: step-reviewer / security-reviewer unavailable (model 404), self-reviewed.

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
- Access case wording captured with a `System.runAs` test (`ADA_Demo_AccessErrorTest`): `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY`, "Operation failed due to fields being inaccessible on Sobject Opportunity, check errors on Exception or Result! fieldNames: ADA_Demo_Internal_Notes__c" (note the double space). The test asserts it exactly, so a platform wording change fails the gate.
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

| Phase | Gate report               | Result                                   | Human approval    |
| ----- | ------------------------- | ---------------------------------------- | ----------------- |
| 0     | `docs/reports/phase-0.md` | PASS                                     | "go" (2026-10-27) |
| 1     | `docs/reports/phase-1.md` | PASS (e2e `.verify/20261104-195603-e2e`) | "go" (2026-11-04) |
| 2     |                           |                                          |                   |
| 3     |                           |                                          |                   |
| 4     |                           |                                          |                   |
