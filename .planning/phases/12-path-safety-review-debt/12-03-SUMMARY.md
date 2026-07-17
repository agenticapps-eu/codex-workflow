---
phase: 12-path-safety-review-debt
plan: 03
subsystem: docs
tags: [adr, decision-records, numbering-convention, documentation]

# Dependency graph
requires: []
provides:
  - "Normative ADR/migration numbering-convention subsection in docs/decisions/README.md"
affects: [13-hook-01-native-plan-review-gate, 14-paired-region-markers]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - docs/decisions/README.md

key-decisions:
  - "Followed D-10 exactly: independent-sequences statement + always-qualify/never-bare rule + the live ADR-0010-documents-migration-0009 worked example, verified against ls migrations/*.md and the Index table before writing."
  - "Placed the new '## Numbering convention' subsection after the intro paragraphs and before '## Index', per the plan's placement guidance and the PATTERNS.md worked-example draft."

patterns-established:
  - "Numbering-collision disambiguation: always qualify a decision-record or migration number as 'ADR-NNNN' or 'migration NNNN' in prose, never a bare 'NNNN' — cited going forward when Phase 13/14 assign new migration numbers."

requirements-completed: [REV-04]

# Metrics
duration: 6min
completed: 2026-07-17
---

# Phase 12 Plan 03: ADR/Migration Numbering Convention Summary

**Added a normative "Numbering convention" subsection to `docs/decisions/README.md` stating the ADR-NNNN and migration-NNNN series are independent sequences, with a live worked example (ADR-0010 documents migration 0009; ADR-0009 is the unrelated plan-review gate) that disambiguates the current off-by-one collision.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-17T12:28:00Z
- **Completed:** 2026-07-17T12:34:14Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- `docs/decisions/README.md` now carries a dedicated `## Numbering convention` subsection stating the ADR-NNNN and migration-NNNN series are independent numbering sequences.
- The subsection prescribes always qualifying a number as `ADR-NNNN` or `migration NNNN` in prose, and forbids a bare `NNNN`.
- The subsection carries the live, repo-verified worked example: migration `0009` (`0009-spec-11-region-aware-placement.md`) is documented by **ADR-0010**, while **ADR-0009** (`0009-plan-review-gate.md`) is the unrelated plan-review gate — closing the exact IN-03/REV-04 ambiguity hazard.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add a normative ADR/migration numbering-convention subsection to docs/decisions/README.md** - `ecccc6b` (docs)

**Plan metadata:** (this commit, follows below)

## Files Created/Modified
- `docs/decisions/README.md` - Added `## Numbering convention` subsection (after intro paragraphs, before `## Index`) stating the two series are independent, prescribing always-qualified numbering, and carrying the live ADR-0010/migration-0009/ADR-0009 worked example.

## Decisions Made
- Verified the worked example against the actual repo state before writing it: `ls migrations/*.md` confirms migration `0009` is `0009-spec-11-region-aware-placement.md`; the Index table confirms ADR-0010's title is "Anchor the §11 block above a leading GitNexus region" (matching migration 0009's subject) and ADR-0009's title is "Bind the plan-review pre-execution gate on the Codex host" (a different subject). No illustration was invented — this collision is already live in the repo's two series, exactly as D-10 required.
- Placed the subsection between the intro paragraphs and the Index table (not after the Index), matching the PATTERNS.md draft and keeping the convention visible before a reader scans ADR numbers.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- REV-04 is closed: the ADR/migration numbering-conflation hazard the roadmapper was told to honor when assigning Phase 13/14's new migration numbers is now documented with actionable, verified guidance in `docs/decisions/README.md`.
- No blockers for Phase 12 Plan 02 (WR-03 guard) or Phase 13 (HOOK-01 native binding, which will assign new migration/decision numbers and should cite this convention).

---
*Phase: 12-path-safety-review-debt*
*Completed: 2026-07-17*
