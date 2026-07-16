---
phase: 11-migration-chain-repair
verified: 2026-07-16T18:12:38Z
status: gaps_found
score: 3/4 must-haves verified
overrides_applied: 0
gaps:
  - truth: "update-codex-agenticapps-workflow/SKILL.md Stage D documents the operator path for a project stuck on 0007's permanent pre-flight abort once 0010 SUPERSEDES the same 0.4.0→0.5.0 transition — readable as a defined, NON-LOOPING procedure, not a dead end (Success Criterion #3 / MIGR-11)."
    status: failed
    reason: >
      Stage A step 4 of SKILL.md (lines ~45-51) selects pending migrations purely
      by from_version <= project_version AND to_version > project_version, sorted
      by id ascending — there is no supersession rule anywhere in the file, in
      migrations/README.md, or in migration frontmatter (confirmed: 0007 and 0010
      both carry from_version: 0.4.0 / to_version: 0.5.0, verified by grep against
      both files' frontmatter). Independently re-derived the consequence the
      review (11-REVIEW.md CR-01/CR-02) predicted:
      (a) For a project stuck at 0.4.0, Stage A's own algorithm computes BOTH 0007
      and 0010 as pending and sorts 0007 first (id ascending) — so a re-run would
      hit 0007's aborting pre-flight again, contradicting the Recovery bullet's
      claim at SKILL.md:95-102 ("0007 no longer selects and 0010 applies instead").
      (b) For an operator hand-forced to 0.5.0, migration 0010's to_version (0.5.0)
      is NOT > 0.5.0, so Stage A's own pending formula never selects 0010 — the
      Recovery bullet's instruction to run `--migration 0010` (SKILL.md:103-111)
      relies on the Flags table's own definition of `--migration NNNN` as "apply
      only the named migration (skip other pending)" — i.e. a filter over an
      already-computed pending set, not an override of the eligibility formula —
      so following the documented instructions verbatim would most likely produce
      "project is up-to-date" and silently fail to deliver the payload.
      No commit touches SKILL.md after ae59833 (the commit reviewed by 11-REVIEW.md);
      the file content read directly from the working tree is byte-identical to what
      the review analyzed. CR-01 and CR-02 are unresolved, not narrative nitpicks —
      MIGR-11's own requirement text ("...so an operator on a stuck 0.4.0 project
      has a defined, non-looping path forward") is not met: the documented recovery
      path does not actually terminate as described.
    artifacts:
      - path: "skills/update-codex-agenticapps-workflow/SKILL.md"
        issue: "Stage A step 4 (lines 45-51) has no supersession rule; the Stage D recovery bullets (lines 88-111) assert outcomes ('0007 no longer selects', '--migration 0010 delivers the missing payload') that Stage A's own documented algorithm does not produce."
    missing:
      - "Either (a) add an explicit supersession rule to Stage A step 4 — e.g. 'when two pending migrations share the same to_version, the higher-id migration supersedes lower-id migrations targeting the same slot; drop the superseded migration(s) from the apply order' — cross-referenced from the Recovery bullet, or (b) rewrite the first Recovery bullet to describe the actual mechanics (0007 will still be attempted and abort; the user must skip-with-warning it before 0010 is reached)."
      - "Explicitly document that --migration NNNN bypasses Stage A's to_version > project_version boundary check (i.e. it also matches to_version == project_version) so the second Recovery bullet's '--migration 0010' instruction actually selects 0010 for a project already at exactly 0.5.0 — without this, the documented flag cannot deliver the promised recovery."
human_verification: []
---

# Phase 11: Migration Chain Repair Verification Report

**Phase Goal:** Every real install stuck between 0.4.0 and 0.5.0 can reach 0008/0009's already-correct floor-check logic, and MIGR-08's execution-coverage gap is shut.
**Verified:** 2026-07-16T18:12:38Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 0.4.0 sandbox with none of 0007's artifacts, run through 0010, ends with Steps 1/2/4 payload present + `.codex/workflow-version.txt` = 0.5.0; RED-before/GREEN-after observed | ✓ VERIFIED | `migrations/0010-heal-0007-knowledge-capture.md` exists with the correct payload split; `test_migration_0010` (`migrations/run-tests.sh:4834-4970`) extracts and executes Step 1/2/3 Apply blocks against a clean 0.4.0/no-`skills/`-tree sandbox and asserts config block + AGENTS.md section + `0.5.0` version. Captured RED transcript (19 FAIL/0 PASS, empty-extraction cascade) and GREEN transcript (19 PASS/0 FAIL) in 11-01-SUMMARY.md are consistent with the code read directly. Full suite independently re-run: 393 PASS / 0 FAIL / 1 SKIP. **Caveat (see WR-02 below):** the extracted pre-flight block itself (`pf_block`) is gated by `assert_extracted_shape` and substring-checked for D-07 but is never `eval`'d/executed against any sandbox in this fixture — the corrected version-floor regex is proven present as text, not proven correct by execution. This does not invalidate the literal SC#1 text (payload + version, RED/GREEN) but is a real mutation-coverage gap, logged as a warning. |
| 2 | Document-contract fixture asserts 0010's pre-flight literal executable line contains no `skills/agentic-apps-workflow` substring | ✓ VERIFIED | `test_migration_0010` D-07 block (`migrations/run-tests.sh:4869-4886`) greps the extracted `pf_block`, `applies_to_block`, and all three Step Apply blocks for the literal substring `skills/agentic-apps-workflow` and fails if found. Independently confirmed migration 0010's Pre-flight section (`migrations/0010-heal-0007-knowledge-capture.md:65-98`) greps `.codex/workflow-version.txt` exclusively — no `skills/**/SKILL.md` reference in any executable block. |
| 3 | `update-codex-agenticapps-workflow/SKILL.md` Stage D documents the operator path for 0007's permanent pre-flight abort once 0010 supersedes the same transition, as a defined NON-LOOPING procedure | ✗ FAILED | See Gaps below. Independently confirmed: Stage A step 4 (SKILL.md:45-51) has no supersession rule; 0007 and 0010 share identical `from_version`/`to_version` frontmatter (both 0.4.0→0.5.0, confirmed by direct grep); the Recovery bullets (SKILL.md:88-111) assert outcomes the documented algorithm does not produce. This is CR-01/CR-02 from 11-REVIEW.md, confirmed still present and unfixed (no commit touches SKILL.md after `ae59833`, the reviewed commit). |
| 4 | MIGR-08's fixture extracts 0008's Step 4 Apply block via `extract_step_block`, executes it against a sandbox seeded at the pre-migration value, asserts exact `.codex/workflow-version.txt` content equality; RED when write line broken, GREEN when restored | ✓ VERIFIED | `test_migration_0008_step4_write` (`migrations/run-tests.sh:1915-1972`) extracts via `extract_step_block "$MIGRATION_0008" 4 Apply`, seeds sandbox at `0.5.0`, executes the extracted block via `eval`, asserts exact equality via `cmp -s` against a `printf '0.6.0\n'` reference (never `grep -q`). **Independently re-ran the full mutation-proof cycle myself** (not trusting the SUMMARY transcript): baseline GREEN (5/5 PASS, exit 0) → commented out 0008's `echo "0.6.0" > .codex/workflow-version.txt` line → RED observed (4 PASS/1 FAIL, exit 1, `got: 0.5.0`) → restored the line → GREEN observed (5/5 PASS, exit 0) → confirmed `git status --porcelain migrations/0008-plan-review-gate.md` empty (file byte-identical to committed state, mutation never landed). |

**Score:** 3/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `migrations/0010-heal-0007-knowledge-capture.md` | New forward migration re-delivering 0007 Steps 1/2/4, dropping Step 3, corrected pre-flight | ✓ VERIFIED | Exists, `id: 0010`, `from_version: 0.4.0`, `to_version: 0.5.0`; pre-flight greps `.codex/workflow-version.txt` exclusively; Step 3 (scaffolder bump) absent by design, documented in `## Notes`. |
| `migrations/run-tests.sh` — `test_migration_0010` | Extraction-gated D-06/D-07 fixture, RED-before/GREEN-after | ✓ VERIFIED (with coverage caveat) | Present and wired into dispatch (`migrations/run-tests.sh:5021`). Pre-flight block extracted but not executed (WR-02). |
| `migrations/run-tests.sh` — `test_migration_0008_step4_write` | Extract-execute-assert mutation-proven fixture for MIGR-08 | ✓ VERIFIED | Present, wired into dispatch under filter key `0008-step4` (`migrations/run-tests.sh:5012-5013`). Independently re-ran RED→GREEN cycle myself (see truth #4). |
| `skills/update-codex-agenticapps-workflow/SKILL.md` Stage D recovery runbook | Non-looping recovery procedure for both stuck-operator states | ⚠️ ORPHANED-BY-LOGIC | Text artifact exists (SKILL.md:88-111), reads as a defined procedure on its face, but its claimed mechanics are not supported by Stage A's own documented selection algorithm in the same file — see truth #3. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `test_migration_0010` | `migrations/0010-heal-0007-knowledge-capture.md` | `extract_preflight_block` / `extract_step_block` | ✓ WIRED | Confirmed via direct read of `run-tests.sh:4852-4856`; extraction is real (not hand-transcribed). |
| `test_migration_0008_step4_write` | `migrations/0008-plan-review-gate.md` Step 4 Apply | `extract_step_block "$MIGRATION_0008" 4 Apply` | ✓ WIRED | Confirmed via direct read of `run-tests.sh:1919-1922`; `extract_step_block`'s inline-code-span fallback (added this phase) correctly extracts 0008's single-line Apply. Independently exercised — see truth #4. |
| SKILL.md Stage D recovery runbook | Stage A pending-migration selection | supersession claim | ✗ NOT WIRED | The runbook's factual claims about what Stage A's algorithm does are not supported by Stage A's own text — no cross-reference, no supersession rule exists to link to. |
| SKILL.md Stage D recovery runbook | `--migration NNNN` flag | documented at SKILL.md:107-111 | ⚠️ PARTIAL | The flag exists and is referenced by name, but the Flags table's own definition ("apply only the named migration, skip other pending" — a filter over an already-computed pending set) does not support using it to select a migration whose `to_version` is not `>` the project's current version, which is exactly the state of the operator this bullet targets. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MIGR-10 | 11-01 | New forward migration heals 0007's chain break, corrected pre-flight, re-delivers Steps 1/2/4 | ✓ SATISFIED | `migrations/0010-heal-0007-knowledge-capture.md` + `test_migration_0010`, independently confirmed. |
| MIGR-08 | 11-02 | Mutation-proven fixture, extract+execute+exact-equality on 0008 Step 4 | ✓ SATISFIED | `test_migration_0008_step4_write`, independently re-run RED→GREEN by this verifier. |
| MIGR-11 | 11-03 | SKILL.md Stage D documents a defined, non-looping recovery path | ✗ BLOCKED | Text exists but describes a recovery mechanism Stage A's own documented algorithm does not implement (CR-01/CR-02, confirmed unresolved). REQUIREMENTS.md marks this `[x]` but the underlying claim is not true against the codebase. |

No orphaned requirements — all three IDs mapped to a phase plan (11-01/11-02/11-03) and cross-referenced in `.planning/REQUIREMENTS.md` lines 48-64, 182-184.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `skills/update-codex-agenticapps-workflow/SKILL.md` | 45-51, 95-102, 103-111 | Documented recovery procedure asserts outcomes ("0007 no longer selects", "`--migration 0010` … delivers the missing payload") not supported by the algorithm documented earlier in the same file | 🛑 BLOCKER | SC#3 / MIGR-11 not met — see Gaps. |
| `migrations/run-tests.sh` | 4834-4970 (`test_migration_0010`) | Pre-flight block extracted and substring-checked (D-07) but never executed against a sandbox — unlike `test_migration_0009`'s equivalent fixture | ⚠️ WARNING | A mutation to 0010's version-floor regex (e.g. `0\.(4|6)\.0`) would survive the test suite undetected. Does not invalidate SC#1's literal text but weakens the "mutation-proven" framing used elsewhere in this phase. |
| `migrations/run-tests.sh` | 4942-4959 (`test_migration_0010` D-06 block) | D-06 assertions omit the `<repo-name>` placeholder-resolution check that migration 0010's own Post-checks (`migrations/0010-heal-0007-knowledge-capture.md:209-211`) claims is "ALWAYS true on success" | ℹ️ INFO | Inconsistent with sibling coverage in `test_migration_0007` (`run-tests.sh:838-845`), which does assert this. Not a blocker for any stated success criterion. |
| `skills/update-codex-agenticapps-workflow/SKILL.md` | 103-111 | Documented recovery only covers an operator forced to exactly `0.5.0`; an operator forced further (e.g. `0.6.0`/`0.7.0`) has no documented recovery route and is below 0010's pre-flight floor | ℹ️ INFO | Scoping gap, not required by any of the four success criteria as stated; noted for awareness (matches 11-REVIEW.md IN-04). |
| `migrations/0010-heal-0007-knowledge-capture.md` | 190, 218 | Step 3's idempotency/post-check uses an unescaped `.` in a BRE (`grep -q '^0.5.0$'`) vs. the pre-flight's escaped ERE | ℹ️ INFO | Inherited verbatim from 0007/0008/0009's own idiom; inert today. |

No `TBD`/`FIXME`/`XXX` debt markers found in any file modified by this phase (`migrations/0010-heal-0007-knowledge-capture.md`, `migrations/run-tests.sh`, `skills/update-codex-agenticapps-workflow/SKILL.md`).

### Behavioral Spot-Checks / Probe Execution

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full migration test suite is green | `bash migrations/run-tests.sh` | 393 PASS / 0 FAIL / 1 SKIP, exit 0 | ✓ PASS |
| MIGR-08 fixture isolated run | `bash migrations/run-tests.sh 0008-step4` | 5 PASS / 0 FAIL, exit 0 | ✓ PASS |
| MIGR-08 mutation-proof RED (verifier-run, not executor-claimed) | comment out 0008's write line → `bash migrations/run-tests.sh 0008-step4` | 4 PASS / 1 FAIL, exit 1, `got: 0.5.0` | ✓ PASS (RED confirmed) |
| MIGR-08 mutation-proof GREEN restore (verifier-run) | restore write line → `bash migrations/run-tests.sh 0008-step4`; `git status --porcelain` on the file | 5 PASS / 0 FAIL, exit 0; git status empty | ✓ PASS |
| 0007 and 0010 frontmatter version-slot collision (underlies SC#3 gap) | `grep -n "^id:\|^from_version:\|^to_version:" migrations/0007-knowledge-capture.md migrations/0010-heal-0007-knowledge-capture.md` | Both: `from_version: 0.4.0`, `to_version: 0.5.0` | ✓ PASS (collision confirmed, no supersession field present anywhere) |
| Search for any supersession mechanism/keyword in SKILL.md, migrations/README.md, or migration frontmatter | `grep -rn "supersed" skills/update-codex-agenticapps-workflow/SKILL.md migrations/*.md migrations/README.md` | Only the two unsupported prose claims already flagged (SKILL.md:93,95) | ✓ PASS (confirms no algorithmic support exists) |

### Human Verification Required

None. All four success criteria are programmatically checkable (frontmatter comparison, algorithm text, fixture execution) and were resolved by direct evidence.

### Gaps Summary

Three of four Phase 11 success criteria are genuinely met, independently re-verified (SC#1, SC#2, SC#4 — including personally re-running MIGR-08's mutation-proof RED→GREEN cycle end to end). SC#3 (MIGR-11) is not met: the Stage D recovery runbook added to `skills/update-codex-agenticapps-workflow/SKILL.md` reads as a defined, terminating procedure on its face, but its two Recovery bullets describe outcomes that Stage A's own documented pending-migration-selection algorithm (same file, lines ~45-51) does not produce — there is no supersession rule anywhere in the codebase (SKILL.md, `migrations/README.md`, or migration frontmatter) that would make "0007 no longer selects" or "`--migration 0010` … delivers the missing payload" true as written. This was flagged in `11-REVIEW.md` as CR-01/CR-02 (BLOCKER-level) and independently re-derived here from the codebase rather than taken on the review's word — the SKILL.md content read directly from the working tree matches exactly what the review analyzed, and no commit has touched the file since the reviewed commit (`ae59833`). Since the entire purpose of MIGR-11 is to give a stuck fleet a working, non-looping recovery path, and the documented path does not actually terminate as claimed, this is a genuine BLOCKER, not a documentation nitpick. `.planning/REQUIREMENTS.md` marks MIGR-11 `[x]` — that mark does not match the codebase and should not be trusted until the gap is closed.

Two additional WARNING-level items are logged (not gaps against any stated success criterion, but real coverage weaknesses): `test_migration_0010` never executes its own extracted pre-flight block (WR-02 — the version-floor regex that is the entire point of MIGR-10 is unproven by execution, only by text-substring match), and the D-06 delivery assertions omit the `<repo-name>` placeholder-resolution check 0010's own Post-checks claims is always true (WR-03).

---

_Verified: 2026-07-16T18:12:38Z_
_Verifier: Claude (gsd-verifier)_
