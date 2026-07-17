---
phase: 11-migration-chain-repair
reviewed: 2026-07-16T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - migrations/0010-heal-0007-knowledge-capture.md
  - migrations/run-tests.sh
  - skills/update-codex-agenticapps-workflow/SKILL.md
findings:
  critical: 2
  warning: 3
  info: 4
  total: 9
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-07-16T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

The forward migration (`0010-heal-0007-knowledge-capture.md`), the new
`extract_step_block` inline-code-span fallback plus `test_migration_0010`
fixture in `migrations/run-tests.sh`, and the Stage D recovery runbook added
to `skills/update-codex-agenticapps-workflow/SKILL.md` are, on their own
terms, internally well-constructed: the migration's payload/pre-flight split
is coherent, the shared harness primitives (`assert_extracted_shape`,
`extract_preflight_block`, `_table_data_rows`) are reused rather than
duplicated, and the new fixture correctly extracts 0010's own document
content rather than transcribing it (TEST-01).

The review surfaced two BLOCKER-level defects, both in the *narrative*
correctness of the Stage D recovery runbook: the runbook asserts specific
outcomes ("0007 no longer selects", "`--migration 0010` … delivers the
missing payload") that are not actually produced by the update-selection
algorithm as documented earlier in the same file. Since this runbook is the
sole deliverable of the SKILL.md change in this phase, and its entire
purpose is to get a stuck fleet unstuck, a recovery path that silently fails
to do what it claims is a correctness defect, not a style nit.

The `run-tests.sh` additions have a real, if currently dormant,
extraction-boundary bug in `extract_step_block`, and `test_migration_0010`
has two coverage gaps: it never executes the extracted Pre-flight block (the
exact code class 0007's bug lived in), and it never asserts the `<repo-name>`
placeholder resolution that migration 0010's own Post-checks section claims
is "ALWAYS true on success." Both are flagged as WARNING since they weaken
the "mutation-proven" claim made for this fixture rather than causing
incorrect runtime behavior today.

## Structural Findings (fallow)

None provided for this review.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Stage D recovery text claims "0007 no longer selects" but Stage A's documented algorithm has no supersession rule that would make that true

**File:** `skills/update-codex-agenticapps-workflow/SKILL.md:45-51,95-102`
**Issue:**
Stage A step 4 defines pending-migration selection purely per-migration:

```
4. Compute pending migrations. ... select those whose `from_version` ≤
   project version AND `to_version` > project version.
```

For a project stuck at `0.4.0`, this predicate is independently satisfied by
**both** migration `0007` (`from_version: 0.4.0`, `to_version: 0.5.0`) and
migration `0010` (`from_version: 0.4.0`, `to_version: 0.5.0`) — see
`migrations/0007-knowledge-capture.md` and
`migrations/0010-heal-0007-knowledge-capture.md` frontmatter. Nothing in
Stage A (or anywhere else in this file) removes `0007` from the pending set
once `0010` exists to supersede it; there is no "skip a lower-id migration
when a higher-id migration shares the same `to_version`" rule documented
anywhere. Stage A then says: "sort by `id` ascending; this is the apply
order" — `0007` sorts before `0010`, so Stage D would attempt `0007` first
and hit its abort (`exit 3`) again, exactly the failure this whole migration
exists to heal.

The Recovery bullet at line 95 states as fact: "Re-run
`$update-codex-agenticapps-workflow` — the project's recorded version is
still `0.4.0`, so `0007` no longer selects and `0010` applies instead ...
This terminates". Nothing upstream in this document supports "0007 no longer
selects." As written, the documented algorithm would re-select `0007`, abort
on it again, and require the user to explicitly skip-with-warning `0007`
before `0010` is ever reached — a materially different (and undocumented)
recovery path than the one described.

**Fix:** Either (a) add an explicit supersession rule to Stage A step 4 —
e.g. "when two pending migrations share the same `to_version`, the
higher-id migration supersedes lower-id migrations targeting the same slot;
drop the superseded migration(s) from the apply order" — and cross-reference
it from the Recovery bullet, or (b) rewrite the Recovery bullet to describe
the actual mechanics (0007 will still be attempted and abort; the user must
skip-with-warning it, after which 0010 applies). Do not leave the claim
unsupported by the algorithm it depends on.

### CR-02: `--migration 0010` recovery instruction is not guaranteed to select 0010 once the project is already at exactly `0.5.0`

**File:** `skills/update-codex-agenticapps-workflow/SKILL.md:103-111,134`
**Issue:**
The second Recovery bullet instructs an operator whose
`.codex/workflow-version.txt` was hand-forced to `0.5.0` (to escape 0007's
abort) to run `$update-codex-agenticapps-workflow --migration 0010`. But:

- Stage A step 4's pending formula requires `to_version > project version`.
  For a project already at `0.5.0`, `0010`'s `to_version` (`0.5.0`) is
  **not** `> 0.5.0`, so `0010` is never computed as pending by Stage A's own
  algorithm.
- The Flags table (line 134) defines `--migration NNNN` as: "Apply only the
  named migration (**skip other pending**)" — i.e. a filter over the
  already-computed pending set, not an override of the eligibility formula.
- Stage A step 4 also says: "If none, log 'project is up-to-date at version
  X' and exit" — which is exactly what would happen if `--migration 0010`
  is applied on top of an empty pending set.

Following the documented instructions verbatim would therefore most likely
produce "project is up-to-date" and silently fail to deliver the payload —
the opposite of what the recovery bullet promises.

(This is the same root gap as CR-01 — no documented mechanism exists for a
migration to be force-applied for idempotent re-apply at its own
`to_version` boundary — but it manifests as a distinct broken user flow and
is called out separately since it affects a different operator scenario.)

**Fix:** Explicitly document that `--migration NNNN` bypasses the Stage A
`to_version > project version` boundary check (i.e. it also matches
`to_version == project version`, consistent with 0010's own pre-flight,
which "accept[s] the target version for idempotent re-apply" per
`migrations/0010-heal-0007-knowledge-capture.md:43-45`). Without that
override documented, the flag as currently specified cannot deliver the
recovery the runbook promises.

## Warnings

### WR-01: `extract_step_block`'s prefix-only boundary matching is unbounded and can mis-scope on documents with two-digit step numbers, or leak a step heading if a fence is left open

**File:** `migrations/run-tests.sh:123-146`
**Issue:**
```awk
index($0, stepp) == 1 { in_step=1; next }
index($0, nextp) == 1 { in_step=0 }
```
`stepp` for `step=1` is the literal string `"### Step 1"`. `index($0, stepp)
== 1` is a **prefix** test, not a whole-token test — a document line reading
`### Step 10: Title` also satisfies `index($0, "### Step 1") == 1`. If any
migration document ever grows past 9 steps, a call like
`extract_step_block "$doc" 1 Apply` would incorrectly treat the `### Step
10` heading as the start of "Step 1", corrupting the scan. This is dormant
today (no shipped migration exceeds 4 steps) but is exactly the class of
silent-wrong-extraction defect (D-36) the surrounding `assert_extracted_shape`
machinery was built to catch — except this particular failure mode produces
a *non-empty*, plausible-looking extraction, so `assert_extracted_shape`
would not flag it.

Separately: if a `### Step N` Apply fence is ever left unclosed before the
next `### Step N+1` heading (a malformed document), rule order lets the
`in_step=0` transition fall through into `inb { print }` for that same line,
because there is no `next`/`exit` on the `index($0, nextp) == 1` branch —
the next step's own heading line would leak into the extracted block instead
of the scan stopping cleanly.

**Fix:** Anchor the boundary matches to a full line/token, e.g. match on
`^### Step [0-9]+\b` and compare the captured number instead of doing a
prefix `index()` compare against an unbounded numeric string; or at minimum
require a non-digit character (`:`/`—`/space) immediately after `stepp` in
the match. Add an `exit`/early return on `index($0, nextp) == 1` so a
malformed document fails extraction cleanly instead of leaking a heading
line into the output.

### WR-02: `test_migration_0010` never executes the extracted Pre-flight block — the version-floor logic 0007's bug lived in is unverified by execution

**File:** `migrations/run-tests.sh:4834-4970` (contrast with `test_migration_0009` at `migrations/run-tests.sh:3619-3660,4367-4415,4711-4730`, which does execute `pf_block` via `_m0009_apply` against multiple fixtures)
**Issue:**
`test_migration_0010` extracts `pf_block` and gates it through
`assert_extracted_shape` (non-empty + contains `.codex/workflow-version.txt`)
and a D-07 substring check, but there is no call anywhere in the function
that actually `eval`s `pf_block` against a sandbox — neither to prove it
exits 0 for a `0.4.0`/`0.5.0` project, nor to prove it exits non-zero (aborts)
for, say, a `0.3.0` or `0.6.0` project. `test_migration_0009`'s suite, in the
very same file, does exactly this kind of execution-based validation for its
own Pre-flight block across several fixtures (conflict, corrupt-mirror,
no-scaffolder-tree cases).

Since migration 0010's entire reason for existing is a corrected
version-floor gate (`grep -qE '^0\.(4|5)\.0$' .codex/workflow-version.txt`),
and the fixture is described in this phase as "mutation-proven," a mutation
to that regex (e.g. `0\.(4|6)\.0`, or dropping the `-E`/escaping so it
stops anchoring correctly) would not be caught by anything in this test
suite — the mutation would survive.

**Fix:** Add at least two execution-based cases mirroring `_m0009_apply`'s
pattern: (1) `pf_block` executed against a project at `0.4.0` (and `0.5.0`)
exits 0; (2) `pf_block` executed against a project at, e.g., `0.3.0` and
`0.6.0` exits non-zero. This closes the gap between "the text looks right"
and "the logic behaves right," consistent with this file's own D-36
discipline elsewhere.

### WR-03: `test_migration_0010`'s D-06 assertions omit the `<repo-name>` placeholder-resolution check that migration 0010's own Post-checks claim is "ALWAYS true on success"

**File:** `migrations/run-tests.sh:4942-4959`; compare `migrations/0010-heal-0007-knowledge-capture.md:209-211`
**Issue:**
0010's own Post-checks section asserts:
```bash
# 1. Config block present, host-neutral, placeholder resolved (ALWAYS true on success)
jq -e '.knowledge_capture.enabled | type == "boolean"' .planning/config.json >/dev/null
! grep -qF '<repo-name>' .planning/config.json
```
`test_migration_0010`'s D-06 block only asserts
`.knowledge_capture.enabled == true`, the AGENTS.md section, and the
`0.5.0` version record (lines 4943-4959). It never asserts
`! grep -qF '<repo-name>' .planning/config.json` against the sandbox after
Steps 1-3 run. `test_migration_0007`'s own suite *does* assert exactly this
(`migrations/run-tests.sh:838-845`, "`<repo-name>` resolved in note path; no
placeholder left"), so the omission here is inconsistent with the sibling
migration's coverage for what is, per 0010's own doc, a verbatim
re-delivery of the same Step 1 payload.

**Fix:** Add an assertion in the D-06 block: after Steps 1-3 run against the
sandbox, assert `! grep -qF '<repo-name>' .planning/config.json` (and,
ideally, that `.knowledge_capture.note` ends with the sandbox's own repo
directory name), matching the coverage `test_migration_0007` already has for
the identical code path.

## Info

### IN-01: Inconsistent regex escaping between Pre-flight and Step 3's idempotency/post-check in migration 0010

**File:** `migrations/0010-heal-0007-knowledge-capture.md:84,190,218`
**Issue:** The Pre-flight correctly uses an escaped ERE:
`grep -qE '^0\.(4|5)\.0$'` (line 84). Step 3's Idempotency check
(`grep -q '^0.5.0$' .codex/workflow-version.txt 2>/dev/null`, line 190) and
the matching Post-check (line 218) use an unescaped `.` in a BRE, which
technically matches any character in that position (e.g. would also match a
corrupted value like `0X5X0`). In practice `.codex/workflow-version.txt`
only ever holds values this migration itself writes, so this is inert
today, and the same unescaped-dot idiom is copied verbatim from 0007/0008/
0009 — not unique to this migration.
**Fix:** Use `grep -qF '0.5.0'` (fixed-string) or escape the dots
(`grep -q '^0\.5\.0$'`) for exactness/consistency with the Pre-flight's own
style.

### IN-02: `_m0010_ok`/`_m0010_fail`/`_m0010_apply` duplicate `_m0009_ok`/`_m0009_fail`/`_m0009_apply` almost verbatim

**File:** `migrations/run-tests.sh:4803-4832` (compare `3577-3594`, `3573-3575`)
**Issue:** All three helper functions are near-identical copies with only
the prefix changed, continuing a pattern already present for 0009. The file
already centralizes several other cross-migration primitives
(`assert_extracted_shape`, `extract_preflight_block`, `extract_step_block`)
specifically to avoid this kind of drift-prone duplication.
**Fix:** Not urgent given the file's own documented rationale ("shell has no
function-local functions ... the prefix keeps them out of the shared
namespace"), but consider hoisting `_ok`/`_fail`/`_apply` (parameterized by
prefix or just made global, since they're identical) into the shared
`SHARED_LIB` primitives alongside `run_check`/`assert_check` the next time
this file is touched, rather than adding a fourth near-identical trio for a
future migration 0011.

### IN-03: Step 1's idempotency check treats a present-but-`null` `knowledge_capture` key as "not applied"

**File:** `migrations/0010-heal-0007-knowledge-capture.md:109`
**Issue:** `jq -e '.knowledge_capture' .planning/config.json` uses `jq -e`,
whose exit status is 1 (false) when the last output value is `null` — so if
`.knowledge_capture` were ever present but explicitly `null`, the
idempotency check would read "not applied" and Step 1 would re-run (safe,
but not truly idempotent-by-inspection for that edge case). This is
inherited verbatim from migration 0007 ("Re-delivers 0007's Step 1
verbatim") and is not a new defect introduced in this phase; noting for
awareness only.
**Fix:** None required given the deliberate verbatim-reuse contract; if
0007's Step 1 idiom is ever revisited, prefer
`jq -e '.knowledge_capture != null'` for a value-explicit check.

### IN-04: Documented recovery only covers an operator who forced the version to exactly `0.5.0`; further-forced projects have no documented path

**File:** `skills/update-codex-agenticapps-workflow/SKILL.md:103-111`
**Issue:** The recovery runbook's second bullet only addresses an operator
who force-escaped `0007`'s abort by setting the version to `0.5.0`. Nothing
prevents an operator from having forced the version further (e.g. to `0.6.0`
or `0.7.0`) to also clear 0008's/0009's own floor checks; such a project
would carry none of 0007's/0010's payload but is below `0010`'s pre-flight
floor (`0.4.0`/`0.5.0` only per
`migrations/0010-heal-0007-knowledge-capture.md:84`), so it has no
documented recovery route at all.
**Fix:** Either explicitly scope the runbook ("recovery is only supported
for projects at exactly `0.4.0` or `0.5.0`; a project force-advanced further
is out of scope and requires manual intervention") or add a recovery bullet
for that case.

---

_Reviewed: 2026-07-16T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
