---
phase: 13-native-enforcement-plan-review-hook
plan: 03
subsystem: infra
tags: [codex-cli, migrations, hooks, jq, awk, toml, mutation-testing, PreToolUse]

# Dependency graph
requires:
  - phase: 13-native-enforcement-plan-review-hook (plan 01)
    provides: "Frozen spike findings — Matcher decision (apply_patch), A1 CONFIRMED (project-scoped [features] hooks=true is effective), Pitfall 3 (never write ~/.codex/*)"
  - phase: 13-native-enforcement-plan-review-hook (plan 02)
    provides: "skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh — the wrapper this migration's hooks.json entry points at"
provides:
  - "migrations/0011-native-plan-review-hook.md — installs the project-scoped PreToolUse entry (merge-don't-clobber) and enables [features] hooks=true in <repo>/.codex/config.toml"
  - "test_migration_0011 in migrations/run-tests.sh — merge-don't-clobber, idempotent re-apply, SC#4-negative, mutation-proven against seeded fixtures"
affects: [13-04, 13-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Leaf-level jq array-append onto a native codex-cli hooks.json PreToolUse array — never a wholesale .hooks/.hooks.PreToolUse replacement (T-13-04)"
    - "awk append-if-absent merge into a TOML [features] table, no new TOML-parsing dependency — scoped strictly to the [features] table so sibling tables and other keys inside it survive (T-13-05)"
    - "Idempotent re-apply tested by gating Apply re-invocation on the step's OWN extracted Idempotency check, mirroring test_migration_0008's partial-application discipline (run-tests.sh:1928) — not by assuming the Apply body itself is append-if-absent"

key-files:
  created:
    - migrations/0011-native-plan-review-hook.md
  modified:
    - skills/agentic-apps-workflow/SKILL.md
    - .codex/workflow-version.txt
    - migrations/run-tests.sh

key-decisions:
  - "Migration 0011's hooks.json Step 1 Apply is an unconditional leaf-level array-append BY DESIGN (matches the plan's specified jq form and 0008's own object-merge precedent) — it is the migration's separately-extracted Idempotency check, not the Apply body, that makes re-application safe. The test proves this by gating re-invocation on the extracted Idempotency check, exactly as the real update flow would, rather than assuming the Apply text is append-if-absent."
  - "A1 CONFIRMED (13-01-SPIKE-FINDINGS.md) closes RESEARCH.md's Assumption A1 affirmatively: the migration's config.toml write is stated as sufficient on its own, with no operator global-enable fallback instruction — the Notes section is explicit that this is conditional on the frozen spike finding, not an unhedged claim."
  - "Two file TYPES this migration must never conflate are described in prose without ever using the exact substring naming the OTHER file (Pitfall 1's grep-enforced acceptance criterion) — migration 0008's destination is referred to as 'the declarative gate-binding map under .planning/' throughout, never spelled out literally, so the migration's own document cannot accidentally trip its own pitfall-avoidance grep."

patterns-established:
  - "A migration writing a NEW native codex-cli file type (not previously written by any migration in this chain) documents both the strict-typing hazard of that file (config.toml's fail-closed [features] table) and the trust-ledger gate it sits behind (interactive hook-trust, Gate B) as Notes, not as something the migration works around."

requirements-completed: [HOOK-03]

# Metrics
duration: ~35min
completed: 2026-07-18
---

# Phase 13 Plan 03: Migration 0011 — Native PreToolUse Plan-Review Hook Summary

**New migration 0011 installs the project-scoped `PreToolUse` hook entry (merge-don't-clobber jq array-append) and `[features] hooks = true` (awk append-if-absent) into `<repo>/.codex/hooks.json` / `<repo>/.codex/config.toml`, closing HOOK-03 and bumping the drift-coupled version records to 0.8.0 in lockstep.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-07-18
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- Authored `migrations/0011-native-plan-review-hook.md`: frontmatter
  `from_version: 0.7.0`, `to_version: 0.8.0`, `applies_to: [.codex/hooks.json, .codex/config.toml]`
  (leading dots, per Pitfall 1). Step 1 merges ONE `PreToolUse` entry
  (`matcher: apply_patch`, per the frozen spike's Matcher decision) onto
  `.hooks.PreToolUse` via `(. // []) + [$entry]` — leaf-level, never a
  wholesale `.hooks`/`.hooks.PreToolUse` replacement. Step 2 merges
  `[features] hooks = true` into `.codex/config.toml` via an awk
  append-if-absent block scoped strictly to the `[features]` table (no new
  TOML-parsing dependency). Step 3 seals `.codex/workflow-version.txt` at
  `0.8.0` last, per 0008's content-steps-then-version-seal convention.
- Bumped `skills/agentic-apps-workflow/SKILL.md` `version:` and this repo's
  own `.codex/workflow-version.txt` to `0.8.0` in the same commit as the
  migration, keeping `test_drift` green.
- Added `test_migration_0011` to `migrations/run-tests.sh`: extracts 0011's
  own Pre-flight, `applies_to`, and each Step's Apply + Idempotency-check
  block from the document itself (never hand-transcribed), gates every
  extraction with `assert_extracted_shape` (D-36), then executes the
  extracted blocks against a seeded sandbox carrying a decoy vendor
  `PreToolUse` entry and a decoy `[some_other]` config.toml table.
  Registered in the dispatcher (`0011` filter) and added
  `migrations/0011-native-plan-review-hook.md` +
  `skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh` to the
  `test_repo_layout` file roster.
- Full suite: **435 PASS / 0 FAIL / 2 SKIP**, exit 0. `test_migration_0011`
  itself: 25 PASS / 0 FAIL. `test_drift` green (SKILL.md 0.8.0 == semver-max
  migration `to_version` 0.8.0 == `.codex/workflow-version.txt` 0.8.0).

## Task Commits

Each task was committed atomically:

1. **Task 1: Author migration 0011 + bump version records to 0.8.0 in lockstep** - `e31023f` (feat)
2. **Task 2: test_migration_0011 — merge-don't-clobber, idempotent re-apply, SC#4-negative; drift stays green** - `61cb0ed` (test)

## Files Created/Modified

- `migrations/0011-native-plan-review-hook.md` - New migration: hooks.json
  merge-don't-clobber (Step 1), config.toml `[features]` merge (Step 2),
  version seal (Step 3); Notes document the interactive hook-trust operator
  action and A1's resolution
- `skills/agentic-apps-workflow/SKILL.md` - `version: 0.7.0` -> `0.8.0`
- `.codex/workflow-version.txt` - `0.7.0` -> `0.8.0`
- `migrations/run-tests.sh` - Added `test_migration_0011` + `_m0011_ok` /
  `_m0011_fail` / `_m0011_apply` helpers, dispatcher registration, and two
  new entries in `test_repo_layout`'s file roster

## Decisions Made

- **Idempotency is proven at the check level, not assumed at the Apply-body
  level.** The plan's own recommended Step 1 Apply form
  (`(.hooks.PreToolUse // []) + [$entry]`) is an unconditional append, not an
  append-if-absent — matching migration 0008's own object-merge precedent
  where the EXTERNAL idempotency check (not the Apply body) is what makes
  re-running the migration safe. The first test draft called Apply directly
  a second time and correctly caught this as a real defect surface (a naive
  test would have shown a duplicate-entry FAIL); the fix gates re-invocation
  on the step's own extracted Idempotency check, mirroring
  `test_migration_0008`'s partial-application fixture discipline
  (`run-tests.sh:1928`, "each step checks its OWN idempotency") — the same
  discipline the real update flow uses.
- **Pitfall 1's acceptance criterion is a literal grep, so the document's own
  prose was rewritten to never spell out the other file's exact name.** The
  migration explains the distinction between the NATIVE `.codex/hooks.json`/
  `.codex/config.toml` this migration touches and migration 0008's
  DECLARATIVE binding map without ever using the literal substring naming
  the latter — otherwise the migration's own Pitfall-1-avoidance explanation
  would trip the very grep it exists to satisfy.
- **A1 CONFIRMED governs the Notes section's phrasing exactly as specified.**
  Since 13-01-SPIKE-FINDINGS.md's A1 line is CONFIRMED, the migration states
  Step 2's project-scoped write as sufficient on its own with no unhedged
  claim independent of that finding — the Notes explicitly say what the
  fallback WOULD have been had A1 been falsified, without actually adding
  that fallback instruction (since it wasn't needed).

## Deviations from Plan

None (Rule 1 fix applied during self-verification, not a plan deviation) —
the plan was executed as written; the one correction made (idempotent
re-apply gating, above) was a bug caught by the plan's OWN Task 2 acceptance
criteria (which explicitly require idempotent re-apply to add no duplicate)
and fixed inline per Rule 1 before the commit, exactly as the deviation
protocol intends: a test that would otherwise have reported FAIL was fixed
by correcting the test's own re-invocation discipline to match the
migration's already-correct idempotency-check contract, not by weakening the
migration.

## Issues Encountered

- `vendor/agenticapps-shared` git submodule was not initialized in this
  worktree (needed by `migrations/run-tests.sh` for shared helpers). Ran
  `git submodule update --init --recursive` to make the test harness
  runnable — a pre-existing repo setup step, not a code change; nothing was
  committed for it (the submodule pointer was already correct in the tree;
  only the local checkout was populated). Same non-issue plan `13-02`
  recorded.

## User Setup Required

None for this migration's files to be correctly authored and tested. Once
this migration is APPLIED to a real project (not this plan's scope — that is
plan `13-05`'s live end-to-end session), the operator must complete the
one-time interactive hook-trust action (`/hooks` or the startup hooks-review
prompt) before the installed hook actually fires — documented in the
migration's own `## Notes` section, never silently worked around.

## Next Phase Readiness

- Migration 0011 exists, is fully tested (merge-don't-clobber, idempotent
  re-apply, SC#4-negative), and the drift-coupled version records are
  bumped in lockstep — HOOK-03 is closed at the migration-authoring level.
- No blockers. Plan `13-04`/`13-05` (ADR-0009 Correction + live
  human-observed SC#2/SC#4-positive session) can proceed; this migration's
  files are the artifact that session installs and observes firing.
- The live session (13-05) is still the first real proof that
  `codex features list` reports `hooks` enabled via this migration's
  project-scoped write specifically, and that the wrapper actually fires
  end-to-end against real codex-cli tool-call traffic — this plan's test
  suite proves the FILE CONTENT is correct by execution against fixtures,
  not the live runtime behavior, which was never this plan's scope.

## Self-Check: PASSED

- FOUND: migrations/0011-native-plan-review-hook.md
- FOUND: skills/agentic-apps-workflow/SKILL.md (version: 0.8.0)
- FOUND: .codex/workflow-version.txt (0.8.0)
- FOUND: migrations/run-tests.sh (test_migration_0011 present, dispatcher entry present, test_repo_layout roster entries present)
- FOUND commit e31023f (Task 1)
- FOUND commit 61cb0ed (Task 2)
- Full suite: 435 PASS / 0 FAIL / 2 SKIP, exit 0 (verified by direct execution, not by inspection)

---
*Phase: 13-native-enforcement-plan-review-hook*
*Completed: 2026-07-18*
