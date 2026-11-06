# ADA architecture

Stage 1 (this build) runs entirely inside the customer's org as a managed package. The only
external calls go to the customer's own accounts: an LLM (free Groq tier during the build),
Azure DevOps (parked, D-16) and, optionally, ServiceNow. Bug reports go by email for now (D-16). Access requests are approved by email through a
Salesforce approval process. The vendor hosts nothing.

```
User ── adaHelpPanel (LWC, utility bar)
          │ 1 diagnose(errorText, recordId)        no callout
          ▼
     ADA_AgentController ──► ADA_DiagnosisService ──► metadata index (ADA_Metadata_Index__c)
          │ 2 explain(sessionKey)                   callout → LLM via ADA_HttpGateway
          │ 3 proposeAction(sessionKey)             builds payload preview, no callout
          │ 4 confirmAction(sessionKey, notes)      email → bug report address (D-16), or
          │                                         DML → ADA_Access_Request__c + approval email
          ▼
     ADA_Action_Log__c (every step, every payload sent)
```

## 1. Components (all in `force-app/`, prefix `ADA_`)

### Objects and metadata

| Component | Purpose | Key fields |
| --- | --- | --- |
| `ADA_Metadata_Index__c` | Cached index of org metadata used for matching. Metadata only, never record data | `Object_Api_Name__c`, `Component_Type__c` (ValidationRule, RequiredField, Flow, ApexTrigger, DuplicateRule), `Api_Name__c`, `Label__c`, `Description__c`, `Message_Template__c`, `Message_Normalised__c`, `Formula_Masked__c`, `Field_Api_Names__c`, `Active__c`, `Source_Last_Modified__c`, `Indexed_At__c`, `Explanation_Json__c`, `Explained_For__c` (explanation cache, step 1.6), `Flow_Runs_When__c` (when a flow runs, in words, step 2.5.2) |
| `ADA_Action_Log__c` | Audit and ROI log, one row per step | `Session_Key__c`, `Step__c` (Diagnose, Explain, Propose, Confirm, Act, Feedback), `Error_Type__c`, `Component_Api_Name__c`, `Confidence__c`, `Target_System__c` (None, LLM, AzureDevOps, ServiceNow, Email), `Payload_Sent__c` (long text, the exact body), `Result__c`, `External_Id__c`, `External_Url__c`, `Status__c`, `Idempotency_Key__c` (unique), `Feedback__c` (Solved, Not solved) |
| `ADA_Access_Request__c` | Access request that goes through email approval | `Permission_Set_Group__c` (API name), `Permission_Label__c`, `Justification__c` (PII-gated), `Status__c` (Draft, Submitted, Approved, Rejected, Fulfilled), `Approver__c`, `Session_Key__c`, `ServiceNow_Number__c` |
| `ADA_Setting__mdt` | One `Default` record | `LLM_Provider__c` (Template, OpenAICompatible, Anthropic), `LLM_Model__c`, `LLM_Timeout_Ms__c`, `Confidence_Threshold__c` (default 0.8), `Bug_Report_Email__c`, `ADO_Enabled__c`, `ADO_Project__c`, `ADO_Area_Path__c`, `ADO_Work_Item_Type__c` (Bug), `ServiceNow_Enabled__c`, `ServiceNow_Catalog_Item__c`, `Default_Approver_Username__c` |
| `ADA_Allowed_Permission__mdt` | Permission set groups ADA may suggest | `Permission_Set_Group__c`, `Grants_Object__c`, `Grants_Field__c`, `Risk__c` (Low, Medium) |
| `ADA_Pii_Pattern__mdt` | Regex patterns the PII gate blocks | `Regex__c`, `Active__c`, `Description__c` |

### Named Credentials (packaged; the customer fills in secrets after install)

| Name | Calls | Auth during build | Auth for customers |
| --- | --- | --- | --- |
| `ADA_Self_Tooling` | The org's own Tooling API | OAuth via a Salesforce auth provider (one click per org) | Same, set up by the install wizard |
| `ADA_LLM` | OpenAI-compatible chat completions endpoint | Groq API key as a custom header | Customer's own provider key |
| `ADA_AzureDevOps` | `https://dev.azure.com/{org}` REST API | Personal access token | Per-user OAuth (Entra ID) before listing |
| `ADA_ServiceNow` | ServiceNow Service Catalog API (optional) | Basic auth on the free developer instance | OAuth |

If a packaged Named Credential's URL can't be changed by subscribers, ship one Named Credential
per supported LLM provider instead (decide in step 1.6, record in DECISIONS).

### Apex, by layer

| Layer | Classes |
| --- | --- |
| Entry | `ADA_AgentController` (`@AuraEnabled` API), `ADA_AgentSession` (state machine) |
| Diagnosis | `ADA_DiagnosisService`, `ADA_ErrorClassifier`, `ADA_MessageNormaliser`, matchers: `ADA_ValidationRuleMatcher`, `ADA_RequiredFieldMatcher`, `ADA_AccessChecker`, `ADA_DuplicateRuleMatcher`, `ADA_FlowErrorMatcher`, `ADA_ApexErrorMatcher`; DTOs `ADA_Diagnosis`, `ADA_ErrorType` |
| Index | `ADA_IMetadataIndexStore`, `ADA_ObjectIndexStore`, `ADA_ToolingClient`, `ADA_FormulaMasker`, `ADA_MetadataIndexJob` (Schedulable + Queueable chain) |
| LLM | `ADA_ILlmProvider`, `ADA_TemplateProvider`, `ADA_OpenAiCompatibleProvider`, `ADA_LlmProviderFactory`, `ADA_PromptBuilder`, `ADA_LlmResponseValidator`, `ADA_ExplanationCache` |
| Safety | `ADA_PiiGate`, `ADA_PayloadBuilder` (one typed builder per target), `ADA_HttpGateway` (the only class that sends `HttpRequest`) |
| Actions | `ADA_IActionTarget`, `ADA_EmailTarget`, `ADA_AzureDevOpsTarget` (parked, D-16), `ADA_AccessRequestService`, `ADA_ServiceNowTarget` (optional), `ADA_ActionLogger` |

### LWC and permissions

- `adaHelpPanel` (utility bar): gets `recordId` from `CurrentPageReference`, paste box, explanation,
  fix steps, feedback buttons, action preview and confirm. Children: `adaDiagnosisCard`,
  `adaActionPreview`.
- `adaSetupWizard` (admin app page): checks each Named Credential, runs the first index, sets
  the approver, shows a self-test.
- Permission sets: `ADA_User` (help panel, own logs, create access requests), `ADA_Admin`
  (settings, index job, all logs).

## 2. Runtime flow and transactions

Each LWC call is its own Apex transaction. Rules: callouts before DML; the server never trusts a
diagnosis sent back by the client, it reloads the session by `Session_Key__c` and checks the
caller owns it.

1. `diagnose(errorText, recordId)` — no callout. Classify, score, log `Diagnose`, return the
   display diagnosis, confidence and allowed next actions.
2. `explain(sessionKey)` — if `LLM_Provider__c = Template`, or the cache has an explanation for
   this component + `Source_Last_Modified__c`, no callout. Otherwise one synchronous callout
   (timeout from settings, default 10 s) through `ADA_HttpGateway`, then validate, then log.
   Any error, timeout or HTTP 429 falls back to `ADA_TemplateProvider`.
3. `proposeAction(sessionKey, actionType, userNotes)` — builds the exact payload with
   `ADA_PayloadBuilder` (notes after the PII gate) and returns it for display with the notes the
   preview was built from. Nothing is sent, logs `Propose`. The LWC re-calls it when the person
   edits the notes, and will not confirm notes the preview does not show.
4. `confirmAction(sessionKey, actionType, userNotes)` — for `RAISE_BUG`, the key is
   `<sessionKey>:RAISE_BUG`; a logged success for that key returns "already sent" without sending.
   Otherwise `ADA_EmailTarget` sends one plain-text email to `Bug_Report_Email__c`, then logs
   `Confirm` (a key is stored only on success, so a failed send can be retried). For
   `REQUEST_ACCESS` (phase 3), insert `ADA_Access_Request__c` and submit it for approval.
5. `recordFeedback(sessionKey, solved)` — logs `Feedback` (drives the deflection metric).

Low confidence (below `Confidence_Threshold__c`) always produces "I'm not sure what's blocking
you" and offers `RAISE_BUG` with the raw context. Never guess.

## 3. Diagnosis rules

Matchers run in this order; the first confident match wins, ties lower the confidence.

| Order | Type | Signal | Source |
| --- | --- | --- | --- |
| 1 | Required field | Platform's required-fields message; field label(s) parsed | Schema describe |
| 2 | Validation rule | Normalised error text equals or closely matches an index message for the record's object | Index (Tooling `ValidationRule`) |
| 3 | Duplicate rule | Duplicate-alert message; active duplicate rules on the object | Index |
| 4 | Access | Insufficient-access message, or field/object not updateable for this user | `Schema` describe in user context, `UserRecordAccess` |
| 5 | Flow | Flow error text, or a match to an indexed flow custom-error message | Index |
| 6 | Apex | Message literal found in an indexed trigger/class body | Index |
| 7 | Unknown | Nothing matched | — |

Notes for the build:

- The object comes from the record ID prefix (`Id.getSObjectType()`); only that object's index
  rows are candidates.
- Normalise both sides: lower case, collapse whitespace, strip punctuation and the platform's
  prefixes (for example "FIELD_CUSTOM_VALIDATION_EXCEPTION").
- Tooling API returns the `Metadata` field only when a query returns a single record, so the
  index job lists IDs first, then fetches each rule's metadata one per callout, chaining
  Queueables to stay under the per-transaction callout limit.
- Real platform message formats are captured in step 0.3 into the golden set. Build matchers
  against those captured strings, not assumed ones.

## 4. Outbound data contract

`ADA_HttpGateway` is the only class allowed to send an `HttpRequest`. Each target has one typed
payload builder. Nothing else may add fields.

**To the LLM** — request body:

| Field | Content |
| --- | --- |
| `errorType` | Enum value |
| `objectApiName`, `objectLabel` | Metadata |
| `componentType`, `componentApiName`, `componentLabel`, `componentDescription` | Metadata, after the PII gate |
| `conditionFormulaMasked` | Formula with every string literal replaced by `TEXT_n` and every 15/18-character ID by `ID_n` |
| `ruleMessage` | The error message as the admin wrote it in metadata (never a rendered message), after the PII gate, ≤ 500 chars |
| `flowRunsWhen` | For a flow, when it starts, chosen from a fixed list of phrases (for example "before a record is saved"); no record values |
| `fieldLabels` | Labels of fields involved |
| `missingPermissionLabels` | Permission set group labels |
| `userQuestion` | The user's own words after the PII gate (optional) |
| `locale` | User locale |

The system prompt is a static resource in the package. The model must return JSON:
`{"explanation": string ≤ 1200 chars, "fixSteps": string[] ≤ 5, "suggestedAction": "NONE" | "RAISE_BUG" | "REQUEST_ACCESS"}`.
Anything else is rejected and the Template provider answers instead.

**To Azure DevOps** — WIQL dedupe query on the tag `ADA-rule:<componentApiName>`, then a
JSON Patch create with: `System.Title`, `System.Description` (HTML-escaped: error type,
component, object, message template after the PII gate, the user's steps after the PII gate,
confidence, session key, record link), `System.Tags` (`ADA; ADA-rule:<api name>`),
`System.AreaPath` (only when set). The search is limited to open items; a hit links the existing
item and creates nothing. The work item type, project and area path come from `ADA_Setting__mdt`;
the record link is not sent.

**By email (bug reports, D-16)** — one plain-text `Messaging.SingleEmailMessage` to the single
address in `ADA_Setting__mdt.Bug_Report_Email__c`; the user cannot choose or see the recipient.
Subject: the generated title on one line, ≤ 200 chars. Body: the same `description` and `tags`
the preview shows, after the PII gate. No HTML, no attachments, no cc or bcc, no activity logged.
`ADA_PiiGate.detect` runs on subject and body just before sending; a hit blocks the send and logs
`Status__c = Blocked` with kinds only. Email counts against the org's daily limit.

**To ServiceNow** (optional, after approval) — catalog order variables: permission label and API
name, requester email, justification after the PII gate, Salesforce request ID.

**Approval email** — sent by Salesforce's own approval process; stays on Salesforce infrastructure.

**Never sent anywhere:** SObject field values, record Names, amounts, attachments, notes, Chatter
or email text, rendered Apex/Flow messages (send the template from metadata instead), session
IDs, credentials.

`ADA_HttpGateway` (HTTP) and `ADA_EmailTarget` (email) run a last-line check on every outgoing body
against the PII patterns. A hit blocks the send and logs `Status__c = Blocked`. Canary values are never in production code:
`ADA_EgressCanaryTest` seeds them and asserts against the bodies the mock recorded (test classes
are the only package files allowed to contain canary values).

## 5. LLM provider abstraction

`ADA_ILlmProvider.explain(ADA_Diagnosis) → ADA_Explanation`. Implementations:

- `ADA_TemplateProvider` — deterministic text per error type. Default and fallback.
- `ADA_OpenAiCompatibleProvider` — `POST {base}/chat/completions` with `model`, `messages`
  (system + user), `temperature: 0`, a token cap, and JSON output requested. Works for Groq
  during the build, and for other OpenAI-compatible providers later.
- `ADA_AnthropicProvider` — later, for customers who choose Claude via the API.

Switching provider = change `ADA_Setting__mdt` + the Named Credential. No code change.
`ADA_ExplanationCache` stores explanations per component + `Source_Last_Modified__c`, which keeps
calls well inside free-tier daily limits.

## 6. Access requests approved by email

1. `ADA_AccessChecker` finds the missing object or field permission and looks up
   `ADA_Allowed_Permission__mdt` for groups that grant it. If none is allowlisted, ADA suggests
   contacting an admin and offers no request.
2. The user confirms; ADA inserts `ADA_Access_Request__c` and submits it with
   `Approval.ProcessSubmitRequest` to the approval process `ADA_Access_Request_Approval`, which
   has email approval response enabled so the approver can reply APPROVE or REJECT.
3. On approval: the requester gets an email; if ServiceNow is enabled, a fulfilment ticket is
   ordered; an admin assigns the permission set group. ADA never assigns permissions in Stage 1.

Whether approval processes can ship in a second-generation managed package is checked in step
3.2. If they can't, the wizard guides the admin to create it (approvers differ per customer
anyway).

## 7. Repository layout

```
force-app/main/default/     the managed package (ADA_*)
demo-app/main/default/      unpackaged demo setup: validation rules, flow, trigger, test users
config/                     scratch org definition
scripts/                    verify.sh, setup-dev-org.sh, new-scratch-org.sh, lib/, e2e/
test-data/                  golden-errors.json, canary values
docs/                       plan, architecture, tests, setup, decisions, reports/
.claude/                    agents and skills that run the build loop
.github/workflows/ci.yml    CI
```
