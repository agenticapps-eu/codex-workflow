# Phase 9: Region-Aware §11 Placement - Pattern Map

**Mapped:** 2026-07-15
**Files analyzed:** 6 (1 new migration, 1 new ADR, 3 modified, 1 modified test-harness site)
**Analogs found:** 6 / 6 — CONTEXT.md already named the codex-workflow analogs; this document's
value-add is the concrete, quotable `claude-workflow` 0029 excerpts, the fixture-idiom
translation, and an enumerated terminator-alternation checklist.

This phase ships no application code — every file is a migration markdown document, a
shell test function, an ADR, or version-bump prose. "Role/data-flow" below is adapted to
that domain (migration = a 3-step state-machine script; fixture = synthesized before/after
shell state; ADR = decision record).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `migrations/0009-spec-11-region-aware-placement.md` | migration | file-I/O (strip+reinject state machine) | `migrations/0004-revendor-spec-11.md` (structure) + `../claude-workflow/migrations/0029-region-aware-spec-11-placement.md` (mechanics) | exact (mechanics), role-match (structure) |
| `migrations/run-tests.sh` → `test_migration_0009` (new fn) | test | batch (synthesized fixtures, document-sourced extraction) | `run-tests.sh::test_migration_0001` (idiom) + `../claude-workflow/…/common-verify.sh` (extractor to port) | role-match (idiom) / exact (extractor logic, layout rejected) |
| `migrations/run-tests.sh:118-134` (retire inlined awk) | test | transform | the document-sourced extraction idiom TEST-01 introduces (self-referential — same function being written) | exact |
| `docs/decisions/0010-region-aware-spec-11-placement.md` | config/doc (ADR) | — | `docs/decisions/0009-plan-review-gate.md` (shape) | exact |
| `CHANGELOG.md` | doc | — | `CHANGELOG.md` `## [0.6.0]` entry (this repo, own precedent) | exact |
| `skills/agentic-apps-workflow/SKILL.md` (`version:` bump) | config | — | v0.6.0 precedent (`sed`-style bump, drift-coupling contract) | exact |

## Pattern Assignments

### `migrations/0009-spec-11-region-aware-placement.md` (migration, file-I/O)

**Analogs:** structure from `migrations/0004-revendor-spec-11.md`; mechanics from
`../claude-workflow/migrations/0029-region-aware-spec-11-placement.md` (shipped code, not
the design doc — quote this directly, retargeting `CLAUDE.md` → `AGENTS.md` and the
`SKILL_FILE`/`SPEC_BLOCK` paths to this host's `${CODEX_HOME:-$HOME/.codex}` convention).

**Frontmatter pattern** — follow 0008's shape (D-40), not 0029's (0029 has no
`optional_for` key; this repo's convention includes it — see 0004's frontmatter above).
0004 frontmatter (`migrations/0004-revendor-spec-11.md:1-14`):
```yaml
---
id: 0004
slug: revendor-spec-11
title: Re-vendor §11 mirror byte-identical to current core (blank-line drift fix)
from_version: 0.2.0
to_version: 0.2.1
applies_to:
  - skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md
  - AGENTS.md
  - skills/agentic-apps-workflow/SKILL.md
  - .codex/workflow-version.txt
requires: []
optional_for: []
---
```
0009's frontmatter per D-40: `from_version: 0.6.0`, `to_version: 0.7.0`,
`applies_to: [AGENTS.md, skills/agentic-apps-workflow/SKILL.md, .codex/workflow-version.txt]`.

**Pre-flight pattern** — 0004's abort shape (`migrations/0004-revendor-spec-11.md:42-49`):
```bash
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }
test -f AGENTS.md || { echo "AGENTS.md missing — run migrations 0000/0001 first"; exit 1; }
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
test -f "$MIRROR" || { echo "spec mirror missing at $MIRROR — re-run codex-workflow install.sh"; exit 1; }
```
**Adaptation (D-28, D-33):** 0009 must NOT port the `test -f AGENTS.md` abort — that's
exactly what D-33 rejects (0004's abort would permanently strand a project below
`to_version`). Keep the mirror-exists pre-flight check (adapt `test -f` → `test -s`,
matching 0029's non-empty guard below — 0029 caught a real bug class `test -f` alone
misses: an interrupted `git pull` leaves a zero-byte mirror that `test -f` still passes).
0029's pre-flight (`../claude-workflow/migrations/0029-region-aware-spec-11-placement.md:80-91`):
```bash
# 2. Vendored §11 block must be present AND non-empty in the global scaffolder
#    bundle. `test -f` alone passes on a zero-byte file...
SPEC_BLOCK="$HOME/.claude/skills/agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
test -s "$SPEC_BLOCK" || {
  echo "ABORT: vendored §11 canonical block missing or empty at:"
  echo "       $SPEC_BLOCK"
  echo "       Re-install: cd ~/.claude/skills/agenticapps-workflow && git pull --ff-only"
  exit 3
}
```
Note: 0029 also carries a third pre-flight guard (`grep -q '^### 4\. Goal-Driven
Execution$'` — a truncation check on the mirror's last section) at
`0029-region-aware-spec-11-placement.md:93-109`. Optional for 0009 (Claude's discretion,
mechanics not policy) but cheap and directly portable if the executor wants the same
defense-in-depth; this host's mirror's last `### ` section is `### 4. Goal-Driven
Execution` too (both mirrors are byte-identical per D-27's shared-source contract) —
verify against `skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md` before reusing the literal grep pattern.

**The anchor rule (D-21) — quote 0029's insert pass verbatim, retargeted.**
Source: `../claude-workflow/migrations/0029-region-aware-spec-11-placement.md:226-246`:
```bash
if awk -v prov="$PROV" -v block_file="$SPEC_BLOCK" '
  BEGIN { inserted = 0 }
  !inserted && (/^## / || /^<!-- gitnexus:start -->$/) {
    print prov
    while ((getline line < block_file) > 0) print line
    close(block_file)
    print ""
    inserted = 1
    print
    next
  }
  { print }
  END {
    if (!inserted) {
      print ""
      print prov
      while ((getline line < block_file) > 0) print line
      close(block_file)
    }
  }
' CLAUDE.md.0029.strip > CLAUDE.md.0029.tmp && [ -s CLAUDE.md.0029.tmp ] \
  && grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' CLAUDE.md.0029.tmp; then
```
**Adaptation:** `CLAUDE.md` → `AGENTS.md`, `SPEC_BLOCK` → this host's `$MIRROR` var name
(0004's convention). Keep the `(/^## / || /^<!-- gitnexus:start -->$/)` alternation
exactly — this is D-21's anchor rule, verbatim. Keep the `grep -q '^## Coding Discipline'`
post-insert shape guard — it's the "non-empty is not the same as correct" defense (D-36's
prose-level equivalent) against a zero-byte mirror producing non-empty-but-wrong output.

**The strip boundary (D-24) — quote 0029's strip pass verbatim, retargeted.**
Source: `../claude-workflow/migrations/0029-region-aware-spec-11-placement.md:192-210`:
```bash
if awk '
  BEGIN { in_block = 0; swallowed_own_h2 = 0 }
  /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ {
    in_block = 1
    next
  }
  in_block && !swallowed_own_h2 && /^## Coding Discipline \(NON-NEGOTIABLE\)$/ {
    swallowed_own_h2 = 1
    next
  }
  in_block && swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/) {
    in_block = 0
    swallowed_own_h2 = 0
    print
    next
  }
  in_block { next }
  !in_block { print }
' CLAUDE.md > CLAUDE.md.0029.strip && [ -s CLAUDE.md.0029.strip ]; then
```
**Adaptation:** `CLAUDE.md` → `AGENTS.md`. Note the `swallowed_own_h2` guard — the block's
OWN `## Coding Discipline (NON-NEGOTIABLE)` heading must be swallowed explicitly before the
terminator search begins, or a naive "stop at the first `/^## /`" terminates on the
block's own heading instead of the block *after* it (this is the specific latent bug
RESEARCH.md flags in its Summary — 0029 already hit and fixed it). **Do NOT** port 0004's
content-sentinel strip (`migrations/0004-revendor-spec-11.md:68-74`, rejected by D-25) —
included below only as the anti-pattern to avoid:
```bash
# REJECTED shape (D-25) — 0004's content-sentinel strip. Do not copy.
awk '
  /^<!-- spec-source: agenticapps-workflow-core@[^ ]+ §11 -->$/ {inblk=1; next}
  inblk && /session-level discipline the model brings to every diff\.$/ {inblk=0; skipblank=1; next}
  inblk {next}
  skipblank && /^$/ {skipblank=0; next}
  {skipblank=0; print}
' AGENTS.md > AGENTS.md.0004.tmp && mv AGENTS.md.0004.tmp AGENTS.md
```

**The region predicate (D-32) — quote 0029's idempotency check verbatim.**
Source: `../claude-workflow/migrations/0029-region-aware-spec-11-placement.md:119-130`:
```bash
[ -f CLAUDE.md ] \
  && grep -q '<!-- spec-source: agenticapps-workflow-core@0\.4\.0 §11 -->' CLAUDE.md \
  && ! awk '
       /^<!-- gitnexus:start -->$/ { r = 1; next }
       /^<!-- gitnexus:end -->$/   { r = 0; next }
       r && /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ { f = 1 }
       END { exit(f ? 0 : 1) }
     ' CLAUDE.md
```
**Adaptation:** `CLAUDE.md` → `AGENTS.md`, no other change needed. This single-pass linear
scan is simpler than D-32's line-number-arithmetic formula and reaches the identical
outcome (fail-closed on unterminated `gitnexus:start`) — RESEARCH.md's Code Examples
section recommends this shape over the arithmetic formula. Note both marker regexes are
anchored `^...$` — this is D-21/D-32's anchoring requirement, not optional.

**The three-branch apply dispatcher (D-30)** — quote 0029's conflict-check +
branch-selection prose shape, `migrations/0029-region-aware-spec-11-placement.md:155-172`:
```bash
if [ ! -f CLAUDE.md ]; then
  echo "INFO: migration 0029 Step 1 — no CLAUDE.md in project; §11 heal skipped."
  echo "      Scaffold a CLAUDE.md (e.g. via /setup-agenticapps-workflow) and"
  echo "      re-run /update-agenticapps-workflow to pick up §11 on the next pass."
elif grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' CLAUDE.md \
     && ! grep -qE "$PROV_RE" CLAUDE.md; then
  echo "ABORT: CLAUDE.md contains a '## Coding Discipline (NON-NEGOTIABLE)'"
  echo "       heading but no provenance comment — it was hand-pasted outside"
  echo "       this migration's management. Refusing to overwrite."
  ...
  exit 3
else
  # strip-if-managed-exists + inject at region-aware anchor (State B = strip+inject; C = inject)
  ...
fi
```
This is D-30's three branches almost verbatim: branch 1 (State D, exit 3) is the `elif`;
branch 2 (State A, skip) is the idempotency check gating whether Apply runs at all
(handled by the harness, not inside this block); branch 3 (State B/C, strip+inject) is the
`else`. **Adaptation:** `CLAUDE.md` → `AGENTS.md`; the informational-skip `INFO:` message
text should reference this host's own setup/update skill names
(`setup-codex-agenticapps-workflow` / `update-codex-agenticapps-workflow`), not 0029's
claude-workflow slugs.

**Rollback — locked to `git checkout AGENTS.md` (D-47). Do NOT port 0029's custom
Rollback awk.** Quoting 0029's Rollback below is *reference only, deliberately not
ported* — its complexity is exactly what required upstream's fixture 08 to catch a
file-destroying bug (per the constraints in this task):
```bash
# REFERENCE ONLY — NOT PORTED (D-47 locks Rollback to `git checkout AGENTS.md`)
# Source: ../claude-workflow/migrations/0029-region-aware-spec-11-placement.md:291-326
if [ -f CLAUDE.md ]; then
  if awk '
    BEGIN { in_block = 0; swallowed_own_h2 = 0 }
    /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ { in_block = 1; next }
    in_block && !swallowed_own_h2 && /^## Coding Discipline \(NON-NEGOTIABLE\)$/ {
      swallowed_own_h2 = 1; next
    }
    in_block && swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/) {
      in_block = 0; swallowed_own_h2 = 0; print; next
    }
    in_block { next }
    !in_block { print }
  ' CLAUDE.md > CLAUDE.md.0029.tmp && [ -s CLAUDE.md.0029.tmp ]; then
    mv CLAUDE.md.0029.tmp CLAUDE.md ...
```
0009's actual Rollback for Step 1 is the one-liner `migrations/0004-revendor-spec-11.md:87`:
```
**Rollback:** `git checkout AGENTS.md`.
```
This makes fixture `08-rollback-region-led`'s bug class (rollback awk eats the region)
structurally impossible in this host — `git checkout` has no terminator to get wrong.

**Step 2/3 (version bump + record) — 0004's 3-step shape, D-41.**
Source: `migrations/0004-revendor-spec-11.md:89-106`:
```
### Step 2: Bump the scaffolder version (implements_spec unchanged)

**Idempotency check:** `grep -q '^version: 0.2.1$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.2.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0004.bak -E 's/^version: 0\.2\.0$/version: 0.2.1/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0004.bak
```
**Rollback:** `sed -i.bak -E 's/^version: 0\.2\.1$/version: 0.2.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 3: Record the new project version

**Idempotency check:** `grep -q '^0.2.1$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:** `echo "0.2.1" > .codex/workflow-version.txt`
**Rollback:** `echo "0.2.0" > .codex/workflow-version.txt`
```
**Adaptation:** `0.2.0`/`0.2.1` → `0.6.0`/`0.7.0` throughout (D-39/D-41).

**Pre-flight version gate (D-39)** — accept both from/to so an idempotent re-run doesn't
abort. 0008's shape is the precedent (`migrations/0008-plan-review-gate.md` frontmatter +
0029's own pre-flight step 1, `0029-region-aware-spec-11-placement.md:72-78`):
```bash
grep -qE '^version: 2\.(6\.0|7\.0)$' "$SKILL_FILE" || {
  INSTALLED=$(grep -E '^version:' "$SKILL_FILE" 2>/dev/null | sed 's/version: //')
  echo "ABORT: workflow scaffolder version is $INSTALLED (need 2.6.0)."
  echo "       Apply prior migrations first via /update-agenticapps-workflow."
  exit 3
}
```
**Adaptation:** `2\.(6\.0|7\.0)` → `0\.(6\.0|7\.0)`, `SKILL_FILE` → this host's
`skills/agentic-apps-workflow/SKILL.md`, `/update-agenticapps-workflow` →
`/update-codex-agenticapps-workflow`.

---

### `migrations/run-tests.sh` → `test_migration_0009` (test, batch)

**Analog for the outer shape (synthesized-printf idiom):**
`run-tests.sh::test_migration_0001`, lines 79-98 —
```bash
test_migration_0001() {
  echo ""
  echo "${YELLOW}=== Migration 0001 — Inject spec §11 Coding Discipline ===${RESET}"

  local mirror="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
  if [ ! -f "$mirror" ]; then
    echo "  ${RED}FAIL${RESET} mirror missing: ..."
    FAIL=$((FAIL+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  local PROV='<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->'

  # Fixture A: AGENTS.md with a heading but no §11 → not yet applied.
  printf '# Title\n\n## Some Section\n\nbody\n' > "$tmp/a-AGENTS.md"
  ...
  assert_check "idempotency: fresh AGENTS.md needs apply" \
    "grep -qE '$PROV' a-AGENTS.md" "$tmp" "not-applied"
```
`assert_check(label, check, fixture_dir, expected)` signature — confirmed at
`vendor/agenticapps-shared/migrations/lib/helpers.sh:60-79`; `expected` is `"applied"` or
`"not-applied"`; it `cd`s into `$fixture` and evaluates `$check`'s exit status.

**This is D-34's locked idiom — case labels inside one function, `printf` into `$tmp`, not
per-fixture directories.** Reject the layout below (shown only to make the rejection
concrete for the executor):
```
# REJECTED layout (D-34) — claude-workflow's per-fixture directories. Do not port.
migrations/test-fixtures/0029/01-gitnexus-led-inject/{setup.sh,verify.sh}
migrations/test-fixtures/0029/02-inside-region-move/{setup.sh,verify.sh}
... (10 such directories total as of 2026-07-15, including 09/10 added after D-46 locked)
```
`migrations/test-fixtures/README.md`'s own "Why no static fixture files" section (lines
66-74) is the rejection rationale to cite in the plan: static copies drift from the
templates (source of truth); this repo extracts from git refs / synthesizes at test time
instead. Its "Limits" section (lines 76-82) is the authorization for D-34's fallback:
> Fixtures cannot capture state that lives outside the repo (e.g. `~/.codex/skills/`)...
> the test harness falls back to a synthesized fixture (constructed at test time)...

**Concrete translation — one claude-workflow fixture dir vs. this repo's `printf`
equivalent.** claude-workflow's `07-prose-mention-not-a-region/setup.sh` (the fixture D-46
folds in, full text):
```bash
#!/bin/sh
# Fixture 07 — BEFORE: this repo's own CLAUDE.md shape (C1). A guard comment
# near the top MENTIONS `<!-- gitnexus:start -->` in backticks as prose, the
# §11 block is correctly anchored right after that comment, and there is NO
# real GitNexus-managed region anywhere in the file. An unanchored marker
# regex treats line 2 as "inside a region"; an anchored one does not.
set -eu
. "$FIXTURES_ROOT/common-setup.sh"

BLOCK="$HOME/.claude/skills/agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"

{
  printf '<!--\n'
  printf '  This block MUST stay ABOVE the `<!-- gitnexus:start -->` region below.\n'
  printf '  This is prose ONLY — this fixture file has no real region.\n'
  printf '%s\n' '-->'
  printf '<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->\n'
  cat "$BLOCK"
  printf '\n## Project Overview\nStuff. No GitNexus region anywhere in this file.\n'
} > CLAUDE.md
```
This repo's D-34-native equivalent — a `printf`-synthesized case inside
`test_migration_0009`, no directory, no separate `setup.sh`:
```bash
# Fixture 07 (D-46.1) — prose mentions the gitnexus:start marker in a comment;
# no real region exists. An unanchored marker regex would misjudge this as
# in-region; an anchored one must not.
{
  printf '<!--\n'
  printf '  This block MUST stay ABOVE the `<!-- gitnexus:start -->` region below.\n'
  printf '  This is prose ONLY — this fixture file has no real region.\n'
  printf -- '-->\n'
  printf '<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->\n'
  cat "$mirror"
  printf '\n## Project Overview\nStuff. No GitNexus region anywhere in this file.\n'
} > "$tmp/g-AGENTS.md"
assert_check "07 prose-mention: anchored regex does not treat prose as a region" \
  "grep -qE '$PROV' g-AGENTS.md && ! awk '...' g-AGENTS.md" "$tmp" "applied"
```
Same content-generation logic (`printf`/`cat` into a file); the only structural change is
target filename (`AGENTS.md`, not `CLAUDE.md`), destination (`$tmp/<letter>-AGENTS.md`, not
a fixture-dir file named `CLAUDE.md`), and invocation (inline in the test function, not a
sourced `setup.sh`).

**The extractor to port (D-35) — quote `common-verify.sh`'s Apply extractor verbatim.**
Source: `../claude-workflow/migrations/test-fixtures/0029/common-verify.sh:100-131`:
```bash
# Pulls the FIRST fenced block following "**Apply:**" within "### Step 1".
# `want` is cleared as soon as a fence opens, so a change from ```bash to ```sh
# cannot make the scan skip past and latch onto Step 1's Rollback fence.
extract_0029_step1_apply() {
  awk '
    /^### Step 1/ { in1=1; next }
    /^### Step 2/ { in1=0 }
    in1 && /^\*\*Apply:\*\*/ { want=1; next }
    want && /^```/ { inb=1; want=0; next }
    inb && /^```$/ { exit }
    inb { print }
  ' "$MIGRATION_0029"
}

STEP1_APPLY="$(extract_0029_step1_apply)"
[ -n "$STEP1_APPLY" ] || {
  echo "PRE: could not extract Step 1 Apply block from $MIGRATION_0029"
  exit 1
}

# Non-empty is not the same as correct. Assert the block carries the anchor
# rule; anything else means the document's shape moved and the extractor
# followed it somewhere wrong. Fail loudly rather than eval it.
case "$STEP1_APPLY" in
  *'gitnexus:start'*) ;;
  *)
    echo "PRE: extracted block is not Step 1's apply — it carries no"
    echo "     gitnexus:start anchor. The migration's Step 1 shape changed;"
    echo "     fix the extractor rather than trusting this block. Extracted:"
    printf '%s\n' "$STEP1_APPLY" | sed 's/^/       /'
    exit 1
    ;;
esac

apply_step1() { eval "$STEP1_APPLY"; }
```
**This is D-35/D-36's core pattern — port near-verbatim.** `MIGRATION_0029` →
`MIGRATION_0009` pointing at `$REPO_ROOT/migrations/0009-spec-11-region-aware-placement.md`.
The shape-assertion `case ... *'gitnexus:start'*` is D-36's antidote to Phase 8's
dead-by-construction defects (08-05/08-09) — do not omit it.

**Port all THREE extractions, not just Apply's — RESEARCH.md's verified finding.**
`common-verify.sh` extracts Idempotency (lines 61-95), Apply (lines 97-131), and Rollback
(lines 133-168) each with its own shape assertion:
- Idempotency check shape assertion (lines 80-92): `case "$STEP1_IDEMPOTENCY" in
  *'spec-source: agenticapps-workflow-core'*) ;; ...`
- Apply shape assertion (lines 117-129, quoted above): `*'gitnexus:start'*`
- Rollback shape assertion (lines 153-166): `case "$STEP1_ROLLBACK" in
  *'spec-source: agenticapps-workflow-core'*) ;; ...`

**Adaptation for D-47:** 0009's Rollback is `git checkout AGENTS.md`, not a fenced awk
block — so the Rollback extractor's shape assertion cannot check for
`spec-source: agenticapps-workflow-core` inside a Rollback awk (there is none). Either
adapt the Rollback extraction to assert the extracted text literally contains
`git checkout AGENTS.md`, or (simpler, since Rollback is a one-liner, not a state machine)
skip porting a Rollback *extractor* entirely and instead assert directly against the
migration document's prose line `**Rollback:** \`git checkout AGENTS.md\`.` — this is a
plan-level decision, not a pattern-mapping one; flagging both options here for the planner.

**The T-08-23 extraction-non-empty-before-assert pattern (D-35's second precedent)** —
`run-tests.sh:967-977`:
```bash
local secfile; secfile="$tmp/section-0008.txt"
awk '
  /^## Pre-execution Gate — Plan Review \(spec §02\)/ {f=1}
  /^<!-- END: agentic-apps-workflow sections -->/      {f=0}
  f
' "$agents_tpl" > "$secfile"

# Extraction from the REAL template must be non-empty BEFORE the insert is
# asserted — a heading-regex mismatch would otherwise report as a confusing
# downstream insert failure instead of "extraction empty" (T-08-23).
if [ -s "$secfile" ]; then
  echo "  ${GREEN}PASS${RESET} section extraction from the real template is non-empty"
  PASS=$((PASS+1))
else
  echo "  ${RED}FAIL${RESET} section extraction from the real template is EMPTY — heading regex drift"
  FAIL=$((FAIL+1))
fi
```
This repo already applies this discipline to *template* extraction; 0009 extends the same
discipline to the migration's own *shell* extraction (TEST-01) — cite this as the
in-repo precedent alongside the ported claude-workflow extractor, since both independently
converge on "assert non-empty before trusting the result."

---

### `migrations/run-tests.sh:118-134` (retire inlined §11 anchor copy, TEST-04/D-37)

**Current inlined copy** (`run-tests.sh:118-125`):
```bash
awk -v mirror="$mirror" '
  /^## / && !done {
    print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
    while ((getline line < mirror) > 0) print line
    close(mirror); print ""; done=1
  }
  { print }
' "$tmp/a-AGENTS.md" > "$tmp/a-injected.md"
```
**Adaptation (D-37):** replace the inlined awk with an extraction from 0001's own document
(`migrations/0001-inject-spec-11-coding-discipline.md`), using the same
fence-scoped-extraction idiom being built for `test_migration_0009` (D-35's pattern,
scoped to whatever heading/marker structure 0001's document uses around its Apply block —
confirm the exact `### Step N` / `**Apply:**` heading text in 0001 before writing the
extractor, since 0001 predates 0008's heading conventions and may not match exactly).
Scope is `run-tests.sh:119` only (D-37) — do NOT also convert 0008's `~run-tests.sh:985`
copy (explicitly deferred, logged in Deferred Ideas).

---

### `docs/decisions/0010-region-aware-spec-11-placement.md` (ADR)

**Analog:** `docs/decisions/0009-plan-review-gate.md` — most recent, GSD-native precedent
in this repo. Section shape (header through footer):
```
# ADR-0009: Bind the plan-review pre-execution gate on the Codex host

**Status**: Accepted  **Date**: 2026-07-15
**Core contract**: `agenticapps-workflow-core/spec/02-hook-taxonomy.md` §"Pre-execution gate" (lines 81-109)
**Sibling host**: claude-workflow ADR-0025 / migration-0016

## Context
...
## Options considered
### A. <rejected option>
### B. <rejected/deferred option>
### C. <chosen option>
## Decision
1. ...  (numbered, each a locked decision with rationale + verification evidence)
## Consequences
## Verification
## Open follow-ups
```
**Adaptation for ADR-0010:** `**Sibling host**` line should read `claude-workflow ADR
(see docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md) /
migration-0029` (this phase's analog to ADR-0009's "Sibling host" cross-reference).
Must include per D-22/CONTEXT.md's "Specific Ideas":
- Both rejected anchor alternatives (D-22.1, D-22.2), each as an `### A.`/`### B.` option
  with rejection reasoning, mirroring ADR-0009's Options-considered shape.
- The corrected invariant (RESEARCH.md's Conflicts section wording — NOT the original
  D-21 rationale sentence, which is false) — quote the corrected form: "The block is
  always followed by a `## ` line, an anchored `<!-- gitnexus:start -->` marker, or EOF."
- D-28.2's drift-repair side effect as a **stated consequence**, not left implicit —
  ADR-0009's own "Consequences" section (lines 400-410) is the shape precedent: short,
  declarative, no new reasoning, just naming what follows from the decisions above.
- D-47's Rollback-shape choice and why it makes fixture-08's bug class structurally
  unreachable here (mirrors ADR-0009 decision-11/12's "known, accepted limitation,
  recorded rather than fixed" framing — same rhetorical shape, applied to a different
  tradeoff).
- One sentence noting the same-day convergence with claude-workflow's 0029 (per Deferred
  Ideas' "Upstream" item and RESEARCH.md Open Question 3's recommendation — "low-stakes,
  defer to the ADR-writing task").

---

### `CHANGELOG.md` (doc)

**Analog:** this repo's own `## [0.6.0] — 2026-07-15` entry, `CHANGELOG.md:25-44`:
```
## [0.6.0] — 2026-07-15

### Added
- **Bind the plan-review pre-execution gate — spec §02** (migration `0008`;
  [ADR-0009](docs/decisions/0009-plan-review-gate.md)). Multi-AI plan review
  must now run before execution begins on this host: ...
```
**Pattern:** bold one-line summary + migration ID + ADR link, then 2-4 sentences of
narrative (what changed, what spec item it closes, why it mattered). A second bullet under
the same `### Added` covers the existing-install migration story when relevant (0008's
second bullet, `CHANGELOG.md:45`). D-46's note ("no known-issues section exists, so the
source prompt's retire-instruction is a no-op") means 0009's entry needs no companion
removal — confirmed, no action needed there.
**Adaptation:** new `## [0.7.0] — <date>` heading above `## [0.6.0]`; bullet references
migration `0009` and `docs/decisions/0010-*.md`.

---

### `skills/agentic-apps-workflow/SKILL.md` (`version:` bump)

**Analog:** the v0.6.0 precedent — no separate file to diff; the pattern is simply the
frontmatter `version:` field bump this repo's version-coupling drift test enforces
(confirmed live: `skills/agentic-apps-workflow/SKILL.md:3` currently reads `version: 0.6.0`).
This is mechanically identical to 0004's Step 2 `sed` pattern (already quoted above under
0009's Step 2) — the "analog" for this row IS 0009's own Step 2 Apply block; there is no
separate pattern to port beyond what 0009 itself performs.

## Shared Patterns

### The terminator-alternation checklist — every awk site in shipped 0029 that carries
`(/^## / || /^<!-- gitnexus:start -->$/)`, enumerated so the planner can enumerate the
same sites in 0009 (this is the corrected D-24 requirement — "every terminator must carry
the same alternation as the anchor"):

| Site in `../claude-workflow/migrations/0029-region-aware-spec-11-placement.md` | Line | Role |
|---|---|---|
| Step 1 Apply — strip pass terminator | :202 | strips the block wherever it currently sits |
| Step 1 Apply — insert pass anchor condition | :228 | the actual D-21 anchor rule |
| Step 1 Rollback — removal pass terminator | :302 | *(reference only — not ported, D-47)* |

**In 0009 (this host), only the first two rows are load-bearing** (Rollback is
`git checkout`, D-47) — but both the strip pass AND the insert pass in 0009's own Step 1
Apply MUST carry the identical alternation, or MIGR-06 idempotency / re-run on an
already-healed region-led `AGENTS.md` will runaway-strip the region (RESEARCH.md's
Pitfall 1, independently confirmed). Enumerate both sites in the plan's task list as
separate assertion targets, not one.

### `test -s` (non-empty) vs `test -f` (exists) — apply everywhere a mirror or extraction
result gates a downstream `mv`/replace. Both pre-flight (0029:85-91, quoted above) and
every strip/insert pass's post-condition (`[ -s ... ]` at 0029:210, :246, :310) use this.
This repo's own T-08-23 precedent (`run-tests.sh:971-977`, quoted above) independently
converges on the same discipline for template extraction — apply it symmetrically to
0009's file-surgery output.

### Atomic replace via temp file + `mv`, never redirect onto the file being read —
0004's `> AGENTS.md.0004.tmp && mv AGENTS.md.0004.tmp AGENTS.md` shape
(`migrations/0004-revendor-spec-11.md:74,83`) and 0029's `.0029.strip`/`.0029.tmp` shape
(both quoted above) agree; apply the same `NNNN.strip`/`NNNN.tmp` naming convention for
0009 (`AGENTS.md.0009.strip`, `AGENTS.md.0009.tmp`), and clean up temp files on every
failure path (0029's `rm -f ... ; echo ABORT; exit 3` pattern, e.g. :251-256, :259-265,
:268-271 — three distinct failure branches, each cleans up and aborts without touching
`AGENTS.md`).

### Fence-scoped extraction with shape assertion (D-35/D-36) — see
`test_migration_0009` section above; this is the single most load-bearing shared pattern
in the phase (TEST-01/TEST-04 both depend on it, and TEST-02's RED-before-GREEN
requirement is validated through it).

### Double-sided idempotency contract (D-38) — `migrations/test-fixtures/README.md:21-33`
(Contract section, quoted in full above under the fixture README excerpt) — every
`assert_check(..., "not-applied")` / `assert_check(..., "applied")` pair in
`test_migration_0009` must exercise both directions per step, matching
`test_migration_0001`'s existing shape (Fixture A = not-applied, Fixture B = applied,
`run-tests.sh:94-103`).

## No Analog Found

None. Every file in this phase's scope has a direct, concrete analog — either in this
repo's own migration history (0004, 0008, 0001, ADR-0009) or in `claude-workflow`'s
shipped 0029. The one genuine gap (a fence-scoped markdown extractor in *this* repo before
today) is what TEST-01 itself builds, ported from 0029's `common-verify.sh`.

## Metadata

**Analog search scope:** `migrations/` (this repo + claude-workflow), `docs/decisions/`,
`CHANGELOG.md`, `skills/agentic-apps-workflow/SKILL.md`, `migrations/test-fixtures/`
(both repos), `vendor/agenticapps-shared/migrations/lib/helpers.sh`.
**Files read in full:** `0004-revendor-spec-11.md`, `../claude-workflow/migrations/0029-*.md`,
`../claude-workflow/migrations/test-fixtures/0029/common-verify.sh`,
`../claude-workflow/migrations/test-fixtures/0029/common-setup.sh`,
`../claude-workflow/migrations/test-fixtures/0029/07-prose-mention-not-a-region/setup.sh`,
`migrations/test-fixtures/README.md`, `docs/decisions/0009-plan-review-gate.md`.
**Files read in relevant part:** `run-tests.sh` (1-145, 955-1005), `0008-plan-review-gate.md`
(1-40), `AGENTS.md` (1-20, 265-314), `CHANGELOG.md` (1-45), `SKILL.md` (1-15).
**Note on fixture count drift:** `../claude-workflow/migrations/test-fixtures/0029/` now
holds **10** fixture dirs (`09-two-provenance-heal`, `10-corrupt-mirror-refused` were
added after CONTEXT.md's D-46 lock, at 14:08/14:27). D-46 locks this phase to 8 cases
(the six original + 07/08); the two newest upstream additions are out of scope per D-46
and not analyzed here — flagged for the planner in case it wants to reconfirm the 8-case
scope is still current before locking tasks.
**Pattern extraction date:** 2026-07-15
