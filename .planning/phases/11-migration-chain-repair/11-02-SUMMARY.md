---
phase: 11-migration-chain-repair
plan: 02
subsystem: testing
tags: [bash, awk, migrations, tdd, mutation-testing, drift-test]

# Dependency graph
requires:
  - phase: 11-migration-chain-repair
    provides: "11-01's CI harness state (migrations/run-tests.sh, 388 PASS baseline) that this plan's fixture builds on"
provides:
  - "test_migration_0008_step4_write fixture in migrations/run-tests.sh — extracts 0008's real Step 4 Apply block via extract_step_block, executes it against a 0.5.0-seeded no-skills/-tree sandbox, asserts exact .codex/workflow-version.txt content equality against 0.6.0 via cmp"
  - "extract_step_block extended with an inline-code-span fallback — closes the exact gap 11-01-SUMMARY.md flagged (0007/0008's single-line version-record Apply steps were previously unreachable by extraction)"
  - "dispatch filter key 0008-step4"
affects: [12-path-safety-and-review-debt, migration-numbering]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "extract_step_block now recognizes an inline `**Label:** \\`code\\`` code span on the SAME line as the label, in addition to its original fenced-block-following behavior — triggers only when the label line itself carries the inline span, so existing fenced-block callers (0009/0010) are unaffected"
    - "Exact content-equality assertions (cmp -s against a printf-generated reference file) replace grep -q substring checks wherever a fixture claims to prove a written value, per D-05 — grep -q would spuriously pass on any file merely containing the target substring"

key-files:
  created: []
  modified:
    - migrations/run-tests.sh

key-decisions:
  - "extract_step_block was extended (not replaced) to add an inline-code-span extraction fallback, rather than transcribing 0008's Step 4 Apply by hand — required because 0008's own Step 4 Apply is a single-line inline code span, not a fenced block, and migrations are immutable so 0008 itself cannot be reformatted to fit the extractor. The fallback prints the inline content and exits immediately (rather than falling through to scan for a later fence), which also closes a latent 'no ### Step 5 boundary' hazard: without the immediate exit, an unmatched want=1 could have latched onto the unrelated ## Post-checks fenced block, the same failure class that hit migration 0010's Step 3 in 11-01."
  - "Dispatch filter key is 0008-step4 (not a bare '0008' variant) to keep it distinct from the existing 0008 filter, which runs test_migration_0008's full suite."

requirements-completed: [MIGR-08]

# Metrics
duration: ~25min
completed: 2026-07-16
---

# Phase 11 Plan 02: Migration Chain Repair — MIGR-08 Execution Coverage Summary

**New `test_migration_0008_step4_write` fixture extracts migration 0008's real Step 4 Apply block via `extract_step_block` (never transcribed) and asserts exact `.codex/workflow-version.txt` content equality via `cmp`, closing the last residual can't-fail-assertion gap Phase 9.1 existed to close; `extract_step_block` itself was extended with an inline-code-span fallback since 0008's Step 4 Apply is a single-line inline span, not a fenced block.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-16T14:15:00Z (approx.)
- **Completed:** 2026-07-16T14:21:03Z
- **Tasks:** 1 (TDD)
- **Files modified:** 1

## Accomplishments

- `extract_step_block` (`migrations/run-tests.sh`) extended with an inline-code-span fallback: when a `**Label:**` line carries a single inline `` `code` `` span on the same line, that span is extracted and returned immediately, instead of falling through to (fruitlessly) scan for a following fenced block. Fenced-block-following behavior for 0009/0010's style Apply steps is unchanged and re-verified by the full suite.
- `test_migration_0008_step4_write()` added, adjacent to `test_migration_0008`: extracts 0008's Step 4 Apply block via `extract_step_block "$MIGRATION_0008" 4 Apply`, gates it with `assert_extracted_shape` (requiring the substring `.codex/workflow-version.txt`), executes it cd-isolated inside a `mktemp -d` sandbox seeded at `.codex/workflow-version.txt = 0.5.0` with no local `skills/` directory, asserts the Step 4 idempotency check is `not-applied` on that pre-state, and asserts EXACT post-execution content equality against `0.6.0` via `cmp -s` (never `grep -q`).
- Registered under dispatch filter key `0008-step4`.
- **Mutation-proof ritual performed and observed** (see verbatim transcript below) — 0008's write line was temporarily commented out, RED observed, restored, GREEN observed. `git diff --stat migrations/0008-plan-review-gate.md` confirms the file is byte-identical to its committed content after the ritual — migration 0008 ships unmodified.
- `bash migrations/run-tests.sh 0008-step4` exits 0 (5/5 PASS).
- `bash migrations/run-tests.sh` (unfiltered) exits 0 — **393 PASS / 0 FAIL / 1 SKIP** (up from 11-01's 388 baseline: +5 new assertions).
- `vendor/agenticapps-shared/` unedited (`git diff --stat` empty).

## Mutation-Proof Ritual (D-05, captured verbatim)

**Setup:** temporarily edited `migrations/0008-plan-review-gate.md` line 332 from
```
**Apply:** `echo "0.6.0" > .codex/workflow-version.txt`
```
to
```
**Apply:** `# echo "0.6.0" > .codex/workflow-version.txt`
```
(prefixing the inline command with `#`, making the extracted line a shell no-op comment instead of a write).

**RED** (`bash migrations/run-tests.sh 0008-step4`, exit 1):
```
=== MIGR-08 — 0008 Step 4 write, extracted + executed + exact-asserted ===
  PASS 0008 Step 4 Apply: extraction from the real document is non-empty
  PASS 0008 Step 4 Apply: extraction contains '.codex/workflow-version.txt'
  PASS 0008 Step 4 sandbox has no local skills/ directory
  ✓ 0008 Step 4 idempotency check is not-applied against the 0.5.0-seeded pre-state (expected not-applied, exit=1)
  FAIL 0008 Step 4: .codex/workflow-version.txt does NOT read exactly 0.6.0 after the extracted Apply
         got: 0.5.0

=== Summary ===
  PASS: 4
  FAIL: 1
```
`EXIT_CODE=1` — exactly the expected failure mode: extraction still succeeds (the mutation only comments out the executable content, not the surrounding markdown shape), but the exact-equality assertion against `0.6.0` fails because the write never happened and the sandbox's seeded `0.5.0` survives untouched. This is the load-bearing proof that the fixture's core assertion CAN fail — the exact discipline D-05 and Phase 9.1 require.

**Restore:** reverted the line back to `**Apply:** \`echo "0.6.0" > .codex/workflow-version.txt\``.

**GREEN** (`bash migrations/run-tests.sh 0008-step4`, exit 0):
```
=== MIGR-08 — 0008 Step 4 write, extracted + executed + exact-asserted ===
  PASS 0008 Step 4 Apply: extraction from the real document is non-empty
  PASS 0008 Step 4 Apply: extraction contains '.codex/workflow-version.txt'
  PASS 0008 Step 4 sandbox has no local skills/ directory
  ✓ 0008 Step 4 idempotency check is not-applied against the 0.5.0-seeded pre-state (expected not-applied, exit=1)
  PASS 0008 Step 4: .codex/workflow-version.txt reads EXACTLY 0.6.0 after the extracted Apply (cmp, not grep -q)

=== Summary ===
  PASS: 5
```
`EXIT_CODE=0` — 5/5 PASS. `git diff --stat migrations/0008-plan-review-gate.md` returned empty after restoring — the migration file is byte-identical to its git-committed content; the mutation was never committed at any point.

**Verifier note:** re-run this exact cycle independently rather than trusting this transcript, per D-05 and the milestone's "a guard is not shipped until it has been observed failing" standard.

## Task Commits

Each task was committed atomically:

1. **Task 1: MIGR-08 fixture — extract, execute, and assert exact equality on 0008 Step 4 (mutation-proven)** - `73b913b` (test)

_This was the plan's single TDD task. The mutation-proof cycle (RED/GREEN) was performed as part of authoring/verifying this one commit's content, per the plan's explicit ritual instructions — no separate test/feat/refactor split was specified or needed since the target of the fixture (0008) is immutable and the fixture itself was authored complete._

**Plan metadata:** (this commit, docs)

## Files Created/Modified

- `migrations/run-tests.sh` — `extract_step_block` extended with an inline-code-span fallback; new `test_migration_0008_step4_write()` fixture added adjacent to `test_migration_0008`; dispatch registration for filter key `0008-step4`.

## Decisions Made

- **Extended `extract_step_block` rather than transcribing 0008's Step 4 Apply by hand** — see Deviations below for the full rationale; this was necessary to satisfy the plan's own acceptance criterion that the executed content come only from extraction, given 0008's immutable inline-code-span formatting.
- **The inline fallback returns immediately (`exit`) rather than falling through to a fence scan** — deliberately closes a latent hazard: 0008 has no `### Step 5` heading to bound the Step 4 window, so an unguarded fall-through could have latched onto the unrelated `## Post-checks` fenced block below it (the same failure class that hit migration 0010's Step 3 extraction in 11-01, per that plan's own Deviations record).
- **Dispatch filter key `0008-step4`** (not reusing bare `0008`) keeps this fixture independently runnable without re-running all of `test_migration_0008`'s ~30 assertions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `extract_step_block` returned empty on migration 0008's Step 4 Apply — the plan's own required extraction target**
- **Found during:** Task 1 (initial fixture authoring, before running anything)
- **Issue:** The plan's interfaces section cites `extract_step_block "$MIGRATION_0008" 4 Apply` as directly reusable, but reading the actual document (`migrations/0008-plan-review-gate.md:332`) showed Step 4's Apply is a single-line INLINE code span (`` **Apply:** `echo "0.6.0" > .codex/workflow-version.txt` ``), not a fenced (` ``` `) block. `extract_step_block`'s original implementation only recognizes fenced blocks following a bare `**Label:**` line; against 0008's real shape it sets `want=1` and then finds no fence before the end of the (unbounded, since 0008 has no `### Step 5`) scan window, silently returning empty. This is precisely the gap 11-01-SUMMARY.md's Deviations section flagged as a latent risk: "their own version-record steps (Step 4) are inline code spans that no fixture currently extracts via `extract_step_block` ... flagged for awareness if a future fixture ever tries to extract those steps." This plan is that future fixture, and the plan's own acceptance criteria (`grep -c 'extract_step_block .*4 Apply' migrations/run-tests.sh` ≥ 1, non-empty extraction required, `bash migrations/run-tests.sh 0008-step4` exits 0) cannot be satisfied without fixing the extractor, since migration 0008 itself is immutable per the repo's compatibility constraint (never edited; fixed forward only).
- **Fix:** Extended `extract_step_block` with an inline-code-span fallback: when the `**Label:**` line itself carries a single inline `` `code` `` span (nothing else but optional trailing whitespace), that span is extracted and printed immediately, bypassing the fence scan entirely. When the label line carries nothing inline (0009/0010's style — the label alone on its own line, followed by a fence), the original fenced-block-following behavior is unchanged. Verified backward-compatible by re-running the full unfiltered suite (393 PASS / 0 FAIL / 1 SKIP, no regressions in `test_migration_0009` or `test_migration_0010`, both of which call `extract_step_block` for fenced Apply blocks).
- **Files modified:** `migrations/run-tests.sh`
- **Verification:** `bash migrations/run-tests.sh 0008-step4` (5/5 PASS) and `bash migrations/run-tests.sh` (393 PASS / 0 FAIL / 1 SKIP), plus the mutation-proof RED→GREEN cycle documented above.
- **Committed in:** `73b913b` (Task 1 commit — the fix landed as part of the single task, since it was discovered before any fixture code could run, not as a later correction)

---

**Total deviations:** 1 auto-fixed (1 Rule-1 bug)
**Impact on plan:** Necessary correctness fix, no scope creep — without it, the plan's D-05 requirement (extraction via `extract_step_block`, never a hand-copied transcription) was structurally unsatisfiable against 0008's real, immutable document shape. The fix is strictly additive and re-verified not to change behavior for any existing caller.

## Issues Encountered

None beyond the deviation above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- MIGR-08 is fully closed: the fixture extracts (never transcribes) 0008's real Step 4 Apply block, executes it against a correctly pre-migration-seeded sandbox, and asserts exact content equality — mutation-proven RED→GREEN, independently re-runnable by the verifier.
- The full local suite is green: 393 PASS / 0 FAIL / 1 SKIP (up from 11-01's 388).
- `vendor/agenticapps-shared/` is unedited (`git diff --stat` empty), preserving the pinned drift MECHANISM per ADR-0035.
- Migration 0008 is unmodified in git (`git diff --stat migrations/0008-plan-review-gate.md` empty) — the mutation-proof ritual was temporary and never committed, per this plan's explicit instruction.
- No blockers for Phase 11's remaining scope or for downstream phases.

## Self-Check: PASSED

- FOUND: `migrations/run-tests.sh` contains `test_migration_0008_step4_write` and the `0008-step4` dispatch registration
- FOUND commit `73b913b` (Task 1: MIGR-08 fixture, extraction fix, mutation-proven)
- `bash migrations/run-tests.sh 0008-step4` exits 0 (5/5 PASS)
- `bash migrations/run-tests.sh` (unfiltered) exits 0 — 393 PASS / 0 FAIL / 1 SKIP
- `git diff --stat vendor/agenticapps-shared/` is empty (pinned mechanism untouched)
- `git diff --stat migrations/0008-plan-review-gate.md` is empty (migration restored, unmodified)

---
*Phase: 11-migration-chain-repair*
*Completed: 2026-07-16*
