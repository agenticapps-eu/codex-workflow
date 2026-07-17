---
phase: 12-path-safety-review-debt
plan: 04
subsystem: infra
tags: [shell, bash, path-safety, plan-review-gate, symlink-containment]

# Dependency graph
requires:
  - phase: 12-path-safety-review-debt (plan 01)
    provides: "The --file bypass's repo-root hoist + parent-dir canonicalize-and-contain guard (_canon_dir/_is_contained), which this plan augments in its empty-parent else-branch"
provides:
  - "Lexical $REPO_ROOT/.planning-rooted fail-safe-accept fallback closing 12-01 truth #4 (never exit-2-blocks a not-yet-created in-tree plan file)"
  - "A mutation-proven fixture reproducing 12-VERIFICATION.md's exact Priority Concern repro"
  - "ADR-0009 decision 12 disclosure of the fallback's mechanism and preserved invariants"
affects: [phase-13-native-plan-review-hook, phase-14-paired-section-11-markers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Empty-canonicalization-branch fallback: when _canon_dir returns empty (path does not exist yet), fall back to a purely lexical containment check against the same root variable rather than fully falling through to normal resolution -- keeps a fail-safe-accept without weakening the resolve-then-contain path used when canonicalization succeeds"

key-files:
  created: []
  modified:
    - skills/agentic-apps-workflow/scripts/check-plan-review.sh
    - migrations/run-tests.sh
    - docs/decisions/0009-plan-review-gate.md

key-decisions:
  - "Fallback lives strictly inside the elif [ -z \"$_cpr_canon_parent\" ] branch (sibling to the existing resolve-then-contain if), not a rewrite of the existing accept -- the two branches are mutually exclusive by construction (_cpr_canon_parent is either non-empty or empty), so the symlink-escape path (12-01 truths #1/#2/#3) is provably untouched"
  - "Fallback root is the same $REPO_ROOT/.planning already used by the canonicalized check (reused variable spelling, not a new one), preserving D-05's vendored-sub-project tightening on the fallback path too"
  - "ADR-0009 gets an additive 'Extended (Phase 12 gap-closure, 12-04)' note appended after the existing 'Reversed (Phase 12, WR-03)' marker, not a rewrite of it -- keeps the original marker's dated history intact while disclosing the new behavior"

requirements-completed: [WR-03]

# Metrics
duration: ~35min
completed: 2026-07-17
---

# Phase 12 Plan 04: Not-Yet-Created-Dir Fail-Safe-Accept Fallback Summary

**Closed the sole Phase 12 verification gap (12-01 truth #4) with a lexical `$REPO_ROOT/.planning`-rooted fallback that fires only when `_canon_dir` returns empty, restoring the pre-Phase-12 fail-safe accept without reopening the WR-03 symlink-escape hole.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-07-17T17:06:28Z
- **Tasks:** 3/3
- **Files modified:** 3

## Accomplishments

- Added an `elif [ -z "$_cpr_canon_parent" ]` fallback branch to the `--file` bypass in `check-plan-review.sh`, sibling to the existing resolve-then-contain `if [ -n "$_cpr_canon_parent" ] && _is_contained ...` accept. It computes a purely lexical absolute parent anchored at `$REPO_ROOT` and reuses `_is_contained` against the un-canonicalized `$REPO_ROOT/.planning` root.
- Verified manually that the verifier's exact sandbox repro (unrelated active `13-active-phase` with `13-01-PLAN.md` and no REVIEWS.md, `--file .planning/phases/14-new-nonexistent/14-01-PLAN.md` where the target dir does not exist) now returns exit 0, where it previously returned exit 2.
- Added fixture (d) to `migrations/run-tests.sh`'s `test_check_plan_review_enforcement`, immediately after the existing sibling-prefix-collision fixture (c), reusing `_cpr_case`/`_cpr_enf_phase` verbatim. The fixture deliberately does NOT pre-create the `--file` target's parent directory (the one property every other `_cpr_enf_phase` fixture in the file does the opposite of).
- Mutation-proved the fallback RED→GREEN: with the branch condition changed to `elif false && [ -z "$_cpr_canon_parent" ]; then`, fixture (d) flipped to `FAIL ... (expected exit=0, got exit=2)`; restoring the condition returned it to `PASS ... (exit=0)`. `git diff --stat` was clean both before disabling and after restoring (confirmed the restored file is byte-identical to the prior commit).
- Re-confirmed fixture (a) (symlinked-parent-escape) still asserts `exit 2` with the fallback active — the WR-03 hole stays closed, because an existing symlinked parent has a non-empty `_cpr_canon_parent` and never reaches the new branch.
- Extended ADR-0009 decision 12's in-place `Reversed (Phase 12, WR-03)` marker with an additive, dated `Extended (Phase 12 gap-closure, 12-04)` note disclosing the fallback's mechanism, the preserved symlink-escape invariant, and the `$REPO_ROOT/.planning` rooting. No `## Correction` section was opened (that remains Phase 13 / DOC-03). Also corrected the marker's stale `:84-118` line-range citation on the `..` floor to the current `:166-176` (IN-03, secondary/optional fix, done because it was trivial).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the lexical `$REPO_ROOT/.planning`-rooted fail-safe-accept fallback to the `--file` bypass** - `66b2b2d` (fix)
2. **Task 2: Add the not-yet-created-dir fixture and mutation-prove RED→GREEN + symlink-hole-not-reopened** - `c594293` (test)
3. **Task 3: Extend the ADR-0009 Reversed marker to disclose the not-yet-created-dir fail-safe-accept fallback** - `1f368b5` (docs)

**Plan metadata:** (this commit, following SUMMARY.md write)

## Files Created/Modified

- `skills/agentic-apps-workflow/scripts/check-plan-review.sh` - Added the `elif [ -z "$_cpr_canon_parent" ]` lexical fallback branch inside the `--file` bypass's basename case arm, with an inline comment block naming the safety argument (`..` floor already ran; fires only on empty `_canon_dir`; rooted at `$REPO_ROOT/.planning`). Also updated the preceding D-02 comment to describe the new two-branch control flow accurately.
- `migrations/run-tests.sh` - Added fixture (d) `NOT-YET-CREATED-DIR WITH UNRELATED ACTIVE PHASE` in `test_check_plan_review_enforcement`, immediately after fixture (c) at what was line 3221. Records the observed RED/GREEN transcript in a comment block above the fixture.
- `docs/decisions/0009-plan-review-gate.md` - Appended the `Extended (Phase 12 gap-closure, 12-04)` note after the existing decision-12 `Reversed (Phase 12, WR-03)` marker; corrected the stale `:84-118` citation to `:166-176`.

## Decisions Made

- The fallback was implemented as an `elif` sibling to the existing accept-`if`, not an `else` wrapping a second nested `if`, and not a rewrite of the existing condition — this keeps the two accept paths (resolve-then-contain vs. lexical-fallback) textually and logically disjoint, which is what makes "when the parent exists, only the canonicalized path can accept" independently verifiable by inspection, not just by test.
- Reused the exact `$REPO_ROOT/.planning` string (not `$_cpr_canon_planning_root`, which is the *canonicalized* root and would be empty or mismatched when the target subtree doesn't exist yet) as the fallback's containment root — using the canonicalized root variable here would have been wrong (it canonicalizes `$REPO_ROOT/.planning` itself, which does exist, so it's not empty, but mixing a canonicalized root against a lexical candidate risks a separator/casing mismatch on any platform where `$REPO_ROOT` itself needed resolution; using the same literal `$REPO_ROOT/.planning` string that appears in the acceptance criteria keeps the intent auditable by grep).
- Chose to encode the mutation-test disable as `elif false && [ -z "$_cpr_canon_parent" ]; then  # MUTATION-TEST-DISABLE-12-04` (short-circuit via `false &&`) rather than commenting out the whole branch body — this is reversible with a single-line Edit and keeps the branch's comment block (the safety argument) intact and readable during the RED run, in case anyone needed to inspect it mid-mutation.

## Deviations from Plan

None — plan executed exactly as written. All four hard constraints in Task 1's action block were encoded and independently verified via grep-based acceptance criteria (see below). The plan's optional/secondary IN-03 stale-citation fix was also applied in Task 3 since it was a one-token change.

One self-correction during Task 1, not a deviation from the plan's design: my first attempt referenced the literal token `_cpr_has_dotdot` inside the new fallback's comment block, which tripped the acceptance criterion "`grep -c '_cpr_has_dotdot'` is unchanged from pre-task" (comment-only grep hits count). Reworded the comment to describe the `..`-clear guard without repeating that exact identifier, re-verified the grep count returned to 3 (unchanged), and re-ran the manual repro and full suite to confirm no functional impact — this was caught and fixed before the Task 1 commit, so no separate commit exists for it.

## Issues Encountered

None beyond the self-correction above.

## Mutation-Proof Transcripts

**RED (fallback disabled via `elif false && [ -z "$_cpr_canon_parent" ]; then`):**

```
=== Summary ===
  PASS: 406
  FAIL: 1
  SKIP: 1

  FAIL WR-03 bypass: --file .planning/phases/14-new-nonexistent/14-01-PLAN.md -> exit 0 (not-yet-created dir + unrelated active PLAN.md-no-REVIEWS.md phase must fall through to fail-safe accept, matching pre-Phase-12 behavior) (expected exit=0, got exit=2)
```

**GREEN (fallback restored, byte-identical to the Task-1 commit — `git diff --stat` clean):**

```
=== Summary ===
  PASS: 407
  SKIP: 1

  PASS WR-03 bypass: --file .planning/phases/14-new-nonexistent/14-01-PLAN.md -> exit 0 (not-yet-created dir + unrelated active PLAN.md-no-REVIEWS.md phase must fall through to fail-safe accept, matching pre-Phase-12 behavior) (exit=0)
```

**Hole-not-reopened re-run (fixture a, present in both RED and GREEN runs above, unaffected by the mutation):**

```
  PASS WR-03 bypass: --file .../evil-link/some-PLAN.md -> exit 2 (symlinked parent resolves OUTSIDE .planning; old lexical-only guard returned exit 0 here -- fail-open closed) (exit=2)
```

**Manual repro of the verifier's exact scenario (12-VERIFICATION.md Priority Concern), run directly against the fixed script:**

```
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.planning/phases"
PHASEDIR="$SANDBOX/.planning/phases/13-active-phase"
mkdir -p "$PHASEDIR"; touch "$PHASEDIR/13-01-PLAN.md"
( cd "$SANDBOX/.planning" && ln -sf "phases/13-active-phase" current-phase )
( cd "$SANDBOX" && bash check-plan-review.sh --file ".planning/phases/14-new-nonexistent/14-01-PLAN.md" )
# EXIT: 0   (was exit 2 before Task 1; pre-Phase-12 script also returned exit 0)
```

## Full Suite Counts

- **Before this plan (baseline, confirmed by re-running after Task 1 alone):** 406 PASS / 0 FAIL / 1 SKIP
- **After Task 2's fixture lands (final state):** 407 PASS / 0 FAIL / 1 SKIP
- **`git diff --stat`** confirmed clean immediately after every mutation-restore cycle and again at the end of this plan (only the three intended files carry changes vs. `main`).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Phase 12's single verification gap (12-01 truth #4 / 12-VERIFICATION.md WR-01) is closed. All 13 of Phase 12's original must-have truths now hold, all mutation-proven where applicable. Phase 12 is ready for re-verification and, on a clean re-verification, for transition. Phase 13 (native plan-review hook) and Phase 14 (paired §11 markers) remain independently scoped and unaffected by this gap-closure; Phase 13's ADR-0009 Correction section (DOC-03) still has both the original decision-12 reversal and this extension to summarize when it lands.

---
*Phase: 12-path-safety-review-debt*
*Completed: 2026-07-17*
