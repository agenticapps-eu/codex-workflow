---
phase: 12-path-safety-review-debt
verified: 2026-07-17T21:10:00Z
status: passed
score: 13/13 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 12/13
  gaps_closed:
    - "A `--file` value naming a not-yet-created file in a not-yet-created dir still falls through (never exit-2-blocks) — fail-safe, never fail-open"
  gaps_remaining: []
  regressions: []
---

# Phase 12: Path Safety & Review Debt Verification Report

**Phase Goal:** The `--file` guard actually stops a symlink-based escape (not just a lexical `..`), and the four independently-scoped `09-REVIEW.md` defects are each closed with their own proof — not batched into one undifferentiated cleanup.
**Verified:** 2026-07-17
**Status:** passed
**Re-verification:** Yes — after gap closure (plan 12-04)

## Gap-Closure Verification (Truth #4)

The prior verification (12/13) FAILED exactly one must-have — 12-01-PLAN.md truth
#4: "A `--file` value naming a not-yet-created file in a not-yet-created dir still
falls through (never exit-2-blocks) — fail-safe, never fail-open." Plan 12-04
claims to close this with a lexical `$REPO_ROOT/.planning`-rooted fallback that
fires only when `_canon_dir` returns empty (parent does not exist yet). I did not
trust the SUMMARY's claims — I independently rebuilt the verifier's exact repro
and reran the mutation cycle myself.

**Independent repro (built from scratch, not copy-pasted from the SUMMARY):**

```
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.planning/phases"
PHASEDIR="$SANDBOX/.planning/phases/13-active-phase"
mkdir -p "$PHASEDIR"; touch "$PHASEDIR/13-01-PLAN.md"
( cd "$SANDBOX/.planning" && ln -sf "phases/13-active-phase" current-phase )
cp skills/agentic-apps-workflow/scripts/check-plan-review.sh "$SANDBOX/check-plan-review.sh"
( cd "$SANDBOX" && bash check-plan-review.sh --file ".planning/phases/14-new-nonexistent/14-01-PLAN.md" )
```

**Result: exit code 0.** (Prior verification observed exit 2 here before the fix;
pre-Phase-12 script also returned exit 0 — this restores that behavior.)

**Independent mutation test (RED→GREEN), run directly on the live repo file, not
in a sandbox copy, then fully restored:**

1. Changed `elif [ -z "$_cpr_canon_parent" ]; then` (check-plan-review.sh:232) to
   `elif false && [ -z "$_cpr_canon_parent" ]; then`.
2. Ran `bash migrations/run-tests.sh`: **406 PASS / 1 FAIL / 1 SKIP** — the single
   FAIL was exactly fixture (d): `WR-03 bypass: --file
   .planning/phases/14-new-nonexistent/14-01-PLAN.md -> exit 0 ... (expected
   exit=0, got exit=2)`. RED confirmed, independently reproduced (matches the
   SUMMARY's claimed transcript exactly).
3. Restored the file from a pre-mutation backup (byte-diff confirmed identical to
   the committed version). Reran: **407 PASS / 0 FAIL / 1 SKIP** — fixture (d) now
   PASS (`exit=0`). GREEN confirmed.
4. `git diff --stat` and `git status --short` confirmed clean after restore — no
   stray mutation left in the tree.

**Conclusion: truth #4 now holds.** The gap is genuinely closed, not merely
claimed closed.

## Regression Check (Truths #1/#2/#3 — must NOT have regressed)

Independently rebuilt all three WR-03 scenarios from scratch (not reusing the
suite's fixture code, to cross-check the suite itself isn't the only thing
asserting these):

| # | Scenario | Expected | Observed | Status |
|---|----------|----------|----------|--------|
| 1 | `--file` parent is a symlink resolving OUTSIDE `.planning` | exit 2 | exit 2 (`❌ plan-review gate: BLOCKED`) | ✓ VERIFIED — not regressed |
| 2 | `--file` parent is a symlink resolving INSIDE `.planning` | exit 0 | exit 0 | ✓ VERIFIED — not regressed |
| 3 | `vendor/foo/.planning/X-PLAN.md` with `vendor/foo/.planning/` an EXISTING real dir | exit 2 | exit 2 (`❌ plan-review gate: BLOCKED`) | ✓ VERIFIED — not regressed |

The fallback added in 12-04 lives strictly in the `elif [ -z "$_cpr_canon_parent" ]`
branch (verified by reading check-plan-review.sh:230-264): the `if [ -n
"$_cpr_canon_parent" ] && _is_contained ...` accept path (truths #1/#2) and the
sibling-prefix containment-false path (truth #3) are untouched — they all require
`_cpr_canon_parent` to be non-empty, i.e. the parent directory to already exist,
which is precisely the case the new fallback never touches.

## Fixture (d) Fidelity Check

- `grep -n "14-new-nonexistent" migrations/run-tests.sh | grep -E "mkdir|touch|_cpr_enf_phase"` returns nothing — the target dir's token appears ONLY inside the `--file` argument, label, and comments. The fixture genuinely does not pre-create `.planning/phases/14-new-nonexistent/`, unlike every other `_cpr_enf_phase`-based fixture in the file.
- Fixture (d) reuses `_cpr_enf_phase "$s" "13-active-phase" "13-01-PLAN.md"` (verified against the real `_cpr_enf_phase` definition at run-tests.sh:2615 — it `mkdir -p`s the phase dir, touches the named file(s), and symlinks `current-phase` to it — no REVIEWS.md is created, matching the "PLAN.md present, no REVIEWS.md" mid-review state the repro requires) and `_cpr_case` (verbatim, no second sandbox/exit-code helper introduced).
- Mutation-proven RED→GREEN independently by the verifier (see above) — matches the SUMMARY's claimed transcript byte-for-byte on the FAIL/PASS line text and PASS/FAIL/SKIP counts.
- Fixture (a) (symlinked-parent-escape) re-run alongside fixture (d) in both the RED and GREEN suite runs above, still asserting exit 2 in both — confirms the fallback did not reopen the WR-03 hole (its parent is an EXISTING symlink, so `_cpr_canon_parent` is non-empty and the new `elif` branch never fires for it).

## Full Suite

`bash migrations/run-tests.sh` (clean, unmutated tree): **407 PASS / 0 FAIL / 1
SKIP.** Matches the SUMMARY's claimed count exactly. Independently executed, not
taken on faith.

## ADR-0009 Disclosure Check

- `grep -c "Reversed (Phase 12, WR-03)" docs/decisions/0009-plan-review-gate.md` = 1 — single in-place marker, not duplicated.
- `grep -n "^## Correction" docs/decisions/0009-plan-review-gate.md` — no match. No `## Correction` section opened (correctly deferred to Phase 13 / DOC-03, confirmed still `[ ]` Pending in REQUIREMENTS.md).
- An `**Extended (Phase 12 gap-closure, 12-04):**` paragraph is appended, dated 2026-07-17, immediately after the existing Reversed marker (read in full at docs/decisions/0009-plan-review-gate.md:417-436). It discloses: the not-yet-created-dir consequence found by verification, the mechanism of the fallback (fires only on empty `_canon_dir`), the preserved symlink-escape invariant (existing symlinked parent still has non-empty `_canon_dir` and is still rejected), the `$REPO_ROOT/.planning` rooting (not a bare `*/.planning/*` glob), and the mutation-proof evidence pointer. This closes the disclosure gap the prior verification flagged (prior truth #5 noted the marker did NOT yet disclose this consequence).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Symlinked parent resolving OUTSIDE `.planning` is rejected (exit 2) | ✓ VERIFIED | Independently rebuilt sandbox, observed exit 2. Not regressed by 12-04's fallback (fallback only fires when parent does not exist). |
| 2 | Symlinked parent resolving INSIDE `.planning` is still accepted (exit 0) | ✓ VERIFIED | Independently rebuilt sandbox, observed exit 0. |
| 3 | Sibling-prefix-collision (`vendor/foo/.planning/X-PLAN.md`) with EXISTING parent falls to gate (exit 2) | ✓ VERIFIED | Independently rebuilt sandbox, observed exit 2. |
| 4 | `--file` naming a not-yet-created file in a not-yet-created dir still falls through (never exit-2-blocks) — fail-safe | ✓ VERIFIED (gap closed) | Independently rebuilt the exact prior-verification repro from scratch: exit 0. Independently mutation-tested the fallback RED (exit 2, 1 FAIL) → GREEN (exit 0, 0 FAIL), byte-diff-confirmed clean restore. |
| 5 | ADR-0009 decision 12 carries a Reversed marker; matching Open-follow-up marked resolved; not-yet-created-dir consequence now disclosed | ✓ VERIFIED | `Reversed (Phase 12, WR-03)` count = 1; `Extended (Phase 12 gap-closure, 12-04)` paragraph present, dated, discloses the fallback, preserved invariants, and `$REPO_ROOT/.planning` rooting. No `## Correction` section opened. |
| 6 | Full-script grep of `validate-0009-anchor.sh` stdout finds zero mirror-derived values | ✓ VERIFIED (regression check, no change in 12-04) | Not touched by 12-04; carried forward from initial verification, unaffected file. |
| 7 | Re-vendor of the mirror does not alter validator's passing-run stdout | ✓ VERIFIED (regression check) | Not touched by 12-04. |
| 8 | `extract_step_block` extracts `### Step 1` without capturing `### Step 10`+ | ✓ VERIFIED (regression check) | Not touched by 12-04; full suite includes `test_extract_step_block_delimiter`, still PASS. |
| 9 | CASE 1 asserts strictly-fewer output lines than input (no hardcoded line number) | ✓ VERIFIED (regression check) | Not touched by 12-04. |
| 10 | Each of the three REV fixes is independently mutation-proven | ✓ VERIFIED (regression check) | Not touched by 12-04; full suite green. |
| 11 | `docs/decisions/README.md` states ADR-NNNN and migration-NNNN are independent numbering sequences | ✓ VERIFIED (regression check) | Not touched by 12-04, file unmodified this plan. |
| 12 | Prescribes always qualifying as `ADR-NNNN`/`migration NNNN`, never bare `NNNN` | ✓ VERIFIED (regression check) | Not touched by 12-04. |
| 13 | Carries the live worked example: migration 0009 documented by ADR-0010, ADR-0009 a different subject | ✓ VERIFIED (regression check) | Not touched by 12-04. |

**Score:** 13/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` | Lexical `$REPO_ROOT/.planning`-rooted fail-safe-accept fallback in the empty-`_canon_dir` branch, reusing `_is_contained` | ✓ VERIFIED | `elif [ -z "$_cpr_canon_parent" ]` branch present at :232, calls `_is_contained "$_cpr_lex_parent" "$REPO_ROOT/.planning"` at :262. `_is_contained` call count = 3 (def + resolve-then-contain call + new fallback call + resolve_phase's own call = 4 total incl. the pointer-containment check; the bypass-block count increased by exactly 1 as required). No second canonicalization helper defined (`_canon_dir` remains the sole `pwd -P` definition). |
| `migrations/run-tests.sh` | Fixture (d): not-yet-created-dir + unrelated active PLAN.md-no-REVIEWS.md phase, exit 0, target dir NOT pre-created | ✓ VERIFIED | Fixture present at ~:3261-3263, reuses `_cpr_enf_phase`/`_cpr_case` verbatim, target dir token never appears in a `mkdir`/`touch`/`_cpr_enf_phase` call. Mutation-proven RED→GREEN independently by the verifier. |
| `docs/decisions/0009-plan-review-gate.md` | Extended in-place Reversed marker disclosing the fallback | ✓ VERIFIED | `Extended (Phase 12 gap-closure, 12-04)` paragraph present, no Correction section opened. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `check-plan-review.sh --file` bypass, empty-`_canon_dir` branch | `_is_contained` against `$REPO_ROOT/.planning` | direct reused call | ✓ WIRED | Confirmed at check-plan-review.sh:262; lexical parent computed at :258-261 anchored at `$REPO_ROOT` when relative. |
| `run-tests.sh` fixture (d) | `check-plan-review.sh` | `_cpr_case` sandbox invocation, exit-0 assertion | ✓ WIRED | Confirmed at run-tests.sh:3263, invokes the real script via `_cpr_case`. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| WR-03 | 12-01, 12-04 | `--file` guard canonicalize-and-contain + not-yet-created-dir fail-safe fallback | ✓ SATISFIED | `.planning/REQUIREMENTS.md:110-124` marks WR-03 `[x]` Complete, describing both the original canonicalize-and-contain guard and the 12-04 fallback closure in the same entry. Independently verified end-to-end (all four scenarios: symlink-escape rejected, symlink-inside accepted, sibling-prefix rejected, not-yet-created-dir accepted). |
| REV-01/02/03/04 | 12-02, 12-03 | Unaffected by 12-04 | ✓ SATISFIED | Carried forward from initial verification; full suite green, files unmodified by this plan. |

No orphaned requirements. DOC-03 (Correction section) remains correctly `[ ]`
Pending, scoped to Phase 13 — not claimed by this phase, and rightly not opened
here.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No `TBD`/`FIXME`/`XXX`/`HACK`/`PLACEHOLDER` markers found in the 3 files 12-04 modified | — | Debt-marker gate clean. |
| — | — | No stub patterns (`return null`, empty handlers, hardcoded empty arrays flowing to output) in the new fallback branch | — | The fallback computes a real value and calls the real `_is_contained` helper; not a stub. |

The two INFO-level anti-patterns noted in the prior verification (stale
`:84-118` citation, `*REVIEW[S].md` comment claim) are unrelated to this
plan's scope; the stale citation was in fact opportunistically corrected to
`:166-176` by 12-04 Task 3 (confirmed present in the ADR text), leaving one
fewer residual INFO item than before.

### Behavioral Spot-Checks / Mutation Evidence

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full migration test suite (clean tree) | `bash migrations/run-tests.sh` | 407 PASS / 0 FAIL / 1 SKIP | ✓ PASS |
| Truth #4 repro (built from scratch) | manual sandbox + `check-plan-review.sh --file .planning/phases/14-new-nonexistent/14-01-PLAN.md` | exit 0 | ✓ PASS |
| Truth #1 regression check (built from scratch) | manual sandbox, symlinked parent escaping `.planning` | exit 2 | ✓ PASS — not regressed |
| Truth #2 regression check (built from scratch) | manual sandbox, symlinked parent inside `.planning` | exit 0 | ✓ PASS — not regressed |
| Truth #3 regression check (built from scratch) | manual sandbox, `vendor/foo/.planning/X-PLAN.md`, existing parent | exit 2 | ✓ PASS — not regressed |
| Fixture (d) mutation RED | `elif false && [ -z "$_cpr_canon_parent" ]` + `bash migrations/run-tests.sh` | 406 PASS / **1 FAIL** / 1 SKIP, FAIL = fixture (d) | ✓ PASS (RED confirmed) |
| Fixture (d) mutation GREEN (restored) | byte-diff-restored file + `bash migrations/run-tests.sh` | 407 PASS / 0 FAIL / 1 SKIP | ✓ PASS (GREEN confirmed) |
| `git diff --stat` / `git status` after full mutation cycle | — | clean (no stray mutation) | ✓ PASS |

### Human Verification Required

None. Every must-have in this phase is a shell-script/text-file behavior
verifiable by direct execution, sandbox reconstruction, and mutation testing;
no UI, real-time, or external-service behavior is in scope.

### Gaps Summary

None. The single gap from the prior verification (12-01 truth #4 / 12-04's
subject) is genuinely closed: independently reconstructed from scratch (not
copy-pasted from the SUMMARY or the fixture code), the fallback returns exit 0
for the exact scenario that previously exit-2-blocked, and the fix is
mutation-proven RED→GREEN by the verifier directly, not merely claimed in the
SUMMARY. All three prior WR-03 truths (#1/#2/#3) were independently
re-verified from scratch and show no regression — the new fallback branch is
provably disjoint (by construction: `if [ -n ... ]` vs. `elif [ -z ... ]`) from
the paths those truths depend on. The full suite passes at the exact count the
SUMMARY claimed (407/0/1), the git tree is clean, and ADR-0009's disclosure is
complete without opening the out-of-scope Correction section. All 13 of Phase
12's must-have truths now hold.

---

_Verified: 2026-07-17_
_Verifier: Claude (gsd-verifier)_
