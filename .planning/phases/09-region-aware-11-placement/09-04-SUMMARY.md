---
phase: 09-region-aware-11-placement
plan: 04
subsystem: migrations
tags: [green, port, region-aware-anchor, ANCHOR-05, D-24, D-47, upstream-pin-8520f90]
requires:
  - "09-01 (validated anchor rule + evidence — ROADMAP hard ordering 1)"
  - "09-03 (the RED fixture suite — ROADMAP hard ordering 2)"
provides:
  - "migrations/0009-spec-11-region-aware-placement.md — the region-aware §11 placement heal, 0.6.0 → 0.7.0"
  - "this repo's scaffolder bumped to 0.7.0, drift coupling green"
  - "TEST-02's GREEN half: 09-03's 25 RED assertions now 34 PASS"
affects:
  - migrations/0009-spec-11-region-aware-placement.md
  - skills/agentic-apps-workflow/SKILL.md
  - "every project this host scaffolds (latent block-destruction defect closed)"
tech-stack:
  added: []
  patterns:
    - "port-not-derive: adapted the pinned upstream 0029 @ 8520f90, diffed rather than re-derived"
    - "one rule, three sites: the terminator alternation carried at predicate/strip/insert"
    - "payload streamed from the mirror via getline, never transcribed (D-19)"
    - "atomic temp-file replace gated on BOTH [ -s ] and a pre-mv shape assertion"
key-files:
  created:
    - migrations/0009-spec-11-region-aware-placement.md
  modified:
    - skills/agentic-apps-workflow/SKILL.md
decisions:
  - "MIRROR (not upstream's SPEC_BLOCK) — 0004:45's local precedent; 09-03 left the naming to this plan and anchored its guard on the mirror PATH, which is invariant under either choice"
  - "D-47's rationale prose placed ABOVE the **Rollback:** line — case 08 scopes from **Rollback:** to ### Step 2 and asserts no 'awk' in that scope, so explaining the decision below the line would have failed the fixture"
  - "Task 1's D-33 acceptance grep spans prose: cited 0004:44 descriptively rather than quoting its literal command"
metrics:
  duration: ~45 min
  completed: 2026-07-15
  tasks: 3
  commits: 3
  files: 2
  suite_before: 279 PASS / 2 SKIP / 25 FAIL (worktree, exit 1 — RED by design)
  suite_after: 313 PASS / 2 SKIP / 0 FAIL (worktree, exit 0 — GREEN)
---

# Phase 9 Plan 04: Author Migration 0009, Turn the Suite GREEN — Summary

Ported `claude-workflow`'s migration 0029 at the pin `8520f90` to this host as
`migrations/0009-spec-11-region-aware-placement.md`, closing the latent §11
block-destruction defect for every project this host scaffolds — and turned
09-03's 25 RED assertions GREEN without touching a single fixture.

## Gates (both confirmed before the first line was written)

| Gate | Evidence | Result |
|---|---|---|
| ROADMAP hard ordering 1 — validate before you write | `09-VALIDATION-EVIDENCE.md:84` `PASS CASE 1 ZERO CHURN`, `:87` `PASS CASE 2 ABOVE REGION`, `:229` `RED OBSERVED (TEST-02)` | **PASS** |
| ROADMAP hard ordering 2 — RED before GREEN | Re-observed myself on this branch: `run-tests.sh 0009` → **exit 1, PASS: 0 / FAIL: 25**, every failure `extraction is EMPTY` / `could not be extracted`, doc confirmed absent | **PASS** |

Upstream pin re-verified live: `8520f90` resolves, is an ancestor of upstream
HEAD `28b393b` (which has moved past the pin, exactly as 09-01 recorded). All
awk read via `git -C ../claude-workflow show 8520f90:…`. **Nothing at upstream
HEAD was read in.**

## Terminal State

| Suite | Result |
|---|---|
| `run-tests.sh` (full) | **PASS: 313 / FAIL: 0 / SKIP: 2 — exit 0** |
| `run-tests.sh 0009` | **PASS: 34 / FAIL: 0 — exit 0** |
| `run-tests.sh drift` | exit 0 |
| `run-tests.sh layout` | exit 0 |
| `run-tests.sh 0001` / `0004` | exit 0 / exit 0 (immutables undisturbed) |
| `validate-0009-anchor.sh` (09-01's harness) | exit 0 |

**The arithmetic reconciles exactly:** 279 (worktree baseline, all non-0009) +
34 (0009's assertions) = **313**. PASS never fell. The plan's acceptance asked
for `FAIL: 0` and `PASS ≥ 278`; both hold. `SKIP: 2` not `1` is the documented
worktree environmental artifact (one check probes
`$REPO_ROOT/../agenticapps-workflow-core`, unresolvable from a nested worktree)
— pre-existing, identical to 09-01/09-02/09-03. Expect 314/1 on the main checkout.

The prompt's projected target of 305 PASS was an estimate; the true figure is
313 because **FAIL count ≠ assertion count**: `assert_extracted_shape`
contributes 2 assertions per call, and a gated case collapses to *one* FAIL at
RED while expanding to several PASSes at GREEN.

### `run-tests.sh 0009` — GREEN output (verbatim)

```
=== Migration 0009 — Region-aware §11 placement ===
  PASS 0009 Pre-flight: extraction from the real document is non-empty
  PASS 0009 Pre-flight: extraction contains 'spec-mirrors/11-coding-discipline-0.4.0.md'
  PASS 0009 Pre-flight carries D-28.1 layer 1 (test -s — zero-byte mirror guard)
  PASS 0009 Pre-flight carries D-28.1 layer 2 (tail sentinel — truncated mirror guard)
  PASS 0009 Step 1 Idempotency check: extraction from the real document is non-empty
  PASS 0009 Step 1 Idempotency check: extraction contains 'spec-source: agenticapps-workflow-core'
  PASS 0009 Step 1 Apply: extraction from the real document is non-empty
  PASS 0009 Step 1 Apply: extraction contains 'gitnexus:start'
  ✓ state A: anchored + current provenance + region later → skip (D-31/MIGR-07) (expected applied, exit=0)
  ✓ state B: provenance present BUT block in region → heal, not skip (D-38 — the whole point) (expected not-applied, exit=1)
  ✓ state C: no provenance at all → inject (expected not-applied, exit=1)
  ✓ state B (D-32 variant): unterminated gitnexus:start → fails closed, treated as in-region (expected not-applied, exit=1)
  PASS 01-gitnexus-led-inject: provenance (line 5) is ABOVE gitnexus:start (line 86)
  PASS 01-gitnexus-led-inject: region markers still paired exactly once (start=1 end=1)
  PASS 01-gitnexus-led-inject: the region's own body content survived
  PASS 02-inside-region-move: exactly ONE provenance line remains (found 1) — moved, not duplicated
  PASS 02-inside-region-move: provenance (line 5) moved ABOVE gitnexus:start (line 86)
  PASS 02-inside-region-move: region survived intact and paired (start=1 end=1) — the D-24 terminator assertion
  PASS 03-healthy-noop: AGENTS.md is BYTE-IDENTICAL after Apply (zero churn — catches an over-eager anchor)
  PASS 04-no-agentsmd: Apply exits ZERO (informational skip, so Step 2's version bump still runs) — got exit=0
  PASS 04-no-agentsmd: skip message names THIS host's skill (update-codex-agenticapps-workflow), not claude-workflow's slug
  PASS 04-no-agentsmd: Apply created no AGENTS.md out of thin air
  PASS 05-unmanaged-conflict: Apply exits exactly 3 on an unmanaged §11 heading (State D) — got exit=3
  PASS 05-unmanaged-conflict: hand-written §11 is BYTE-IDENTICAL after the refusal (refused AND untouched)
  PASS 06-no-heading-eof: provenance is present after Apply (END fallback fired, block not dropped)
  PASS 06-no-heading-eof: block was APPENDED at EOF (provenance at line 5, below the 3 lines of pre-existing prose)
  PASS 09-two-provenance-heal: healed down to exactly ONE provenance line (found 1) — swallowed_own_h2 reset at the terminator
  PASS 09-two-provenance-heal: both terminating '## ' headings survived (## Workflow, ## Deployment) — the strip did not over-run
  ✓ 07-prose-mention-not-a-region: a prose mention of the marker is NOT a region → skip (D-21 anchored regex) (expected applied, exit=0)
  PASS 08-rollback-region-led: Step 1 Rollback is 'git checkout AGENTS.md' (D-47 — structurally immune, no terminator to get wrong)
  PASS 08-rollback-region-led: Step 1 Rollback carries NO fenced awk block — the region-eating bug class stays unreachable
  PASS 10-corrupt-mirror-refused (a) zero-byte mirror: pre-flight refuses with exit 3 (D-28.1 layer 1, test -s) — got exit=3
  PASS 10-corrupt-mirror-refused (b) truncated mirror: pre-flight refuses with exit 3 (D-28.1 layer 2, tail sentinel) — got exit=3
  PASS 10-corrupt-mirror-refused (c) healthy mirror: pre-flight PASSES with exit 0 (the direction that proves it is not refusing everything) — got exit=0

=== Summary ===
  PASS: 34
```

## The Fixtures Were Not Edited

**`migrations/run-tests.sh` is BLOB-HASH IDENTICAL to 09-03's final commit `185abfd`.**
Not "diff is empty" by inspection — the git object hashes match:

```
git diff 185abfd -- migrations/run-tests.sh   → 0 lines
git diff 1a5488a -- migrations/run-tests.sh   → 0 lines
rev-parse 185abfd:migrations/run-tests.sh == rev-parse HEAD:migrations/run-tests.sh → IDENTICAL
```

09-02's `extract_step_block` / `extract_preflight_block` / `assert_extracted_shape`
bodies hash-compared against `185abfd`: **all UNCHANGED**. No assertion was
weakened, deleted, or relaxed. GREEN was reached by shipping the document, which
is the only legitimate route.

## ANCHOR-05 — Site-by-Site Audit

`awk`-scoped to Step 1, comments filtered (`grep -v '^[[:space:]]*#'`), so this
counts **code**, not the document's own prose about the rule:

| # | Line | Site | Role |
|---|---|---|---|
| 1 | **L163** | `/^<!-- gitnexus:start -->$/ { r = 1; next }` | idempotency predicate's anchored marker |
| 2 | **L265** | `in_block && swallowed_own_h2 && (/^## / \|\| /^<!-- gitnexus:start -->$/) {` | **strip terminator** |
| 3 | **L288** | `!inserted && (/^## / \|\| /^<!-- gitnexus:start -->$/) {` | **insert anchor** |

Count = **3** (acceptance: ≥ 3). Cross-checked against PATTERNS.md's
terminator-alternation checklist: rows 1 and 2 of that checklist (`0029:202`
strip, `0029:228` insert) are both ported; row 3 (`0029:302` Rollback removal
pass) is correctly **not** ported — D-47.

- **D-25 not reintroduced:** content-sentinel grep in Step 1 → **0**.
- **Atomicity:** the single `mv` onto AGENTS.md (**L308**) is preceded by
  `[ -s AGENTS.md.0009.tmp ]` (**L306**) *and*
  `grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md.0009.tmp` (**L307**).
  The strip's output is gated by `[ -s AGENTS.md.0009.strip ]` (**L273**). Every
  failure branch `rm -f`s its temps, echoes ABORT, and `exit 3` without touching
  AGENTS.md. awk output is never redirected onto the file being read.

## Mutation Demonstrations (Dimension 8) — BOTH CAME BACK NEGATIVE

Both mandatory mutation demos **failed to produce red**. Recorded as findings,
not smoothed over. Neither indicts the shipped document — both indict fixture
coverage.

### 1. Strip-terminator mutation — THE PLAN'S EXPLICIT STOP CONDITION

Narrowed **L265's strip terminator only** (insert anchor L288 left intact;
alternation site count 3 → 2, mutation verified landed before trusting the run):

```
########## MUTATED RUN (narrow strip terminator) ##########
  PASS 02-inside-region-move: exactly ONE provenance line remains (found 1) — moved, not duplicated
  PASS 02-inside-region-move: provenance (line 5) moved ABOVE gitnexus:start (line 86)
  PASS 02-inside-region-move: region survived intact and paired (start=1 end=1) — the D-24 terminator assertion
  PASS: 34
MUTATED_EXIT=0          ← SUITE STAYED GREEN

########## REVERTED RUN ##########
  PASS: 34
REVERTED_EXIT=0
```

Task 2's acceptance says: *"If the suite stays GREEN with the narrow terminator,
the fixtures do not test the thing this phase exists to fix — STOP and surface
it."* **Surfacing it, with the root cause proven rather than guessed.**

An isolated strip replay over both file shapes:

```
state-b  narrow  → start=1 end=1 regionBody=1  region INTACT
state-b  wide    → start=1 end=1 regionBody=1  region INTACT
healed   narrow  → start=0 end=1 regionBody=1  >>> REGION DESTROYED (orphaned/unpaired) <<<
healed   wide    → start=1 end=1 regionBody=1  region INTACT
```

**Root cause, in one sentence: case 02 cannot discriminate the terminator,
because in State B the §11 block sits *inside* the region followed by
`## Always Do` — a `## ` heading also inside the region — so the narrow
terminator halts there and never reaches the marker.** Narrow and wide produce
byte-identical output on that shape.

The **only** shape that discriminates is the **already-healed region-led file**
(§11 above the region, marker as the next structural line) — reached solely by
**re-running Apply**. Confirmed no fixture does: 7 `_m0009_mk_project` calls, 7
`_m0009_apply` calls, one Apply per fresh project. There is no idempotent-re-run
fixture.

**This is a fixture-coverage gap, NOT an untested claim and NOT a defect in
0009.** ANCHOR-05 *is* demonstrated live and committed in this repo — by 09-01's
`migrations/validate-0009-anchor.sh` counter-case B, which strips exactly the
healed file and asserts `start=0 end=1` (region destroyed), green at exit 0. The
phase is not blind; the gap is specific to `run-tests.sh`'s TEST-03 fixtures.

Additionally: in real operation the narrow terminator is unreachable on that
shape anyway, because a healed file's idempotency check returns `applied` and
the runtime skips Step 1 entirely. The alternation is defense-in-depth — which
is exactly why it must be there, and why it should also be *fixture*-tested.

**Could not fix here:** Task 2's acceptance requires
`git diff 185abfd -- migrations/run-tests.sh` to be **empty**. Adding fixture
`11-idempotent-rerun` would violate that. Recommended follow-up below.

### 2. Step 3 version mutation — MIGR-08 IS UNTESTED

Changed Step 3's Apply to write `0.6.0`:

```
########## MUTATED RUN (Step 3 writes 0.6.0) ##########
run-tests.sh 0009 → PASS: 34, exit 0        ← nothing failed
run-tests.sh      → PASS: 313, SKIP: 2, exit 0   ← nothing failed
```

Task 3's acceptance: *"If nothing fails, MIGR-08 is untested — record that gap
explicitly and surface it rather than shipping the illusion of coverage."*
**Recording it.**

Root cause, verified: `test_migration_0009` extracts only three blocks —
Pre-flight, Step 1 Idempotency check, Step 1 Apply (`run-tests.sh:3433-3435`).
Nothing extracts or executes Step 2 or Step 3. The drift test compares SKILL.md's
`version` against the migration's **frontmatter** `to_version`, never Step 3's
body. So the value Step 3 writes to `.codex/workflow-version.txt` is asserted by
**a static grep in this plan's acceptance criteria only** — not by any executable
fixture. Reverted; value confirmed back to `0.7.0`.

## Deviations from Plan

### 1. [Rule 1 - Bug] Task 1's D-33 acceptance grep spans prose, not just code

- **Found during:** Task 1 verification —
  `awk '/^## Pre-flight/{f=1} f&&/^## Steps/{exit} f' … | grep -c 'test -f AGENTS.md'`
  returned **1**, required **0**.
- **Issue:** The criterion's scope is the whole Pre-flight *section*, prose
  included. My prose explained the D-33 divergence by **quoting 0004:44's literal
  command**, which tripped a check meant to prove the abort was not *ported as code*.
  The abort was never in the code.
- **Fix:** Cited `0004:44` descriptively ("which hard-aborts when the project has
  no `AGENTS.md`") instead of quoting the literal. Meaning preserved, criterion
  satisfied honestly rather than by loosening it. → **0**.
- **Files:** `migrations/0009-spec-11-region-aware-placement.md` — **Commit:** `46b4450`

### 2. [Rule 2 - Correctness] D-47's rationale prose moved ABOVE the Rollback line

- **Found during:** Task 2, reading case 08 before writing.
- **Issue:** The plan's action says to add, after `**Rollback:**`, "one sentence
  recording why: 0029's custom Rollback **awk** …". But case 08 scopes `rb_scope`
  from `**Rollback:**` to `### Step 2` and asserts
  `! printf '%s' "$rb_scope" | grep -q 'awk'`. Following the instruction literally
  would have put the string `awk` inside that scope and **failed the fixture** —
  a spurious red caused by prose, not by a region-eating rollback.
- **Fix:** The full rationale is recorded, in Step 1's prose immediately **above**
  the `**Rollback:**` line, and phrased without the literal token in the asserted
  scope. Both intents satisfied: the decision is documented for future readers,
  and the regression guard stays live.
- **Files:** `migrations/0009-spec-11-region-aware-placement.md` — **Commit:** `49b2fab`

### 3. [Naming decision — 09-03 delegated it] `MIRROR`, not upstream's `SPEC_BLOCK`

0004:45's local precedent. 09-03 explicitly left this to this plan and anchored
its pre-flight shape guard on the mirror **path**, which is invariant under
either name — so this choice cost nothing.

### 4. [Environmental, not a deviation] Submodule init required

`vendor/agenticapps-shared` was unpopulated in the fresh worktree; the harness
hard-fails without it. Ran `git submodule update --init --recursive` → `1f5d543`,
a checkout of an already-pinned submodule. No tracked-file change, no new
dependency surface, not a package-manager install. Same as 09-01/09-02/09-03.

### 5. [Environmental, not a deviation] Worktree baseline SKIP is 2, not 1

Documented by all three prior plans. `FAIL: 0` is the metric that matters.

### 6. [Tooling honesty] A `sed` mutation silently no-op'd

My first strip-terminator mutation attempt failed with
`sed: bad flag in substitute command: '/'` — and the subsequent run *looked* like
a passing "mutation demo". It was not: the file was unmodified. Caught by
verifying L265 after the edit. Re-done via python3 with an assertion that the
mutation landed, and the alternation count re-checked (3 → 2) **before** trusting
any result. Noting it because an unverified mutation demo is precisely the
dead-assertion failure mode this phase exists to close — it would have produced a
confidently false "the demo passed".

## Scope Confinement

`gitnexus_detect_changes()` run before commits per CLAUDE.md. It reported
`risk_level: low, affected_count: 0` and listed two `Section:` symbols in
`AGENTS.md` / `CLAUDE.md`. **That verdict is not evidence about this change** —
it reports against the **main checkout**, not this worktree; the files it lists
are pre-existing uncommitted edits that are not mine; and it **never saw**
`migrations/0009-…md` or `SKILL.md`. Recorded as instructed, and discounted for
the stated reason (RESEARCH.md A2 / 09-02's Cypher finding: GitNexus does not
index shell functions, and migration `.md` documents are not indexed symbols).
`gitnexus_impact` was **not** run and is **not** claimed: no existing symbol is
edited by this plan. Grep and git object hashes are ground truth here.

**Ground truth vs the wave-2 tip `1a5488a`:**

- Exactly **2 files** changed: `migrations/0009-…md` (+361 new), `SKILL.md` (1 line).
- **Zero deletions** across all three commits (`--diff-filter=D` empty).
- `migrations/0001-…md`, `migrations/0004-…md`, `AGENTS.md`: **untouched across
  all commits** (immutables honored; this host's own latent-but-safe AGENTS.md
  was not "repaired").
- Working tree clean; no untracked files.

## Requirements

| Req | Status | Evidence |
|---|---|---|
| ANCHOR-01/02 | complete | cases 01/02/06 (anchor + END EOF fallback) |
| ANCHOR-05 | complete | 3-site audit above; **fixture-untested** — see mutation demo 1 |
| MIGR-01 | complete | D-39 version gate, `0.(6.0\|7.0)` |
| MIGR-02/03/04 | complete | cases 03 / 02 / 01 |
| MIGR-05 | complete | case 05 (exit 3 + byte-identity) |
| MIGR-06 | complete | State A row → runtime skips Step 1 |
| MIGR-07 | complete | State A row (D-31 — falls out of the predicate) |
| MIGR-08 | **shipped, UNTESTED** | Step 3 writes `0.7.0`; mutation demo 2 proves no fixture asserts it |
| MIGR-09 | complete | drift green; SKILL.md `0.7.0` landed in `46b4450` with the frontmatter |

## Known Stubs

**None.** The migration is complete and every step is live.

## Threat Model Compliance

| Threat | Disposition | Status |
|---|---|---|
| T-09-01 (runaway strip destroying the region) | mitigate | **Partially met — READ THIS.** The alternation is present and audited at both load-bearing sites, and 09-01's harness demonstrates it live. But the plan named three enforcement mechanisms and **the third (the fixture mutation demo) does not fire** — see mutation demo 1. The mitigation holds; one of its three proofs does not. |
| T-09-02 (corrupt/truncated mirror) | mitigate | **Met** — both layers, case 10 (a)/(b)/(c) green in both directions |
| T-09-03 (overwriting a hand-authored §11) | mitigate | **Met** — case 05: exit 3 **and** `cmp -s` byte-identity |
| T-09-04 (non-atomic write) | mitigate | **Met** — L306/L307 gate L308's mv; all failure branches clean up and exit 3 untouched |
| T-09-13 (stale `swallowed_own_h2`) | mitigate | **Met in code** (both flags reset, L266-267). Note: case 09's fixture may not discriminate the reset — its first block is terminated by a real `## Workflow`, which resets the flag anyway. Flagged, not investigated further; out of scope. |
| T-09-14 (fail-open region predicate) | mitigate | **Met** — D-32 variant row green |
| T-09-15 (Rollback "improved" into region-eating code) | mitigate | **Met** — case 08 both halves green |
| T-09-05 (unpinned upstream absorbed) | mitigate | **Met** — pin verified ancestor of HEAD `28b393b`; all reads via `show 8520f90:` |
| T-09-16 (injected prose drift) | accept | **Met** — strip is blind (D-26); D-28.2 consequence stated in the document |
| T-09-SC (package installs) | accept | **Met** — none; submodule init only |

## Threat Flags

None. No new network, auth, file-access, or schema surface. The migration's file
surgery is confined to the project's own `AGENTS.md`, guarded, atomic, and
reversible via `git checkout`.

## Deferred / Recommended Follow-Ups

1. **Fixture `11-idempotent-rerun` (HIGH — closes the T-09-01 proof gap).** Run
   Apply **twice** on case 01's region-led project and assert the region survives
   the second pass (`start=1 end=1`). This is the only fixture shape that makes
   ANCHOR-05's alternation load-bearing in `run-tests.sh`. Verified empirically
   above that it *would* go red under a narrow terminator. Could not be added here:
   Task 2's acceptance requires `run-tests.sh` to be untouched.
2. **Fixture for MIGR-08 (MEDIUM).** Extract and execute Step 3 against a scratch
   project and assert `.codex/workflow-version.txt` reads `0.7.0`.
3. **`extract_step_block`'s `want`-flag leak (LOW).** 09-03's known latent bug,
   still unfixed. **Not tripped by this document** — Step 1's Apply and Idempotency
   check each have a fence inside their own step, and Step 1's Apply extraction was
   re-verified after Step 2 existed to bound it (131 lines, no Step 2 leak).
4. **PATTERNS.md's stale "D-46 locks this phase to 8 cases"** — 09-03 already
   flagged it; it is 10.
5. **Upstream has moved past the pin** (`8520f90` → `28b393b`). A deliberate
   follow-up diff, per D-48 — not absorbed here.

## Notes for the Orchestrator

- **STATE.md / ROADMAP.md / REQUIREMENTS.md deliberately untouched** (worktree
  mode — the orchestrator owns those writes after the wave merges).
- Recommended marking after merge: **ANCHOR-01/02/05, MIGR-01..07, MIGR-09 →
  complete**. **MIGR-08 → complete-but-untested**, or hold pending follow-up 2 —
  the requirement is shipped, but no executable assertion covers it.
- **The phase's full suite is now GREEN (exit 0).** The 25 FAILs 09-03 warned
  about are resolved.
- **Two mandatory mutation demos came back negative.** Neither blocks the merge —
  the shipped document is correct and matches the pin — but follow-up 1 should
  not be dropped, since it is the difference between "the alternation is right"
  and "the suite would catch it if it stopped being right".

## Commits

| Task | Commit | Description |
|---|---|---|
| 1 | `46b4450` | feat(09-04): add 0009 frontmatter, prose and pre-flight; bump scaffolder to 0.7.0 |
| 2 | `49b2fab` | feat(09-04): add Step 1 region-aware heal — turns the 0009 RED suite GREEN |
| 3 | `2c81e76` | feat(09-04): add 0009 Steps 2 and 3 — version bump and project version record |

`git log` reads `test(09-03)` ×3 → `feat(09-04)` ×3 — the auditable
RED-before-GREEN trail, verified in order.

## Self-Check: PASSED

| Claim | Verified |
|---|---|
| `migrations/0009-spec-11-region-aware-placement.md` exists (415 lines ≥ 120) | FOUND |
| `to_version: 0.7.0` in 0009 | FOUND (1) |
| `skills/agentic-apps-workflow/SKILL.md` reads `version: 0.7.0` | FOUND (1) |
| `implements_spec: 0.4.0` unchanged (D-17) | FOUND (1) |
| key_link: `getline line <` streams the mirror | FOUND (3) |
| key_link: `AGENTS.md.0009.(strip\|tmp)` temp files | FOUND (9) |
| Commit `46b4450` | FOUND |
| Commit `49b2fab` | FOUND |
| Commit `2c81e76` | FOUND |
| `run-tests.sh` blob identical to `185abfd` | CONFIRMED |
| Full suite exit 0, FAIL: 0 | CONFIRMED (313/0/2) |
| Working tree clean | PASS |
