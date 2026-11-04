# Phase 1 gate report: Explain

**Outcome:** a user can paste a Salesforce save error into the ADA help panel and get a plain-English diagnosis, an explanation built from the rule's condition and message, fix steps and a feedback button, with no record values leaving the org and with the LLM switched off if wanted.

## Gate results
- `e2e` PASS on the dev org `ada-dev` (D-12): `.verify/20261104-195603-e2e`, 145 s.
- Apex: 277 tests, 0 failing; package coverage 97.2% across 36 classes; lowest class `ADA_ExplanationService` 92%.
- LWC: 27 Jest tests (2 suites) pass; ESLint and Prettier clean; Code Analyzer clean.
- Golden set: 11/11 (100%, min 95%), 0 confident wrong.
- Egress canary (`ADA_EgressCanaryTest`): passes; no canary value in any recorded endpoint, header or body (covers diagnose and explain).
- Live Groq (`openai/gpt-oss-120b`): `scripts/e2e/live-llm.apex` run directly, three golden validation rules returned specific, accurate explanations (the rule message is now part of the request).

## Reviewers
`security-reviewer` and `step-reviewer` could not start (model 404 from the Task tool, as in earlier steps). Self-review instead:
- Only `ADA_HttpGateway` calls `new Http().send`; all endpoints are `callout:`.
- `without sharing` appears only in the two documented inner writers (`ADA_ActionLogger.Writer`, `ADA_ExplanationCache.Writer`), each scoped to the caller or to two cache fields.
- Index and session SOQL is `USER_MODE`; the Tooling queries are fixed strings, with ids checked against `[A-Za-z0-9]{15,18}` before use in dynamic SOQL.
- LWC: no `innerHTML`, `lwc:dom` or `eval`; server text is bound as text nodes (XSS test).
- New in this phase's last step: `ruleMessage` is PII-scrubbed and clipped in `ADA_PayloadBuilder.forLlm`; `ADA_FormulaReader` is bounded (length, token, depth, item limits) and returns null instead of throwing.
Run the real reviewers when the tool works.

## Deviations and decisions
- D-12 (dev org instead of scratch orgs): the gate ran on `ada-dev`, not a fresh scratch org as the skill says.
- D-13: one `ADA_LLM` Named Credential, URL chosen at setup.
- D-14: explanations quote the rule and read its condition (found by the manual demo).
- Build model is `openai/gpt-oss-120b` (the first choice is no longer offered).
- Findings recorded per step in `PROGRESS.md`.

## Risks and open points for phase 2
- The full `live` gate stalled twice at `RunLocalTests` (empty results file); the cause looks org-side but is unconfirmed. Re-run it before relying on it.
- `verify.sh unit|e2e|live` redeploys the default setting (Template) over the org's; re-apply with `scripts/lib/apply-llm-setting.sh`.
- Explanation quality is acceptable but the human wants more improvement (flow, Apex, duplicate and access answers still use generic Template text).
- `ADA_AnthropicProvider` not built. `diagnoseForHarness` is `public`; revisit at the phase 4 package gate.
- Reviewers have never run on this project.

## What the human must do for phase 2
- Azure DevOps organisation, free test project and a PAT (deferred from 0.1), needed from 2.1 (live from 2.2).
- Say "go" to start phase 2, or list the explanation improvements to do first.
