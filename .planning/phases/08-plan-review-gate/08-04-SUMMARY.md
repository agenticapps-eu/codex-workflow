---
phase: 08-plan-review-gate
plan: 04
subsystem: infra
tags: [gsd, plan-review-gate, config-binding, agents-md, ritual-prose, codex-workflow]

# Dependency graph
requires:
  - phase: 08-plan-review-gate (08-01, 08-02)
    provides: "check-plan-review.sh verifier (resolver, grandfather guards, REVIEWS strictness, block message)"
  - phase: 08-plan-review-gate (08-03)
    provides: "codex-plan-review producer skill + ADR-0009"
provides:
  - "hooks.pre_execution.plan_review binding, byte-identical in .planning/config.codex.json and skills/setup-codex-agenticapps-workflow/templates/config-hooks.json"
  - "'## Pre-execution Gate — Plan Review (spec §02)' ritual section authored once in agents-md-additions.md and mirrored byte-identically (three-way diff) into AGENTS.md and skills/agentic-apps-workflow/SKILL.md"
  - "16-distinct-gate bindings table in all three surfaces (D-20 tdd collapse + plan-review row), matching spec/02"
  - "SKILL.md Step 3 gains a new Pre-execution group ahead of Pre-phase"
affects: [08-05, 08-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Declarative pre_execution hook group, fifth group alongside pre_phase/per_task/post_phase/finishing, carrying a verifier pointer key unique to this one gate (D-01 hybrid)"
    - "Single-source-of-truth ritual prose: authored once in agents-md-additions.md, mirrored via awk extract-to-tempfile + getline-from-file into AGENTS.md (inside its marker block) and appended to SKILL.md (its ritual-tail terminus, no marker) — proven by a three-way diff with a non-emptiness guard"
    - "Ritual always invokes, never teaches skip: skip/grandfather conditions described only as verifier behavior, not as an agent-facing decision procedure (T-08-32)"

key-files:
  created: []
  modified:
    - .planning/config.codex.json
    - skills/setup-codex-agenticapps-workflow/templates/config-hooks.json
    - skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md
    - AGENTS.md
    - skills/agentic-apps-workflow/SKILL.md

key-decisions:
  - "The trigger skill's plan-review binding row is written as a literal '| plan-review |' prefix (no backticks around the gate slug), diverging from that table's own backtick-wrapped-gate-slug convention elsewhere, because the plan's acceptance check greps for the literal unbacktick-wrapped prefix — a deliberate, narrow exception to local styling to satisfy an explicit mechanical check"
  - "SKILL.md's 'The 15 gates from spec/02...' intro prose was updated to '16 gates' since it is now directly contradicted by the table this task edits in the same file — a Rule 1 in-scope correction, not new scope"
  - "ROADMAP.md criterion 1 and its deviation notice were verified read-only and NOT edited — the amendment was already made during replanning (before execution), matching the plan's Part D contract"

requirements-completed:
  - "core spec §02 (plan-review gate) — declarative binding + invocation wiring"
  - "core spec §09 (conformance) — bind every applicable gate; 16 gates, not 15"

# Metrics
duration: 9min
completed: 2026-07-15
---

# Phase 08 Plan 04: Declarative binding + ritual wiring + 16-gate table Summary

**Bound `pre_execution.plan_review` declaratively in both config files, authored the always-invoke ritual section once and mirrored it byte-identically into AGENTS.md and the trigger SKILL.md, and corrected both bindings tables to 16 distinct gates (D-20 tdd collapse).**

## Performance

- **Duration:** ~9 min (task commits only; excludes read/verification time)
- **Started:** 2026-07-15T09:45:53+02:00 (base commit)
- **Completed:** 2026-07-15T09:54:41+02:00
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- `.planning/config.codex.json` and `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` both gained an identical `hooks.pre_execution.plan_review` block (`skill: codex-plan-review`, bare `${CODEX_HOME}`-rooted `verifier` path, `fires_when`, `evidence_artifact: <NN>-REVIEWS.md`, `min_reviewers: 2`, both escape hatches) — the two files still differ only in the two pre-existing, out-of-scope drifts (`implements_spec` and `per_task.tdd.strengthened_by`).
- `## Pre-execution Gate — Plan Review (spec §02)` authored once in `agents-md-additions.md` (the single source of truth) and mirrored byte-identically into `AGENTS.md` and `skills/agentic-apps-workflow/SKILL.md` — proven by a three-way `diff` with a non-emptiness guard. The ritual always invokes the verifier and describes skip/grandfather conditions only as verifier behavior, never as an agent-facing decision procedure (closing the T-08-32 self-inflicted-bypass risk).
- All three bindings tables (template, `AGENTS.md`, `SKILL.md` Step 3) now read 16 distinct gates: the duplicate `tdd` row collapsed to mirror `config-hooks.json`'s single-gate `strengthened_by` nesting, the template's combined brainstorm row split into two, and a leading `plan-review` row added to each.
- `skills/agentic-apps-workflow/SKILL.md` gained a new `### Pre-execution` group under `## Step 3` (ahead of `### Pre-phase`), mirroring the config's `pre_execution` becoming the first key of `hooks`.
- ROADMAP.md success criterion 1 and its deviation notice (naming ADR-0009, forbidding a closure claim on the original unconditional criterion) were verified present and unedited — Part D was a read-only guard, not a rewrite.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the pre_execution binding to both config files** - `2a164c7` (feat)
2. **Task 2: Author the ritual section, fix the gate table, and correct the enforcement claim** - `2ae3b67` (docs)
3. **Task 3: Mirror the section + table into AGENTS.md and the trigger SKILL.md** - `41da819` (docs)

_No separate plan-metadata commit yet — this SUMMARY.md is committed next (worktree mode: STATE.md/ROADMAP.md excluded, owned by the orchestrator after merge)._

## Files Created/Modified

- `.planning/config.codex.json` - gained `hooks.pre_execution.plan_review`
- `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` - gained the identical block (what fresh installs get)
- `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md` - single source of truth: new ritual section + 16-gate table (tdd collapse, brainstorm split, plan-review row)
- `AGENTS.md` - mirrored ritual section (inside the marker block) + 16-gate table (tdd collapse, plan-review row; brainstorm rows already separate)
- `skills/agentic-apps-workflow/SKILL.md` - mirrored ritual section (appended, no marker in this file) + new `### Pre-execution` Step-3 group + tdd collapse; `15 gates` intro prose corrected to `16 gates`; `version:` left untouched at `0.5.0`

## Decisions Made

See `key-decisions` in frontmatter above. All three were either locked by `08-CONTEXT.md`/the plan's own acceptance criteria, or a narrow in-scope Rule 1 correction (the SKILL.md gate-count prose). No new architectural decisions were made.

## Deviations from Plan

**1. [Rule 1 - Bug] Trigger skill's `plan-review` row initially used backticks around the gate slug, failing the plan's literal section-scoped grep**
- **Found during:** Task 3 verification (acceptance criterion: `awk '.../^\| plan-review/{print "in-group"}' skills/agentic-apps-workflow/SKILL.md` prints `in-group`)
- **Issue:** The row was written as `` | `plan-review` | ... `` to match this table's own existing convention (every other gate slug in `SKILL.md`'s Step 3 tables is backtick-wrapped), but the plan's acceptance check greps for a literal `^\| plan-review` prefix with no backtick, so the first draft produced no match.
- **Fix:** Reformatted the row to `| plan-review | ...` (no backticks around the slug), matching the literal check. This is a narrow, deliberate divergence from the table's local backtick convention for this one row, made to satisfy an explicit mechanical acceptance criterion rather than a judgment call.
- **Files modified:** `skills/agentic-apps-workflow/SKILL.md`
- **Verification:** Re-ran the exact awk one-liner from the plan → prints `in-group`; re-ran the "misplaced" check → prints nothing.
- **Committed in:** `41da819` (part of Task 3 commit — fixed before committing)

**2. [Rule 1 - Bug] `SKILL.md`'s "The 15 gates from spec/02..." intro sentence became false once Task 3 added the 16th (`plan-review`) gate to the same file's tables**
- **Found during:** Task 3, while editing `## Step 3 — Gate-to-skill bindings`
- **Issue:** The section's opening prose asserted "The 15 gates from spec/02-hook-taxonomy.md are bound..." immediately above tables that, after this task's edit, read 16 distinct gates — a direct, self-contradicting inconsistency introduced by this task's own change, not a pre-existing one.
- **Fix:** Changed "15 gates" to "16 gates" in that one sentence.
- **Files modified:** `skills/agentic-apps-workflow/SKILL.md`
- **Verification:** Table row count re-confirmed at 16 via the plan's own awk row-counting command; no other counts (`spec/09:61`'s "15 gates" bug, which is a different file, out of scope) were touched.
- **Committed in:** `41da819` (part of Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs, both Rule 1, both scoped strictly to files this task already modified)
**Impact on plan:** Neither changed scope or intent; both were required for the task's own acceptance criteria / internal consistency to hold.

## Issues Encountered

`bash migrations/run-tests.sh` initially failed with "agenticapps-shared submodule not initialized" — the worktree checkout did not include the `vendor/agenticapps-shared` submodule. Ran `git submodule update --init --recursive` (read-only environment setup, not a plan deviation) before running the suite; `git status`/`git diff --submodule` confirmed no tracked content changed as a result.

## User Setup Required

None - no external service configuration required. (Operator setup for `codex-plan-review`'s reviewer CLIs was already documented in `08-03-SUMMARY.md`.)

## Next Phase Readiness

- The gate is now bound declaratively in this repo's own config and in the template fresh installs get, and the ritual invocation exists in both always-loaded surfaces (`AGENTS.md`, trigger `SKILL.md`), byte-identical to the template — this is exactly the shape plan `08-05`'s migration `0008` needs to extract from and merge idempotently.
- Both bindings tables read 16 distinct gates, matching `spec/02`; the exact heading text, both table row shapes (`Scope` for the template vs `Applies to scaffolder?` for `AGENTS.md`), the collapsed `tdd` row, and the leading `plan-review` row are recorded above for `08-05` to read rather than re-derive.
- `bash migrations/run-tests.sh` is green: `layout` (35 PASS), `drift` (1 PASS), and the full suite (210 PASS / 2 SKIP / 0 FAIL — one SKIP is this worktree's environment lacking the adjacent `agenticapps-workflow-core` sibling repo, unrelated to this plan's edits; 0 FAIL either way).
- No GSD prompt (`prompts/`, `get-shit-done/`) was edited (D-04 held); no `hooks.json` was created or edited (D-02 held); nothing under `.planning/phases/0[0-7]/` was touched (D-18 held); `ROADMAP.md` was not modified (Part D verified it read-only).
- No blockers for plan `08-05`.

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: .planning/config.codex.json
- FOUND: skills/setup-codex-agenticapps-workflow/templates/config-hooks.json
- FOUND: skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md
- FOUND: AGENTS.md
- FOUND: skills/agentic-apps-workflow/SKILL.md
- FOUND: .planning/phases/08-plan-review-gate/08-04-SUMMARY.md
- FOUND commit: 2a164c7 (Task 1)
- FOUND commit: 2ae3b67 (Task 2)
- FOUND commit: 41da819 (Task 3)
- FOUND commit: bf57a41 (SUMMARY.md)
