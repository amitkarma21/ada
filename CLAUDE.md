# ADA — Admin Deflection Agent (Salesforce managed package)

ADA answers "why can't I save this record?" from org metadata, and when the answer is
"it's a bug" or "you need access", it raises an Azure DevOps bug or an access request
(approved by email). It ships as a free AppExchange managed package. Customers need no
Agentforce licence, and in Stage 1 the vendor hosts nothing.

Read these before writing any code:

- `docs/IMPLEMENTATION_PLAN.md` — the ordered steps, each with acceptance criteria and a gate.
- `docs/ARCHITECTURE.md` — components, interfaces, the outbound data contract.
- `docs/TEST_STRATEGY.md` — test layers, golden set, egress canary, thresholds.
- `docs/DECISIONS.md` — decisions already made. Don't reopen them without a proposal.
- `PROGRESS.md` — where the build is. Always update it.

## Non-negotiable invariants

These hold in every step. A change that breaks one is wrong even if tests pass.

1. **No record values leave the org.** Outbound HTTP bodies may only contain the fields in
   the data contract (`docs/ARCHITECTURE.md` §4). Field values, record names, amounts,
   attachments and Chatter/email text never go out. The egress canary test must stay green.
2. **All callouts use Named Credentials** (`callout:ADA_...`). Never `UserInfo.getSessionId()`,
   never hardcoded endpoints, keys or tokens. Secrets live only in External Credentials.
3. **User mode by default.** SOQL with `WITH USER_MODE`, DML with `AccessLevel.USER_MODE`,
   classes `with sharing`. Any exception is recorded in `docs/DECISIONS.md` with the reason.
4. **Callouts before DML** in every transaction. Log after the callout, or in a separate call.
5. **LLM output is untrusted.** Parse as JSON, validate against the schema and the action
   allowlist, reject anything else. Never execute, eval or render it as HTML.
6. **Nothing is written to an external system without explicit user confirmation**, and every
   write is logged to `ADA_Action_Log__c` with the exact payload sent.
7. **Everything works with the LLM switched off.** The Template provider is the fallback for
   errors, timeouts, rate limits (429) and "LLM disabled".
8. **Demo metadata never enters the package.** `force-app/` is the package; `demo-app/` is the
   unpackaged demo org setup (validation rules, flow, trigger, test users).

## The build loop — follow it for every step

Work strictly one step at a time, in the order of `docs/IMPLEMENTATION_PLAN.md`.
The `/next-step` skill runs this loop; follow it even when not invoked.

1. **Pick** the first step in `PROGRESS.md` that is not `DONE`. Mark it `IN PROGRESS`.
2. **Plan** in 3–6 bullets under the step in `PROGRESS.md`: files to touch, tests to add.
3. **Test first.** Write or extend the tests that prove the acceptance criteria.
4. **Implement** the smallest change that makes them pass.
5. **Gate.** Run `scripts/verify.sh <gate>` with the gate the step names.
6. **Fix loop.** On failure: find the root cause, fix it, re-run the gate.
   After **3 failed attempts on the same step, stop**, write the blocker in `PROGRESS.md`
   and ask the human. Don't skip ahead.
7. **Review.** Run the `step-reviewer` subagent on the step's diff. For steps tagged
   `security`, also run `security-reviewer`. Fix findings, re-run the gate.
8. **Record evidence** in `PROGRESS.md`: gate result, test count, coverage, log folder path,
   deviations from the plan.
9. **Commit** with message `step <id>: <summary>`. Push. CI must be green before the next
   step: check with `gh run watch` (or `gh run list --limit 1`); if `gh` isn't available, ask
   the human to confirm CI is green.
10. **Phase end:** when the last step of a phase is `DONE`, run `/phase-gate <phase>` and
    **stop for human review**. Don't start the next phase until the human says go.

## Course-correction rules

- If a step shows the plan is wrong (an API doesn't exist, a limit is hit, a platform feature
  behaves differently), **don't improvise silently.** Add a `PROPOSED` entry to
  `docs/DECISIONS.md` with the evidence and options, set the step to `BLOCKED`, and ask.
- Never weaken a test, delete a failing test, lower a threshold or add a skip to get green.
- Never change an invariant. Only the human can.
- If you notice an earlier `DONE` step is broken, reopen it (`REOPENED` with the reason)
  before continuing.
- Steps marked **HUMAN** need the person (account sign-ups, OAuth clicks, secrets).
  Stop, list exactly what they must do, and wait.

## Commands

| What                                                 | Command                         |
| ---------------------------------------------------- | ------------------------------- |
| Static checks (no org)                               | `scripts/verify.sh static`      |
| Deploy + Apex/LWC tests + coverage                   | `scripts/verify.sh unit`        |
| Unit + golden-set accuracy + egress canary           | `scripts/verify.sh e2e`         |
| E2E + live calls to Groq / Azure DevOps / ServiceNow | `LIVE=1 scripts/verify.sh live` |
| Package version + install smoke test                 | `scripts/verify.sh package`     |
| Deploy + seed the dev org                            | `scripts/setup-dev-org.sh`      |
| New scratch org (CI and phase 4 install test only)   | `scripts/new-scratch-org.sh`    |

### Environment notes (this machine)

- Run everything from the repo root. A shell started elsewhere
  fails with "not a valid Salesforce DX project".
- `gh` lives in `~/.local/bin`: prefix commands with `export PATH="$HOME/.local/bin:$PATH"`.
- Local npm 10 crashes resolving `@salesforce/sfdx-lwc-jest`. Install packages with
  `npx -y npm@11 install --save-dev <pkg>`; CI uses npm 11.
- Aliases: `ada-devhub` must point at the Dev Hub username (alias chains do not resolve);
  `ada-dev` is the dev org (the same Developer Edition org as the Dev Hub, D-12), also pointed
  at the Dev Hub username. Gates and quick commands target it. Always pass `--target-org`: this
  machine has other client orgs connected, and nothing here may touch them. Redeploy and
  reseed with `scripts/setup-dev-org.sh`.
- Format before gating: `npm run prettier`. The `static` gate fails on unformatted files.
- Quick deploy: `sf project deploy start --source-dir force-app --target-org ada-dev --wait 30`.
  Quick test: `sf apex run test --class-names <Class> --result-format human --wait 10 -o ada-dev`.
- macOS `sed` needs `sed -i ''`.
- Permission sets: custom metadata type access uses `customMetadataTypeAccesses`, not
  `objectPermissions` (those are silently dropped).
- Package source must not contain the string `ADA_Demo` or a literal `http(s)://` (invariant
  checks), including in test classes.
- The `step-reviewer` / `security-reviewer` subagents may fail with a model 404. Self-review the
  diff and note it in `PROGRESS.md`; retry later.
- Never commit `.vscode/`.

Gate logs land in `.verify/<timestamp>-<gate>/`; one summary line per run is appended to
`.verify/history.log`. Quote the log path in `PROGRESS.md`.

## Conventions

- Prefix every component with `ADA_` (objects, classes, metadata, permission sets, LWCs use `ada`).
- Apex: one responsibility per class; interfaces for anything external (`ADA_ILlmProvider`,
  `ADA_IMetadataIndexStore`, `ADA_IActionTarget`) so tests inject fakes.
- Tests: `<ClassName>Test`, `@IsTest`, Arrange/Act/Assert, `HttpCalloutMock` for every callout,
  `System.runAs` for permission cases. Target ≥ 85% coverage per class (package minimum is 75%).
- No `System.debug` left in package code except the golden harness marker.
- API version: use the latest the CLI supports; keep it the same across the project.
- Keep files small; prefer clear code over clever code. Comments explain _why_.
