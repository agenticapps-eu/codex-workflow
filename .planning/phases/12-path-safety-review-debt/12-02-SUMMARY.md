---
phase: 12-path-safety-review-debt
plan: 02
subsystem: testing
tags: [bash, awk, migrations, test-harness, mutation-testing]

# Dependency graph
requires:
  - phase: 12-path-safety-review-debt
    provides: "12-01's WR-03 symlink-resolution guard (independent file surface, no overlap)"
provides:
  - "validate-0009-anchor.sh stdout genuinely deterministic — no mirror-derived
    line count or line number survives a passing run"
  - "extract_step_block requires a delimiter (':', ' ', or EOL) after the step
    digit, closing the '### Step 1' vs '### Step 10'+ prefix collision"
  - "CASE 1's line drop is asserted with a strictly-smaller-count check, no
    hardcoded line number"
affects: [13-native-plan-review-hook, 14-paired-11-markers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "delim_ok() awk helper: substr/literal character comparison for a
      delimiter guard, never a compiled regex built from interpolated input"
    - "printf-into-$tmp synthetic fixture with a DELIBERATELY OUT-OF-ORDER
      heading sequence, needed because natural ascending order masks the bug
      via the extractor's own exit-after-fence-close short-circuit"

key-files:
  created: []
  modified:
    - migrations/validate-0009-anchor.sh
    - migrations/run-tests.sh

key-decisions:
  - "REV-01 removed 'at line N' text from ALL three PASS-path messages that
    carried it (CASE 2, COUNTER-CASE A, WIDENED TERMINATOR), not only CASE
    2's PASS line as the plan's <action> text named — the automated verify
    command greps the ENTIRE script's stdout, and COUNTER-CASE A / WIDENED
    TERMINATOR's PASS text also embedded 'at line N' phrasing that would
    have failed the same grep even though those specific values are not
    mirror-length-dependent (see 09-VALIDATION-EVIDENCE deviation note)."
  - "REV-02's synthetic fixture places '### Step 10' BEFORE '### Step 1' in
    document text, not in natural ascending order as the plan's <action>
    literally described — empirically verified that a natural 1..10 ordering
    never reproduces the collision (extract_step_block exits at Step 1's own
    fence close before scanning reaches Step 10), so only the reordered
    construction is mutation-provable."

requirements-completed: [REV-01, REV-02, REV-03]

# Metrics
duration: 55min
completed: 2026-07-17
---

# Phase 12 Plan 2: REV-01/02/03 Debt Closure Summary

**validate-0009-anchor.sh stdout is now genuinely deterministic (mirror-derived values removed, not reworded), extract_step_block no longer prefix-collides `### Step 1` with `### Step 10`+, and CASE 1's line drop is asserted with a strictly-smaller-count check — all three independently mutation-proven RED then GREEN by hand.**

## Performance

- **Duration:** 55 min
- **Started:** 2026-07-17T13:36:00Z (per 12-02-PLAN.md file timestamp)
- **Completed:** 2026-07-17T12:55:41Z (session clock; see Issues Encountered)
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- **REV-01 (WR-05):** `validate-0009-anchor.sh`'s banner no longer prints
  `$(wc -l < "$MIRROR"))`; CASE 2, COUNTER-CASE A, and WIDENED TERMINATOR's
  PASS text no longer print any `at line N` value. The underlying relational
  assertions (`$c2_prov -ge $c2_start`, etc.) are unchanged — only what gets
  echoed to stdout was narrowed. A new `test_validate_0009_anchor_determinism`
  in `run-tests.sh` full-script-greps the real validator's stdout for the
  absence of both shapes, registered under the `determinism` filter.
- **REV-02 (IN-01):** `extract_step_block`'s `index($0, stepp) == 1` bare-prefix
  test is now gated by `delim_ok()`, an awk function requiring the character
  immediately after the matched prefix to be `:`, ` `, or EOL — via
  `substr`/literal comparison, never a compiled regex from interpolated input
  (the file's own "literal prefix, nothing to escape" property at `:80-91` is
  preserved). Applied to both the `stepp` start-match and the `nextp`
  end-of-block boundary. A new `test_extract_step_block_delimiter` proves it
  with a synthetic out-of-order 3-heading document.
- **REV-03 (IN-02):** CASE 1 in `validate-0009-anchor.sh` now asserts
  `[ "$(wc -l < strip)" -lt "$(wc -l < input)" ]` between `candidate_strip` and
  `candidate_insert`, routed through the file's own `pass`/`fail` helpers, with
  no hardcoded line number.

## Task Commits

Each task was committed atomically:

1. **Task 1: REV-01 — remove mirror-derived stdout + add determinism test** - `9646c34` (fix)
2. **Task 3: REV-03 — CASE 1 strictly-smaller-count line-drop assertion** - `a3b82ad` (test)

   _(Committed before Task 2 to keep validate-0009-anchor.sh's two independent
   REV-01/REV-03 hunks in separate, cleanly-diffable commits — see Deviations._)
3. **Task 2: REV-02 — delimiter-aware extract_step_block + synthetic proof** - `043350f` (fix)

_Note: no `docs:` plan-metadata commit is listed here — this SUMMARY/STATE/ROADMAP
commit itself is that commit (see final_commit step)._

## Files Created/Modified

- `migrations/validate-0009-anchor.sh` — REV-01 (banner + 3 PASS-text sites
  narrowed to remove `at line N`/`(N lines)`; comment reconciled) and REV-03
  (CASE 1 strictly-smaller-count assertion inserted between strip and insert).
- `migrations/run-tests.sh` — REV-02 (`extract_step_block`'s `delim_ok` guard;
  new `test_extract_step_block_delimiter`, filter `extract-step-block`) and
  REV-01's proof (`test_validate_0009_anchor_determinism`, filter `determinism`).

## Decisions Made

- **REV-01 scope widened beyond the plan's literal CASE-2-only wording.** The
  plan's `<action>` named only CASE 2's PASS line (`:292`) for the `at line`
  removal. The plan's own automated `<verify>` command greps the WHOLE
  script's stdout for `at line [0-9]+` — a stricter bar. COUNTER-CASE A
  (`:315`, pre-fix) and WIDENED TERMINATOR PRESERVES REGION (`:359`, pre-fix)
  also embedded `at line N` phrasing in their PASS text. Empirically these two
  specific values are not mirror-length-dependent (they resolve before or
  entirely outside the streamed mirror content), so they were not part of the
  WR-05 defect strictly construed — but leaving them in would fail the plan's
  own `<verify>` grep on every run. Removed them too, rephrased relationally
  (`region body present` instead of `body at line $wb_body`), to satisfy the
  literal automated gate without weakening any assertion (the underlying
  `count_exact`/`line_of_sub` computations and comparisons are untouched).
- **REV-02's synthetic fixture uses an out-of-order heading sequence
  (`### Step 10` before `### Step 1`), not the natural ascending order the
  plan's `<action>` described ("write `### Step 1:` … `### Step 10:` … blocks
  in one printf/heredoc sequence").** Verified empirically (see Issues
  Encountered) that a natural 1..10 ascending document never triggers the
  collision under the pre-fix extractor: `extract_step_block` calls `exit`
  the instant Step 1's own fenced Apply block closes, which always happens
  before the scan reaches a later `### Step 10` heading. The bug is only
  reachable when the colliding heading is scanned BEFORE the real one. The
  reordered fixture is the only construction that is genuinely
  mutation-provable (empirically confirmed RED under the pre-fix extractor,
  GREEN after) while still satisfying the plan's core acceptance criterion:
  `extract_step_block(doc,1,Apply)` returns Step 1's body with zero bytes of
  Step 10's.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] REV-01's grep scope widened to all PASS-path `at line N` occurrences, not only CASE 2's**
- **Found during:** Task 1 (REV-01)
- **Issue:** The plan's `<action>` named only CASE 2's PASS text (`:292`) for
  the `at line` removal, but COUNTER-CASE A (`:315`) and WIDENED TERMINATOR
  PRESERVES REGION (`:359`) also print `at line N` in their PASS text, and the
  plan's own automated `<verify>` greps the FULL script stdout — those two
  sites would have failed the very verify command the plan specifies.
- **Fix:** Rephrased all three PASS-path messages to report the same facts
  relationally (paired counts, "region body present") instead of printing
  line numbers. Relational comparisons and computed values (`c2_prov`,
  `cA_start`, `wb_body`, etc.) are untouched — only the `pass "..."` text
  changed.
- **Files modified:** `migrations/validate-0009-anchor.sh`
- **Verification:** `bash migrations/validate-0009-anchor.sh 2>/dev/null | grep -Eq "\([0-9]+ lines\)|at line [0-9]+"` returns false (no match) on a passing run; full suite stays 0 FAIL.
- **Committed in:** `9646c34` (Task 1 commit)

**2. [Rule 1 - Bug] REV-02's fixture uses out-of-order headings instead of natural ascending order**
- **Found during:** Task 2 (REV-02)
- **Issue:** Empirically verified (via a throwaway `/tmp` reproduction of the
  pre-fix `extract_step_block`, run three ways) that a natural `### Step 1`
  … `### Step 10` ascending document — as the plan's `<action>` literally
  described — does NOT reproduce the IN-01 collision: the extractor's own
  `inb && /^```$/ { exit }` fires the instant Step 1's fenced Apply block
  closes, always before the scan reaches a later Step 10 heading. A
  natural-order fixture would have been GREEN under both the buggy and fixed
  extractor, making it dead-by-construction (D-36) — exactly the defect class
  this milestone exists to close.
- **Fix:** Constructed the synthetic document with `### Step 10` appearing
  BEFORE `### Step 1` in file text order (still all-new content via
  printf-into-$tmp, D-34), which is the only ordering that lets the
  bare-prefix collision actually fire under the pre-fix extractor.
- **Files modified:** `migrations/run-tests.sh`
- **Verification:** Mutation-proven by hand — reverting `delim_ok` guard to
  the bare `index($0, stepp) == 1` test flips `test_extract_step_block_delimiter`
  to 2 FAIL / 2 PASS (wrong body content, Step 10 bytes leaked into Step 1's
  extraction); restoring the guard returns 4/4 PASS.
- **Committed in:** `043350f` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — the plan's literal `<action>`
text undershot what its own `<verify>`/`<acceptance_criteria>` required; both
fixes make the implementation match the stricter, already-locked bar rather
than loosen it).
**Impact on plan:** Both auto-fixes were necessary for the assertions to be
genuinely mutation-provable / to satisfy the plan's own automated verify
commands. No scope creep — no new files, no architectural change.

## Issues Encountered

- **REV-02 fixture design required empirical verification before writing the
  final test.** Initial attempts to reproduce IN-01 with a natural
  1..10-ascending synthetic document, and separately with a document that
  omits Step 1 entirely (only Step 10+ present), were run against a scratch
  copy of the pre-fix `extract_step_block` in `/tmp` to observe actual
  behavior before committing to a fixture shape. Confirmed: natural ascending
  order never reproduces the bug (extractor exits before reaching the
  colliding heading); omitting Step 1 does reproduce it but doesn't match the
  plan's "Step 1's body vs Step 10's body" acceptance framing; the
  out-of-order (`Step 10` before `Step 1`) construction reproduces it AND
  matches the acceptance framing. Documented in the fixture's own header
  comment in `run-tests.sh` so a future reader isn't confused by the unusual
  heading order.
- **`PLAN_START_TIME`/completion timestamp discrepancy in this Summary's
  Performance section.** The 12-02-PLAN.md file's own mtime (13:36) predates
  this execution session's wall-clock observations (up to 12:55 in a
  different capture); both are approximate session-relative markers, not
  independently verified against a monotonic clock — recorded as observed,
  duration estimated from task-to-task tool-call spacing (~55 min).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All three REV-01/02/03 defects from `09-REVIEW.md` are closed with
  independent mutation-proven assertions, each re-runnable by a verifier
  without trusting this Summary's claims (the exact commands are in each
  task's `<verify>`/acceptance criteria and reproduced in the Deviations
  section above).
- `migrations/run-tests.sh` full suite: 406 PASS / 0 FAIL / 1 SKIP (402
  pre-existing + 4 new REV-02 assertions; REV-01's determinism test folds into
  the same PASS count under the `determinism` filter — see task commits for
  the exact per-filter breakdown).
- Plan 12-01 (WR-03 symlink guard) and Plan 12-03 (REV-04 numbering
  convention) were already committed on this branch before this plan ran;
  this plan's file surface (`migrations/validate-0009-anchor.sh`,
  `migrations/run-tests.sh`) did not overlap either. Phase 12 is now fully
  executed (3/3 plans); ready for phase-level re-verification / transition.

## Self-Check: PASSED

- FOUND: `migrations/validate-0009-anchor.sh`
- FOUND: `migrations/run-tests.sh`
- FOUND: `.planning/phases/12-path-safety-review-debt/12-02-SUMMARY.md`
- FOUND: commit `9646c34` (Task 1 — REV-01)
- FOUND: commit `a3b82ad` (Task 3 — REV-03)
- FOUND: commit `043350f` (Task 2 — REV-02)
- FOUND: commit `61eb554` (plan summary)

---
*Phase: 12-path-safety-review-debt*
*Completed: 2026-07-17*
