---
phase: 13-native-enforcement-plan-review-hook
plan: 04
subsystem: docs
tags: [adr, decision-record, docs, grep-assertion, mutation-testing]

# Dependency graph
requires:
  - phase: 13-native-enforcement-plan-review-hook (plan 03)
    provides: "migrations/0011-native-plan-review-hook.md — the migration whose HOOK-03 unconditional native block supersedes ADR-0009 decision 9"
provides:
  - "docs/decisions/0009-plan-review-gate.md's dated ## Correction section (DOC-03, SC#5): decision 9 SUPERSEDED, decision 12 REVERSED (by reference to Phase 12's existing inline markers), and the global-vs-project-scoped factual correction"
  - "test_adr_0009_correction in migrations/run-tests.sh — grep-assertion pinning the Correction section's content, mutation-proven"
affects: [13-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Grep-assertion test scoped to a section's own line span (awk '/^## Correction/,0', portable BSD/macOS + gawk idiom already precedented at run-tests.sh:609) rather than whole-file grep, so the assertion cannot pass by matching a pre-existing marker elsewhere in the same document"

key-files:
  created: []
  modified:
    - docs/decisions/0009-plan-review-gate.md
    - migrations/run-tests.sh

key-decisions:
  - "The Correction section's decision-12 item is a REFERENCE only (cites Phase 12's existing 'Reversed (Phase 12, WR-03)' / 'Extended (Phase 12 gap-closure, 12-04)' inline markers by name and date) and never repeats the _canon_dir/_is_contained guard mechanics — grep-verified by asserting absence of those substrings within the new section's own span, both in the ADR itself and in the pinning test."
  - "Decision 9's SUPERSESSION is stated without retroactively validating decision 9's original rejection of option B — the trust-ledger and self-scoping concerns it named were confirmed real by Phase 13's own spike findings (13-01-SPIKE-FINDINGS.md); only the specific 'global, not per-project' factual premise no longer holds."

patterns-established: []

requirements-completed: [DOC-03]

# Metrics
duration: ~20min
completed: 2026-07-18
---

# Phase 13 Plan 04: ADR-0009 Correction Section Summary

**ADR-0009 gains a dated `## Correction` section (DOC-03/SC#5) recording decision 9 superseded by HOOK-03's native block, decision 12's Phase-12 reversal by reference, and the corrected "native hooks are project-scoped, not only global" fact — pinned by a mutation-proven grep-assertion test.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-18
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Appended a top-level `## Correction` section (dated 2026-07-18, within
  `docs/decisions/0009-plan-review-gate.md`'s existing numbering — no new
  ADR number, per REV-04) as an in-place edit to ADR-0009, recording:
  (1) decision 9 SUPERSEDED by migration 0011's unconditional native
  `PreToolUse` block, without retroactively validating decision 9's
  original rejection of option B; (2) decision 12's reversal REFERENCED
  (not duplicated) — cites Phase 12's existing `Reversed (Phase 12,
  WR-03)` and `Extended (Phase 12 gap-closure, 12-04)` inline markers by
  name; (3) the factual correction that `<repo>/.codex/hooks.json` and
  `<repo>/.codex/config.toml` are documented, project-scoped layers,
  falsifying decision 9's "global rather than per-project" claim as of
  codex-cli 0.144.4.
- Added `test_adr_0009_correction` to `migrations/run-tests.sh`: 6
  grep-assertion PASS/FAIL checks scoped to the Correction section's own
  line span (`awk '/^## Correction/,0'`), not the whole file — exactly
  one heading, decision 9 superseded, decision 12 reversed by reference,
  absence of duplicated guard-mechanics substrings, the
  global-vs-project-scoped correction, and a valid date. Registered in
  the dispatcher under the `adr-0009-correction` filter.
- Mutation-proven: stripping the Correction section (`awk` truncation to
  the pre-section state) flips 5 of 6 assertions from PASS to FAIL —
  verified by direct execution, file restored via backup diff
  afterward.
- Full suite: **441 PASS / 0 FAIL / 2 SKIP**, exit 0 (up from 435 in
  plan 13-03; +6 new assertions, no regressions).

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the dated ## Correction section in ADR-0009** - `adea8ef` (docs)
2. **Task 2: Grep-assertion test pinning the Correction section (DOC-03)** - `0644a6b` (test)

## Files Created/Modified

- `docs/decisions/0009-plan-review-gate.md` - New `## Correction` section
  appended after "Open follow-ups", dated 2026-07-18, recording the three
  DOC-03 items; decision 11 (unrelated) and decision 12's existing inline
  markers left untouched
- `migrations/run-tests.sh` - Added `test_adr_0009_correction` (6
  assertions) plus its dispatcher registration
  (`[ "$FILTER" = "adr-0009-correction" ]`)

## Decisions Made

- Dated the Correction section `2026-07-18` (execution date) rather than
  RESEARCH.md's suggested `2026-07-17` placeholder — the plan's own
  acceptance criteria regex (`2026-07-(17|1[89]|2[0-9])`) explicitly
  tolerates either, and the section itself states "dated 2026-07-18",
  matching the actual authoring date rather than a stale suggestion.
- Scoped every content grep-assertion in the new test to the Correction
  section's own line span, not the whole ADR file — the ADR already
  contains "decision 12" and "Reversed" text elsewhere (Phase 12's own
  inline markers), so a whole-file grep would risk a false PASS if the
  new section were later removed but old text happened to satisfy the
  same pattern. Verified this scoping matters by confirming the
  pre-existing markers do NOT independently satisfy the same
  assertions (grep dry-run before writing the test).
- Added a 6th assertion beyond the plan's minimum-4 requirement
  (absence of `_canon_dir`/`_is_contained` substrings in the new
  section) to make the "reference, not duplicate" acceptance criterion
  itself mutation-detectable, not just eyeballed at write time.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance criteria
were verified by direct execution (grep counts, full suite run, mutation
test) rather than by inspection alone.

## Issues Encountered

- `vendor/agenticapps-shared` git submodule was not initialized in this
  worktree (same pre-existing repo setup step plans 13-02/13-03 already
  recorded). Ran `git submodule update --init --recursive` to make
  `migrations/run-tests.sh` runnable; nothing committed for this since
  the submodule pointer was already correct in the tree.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DOC-03 (SC#5) is closed: ADR-0009 carries its dated Correction section,
  pinned by a mutation-proven grep-assertion test that would go RED on a
  silent removal of any of the three recorded items.
- No blockers. Plan `13-05` (the live, human-observed end-to-end session
  proving migration 0011's hook actually fires) can proceed
  independently — this plan only touched documentation and the test
  harness, no runtime code.

## Self-Check: PASSED

- FOUND: docs/decisions/0009-plan-review-gate.md (`## Correction` section present, dated 2026-07-18)
- FOUND: migrations/run-tests.sh (`test_adr_0009_correction` defined + dispatcher-registered)
- FOUND commit adea8ef (Task 1)
- FOUND commit 0644a6b (Task 2)
- Full suite: 441 PASS / 0 FAIL / 2 SKIP, exit 0 (verified by direct execution)
- Mutation test: stripping the Correction section flips 5/6 assertions RED (verified by direct execution, file restored)

---
*Phase: 13-native-enforcement-plan-review-hook*
*Completed: 2026-07-18*
