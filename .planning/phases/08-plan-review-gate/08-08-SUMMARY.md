---
phase: 08-plan-review-gate
plan: 08
subsystem: testing
tags: [bash, awk, tdd, gap-closure, plan-review-gate, migration-correctness]

# Dependency graph
requires:
  - phase: 08-plan-review-gate
    provides: "Migration 0008 Step 3's bindings-table corrections (08-05/08-06) and its idempotency/atomicity contract; 08-07's CR-01/WR-01 fixes to check-plan-review.sh (unrelated file, same phase)"
provides:
  - "Migration 0008 Step 3's plan-review-row insertion correlated with the already-validated '| Gate |' bindings-table header, instead of firing on the first '|---' line anywhere in AGENTS.md"
  - "Decoy-table regression fixture (AGENTS.md.decoy-table) in test_migration_0008 proving the row lands in the correct table when an unrelated Markdown table precedes the bindings table"
  - "Both copies of the awk (migrations/0008-plan-review-gate.md and all 4 inline occurrences in migrations/run-tests.sh) kept logically identical"
affects: [08-plan-review-gate verification re-run, any downstream project whose AGENTS.md carries a Markdown table before its gate-bindings table]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Header-flag correlation in awk: set a boolean when the already-validated header line is seen, then gate the structural match (the separator) on that boolean, rather than matching the structural pattern unconditionally. Keeps the fix local to the awk pass with no second grep whose result could drift from the shape guard above it."
    - "Line-number integer comparison over an awk range one-liner for a 'X happened after Y' regression assertion — trivially verifiable by eye, per the plan's explicit anti-vacuous-pass guidance."

key-files:
  created: []
  modified:
    - "migrations/0008-plan-review-gate.md"
    - "migrations/run-tests.sh"

key-decisions:
  - "Fixed all 4 inline occurrences of the awk in run-tests.sh (apply, second-run no-op re-check, the new decoy-table apply, and the wrong-shape decline path), not just the one the plan's <interfaces> block cited by line number — the awk is duplicated more than twice within run-tests.sh itself, and leaving any copy unfixed would make part of the suite exercise stale logic while claiming coverage."
  - "Reused the exact production apply block (same awk, same template-sourced row variables) for the new decoy-table fixture rather than authoring a parallel copy, so the RED fixture is provably testing the real Step 3 logic, not a stand-in."
  - "Self-guard checks the fixture's own shape (first '|---' precedes '| Gate |') independently of the fix, so it passes in both RED and GREEN — it is a fixture-rot guard, not a WR-02 assertion."

requirements-completed:
  - "core spec §02 (plan-review gate) — the migration must land the plan-review binding in the bindings table it validated"
  - "core spec §09 (conformance) — a migrated install's bindings table must equal a fresh install's"

# Metrics
duration: ~10min
completed: 2026-07-15
---

# Phase 8 Plan 08: Close WR-02 Migration 0008 Table-Insertion Misinsertion Summary

**Correlated migration 0008 Step 3's plan-review row insertion with its own already-validated `| Gate |` header (instead of the first `|---` line in the file) in both copies of the awk, closing a self-sealing silent-corruption defect reproduced during gap-closure planning.**

## Performance

- **Duration:** ~10 min (RED commit 11:46:47 CEST, GREEN commit 11:48:55 CEST)
- **Tasks:** 2 (RED, GREEN)
- **Files modified:** 2 (`migrations/run-tests.sh`, `migrations/0008-plan-review-gate.md`)

## Accomplishments

- WR-02 closed and upgraded from "suspected/code-inspection-only" (08-REVIEW.md) to reproduced-and-fixed: migration 0008 Step 3's bindings-table awk now only inserts the `plan-review` row into the table whose `| Gate |` header it already validated, never into an unrelated Markdown table that happens to precede it in a target repo's `AGENTS.md`.
- Added a decoy-table fixture (`AGENTS.md.decoy-table`) to `test_migration_0008`: an unrelated `| Tool | Purpose |` table prepended before the same realistic pre-0008 bindings table the existing `AGENTS.md.scope-shaped` fixture uses. Four new assertions: a self-guard pinning the fixture's own shape, a line-number comparison proving the row lands after the `| Gate |` header, a zero-count check that no plan-review line appears before that header, and the existing 16-row/16-distinct-gate post-condition reused against this new fixture.
- Confirmed the RED failure was the actual WR-02 defect (not an incidental failure): the plan-review row landed at line 7, inside the decoy table, before the `| Gate |` header (which itself shifted from line 12 to line 13 because of the misinsertion above it); the bindings table stayed at 15/15 instead of reaching 16/16.
- Fixed the awk identically in both places the plan's `<interfaces>` cited (`migrations/0008-plan-review-gate.md` and the mirror in `migrations/run-tests.sh`) — and additionally in the two OTHER inline copies of the same awk that already existed inside `run-tests.sh` (the second-run no-op re-check for the scope-shaped fixture, and the wrong-shape-decline path), so no copy inside the test file itself is left exercising stale logic.
- Updated the migration doc's prose to explain the correlation and why it matters: an unrelated earlier table would otherwise silently absorb the row, and Step 3's own idempotency check (`grep -q '^| plan-review' AGENTS.md`) would then find the misplaced row on every future run and mark the step permanently applied — masking the miss forever (the self-sealing property the plan's objective called out).

## Task Commits

Strict RED -> GREEN TDD gate sequence, verified in git log (`test(...)` precedes `feat(...)`):

1. **Task 1: RED — decoy-table fixture reproduces WR-02 misinsertion** - `a7b2c0f` (test)
2. **Task 2: GREEN — correlate Step 3 insertion with validated bindings header** - `764f877` (feat)

_No metadata-only commit yet — this SUMMARY.md is committed separately below per worktree protocol._

## Files Created/Modified

- `migrations/run-tests.sh` - Added the `AGENTS.md.decoy-table` fixture and its 4 assertions to `test_migration_0008` (self-guard, post-insertion line-number check, before-header zero-count check, 16/16 row-and-gate-count reuse via `_table_data_rows`). Fixed all 4 inline copies of the Step 3 awk (`/^\| Gate \|/ { seen_hdr=1 }` added; separator match gated on `seen_hdr && !ins_pr`).
- `migrations/0008-plan-review-gate.md` - Fixed the documented Step 3 awk identically to the test's copy; extended the surrounding prose to name the WR-02 defect, its self-sealing interaction with the idempotency check, and why gating on the validated header (rather than a second independent grep) keeps the correlation local.

## Decisions Made

- **All 4 inline awk copies in `run-tests.sh` were fixed, not just the one line-numbered in the plan's `<interfaces>` block.** The plan's interfaces section cited `run-tests.sh:1143-1153` as "the" mirror, but by the time of execution the file already contained the identical awk snippet 3 times (apply, second-run no-op re-check, wrong-shape decline path) before this plan's own 4th addition (the decoy-table apply). Fixing only the cited copy would have left 2 pre-existing copies exercising the old, buggy correlation-free logic — meaning the "second run is a no-op" and "wrong-shape declines" assertions would still be passing against stale logic even though they happened to still pass (their outcomes don't depend on the header-gating in those specific scenarios, but leaving them unfixed would be a latent inconsistency the D-19 single-source-of-truth lesson this phase keeps citing exists to prevent).
- **The new fixture's transform reuses the exact production variables** (`$row_plan_review`, `$row_brainstorm_ui`, `$row_brainstorm_arch`, `$row_tdd`, already extracted from the template earlier in the same test function) rather than re-extracting or hardcoding them, so the decoy-table fixture is provably running the same logic as the scope-shaped fixture and the real migration step, not a parallel stand-in that could drift.
- **Self-guard was placed BEFORE the transform runs**, checking the fixture's pre-transform shape (first `|---` line number less than `| Gate |` header line number) — this makes it a fixture-rot guard that passes in both RED and GREEN, distinct from the WR-02 assertions themselves which only pass post-fix.

## Deviations from Plan

None from the plan's stated tasks and behavior. One scope expansion within Rule 1 (auto-fix bugs) is documented above under "Decisions Made": the plan's `<interfaces>` block named one occurrence of the run-tests.sh mirror by line range, but 3 additional identical occurrences existed in the same file (2 pre-existing, 1 newly added by this plan's own Task 1); all 4 were fixed together to keep the mirror actually mirrored, per the plan's own explicit instruction to "keep them logically identical."

Environment note (not a plan deviation): this worktree's `vendor/agenticapps-shared` git submodule was uninitialized at session start (`run-tests.sh` failed immediately with "submodule not initialized"). Ran `git submodule update --init --recursive` to check it out at its already-pinned commit — this is a local checkout operation reading the existing `.gitmodules` pin, not a change to any tracked file, and left the working tree clean (confirmed via `git status --short` before the first commit).

## Issues Encountered

None beyond the submodule checkout noted above. The RED failure was verified to be the WR-02 defect itself (row misinserted into the decoy table, header line shifted, bindings table short of 16/16) rather than an incidental fixture-authoring mistake, per the plan's Task 1 `<action>` requirement.

## GitNexus / Blast Radius

GitNexus MCP tools (`gitnexus_impact`, `gitnexus_detect_changes`) were not available in this executor's toolset, and running `npx gitnexus analyze` was explicitly prohibited for this session (regenerates untracked project files and blocks the orchestrator's automated merge). Performed the equivalent check manually: `grep -rn "ins_pr\b"` across the repo (excluding `vendor/`) confirms the touched awk logic is confined to exactly the two files this plan modifies — `migrations/run-tests.sh` (4 occurrences, all now fixed) and `migrations/0008-plan-review-gate.md` (1 occurrence, fixed). The only other repo references to the old pattern are historical/documentary (`.planning/phases/08-plan-review-gate/08-REVIEW.md` and `08-08-PLAN.md`, both records of the defect, not executable code). Blast radius confirmed confined to this migration and its dedicated test suite.

## Known Stubs

None.

## Threat Flags

None — this plan's own `<threat_model>` entries (T-08-44 tampering, T-08-45 repudiation) are the exact mitigations implemented here; no new surface was introduced beyond what was already scoped. Both threats now hold `mitigate` with the fix landed and the decoy fixture as the regression guard.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `bash migrations/run-tests.sh` is green: 277 PASS / 2 SKIP / 0 FAIL (baseline was 273 PASS / 2 SKIP / 0 FAIL per 08-07-SUMMARY.md's worktree note; the 4 new decoy-table assertions account for the delta; the extra SKIP beyond the main-tree's 1 is the documented missing-sibling-repo (`agenticapps-workflow-core`) worktree artifact, not a regression). `bash migrations/run-tests.sh 0008` alone: 49 PASS / 0 FAIL.
- Migration 0008's idempotency and atomicity contract (08-05/08-06) is unchanged and re-verified: the scope-shaped fixture still reaches 16 rows/16 distinct gates and is still a no-op on a second run; the wrong-shape decline path (T-08-40) still declines with exit 7 rather than guessing; the no-scaffolder-tree and partial-application-recovery fixtures still pass end to end.
- `check-plan-review.sh` was not touched, per this plan's explicit scope boundary (08-07 owns it).
- No architectural changes were introduced; this plan closes one code-review finding (WR-02) against an existing, already-shipped migration step, mirroring 08-07's shape for the same phase.
- Ready for 08-VERIFICATION.md re-run against this gap closure and for any remaining gap-closure plans in this wave (08-09 if present).

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: migrations/run-tests.sh
- FOUND: migrations/0008-plan-review-gate.md
- FOUND: .planning/phases/08-plan-review-gate/08-08-SUMMARY.md
- FOUND commit: a7b2c0f (test — RED)
- FOUND commit: 764f877 (feat — GREEN)
