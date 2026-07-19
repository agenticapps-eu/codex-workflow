# Phase 12: Path Safety & Review Debt - Pattern Map

**Mapped:** 2026-07-17
**Files analyzed:** 5 (all modified-in-place; no new source files this phase)
**Analogs found:** 5 / 5 (all analogs are regions within the same files being
modified, or their existing sibling test suites — this is an in-place-repair
phase, not a greenfield one)

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` (WR-03 guard augmentation) | middleware (path-safety guard) | request-response (CLI exit-code verdict) | same file: `_canon_dir`/`_is_contained` (`:133-146`) + their reuse at `:270-272` | exact — reuse, not new pattern |
| `migrations/validate-0009-anchor.sh` (REV-01 determinism, REV-03 line-drop assertion) | test/validator (standalone harness) | batch (replay + assert) | same file: CASE 2 / COUNTER-CASE A/B assertion shape (`:266-363`) | exact |
| `migrations/run-tests.sh` (REV-02 delimiter fix + new WR-03/REV fixture registration) | test (in-process suite) | batch (assertion harness) | same file: `test_check_plan_review_enforcement`'s T-08-01/T-08-37/T-08-36 fixtures (`:2446-2497`, `:3022-3129`) | exact |
| `docs/decisions/0009-plan-review-gate.md` (D-08/D-09 in-place marker) | config/doc (ADR record) | transform (append marker to existing decision text) | same file: decision 11's superseded-marker precedent pattern (search decision 11 body) + decision 12 body (`:366-398`) and Open-follow-up entry (`:435-442`) | exact |
| `docs/decisions/README.md` (REV-04 numbering convention) | config/doc (index + convention) | transform (add subsection) | same file: Index table (`:14-27`) — ADR-0010 documents migration 0009, the worked example | exact |

## Pattern Assignments

### `skills/agentic-apps-workflow/scripts/check-plan-review.sh` (middleware, request-response)

**Analog:** itself — `_canon_dir`/`_is_contained` (`:133-146`) and their existing
reuse at the current-phase pointer resolver (`:262-277`).

**The exact helpers WR-03 MUST reuse (do not reinvent, SC#1)** (`:129-146`):
```bash
# Portable directory canonicalization. `realpath -m` is absent on stock
# macOS; `readlink -f` differs between BSD and GNU. This subshell cd + pwd -P
# idiom resolves symlinks and `..` traversal and prints nothing on a
# non-existent or unreadable path, everywhere.
_canon_dir() { ( cd "${1:-}" 2>/dev/null && pwd -P ); }

# Separator-aware containment test: cand must equal root, or be root plus a
# path separator plus more — so ".planning/phases-evil" cannot pass as a
# child of ".planning/phases" (T-08-01).
_is_contained() {
  local cand="${1:-}" root="${2:-}"
  [ -n "$cand" ] && [ -n "$root" ] || return 1
  [ "$cand" = "$root" ] && return 0
  case "${cand}/" in
    "${root}/"*) return 0 ;;
    *) return 1 ;;
  esac
}
```

**Their existing reuse — the exact idiom to replicate for `--file`'s parent
dir** (`:258-277`, the explicit-pointer resolver step):
```bash
p="$(readlink .planning/current-phase 2>/dev/null || true)"
if [ -n "${p:-}" ]; then
  pdir=""
  if [ -d "$p" ]; then
    pdir="$p"
  elif [ -d ".planning/$p" ]; then
    pdir=".planning/$p"
  fi
  if [ -n "$pdir" ]; then
    canon_p="$(_canon_dir "$pdir")"
    canon_root="$(_canon_dir ".planning/phases")"
    if _is_contained "$canon_p" "$canon_root"; then
      echo "$pdir"
      return 0
    fi
  fi
fi
```
WR-03's shape is the same three-line skeleton: `_canon_dir` the `--file`
value's **parent directory** (`dirname "$CPR_FILE"`, not the file itself —
`_canon_dir` `cd`'s and the leaf may not exist yet, D-02), `_canon_dir` the
allowed root (`$REPO_ROOT/.planning`, D-05, only reachable after the D-04
hoist below), then gate on `_is_contained`. Per D-02, an empty `canon_p`
(non-existent/uncanonicalizable parent) must **fall through** to the existing
lexical `..` check / normal resolution — never `exit 2` here.

**The lexical `..` check being augmented, NOT replaced (D-01)** (`:84-118`):
```bash
if [ -n "$CPR_FILE" ]; then
  _cpr_has_dotdot=0
  IFS='/' read -ra _cpr_file_parts <<< "$CPR_FILE"
  for _cpr_file_part in "${_cpr_file_parts[@]}"; do
    if [ "$_cpr_file_part" = ".." ]; then
      _cpr_has_dotdot=1
      break
    fi
  done

  if [ "$_cpr_has_dotdot" -eq 0 ]; then
    case "$CPR_FILE" in
      .planning/*|*/.planning/*)
        case "$(basename "$CPR_FILE")" in
          *PLAN.md|*PLAN-*.md|*REVIEW[S].md|ROADMAP.md|PROJECT.md|REQUIREMENTS.md|*CONTEXT.md|*RESEARCH.md)
            exit 0
            ;;
        esac
        ;;
    esac
  fi
fi
```
Keep this block's structure intact. The new canonicalization+containment
check is an **additional gate inserted after** `_cpr_has_dotdot -eq 0` and
before (or alongside) the `case` prefix test — both must pass for `exit 0` to
fire. D-05 also **tightens** the prefix arm: `_is_contained` against
`$REPO_ROOT/.planning` only — a `vendor/foo/.planning/X-PLAN.md` match on the
old lexical `*/.planning/*` arm no longer bypasses. Flag this in the phase
SUMMARY per D-05.

**Repo-root self-location block being hoisted (D-04)** (`:167-190`, currently
runs AFTER the bypass at `:84` — move it to just after the `GSD_SKIP_REVIEWS`
hatch, before the bypass block):
```bash
REPO_ROOT=""
_cpr_git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "${_cpr_git_root:-}" ]; then
  REPO_ROOT="$_cpr_git_root"
else
  _cpr_walk="$(pwd -P 2>/dev/null || true)"
  while [ -n "${_cpr_walk:-}" ]; do
    if [ -d "${_cpr_walk}/.planning" ]; then
      REPO_ROOT="$_cpr_walk"
      break
    fi
    [ "$_cpr_walk" = "/" ] && break
    _cpr_walk="$(dirname "$_cpr_walk")"
  done
fi

if [ -z "${REPO_ROOT:-}" ]; then
  _debug "repo-root: <unresolved> (not a git tree, no .planning ancestor)"
  exit 0
fi

cd "$REPO_ROOT" 2>/dev/null || exit 0
```
Re-verify T-08-* ordering assertions still pass after the reorder: the
`GSD_SKIP_REVIEWS` hatch (`:65-68`) stays first; `_canon_dir`/`_is_contained`
also need `$REPO_ROOT` defined and `cd`'d-into before they run, which is
exactly why this block must move above the bypass, not just above the
resolver.

**The guard NOT to copy for `--file` — REVIEWS.md's deliberately-asymmetric
reject-any-symlink rule (D-03 contrast)** (`:459-472`):
```bash
# Symlink guard FIRST (<ordering> step 7a; T-08-36) -- [ -L ] is the only
# test that does NOT dereference. ...
# Reject symlinks outright rather than
# canonicalizing-and-containing: an evidence artifact has no legitimate
# reason to indirect (deliberate asymmetry with plan 08-01's current-phase
# pointer, which IS legitimately a symlink and IS canonicalized-and-
# contained -- a pointer is MEANT to indirect; an evidence artifact is not).
if [ -L "$REVIEWS" ]; then
  _cpr_block "the review artifact $REVIEWS is a symlink -- symlinked evidence is treated as missing, never canonicalized-and-contained"
fi
```
This is a **reject-any-symlink** rule — the opposite policy from WR-03. D-03
is explicit: a `--file` edit target legitimately may sit behind a symlinked
parent (e.g. a worktree symlink), so WR-03 must **resolve-then-contain**
(the current-phase-pointer idiom above), never reject any symlink outright.
Do not let this REVIEWS.md idiom leak into the `--file` guard.

---

### `migrations/validate-0009-anchor.sh` (test/validator, batch)

**Analog:** itself — the existing CASE 2 / COUNTER-CASE A / COUNTER-CASE B
assertion shape (`:266-363`), which is this repo's local mutation-proof
idiom: assert the WRONG rule fails, and assert the RIGHT rule passes, over
the same fixture, so a PASS can never be dead-by-construction.

**REV-01 — remove (not reword) the mirror-derived stdout values (D-11).**
Banner (`:241`):
```bash
echo "Mirror:          skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md ($(wc -l < "$MIRROR" | tr -d ' ') lines)"
```
Remove the `$(wc -l < "$MIRROR" ...)` clause entirely — the line count is not
determinism-safe (this repo's mirror has already been re-vendored 75→79
lines once, per D-11). CASE 2's PASS text (`:292`) similarly embeds
mirror-derived line numbers computed at `:275-279`:
```bash
c2_prov="$(line_of_sub "$tmp/case2-healed.md" "$PROV")"
c2_start="$(line_of_exact "$tmp/case2-healed.md" '<!-- gitnexus:start -->')"
...
pass "CASE 2 ABOVE REGION — provenance at line $c2_prov is above gitnexus:start at line $c2_start; region intact and paired (start=$c2_start_n end=$c2_end_n), body at line $c2_body"
```
`$c2_start`'s numeric value shifts with the mirror's line count (the insert
prints the mirror body before the matched heading line), which is exactly
the non-deterministic value REV-01/SC#2 targets. Per D-11 fix-option (a):
strip the numeric line references from the PASS message text — keep the
relational assertions (`$c2_prov -ge $c2_start` etc., which are fine, they
compare, not print, mirror-dependent numbers) but do not echo the derived
line numbers into stdout. Proof: a full-script `grep` asserting no
mirror-derived value (banner count, CASE 2 line numbers) survives in stdout,
mutation-proven (reintroduce a `$(wc -l ...)`-style value → RED; remove →
GREEN) — this grep-based proof itself belongs in `run-tests.sh` (see below),
not inside `validate-0009-anchor.sh`.

**REV-03 — CASE 1's line-drop assertion (D-13), the exact insertion point**
(`:249-264`, between strip and insert):
```bash
if [ ! -s "$REPO_ROOT/AGENTS.md" ]; then
  fail "CASE 1 ZERO CHURN — AGENTS.md missing or empty; replay input unavailable"
else
  cp "$REPO_ROOT/AGENTS.md" "$tmp/case1-input.md"
  candidate_strip "$tmp/case1-input.md" > "$tmp/case1.strip"
  # <-- INSERT THE NEW ASSERTION HERE, between strip and insert:
  #     [ "$(wc -l < "$tmp/case1.strip")" -lt "$(wc -l < "$tmp/case1-input.md")" ]
  #     — strictly-smaller-count, NO hardcoded line number (not 313→232).
  candidate_insert "$tmp/case1.strip" > "$tmp/case1.out"

  if [ ! -s "$tmp/case1.strip" ] || [ ! -s "$tmp/case1.out" ]; then
    fail "CASE 1 ZERO CHURN — replay produced empty output (strip or insert failed)"
  elif diff -u "$tmp/case1-input.md" "$tmp/case1.out" > "$tmp/case1.diff" 2>&1; then
    pass "CASE 1 ZERO CHURN — candidate rule re-derives §11's current position byte-identically"
  else
    fail "CASE 1 ZERO CHURN — replay churned the real AGENTS.md; diff follows"
    sed 's/^/      /' "$tmp/case1.diff"
  fi
fi
```
Use this file's own `pass`/`fail` helpers (`:52-53`) and the existing
non-empty-then-`diff` chaining style as the template — add a `pass`/`fail`
call for the new line-drop assertion using the same `[ ... ] && pass ... ||
fail ...` idiom already used throughout CASE 2 / COUNTER-CASE A/B
(`:281-293`, `:310-318`).

**Mutation-proof idiom, verbatim example to replicate for the REV-03
assertion** — COUNTER-CASE B (`:328-363`), the wrong-rule-must-fail /
right-rule-must-pass pairing:
```bash
# B.1 — the narrow terminator must eat the region.
narrow_strip "$tmp/case2-healed.md" > "$tmp/counterB-narrow.md"
...
if [ ! -s "$tmp/counterB-narrow.md" ]; then
  fail "..."
elif [ "$nb_start_n" = "0" ] && [ "$nb_end_n" = "1" ] && [ -z "$nb_body" ]; then
  pass "COUNTER-CASE B (counter) NARROW TERMINATOR EATS REGION — ..."
else
  fail "... The narrow rule behaved correctly, so D-24's alternation is not shown to be load-bearing and the WIDENED assertion below is dead-by-construction."
fi

# B.2 — the widened terminator (the candidate) must preserve it.
candidate_strip "$tmp/case2-healed.md" > "$tmp/counterB-widened.md"
...
```
For REV-03: manually verify by breaking the drop (temporarily reintroduce
the mirror-derived-value bug, or comment out the new assertion / substitute
a tautology) → confirm RED, then restore → confirm GREEN. This is a
verification *process* step (run the harness twice), not a second
counter-case function to ship — `validate-0009-anchor.sh` is a standalone
script re-run manually, unlike `run-tests.sh`'s in-process counters.

---

### `migrations/run-tests.sh` (test, batch — the harness all new fixtures register in)

**Analog:** the existing `check-plan-review.sh` suite's T-08-01 (path-safety)
and T-08-37 (bypass list) fixtures inside `test_check_plan_review_enforcement`
/ `test_check_plan_review_resolver` — the closest existing symlink-escape and
`--file`-bypass fixtures respectively, and the template for the two new
WR-03 fixtures (symlinked-parent, sibling-prefix-collision).

**Harness invocation helpers already defined at file scope — reuse, do not
reinvent** (`:1991-2066`):
```bash
_cpr_case() {
  local label sandbox expected rc err own_err
  label="${1:-}"; sandbox="${2:-}"; expected="${3:-}"; shift 3
  err=""
  own_err=0
  if [ "${1:-}" = "--err-out" ]; then
    err="${2:-}"; shift 2
  fi
  [ "${1:-}" = "--" ] && shift
  if [ -z "$err" ]; then
    err="$(mktemp)"
    own_err=1
  fi
  ( cd "$sandbox" && bash "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" "$@" ) >/dev/null 2>"$err"
  rc=$?
  if [ "$rc" = "$expected" ]; then
    echo "  ${GREEN}PASS${RESET} $label (exit=$rc)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $label (expected exit=$expected, got exit=$rc)"
    FAIL=$((FAIL+1))
  fi
  if [ "$own_err" = "1" ]; then
    rm -f "$err"
  fi
}

_cpr_check_contains() {
  local label errfile needle
  label="${1:-}"; errfile="${2:-}"; needle="${3:-}"
  if grep -qF -- "$needle" "$errfile" 2>/dev/null; then
    echo "  ${GREEN}PASS${RESET} $label"
    PASS=$((PASS+1))
  ...
}
```

**Existing symlink-escape fixture — direct template for the WR-03
symlinked-parent case** (`:2446-2465`, T-08-01, resolver suite):
```bash
# ── Path safety (threat T-08-01) ─────────────────────────────────────────────

s="$tmp/escape-sibling"
mkdir -p "$s/.planning/phases" "$s/scratch-outside"
touch "$s/scratch-outside/PLAN.md"
ln -s "$s/scratch-outside" "$s/.planning/current-phase"
_cpr_case_and_absent "path-safety: pointer to a sibling dir OUTSIDE .planning/phases is rejected, falls through" "$s" 0 "scratch-outside"

escdir="${tmp}-escape"
mkdir -p "$escdir"
touch "$escdir/PLAN.md"
s="$tmp/escape-tmp"
mkdir -p "$s/.planning/phases"
ln -s "$escdir" "$s/.planning/current-phase"
_cpr_case_and_absent "path-safety: pointer to a /tmp-rooted escape target (derived from sandbox mktemp) is rejected" "$s" 0 "$escdir"
```
The new WR-03 **symlinked-parent** fixture follows this exact shape but
targets `--file` instead of `current-phase`: create
`.planning/phases/<name>/evil-link -> $outsidedir` (mirroring ADR-0009
decision 12's own live repro command,
`ln -s /tmp/outside .planning/phases/09-test-phase/evil-link`), then
`_cpr_case "... --file .planning/phases/<name>/evil-link/some-PLAN.md -> exit 2 (symlinked parent resolves outside the tree)" "$s" 2 --file "..."`.
Assert the OLD guard's `exit 0` behavior (fail-open) is what's being fixed —
consider a paired before/after note in the PLAN, or run the fixture against
a stashed pre-fix copy to observe RED, matching this repo's RED-before-GREEN
convention.

**Existing `--file` bypass-list fixtures — template for ordering/shape,
including the exit-0-on-legitimate-artifact and exit-2-on-traversal cases**
(`:3022-3043`, T-08-08/T-08-37):
```bash
# ── --file bypass list (T-08-08, T-08-37) ───────────────────────────────────

s="$tmp/bypass-plan"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-plan")"
_cpr_case "bypass: --file .planning/.../08-01-PLAN.md -> exit 0 (canonical GSD artifact)" "$s" 0 --file ".planning/phases/08-bypass-plan/08-01-PLAN.md"

s="$tmp/bypass-nonplanning"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-nonplanning")"
_cpr_case "bypass: --file docs/IMPLEMENTATION-PLAN.md -> exit 2 (basename matches but NOT .planning/-rooted)" "$s" 2 --file "docs/IMPLEMENTATION-PLAN.md"
```
The new **sibling-prefix-collision** fixture (D-05's tightening — a
`vendor/foo/.planning/X-PLAN.md`-shaped path that used to satisfy the old
`*/.planning/*` lexical arm) belongs in this same block, immediately after
the existing traversal cases (`:3030-3037`), asserting `exit 2` under the
new `$REPO_ROOT/.planning`-only containment (where the old code would have
returned `exit 0`) — this is the disclosed behavior change from D-05, so the
fixture's label should say so explicitly, mirroring the existing labels'
style of naming *why* (e.g. `"(basename matches but NOT .planning/-rooted)"`).

**`_cpr_enf_phase` sandbox builder — reuse for both new fixtures** (`:2483-2497`):
```bash
_cpr_enf_phase() {
  local root="$1" name="$2" phasedir p
  shift 2
  phasedir="$root/.planning/phases/$name"
  mkdir -p "$phasedir"
  if [ "$#" -eq 0 ]; then
    touch "$phasedir/08-01-PLAN.md"
  else
    for p in "$@"; do
      touch "$phasedir/$p"
    done
  fi
  ( cd "$root/.planning" && ln -sf "phases/$name" current-phase )
  echo "$phasedir"
}
```

**REV-02 — `extract_step_block` delimiter fix, exact target** (`:123-146`):
```bash
extract_step_block() {
  local doc="$1" step="$2" label="$3"
  local next_step=$((step + 1))
  awk -v stepp="### Step ${step}" \
      -v nextp="### Step ${next_step}" \
      -v lblp="**${label}:**" '
    index($0, stepp) == 1 { in_step=1; next }
    index($0, nextp) == 1 { in_step=0 }
    ...
  ' "$doc"
}
```
`index($0, stepp) == 1` is a **prefix** match: `stepp="### Step 1"` matches
both `### Step 1: <title>` (intended) and `### Step 10: <title>` /
`### Step 1` followed directly by more digits (unintended) — the exact IN-01
defect. D-12's fix: match on the step delimiter too — `### Step N:` and
`### Step N ` (colon or trailing space/EOL after the digit), not a bare
digit-string prefix. The header comment's own stated invariant
(`:80-90`, "Scope/label matching is by LITERAL PREFIX ... not by an
interpolated regex" and "`^### Step N` prefix matches BOTH this repo's
`### Step 1: <title>` (colon) and upstream's `### Step 1 — <title>` (dash)")
documents the two valid delimiters (`:` and ` —`/` -`) that the fix must
still match while excluding a bare numeric continuation like `0`. Preserve
the "literal prefix, never an interpolated regex" no-escaping property (the
comment's own stated design constraint) — do not swap to
`"/^" stepp "[:space:]/"` with raw interpolation; instead extend the
`index()`-based prefix test to require the character immediately after
`stepp` be one of the delimiter set (`:`, ` `, EOL), still via `substr`/
literal comparison, not a compiled regex built from unescaped input.

**Proof fixture — synthetic 10+-step document (D-12).** No existing fixture
builds a synthetic 10-step migration document; this is new fixture content,
but follow the same `printf`-into-`$tmp` idiom this harness uses everywhere
(see `test_migration_0001`'s and `_m0009_*`'s synthesis style, e.g.
`validate-0009-anchor.sh`'s `synth_region_led` at `:196-218` for the printf
block shape) — write `### Step 1: ...` through `### Step 10: ...` blocks in
one heredoc/printf sequence, then assert `extract_step_block(doc, 1, Apply)`
returns Step 1's content and does NOT contain Step 10's content — RED under
the old prefix match (`### Step 1` matches `### Step 10`'s header too),
GREEN under the fix.

**REV-01's stdout-determinism grep-based proof** (new assertion, add
adjacent to wherever `validate-0009-anchor.sh` is invoked/asserted-on from
`run-tests.sh`, if it is — check for an existing `test_migration_0009`-style
invocation of the validator script; if none exists yet, add one following
the `test_migration_NNNN` naming convention, e.g. a small
`test_validate_0009_anchor_determinism` that runs
`bash migrations/validate-0009-anchor.sh` and greps its full stdout for the
absence of any numeric line-count value tied to `$MIRROR`'s line count,
mutation-proven by temporarily reintroducing a `wc -l`-derived value and
confirming FAIL, then removing it and confirming PASS).

---

### `docs/decisions/0009-plan-review-gate.md` (config/doc, transform)

**Analog:** the file's own decision-12 body (`:366-398`) and the matching
Open-follow-up entry (`:428-442`) — this is an in-place edit, not a new
section. D-08 requires only a `**Reversed (Phase 12, WR-03):** …` marker
appended to decision 12, plus the Open-follow-up entry marked resolved — NOT
the dated Correction section (Phase 13's DOC-03).

**Decision 12's current text — the accepted limitation being reversed**
(`:366-398`):
```
12. **The `--file` bypass's traversal guard is lexical-`..`-only, not
    symlink-safe — a known, accepted, documented limitation (WR-03).**
    ...
    Canonicalize-and-contain, the pattern the resolver uses for
    `.planning/current-phase`, is not available at this call site: `_canon_dir`
    `cd`'s into a path and therefore requires it to exist, and `--file` may
    legitimately name a file about to be created. ...
    The concrete future fix — reject any
    `--file` value with a symlinked existing prefix component, testable by
    walking and `[ -L ]`-testing each existing prefix directory without
    requiring the leaf to exist — is carried in Open follow-ups below.
```
Per D-09, the marker must NOT just say "fixed" — it must correct the record:
the future fix as speculated here (walk-each-prefix-component, `[ -L ]`-test
each) is **not** what Phase 12 built. What shipped is parent-directory
canonicalization via `_canon_dir`/`pwd -P` (resolves symlinks anywhere in
the parent chain in one shot) + `_is_contained`. The in-place marker (append
after this decision's text, before "Deferred rather than fixed..." or as a
new paragraph) must name the actual mechanism, e.g.:
```
**Reversed (Phase 12, WR-03):** [date]. The guard now canonicalizes the
`--file` value's parent directory (`_canon_dir`, the `cd ... && pwd -P`
idiom) and rejects a symlink-resolved escape via `_is_contained` against
`$REPO_ROOT/.planning` — reusing, not reinventing, the same helpers the
current-phase resolver already used (this decision's own text above named
that reuse as unavailable; it is now the shipped mechanism). This is NOT the
walk-each-prefix-component fix speculated in the Open follow-up below (which
is now superseded/resolved, not merely satisfied) — parent-directory
canonicalization resolves symlinks anywhere in the parent chain in one shot
without walking each component individually. The lexical `..` check
(`:84-118`) is retained as a defensive floor for the not-yet-created-parent
case, not removed. NOTE: this also tightens the `*/.planning/*` bypass arm
to `$REPO_ROOT/.planning` only — a nested/vendored
`vendor/foo/.planning/X-PLAN.md` no longer bypasses (disclosed behavior
change, not a silent regression). The dated Correction section covering d.9
superseded + this reversal + the global-vs-per-project fix lands in Phase 13
(DOC-03).
```

**Open-follow-up entry to mark resolved** (`:435-442`):
```
- **WR-03's symlinked-prefix-component fix** (decision 12): reject any
  `--file` value with a symlinked existing prefix directory component, not
  only a literal `..` component. Testable without requiring the leaf to
  exist, by walking each existing prefix directory of the `--file` value
  and `[ -L ]`-testing it. Deferred, not fixed, in this gap-closure —
  decision 12 records why: the gate is agent-mediated, so this guard is
  hygiene against an accidental over-broad bypass, not a boundary against a
  hostile caller.
```
Mark this **Resolved (Phase 12)** in place — do not delete it (it is
historical record of what was originally speculated); a short trailing note
such as `**Resolved (Phase 12):** shipped as parent-directory
canonicalization, not the walk-each-prefix-component approach speculated
above — see decision 12's Reversed marker.` is sufficient, matching D-09's
"describe the mechanism actually shipped" requirement.

---

### `docs/decisions/README.md` (config/doc, transform)

**Analog:** the file's own Index table (`:14-27`) — supplies the worked
example (ADR-0010 documents migration 0009) directly, no external analog
needed.

**Full current file** (27 lines, already read in full — this is the base to
extend, not replace):
```markdown
# Architecture decision records

ADRs for `codex-workflow`. Numbered sequentially: `NNNN-slug.md`.

The shape follows the AgenticApps workflow's ADR convention —
status, date, context, decision, consequences, references.

When a `codex-database-sentinel-audit` finding is accepted rather
than fixed (in projects USING this scaffolder), the accepting ADR
uses the
[`adr-db-security-acceptance.md`](../../skills/setup-codex-agenticapps-workflow/templates/adr-db-security-acceptance.md)
template shape — risk owner, re-audit date, compensating controls.

## Index

| ADR | Title | Status |
|---|---|---|
...
| [0009](0009-plan-review-gate.md) | Bind the plan-review pre-execution gate on the Codex host | Accepted |
| [0010](0010-region-aware-spec-11-placement.md) | Anchor the §11 block above a leading GitNexus region | Accepted |
```
D-10's normative subsection goes after the intro paragraphs and before (or
after) `## Index`, e.g. `## Numbering convention`, stating: ADR-NNNN and
migration-NNNN are **independent sequences** (confirmed by
`ls migrations/*.md`: migration `0009` is
`0009-spec-11-region-aware-placement.md`, documented by **ADR-0010**, not
ADR-0009 — ADR-0009 is a different subject, `0009-plan-review-gate.md`);
always write `ADR-NNNN` or `migration NNNN`, never a bare `NNNN`. This
worked example is already fully present in this repo's own two numbered
series and needs no invented illustration.

---

## Shared Patterns

### The mutation-proof / RED-then-GREEN verification discipline
**Source:** `migrations/validate-0009-anchor.sh` COUNTER-CASE A/B
(`:296-363`) — wrong-rule-must-fail paired with right-rule-must-pass, over
the identical fixture, so a PASS is never dead-by-construction. Also stated
generally at `migrations/run-tests.sh:3483-3496` ("RED before GREEN...DO NOT
weaken these assertions...DO NOT add a skip guard").
**Apply to:** every new assertion in this phase (WR-03's two fixtures,
REV-01's determinism grep, REV-02's synthetic-10-step proof, REV-03's
line-drop assertion) — each must be independently demonstrated to catch its
own regression (temporarily break the fix → confirm the assertion goes RED
→ restore → confirm GREEN), and the phase verifier re-runs this cycle
independently rather than trusting the executor's claim (per CONTEXT.md
Claude's Discretion).

### Portable path canonicalization
**Source:** `skills/agentic-apps-workflow/scripts/check-plan-review.sh:133-146`
(`_canon_dir`, `_is_contained`).
**Apply to:** WR-03 only in this phase (the guard under repair). Do not
introduce a second path-safety primitive elsewhere (out of scope per
CONTEXT.md — no TOCTOU-defeating mechanism).

### `_cpr_*` sandbox/assertion helpers
**Source:** `migrations/run-tests.sh:1991-2066` (`_cpr_case`,
`_cpr_case_and_absent`, `_cpr_check_contains`, `_cpr_check_resolved`) and
`:2483-2497` (`_cpr_enf_phase`).
**Apply to:** all new WR-03 fixtures in `run-tests.sh` — reuse these
verbatim; do not write a second sandbox-building or exit-code-checking
helper (the file's own header comment at `:2471-2476` states this
explicitly for the 08-02 suite, and the same rule applies to phase 12's
additions).

### `printf`-into-`$tmp` fixture synthesis (no static fixture files)
**Source:** `migrations/validate-0009-anchor.sh:196-218` (`synth_region_led`)
and `migrations/run-tests.sh:3498-3505` (D-34, "FIXTURE IDIOM IS LOCKED").
**Apply to:** REV-02's synthetic 10+-step document and any other new
fixture content needed for REV-01/REV-03 proofs in `run-tests.sh`. Do not
introduce a `test-fixtures/<NN>/` directory-per-fixture layout — that
convention is explicitly rejected (`migrations/test-fixtures/README.md` §
"Why no static fixture files").

## No Analog Found

None — every file in this phase's scope is a modification to an existing
file, and each modification's closest analog is a region within that same
file (or its existing sibling test suite already covering the surrounding
guard/migration). There is no greenfield file in Phase 12.

## Metadata

**Analog search scope:**
`skills/agentic-apps-workflow/scripts/check-plan-review.sh`,
`migrations/validate-0009-anchor.sh`, `migrations/run-tests.sh`,
`docs/decisions/0009-plan-review-gate.md`, `docs/decisions/README.md`,
`migrations/README.md` (glanced, not quoted), `migrations/*.md` (`ls` only,
for the REV-04 worked example).
**Files scanned (read in full or targeted ranges):** 5 primary + 1 `ls`
listing for the numbering-collision confirmation.
**Pattern extraction date:** 2026-07-17
