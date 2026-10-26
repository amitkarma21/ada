# ADA — Admin Deflection Agent

A Salesforce managed package that answers "why can't I save this record?" from org metadata,
raises Azure DevOps bugs and email-approved access requests, with no Agentforce licence and no
record data leaving the org. Built step by step with Claude Code, with a test gate after every
step.

## What's in this kit

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | Rules Claude Code follows: invariants, the build loop, course correction |
| `PROGRESS.md` | Step tracker with evidence; Claude Code updates it every step |
| `docs/IMPLEMENTATION_PLAN.md` | 19 steps in 5 phases, each with acceptance criteria and a gate |
| `docs/ARCHITECTURE.md` | Components, runtime flow, diagnosis rules, outbound data contract |
| `docs/TEST_STRATEGY.md` | Test layers, thresholds, golden set, egress canary, CI |
| `docs/SETUP.md` | Free accounts and tools, and the per-scratch-org human steps |
| `docs/DECISIONS.md` | Decisions made so far; Claude Code proposes changes here |
| `.claude/skills/next-step` | `/next-step` — runs one step through the full loop |
| `.claude/skills/phase-gate` | `/phase-gate <n>` — end-of-phase checkpoint and report |
| `.claude/agents/` | `step-reviewer` and `security-reviewer` subagents |
| `scripts/verify.sh` | The gates: `doctor`, `static`, `unit`, `e2e`, `live`, `package` |
| `.github/workflows/ci.yml` | `static` on every push; org tests on demand and nightly |

## How to start

1. Create an empty GitHub repo, copy this kit into it, commit and push.
2. Do the account setup in `docs/SETUP.md` §1–6 (all free).
3. Open the repo in Claude Code and paste:

   > Read CLAUDE.md, docs/IMPLEMENTATION_PLAN.md and PROGRESS.md. Confirm you understand the
   > build loop and the invariants in five lines, then tell me what I need to do for step 0.1.

4. After step 0.1, run `/next-step` for each step. Claude Code stops at HUMAN steps, at blockers
   and at the end of each phase (`/phase-gate`). Review the phase report in `docs/reports/`
   and reply "go" to continue.

## How course correction works

- Every step must pass its gate and a reviewer before it's marked done, and CI must be green
  before the next step starts.
- Three failed attempts on a step, or a wrong assumption in the plan, stops the build with a
  written blocker or a `PROPOSED` decision for you.
- Every gate run is logged in `.verify/history.log`, and each phase ends with a report showing
  coverage, golden-set accuracy and the egress canary result.
