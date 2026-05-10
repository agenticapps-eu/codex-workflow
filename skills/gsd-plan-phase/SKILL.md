---
name: gsd-plan-phase
version: 0.1.0
implements_spec: 0.1.0
description: |
  Run the GSD plan step for a phase: read CONTEXT.md, author PLAN.md
  (the task list with gate triggers and must_haves), and produce the
  supporting artifacts the phase needs (RESEARCH.md for architecture
  alternatives, UI-SPEC.md for chosen UI variants). Use after
  `$gsd-discuss-phase` has produced CONTEXT.md — typed by the user as
  `$gsd-plan-phase {N}`. Explicit-only
  (`policy.allow_implicit_invocation: false`).
---

# gsd-plan-phase

This is the second GSD entry-point skill. It transforms the
discussion output into the executable plan that `$gsd-execute-phase`
consumes.

## When to invoke

User types `$gsd-plan-phase {N}`. The phase's CONTEXT.md must already
exist (from `$gsd-discuss-phase`) — refuse to plan against a phase
with no CONTEXT.md and route the user to `$gsd-discuss-phase {N}`
first.

## What this skill does

1. **Read upstream artifacts.**
   - `ROADMAP.md` for the phase's stated goal
   - `.planning/phases/<NN>/CONTEXT.md` for resolved questions and
     decisions
   - Prior phases' artifacts for any cross-phase dependencies
2. **Decompose into tasks.** Each task is small enough for one
   commitment-ritual cycle. Granularity rule: a task that takes more
   than ~30 minutes of agent attention should split.
3. **For each task, name:**
   - One-line goal
   - Files (or surfaces) it touches
   - Whether `tdd="true"` applies (any task with logic verifiable by
     automated test)
   - Which gates from spec/02 fire on this task or on the phase as a
     whole
   - Must_haves (the verifiable outcomes that must be true after
     this task ships)
4. **Identify gate triggers.** Per spec/02, walk:
   - Pre-phase: brainstorm-ui, brainstorm-architecture, design-shotgun,
     design-critique
   - Per-task: tdd, ui-preview, verification (always)
   - Post-phase: spec-review, code-review (always), security,
     database-security, qa, impeccable-audit, db-pre-launch-audit
   - Finishing: branch-close (always)

   For each gate that fires, name the bound `codex-*` skill in the
   plan. The trigger skill's Step 3 binding table is the source.
5. **Author PLAN.md** at `.planning/phases/<NN>/PLAN.md`:

   ```markdown
   # Phase {{N}} — Plan

   Goal: {{from ROADMAP.md}}
   Spec version: 0.1.0
   Context: see CONTEXT.md

   ## Tasks

   ### Task 1 — {{one-line goal}}
   - Touches: {{files / surfaces}}
   - tdd: {{true | false}}
   - Gates: {{list}}
   - must_have:
     - {{verifiable outcome 1}}
     - {{verifiable outcome 2}}
   - should_have:
     - {{nice-to-have, not blocking}}

   ### Task 2 …

   ## Gates (phase-level)

   | Gate | When fires | Bound skill |
   |---|---|---|
   | spec-review | always (post-phase) | codex-spec-review |
   | code-review | always (post-phase) | codex-code-review |
   | security | {{condition}} | codex-cso |
   | … | … | … |

   ## Wave plan

   - Wave 1 (parallelizable): Task 1, Task 2
   - Wave 2 (depends on wave 1): Task 3
   - Wave 3: Task 4

   ## Verification

   See VERIFICATION.md (authored by `$gsd-execute-phase` per task).
   ```
6. **Author supporting artifacts as needed.**
   - `RESEARCH.md` if any task introduces a new service / model /
     integration / data shape and CONTEXT.md doesn't already have an
     "Architecture alternatives" section. Invoke
     `codex-brainstorming` in architecture mode.
   - `UI-SPEC.md` if the phase ships a new UI surface. Route to
     `codex-design-shotgun` first if no chosen variant exists yet.
7. **Pre-flight check** for skill availability. Walk the phase's
   gate list and verify each bound `codex-*` skill is installed in
   `$CODEX_HOME/skills/`. Surface any missing skills before the user
   moves to execute — fixing later wastes a wave.

## Output

`.planning/phases/<NN>/PLAN.md` plus any supporting RESEARCH.md /
UI-SPEC.md. The next step is `$gsd-execute-phase {N}`, which walks
the tasks in the wave plan.

## Failure modes

- **Authoring PLAN.md without CONTEXT.md.** Refuse and route to
  `$gsd-discuss-phase` — planning without context produces plans
  that drift from intent.
- **Tasks too large to fit one commitment-ritual cycle.** Split.
- **Skipping the pre-flight skill check.** Discovering a missing
  `codex-cso` mid-phase blocks execution and forces a skill install
  in flight; cheaper to catch up front.
- **Treating PLAN.md as immutable.** Plans drift; if execution
  surfaces a discrepancy, return to plan, update PLAN.md, then
  resume execute.

## Notes for the Codex host

- Wave plan is the unit of parallelism. Codex's subagent surface
  (per ADR-0002, via `codex exec`) makes wave-1 tasks parallelizable
  if the project's filesystem isolation allows it. v0.1.0 keeps wave
  execution sequential by default; parallel waves are a v0.2.0
  enhancement.
- The pre-flight skill check is `ls -d $CODEX_HOME/skills/codex-*`
  and a comparison against the gate list.
