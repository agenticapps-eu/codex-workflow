---
phase: 12-path-safety-review-debt
reviewed: 2026-07-17T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - skills/agentic-apps-workflow/scripts/check-plan-review.sh
  - migrations/run-tests.sh
  - migrations/validate-0009-anchor.sh
  - docs/decisions/0009-plan-review-gate.md
  - docs/decisions/README.md
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-07-17
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 12 hardens the `--file` bypass in `check-plan-review.sh` (WR-03: parent-dir
canonicalize-and-contain against `$REPO_ROOT/.planning`), makes
`validate-0009-anchor.sh` stdout deterministic (REV-01/03), adds a delimiter
guard to `extract_step_block` in `run-tests.sh` (REV-02), and updates two ADR docs.

I verified the security-critical claims empirically rather than trusting the
prose:

- **Path-safety fix is correct and genuinely closes the hole.** I traced the
  moved bypass block, confirmed `_canon_dir` runs in a subshell (does not corrupt
  the script's cwd), confirmed the fix is strictly *more* restrictive than the old
  lexical-only bypass (no new fail-open), and confirmed parent-dir canonicalization
  resolves a symlink *anywhere* in the parent chain in one shot. The WR-03 test
  trio (symlink-escape → exit 2, symlink-inside → exit 0, vendored-`.planning` →
  exit 2) exercises `_is_contained` on a real directory and passes.
- **Awk delimiter guard is correct.** `delim_ok` uses 1-indexed `substr` at
  `plen+1`; for `stepp="### Step 1"` it correctly accepts `:`/space/EOL and rejects
  the digit in `### Step 10`, on both the `stepp` open and the `nextp` close
  boundary. No off-by-one.
- **Determinism verified.** `validate-0009-anchor.sh` runs byte-identically; the
  mirror line-count and all line-number echoes were removed from the happy path.
- **Full suite green:** `migrations/run-tests.sh` → 406 PASS / 1 SKIP / 0 FAIL.
  `shellcheck` is clean on `check-plan-review.sh` (the one SC2016 on
  `validate-0009-anchor.sh:209` is a false positive — literal backticks inside a
  printf fixture).

No BLOCKER-class defect found. One behavior-change WARNING and three
documentation/quality INFO items follow.

## Structural Findings (fallow)

No `<structural_findings>` block was provided for this review.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: `--file` bypass now silently drops for a legitimate plan file whose parent dir does not yet exist

**File:** `skills/agentic-apps-workflow/scripts/check-plan-review.sh:223-228`
**Issue:**
The old bypass exited 0 (ALLOW) for any `.planning/`-rooted path with a matching
canonical basename, **regardless of whether the parent existed**. The new guard
gates the `exit 0` on `[ -n "$_cpr_canon_parent" ] && _is_contained ...`, and
`_canon_dir` returns empty for a non-existent parent (it `cd`s into the path).
So a *legitimate* `--file .planning/phases/13-new/13-01-PLAN.md` whose phase
directory has not been created yet no longer bypasses — it falls through to
`resolve_phase`, and if the currently-resolved active phase has `*-PLAN.md` but no
`*-REVIEWS.md`/`*-SUMMARY.md`, the verifier now returns `exit 2` (BLOCK) where it
previously returned `exit 0`.

This is the deliberately-chosen fail-closed direction (the code comment cites
T-12-02, "failing open is the milestone's nemesis"), so it is not a logic error —
but it is a real, undocumented behavioral regression for a normal planning action
(writing the first plan into a not-yet-`mkdir`'d phase dir). The ADR-0009 Reversed
marker discloses only the *vendored-path* tightening, not this parent-absent case.
It is also untested: every WR-03 fixture (`_cpr_enf_phase`) pre-creates the phase
directory, so the "legit `.planning` plan, parent absent" path has no coverage and
its exit code is unasserted.

**Fix:** Either (a) add a test asserting the intended verdict for a legitimate
`.planning/`-rooted `--file` whose parent does not yet exist, and document the
consequence in ADR-0009 decision 12's Reversed marker alongside the vendored-path
disclosure; or (b) if a to-be-created plan file should still bypass, fall back to a
*lexical* containment check when `_canon_dir` returns empty — e.g. after the
parent-absent case, verify the un-canonicalized `--file` is lexically rooted at
`.planning/` (the `..` guard already ran) before allowing:
```sh
if [ -n "$_cpr_canon_parent" ]; then
  _is_contained "$_cpr_canon_parent" "$_cpr_canon_planning_root" && exit 0
else
  # parent not yet created: no symlink to resolve, '..' already rejected above
  case "$CPR_FILE" in .planning/*) exit 0 ;; esac
fi
```
Choose (a) or (b) deliberately — do not leave the consequence both undocumented
and untested.

## Info

### IN-01: README numbering-convention claim "each starts at 0000" is inaccurate for the ADR series

**File:** `docs/decisions/README.md:16-18`
**Issue:** The newly-added "Numbering convention" section states the `ADR-NNNN`
and `migration NNNN` series "each start at `0000` and increment on its own." The
migration series does start at `0000` (`migrations/0000-baseline.md`), but the ADR
series starts at `0001` — there is no `ADR-0000` in `docs/decisions/`. The claim is
factually wrong for one of the two series it describes.
**Fix:** Reword to "each begins its own sequence (migrations from `0000`, ADRs from
`0001`) and increments independently," or drop the specific start number.

### IN-02: `*REVIEW[S].md` bracket obfuscation defends an invariant this phase itself violates

**File:** `skills/agentic-apps-workflow/scripts/check-plan-review.sh:184-193, 205`
**Issue:** The comment at 184-191 justifies writing `*REVIEW[S].md` (not
`*REVIEWS.md`) at line 193 to avoid a contiguous `REVIEWS.md` substring "this early
in the file" that "would falsely satisfy that grep-based check. Do not simplify
this back to `*REVIEWS.md`." But this phase's own WR-03 comment adds a contiguous
`REVIEWS.md` at line 205 ("the `REVIEWS.md` evidence guard's reject-any-symlink
rule"), and the defending comment itself (lines 189-190) plus the file header (line
10) already contain contiguous `REVIEWS.md` before any executable code. No
grep-based source-order test targeting the script's source exists in
`run-tests.sh`, and the full suite passes — so the bracket trick now protects an
invariant that is already broken in three places, making it misleading dead-weight
that a future maintainer will puzzle over.
**Fix:** Either drop the `[S]` obfuscation and the stale comment (the glob is
identical), or, if a source-order guard is genuinely intended, add it as a real
test and make the comment reference it precisely instead of a hypothetical.

### IN-03: ADR-0009 Reversed marker cites a stale line range that this phase invalidated

**File:** `docs/decisions/0009-plan-review-gate.md:410-411`
**Issue:** The Reversed marker says the lexical `..` check is "at `:84-118`
pre-Phase-12 numbering." This phase moved that block *down* the file (it now spans
roughly `:148-234`), so the cited `:84-118` range now points at unrelated code.
The "pre-Phase-12 numbering" caveat softens this but still leaves a reader chasing
a range that no longer exists in the current file.
**Fix:** Reference the block by its stable anchor (the `# --file bypass list`
comment / `_cpr_has_dotdot` guard) rather than an absolute line range, which drifts
on every edit.

---

_Reviewed: 2026-07-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
