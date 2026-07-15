---
phase: 08-plan-review-gate
plan: 02
subsystem: infra
tags: [bash, gate-verifier, plan-review, spec-02, tdd, migration-harness, yaml-parsing]

# Dependency graph
requires:
  - "08-01: skills/agentic-apps-workflow/scripts/check-plan-review.sh — repo-root self-location, D-05 resolver, D-08/D-09 grandfather guards, GSD_PLAN_REVIEW_DEBUG contract, _cpr_case/_cpr_check_resolved/_cpr_check_contains test helpers"
  - "08-03: skills/codex-plan-review/SKILL.md — the reviews-skeleton marker pair (producer contract), extracted verbatim by test_check_plan_review_contract"
provides:
  - "skills/agentic-apps-workflow/scripts/check-plan-review.sh — complete block path: GSD_SKIP_REVIEWS=1 hatch, --file bypass list (traversal-safe), multi-ai-review-skipped hatch, *-REVIEWS.md evidence collection (ambiguity-safe), live-symlink + non-regular fail-closed guards, frontmatter reviewers:/plans_reviewed: parse (flow + block YAML), exit-2 block message naming codex-plan-review"
  - "migrations/run-tests.sh test_check_plan_review_enforcement — ~50-assertion block-path suite"
  - "migrations/run-tests.sh test_check_plan_review_contract — producer<->verifier round-trip suite (real 08-REVIEWS.md + codex-plan-review skeleton)"
affects: [08-04, 08-05, 08-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Frontmatter-bounded awk parse (between the first two '---' lines only) accepting BOTH flow (key: [a, b]) and block (key:\\n  - a) YAML sequence styles, without a YAML library dependency"
    - "Distinct-reviewer counting: strip quotes, trim whitespace, lowercase, sort -u, wc -l — a duplicate or case-variant name counts once"
    - "Symlink-before-regular-file guard ordering ([ -L ] tested strictly before [ -f ]) because [ -f ] dereferences a live symlink and would otherwise admit it"
    - "'..'-component rejection (split on '/', reject any exact '..' segment) BEFORE the textual prefix+basename bypass test, closing the traversal-shaped hole a normalize-then-test approach would reopen"
    - "Multi-line command substitution (CURRENT_PHASE=$(\\n  resolve_phase\\n)) used deliberately so a non-comment source line ends in exactly 'resolve_phase', satisfying a mechanical guard-order regression assertion"
    - "*REVIEW[S].md bracket-expression glob (functionally identical to *REVIEWS.md) used once, in the --file bypass basename set, specifically to avoid an early literal 'REVIEWS.md' substring that would otherwise satisfy a later source-order assertion for the wrong reason"

key-files:
  created: []
  modified:
    - skills/agentic-apps-workflow/scripts/check-plan-review.sh
    - migrations/run-tests.sh

key-decisions:
  - "Escape hatch 1 (GSD_SKIP_REVIEWS=1) and the --file bypass list sit ABOVE resolve_phase entirely (before repo-root self-location work even runs for hatch 1), per <ordering>'s step 1/2; escape hatch 2 (multi-ai-review-skipped) sits AFTER resolution but BEFORE the grandfather guards, checked only at the resolved phase dir — never the raw '.planning/current-phase/...' path, which would re-follow a symlink plan 08-01's containment check already rejected (T-08-29)."
  - "*-REVIEWS.md collection uses a counted array, never `find ... | head -1`: zero matches blocks (D-10), two or more matches blocks as ambiguous (T-08-30), naming every match."
  - "Symlink guard order is the fix, not merely its presence: [ -L ] runs strictly before [ -f ], because [ -f ] is a dereferencing test that returns true for a live symlink pointing at any regular file — testing it first would have re-opened the exact bypass T-08-36 exists to close."
  - "'..'-component rejection in the --file bypass runs before the prefix+basename test and rejects on shape alone (never normalize-then-contain), so a traversal that resolves back inside .planning/ onto a real canonical artifact is still rejected — pinned by an explicit test case."
  - "Frontmatter is authoritative when present; the >=5-line non-emptiness fallback runs ONLY when frontmatter (an opening '---') is entirely absent. An opening '---' with no closing '---' is MALFORMED and blocks with a distinct message — it never falls through to the fallback."
  - "plans_reviewed coverage blocks on any current *-PLAN.md missing from the list, but is documented at its call site as structurally unenforceable once any *-SUMMARY.md exists (the pre-existing grandfather guard fires first and never reaches this check) — a known, upstream-reported limitation (ADR-0009 decision 8b), not something this plan diverges on unilaterally."
  - "The reference's warn-and-allow (D-13's superseded behavior) is replaced with block-and-exit-2 for the frontmatter-absent, <5-line fallback path — commented at the call site so a future reader porting from the reference does not 'restore' the looser behavior."
  - "08-01's resolver-suite fixtures were updated with a companion *-SUMMARY.md per resolved-phase test case (not touching any assertion, label, or resolution logic) because those fixtures build a bare *-PLAN.md with no *-REVIEWS.md/*-SUMMARY.md and expect exit 0 — under this plan's real enforcement that would now legitimately block. The added SUMMARY.md routes those cases through 08-01's own pre-existing SUMMARY grandfather guard (which fires before the new REVIEWS check), keeping the resolver suite's actual resolution/debug-output assertions exercising identical behavior."

requirements-completed: ["core spec §02 (plan-review gate) — evidence artifact enforcement + block behavior"]

# Metrics
duration: 75min
completed: 2026-07-15
---

# Phase 08 Plan 02: Plan-Review Gate — REVIEWS Enforcement + Block Path Summary

**Completed `check-plan-review.sh`'s block path: both escape hatches, the traversal-safe `--file` bypass list, ambiguity- and symlink-safe REVIEWS.md evidence collection, dual-YAML-style frontmatter parsing with distinct-reviewer counting and `plans_reviewed` coverage, and the exit-2 block message — proven by a 30+ case enforcement suite plus a producer↔verifier contract suite that runs this repo's real `08-REVIEWS.md` and the `codex-plan-review` skeleton through the shipped verifier.**

## Performance

- **Duration:** ~75 min
- **Completed:** 2026-07-15
- **Tasks:** 2 (RED, GREEN)
- **Files modified:** 2

## Accomplishments

- Added `test_check_plan_review_enforcement` and `test_check_plan_review_contract` to `migrations/run-tests.sh`, covering: the block path and its message tokens; REVIEWS strictness in both flow and block YAML styles including distinct-reviewer normalization (`[gemini, gemini]` and case/whitespace variants both count as 1); `plans_reviewed` coverage (gap, superset, missing key, style independence); malformed-vs-absent frontmatter; both escape hatches plus their negative cases (including the escaped-`current-phase`-pointer regression guard); the four `--file` bypass cases including the two round-2 traversal regressions; three non-regular-artifact fail-closed cases (FIFO under timeout, directory, dangling symlink); three live-symlink fail-closed cases (outside the phase dir, a valid REVIEWS.md elsewhere, inside the same phase dir); and the ambiguous-artifact case.
- Implemented the full block path in `check-plan-review.sh` at plan 08-01's marked insertion point plus the two above-resolution short-circuits `<ordering>` requires: `GSD_SKIP_REVIEWS=1` and the `--file` bypass list sit above `resolve_phase`; the `multi-ai-review-skipped` marker check sits after resolution but before the grandfather guards, checked only at the resolved phase dir.
- Implemented the `_cpr_fm_list` awk helper: a YAML-library-free parser bounded to the frontmatter block (between the first two literal `---` lines) that accepts both a one-line flow sequence and an indented block sequence for the same key, used for both `reviewers:` and `plans_reviewed:`.
- Closed both round-2 bypasses named in the plan's threat register: the live-symlink bypass (T-08-36, `[ -L ]` tested strictly before the dereferencing `[ -f ]`) and the `--file` traversal bypass (T-08-37, a `..`-component rejection that runs before the textual prefix+basename test and rejects on shape alone, never normalize-then-contain).
- Discovered and fixed a real interaction between 08-01's resolver-suite fixtures and 08-02's new enforcement (documented as a deviation below), keeping the full harness at 210 PASS / 2 SKIP / 0 FAIL.

## Task Commits

Each task was committed atomically (TDD plan — RED then GREEN):

1. **Task 1 (RED): enforcement + producer-contract cases** — `9db8431` (test)
2. **Task 2 (GREEN): check-plan-review.sh — enforcement, hatches, block message** — `e27f2c5` (feat)

## TDD Gate Compliance

RED gate confirmed: `9db8431` (`test(RED): ...`) landed first, with `bash migrations/run-tests.sh check-plan-review` exiting 1 (44 FAIL, 78 PASS — every expect-2 case failed because the verifier did not yet implement the block path; the accidental allow-path passes and the untouched 08-01 resolver suite stayed green).
GREEN gate confirmed: `e27f2c5` (`feat(GREEN): ...`) landed after, with the same command exiting 0 (123 PASS, 0 FAIL, all three suites) and the full harness exiting 0 (210 PASS, 2 SKIP, 0 FAIL — up from 166 PASS / 44 FAIL / 2 SKIP at the RED commit, and up from 08-01's own 142 PASS / 2 SKIP baseline).
No REFACTOR commit was needed.

## Files Created/Modified

- `skills/agentic-apps-workflow/scripts/check-plan-review.sh` (modified) — added the two above-resolution short-circuits (`GSD_SKIP_REVIEWS=1` hatch, `--file` bypass list with traversal rejection), the `multi-ai-review-skipped` hatch at the resolved phase dir, the `_cpr_block` shared block-message helper, `*-REVIEWS.md` collection with ambiguity handling, the `[ -L ]`-then-`[ -f ]` symlink/non-regular guard, the `_cpr_fm_list` frontmatter-bounded dual-style YAML parser, distinct-reviewer counting, `plans_reviewed` coverage, malformed-vs-absent frontmatter handling, and the `>=5`-line fallback (D-13). Also changed `CURRENT_PHASE=$(resolve_phase)` to a multi-line command substitution so a non-comment source line ends in exactly `resolve_phase`, satisfying the plan's mechanical guard-order regression assertion.
- `migrations/run-tests.sh` (modified) — added `_cpr_enf_phase` (fixture helper), `test_check_plan_review_enforcement` (~50 assertions), `test_check_plan_review_contract` (producer↔verifier round trip), wired both into the existing `check-plan-review` dispatcher filter alongside `test_check_plan_review_resolver`. Also added a companion `*-SUMMARY.md` to each of 08-01's resolver-suite fixtures that creates a real `*-PLAN.md` and expects exit 0 (see Deviations).

## Decisions Made

See `key-decisions` in frontmatter above. All decisions were dictated by this plan's `<ordering>`, `<interfaces>`, and threat-register sections (T-08-06 through T-08-37) — no new architectural decisions were made outside what the plan specified.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `awk` syntax error: `close` collides with awk's built-in `close()` function**
- **Found during:** Task 2, first GREEN test run (every REVIEWS.md case with valid frontmatter failed with "found 0 distinct reviewer(s)" instead of the expected count)
- **Issue:** The frontmatter-block extraction used `awk -v close="$_cpr_fm_close_line" 'NR > 1 && NR < close'`. `close` is a reserved awk built-in function name (closes a file/pipe stream); using it as a variable name in this position produced a silent-ish awk syntax error on stderr and an empty frontmatter block, which in turn made every `reviewers:`/`plans_reviewed:` parse return zero entries.
- **Fix:** Renamed the awk variable from `close` to `endline`.
- **Files modified:** `skills/agentic-apps-workflow/scripts/check-plan-review.sh`
- **Verification:** Re-ran `bash migrations/run-tests.sh check-plan-review`; all valid-frontmatter cases that had failed now pass with the correct distinct-reviewer count.
- **Committed in:** `e27f2c5` (part of the GREEN commit — found and fixed before committing)

**2. [Rule 1 - Bug] Test assertions compared an absolute sandbox path against the verifier's relative-path stderr output**
- **Found during:** Task 2, second GREEN test run (`block: stderr names the resolved phase dir` and `symlink: stderr names the symlink path` failed even though the block message and symlink message were both correct)
- **Issue:** `check-plan-review.sh` `cd`s into the resolved repo root (the sandbox root, per-test) before printing any phase path, so its block-message output is relative to that root (e.g. `.planning/phases/08-block-basic`), never the sandbox's own absolute filesystem path (`$phasedir`, e.g. `/tmp/xxx/block-basic/.planning/phases/08-block-basic`). Two test assertions searched stderr for the absolute `$phasedir` string, which can never appear.
- **Fix:** Changed both assertions to search for the relative substring the verifier actually emits (`.planning/phases/<name>[/08-REVIEWS.md]`), with a comment recording why.
- **Files modified:** `migrations/run-tests.sh`
- **Verification:** Re-ran `bash migrations/run-tests.sh check-plan-review`; both cases pass.
- **Committed in:** `e27f2c5` (part of the GREEN commit)

**3. [Rule 1 - Bug] 08-01's resolver-suite fixtures broke under 08-02's real enforcement**
- **Found during:** Task 2, first GREEN test run (~20 of 08-01's own resolver-suite cases — root-location, resolution steps 1-3, precedence, decimal padding, section bounding, absent-vs-ambiguous, mtime tie-break — flipped from PASS to FAIL, each expecting exit 0 but now legitimately getting exit 2)
- **Issue:** 08-01's resolver suite tests resolution logic in isolation: its sandboxes create a bare `*-PLAN.md` with no `*-SUMMARY.md` and no `*-REVIEWS.md`, and assert exit 0 (meaning "resolution succeeded, allow" — valid under 08-01's own scope, which never exits 2). Once this plan's real REVIEWS.md enforcement lands, those same sandboxes have exactly the shape D-10 exists to block: plans present, no review evidence. This is a genuine, expected interaction between two plans' fixtures, not a bug in either plan individually — but the plan's own acceptance criteria require `FAIL: 0` across all three suites (resolver + enforcement + contract) after GREEN, so it had to be resolved without touching the resolver suite's actual assertions, labels, or resolution semantics.
- **Fix:** Added a companion `*-SUMMARY.md` file to each resolver-suite sandbox where a case creates a real `*-PLAN.md`, is resolved by 08-01's own `resolve_phase`, and expects exit 0 (~19 sites: root-location git/non-git, resolution steps 1a/1b/2a/2b/2c/2d/3, precedence, decimal dec1/dec2/dec3, section bounding sec1/sec2, absent-vs-ambiguous, and both equal-mtime candidates). This routes each case through 08-01's own pre-existing `*-SUMMARY.md` grandfather guard, which fires immediately after resolution and its debug output but strictly before the new REVIEWS.md check — so every resolution-order and `resolved-phase:`-debug-line assertion in the resolver suite continues to exercise the exact same code path and produce the exact same PASS/FAIL verdict as before. Cases that were already fail-open before reaching the grandfather guards (ambiguity, path-safety escapes, no-`*-PLAN.md`-at-all, ".planning/ empty", legacy bare-number layout, the pre-existing SUMMARY-grandfather case itself) needed no change.
- **Files modified:** `migrations/run-tests.sh`
- **Verification:** Re-ran `bash migrations/run-tests.sh check-plan-review` (0 FAIL, all three suites) and the full `bash migrations/run-tests.sh` (210 PASS, 2 SKIP, 0 FAIL).
- **Committed in:** `e27f2c5` (part of the GREEN commit)

---

**Total deviations:** 3 auto-fixed (2 bugs found via test failure, 1 real cross-plan fixture interaction resolved without touching test semantics)
**Impact on plan:** None on scope or design — all three were caught and fixed during the plan's own GREEN verification loop, before the commit landed.

## Issues Encountered

None beyond the three deviations above.

## User Setup Required

None — no external service configuration required by this plan.

## Known Stubs

None. `check-plan-review.sh`'s block path is fully functional: every case in `<ordering>` and the threat register is implemented and covered by a passing test.

## Threat Flags

None. All new surface (the two above-resolution short-circuits, the REVIEWS.md evidence check, the symlink/non-regular guards, the frontmatter parser) is covered by this plan's own `<threat_model>` (T-08-06 through T-08-37) — no additional network endpoints, auth paths, or schema changes were introduced beyond what the plan's threat register already accounts for.

## Shipped Contract (for downstream plans)

**Guard order, as shipped** (source-line order in `check-plan-review.sh`):
1. `GSD_SKIP_REVIEWS=1` (before any filesystem work)
2. `--file` bypass list (`..`-rejection first, then `.planning/`-prefix + canonical-basename match; `*REVIEW[S].md` is used instead of `*REVIEWS.md` in this one spot only, functionally identical, to avoid a mechanical source-order assertion false-positive)
3. Repo-root self-location + `resolve_phase` (08-01, unchanged)
4. `multi-ai-review-skipped` marker, checked only at the resolved phase dir
5. Grandfather guards (08-01, unchanged: legacy bare-number layout, no `*-PLAN.md`, `*-SUMMARY.md` present)
6. `*-REVIEWS.md` collection (counted; 0 or 2+ both block)
7. `[ -L ]` symlink guard, then `[ -f ]` regular-file guard
8. Frontmatter detection: opening `---` with no closing `---` blocks as MALFORMED; opening+closing `---` parses `reviewers:`/`plans_reviewed:` (distinct count `<2` blocks; missing/incomplete `plans_reviewed:` blocks); absent frontmatter falls back to the `>=5`-line check (blocks below it, D-13)

**Block message tokens** (stable, asserted by tests via substring match, not full-text match): the resolved phase dir (relative to repo root), the `--file` path when supplied, the missing-artifact path shape `<phase>/<NN>-REVIEWS.md`, the literal string `codex-plan-review`, the literal string `GSD_SKIP_REVIEWS`, and the literal string `multi-ai-review-skipped`.

**Exit codes:** 0 = allow, 2 = block. No other exit code is meaningful.

Plan `08-04` (ritual prose) must name the same remedy (`codex-plan-review`) and the same two hatch spellings. Plan `08-05` may rely on this exit-code contract without re-deriving it.

## Next Phase Readiness

- `check-plan-review.sh` is complete for both plan `08-04` (ritual wiring) and `08-05` (migration) to consume as a finished artifact — no further script changes are anticipated from those plans.
- Full harness green: 210 PASS / 2 SKIP / 0 FAIL.
- No blockers. Per this plan's own `<verification>` "Gate coverage" section: the live gate at this repo's own root is already grandfathered (08-01's `*-SUMMARY.md` shipped in wave 1) and will never itself exercise the block path — that is expected, not a regression (the bootstrap paradox), and coverage comes exclusively from `test_check_plan_review_enforcement` and `test_check_plan_review_contract`.

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: skills/agentic-apps-workflow/scripts/check-plan-review.sh
- FOUND: migrations/run-tests.sh
- FOUND commit: 9db8431 (test RED)
- FOUND commit: e27f2c5 (feat GREEN)
