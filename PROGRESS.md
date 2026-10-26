# ADA build progress

Status values: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`, `REOPENED`.
Claude Code updates this file at every step (see `CLAUDE.md`, the build loop).

## Steps

| Step | Title | Tags | Gate | Status | Evidence (log, tests, coverage) |
| --- | --- | --- | --- | --- | --- |
| 0.1 | Accounts and tools | HUMAN | doctor | DONE | doctor PASS, `.verify/20261026-162142-doctor`. Groq key, Azure DevOps and ServiceNow deferred (needed from 1.6 / phase 2). Dev Hub alias `ada-devhub` -> AdminBot username. |
| 0.2 | Project scaffold | | static | TODO | |
| 0.3 | Demo org and golden set | | unit | TODO | |
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

## Blockers

<!-- BLOCKED steps: what failed, evidence, options, what the human needs to decide. -->

## Phase log

| Phase | Gate report | Result | Human approval |
| --- | --- | --- | --- |
| 0 | | | |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
