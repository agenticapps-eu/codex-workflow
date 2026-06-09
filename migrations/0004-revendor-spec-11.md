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

# Migration 0004 — Re-vendor §11 mirror (blank-line drift fix)

The §11 mirror shipped in v0.2.0 (migration `0001`) was vendored from a
**stale local checkout** of `agenticapps-workflow-core`. Core commit
`10f2c96` ("spec: blank lines around §11 anti-pattern lists
(markdown/prettier-clean)", merged via core #12) had added a blank line
after each "Anti-patterns this rule prevents:" line, growing the
canonical block from 75 to 79 lines and shifting the fence from 26–102
to 26–106. The v0.2.0 mirror therefore drifted from the current
authoritative core §11 — a byte-identity (canonical-prose) conformance
defect (§09 item 1).

This migration re-vendors the mirror byte-identical to the **current**
core §11 and re-injects the corrected block into the project's
`AGENTS.md`. `implements_spec` stays **0.4.0** — core's
`spec_version` is unchanged (10f2c96 is a markdown-clean patch within
0.4.0, not a spec version bump). Only the scaffolder version bumps
**0.2.0 → 0.2.1** (a patch correcting the vendored bytes).

Per migration immutability, `0001` is NOT edited; this is a new
migration. The fence-relative re-vendor + the fence-relative test
(`migrations/run-tests.sh`) prevent recurrence on future spec
line-number shifts.

## Pre-flight

```bash
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }
test -f AGENTS.md || { echo "AGENTS.md missing — run migrations 0000/0001 first"; exit 1; }
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
test -f "$MIRROR" || { echo "spec mirror missing at $MIRROR — re-run codex-workflow install.sh"; exit 1; }
# A managed §11 block must already exist (this migration corrects it; migration 0001 injects it).
grep -qE '<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->' AGENTS.md \
  || { echo "no managed §11 block in AGENTS.md — apply migration 0001 first"; exit 1; }
```

## Steps

### Step 1: Re-inject the corrected §11 block into AGENTS.md

**Idempotency check (positive — block already matches the corrected mirror):**
```bash
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' AGENTS.md \
  | diff -q - "$MIRROR" >/dev/null
```
**Pre-condition:** the corrected mirror is installed (pre-flight) and is itself
byte-identical to current core §11 (the scaffolder ships it that way).
**Apply:** strip the existing managed §11 block, then re-inject from the mirror.
```bash
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
# Strip the existing managed block (provenance anchor → closing line + one trailing blank).
awk '
  /^<!-- spec-source: agenticapps-workflow-core@[^ ]+ §11 -->$/ {inblk=1; next}
  inblk && /session-level discipline the model brings to every diff\.$/ {inblk=0; skipblank=1; next}
  inblk {next}
  skipblank && /^$/ {skipblank=0; next}
  {skipblank=0; print}
' AGENTS.md > AGENTS.md.0004.tmp && mv AGENTS.md.0004.tmp AGENTS.md
# Re-inject the corrected block before the first '## ' heading.
awk -v mirror="$MIRROR" '
  /^## / && !done {
    print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
    while ((getline line < mirror) > 0) print line
    close(mirror); print ""; done=1
  }
  { print }
' AGENTS.md > AGENTS.md.0004.tmp && mv AGENTS.md.0004.tmp AGENTS.md
```
**Verbatim assertion:** the AGENTS.md block now diffs clean against the mirror
(same command as the idempotency check).
**Rollback:** `git checkout AGENTS.md`.

### Step 2: Bump the scaffolder version (implements_spec unchanged)

**Idempotency check:** `grep -q '^version: 0.2.1$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.2.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0004.bak -E 's/^version: 0\.2\.0$/version: 0.2.1/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0004.bak
```
(`implements_spec: 0.4.0` is unchanged — do NOT touch it.)
**Rollback:** `sed -i.bak -E 's/^version: 0\.2\.1$/version: 0.2.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 3: Record the new project version

**Idempotency check:** `grep -q '^0.2.1$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:** `echo "0.2.1" > .codex/workflow-version.txt`
**Rollback:** `echo "0.2.0" > .codex/workflow-version.txt`

## Post-checks

- AGENTS.md §11 block byte-identical to the mirror (Step 1 assertion)
- mirror byte-identical to current core §11 (fence-relative; `run-tests.sh`)
- `grep -q '^version: 0.2.1$' skills/agentic-apps-workflow/SKILL.md`
- `grep -q '^implements_spec: 0.4.0$' skills/agentic-apps-workflow/SKILL.md` (unchanged)
- `grep -q '^0.2.1$' .codex/workflow-version.txt`
- Drift test green: SKILL.md `version` (0.2.1) == latest migration `to_version` (0.2.1)

## Skip cases

- **Already corrected** (Step 1 idempotency passes) — Steps no-op if already 0.2.1.
- **No managed §11 block** — pre-flight aborts; apply migration 0001 first.

## Notes

Root cause: v0.2.0's `0001` vendored from a stale local core checkout. Fix is
forward-only (migration immutability). The harness now extracts the canonical
block fence-relative, so a future spec line-shift cannot reintroduce this drift
silently.
