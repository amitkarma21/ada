# ADA implementation plan

Five phases, each ending in a human checkpoint. Every step has acceptance criteria and a
**gate** (`scripts/verify.sh <gate>`) that must pass before the step is `DONE`. Claude Code runs
each step through the loop in `CLAUDE.md` (`/next-step`), and each phase ends with
`/phase-gate <n>`.

Tags: **HUMAN** = needs the person (accounts, OAuth clicks, secrets).
**security** = also run the `security-reviewer` subagent.

Gates, from cheapest to most complete:

| Gate | Runs | Needs |
| --- | --- | --- |
| `doctor` | Tool versions, Dev Hub auth, GitHub CLI auth | Nothing deployed |
| `static` | Prettier, ESLint, LWC Jest, Code Analyzer, data-file checks, egress grep | No org |
| `unit` | `static` + deploy both package dirs to the dev org (D-12) + all Apex tests + coverage ≥ 85% | Dev org (`ada-dev`) |
| `e2e` | `unit` + golden-set accuracy + index smoke | Dev org with index built |
| `live` | `e2e` + real calls to Groq / Azure DevOps / ServiceNow | `LIVE=1` and credentials set up |
| `package` | Package version build + install into a fresh scratch org + smoke | Namespace (phase 4) |

---

## Phase 0 — Foundation

### 0.1 Accounts and tools — HUMAN
Follow `docs/SETUP.md` sections 1–6.
**Acceptance:** `sf`, Node LTS, Git and `gh` installed; Dev Hub authorised as alias `ada-devhub`;
GitHub repo created and pushed; Groq API key, Azure DevOps PAT and (optional) ServiceNow
developer instance ready but **not** committed anywhere.
**Gate:** `doctor`.

### 0.2 Project scaffold
The kit already has `sfdx-project.json` (`force-app` = package, `demo-app` = unpackaged),
`package.json` scripts, `.prettierrc`, `jest.config.js`, `.gitignore`, the CI workflow and the
scripts. This step makes them work:
- `npm install --save-dev prettier prettier-plugin-apex @prettier/plugin-xml eslint
  @salesforce/eslint-config-lwc @lwc/eslint-plugin-lwc @salesforce/eslint-plugin-lightning
  eslint-plugin-import eslint-plugin-jest @salesforce/sfdx-lwc-jest` (pins current versions,
  creates `package-lock.json`).
- Add the ESLint config the installed `@salesforce/eslint-config-lwc` version expects (flat
  config or legacy), scoped to LWC folders.
- Set `sourceApiVersion` in `sfdx-project.json` to the latest the CLI supports.
- `chmod +x scripts/*.sh scripts/lib/*.sh`; install the Code Analyzer plugin; confirm its flags
  match `verify.sh` (`sf code-analyzer run --help`) and fix the script if not.
**Acceptance:**
- `npm ci` works; `scripts/verify.sh static` passes on the empty project.
- CI runs on push and is green.
- `scripts/setup-dev-org.sh` deploys both directories to the dev org `ada-dev`, assigns permission sets and seeds (re-runnable).
**Gate:** `static`, then CI green.

### 0.3 Demo org and golden set
In `demo-app/` only (never `force-app/`):
- Opportunity validation rules: `ADA_Demo_CloseDate_Future` (close date in the past on an open
  opportunity), `ADA_Demo_Large_Deal_Description` (amount over 100,000 needs a description).
- Case validation rule `ADA_Demo_Close_Reason` (closed case needs a reason).
- Record-triggered flow on Case with a Custom Error element (escalated cases need High priority).
- Apex trigger on Case that calls `addError` (web cases need an origin).
- Custom field `Opportunity.ADA_Demo_Internal_Notes__c` with no access for the standard
  profile; permission set `ADA_Demo_Notes_Editor`; permission set group
  `ADA_Demo_Notes_Editors` containing it.
- A Lightning app `ADA Demo` with a utility bar (the help panel is added in step 1.8).
- Seed script `scripts/e2e/seed.apex` creating records whose names and descriptions use the
  canary values in `test-data/canaries.json`.
- `scripts/e2e/capture-golden.apex` triggers each error with `Database.update(records, false)`
  / `Database.insert(records, false)` and prints each `{caseId, object, statusCode, message}` on
  a line starting `ADA_GOLDEN|`. `scripts/e2e/capture-golden.mjs` runs it and writes
  `test-data/golden-errors.json` (keep the `expected` block from the template; fill `message`).
- Add access-error and required-field cases by hand, using the exact platform wording seen in
  the org (verify with an Apex test using `System.runAs`).

**Acceptance:**
- Demo deploys to the dev org with `scripts/setup-dev-org.sh`.
- Capture produces at least 7 distinct cases covering every type in ARCHITECTURE §3 except
  Unknown; plus 3 Unknown cases (made-up messages).
- `test-data/golden-errors.json` and `test-data/canaries.json` committed; no canary value
  appears anywhere in `force-app/`.
**Gate:** `unit`.
**Phase 0 gate:** `/phase-gate 0` — dev org redeploy with `scripts/setup-dev-org.sh`, `unit`, report.

---

## Phase 1 — Explain (the core product)

### 1.1 Data model and settings — security
Objects, fields, custom metadata types and default records, permission sets `ADA_User` and
`ADA_Admin`, `ADA_Diagnosis`, `ADA_ErrorType`, the three interfaces (ARCHITECTURE §1).
**Acceptance:**
- Everything deploys; `ADA_Setting__mdt.Default` exists with `LLM_Provider__c = Template`.
- `System.runAs` tests: an `ADA_User` can create logs and access requests but can't read other
  users' logs or edit settings; `ADA_Admin` can.
- A schema test asserts `ADA_Metadata_Index__c` has no field that could hold record data
  (only the fields listed in ARCHITECTURE §1).
**Gate:** `unit`.

### 1.2 Self-org Tooling API access — HUMAN + security
Package an auth provider, External Credential and Named Credential `ADA_Self_Tooling`.
`ADA_ToolingClient.query(soql)` with paging and clear errors (401 → "Run the ADA setup to
reconnect"). HUMAN: authorise the credential once in the dev org (instructions in
`docs/SETUP.md` §7). `scripts/e2e/tooling-smoke.apex` lists validation rules on Opportunity.
**Acceptance:**
- Unit tests (mocked) for success, paging, 401, 500, malformed JSON.
- Smoke prints both Opportunity demo rules.
- No `getSessionId` anywhere (static gate grep).
**Gate:** `unit` + smoke output pasted into PROGRESS.

### 1.3 Metadata index — security
`ADA_MetadataIndexJob` (manual run + nightly schedule), `ADA_ObjectIndexStore`,
`ADA_FormulaMasker`, `ADA_MessageNormaliser`. Index validation rules, required fields, duplicate
rules, record-triggered flows (custom error messages where readable), trigger/class message
literals. Incremental on last-modified date. List IDs first, then one metadata callout per rule,
chained Queueables under the callout limit.
**Acceptance:**
- In the dev org, the index has a row for every demo rule, flow and trigger.
- `ADA_FormulaMasker` test: `Account.Name = 'Acme Pty Ltd' && OwnerId = '005000000000001AAA'`
  becomes `Account.Name = 'TEXT_1' && OwnerId = 'ID_1'`.
- A mocked run over 150 rules chains Queueables and never exceeds the callout limit.
- Re-running with nothing changed makes no metadata callouts.
**Gate:** `e2e` (index smoke part).

### 1.4 Classifier and matchers
`ADA_DiagnosisService`, `ADA_ErrorClassifier` and the six matchers (ARCHITECTURE §3), with
confidence scoring and the threshold from settings. Add the harness method the golden runner
calls: `public static Map<String, Object> diagnoseForHarness(String objectApiName, String message)`
returning `type`, `componentApiName`, `confidence` and `threshold` (no record context, no DML,
no callouts).
**Acceptance:**
- Unit tests per matcher: positive, negative, near-miss, two-candidate tie (confidence drops).
- Golden set: accuracy ≥ 95%, and **zero** confident wrong answers (wrong type or wrong
  component at or above the threshold). Unknown cases return Unknown.
- Diagnosis of one error completes in under 500 ms of CPU in the dev org (log it).
**Gate:** `e2e`.

### 1.5 PII gate, HTTP gateway, payload builders — security
`ADA_PiiGate` (patterns from `ADA_Pii_Pattern__mdt`: email, Australian phone formats, tax file
number, card numbers with a Luhn check, plus a lookup of Account and Contact names that appear in
the text), `ADA_HttpGateway` (the only sender, last-line check, logging), `ADA_PayloadBuilder`
for the LLM body.
**Acceptance:**
- PII gate tests for each pattern, false-positive cases (a phone-like rule number), and the
  name lookup.
- **Egress canary test** (`ADA_EgressCanaryTest`): seeds the canary records, runs diagnose →
  explain → propose → confirm with mocks that capture every request body, and asserts no canary
  value appears in any body.
- The `static` gate fails if `new Http()` or `.send(` appears outside `ADA_HttpGateway`.
**Gate:** `unit`.

### 1.6 LLM providers — security
`ADA_TemplateProvider`, `ADA_OpenAiCompatibleProvider`, `ADA_LlmProviderFactory`,
`ADA_PromptBuilder` (system prompt as a static resource), `ADA_LlmResponseValidator`,
`ADA_ExplanationCache`. Configure Groq as the build-time provider (`docs/SETUP.md` §4).
Decide one-Named-Credential-per-provider vs an editable URL and record it in DECISIONS.
**Acceptance:**
- Tests: valid response; invalid JSON; extra fields; action not in the allowlist; HTTP 429;
  timeout; provider set to Template (no callout made). Each failure falls back to Template.
- Snapshot test: the request body contains only the contract fields.
- Cache test: the second explanation for the same component makes no callout.
- `LIVE=1`: three golden cases return valid, sensible JSON from Groq (paste in PROGRESS).
**Gate:** `unit` (and `live` for the smoke).

### 1.7 Agent controller and session — security
`ADA_AgentController` (`diagnose`, `explain`, `proposeAction`, `recordFeedback`),
`ADA_AgentSession`, `ADA_ActionLogger` (ARCHITECTURE §2).
**Acceptance:**
- The full path runs with mocks without "uncommitted work pending" errors (proves callout
  before DML).
- A user can't load another user's session (test with two users).
- Every step writes one `ADA_Action_Log__c` row; the LLM row stores the exact body sent.
- Low confidence returns the "not sure" answer and offers only `RAISE_BUG`.
**Gate:** `unit`.

### 1.8 Help panel (LWC)
`adaHelpPanel` with `adaDiagnosisCard`; added to the `ADA Demo` utility bar (demo-app).
States: idle, diagnosing, explained, low confidence, error. Feedback buttons. Text from the LLM
rendered as text only.
**Acceptance:**
- Jest tests for every state, for keyboard use and labels, and that an explanation containing
  `<img src=x onerror=...>` renders as text.
- Manual demo (`docs/reports/demo-phase-1.md` checklist) passes in the dev org.
**Gate:** `unit`.

**Phase 1 gate:** `/phase-gate 1` on the dev org (redeployed with `scripts/setup-dev-org.sh`) with gate `e2e`. Demo: open an
Opportunity, break the close-date rule, paste the error, get the explanation and fix steps, mark
it solved.

---

## Phase 2 — Raise a bug in Azure DevOps

### 2.1 Azure DevOps target — security
Named Credential `ADA_AzureDevOps` (PAT during the build; decide how the External Credential
presents it, record in DECISIONS), `ADA_AzureDevOpsTarget` with WIQL dedupe on the
`ADA-rule:<api name>` tag and JSON Patch create; error mapping for 401, 403, 404, 429.
**Acceptance:**
- Mocked tests for search hit, search miss + create, each error code.
- Payload snapshot equals ARCHITECTURE §4; user notes with `<script>` are HTML-escaped.
- Egress canary test extended to this path, still green.
**Gate:** `unit`.

### 2.2 Confirm-then-create flow
`proposeAction` returns the exact payload preview; `confirmAction(RAISE_BUG)` with an
idempotency key; LWC `adaActionPreview` shows the fields and a Confirm button, then the link.
**Acceptance:**
- Double confirm (same key) creates one work item.
- Jest tests for preview, confirm, success link, error message.
- `LIVE=1`: creates a bug in the free Azure DevOps test project; running the same case again
  links to the existing bug instead of creating another.
**Gate:** `e2e`, then `live`.

**Phase 2 gate:** `/phase-gate 2` with gate `live`. Demo: trigger the Apex-trigger error,
choose "raise a bug", confirm, open the work item; repeat and see it deduplicated.

---

## Phase 3 — Request access, approved by email

### 3.1 Access checker and allowlist — security
`ADA_AccessChecker` finds the missing object/field permission and suggests allowlisted
permission set groups from `ADA_Allowed_Permission__mdt`. The demo allowlist record pointing
to `ADA_Demo_Notes_Editors` lives in `demo-app/` (custom metadata records are deployable there),
never in `force-app/`.
**Acceptance:**
- `System.runAs` tests with a user lacking the demo field: correct gap and suggestion; with no
  allowlisted group, no request is offered.
**Gate:** `unit`.

### 3.2 Approval process (spike first)
Check in the Metadata Coverage Report whether approval processes ship in a second-generation
managed package; record the answer in DECISIONS. Create `ADA_Access_Request_Approval` with
email approval response, in `force-app/` if packageable, otherwise in `demo-app/` plus wizard
instructions. HUMAN: enable email approval response and set email deliverability to all email in
the scratch org if the settings can't be deployed.
**Acceptance:**
- Submitting a request creates a pending approval (`ProcessInstance`) assigned to the
  configured approver.
- HUMAN check: the approval email arrives and replying APPROVE approves it.
**Gate:** `unit` + HUMAN confirmation recorded in PROGRESS.

### 3.3 Request flow end to end
`confirmAction(REQUEST_ACCESS)` creates the PII-gated request and submits it; on approval the
requester is emailed; optional ServiceNow order through `ADA_ServiceNowTarget`.
**Acceptance:**
- Tests: request created and submitted; justification PII-gated; on approval, requester
  email sent; **no** `PermissionSetAssignment` is ever created by ADA.
- Egress canary extended to the ServiceNow path, still green.
- `LIVE=1` (optional): approval creates a ServiceNow catalog order on the developer instance.
**Gate:** `e2e` (and `live` if ServiceNow is enabled).

**Phase 3 gate:** `/phase-gate 3`. Demo: as the restricted user, try to edit the internal-notes
field, get the explanation, request access, approver replies APPROVE by email, requester is told.

---

## Phase 4 — Package and AppExchange readiness

### 4.1 Namespace — HUMAN
Register a namespace in a free Developer Edition org, link it to the Dev Hub, set it in
`sfdx-project.json`, create a namespaced scratch org.
**Acceptance:** all tests pass in the namespaced scratch org (watch dynamic SOQL and
JavaScript references that need the namespace prefix).
**Gate:** `unit`.

### 4.2 Managed package and setup wizard
`sf package create` (managed, second-generation), `adaSetupWizard`, package version with code
coverage, install into a fresh scratch org, post-install smoke.
**Acceptance:**
- Version builds with coverage ≥ 85%; installs cleanly; the wizard's self-test passes after the
  admin connects credentials; the help panel works in the installed org.
**Gate:** `package`.

### 4.3 Security review readiness — security
Code Analyzer with no high-severity findings (or documented false positives), and documents in
`docs/security/`: false positives, data flow (from ARCHITECTURE §4), usage guide, test
credentials plan. Final regression on the installed package: golden accuracy and egress canary.
**Acceptance:** both reviewers return PASS on all of `force-app/`; regression green.
**Gate:** `package` + `e2e` on the installed org.

**Phase 4 gate:** `/phase-gate 4`. Then the human lists it as a free app and submits for review
(no review fee for free apps).

---

## Out of scope for this build (Stage 2)

Anthropic provider, per-user OAuth for Azure DevOps, Slack companion service, MCP tools,
automatic permission assignment, record-specific formula evaluation.

## Monitoring the build

- `PROGRESS.md` — status and evidence per step, blockers, phase log.
- `.verify/history.log` — one line per gate run (time, gate, result, duration). A step that
  takes more than 3 runs to pass is worth a look at the plan.
- CI on every push; the step is not done until CI is green.
- `docs/reports/phase-<n>.md` — written at each phase gate.
- Trends to watch at each phase gate: coverage, golden-set accuracy, number of gate attempts per
  step, open DECISIONS proposals.
