---
phase: 12-path-safety-review-debt
verified: 2026-07-17T15:30:00Z
status: gaps_found
score: 12/13 must-haves verified
overrides_applied: 0
gaps:
  - truth: "A `--file` value naming a not-yet-created file in a not-yet-created dir still falls through (never exit-2-blocks) — fail-safe, never fail-open"
    status: failed
    reason: >
      Independently constructed the exact scenario 12-REVIEW.md's WR-01 finding describes
      (no WR-03 fixture covers it — every _cpr_enf_phase fixture pre-creates the phase dir).
      In a sandbox with an active phase (.planning/current-phase -> phases/13-active-phase)
      that has a *-PLAN.md but no *-REVIEWS.md (a realistic in-flight state — this repo's own
      Phase 12/13 boundary is an instance of it), invoking
      `check-plan-review.sh --file .planning/phases/14-new-nonexistent/14-01-PLAN.md` where
      `14-new-nonexistent/` does NOT exist returns exit 2 (BLOCK), not exit 0. The bypass's
      parent-dir canonicalization correctly returns empty and the bypass itself does not fire
      (D-02's literal contract holds at that layer), but control then falls through to
      resolve_phase, which resolves the unrelated ACTIVE phase (13-active-phase) via the
      current-phase pointer, finds its PLAN.md with no REVIEWS.md, and exits 2 through the
      REVIEWS.md evidence gate. Re-ran the identical scenario against the pre-Phase-12 script
      (`git show 7fe440d~1:...`) and confirmed exit 0 there — this is a genuine, reproducible
      behavioral regression introduced by this phase, not a pre-existing condition. With no
      active phase resolved at all, the same --file value correctly returns exit 0, confirming
      the failure is conditional but realistic (any repo with an in-flight unreviewed phase,
      which includes this repo's own Phase-12-to-Phase-13 transition).
    artifacts:
      - path: "skills/agentic-apps-workflow/scripts/check-plan-review.sh"
        issue: "Lines ~223-228: the --file bypass's fall-through-on-unresolvable-parent (D-02) is correct at the bypass layer, but nothing prevents the subsequent resolve_phase + REVIEWS.md gate from blocking a legitimate not-yet-created .planning-rooted plan file when a DIFFERENT active phase is mid-review. The old lexical-.. -only guard exited 0 unconditionally in this case; the new guard does not."
    missing:
      - "A fixture in migrations/run-tests.sh exercising a --file value whose parent dir does not exist, in a sandbox with an unrelated active phase that has PLAN.md-no-REVIEWS.md, asserting the intended verdict (currently unasserted — 12-REVIEW.md WR-01 flagged this as untested)."
      - "Either implement 12-REVIEW.md WR-01's fix option (b) — a lexical .planning/-rooted fallback when _canon_dir returns empty, so the bypass still authorizes a legitimate not-yet-created in-tree plan file — or explicitly accept option (a) (document the consequence in ADR-0009's Reversed marker and disclose it in the phase SUMMARY, which was not done) and add the missing test either way."
---

# Phase 12: Path Safety & Review Debt Verification Report

**Phase Goal:** The `--file` guard actually stops a symlink-based escape (not just a lexical `..`), and the four independently-scoped `09-REVIEW.md` defects are each closed with their own proof — not batched into one undifferentiated cleanup.
**Verified:** 2026-07-17
**Status:** gaps_found
**Re-verification:** No — initial verification

## Priority Concern (WR-01) — Independently Constructed Test

12-REVIEW.md flagged (WARNING, WR-01) that a legitimate `.planning/`-rooted plan file whose
parent directory does not yet exist could now reach `exit 2` where the old lexical guard
returned `exit 0`, and that no fixture covers this because every WR-03 fixture pre-creates the
phase directory. I constructed and ran the concrete repro myself rather than trusting the
narrative:

```
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/.planning/phases"
PHASEDIR="$SANDBOX/.planning/phases/13-active-phase"
mkdir -p "$PHASEDIR"; touch "$PHASEDIR/13-01-PLAN.md"    # active phase, PLAN present, no REVIEWS.md
( cd "$SANDBOX/.planning" && ln -sf "phases/13-active-phase" current-phase )

( cd "$SANDBOX" && bash check-plan-review.sh --file ".planning/phases/14-new-nonexistent/14-01-PLAN.md" )
# 14-new-nonexistent/ does NOT exist
```

**Result: exit code 2 (BLOCK).**

Cross-checked against the pre-Phase-12 script (`git show 7fe440d~1:skills/agentic-apps-workflow/scripts/check-plan-review.sh`)
with the identical sandbox: **exit code 0 (ALLOW)**. This confirms a genuine regression, not a
pre-existing limitation. With no active phase resolved at all (truly greenfield sandbox, no
`current-phase` pointer), the same `--file` value correctly returns exit 0 — so the failure is
conditional on there being an unrelated active, pending-review phase, which is a realistic and
common state (this repo's own Phase 12 → Phase 13 boundary is exactly this shape: Phase 12 is
executed and this verification is running while Phase 13 has not yet been planned/reviewed).

**Conclusion:** this CONTRADICTS 12-01-PLAN.md's must-have truth #4 ("A `--file` value naming a
not-yet-created file in a not-yet-created dir still falls through (never exit-2-blocks) —
fail-safe, never fail-open"). The bypass itself behaves exactly as D-02 specifies (empty
`_canon_dir` → does not fire → falls through), but the phase's own must-have promises a
stronger end-to-end guarantee ("never exit-2-blocks") than what the shipped code delivers once
the fall-through reaches `resolve_phase` + the REVIEWS.md gate. This is a real functional gap,
not a documentation nit — see gap entry in frontmatter.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Symlinked parent resolving OUTSIDE `.planning` is rejected (exit 2), where old lexical check let it through | ✓ VERIFIED | Fixture (a) PASSES; re-ran against pre-fix script (`7fe440d~1`) — observed exit=0 there, exit=2 post-fix. Independently mutation-tested `_is_contained` → `return 0` unconditionally — fixture (a) flips to FAIL (exit=0), confirming rejection is genuinely produced by `_is_contained`, not fall-through. Restored, `git diff --stat` clean. |
| 2 | Symlinked parent resolving INSIDE `.planning` is still accepted (exit 0) — resolve-then-contain | ✓ VERIFIED | Fixture (b) PASSES (exit=0). Code at `check-plan-review.sh:226-228` requires `_is_contained` true, not "no symlink" — resolve-then-contain confirmed by inspection and test. |
| 3 | Sibling-prefix-collision (`vendor/foo/.planning/X-PLAN.md`) no longer bypasses — falls to gate (exit 2) | ✓ VERIFIED | Fixture (c) PASSES; `vendor/foo/.planning/` created as a real dir in the fixture (confirmed by reading run-tests.sh:3219-3221) so `_canon_dir` succeeds and `_is_contained` genuinely evaluates false. Mutation-tested `_is_contained` → unconditional true — fixture (c) flips to FAIL, confirming genuine `_is_contained`-driven rejection, not D-02 fall-through. Restored, clean diff. |
| 4 | `--file` naming a not-yet-created file in a not-yet-created dir still falls through (never exit-2-blocks) — fail-safe | ✗ **FAILED** | See Priority Concern above. Independently constructed repro returns exit 2 in a realistic scenario (active unrelated phase pending review); pre-Phase-12 script returns exit 0 for the identical input. No fixture in the phase covers this case (12-REVIEW.md WR-01 confirmed). |
| 5 | ADR-0009 decision 12 carries a Reversed marker; matching Open-follow-up marked resolved | ✓ VERIFIED | `grep -n "Reversed (Phase 12, WR-03)"` at `:400`, `grep -n "Resolved (Phase 12)"` at `:463`. Marker names `_canon_dir`/`_is_contained`, parent-directory canonicalization, disclaims walk-each-prefix, discloses the `*/.planning/*` tightening. No `## Correction` section opened (`grep -c` = 0). Note: marker does NOT disclose the not-yet-created-dir consequence (truth #4's gap) — 12-REVIEW.md IN-03 also flags a stale line-range citation in this same marker (`:84-118` no longer matches post-move code; info-level, not blocking). |
| 6 | Full-script grep of `validate-0009-anchor.sh` stdout finds zero mirror-derived values | ✓ VERIFIED | `bash migrations/validate-0009-anchor.sh \| grep -Ec "\([0-9]+ lines\)\|at line [0-9]+"` = 0. Verified by direct execution, not just the SUMMARY's claim. |
| 7 | Re-vendor of the mirror does not alter validator's passing-run stdout | ✓ VERIFIED | Ran validator twice back-to-back — byte-identical stdout (`diff` clean). Assertions are relational (`-lt`, `-ge`) not value-printing; a re-vendor changes computed values, not the fixed text that gets echoed. |
| 8 | `extract_step_block` extracts `### Step 1` without capturing `### Step 10`+ (synthetic 10+-step doc) | ✓ VERIFIED | `test_extract_step_block_delimiter` PASSES. Independently mutation-tested: removed the `delim_ok(...)` guard from both the `stepp` and `nextp` match lines (reverting to bare `index($0, stepp) == 1`) → test flips to 2 FAIL ("extraction does NOT contain Step 1's own body" / "WRONGLY contains Step 10's body"). Restored, full suite back to 406 PASS / 0 FAIL, `git diff --stat` clean. |
| 9 | CASE 1 asserts strictly-fewer output lines than input (no hardcoded line number) | ✓ VERIFIED | Code at `validate-0009-anchor.sh:269-273`: `[ "$(wc -l < strip)" -lt "$(wc -l < input)" ]`, no literal `313`/`232`. Independently mutation-tested: replaced `candidate_strip` call with a no-op `cp` → assertion flips to FAIL ("strip did not reduce line count"), plus the downstream CASE 1 ZERO CHURN assertion also fails (both real, both catching the mutation). Restored, `git diff --stat` clean. |
| 10 | Each of the three REV fixes is independently mutation-proven (break → RED, restore → GREEN) | ✓ VERIFIED | All three (REV-01, REV-02, REV-03) independently mutated and restored by the verifier (not trusting the SUMMARY's claims) — see truths #6-9 evidence above. Every mutation cycle ended with `git diff --stat` clean. |
| 11 | `docs/decisions/README.md` states ADR-NNNN and migration-NNNN are independent numbering sequences | ✓ VERIFIED | `README.md:14-19` "## Numbering convention" states "**independent** numbering sequences." |
| 12 | Prescribes always qualifying as `ADR-NNNN`/`migration NNNN`, never bare `NNNN` | ✓ VERIFIED | `README.md:19-20`: "Always qualify a number in prose as `ADR-NNNN` or `migration NNNN`; never write a bare `NNNN`." |
| 13 | Carries the live worked example: migration 0009 documented by ADR-0010, ADR-0009 a different subject | ✓ VERIFIED | `README.md:23-26` states exactly this, verified against `ls migrations/*.md` (migration 0009 = `0009-spec-11-region-aware-placement.md`) and the Index table (ADR-0009 = plan-review gate, ADR-0010 = region-aware placement). |

**Score:** 12/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` | Augmented `--file` guard: lexical `..` floor + parent-dir canonicalize-and-contain, repo-root hoisted above bypass | ✓ VERIFIED (with caveat) | `_canon_dir`/`_is_contained` reused (not reinvented); repo-root block precedes the bypass; `_cpr_has_dotdot` floor intact. Functionally correct for symlink-escape and sibling-prefix cases; the not-yet-created-dir case (truth #4) is where the artifact's real-world behavior diverges from its own documented contract. |
| `migrations/run-tests.sh` | WR-03 fixtures + REV-01 determinism test + REV-02 delimiter fixture | ✓ VERIFIED | All fixtures present, wired into `test_check_plan_review_enforcement` and the runner list; all PASS; all independently mutation-tested by the verifier. |
| `docs/decisions/0009-plan-review-gate.md` | In-place Reversed marker + Resolved follow-up | ✓ VERIFIED | Present, correctly scoped, no Correction section opened. Does not disclose the not-yet-created-dir consequence (see truth #4/#5). |
| `migrations/validate-0009-anchor.sh` | Deterministic stdout + CASE 1 strictly-smaller assertion | ✓ VERIFIED | Byte-identical across repeated runs; assertion present and mutation-proven. |
| `docs/decisions/README.md` | Numbering-convention subsection | ✓ VERIFIED | Present with all three required elements. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `check-plan-review.sh --file` guard | `_canon_dir`/`_is_contained` | direct call, reused not reinvented | ✓ WIRED | Confirmed by reading the bypass block; no second canonicalization helper defined. |
| `run-tests.sh` WR-03 fixtures | `check-plan-review.sh` | `_cpr_case` sandbox invocation | ✓ WIRED | All three fixtures invoke the real script via `_cpr_case`; exit codes asserted. |
| `run-tests.sh` REV-01 determinism test | `validate-0009-anchor.sh` stdout | full-stdout grep | ✓ WIRED | `test_validate_0009_anchor_determinism` runs the real validator and greps full stdout. |
| `extract_step_block` | `### Step N` delimiter | `delim_ok()` substr guard | ✓ WIRED | Applied to both `stepp` and `nextp` boundaries per plan spec. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| WR-03 | 12-01 | `--file` guard canonicalize-and-contain, real symlink-escape defense | ⚠️ PARTIALLY SATISFIED | Symlink-escape and sibling-prefix sub-goals fully met (SC#1 fixtures pass). The guard's own "never exit-2-blocks the not-yet-created case" must-have FAILED under independent test — see Priority Concern. |
| REV-01 | 12-02 | validate-0009-anchor.sh stdout determinism | ✓ SATISFIED | Verified by direct execution + mutation test. |
| REV-02 | 12-02 | extract_step_block delimiter safety | ✓ SATISFIED | Verified by direct execution + mutation test. |
| REV-03 | 12-02 | CASE 1 strictly-smaller-count assertion | ✓ SATISFIED | Verified by direct execution + mutation test. |
| REV-04 | 12-03 | ADR/migration numbering-convention doc | ✓ SATISFIED | Verified by direct file read; worked example cross-checked against repo state. |

All five requirement IDs are present in `.planning/REQUIREMENTS.md` under §Path Safety & Review
Debt, mapped to Phase 12, marked `[x]` Complete and status "Complete" in the traceability table.
No orphaned requirements found (no additional Phase-12 IDs in REQUIREMENTS.md beyond these five).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `docs/decisions/0009-plan-review-gate.md` | ~410-411 | Stale line-range citation (`:84-118`) in the Reversed marker, now pointing at unrelated code after this phase moved the block | ℹ️ INFO | Matches 12-REVIEW.md IN-03. Cosmetic/documentation drift, not functional. |
| `docs/decisions/README.md` | ~17 | "each starts at `0000`" is factually wrong for the ADR series (ADRs start at `0001`; no `ADR-0000` exists) | ℹ️ INFO | Matches 12-REVIEW.md IN-01. Does not violate the plan's must-haves (independent-sequences statement, qualification rule, and worked example are all still correct); the extra "starts at 0000" clause is inaccurate prose beyond what was required. |
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` | 184-193, 205 | `*REVIEW[S].md` bracket-obfuscation comment claims to avoid a contiguous "REVIEWS.md" substring "this early in the file," but this phase's own WR-03 comment (line 205) and the file header already contain the literal substring earlier — the guard now protects an invariant already broken elsewhere, with no test enforcing it | ℹ️ INFO | Matches 12-REVIEW.md IN-02. Dead-weight/misleading comment, no functional effect (confirmed no source-order grep test exists and the suite passes regardless). |
| — | — | No `TBD`/`FIXME`/`XXX` markers found in any of the 5 phase-modified files | — | Debt-marker gate clean. |

No BLOCKER-class code-quality anti-pattern found beyond the WR-01 functional gap already
reported as a failed truth.

### Behavioral Spot-Checks / Full Suite Evidence

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full migration test suite | `bash migrations/run-tests.sh` | 406 PASS / 0 FAIL / 1 SKIP | ✓ PASS |
| ADR-0009 anchor validator | `bash migrations/validate-0009-anchor.sh` | All cases PASSED, `RESULT: all cases PASSED` | ✓ PASS |
| Validator stdout determinism (2 consecutive runs) | `diff` of two runs | Byte-identical | ✓ PASS |
| WR-03 fixture (a) mutation test | weaken `_is_contained` → unconditional true | flips FAIL (exit=0, expected 2) | ✓ PASS (RED confirmed) |
| WR-03 fixture (c) mutation test | same mutation | flips FAIL (exit=0, expected 2) | ✓ PASS (RED confirmed) |
| REV-01 determinism mutation test | reintroduce `(N lines)` into CASE 1 banner | determinism test flips FAIL | ✓ PASS (RED confirmed) |
| REV-02 delimiter mutation test | strip `delim_ok()` guard from both match sites | 2 assertions flip FAIL (wrong-body extraction) | ✓ PASS (RED confirmed) |
| REV-03 line-drop mutation test | no-op `candidate_strip` | assertion flips FAIL | ✓ PASS (RED confirmed) |
| **WR-01 priority-concern repro (new)** | `--file` into a not-yet-created dir, active unrelated phase pending review | **exit 2** (post-fix) vs **exit 0** (pre-Phase-12 script, identical input) | ✗ **FAIL** — contradicts must-have truth #4 |

All mutations were restored; `git diff --stat` confirmed clean after every cycle and at the end
of this verification session.

### Human Verification Required

None. Every must-have in this phase is a shell-script/text-file behavior verifiable by direct
execution and grep; no UI, real-time, or external-service behavior is in scope.

### Gaps Summary

Twelve of thirteen must-have truths hold, verified independently by direct execution and
mutation testing (not by trusting SUMMARY.md's claims). REV-01/02/03/04 are all fully and
correctly closed with genuine, verifier-reproduced RED→GREEN mutation proofs. WR-03's core
security property (symlink-escape rejection, sibling-prefix tightening, resolve-then-contain
accept-on-inside) is also genuinely closed and mutation-proven.

The one gap is exactly the concern 12-REVIEW.md's WR-01 finding raised, escalated per this
verification's priority-concern instruction: the guard's own must-have — "a `--file` value
naming a not-yet-created file in a not-yet-created dir still falls through (never
exit-2-blocks)" — does not hold end-to-end. The bypass layer itself behaves correctly per D-02
(empty `_canon_dir` → does not fire → falls through), but the phase never tested what happens
*after* the fall-through when a different, unrelated phase is mid-review: `resolve_phase` +
the REVIEWS.md gate can and does produce `exit 2` for a legitimate not-yet-created planning
artifact, a behavior the pre-Phase-12 script did not exhibit for the same input. This is a
real, reproducible functional regression, not merely an undocumented edge case — I built and
ran the repro myself and cross-checked against the pre-fix script to confirm it is new to this
phase.

12-REVIEW.md already named two concrete fix options (WR-01: (a) test + document the consequence
in the ADR marker, or (b) add a lexical `.planning/`-rooted fallback when `_canon_dir` returns
empty). Neither was taken — the phase's SUMMARY and ADR-0009 marker are silent on this case, and
no fixture covers it.

---

_Verified: 2026-07-17_
_Verifier: Claude (gsd-verifier)_
