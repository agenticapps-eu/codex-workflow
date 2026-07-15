---
phase: 08-plan-review-gate
reviewed: 2026-07-15T00:00:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - skills/agentic-apps-workflow/scripts/check-plan-review.sh
  - migrations/run-tests.sh
  - migrations/0008-plan-review-gate.md
  - skills/codex-plan-review/SKILL.md
  - docs/decisions/0009-plan-review-gate.md
  - docs/decisions/README.md
  - skills/agentic-apps-workflow/SKILL.md
  - skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md
  - skills/setup-codex-agenticapps-workflow/templates/config-hooks.json
  - .planning/config.codex.json
  - AGENTS.md
  - CHANGELOG.md
  - .codex/workflow-version.txt
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

# Phase 08: Code Review Report

**Reviewed:** 2026-07-15T00:00:00Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Reviewed the plan-review pre-execution gate: the verifier
(`check-plan-review.sh`), its test harness, migration `0008`, the
`codex-plan-review` producer skill, ADR-0009, and the declarative/ritual
wiring. All findings below were **actually executed and traced** against the
real script in a scratch sandbox (not merely read), except CR/WR findings
explicitly marked "code-inspection only." The resolver, containment checks,
symlink-before-regular-file ordering, ambiguous-artifact handling, and the
`--file` `..`-rejection all behaved exactly as documented and as `run-tests.sh`
asserts (260 PASS / 1 SKIP / 0 FAIL confirmed by re-running the suite).

One **Critical** fail-open bug was found and verified by direct execution: the
frontmatter-vs-fallback branch decision uses byte-exact string comparison on
the opening `---` delimiter, so a REVIEWS.md with CRLF line endings or a
trailing space on that one line is silently treated as "no frontmatter,"
bypassing the `>=2` distinct-reviewer check and the `plans_reviewed` coverage
check entirely — a file with only 1 reviewer (or the reviewer's own name
being self-referential) can pass with just 5 total lines. This is exactly the
"gate silently fails open" failure class the review was asked to prioritize,
and the test suite has no coverage for it (I confirmed via grep of
`run-tests.sh`).

Three Warnings and one Info round out the report — spoofable reviewer
identity (any two distinct strings satisfy `reviewers:`, including `codex`
itself, which D-15 explicitly excludes as self-review), a code-inspection-only
concern about migration 0008 Step 3's table-edit pattern not being scoped to
the specific validated table, a code-inspection-only concern about the
`--file` bypass's traversal guard not covering symlinked directory
components, and a documentation-accuracy nit in the declarative config's
`fires_when` text.

## Critical Issues

### CR-01: Frontmatter detection uses byte-exact `---` match — CRLF or a trailing space silently downgrades a structured review to the spoofable fallback, bypassing the `>=2` reviewer check entirely

**File:** `skills/agentic-apps-workflow/scripts/check-plan-review.sh:539`
**Traced:** yes — executed directly against the real script in a sandbox repo.

**Issue:** The frontmatter-vs-fallback decision is:

```bash
_cpr_fm_first_line="$(head -n 1 "$REVIEWS" 2>/dev/null || true)"
if [ "${_cpr_fm_first_line:-}" = "---" ]; then
  # strict path: parse reviewers:, require >=2 distinct, check plans_reviewed
else
  # D-13 fallback: >=5 non-empty-file lines, no reviewer check at all
fi
```

The comparison is a byte-exact string equality test. D-13's fallback is meant
to apply only when frontmatter is "entirely absent" (a hand-written file with
no `---` block at all). But the exact-match test also silently takes the
fallback branch for a file that clearly *intends* to carry frontmatter —
`reviewers:`, `plans_reviewed:`, a closing `---` — merely because the first
line is `"--- "` (trailing space) or `"---\r"` (CRLF line endings, e.g. a file
authored/edited on Windows or by a tool that emits CRLF). In both cases the
strict reviewer-count and `plans_reviewed`-coverage checks never run, and the
file only has to clear the `>=5`-line bar — which has nothing to do with
reviewer count at all.

**Verified reproduction** (executed against the real script, not merely
read):

```
$ printf -- '--- \nphase: 9\nreviewers: [solo]\nplans_reviewed: []\n---\nbody\n' > 09-REVIEWS.md
$ bash check-plan-review.sh
exit=0          # ONE reviewer ("solo"), passes anyway
```

```
$ printf -- '---\r\nphase: 9\r\nreviewers: [solo]\r\nplans_reviewed: []\r\n---\r\nbody line\r\n' > 09-REVIEWS.md
$ bash check-plan-review.sh
exit=0          # same bug via CRLF line endings
```

For comparison, a closing-delimiter defect (`--- ` with a trailing space) is
correctly caught as MALFORMED and blocks — the bug is specifically in the
*opening*-line detection, not the parser as a whole.

This is a real fail-open: any REVIEWS.md with a one-character typo or the
"wrong" line-ending convention on its very first line collapses the entire
gate down to a 5-non-empty-line check, silently discarding the requirement
that motivates this whole phase (>=2 independent external reviewers). I
confirmed `run-tests.sh` has no CRLF or trailing-whitespace test case for this
path (`grep` for those terms against the enforcement test block returned
nothing), so this gap is not caught by the existing 260-assertion suite.

**Fix:** Match the delimiter with a tolerant regex instead of exact equality,
e.g.:

```bash
if printf '%s' "${_cpr_fm_first_line:-}" | grep -qE '^---[[:space:]]*\r?$'; then
```

or normalize trailing `\r`/whitespace before comparing:

```bash
_cpr_fm_first_line="$(head -n 1 "$REVIEWS" 2>/dev/null | tr -d '\r' | sed -e 's/[[:space:]]*$//' || true)"
if [ "${_cpr_fm_first_line:-}" = "---" ]; then
```

Apply the same normalization to the closing-delimiter search (`awk '... $0
== "---" ...'`) for consistency, and add both a trailing-space and a CRLF
fixture to `test_check_plan_review_enforcement` so this class of bug cannot
regress silently again.

## Warnings

### WR-01: `reviewers:` distinctness check has no vendor allowlist — any two distinct strings pass, including `codex` itself (which D-15 explicitly excludes)

**File:** `skills/agentic-apps-workflow/scripts/check-plan-review.sh:550-561`
**Traced:** yes — executed directly.

**Issue:** D-15 requires "vendor-diverse external CLIs (`claude`, `gemini`,
`opencode`); require >=2... Exclude `codex` — the implementing host
self-skips." The verifier, however, only counts *distinct normalized
strings* in `reviewers:` — it never checks membership in a known-vendor set,
and never rejects `codex` as a reviewer name. Verified:

```
$ cat > 09-REVIEWS.md <<'EOF'
---
phase: 9
reviewers: [alice, bob]
plans_reviewed: [09-01-PLAN.md]
---
body
EOF
$ bash check-plan-review.sh
exit=0     # passes with two names that are not any real reviewer CLI

$ cat > 09-REVIEWS.md <<'EOF'
---
reviewers: [codex, codex-self]
plans_reviewed: [09-01-PLAN.md]
---
body
EOF
$ bash check-plan-review.sh
exit=0     # passes even though "codex" is the self-review D-15 forbids
```

I recognize this sits close to the already-accepted trust boundary the ADR
names elsewhere (decision 10/11: the marker-file hatch and the `>=5`-line
fallback are both openly "spoofable by a lying operator," and the whole gate
is agent-mediated, not cryptographically enforced). But those limitations are
explicitly named and accepted in ADR-0009; this specific gap — that the
"strict," supposedly-authoritative frontmatter path enforces *count* but not
*identity*, and does not even exclude the literal string `codex` — is not
called out anywhere in the ADR, CONTEXT, or SUMMARYs I read. Given the entire
purpose of the gate is vendor-diverse review, a verifier that accepts any two
arbitrary tokens (or two `codex`-derived tokens) as satisfying "external
review" is worth naming explicitly rather than leaving implicit.

**Fix:** Either (a) validate normalized reviewer entries against the known
vendor set (`claude`, `gemini`, `opencode`) and reject `codex`/unrecognized
names, with a documented escape valve for future vendors, or (b) if arbitrary
names are intentionally accepted (e.g., to allow other future hosts), record
that decision explicitly in ADR-0009 the way decision 11 records the
`>=5`-line fallback's spoofability, so a future reader doesn't mistake silence
for an oversight.

### WR-02: Migration 0008 Step 3's table-edit pattern is not scoped to the header it validated — an earlier `|---` table anywhere in AGENTS.md would be silently corrupted instead of the bindings table

**File:** `migrations/0008-plan-review-gate.md:287-297` (mirrored in
`migrations/run-tests.sh:1143-1153`)
**Traced:** code-inspection only — I could not construct a failing case
against this repo's own `AGENTS.md` (its bindings table happens to be the
first `|---` line in the file) or against the shipped test fixture (which is
a standalone table-only file with no preceding content), so this is
*suspected*, not executed against a failing repro.

**Issue:** Step 3's shape guard validates that a line matching `^| Gate |`
exists in the target `AGENTS.md` and that its text matches the template's
header — but it never records *which line number* that header lives at. The
subsequent `awk` correction pass then operates on the **first** `^\|---`
line found anywhere in the whole file:

```awk
/^\|---/ && !ins_pr { print; print pr; ins_pr=1; next }
```

If a target `AGENTS.md` — assembled by "root-down concatenation" from
multiple skills' template additions, as the repo's own docs describe — has
*any other* Markdown table with a `|---|...|` separator positioned before the
bindings table (e.g., from an unrelated skill's own additions section), this
pass will insert the `plan-review` row into that unrelated table instead of
the bindings table, leave the real bindings table untouched (still missing
`plan-review`, still 15 rows), and the migration will still report success.
Worse, the Step 3 idempotency check (`grep -q '^| plan-review' AGENTS.md`)
would then find the erroneously-inserted row on any future re-run and treat
the step as already applied — permanently masking the fact that the actual
bindings table was never corrected, while a `git diff` would additionally
show a foreign table now carrying a nonsensical extra row.

Neither this repo's own `AGENTS.md` nor `test_migration_0008`'s Step-3
fixture (`$tmp/AGENTS.md.scope-shaped`, a standalone file that *starts* with
the table itself, no preceding content) exercises this shape, so the existing
test suite would not catch a regression here or validate the fix.

**Fix:** Correlate the header match with the separator line explicitly —
e.g., capture the header's line number and confine the awk pass to a range
starting at that line, or match on the specific two-line sequence (header
line immediately followed by its separator) rather than any bare `|---|`
found first in the document. Add a fixture to `test_migration_0008` that
prepends an unrelated `|---|`-separated table before the bindings table and
asserts the correction lands in the *right* table.

### WR-03: `--file` bypass's traversal guard rejects literal `..` path components only, not symlinked directories that resolve outside `.planning/` without ever containing `..`

**File:** `skills/agentic-apps-workflow/scripts/check-plan-review.sh:84-118`
**Traced:** yes, partially — executed directly (confirmed the bypass fires
for a symlinked path component); the practical severity is bounded because
the whole gate is agent-mediated advisory text, not a kernel-level file-write
interceptor (per ADR-0009 decision 9), so I am not escalating this to
Critical.

**Issue:** The comment block above the bypass explicitly scopes its claim to
`..`-component rejection ("reject on the '..' component itself"), and the
plan's own SUMMARY only claims the bypass is "traversal-safe," not
"symlink-safe" (unlike the REVIEWS.md evidence check, which explicitly adds a
`[ -L ]` guard for exactly this reason). Verified that a pre-existing
symlinked directory component inside `.planning/phases/<phase>/` that points
outside the tree, with no `..` segment anywhere in the literal `--file`
string, still satisfies the prefix+basename bypass:

```
$ ln -s /tmp/outside .planning/phases/09-test-phase/evil-link
$ bash check-plan-review.sh --file ".planning/phases/09-test-phase/evil-link/some-PLAN.md"
exit=0     # bypass fires; textual path looks like a legitimate plan file
```

Because `_canon_dir` deliberately isn't used here (the file may not exist
yet, so it can't be `cd`'d into), there is no straightforward way to
canonicalize-and-contain the way the resolver does for `.planning/current-phase`.
Given the whole verifier is advisory (an agent chooses to invoke it and
chooses to honor its exit code), the practical blast radius of this gap is
smaller than CR-01, but it's still a real, if narrow, gap in the "traversal-safe"
claim, and worth closing or explicitly documenting as a known limitation the
way WR-01's spoofability equivalents are documented elsewhere in ADR-0009.

**Fix:** Reject any `--file` value containing a path component that is itself
a symlink (testable without requiring the leaf to exist, by walking and
`[ -L ]`-testing each existing prefix directory component), or explicitly
document in the script's own comment block and ADR-0009 that the traversal
guard covers lexical `..` only, not symlinked-directory escapes, mirroring
how decision 11 documents the `>=5`-line fallback's known weakness.

## Info

### IN-01: Declarative `fires_when` text in the gate binding omits the REVIEWS.md-evidence condition that actually drives the block

**File:** `.planning/config.codex.json:10` (identical text in
`skills/setup-codex-agenticapps-workflow/templates/config-hooks.json:10`)

**Issue:** The new `pre_execution.plan_review` binding describes its trigger
as:

```json
"fires_when": "phase has >=1 *-PLAN.md AND no *-SUMMARY.md exists"
```

This is the condition under which `check-plan-review.sh` reaches the
REVIEWS.md evidence check at all — but it is not the condition under which
the gate actually blocks. The real block condition additionally requires that
no valid `*-REVIEWS.md` (with `>=2` distinct reviewers and full
`plans_reviewed` coverage) exists in the phase directory. A reader who trusts
this one-line summary (e.g., another agent scanning the declarative config
without reading the verifier script) would reasonably conclude the gate
fires on every plans-without-summary phase, when in fact a phase with a valid
REVIEWS.md sails through silently. This is purely descriptive text with no
functional effect, so it's Info rather than Warning, but it's new text
introduced by this phase and worth tightening for future readers.

**Fix:** Extend the description, e.g. `"fires_when": "phase has >=1
*-PLAN.md AND no *-SUMMARY.md exists AND no valid <NN>-REVIEWS.md (>=2
distinct reviewers, full plans_reviewed coverage) exists"`.

---

_Reviewed: 2026-07-15T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
