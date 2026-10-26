---
name: next-step
description: Runs exactly one ADA build step through the full loop (plan, test first, implement, gate, fix, review, record, commit). Use when continuing the build.
argument-hint: "[step-id, optional — defaults to the next step not DONE]"
disable-model-invocation: true
---

Run ONE build step through the loop in `CLAUDE.md`. Step requested: $ARGUMENTS
(if empty, take the first step in `PROGRESS.md` that is not `DONE`).

1. **Check preconditions.**
   - Previous step is `DONE` and its commit's CI run is green (`gh run list --limit 1`).
     If CI is red or unknown, stop and say so.
   - If this step is marked **HUMAN**, list exactly what the person must do (links, clicks,
     values to paste into which External Credential) and stop.
   - If the step is first in a new phase, confirm the human approved the previous phase gate
     (`PROGRESS.md` → Phase log). If not, stop.

2. **Plan.** Re-read the step's acceptance criteria in `docs/IMPLEMENTATION_PLAN.md` and the
   relevant sections of `docs/ARCHITECTURE.md`. Write 3–6 plan bullets under the step in
   `PROGRESS.md` and set it to `IN PROGRESS`.

3. **Test first.** Add or extend tests that prove each acceptance criterion. Name each
   test after the criterion it proves.

4. **Implement** the smallest change that passes them. Respect every invariant.

5. **Gate.** Run `scripts/verify.sh <gate named in the step>`.
   - Fail → read the log in `.verify/<latest>/`, find the root cause, fix, re-run.
   - Count attempts. After 3 failures: set the step to `BLOCKED`, write the blocker, the
     evidence and 2–3 options in `PROGRESS.md`, and stop for the human.
   - If the cause is a wrong plan assumption, add a `PROPOSED` entry to `docs/DECISIONS.md`
     and stop.

6. **Review.** Run the `step-reviewer` subagent. If the step is tagged `security`, also run
   `security-reviewer`. Fix every "must fix", then re-run the gate.

7. **Record** in `PROGRESS.md`: status `DONE`, gate result, test count, coverage %, log folder,
   reviewer verdicts, deviations.

8. **Commit** `step <id>: <summary>` and push. Watch CI (`gh run watch`). If CI fails, treat
   it as a gate failure and go back to step 5.

9. **Report** to the human in 5 lines or fewer: what was built, gate result, coverage, anything
   they need to do, and the next step's id. If the step was the last in its phase, say that
   `/phase-gate <phase>` is next and stop.
