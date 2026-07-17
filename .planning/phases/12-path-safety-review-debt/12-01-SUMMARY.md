---
phase: 12-path-safety-review-debt
plan: 01
subsystem: infra
tags: [shell, path-safety, symlink-resolution, plan-review-gate, adr]

# Dependency graph
requires:
  - phase: 08-plan-review-gate
    provides: "check-plan-review.sh's --file bypass, _canon_dir/_is_contained helpers, ADR-0009"
provides:
  - "Real symlink-resolution boundary check on the --file bypass, replacing the lexical-..-only guard (WR-03)"
  - "Three mutation-proven fixtures: symlinked-parent-escape (reject), symlinked-parent-inside (accept), sibling-prefix-collision (reject)"
  - "In-place ADR-0009 decision 12 Reversed marker + Resolved Open follow-up"
affects: [13-native-plan-review-hook, path-safety, ADR-0009]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Parent-directory canonicalize-and-contain (_canon_dir + _is_contained) reused for a --file edit-target guard, not just the current-phase pointer resolver"
    - "Resolve-then-contain symlink policy for --file targets, deliberately distinct from the REVIEWS.md evidence guard's reject-any-symlink policy"

key-files:
  created: []
  modified:
    - skills/agentic-apps-workflow/scripts/check-plan-review.sh
    - migrations/run-tests.sh
    - docs/decisions/0009-plan-review-gate.md

key-decisions:
  - "Hoisted repo-root self-location above the --file bypass (D-04) so $REPO_ROOT exists before the bypass's containment check runs; GSD_SKIP_REVIEWS stays the first executable gate"
  - "Kept the lexical '..' check as a defensive floor alongside the new containment gate (D-01) rather than replacing it -- it still fires when the parent dir does not exist"
  - "On an un-canonicalizable parent, the bypass falls through to normal resolution -- never exit 2, never bypass-approves (D-02, fail-safe not fail-open)"
  - "Resolve-then-contain, not reject-any-symlink (D-03) -- an in-tree symlinked parent is accepted, unlike REVIEWS.md's evidence guard"
  - "Tightened the '*/.planning/*' lexical arm to $REPO_ROOT/.planning only (D-05) -- a vendored vendor/foo/.planning/X-PLAN.md no longer bypasses this repo's gate. Disclosed behavior change, not a silent regression."
  - "ADR-0009 decision 12 gets only an in-place Reversed marker + Resolved follow-up note this phase -- the full dated Correction section is Phase 13's DOC-03 (D-08)"

patterns-established:
  - "WR-03 fixtures follow the RED-before-GREEN convention with an explicit mutation check that weakening _is_contained alone (not just the fall-through path) turns the rejection case RED, proving the block is genuinely produced by the reused helper"

requirements-completed: [WR-03]

# Metrics
duration: 25min
completed: 2026-07-17
---

# Phase 12 Plan 01: WR-03 Symlink-Resolution Guard Summary

**`--file`'s bypass now canonicalizes and contains the target's parent directory against `$REPO_ROOT/.planning` (reusing `_canon_dir`/`_is_contained`), closing the symlink-escape hole ADR-0009 decision 12 had accepted as a known limitation.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-17T14:25:47+02:00
- **Tasks:** 3 / 3
- **Files modified:** 3

## Accomplishments
- Real symlink-resolution boundary on `check-plan-review.sh`'s `--file` bypass: a symlinked parent directory that resolves outside `$REPO_ROOT/.planning` no longer bypasses the gate, while one that resolves inside is still accepted (resolve-then-contain, not reject-any-symlink).
- Three independently mutation-proven fixtures added to `run-tests.sh`, each verified RED against the pre-fix guard and GREEN against the fix (the reject cases; the accept case was verified consistent across both).
- ADR-0009 decision 12 carries an in-place `Reversed (Phase 12, WR-03)` marker naming the actual shipped mechanism, and its Open follow-up is marked `Resolved (Phase 12)` in place.

## Task Commits

Each task was committed atomically:

1. **Task 1: Hoist repo-root block and augment the --file guard with parent-dir canonicalize-and-contain** - `7fe440d` (feat)
2. **Task 2: Add three RED-before-GREEN WR-03 fixtures to run-tests.sh** - `177cdb3` (test)
3. **Task 3: Add in-place ADR-0009 Reversed marker at decision 12 and resolve the Open-follow-up** - `a1c2195` (docs)

## Files Created/Modified
- `skills/agentic-apps-workflow/scripts/check-plan-review.sh` - Repo-root self-location hoisted above the `--file` bypass (D-04); the bypass augmented with a parent-dir `_canon_dir`/`_is_contained` containment gate against `$REPO_ROOT/.planning`, keeping the lexical `..` floor and the fall-through-on-unresolvable-parent contract intact
- `migrations/run-tests.sh` - Three WR-03 fixtures added to `test_check_plan_review_enforcement`, immediately after the existing `--file` traversal cases, reusing `_cpr_case`/`_cpr_enf_phase` verbatim
- `docs/decisions/0009-plan-review-gate.md` - In-place `Reversed (Phase 12, WR-03)` marker at decision 12; matching Open follow-up marked `Resolved (Phase 12)`

## Decisions Made
- D-04: hoisted the repo-root self-location block above the `--file` bypass so `$REPO_ROOT` is available for containment checks, keeping `GSD_SKIP_REVIEWS` as the first executable gate.
- D-01/D-02/D-03/D-05 honored exactly as specified in 12-CONTEXT.md: lexical `..` floor retained, fall-through (never fail-open, never fail-closed) on an un-canonicalizable parent, resolve-then-contain symlink policy, and the `$REPO_ROOT/.planning`-only containment root.
- D-08/D-09: ADR-0009 got only the minimal in-place marker + resolved follow-up; the dated Correction section stays Phase 13's DOC-03, avoiding a same-file-region race between the two phases' PRs.

## Behavior Change Disclosure (D-05)

**`*/.planning/*` bypass tightened to `$REPO_ROOT/.planning` only.** Before this plan, any `--file` value whose path textually matched `.planning/*` or `*/.planning/*` and whose basename matched the canonical GSD artifact list (`*PLAN.md`, `ROADMAP.md`, etc.) bypassed the plan-review gate — including a vendored sub-project's own planning tree, e.g. `vendor/foo/.planning/X-PLAN.md`. After this plan, the bypass additionally requires the file's *parent directory* to canonicalize (resolve symlinks) into a path contained within *this repo's* `$REPO_ROOT/.planning` tree. A vendored `vendor/foo/.planning/X-PLAN.md` no longer bypasses; it falls through to normal phase resolution and is subject to the same REVIEWS.md enforcement as any other file. This is an intentional correctness fix (a sub-project's planning doc should not silently authorize edits under this repo's gate), not a silent regression — it is recorded here, in the phase's fixture (c) label, and in ADR-0009 decision 12's Reversed marker.

## Deviations from Plan

None - plan executed exactly as written. All D-01 through D-05, D-08, D-09 decisions from 12-CONTEXT.md were followed as locked.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Verification Evidence

- `bash migrations/run-tests.sh`: 401 PASS / 0 FAIL / 1 SKIP (up from 398 PASS / 0 FAIL / 1 SKIP pre-plan; +3 new WR-03 fixtures).
- Fixture (a) symlinked-parent-escape: observed `exit=0` (FAIL against expected `exit=2`) when run against the pre-Task-1 script (`git show 7fe440d~1:...`), and `exit=2` (PASS) against the Task-1 fix — genuine RED-before-GREEN.
- Fixture (c) sibling-prefix-collision: same RED-before-GREEN pattern observed (`exit=0` pre-fix, `exit=2` post-fix). Additionally verified mutation-proof: temporarily weakening `_is_contained()` to `return 0` unconditionally (leaving the fall-through path untouched) turned both fixture (a) and (c) RED again, confirming the rejection is produced by `_is_contained` genuinely evaluating containment-false, not by the D-02 fall-through reaching `exit 2` downstream for an unrelated reason.
- Fixture (b) symlinked-parent-inside: `exit=0` under both the pre-fix and post-fix script (not a regression case — proves D-03's resolve-then-contain accept path).
- All temporary script mutations were restored to the committed state (`git diff --stat` confirmed no residual diff) before proceeding to the next verification step.

## Next Phase Readiness

- WR-03 is fully closed for this plan's scope; the remaining Phase 12 requirements (REV-01 through REV-04) are plan 02/03's scope per the phase roadmap.
- ADR-0009's decision 12 is now internally consistent with the shipped code; Phase 13's DOC-03 can build its consolidated Correction section on top of this plan's Reversed marker without re-deriving the mechanism description.
- No blockers for subsequent plans in this phase.

---
*Phase: 12-path-safety-review-debt*
*Completed: 2026-07-17*
