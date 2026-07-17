---
phase: 11-migration-chain-repair
plan: 05
subsystem: testing
tags: [bash, migration-fixtures, mutation-testing, jq]

# Dependency graph
requires:
  - phase: 11-migration-chain-repair (plan 01)
    provides: migrations/0010-heal-0007-knowledge-capture.md and its initial test_migration_0010 fixture
provides:
  - Execution-backed (mutation-proven) version-floor coverage for migration 0010's pre-flight
  - <repo-name> placeholder-resolution assertion in 0010's D-06 delivery block, at parity with 0007
affects: [11-migration-chain-repair verification, future migration fixtures following the extract-and-execute pattern]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Seeded-version sandbox execution: _m0010_mk_version_sandbox builds a .git + .codex/workflow-version.txt-only sandbox differing in exactly one variable, executed via the existing _m0010_apply helper — mirrors test_migration_0009's _m0009_mk_project / _m0009_apply pattern for its own pre-flight."

key-files:
  created: []
  modified:
    - migrations/run-tests.sh

key-decisions:
  - "Reused the existing _m0010_apply helper (already present for Step 1/2/3 execution) for pf_block execution instead of inventing a new runner, since its (sandbox, CODEX_HOME, block_text) signature already matched the need."
  - "Pinned CODEX_HOME to REPO_ROOT (the real repo's own templates) across all four version-seeded sandboxes, so the pre-flight's template-presence guards pass identically in every case and the .codex/workflow-version.txt file is the SOLE variable under test — isolating the floor regex exactly as 0009's fixture isolates its mirror-guard cases from its own version gate."
  - "Placed the WR-03 <repo-name> assertion immediately after the existing D-06 knowledge_capture.enabled check (not appended at the end), mirroring test_migration_0007's placement directly after its own equivalent check."

patterns-established:
  - "Version-floor mutation-proofing: build N sandboxes differing only in the field under test, execute the extracted (never hand-transcribed) block against each, assert exit codes — proven by an actual mutation ritual with transcripts in the SUMMARY, not merely claimed."

requirements-completed: [MIGR-10]

# Metrics
duration: ~30min
completed: 2026-07-17
---

# Phase 11 Plan 05: Harden test_migration_0010 (WR-02 + WR-03) Summary

**test_migration_0010 now executes its extracted pre-flight against four seeded-version sandboxes (0.3.0/0.4.0/0.5.0/0.6.0), mutation-proven, and asserts `<repo-name>` placeholder resolution in the D-06 delivery block, closing both WARNING-level gaps from 11-VERIFICATION.md.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-07-17 (session start)
- **Completed:** 2026-07-17T10:14:32Z
- **Tasks:** 2 completed
- **Files modified:** 1 (`migrations/run-tests.sh`)

## Accomplishments

- WR-02 closed: `test_migration_0010` now EXECUTES the extracted `pf_block` (via a new `_m0010_mk_version_sandbox` helper + the existing `_m0010_apply` runner) against sandboxes seeded at `0.3.0`/`0.4.0`/`0.5.0`/`0.6.0`, asserting accept(exit 0)/reject(non-zero) per 0010's `0.4.0 -> 0.5.0` floor.
- Mutation ritual performed and recorded (see transcripts below): mutating the floor regex to `0\.(4|6)\.0` drives the 0.5.0 and 0.6.0 assertions RED (21 PASS/2 FAIL); restoring drives GREEN (23 PASS/0 FAIL); `git status --porcelain` confirmed byte-identical restoration.
- WR-03 closed: the D-06 block now asserts `knowledge_capture.note` ends with `/sandbox.md` (the sandbox's real repo dir name) AND that no literal `<repo-name>` remains in `.planning/config.json`, mirroring `test_migration_0007`'s identical check and 0010's own "ALWAYS true on success" Post-check claim.
- Mutation-proofed WR-03 too: breaking Step 1's `gsub` target (`<repo-name>` -> `<not-repo-name>`) drove the new assertion RED (23 PASS/1 FAIL); restoring drove GREEN (24 PASS/0 FAIL); `git status --porcelain` confirmed byte-identical restoration.
- Full suite verified green throughout: 397 PASS / 0 FAIL / 2 SKIP (the 2 SKIPs are pre-existing environment conditions — `0000-baseline.md is interactive-only` and `core spec repo not adjacent` — unrelated to this plan's changes).

## Task Commits

Each task was committed atomically:

1. **Task 1: Execute test_migration_0010's extracted pre-flight against seeded-version sandboxes (WR-02)** - `aaabff4` (test)
2. **Task 2: Assert 0010's `<repo-name>` placeholder resolution in the D-06 delivery block (WR-03)** - `051403f` (test)

_Note: both tasks were `tdd="true"` gap-closure hardenings on an existing fixture (not new RED/GREEN feature cycles) — verification was done via mutation ritual (breaking then restoring the production code under test) rather than a separate failing-test-first commit, per the plan's own `<verify><automated>` gates which were deliberately written to fail on the pre-change tree._

## Files Created/Modified
- `migrations/run-tests.sh` - Added `_m0010_mk_version_sandbox` helper; added WR-02 execution block (4 seeded-version sandboxes, `_m0010_apply` against extracted `pf_block`); added WR-03 `<repo-name>` placeholder-resolution assertion to the D-06 block, plus its corresponding `_m0010_fail` cascade line for extraction-failure consistency.

## Decisions Made
- Reused the pre-existing `_m0010_apply` helper (built for Step 1/2/3 execution) for the pre-flight execution rather than inventing a parallel runner — its `(sandbox_dir, codex_home, block_text)` signature already fit.
- New helper `_m0010_mk_version_sandbox <tmp> <name> <version>` mirrors `_m0009_mk_project`'s no-scaffolder-tree shape (D-07): `.git` + `.codex/workflow-version.txt` only, nothing else, so the version file is provably the sole variable across all four sandboxes.
- CODEX_HOME pinned to `REPO_ROOT` (the trusted real repo, already used for Step 1/2/3 execution) across the WR-02 sandboxes, holding both required templates constant so a floor accept/reject can only be attributed to the version-floor regex.

## Deviations from Plan

None - plan executed exactly as written. Both tasks matched the plan's `<action>` and `<acceptance_criteria>` directly; no architectural changes, no missing-functionality gaps, no blocking issues encountered.

## Issues Encountered

- The worktree's `vendor/agenticapps-shared` git submodule was not initialized, which made `migrations/run-tests.sh` abort immediately with "agenticapps-shared submodule not initialized." Ran `git submodule update --init --recursive` (a read-only, non-code-modifying environment fix, not a plan deviation) to unblock local test execution — no repository files were changed by this step.

## Mutation-Proof Transcripts (verifier re-run material)

### WR-02 — version-floor regex mutation (`0\.(4|5)\.0` -> `0\.(4|6)\.0`)

**Baseline GREEN** (`bash migrations/run-tests.sh 0010`): 23 PASS / 0 FAIL, exit 0. All four WR-02 floor assertions PASS (0.3.0 rejected exit=3, 0.4.0 accepted exit=0, 0.5.0 accepted exit=0, 0.6.0 rejected exit=3).

**Mutated** (`migrations/0010-heal-0007-knowledge-capture.md:84` regex changed to `^0\.(4|6)\.0$`), re-ran `bash migrations/run-tests.sh 0010`:
```
FAIL WR-02 floor (execution): 0.5.0 (idempotent re-apply) ACCEPTED by the extracted pre-flight — got exit=3
FAIL WR-02 floor (execution): 0.6.0 (above 0010's slot) REJECTED by the extracted pre-flight — got exit=0
=== Summary ===
  PASS: 21
  FAIL: 2
```
Exit code 1 (RED), exactly the two assertions the mutation was predicted to flip (0.5.0 accept->reject, 0.6.0 reject->accept).

**Restored** (migration doc reverted to the original regex), re-ran `bash migrations/run-tests.sh 0010`: 23 PASS / 0 FAIL, exit 0 (GREEN). `git status --porcelain migrations/0010-heal-0007-knowledge-capture.md` returned empty — confirming the file is byte-identical to the committed state; the mutation never landed in any commit.

### WR-03 — placeholder-resolution mutation (`gsub("<repo-name>"; ...)` -> `gsub("<not-repo-name>"; ...)`)

**Baseline GREEN** (after Task 2's edit): 24 PASS / 0 FAIL, exit 0, including `PASS D-06/WR-03: <repo-name> resolved in knowledge_capture.note (ends with /sandbox.md); no placeholder left`.

**Mutated** (`migrations/0010-heal-0007-knowledge-capture.md:123`, Step 1's `gsub` target changed so `<repo-name>` no longer matches), re-ran:
```
FAIL D-06/WR-03: <repo-name> resolved in knowledge_capture.note (ends with /sandbox.md); no placeholder left
=== Summary ===
  PASS: 23
  FAIL: 1
```
Exit code 1 (RED) — exactly the new assertion, and only that assertion.

**Restored**, re-ran: 24 PASS / 0 FAIL, exit 0 (GREEN). `git status --porcelain migrations/0010-heal-0007-knowledge-capture.md` returned empty — byte-identical restoration confirmed.

### Full-suite regression check (after both tasks)

`bash migrations/run-tests.sh` (unfiltered, full suite): 397 PASS / 0 FAIL / 2 SKIP, exit 0. `git status --short` at that point showed only `M migrations/run-tests.sh` (this plan's own file) — no unrelated files touched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both WR-02 and WR-03 warnings from `11-VERIFICATION.md` are now closed with execution-backed, mutation-proven coverage; the verifier can independently re-run the same mutation cycles documented above.
- MIGR-10 remains SATISFIED (unchanged); this plan only strengthens its existing fixture's mutation-coverage, it does not alter migration 0010's behavior or any other phase success criterion.
- No blockers for the phase's remaining open item: SC#3 / MIGR-11 (the SKILL.md Stage D supersession gap) is out of scope for this plan and is tracked separately (plan 11-04, same wave, zero file overlap).

---
*Phase: 11-migration-chain-repair*
*Completed: 2026-07-17*

## Self-Check: PASSED
- FOUND: `.planning/phases/11-migration-chain-repair/11-05-SUMMARY.md`
- FOUND commit: `aaabff4` (Task 1)
- FOUND commit: `051403f` (Task 2)
- FOUND commit: `0081e0c` (SUMMARY)
- `git status --short` clean at time of check
