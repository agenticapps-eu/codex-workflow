---
name: gsd-execute-phase
version: 0.1.0
implements_spec: 0.4.0
description: |
  Heavyweight wave-based phase executor. Reads PLAN.md, walks tasks
  in wave order, fires the applicable spec/02 gates per task and per
  phase, refuses to mark any task complete without `codex-verification`
  evidence, and runs the post-phase review pipeline (spec-review →
  code-review → security/qa/audits) before invoking
  `codex-finishing-branch`. Use after `$gsd-plan-phase` — typed as
  `$gsd-execute-phase {N}`. Explicit-only
  (`policy.allow_implicit_invocation: false`).
---

# gsd-execute-phase

This is the heaviest GSD entry-point skill — the orchestrator that
turns a plan into shipped code with conformant evidence.

## When to invoke

User types `$gsd-execute-phase {N}` after `$gsd-plan-phase {N}` has
authored PLAN.md (and the supporting artifacts). The phase's
CONTEXT.md and PLAN.md must exist; refuse to execute against a
missing PLAN.md and route to `$gsd-plan-phase` first.

## What this skill does

### Stage A — Pre-execute

1. **Load PLAN.md.** Parse the task list, wave plan, and gate
   triggers.
2. **Load CONTEXT.md.** Carry decisions and design alternatives into
   execution scope.
3. **Pre-flight skill check.** Verify every `codex-*` skill named in
   the plan is installed in `$CODEX_HOME/skills/`. Block if any
   missing.
4. **Pre-phase gates.** Fire any pre-phase gate that hasn't already:
   - `brainstorm-ui` / `brainstorm-architecture` if CONTEXT.md / RESEARCH.md
     lacks the alternatives section
   - `design-shotgun` if a UI plan has no UI-SPEC.md
   - `design-critique` if a UI plan has UI-SPEC.md but no critique

### Stage B — Wave execution

For each wave in the plan, in order:

5. **For each task in the wave:**
   - Emit the commitment-ritual block per the trigger skill's Step 0
     (canonical-prose verbatim from spec/01)
   - If `tdd="true"`: invoke `codex-tdd` to produce the RED+GREEN
     commit pair
   - If the task is UI-touching: invoke `codex-qa` in `mode=preview`
     to produce the screenshot + commit reference
   - Write the task's must_have and Evidence subrows into
     `VERIFICATION.md`
   - Invoke `codex-verification` BEFORE marking the task complete.
     Refuse completion if any must_have lacks Evidence.
   - Commit atomically per task with a clear commit message.

### Stage C — Post-phase gates

6. **Stage 1 review** — invoke `codex-spec-review`. Block on outcome
   `gap`; fix or accept-via-ADR before continuing.
7. **Stage 2 review** — invoke `codex-code-review`. The skill spawns
   an independent reviewer via `codex exec` per ADR-0002. Block on
   verdict `block`.
8. **Security gate** if the phase's diff touches auth / storage /
   request handling / secrets / LLM trust boundaries — invoke
   `codex-cso`. If DB-touching, also invoke
   `codex-database-sentinel-audit` (in phase-scoped mode). Block on
   Critical/High DB findings; accept via the database-security
   acceptance ADR pattern.
9. **QA gate** if a dev server is reachable and the phase ships
   user-visible behavior — invoke `codex-qa` in `mode=phase-qa`.
   Block on `block` verdict.
10. **Impeccable audit** if the phase's diff modifies a shipping UI
    surface — invoke `codex-impeccable-audit`. Block on Red
    findings; accept via ADR.

### Stage D — Finishing

11. **Branch close** — invoke `codex-finishing-branch`. The skill
    composes the PR description from the phase artifacts, opens the
    PR, and updates the phase summary.

## Output

After `$gsd-execute-phase` completes, the phase directory contains:

- `CONTEXT.md` (from discuss)
- `PLAN.md` (from plan)
- `RESEARCH.md`, `UI-SPEC.md` (where applicable)
- `VERIFICATION.md` with every must_have + Evidence
- `REVIEW.md` with Stage 1 + Stage 2 sections
- `SECURITY.md` (where the security gate fired)
- `DB-AUDIT.md` (where database-security fired)
- `QA.md` (where qa fired)
- `IMPECCABLE-AUDIT.md` (where impeccable-audit fired)
- A merged PR linking all of the above

Plus the actual shipped code on a feature branch + opened PR.

## Failure modes

- **Skipping the commitment block per task.** Spec/01 requires it as
  the first user-facing output of every code-touching turn — that
  includes every wave-step task here. The trigger skill's Step 0 is
  the canonical block.
- **Marking tasks complete without `codex-verification`.** This is
  the most common LLM failure mode (per spec/06); the executor
  refuses completion without evidence.
- **Collapsing Stage 1 + Stage 2 review.** Spec/07 requires
  separate agent contexts. `codex-code-review` enforces the
  independence via `codex exec`.
- **Stopping at Stage 2 if it blocks.** Block-verdict review fires
  fix → both stages re-run. Stage 2 is not optional.
- **Opening the PR before the audits clear.** `codex-finishing-branch`
  refuses to open if any blocking gate has unfixed/unaccepted
  findings.

## Notes for the Codex host

- v0.1.0 runs waves sequentially. Parallel wave execution via
  `codex exec` subagent fan-out is a v0.2.0 enhancement.
- The post-phase pipeline (Stages C and D) fires in dependency
  order: spec-review precedes code-review; security/qa/audits run in
  parallel after Stage 2; finishing-branch runs last.
- If any stage produces a blocking verdict that the user explicitly
  accepts (e.g. via ADR override), record the override path and
  re-run the relevant stages to confirm acceptance is durable.
