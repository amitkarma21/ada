# ADA test strategy

Every step proves its acceptance criteria with tests before it's `DONE`, and every gate runs
all earlier tests, so a regression is caught at the step that caused it.

## Layers

| Layer | What it proves | Tool | Gate |
| --- | --- | --- | --- |
| Static | Formatting, lint, Code Analyzer findings, only `ADA_HttpGateway` sends HTTP, no session IDs, no canary values in source | Prettier, ESLint, `sf code-analyzer`, grep checks | `static` |
| LWC unit | Every component state, accessibility labels, LLM text rendered as text | `sfdx-lwc-jest` | `static` |
| Apex unit | Each class's behaviour, every error path, permissions with `System.runAs` | Apex tests + `HttpCalloutMock` | `unit` |
| Egress canary | No record value reaches any outbound body | `ADA_EgressCanaryTest` | `unit` |
| Golden set | Classifier accuracy against real platform messages | `scripts/e2e/run-golden.mjs` | `e2e` |
| Live | Real calls to Groq, Azure DevOps, ServiceNow behave as mocked | `scripts/e2e/live-*.apex` | `live` |
| Package | The installed package works in a clean org | `scripts/verify.sh package` | `package` |
| Review | Criteria met, invariants held, AppExchange-style findings | `step-reviewer`, `security-reviewer` | every step / phase |

## Thresholds (never lowered)

- Apex coverage: org-wide ≥ 85% and every package class ≥ 75%.
- Golden set: accuracy ≥ 95%; **zero** confident wrong answers.
- Egress canary: zero hits.
- Code Analyzer: zero findings at severity 1–2 (Critical, High) unless documented as a false
  positive in `docs/security/false-positives.md`.
- LWC: every component has Jest tests; aim for ≥ 90% statements.

## Mocks and fakes

- Every callout goes through `ADA_HttpGateway`; tests use one `ADA_MockHttp` that records each
  request (method, endpoint, body) and returns scripted responses. The egress canary test reads
  those recorded bodies.
- `ADA_IMetadataIndexStore` has an in-memory fake so diagnosis tests don't need the Tooling API.
- `ADA_ILlmProvider` has a scripted fake for controller tests.
- Never `SeeAllData=true`. Create test users in tests.
- Package tests run in the demo org, where demo validation rules, the flow and the trigger are
  active, and later in customer orgs with their own automation. So tests that need records
  create data that satisfies the demo rules, prefer objects ADA owns, and never assume a clean
  org. Package version builds run tests in a clean org, which catches the opposite mistake.

## Script conventions

Anonymous Apex scripts in `scripts/e2e/` report through marker lines so the gates can check them:
`System.debug(LoggingLevel.ERROR, '<MARKER>|' + detail);`

| Script | Written in step | Markers |
| --- | --- | --- |
| `seed.apex` | 0.3 | none (creates canary records) |
| `capture-golden.apex` | 0.3 | `ADA_GOLDEN` + JSON per case |
| `tooling-smoke.apex` | 1.2 | `ADA_TOOLING_OK` / `ADA_TOOLING_FAIL` |
| `index-smoke.apex` | 1.3 | `ADA_INDEX_OK` (with counts) / `ADA_INDEX_FAIL` |
| `live-llm.apex`, `live-ado.apex`, `live-servicenow.apex` | 1.6, 2.2, 3.3 | `ADA_LIVE_OK` / `ADA_LIVE_FAIL` |
| `post-install-smoke.apex` | 4.2 | `ADA_SMOKE_OK` / `ADA_SMOKE_FAIL` |

`scripts/lib/run-apex-markers.mjs` runs a script and fails unless the OK marker appears and the
FAIL marker doesn't.

## Golden set (`test-data/golden-errors.json`)

Captured from the demo org in step 0.3, so messages are the platform's real wording.

```json
{
  "id": "opp-closedate-past",
  "object": "Opportunity",
  "message": "<exact text captured from the org>",
  "expected": { "type": "VALIDATION_RULE", "componentApiName": "ADA_Demo_CloseDate_Future" }
}
```

`run-golden.mjs` sends each message through `ADA_DiagnosisService` in the dev org (anonymous
Apex that prints `ADA_RESULT|<json>` lines), compares type and component, and prints accuracy,
confident-wrong count and a per-case table. Add a case to the golden set for every bug found.

## Egress canary

`test-data/canaries.json` lists unique strings (for example `CANARY-OPP-4K9X`) used as record
names, descriptions and amounts in seed data and tests. `ADA_EgressCanaryTest` runs every flow
that sends data out and asserts none of these strings appears in any recorded request body. The
`static` gate also fails if a canary value appears in `force-app/`.

## Live tests (opt-in)

Run with `LIVE=1 scripts/verify.sh live`. They use only demo metadata and canary-free text, and
clean up after themselves where the API allows (Azure DevOps bugs are tagged `ADA-live-test` so
they're easy to close). Free-tier rate limits: run live tests at phase gates, not on every step.

## What CI runs

| Trigger | Jobs |
| --- | --- |
| Every push and pull request | `static` (no org, no limits used) |
| Manual (`workflow_dispatch`) and nightly | `unit` on a new scratch org, deleted afterwards (optional) |

Local `unit` and `e2e` run against the Developer Edition dev org (`ada-dev`, D-12), not a scratch
org. CI only creates a scratch org on manual or nightly runs, and the phase 4 `package` gate
installs into a fresh one.
