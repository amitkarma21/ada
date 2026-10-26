---
name: phase-gate
description: End-of-phase checkpoint for the ADA build. Runs the full gate, both reviewers and the phase demo, writes a report, then stops for human approval.
argument-hint: "<phase number>"
disable-model-invocation: true
---

Phase gate for phase $ARGUMENTS.

1. Confirm every step in the phase is `DONE` in `PROGRESS.md`. If not, list what's open and stop.
2. Run the highest gate the phase requires (see the phase's "Phase gate" line in
   `docs/IMPLEMENTATION_PLAN.md`), on a **fresh scratch org** (`scripts/new-scratch-org.sh`) so
   nothing depends on leftover state.
3. Run `security-reviewer` on all of `force-app/`, and `step-reviewer` on the phase's full diff
   (`git diff <phase start commit>..HEAD`).
4. Run the phase demo script listed in the plan and capture what the user would see.
5. Write `docs/reports/phase-<n>.md`:
   - Outcome in one sentence.
   - Gate results with log paths; Apex coverage (org-wide and lowest class); LWC test count.
   - Golden-set accuracy (from phase 1 on) and egress canary result.
   - Reviewer verdicts and what was fixed.
   - Deviations from the plan and new DECISIONS entries.
   - Risks for the next phase and anything the human must do.
6. Add a line to the Phase log in `PROGRESS.md`: `Phase <n> — awaiting human approval`.
7. Stop. Tell the human the report path and ask for "go" before the next phase.
