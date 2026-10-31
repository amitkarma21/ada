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
