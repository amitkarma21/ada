# Phase 0 report

**Outcome:** Tooling, scaffold, demo org and a captured golden set are in place; nothing in `force-app/` yet.

## Gate results
- 0.1 `doctor` PASS: `.verify/20261026-162142-doctor`
- 0.2 `static` PASS: `.verify/20261027-220419-static`; CI run 40493548233 green
- 0.3 `unit` PASS on a scratch org built from scratch by `scripts/new-scratch-org.sh`: `.verify/20261027-222502-unit`; CI run 40496190202 green
- Apex tests: 4 run, 0 failing (all in `demo-app/`). Coverage: not applicable, no package classes yet.
- LWC tests: none yet (`--passWithNoTests`).
- Golden set: 8 real cases (VALIDATION_RULE x3, FLOW, APEX, DUPLICATE_RULE, REQUIRED_FIELD, ACCESS) + 3 UNKNOWN. Accuracy and egress canary: from phase 1.

## Reviewers
- `step-reviewer` and `security-reviewer` could not run (subagent returned a 404 for its model). Diffs were self-reviewed. `force-app/` is empty, so there was nothing for the security reviewer to read. Re-run both on the phase 1 diff.

## Deviations and findings
See the step notes in `PROGRESS.md`. The ones that matter for phase 1:
- Flow Custom Error, Apex `addError` and validation rules all arrive as `FIELD_CUSTOM_VALIDATION_EXCEPTION` with no rule name in the message. The classifier must separate them by matching against the index, not by status code.
- The Account duplicate message is only "Use one of these records?", so the Duplicate matcher keys off `DUPLICATES_DETECTED` / that text plus active duplicate rules on the object.
- The access wording is long and has a double space; matchers must normalise whitespace.
- Local npm 10.9 cannot install the dev dependencies; use npm 11 (`npx -y npm@11 ...`).
- No new DECISIONS entries besides D-11 (extension idea, rejected).

## Risks for phase 1
- Step 1.2 is HUMAN (OAuth click for the self-org Tooling API credential).
- Step 1.6 live test needs a Groq key (not created yet; put it in the External Credential, never in files).
- Tooling API returns formula metadata one record per callout; step 1.3 must chain Queueables.

## Human must do before phase 1
- Review this report and say "go".
- Optional now: create a Groq API key (console.groq.com).
