# Decisions

Status: `ACCEPTED` (in force), `PROPOSED` (raised during the build, waiting for the human),
`SUPERSEDED`. Claude Code adds `PROPOSED` entries; only the human accepts them.

Template for new entries:

```
## D-NN Title — PROPOSED
Context: what happened (step id, evidence, log path)
Options: 1) … 2) … 3) …
Recommendation: …
Decision: (human fills in)
```

---

## D-01 External managed package, no Agentforce — ACCEPTED

Customers shouldn't need an Agentforce licence, and the app should be listable on AppExchange.
Stage 1 runs entirely in the customer's org; the vendor hosts nothing.

## D-02 Deterministic diagnosis, LLM only explains — ACCEPTED

Matching errors to metadata is done in Apex. The LLM writes the explanation and picks from an
allowlist of actions. This keeps answers accurate, cheap, testable and reviewable.

## D-03 Fixed agent loop, not open tool-calling — ACCEPTED

Diagnose → explain → propose → confirm → act → log, coded as a state machine. Predictable,
within Apex limits, easier to pass security review. MCP and open tool use wait for Stage 2.

## D-04 Free runtime LLM: Groq via an OpenAI-compatible provider — ACCEPTED

Free to build, swappable later (setting + Named Credential, no code change). Groq's terms say
inputs and outputs aren't used for training and zero data retention is available. Google's free
Gemini tier was rejected because free-tier prompts are used to improve Google products and may
be read by human reviewers. Template mode is the default and the fallback, so the app works with
no LLM at all. Re-check the provider's terms before listing.

## D-05 Approval by email, not Slack — ACCEPTED

Slack buttons need a public endpoint. A Salesforce approval process with email approval
response is free, native and needs no endpoint. ServiceNow becomes an optional fulfilment ticket
after approval. ADA never assigns permissions itself in Stage 1.

## D-06 GitHub + GitHub Actions for CI — ACCEPTED

`static` on every push; org-based jobs on manual or nightly runs to save scratch org limits.

## D-07 Standard objects for the demo org — ACCEPTED

Opportunity and Case with demo validation rules, a flow, a trigger and a restricted field, all
in `demo-app/`, never in the package.

## D-08 Mask formula literals before sending — ACCEPTED

Validation rule formulas can contain hardcoded customer names or record IDs. String literals
become `TEXT_n` and IDs become `ID_n` before anything leaves the org.

## D-09 Index stored in a custom object — ACCEPTED

`ADA_Metadata_Index__c` instead of Platform Cache, because cache allocation isn't guaranteed in
every org edition. A cache layer can be added later behind `ADA_IMetadataIndexStore`.

## D-10 Synchronous LLM callout with a short timeout — ACCEPTED

LLM explanations are short and the free provider is fast; a 10-second timeout with Template
fallback keeps the flow simple. Revisit (Continuation or Queueable + platform event) if timeouts
show up in the logs.

## D-11 Chrome extension instead of a managed package — REJECTED

Considered 2026-10-26 and rejected by the human; the product stays a managed package on
AppExchange (D-01 holds). The extension would have held the user's Salesforce session, moved the
"no record values leave the org" guarantee from the org to the browser, and needed a vendor
proxy or per-user LLM keys. Ideas worth reusing later: showing the user the exact outbound
payload before sending, and evaluating a rule's formula locally so only derived facts go to the
LLM (a Stage 2 candidate, already listed as "record-specific formula evaluation").

## D-12 Build and test in the Developer Edition org, not scratch orgs — ACCEPTED

Decided 2026-10-28 at the human's request after repeated scratch-org friction (locked PKCE on
External Client Apps, no classic connected apps, 7-day expiry forcing a repeat of the OAuth
click). `ada-dev` is now an alias for the Developer Edition org that is also the Dev Hub. The
`unit` and `e2e` gates deploy `force-app` and `demo-app` there and refuse to run unless the org's
`OrganizationType` is `Developer Edition`. Costs accepted: demo metadata (Case flow and trigger,
validation rules, duplicate rule) is live in that org; there is no clean-slate rebuild between
runs (the seed script is re-runnable, deploys are idempotent); phase-gate "fresh org" runs need a
manual reset. Scratch orgs remain only for the CI org job and the phase 4 `package` gate, which
must install into an empty org.

## D-13 One `ADA_LLM` Named Credential, URL set at setup — ACCEPTED

A single `ADA_LLM` Named Credential (OpenAI-compatible chat completions) is created at setup from
`setup/llm-template` with the provider's base URL, instead of shipping one credential per provider.
The provider and model live in `ADA_Setting__mdt`; the key is pasted into the External Credential
principal and never passes through scripts or code. `ADA_AnthropicProvider` (later) would need its
own credential because its request format differs. Revisit at the package gate (4.2) if a packaged
credential's URL cannot be edited by subscribers.

## D-14 Explanations quote the rule and read its condition — ACCEPTED

Decided 2026-11-01 after the first manual demo returned generic guidance ("read the error message,
update that value"). The index already holds the rule's configured message and masked condition, so:
`ruleMessage` (metadata text, PII-gated, 500 chars) joins the LLM contract in ARCHITECTURE section 4;
the system prompt now tells the model to explain the rule in business terms and name the field to
change; and `ADA_FormulaReader` turns a masked formula into plain-English conditions and fix hints
so the Template fallback is specific too, with no model involved. The reader never invents masked
values ("one of the values the rule watches") and returns nothing when it cannot parse a formula,
in which case the Template falls back to the rule's message and field labels. A field-API-name to
label map is passed to the Template only and is never sent. Cached explanations carry a version
(`ADA_ExplanationCache.VERSION`) so answers written under an older prompt or contract are
regenerated; raise it whenever the prompt or the contract changes.

## D-15 Azure DevOps access token as a Basic-auth External Credential — ACCEPTED

Decided 2026-11-04 for step 2.1. Azure DevOps accepts a personal access token as the password of an
HTTP Basic header (any username). The `ADA_AzureDevOps` External Credential therefore uses the
`Basic` protocol and the Named Credential generates the `Authorization` header itself, so no token
or header formula appears in code, settings or scripts; the human pastes it into the principal
(`scripts/setup-ado.sh` prints the steps). The URL (`https://dev.azure.com/<org>`) is set at setup
from `setup/ado-template`, as for the LLM (D-13). Project, area path and work item type are in
`ADA_Setting__mdt`. Dedupe is a WIQL search on the `ADA-rule:<api name>` tag, limited to open items
(not Closed, Done or Removed): a hit links the existing item and creates nothing. The rule name must
match `[A-Za-z0-9_]{1,80}` before it enters the query, otherwise nothing is sent. Links returned to
the UI must be `https://`. Per-user OAuth (Entra ID) is the pre-listing replacement (4.3).
Known limit: the PII gate scrubs Account and Contact names, emails, phones, TFNs and cards in the
user's notes, not other record names (an Opportunity name typed in the notes is not recognised).
The control for that is the exact payload preview the user confirms in 2.2.

## D-16 Bug reports go by email for now — ACCEPTED

Decided 2026-11-04 for step 2.2. `RAISE_BUG` sends one plain-text email to `Bug_Report_Email__c` in
`ADA_Setting__mdt` instead of creating an Azure DevOps work item. The user cannot choose or see the
recipient, and nothing from the user goes into a header: the subject is the generated title with
line breaks removed, the body is text only, and the address list is exactly the setting. The body is
the same `WorkItemBody` the preview shows (title, description, tags) and the PII `detect` check runs
on subject and body just before sending, as `ADA_HttpGateway` does for HTTP, so a blocked body is
never sent. One report per session: the idempotency key is `<session key>:RAISE_BUG`, a second
confirm returns the first result without sending. Only a success is logged under the key, so a
failed send can be retried. Email has no dedupe by rule (the Azure DevOps target had one) and no
link back; the log row is the audit trail. Sending counts against the org's daily email limit, and
needs Deliverability set to All email (sandboxes default to system email only). `ADA_AzureDevOpsTarget`
(D-15) stays built and tested but is not wired to the confirm flow; switching back is a change in
`ADA_AgentController.confirmAction` only.

## D-17 Keep an anonymous sample of errors ADA could not explain — ACCEPTED

Decided 2026-11-06 for step 2.6.1. Until now the log held no error text. To let admins see which
errors ADA keeps missing, a Diagnose row that is not confident stores `Error_Sample__c`: the message
after the PII gate (patterns and Account / Contact names), the "first error:" wrapper and status code
removed, lower-cased, punctuation and every digit dropped, at most 200 characters (`ADA_ErrorSampler`).
Confident rows store nothing. The sample is never sent to the LLM or any other system, and it is not
in the analytics set: field access is read for the row owner (`ADA_User`, no edit) and read/edit for
`ADA_Admin` only, `ADA_Analytics` has none. The admin list view "Unknown errors" and the report
"Unknown error samples" (private folder, own report type) group repeats. Static check 9 fails if any
other report, report type or dashboard reads the field. Known limit: free text can still carry a
word that is personal data and is not a pattern or a known Account / Contact name; the digit and
length limits reduce, not remove, that.
