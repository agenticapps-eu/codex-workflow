---
id: 0001
slug: inject-spec-11-coding-discipline
title: Inject spec §11 Coding Discipline canonical block + bump to 0.4.0
from_version: 0.1.0
to_version: 0.2.0
applies_to:
  - AGENTS.md
  - skills/agentic-apps-workflow/SKILL.md
  - .codex/workflow-version.txt
requires: []
optional_for: []
---

# Migration 0001 — Inject spec §11 Coding Discipline

`agenticapps-workflow-core` 0.4.0 adds **§11 — Coding Discipline**, a
**canonical-prose** section (§09 item 1): host implementations MUST
reproduce the block **verbatim** in their primary project-instruction
file. For the Codex host that file is `AGENTS.md`.

This migration injects the vendored §11 block into a project's
`AGENTS.md` immediately before the first `## ` (level-2) heading —
"near the top" per §11's SHOULD and §12's long-context advisory — behind
a provenance anchor so the block is machine-identifiable and
re-injection is idempotent.

It also **bundles the conformance-claim bump** (Step 2): the trigger
skill's `version` 0.1.0 → 0.2.0 and `implements_spec` 0.1.0 → 0.4.0.
§11 is the canonical-prose MUST that earns the 0.4.0 claim, so this
migration is the **sole bumper** of those fields. The later additive
migrations of this catch-up (`0002` §13 skill, `0003` §10 delegation)
ride on this `to_version: 0.2.0` and do not move the claim again. A
state where `version` moved but `implements_spec` did not (or vice
versa) is non-conformant — Step 2 applies both or neither.

The byte-identical source is vendored at
`templates/spec-mirrors/11-coding-discipline-0.4.0.md` (installed to
`${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/`).
It is the content between the fences of core
`spec/11-coding-discipline.md` — no paraphrase, no provenance comment
inside the block (a comment inside would alter the verbatim prose).

## Pre-flight

```bash
# Project root must be a git repo (atomic commit per migration assumes git)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# AGENTS.md must exist (it is the canonical Codex instruction file; baseline 0000 creates it)
test -f AGENTS.md || { echo "AGENTS.md missing — run \$setup-codex-agenticapps-workflow (migration 0000) first"; exit 1; }

# The vendored §11 mirror must be installed
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
test -f "$MIRROR" || { echo "spec mirror missing at $MIRROR — re-run codex-workflow install.sh"; exit 1; }

# CONFLICT: a '## Coding Discipline (NON-NEGOTIABLE)' heading already present
# WITHOUT the provenance comment means an unmanaged copy exists. Refuse rather
# than create a duplicate or silently adopt prose we cannot verify is verbatim.
if grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md \
   && ! grep -qE '<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->' AGENTS.md; then
  echo "ABORT: AGENTS.md contains a '## Coding Discipline (NON-NEGOTIABLE)' heading"
  echo "       but no '<!-- spec-source: ... §11 -->' provenance comment. This"
  echo "       migration will not duplicate or silently adopt unmanaged prose."
  echo ""
  echo "  Resolve by hand, then re-run, in ONE of two ways:"
  echo "  (a) DELETE the existing section so this migration injects the managed,"
  echo "      verbatim block under provenance; or"
  echo "  (b) If your existing section is already byte-identical to"
  echo "      templates/spec-mirrors/11-coding-discipline-0.4.0.md, add the line"
  echo "      '<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->'"
  echo "      immediately above the heading to adopt it as managed; Step 1 then no-ops."
  exit 3
fi
```

## Steps

### Step 1: Inject the §11 canonical block into AGENTS.md

**Idempotency check:** `grep -qE '<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->' AGENTS.md`
**Pre-condition:** mirror installed (pre-flight), AGENTS.md has at least one `## ` heading (else block is appended at EOF)
**Apply:**
```bash
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
# Insert provenance anchor + verbatim mirror content + one blank line,
# immediately before the first '## ' heading. The mirror is streamed
# byte-for-byte (no transcription), so the injected block is identical
# to core spec §11. Fallback: if no '## ' heading exists, append at EOF.
awk -v mirror="$MIRROR" '
  /^## / && !done {
    print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
    while ((getline line < mirror) > 0) print line
    close(mirror)
    print ""
    done=1
  }
  { print }
  END {
    if (!done) {
      print ""
      print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
      while ((getline line < mirror) > 0) print line
      close(mirror)
    }
  }
' AGENTS.md > AGENTS.md.0001.tmp && mv AGENTS.md.0001.tmp AGENTS.md
```
**Rollback:** delete from the `<!-- spec-source: ... §11 -->` line through the
`session-level discipline the model brings to every diff.` line inclusive
(plus the trailing blank), or `git checkout AGENTS.md` if uncommitted.

**Verbatim assertion (post-apply):**
```bash
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' AGENTS.md \
  | diff - "$MIRROR" || { echo "injected §11 block is NOT byte-identical to the mirror"; exit 1; }
```

### Step 2: Bump the conformance claim (version + implements_spec)

**Idempotency check:** `grep -q '^version: 0.2.0$' skills/agentic-apps-workflow/SKILL.md && grep -q '^implements_spec: 0.4.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** the trigger SKILL.md carries both `version:` and `implements_spec:` (abort if either is absent — never land a partial claim)
**Apply:**
```bash
SKILL_FILE="skills/agentic-apps-workflow/SKILL.md"
grep -q '^version:' "$SKILL_FILE" || { echo "ABORT: $SKILL_FILE has no version: field"; exit 1; }
grep -q '^implements_spec:' "$SKILL_FILE" || { echo "ABORT: $SKILL_FILE has no implements_spec: field"; exit 1; }
# Bundle: both move together or neither.
sed -i.0001.bak -E \
  -e 's/^version: 0\.1\.0$/version: 0.2.0/' \
  -e 's/^implements_spec: 0\.1\.0$/implements_spec: 0.4.0/' "$SKILL_FILE"
# Prose references in the skill body (full-conformance citation line).
sed -i.0001.bak -E \
  -e 's/v0\.1\.0\. The frontmatter `implements_spec: 0\.1\.0`/v0.4.0. The frontmatter `implements_spec: 0.4.0`/' "$SKILL_FILE"
rm -f "$SKILL_FILE.0001.bak"
```
**Rollback:** `git checkout skills/agentic-apps-workflow/SKILL.md`, or reverse the
two `sed` substitutions (0.2.0 → 0.1.0, 0.4.0 → 0.1.0).

### Step 3: Record the new project version

**Idempotency check:** `grep -q '^0.2.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists (baseline 0000 created it)
**Apply:**
```bash
echo "0.2.0" > .codex/workflow-version.txt
```
**Rollback:** `echo "0.1.0" > .codex/workflow-version.txt`

## Post-checks

- `grep -qE '<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->' AGENTS.md` — provenance anchor present
- §11 block in AGENTS.md is byte-identical to the mirror (the Step 1 verbatim assertion)
- `grep -q '^version: 0.2.0$' skills/agentic-apps-workflow/SKILL.md` — version bumped
- `grep -q '^implements_spec: 0.4.0$' skills/agentic-apps-workflow/SKILL.md` — claim bumped
- `grep -q '^0.2.0$' .codex/workflow-version.txt` — project version recorded
- Drift test green: trigger SKILL.md `version` == latest migration `to_version`

## Skip cases

- **Already injected** (provenance anchor present) — Step 1 idempotency check
  short-circuits; Steps 2/3 likewise no-op if already at 0.2.0/0.4.0.
- **Unmanaged §11 prose present** (heading without provenance) — pre-flight
  aborts (exit 3) with the two hand-resolution paths above. This is a hard
  block, not a skip: the operator must reconcile before re-running.
- **AGENTS.md missing** — pre-flight aborts; run migration 0000 first.

## Notes

This migration is testable non-interactively (unlike 0000): its
idempotency check, conflict pre-flight, and byte-identity assertion all
run against synthetic fixtures. See `test_migration_0001` in
`migrations/run-tests.sh`.

Per the migration-immutability contract, the chain stays contiguous
(`0000` → `0001`). The §13 and §10 absorptions ship as new migrations
(`0002`, `0003`), never as edits to this one.
