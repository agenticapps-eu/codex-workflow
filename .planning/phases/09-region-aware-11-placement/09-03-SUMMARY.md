---
phase: 09-region-aware-11-placement
plan: 03
subsystem: migration-test-harness
tags: [tdd, red-before-green, fixtures, TEST-02, TEST-03, dead-assertion-detector, D-38, D-46]
requires:
  - extract_step_block (09-02)
  - extract_preflight_block (09-02)
  - assert_extracted_shape (09-02)
provides:
  - "test_migration_0009 — ten TEST-03 cases + the four-state double-sided idempotency table"
  - "09-VALIDATION-EVIDENCE.md §8-14 — the recorded RED observation (TEST-02's auditable half)"
  - "ROADMAP hard ordering 2 discharged: 09-04 unblocked to ship 0009 and turn the suite GREEN"
affects:
  - migrations/run-tests.sh
  - "09-04 (must satisfy the contract these fixtures assert; must not edit them)"
tech-stack:
  added: []
  patterns:
    - "printf-synthesized fixture cases inside one function (D-34) — this repo's native idiom"
    - "extraction-gated fixtures: a failed gate reports FAIL per case, never a silent skip"
    - "subshell-wrapped eval with CODEX_HOME + cwd redirected into $tmp"
    - "liveness demonstration by pointing fixtures at a known-wrong implementation"
key-files:
  created: []
  modified:
    - migrations/run-tests.sh
    - .planning/phases/09-region-aware-11-placement/09-VALIDATION-EVIDENCE.md
decisions:
  - "Pre-flight shape guard anchors on the mirror PATH, not `test -s` — the pin forbids anchoring on guard operators that case 10 mutation-tests, and MIRROR/SPEC_BLOCK naming is 09-04's choice"
  - "Case 03 RUNS Apply rather than only asserting the skip — otherwise cmp -s compares an untouched file and passes vacuously"
  - "Extraction gate reports FAIL per case rather than skipping — an ungated empty check makes State A PASS vacuously (verified)"
metrics:
  duration: ~30 min
  completed: 2026-07-15
  tasks: 3
  commits: 3
  files: 2
  suite_before: 279 PASS / 2 SKIP / 0 FAIL (worktree, exit 0)
  suite_after: 279 PASS / 2 SKIP / 25 FAIL (worktree, exit 1 — RED BY DESIGN)
---

# Phase 9 Plan 03: Write test_migration_0009 RED, Observe It Failing — Summary

Wrote ten TEST-03 fixture cases plus D-38's four-state double-sided idempotency table against
a migration document that does not exist, observed the suite RED, and recorded the observation
as auditable evidence — discharging ROADMAP hard ordering 2 ("RED before GREEN").

## THIS PLAN ENDS RED. THAT IS THE DELIVERABLE.

`migrations/run-tests.sh 0009` exits **1** with **PASS: 0 / FAIL: 25**, because
`migrations/0009-spec-11-region-aware-placement.md` **does not exist**. This is the required
terminal state, not a defect.

- **Do not "fix" it.** Plan 09-04 turns it GREEN by *shipping the document*.
- **The 0009 document was NOT created, stubbed, or scaffolded** — verified at plan end.
- **No assertion was weakened** and **no "skip if the document is missing" guard was added.**
  A conditional skip is precisely how a suite that never fails ships as coverage.
- The auditable trail is the commit shape: three `test(09-03):` RED commits here; `feat(GREEN)`
  belongs to 09-04.

## What Was Built

| Component | Contract |
|---|---|
| `test_migration_0009` | Banner, `mktemp -d` + `trap RETURN`, printf-synthesized fixtures, dispatcher-wired at `0009` |
| Three extractions | Pre-flight / Step 1 Idempotency / Step 1 Apply, pulled from 0009's own document (TEST-01), each gated by `assert_extracted_shape` before any consumer runs |
| Four-state table (D-38) | State A `applied`; **State B `not-applied` despite provenance present**; State C `not-applied`; D-32 unterminated marker fails closed on State B's predicate; State D at case 05 |
| Ten cases (D-46) | `01-gitnexus-led-inject` … `10-corrupt-mirror-refused`, all as case labels in one function |
| `_m0009_mk_fake_home` / `_m0009_mk_project` / `_m0009_apply` / `_m0009_ok` / `_m0009_fail` | File-scope `_m0009_`-prefixed helpers, following this harness's `_cpr_*` convention (shell has no function-local functions) |

**D-46 is 10 cases, not 8.** `09-PATTERNS.md`'s Metadata note ("D-46 locks this phase to 8
cases") is **stale** — confirmed live: the pin `8520f90` carries all ten fixture dirs including
`09-two-provenance-heal` and `10-corrupt-mirror-refused`. CONTEXT.md/REQUIREMENTS.md win.

## Verification Gates

| Gate | Result |
|---|---|
| `run-tests.sh 0009` exits NON-ZERO with `FAIL: > 0` | **PASS** — exit 1, PASS 0 / FAIL 25 (RED, required) |
| `run-tests.sh 0001` exits 0 | **PASS** — 09-02's work undisturbed |
| `run-tests.sh drift` exits 0 | **PASS** — newest migration is still 0008 @ 0.6.0 until 09-04 lands |
| Full suite | **PASS 279** (= worktree baseline exactly) / FAIL 25 / SKIP 2 — RED confined to 0009 |
| `0009-spec-11-region-aware-placement.md` does NOT exist | **PASS** — ABSENT |
| `git status --porcelain AGENTS.md 0001 0004` | **PASS** — prints nothing |
| Dispatcher wired: `grep -c 'FILTER" = "0009"'` | **PASS** — 1 |
| `assert_check` count, awk-scoped to fn body (≥4) | **PASS** — 5 |
| State B's 4th arg is `not-applied` | **PASS** — `"$idem_block" "$sb" "not-applied"` (run-tests.sh:3550) |
| Ten labels, comment-filtered (≥10) | **PASS** — 36 label-carrying code lines, **10 distinct** |
| `grep -q 'RED OBSERVED'` in evidence | **PASS** — recorded, and the block **diffs CLEAN** against a fresh run |
| Real `~/.codex` mirror intact (T-09-10) | **PASS** — 3748 bytes, 79 lines, tail sentinel present, byte-identical to repo mirror, mtime 2026-06-09 |

## Liveness Demonstrations (Dimension 8 — all three mandatory ones captured)

Full verbatim output is recorded in `09-VALIDATION-EVIDENCE.md` §12-13. Summary:

### 1. Naive-anchor override (Task 2) — the suite-level half of TEST-02

Pointed `MIGRATION_0009` at 0001's document (the naive `/^## / && !done` anchor), on a
**scratch copy** — the tracked file was never mutated.

- **Run 1 (guard intact):** `PASS 0009 Step 1 Apply: extraction ... non-empty` then
  `FAIL ... does NOT contain 'gitnexus:start'`. **D-36's thesis observed live: non-empty and
  still wrong.** The guard correctly gated all six cases.
- **Run 2 (guard bypassed):** **8 of 14 case assertions FAIL.**
  - **Case 01: provenance line 10 vs gitnexus:start line 5** — the naive rule injected §11
    *inside* the region. **These are the exact line numbers 09-01's counter-case A recorded**
    — the fixture-level twin and rule-level replay reproduce the same defect at the same
    coordinates.
  - **Case 03: byte-identity BROKEN** — the over-eager anchor caught, which is precisely what
    CONTEXT.md says case 03 exists for. The assertion is live, not vacuous.
  - Case 02: 2 provenance lines (naive duplicates, never moves). Case 04: `exit=2`. Case 05:
    `exit=0` and the hand-written §11 mangled.

### 2. Case-07 substring mutation (Task 3) — the dead-assertion detector

| Variant | Result |
|---|---|
| Control — anchored `/^<!-- gitnexus:start -->$/` | **PASS=4 FAIL=0** |
| Mutated — substring `/gitnexus:start/` | **PASS=3 FAIL=1 — case 07 the ONLY failure** |

Exactly the specified behavior: a substring match passes every other fixture and fails only
this one. **The passing control is also forward evidence for 09-04**: the four-state table
(including State B non-zero despite provenance) is satisfiable by the D-21/D-32 predicate —
09-04 is not being handed a contradictory contract.

### 3. The extraction gate is load-bearing (Task 1) — not in the plan, but necessary

Verified that passing an **empty** check to `assert_check` makes **State A report PASS**
(`eval ""` → exit 0 → `applied`), as does case 07 — both expect `applied`. Without the
`idem_ok` gate, two assertions would have passed **vacuously** against a missing document
while the suite still looked partially green. That is the exact Phase 8 defect. The gate
converts each into an honest FAIL.

## Deviations from Plan

### 1. [Rule 2 - Correctness] Pre-flight shape guard anchors on the mirror path, not `test -s`

- **Found during:** Task 1, reading the pin's `common-verify.sh` before porting it.
- **Issue:** The plan specifies `test -s` as the pre-flight's required substring. The pinned
  upstream **explicitly rejects exactly this**, with a documented rationale: anchor on what
  identifies the block *structurally*, *"NOT on the specific guard operators (`test -s`, the
  tail-sentinel grep) that fixture 10 exists to mutation-test. Coupling this shape check to
  the guard text itself would make reverting a guard trip the loader for EVERY fixture …
  masking the real signal."* Case 10 mutation-tests those two operators, so gating the loader
  on one would hide the signal case 10 exists to produce. Secondarily, the plan's own
  interfaces block leaves the variable named `MIRROR`/`SPEC_BLOCK` — 09-04's choice — so a
  name-based anchor is brittle too.
- **Fix:** Anchored on `spec-mirrors/11-coding-discipline-0.4.0.md` (invariant under either
  naming, not a mutation-tested operator). **`test -s` and the tail sentinel are still
  asserted** — as two explicit D-28.1 *document-contract* assertions, where a missing guard
  names itself instead of masquerading as an extractor failure. Strictly more coverage than
  the plan asked for, same intent.
- **Files modified:** `migrations/run-tests.sh` — **Commit:** `a4b137f`

### 2. [Rule 1 - Bug] Case 03 runs Apply rather than only asserting the runtime skip

- **Found during:** Task 2.
- **Issue:** The plan derives case 03's byte-identity from Step 1 being skipped ("Because the
  idempotency check returns `applied`, the migration runtime skips Step 1 entirely; assert the
  file is BYTE-IDENTICAL"). But **if Apply never runs, `cmp -s` compares a file nothing
  touched and passes unconditionally** — a dead assertion, the precise defect class this phase
  exists to close. The plan's own stated purpose for the case is to "catch an over-eager
  anchor", and an over-eager anchor can only manifest if Apply *runs*.
- **Fix:** Run Apply deliberately and assert byte-identity against a pristine copy — the
  fixture-level twin of 09-01's CASE 1 (ANCHOR-03). The skip itself is still asserted, by the
  State A row. **Verified live:** under the naive anchor, case 03's byte-identity FAILS, so
  the live version genuinely discriminates.
- **Files modified:** `migrations/run-tests.sh` — **Commit:** `2315393`

### 3. [Environmental, not a deviation] Submodule init required in the worktree

`vendor/agenticapps-shared` was unpopulated in the fresh worktree; the harness hard-fails
without it. Ran `git submodule update --init --recursive` → `1f5d543`. A checkout of an
already-pinned submodule; no tracked-file change, no new dependency surface (not a
package-manager install, so the Rule 3 exclusion does not apply). Same as 09-01/09-02.

### 4. [Environmental, not a deviation] Worktree baseline is 279/2, not 280/1

One assertion SKIPs because it probes `$REPO_ROOT/../agenticapps-workflow-core`, which does
not resolve from a nested worktree path. Pre-existing and fully explained by 09-01/09-02;
expect 280/1 on the main checkout. **FAIL count is the metric that matters, and PASS held at
exactly 279 — the worktree baseline — so all 25 FAILs are 0009's own.**

## Scope Confinement (Task 3 acceptance — mandatory)

`gitnexus_detect_changes()` was run before commits. It reported `risk_level: low,
affected_count: 0` — **but that verdict is not evidence about this change**: it reports
against the **main checkout**, not this worktree. It listed uncommitted `AGENTS.md`/`CLAUDE.md`
edits that are not mine and **never saw `run-tests.sh`**. RESEARCH.md assumption A2 (GitNexus
does not index shell functions) was confirmed empirically by 09-02 via Cypher. Grep is ground
truth here, per this plan's own `<mcp_tools>` guidance.

**Ground truth, hash-compared against the wave-1 tip `103cdfa`:**

- `test_migration_0000` … `test_migration_0008` bodies: **all byte-identical** (no leak).
- 09-02's `extract_step_block` / `extract_preflight_block` / `assert_extracted_shape`:
  **all UNCHANGED**.
- Both diff hunks are **pure additions**; `--diff-filter=D` reports **zero deletions**.
- Full-suite PASS stayed at exactly **279** — an arithmetic check that nothing regressed.

## Notes for Plan 09-04 (the GREEN half)

**Turn this suite green by shipping the document, never by editing the fixtures.** If a
fixture must change for 0009 to pass, that is a design disagreement to surface explicitly.

The contract these fixtures assert:

1. `## Pre-flight` fenced block resolving the mirror from `${CODEX_HOME:-$HOME/.codex}`,
   carrying **both** D-28.1 layers (`test -s` **and** `grep -q '^### 4\. Goal-Driven
   Execution$'`), both refusing with **`exit 3`**, and **passing (exit 0)** on a healthy
   mirror + `.git` + SKILL.md at `0.6.0` (D-39 accepts `0.(6.0|7.0)`).
2. `### Step 1: …` with `**Idempotency check:**` (fenced) — provenance present **AND NOT
   in-region**, marker regexes **anchored**. State B must return non-zero.
3. `### Step 1` `**Apply:**` (fenced) carrying `gitnexus:start`, the D-30 three-branch
   dispatcher **inside Apply** (case 05 asserts the extracted *Apply* exits 3 — 0001 puts its
   conflict check in the pre-flight; per the pin's `0029:155-172`, 0009's belongs in Apply),
   D-33's informational skip naming `update-codex-agenticapps-workflow`, the `swallowed_own_h2`
   reset, and an `END` EOF fallback.
4. `**Rollback:** \`git checkout AGENTS.md\`.` as **prose within Step 1, with no fenced awk**
   (D-47).
5. Heading shapes must stay `### Step N…` / `**Apply:**` at line start — 09-02's helpers match
   by literal prefix.

`assert_extracted_shape` contributes **2** assertions per call; factor that into expected PASS
counts.

## Deferred / Noted, Not Fixed

- **`extract_step_block`'s `want` flag is not cleared at the next step boundary.** For a label
  with no fence inside its step (e.g. a prose `**Rollback:**`), `want` stays armed past
  `### Step 2` and latches onto Step 2's fence. Harmless for 0009's real consumers (Apply and
  Idempotency check both have fences inside their own step) and `assert_extracted_shape` would
  catch it anyway — which is exactly why D-36 exists. **Avoided rather than relied upon:**
  case 08 scopes its own awk from `**Rollback:**` to `### Step 2` instead of using the helper.
  09-02's helper is out of this plan's scope; logged for a follow-up.
- **D-37's deferred item stands** — 0008's inlined Step-3 insert-awk copy (~`run-tests.sh:985`)
  remains un-converted, as scoped.

## Threat Model Compliance

| Threat ID | Disposition | Status |
|---|---|---|
| T-09-10 (corrupt mirror written to real `~/.codex`) | mitigate | **Met** — `_m0009_mk_fake_home` builds mirrors only under `$tmp`; every eval exports `CODEX_HOME` there. Real mirror verified intact: 3748 bytes, 79 lines, sentinel present, byte-identical, mtime 2026-06-09 |
| T-09-11 (Apply run at the real repo root) | mitigate | **Met** — every eval subshelled and `cd`'d to a `_m0009_mk_project` scratch root; `trap 'rm -rf "$tmp"' RETURN` bounds it. `git status --porcelain AGENTS.md` empty |
| T-09-07 (extracted `exit 3` kills the suite) | mitigate | **Met** — `_m0009_apply` wraps every eval in a subshell; cases 05 and 10 are the two `exit 3` paths and both assert the code from a subshell |
| T-09-08 (dead-by-construction fixtures) | mitigate | **Met** — three liveness demos (naive-anchor override, case-07 substring mutation, terminal RED), all captured; plus the gate-is-load-bearing demo. Source assertions awk-scoped and comment-filtered |
| T-09-12 (claiming RED-before-GREEN without evidence) | mitigate | **Met** — `## RED OBSERVED` records verbatim output, SHA `2315393`, and proof the doc is absent; block diffs clean against a fresh run; `test(09-03):` prefixes make the ordering legible |
| T-09-05 (unpinned upstream) | mitigate | **Met** — all fixture intent read via `git -C ../claude-workflow show 8520f90:…`; pin recorded in the function header |
| T-09-SC (package installs) | accept | **Met** — no installs; submodule init only |

## Known Stubs

**None.** The suite is fully wired and every case is live. The 25 FAILs are not stubs — they
are the plan's required RED terminal state, caused by an absent document that plan 09-04 owns.

## Threat Flags

None. No new network, auth, file-access, or schema surface. All file surgery is confined to
`mktemp -d` scratch roots with `CODEX_HOME` redirected.

## Requirements

- **TEST-03** — satisfied structurally: ten cases, printf-synthesized, one function, no
  per-fixture directories (D-34).
- **TEST-02** — RED half satisfied with recorded evidence: observed failing before 0009
  existed **and** observed failing against the naive anchor specifically. GREEN half is 09-04's.

## Commits

| Task | Commit | Description |
|---|---|---|
| 1 | `a4b137f` | test(09-03): scaffold test_migration_0009 + four-state idempotency table (RED) |
| 2 | `2315393` | test(09-03): add the six locked TEST-03 cases 01-06 (RED) |
| 3 | `185abfd` | test(09-03): add D-46's cases 07-10 and record the RED observation (TEST-02) |

## Notes for the Orchestrator

- **STATE.md and ROADMAP.md deliberately untouched** (worktree mode — the orchestrator owns
  those writes after the wave merges).
- **REQUIREMENTS.md deliberately untouched** — TEST-02/TEST-03 are the plan's `requirements`,
  but the wave merges alongside other plans and this file is a shared artifact. Recommended
  marking after merge: **TEST-03 → complete**; **TEST-02 → complete on its RED half only**,
  or keep Pending until 09-04 lands GREEN, since the requirement describes the full
  RED→GREEN cycle.
- **The phase's full suite will report FAIL: 25 until 09-04 merges.** That is expected and is
  ROADMAP hard ordering 2 working as designed — not a wave-2 regression.

## Self-Check: PASSED

| Claim | Verified |
|---|---|
| `migrations/run-tests.sh` contains `test_migration_0009` | FOUND |
| `09-VALIDATION-EVIDENCE.md` contains `RED OBSERVED` | FOUND |
| `09-03-SUMMARY.md` exists | FOUND |
| Commit `a4b137f` | FOUND |
| Commit `2315393` | FOUND |
| Commit `185abfd` | FOUND |
| `migrations/0009-spec-11-region-aware-placement.md` does NOT exist | CONFIRMED ABSENT |
| Ten distinct case labels | 10/10 |
| Recorded RED block matches a fresh run | DIFF CLEAN |
</content>
</invoke>
