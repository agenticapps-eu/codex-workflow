---
phase: 09-region-aware-11-placement
plan: 02
subsystem: migration-test-harness
tags: [test-harness, extraction, tdd, shape-assertion, TEST-01, TEST-04]
requires: []
provides:
  - extract_step_block
  - extract_preflight_block
  - assert_extracted_shape
  - document-sourced test_migration_0001
affects:
  - migrations/run-tests.sh
  - plan 09-03 (consumes all three helpers for 0009's fixture suite)
tech-stack:
  added: []
  patterns:
    - fence-scoped markdown extraction with shape assertion (ported from claude-workflow @ 8520f90)
    - literal-prefix awk matching for parameterized scope/label (no regex interpolation)
    - subshell-wrapped eval of document-extracted shell
key-files:
  created: []
  modified:
    - migrations/run-tests.sh
decisions:
  - "Literal-prefix matching (index($0,p)==1) instead of escaped regex interpolation — nothing to escape, cannot be injected"
  - "assert_extracted_shape reports via harness counters instead of exit 1 — upstream is a per-fixture subshell, this is an in-process 279-assertion suite"
  - "Plan's predicted 0004 mutation is non-discriminating; substituted three mutations that genuinely discriminate"
metrics:
  duration: ~15 min
  completed: 2026-07-15
  tasks: 2
  files: 1
  suite_before: 277 PASS / 2 SKIP / 0 FAIL (worktree)
  suite_after: 279 PASS / 2 SKIP / 0 FAIL (worktree)
---

# Phase 9 Plan 02: Fence-Scoped Extractor + Retire Inlined Anchor Copy — Summary

Built this repo's first fence-scoped migration-document extractor with D-36 shape
assertions, and retired `run-tests.sh:119`'s inlined copy of 0001's injection awk by
executing 0001's own document instead.

## What Was Built

Three reusable helpers in `migrations/run-tests.sh`, placed above `test_migration_0001`
so plan 09-03 can consume them:

| Helper | Contract |
|---|---|
| `extract_step_block <doc> <step_n> <label>` | First fenced block after `**<label>:**` within `### Step N`, scoped to `### Step N+1` |
| `extract_preflight_block <doc>` | First fenced block under `## Pre-flight`, scoped to the next `## ` heading |
| `assert_extracted_shape <label> <text> <required_substring>` | Asserts non-empty AND contains substring; prints extraction indented on failure; 2 counters per call; returns non-zero so callers gate execution |

Ported from the pin (D-48) `claude-workflow @ 8520f90d235e0c50b0484b170d595ab6f2cd1173`,
`migrations/test-fixtures/0029/common-verify.sh`. The pin is recorded in the helper header
comment, along with why the shared lib's `extract_to()` (a git-show/whole-file extractor)
does not solve TEST-01.

Upstream's load-bearing `want=0`-on-fence-open is preserved verbatim — it is why a
` ```bash `→` ```sh ` change cannot make the scan skip past and latch onto the Rollback fence.

## GitNexus Impact Result (CLAUDE.md mandatory rule)

`gitnexus_impact({target: "test_migration_0001", direction: "upstream"})` returned:

```
{ "error": "Target 'test_migration_0001' not found", "impactedCount": 0, "risk": "UNKNOWN" }
```

**RESEARCH.md assumption A2 is CONFIRMED: GitNexus does not index shell functions.** Verified
rather than assumed — a Cypher query for all nodes in `run-tests.sh` returns exactly one node,
the `File` node itself, with zero `Function` nodes inside it:

```
| f.name       | f.filePath             | LABEL |
| run-tests.sh | migrations/run-tests.sh | File  |
```

Fell back to ground truth (`grep`): `test_migration_0001` is defined at `:197` and called
exactly once, by the dispatcher at `:3268` (the plan predicted `:3149`; the +118-line helper
insert accounts for the shift). **Blast radius: 1 direct caller, risk LOW** — as the plan
predicted. No HIGH/CRITICAL finding; no escalation needed.

`gitnexus_detect_changes()` was run before both commits: `risk_level: low`, `affected_count: 0`,
`affected_processes: []`. Note it reports against the **main checkout**, not this worktree — it
listed uncommitted `AGENTS.md`/`CLAUDE.md` edits that are not mine and did not see
`run-tests.sh`. Its low-risk verdict is therefore not evidence about this change; the
grep-based ground truth above is.

## Guard-Failure Demonstrations (Dimension 8 — mandatory)

Every guard was **observed failing** against a deliberately wrong document before being trusted.

### (a) Empty extraction — `extract_step_block` at a doc with no `### Step 1`

```
[extracted byte-length: 0]
  FAIL demo-a (README.md has no Step 1): extraction is EMPTY — heading/fence shape drift
  FAIL demo-a (README.md has no Step 1): extraction does not contain 'getline line < mirror' (extraction was empty)
-> return status: 1   counters: PASS=0 FAIL=2
```

### (b) Non-empty but WRONG — correct block, substring it cannot contain

```
  PASS demo-b (0001 Apply vs gitnexus:start): extraction from the real document is non-empty
  FAIL demo-b (0001 Apply vs gitnexus:start): extraction does NOT contain 'gitnexus:start' — the
         document's shape moved and the extractor followed it somewhere
         wrong. Fix the extractor rather than trusting this block.
         Extracted:
       MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
       # Insert provenance anchor + verbatim mirror content + one blank line,
       ...
       ' AGENTS.md > AGENTS.md.0001.tmp && mv AGENTS.md.0001.tmp AGENTS.md
-> return status: 1   counters: PASS=1 FAIL=1
```

Confirms D-36's point: non-empty is not the same as correct, and the extracted text is printed
indented (upstream's `sed 's/^/       /'` behavior) so the failure is diagnosable.

### (c) Control — correct block + substring it DOES contain

```
  PASS demo-c (0001 Apply vs mirror-stream): extraction from the real document is non-empty
  PASS demo-c (0001 Apply vs mirror-stream): extraction contains 'getline line < mirror'
-> return status: 0   counters: PASS=2 FAIL=0
```

### (d) Bonus — `extract_preflight_block` guard (needed by 09-03 fixture 10)

Against 0001's real `## Pre-flight`: both assertions PASS, extraction is 28 lines, and it does
**not** leak past the fence into `### Step 1`. Against `migrations/README.md` (no `## Pre-flight`):

```
[extracted byte-length: 0]
  FAIL preflight (README.md — no Pre-flight heading): extraction is EMPTY — heading/fence shape drift
  FAIL preflight (README.md — no Pre-flight heading): extraction does not contain 'MIRROR=' (extraction was empty)
```

### Extractor behavior demonstration (Task 1 acceptance)

`extract_step_block migrations/0001-inject-spec-11-coding-discipline.md 1 Apply` prints 0001's
Apply block and:

```
CONTAINS anchor awk (/^## / && !done): YES
CONTAINS mirror-stream (getline line < mirror): YES
CONTAINS Rollback (must be NO): NO
```

## Mutation Demonstration (Task 2) — and a plan correction

**The plan's specified mutation does not discriminate, and its stated rationale is empirically
false.** The acceptance criterion says to point the extraction at `0004-revendor-spec-11.md`
and expect failure "(0004's Apply strips with a content sentinel and injects differently, so
byte-identity or the shape guard must break)". Run as specified, the suite still reported
**PASS: 6 / FAIL: 0** — no failure.

This is not a defect in the conversion. Reading 0004's extracted Step 1 Apply shows why:

```bash
# 0004 Step 1 Apply — strip pass (a NO-OP against fixture A: no provenance line exists)
awk '/^<!-- spec-source: ...§11 -->$/ {inblk=1; next} ...' AGENTS.md > AGENTS.md.0004.tmp && mv ...
# 0004 Step 1 Apply — inject pass: IDENTICAL to 0001's
awk -v mirror="$MIRROR" '
  /^## / && !done { print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
    while ((getline line < mirror) > 0) print line ... }
```

0004 injects with the **same naive `/^## / && !done` anchor** and streams the **same mirror**;
its strip is a complete no-op on a fixture with nothing to strip. So against fixture A, 0004's
Apply is **behaviorally identical** to 0001's, and byte-identity correctly still holds. This is
substantive supporting evidence for 09-CONTEXT.md's "three naive-anchor sites" claim —
`0001:91` and `0004:77` really are the same awk.

The criterion's *intent* is proving the assertion is live, not dead-by-construction. Three
mutations that genuinely discriminate were each **observed failing**, with the control passing:

| Mutation | Expectation | Observed |
|---|---|---|
| **M1** extract Step **2** (version bump) instead of Step 1 | shape guard breaks | `FAIL ... does NOT contain 'getline line < mirror'` + `FAIL byte-identity NOT asserted` → **PASS: 4 / FAIL: 2** |
| **M2** neuter the eval (block never runs) | byte-identity breaks | `FAIL injected §11 block differs from the mirror` → **PASS: 5 / FAIL: 1** |
| **M3** truncate the fake mirror the block streams | byte-identity breaks | `FAIL injected §11 block differs from the mirror` → **PASS: 5 / FAIL: 1** |
| **control** (reverted) | all pass | **PASS: 6 / FAIL: 0** |

Together these prove the assertion depends on (M1) the extracted text being the right block,
(M2) that block actually executing, and (M3) that block genuinely reading the mirror. M1 also
proves `assert_extracted_shape`'s return value correctly **gates** execution — a bad extraction
reports FAIL rather than silently skipping the injection assertion.

## Suite Counts

| | PASS | SKIP | FAIL | exit |
|---|---|---|---|---|
| Before (this worktree) | 277 | 2 | 0 | 0 |
| After (this worktree) | **279** | 2 | **0** | 0 |
| `run-tests.sh 0001` before | 4 | 1 | 0 | 0 |
| `run-tests.sh 0001` after | **6** | 1 | **0** | 0 |

+2 is exactly the two new `assert_extracted_shape` assertions. PASS never fell; FAIL stayed 0.

## Verification Gates

- `migrations/run-tests.sh 0001` exits 0, byte-identity PASS line present — **PASS**
- Full suite `FAIL: 0`, PASS ≥ 278 (279) — **PASS**
- `git status --porcelain migrations/0001-*.md migrations/0004-*.md` prints nothing — **PASS** (immutables untouched, T-09-09)
- Inlined copy gone (scoped to fn body, comments filtered): `grep -c '/\^## / && !done'` → **0**
- Replacement real (scoped to fn body): `grep -c 'extract_step_block'` → **1**
- Helpers exist as code not just comment: comment-filtered `grep -c` → **3**
- D-37 scope fence: `test_migration_0008` body has **0** `extract_step_block` and still carries its own inlined awk (17 `awk` refs) — deferred, not silently converted

## Deviations from Plan

### 1. [Rule 3 - Blocking] `vendor/agenticapps-shared` submodule not initialized in the worktree

- **Found during:** Task 1 setup
- **Issue:** `vendor/agenticapps-shared/` was empty in the fresh worktree; the harness hard-fails
  without it (`error: agenticapps-shared submodule not initialized`), so no task was verifiable.
- **Fix:** `git submodule update --init --recursive` → checked out `1f5d543`. Not a package-manager
  install (no new dependency surface); the submodule is already pinned in the repo.
- **Files modified:** none committed (submodule at its pinned commit; `git status` clean)

### 2. [Rule 2 - Correctness] Plan's mutation demonstration is non-discriminating — substituted stronger ones

- **Found during:** Task 2 acceptance
- **Issue:** The specified 0004 mutation passes instead of failing, because 0004's Apply is
  behaviorally identical to 0001's on fixture A (same naive anchor, same mirror, no-op strip).
  Accepting the criterion as written would have meant either reporting a false "mutation
  confirmed" or treating a correct conversion as broken.
- **Fix:** Reported the finding honestly (it corroborates the phase's naive-anchor premise) and
  ran three mutations that genuinely discriminate (M1/M2/M3 above), each observed failing with a
  passing control. The criterion's intent — prove the assertion is live — is satisfied more
  strongly than the literal instruction would have.
- **Files modified:** none (mutations applied to a `/tmp` backup copy and reverted; final sha
  matches the pre-mutation sha `24256e11848c`)

### 3. [Deliberate design choice] Literal-prefix matching instead of escaped regex interpolation

- **Found during:** Task 1 implementation
- **Issue:** The plan says to "escape the label for awk's regex safely rather than interpolating
  raw". Upstream can hardcode `/^\*\*Apply:\*\*/` because its step/label are fixed; these helpers
  take both as **parameters**, and `-v` values additionally undergo awk escape processing, which
  makes hand-escaping fragile.
- **Fix:** Used literal prefix comparison (`index($0, p) == 1`), which has nothing to escape and
  cannot be injected — strictly stronger than escaping, and matches the same lines upstream's
  anchored regexes do (verified against both `### Step 1:` colon/dash forms and both
  `**Apply:**`-alone and `**Apply:** <prose>` shapes). Rationale recorded in the header comment.
  Covered by "Claude's Discretion: the exact awk implementation — mechanics, not policy".

### 4. [Environmental] Worktree baseline is 277/2, not the plan's 278/1

- **Found during:** baseline capture
- **Issue:** One assertion (`mirror == core spec §11`) SKIPs instead of PASSing because it probes
  `$REPO_ROOT/../agenticapps-workflow-core`, which is not adjacent to a worktree path.
- **Fix:** None needed — environmental, not a regression. Deltas measured against the worktree
  baseline (277 → 279). The equivalent main-checkout figure is 278 → 280.

## Threat Model Compliance

| Threat ID | Disposition | Status |
|---|---|---|
| T-09-06 (extractor latches onto wrong fence, harness evals it) | mitigate | **Met** — `assert_extracted_shape` gates every extraction on a required substring before execution and its return value blocks the eval (proven by M1); upstream's `want=0` preserved verbatim |
| T-09-07 (extracted block's `exit` kills the suite) | mitigate | **Met** — the eval runs in an explicit subshell `( cd "$proj" && export CODEX_HOME=... && eval ... )` |
| T-09-08 (dead-by-construction assertion reads as coverage) | mitigate | **Met** — 3 guard-failure demos + 3 discriminating mutations, all observed failing; source assertions scoped with `awk` to the fn body and comment-filtered |
| T-09-09 (silent edit to immutable 0001/0004) | mitigate | **Met** — `git status --porcelain` on both prints nothing |
| T-09-05 (unpinned upstream logic) | mitigate | **Met** — read via `git -C ../claude-workflow show 8520f90:...`; pin recorded in the helper header comment |
| T-09-SC (package installs) | accept | **Met** — no installs; submodule init only, no new dependency surface |

## Known Stubs

None. Both helpers and the conversion are fully wired and exercised by the live suite.
`extract_preflight_block` has no in-suite consumer yet by design — plan 09-03's fixture 10
consumes it for D-28.1's mirror guards — but it is not a stub: it is implemented, and both its
success and failure paths are demonstrated above.

## Notes for Plan 09-03

- All three helpers are generic and ready: `extract_step_block <doc> <n> <label>` handles
  `Apply` and `Idempotency check`; `extract_preflight_block` handles D-28.1's guards.
- 0009 must keep its Apply marker at the **start of the line** (`**Apply:**` or
  `**Apply:** <prose>`) and its step headings as `### Step N...` for the prefix match to hold.
- `assert_extracted_shape` contributes **2** assertions per call — factor that into expected
  PASS counts.
- Callers **must** gate on its return status and **must** subshell-wrap any eval (T-09-07).
- Per D-47, 0009's Rollback is `git checkout AGENTS.md` (prose, not a fenced block), so a
  Rollback *extractor* is unnecessary — assert against the document's prose line instead.

## Commits

| Task | Commit | Description |
|---|---|---|
| 1 | `d51b032` | test(09-02): add fence-scoped extractor with shape assertions (TEST-01) |
| 2 | `69209cf` | test(09-02): source test_migration_0001 from 0001's document (TEST-04) |

## Requirements Satisfied

- **TEST-01** — migration shell is extracted from the migration document with shape assertions,
  never transcribed. Mechanism exists and is proven live.
- **TEST-04** — the inlined anchor copy at `run-tests.sh:119` is gone, replaced by
  document-sourced extraction (ROADMAP Success Criterion 5).

## Self-Check: PASSED

- Files verified present: `migrations/run-tests.sh`,
  `.planning/phases/09-region-aware-11-placement/09-02-SUMMARY.md`
- Commits verified in `git log`: `d51b032`, `69209cf`, `85b244b`
- Helpers verified in committed HEAD (comment-filtered): 5 code references
- Final suite re-run on a clean tree: **exit 0, PASS: 279, FAIL: 0, SKIP: 2**
- STATE.md / ROADMAP.md deliberately untouched (worktree mode — orchestrator owns those writes)
</content>
</invoke>
