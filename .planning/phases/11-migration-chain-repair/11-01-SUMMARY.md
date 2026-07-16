---
phase: 11-migration-chain-repair
plan: 01
subsystem: infra
tags: [migrations, bash, awk, jq, tdd, drift-test, semver]

# Dependency graph
requires:
  - phase: 10-ci-that-can-prove-failure
    provides: CI harness (migrations/run-tests.sh) that now runs this plan's fixtures on ubuntu + macOS
provides:
  - migrations/0010-heal-0007-knowledge-capture.md — new forward migration re-delivering 0007's Steps 1/2/4 payload behind a corrected .codex/workflow-version.txt-only pre-flight
  - test_migration_0010 fixture in migrations/run-tests.sh (extraction-gated D-06 delivery + D-07 document-contract assertions), RED-before / GREEN-after observed
  - test_drift leg-1 fix: drift target selected by semver-max to_version across migrations/*.md, not filename sort
affects: [12-path-safety-and-review-debt, migration-numbering, update-codex-agenticapps-workflow-skill]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Migration fixtures extract pre-flight/applies_to/Step-Apply blocks from the migration document itself via extract_preflight_block/extract_step_block, never hand-transcribed (TEST-01)"
    - "Every extraction gated by assert_extracted_shape (D-36) before execution or assertion — an extraction gate down reports loud FAILs via a per-test _fail helper, never silent pass-through"
    - "A migration Step's Apply MUST be a fenced code block, not an inline code span, if any fixture extracts it via extract_step_block (extract_step_block only recognizes fenced blocks)"
    - "Drift-target selection is consumer-owned policy (ADR-0035): semver-max to_version across migrations/*.md, computed with a portable numeric-field sort (no GNU-only version-sort flag), not delegated to the pinned filename-sort mechanism when a version-backport migration is present"

key-files:
  created:
    - migrations/0010-heal-0007-knowledge-capture.md
  modified:
    - migrations/run-tests.sh

key-decisions:
  - "Migration 0010's Step 3 (version record) Apply is a fenced ```bash block, diverging from 0007/0008's inline-code-span style for the equivalent step — required because extract_step_block only recognizes fenced blocks; the inline form caused the extractor to fall through into the next fenced block (Post-checks), a Rule-1 bug caught and fixed during Task 2's GREEN run."
  - "test_drift's leg 1 no longer calls the shared run_drift_test() helper; it computes the drift target inline as the semver-max to_version across migrations/*.md. The pinned vendor/agenticapps-shared mechanism is unedited — only this consumer's policy changed, per ADR-0035."

requirements-completed: [MIGR-10]

# Metrics
duration: ~20min
completed: 2026-07-16
---

# Phase 11 Plan 01: Migration Chain Repair — 0007 Heal Summary

**New forward migration 0010 re-delivers 0007's knowledge-capture payload behind a `.codex/workflow-version.txt`-only pre-flight, closing the chain break that made every install stuck at 0.4.0 unable to reach 0.5.0+; `test_drift` now selects its target by semver-max `to_version` instead of filename sort so 0010's version-backport doesn't trip a false mismatch.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-16T15:53:00+02:00 (approx.)
- **Completed:** 2026-07-16T16:03:10+02:00
- **Tasks:** 3 (2 TDD, 1 auto)
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- `migrations/0010-heal-0007-knowledge-capture.md` created: `id: 0010`, `from_version: 0.4.0`, `to_version: 0.5.0`, three steps (config.json seed, AGENTS.md ritual-tail insert, version record), pre-flight verbatim-reusing 0008's proven floor-check pattern, zero references to `skills/agentic-apps-workflow` in any executable surface.
- `test_migration_0010` fixture added to `migrations/run-tests.sh`, extracting 0010's own pre-flight/applies_to/Step-Apply blocks (TEST-01 discipline), gated by `assert_extracted_shape`, asserting both the D-06 delivery contract (payload lands, version heals to `0.5.0` on a clean 0.4.0 sandbox with no `skills/` tree) and the D-07 document contract (no executable surface names the buggy scaffolder-relative path).
- **RED→GREEN observed and captured** (success criterion #1) — see below.
- `test_drift` fixed to select the drift target by semver-max `to_version` across all migration files rather than by filename sort, so migration 0010's version-backport (filename sorts last, `to_version` is a earlier `0.5.0`) does not falsely trip drift. Sanity-mutated (SKILL.md → `0.9.9` → RED → restore → GREEN, byte-identical) to prove the leg still detects real drift.
- Full suite: `bash migrations/run-tests.sh` exits 0 — **388 PASS / 0 FAIL / 1 SKIP**.

## RED→GREEN Transition (TDD, captured verbatim)

**RED — before `migrations/0010-heal-0007-knowledge-capture.md` existed** (`bash migrations/run-tests.sh 0010`, exit 1):

```
=== Migration 0010 — Heal 0007 knowledge-capture chain break ===
awk: can't open file /Users/donald/Sourcecode/agenticapps/codex-workflow/migrations/0010-heal-0007-knowledge-capture.md
 source line number 1
  FAIL 0010 Pre-flight: extraction is EMPTY — heading/fence shape drift
  FAIL 0010 Pre-flight: extraction does not contain '.codex/workflow-version.txt' (extraction was empty)
  FAIL 0010 applies_to: extraction is EMPTY — heading/fence shape drift
  FAIL 0010 applies_to: extraction does not contain '.planning/config.json' (extraction was empty)
  FAIL 0010 Step 1 Apply: extraction is EMPTY — heading/fence shape drift
  FAIL 0010 Step 1 Apply: extraction does not contain '.planning/config.json' (extraction was empty)
  FAIL 0010 Step 2 Apply: extraction is EMPTY — heading/fence shape drift
  FAIL 0010 Step 2 Apply: extraction does not contain 'AGENTS.md' (extraction was empty)
  FAIL 0010 Step 3 Apply: extraction is EMPTY — heading/fence shape drift
  FAIL 0010 Step 3 Apply: extraction does not contain '.codex/workflow-version.txt' (extraction was empty)
  FAIL D-07: no executable surface names skills/agentic-apps-workflow — NOT ASSERTED: one or more extractions failed
  FAIL D-07 sandbox self-guard: no local skills/ directory — NOT ASSERTED: one or more extractions failed
  FAIL D-06 sandbox self-guard: carries none of 0007's artifacts before apply — NOT ASSERTED: extraction failed
  FAIL Step 1 Apply executes cleanly against the 0.4.0 sandbox — NOT ASSERTED: extraction failed
  FAIL Step 2 Apply executes cleanly against the 0.4.0 sandbox — NOT ASSERTED: extraction failed
  FAIL Step 3 Apply executes cleanly against the 0.4.0 sandbox — NOT ASSERTED: extraction failed
  FAIL D-06: knowledge_capture.enabled is true in .planning/config.json after Steps 1-3 — NOT ASSERTED: extraction failed
  FAIL D-06: AGENTS.md carries the Knowledge Capture — Ritual Tail section after Steps 1-3 — NOT ASSERTED: extraction failed
  FAIL D-06: .codex/workflow-version.txt reads exactly 0.5.0 after Steps 1-3 — NOT ASSERTED: extraction failed

=== Summary ===
  PASS: 0
  FAIL: 19
```
`EXIT_CODE=1` — 19 FAIL / 0 PASS, exactly the expected empty-extraction cascade (assert_extracted_shape correctly reports both the non-empty check and the substring check as FAIL for every gate, and everything downstream reports "NOT ASSERTED" via the loud-fail helper rather than silently vanishing).

**GREEN — after `migrations/0010-heal-0007-knowledge-capture.md` was authored** (`bash migrations/run-tests.sh 0010`, exit 0):

```
=== Migration 0010 — Heal 0007 knowledge-capture chain break ===
  PASS 0010 Pre-flight: extraction from the real document is non-empty
  PASS 0010 Pre-flight: extraction contains '.codex/workflow-version.txt'
  PASS 0010 applies_to: extraction from the real document is non-empty
  PASS 0010 applies_to: extraction contains '.planning/config.json'
  PASS 0010 Step 1 Apply: extraction from the real document is non-empty
  PASS 0010 Step 1 Apply: extraction contains '.planning/config.json'
  PASS 0010 Step 2 Apply: extraction from the real document is non-empty
  PASS 0010 Step 2 Apply: extraction contains 'AGENTS.md'
  PASS 0010 Step 3 Apply: extraction from the real document is non-empty
  PASS 0010 Step 3 Apply: extraction contains '.codex/workflow-version.txt'
  PASS D-07: no executable surface (pre-flight, applies_to, every Step Apply) names skills/agentic-apps-workflow
  PASS D-07 sandbox self-guard: no local skills/ directory (no-scaffolder-tree shape)
  PASS D-06 sandbox self-guard: carries none of 0007's artifacts before apply (clean 0.4.0 state)
  PASS Step 1 Apply executes cleanly against the 0.4.0 sandbox — got exit=0
  PASS Step 2 Apply executes cleanly against the 0.4.0 sandbox — got exit=0
  PASS Step 3 Apply executes cleanly against the 0.4.0 sandbox — got exit=0
  PASS D-06: knowledge_capture.enabled is true in .planning/config.json after Steps 1-3
  PASS D-06: AGENTS.md carries the Knowledge Capture — Ritual Tail section after Steps 1-3
  PASS D-06: .codex/workflow-version.txt reads exactly 0.5.0 after Steps 1-3

=== Summary ===
  PASS: 19
```
`EXIT_CODE=0` — 19 PASS / 0 FAIL. Success criterion #1 (RED-before / GREEN-after) is directly observed, not inferred.

Note: the very first GREEN attempt actually FAILED on 2 assertions (`Step 3 Apply executes cleanly` and the version-heal check) — see Deviations below for the root cause and fix, applied before this final GREEN capture.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author test_migration_0010 fixture + dispatch registration; observe RED** - `1d2ad7c` (test)
2. **Task 2: Author migration 0010 (0007-fix); observe the fixture GREEN** - `ee48b0e` (feat)
3. **Task 3: Fix test_drift so 0010's backport to_version keeps the suite green** - `153c784` (fix)

_TDD tasks 1/2 form the RED→GREEN pair; no separate refactor commit was needed._

## Files Created/Modified

- `migrations/0010-heal-0007-knowledge-capture.md` — new forward migration: 3 steps (config.json `knowledge_capture` seed, AGENTS.md ritual-tail insert, `.codex/workflow-version.txt` record), pre-flight reusing 0008's version-floor pattern, no target-project `skills/` reference.
- `migrations/run-tests.sh` — `test_migration_0010()` + dispatch registration (Task 1); `test_drift`'s leg 1 rewritten to select the drift target by semver-max `to_version` (Task 3).

## Decisions Made

- **Step 3's Apply is a fenced code block, not inline** — see Deviations below; this is the one place 0010 deliberately diverges from 0007/0008's exact formatting for the equivalent step, required by the extraction mechanism this plan's own fixture uses.
- **`test_drift` leg 1 stopped delegating to `run_drift_test()`** and instead computes the semver-max `to_version` inline. The pinned vendor mechanism is untouched (confirmed via `git diff --stat vendor/agenticapps-shared/` — empty); only the consumer-owned policy changed, consistent with ADR-0035's mechanism/policy split.
- **No payload-presence detection in migration 0010** (D-01/D-02, as locked in 11-CONTEXT.md) — verified: the pre-flight is a strict version-floor gate only; the manual-0.5.0-escape operator is deliberately out of scope for this plan, routed to MIGR-11's future Stage D documentation instead.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Migration 0010 Step 3's Apply block was an inline code span, which `extract_step_block` cannot parse — the extractor fell through to the wrong fenced block**
- **Found during:** Task 2 (first GREEN attempt)
- **Issue:** Step 3's Apply was written as `` **Apply:** `echo "0.5.0" > .codex/workflow-version.txt` `` (inline code span), copying 0007's/0008's exact formatting for their equivalent version-record step. `extract_step_block` only recognizes fenced (```` ``` ````) blocks following a `**Label:**` line; with no fence at Step 3's `**Apply:**` line, the awk state machine's `want` flag stayed set and latched onto the *next* fenced block in the document — the `## Post-checks` bash block. The fixture then executed the post-checks block (an assertion script) as if it were Step 3's Apply, which happened to `exit 1` on the still-unhealed `.codex/workflow-version.txt` check, producing a misleading FAIL two levels removed from the real cause.
- **Fix:** Converted Step 3's Apply to a fenced ` ```bash ` block containing the same single line (`echo "0.5.0" > .codex/workflow-version.txt`). No other step needed this fix — Steps 1 and 2 already used fenced blocks.
- **Files modified:** `migrations/0010-heal-0007-knowledge-capture.md`
- **Verification:** Re-ran `bash migrations/run-tests.sh 0010` — all 19 assertions PASS, exit 0.
- **Committed in:** `ee48b0e` (part of Task 2's commit — the fix landed before the GREEN capture recorded in this SUMMARY, so no separate commit was needed)

---

**Total deviations:** 1 auto-fixed (1 Rule-1 bug, caught by the fixture's own execution — exactly the discipline TDD is meant to produce)
**Impact on plan:** Necessary correctness fix, no scope creep. It also surfaces a latent risk in 0007/0008: their own version-record steps (Step 4) are inline code spans that no fixture currently extracts via `extract_step_block` — those tests hand-transcribe the equivalent command instead, so they never hit this failure mode. Not in scope to change here (immutable migrations); flagged for awareness if a future fixture ever tries to extract those steps.

## Issues Encountered

None beyond the deviation above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- MIGR-10 is fully closed: migration 0010 exists, is fixture-tested (RED→GREEN observed), and the full local suite (388 PASS / 0 FAIL / 1 SKIP) is green including `test_drift` and `test_migration_0010`.
- `vendor/agenticapps-shared/` is unedited (`git diff --stat` empty), preserving the pinned drift MECHANISM per ADR-0035.
- Phase 11's remaining scope (MIGR-11 Stage D recovery-runbook documentation, MIGR-08 execution-coverage fixture) is **not** covered by this plan — 11-01 was scoped to MIGR-10 only per its frontmatter (`requirements: [MIGR-10]`). Subsequent 11-0N plans pick those up.
- No blockers for the next plan in this phase.

---
*Phase: 11-migration-chain-repair*
*Completed: 2026-07-16*
