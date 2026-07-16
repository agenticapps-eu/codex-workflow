---
id: 0010
slug: heal-0007-knowledge-capture
title: Heal migration 0007's chain break — knowledge capture re-delivery (v0.4.0 -> 0.5.0)
from_version: 0.4.0
to_version: 0.5.0
applies_to:
  - .planning/config.json                      # seed the host-neutral knowledge_capture block
  - AGENTS.md                                   # insert the "Knowledge Capture — Ritual Tail" section
  - .codex/workflow-version.txt                 # record new project version
requires: []
optional_for: []
---

# Migration 0010 — Heal 0007's knowledge-capture chain break (v0.4.0 -> 0.5.0)

**Root cause this migration fixes:** migration 0007's pre-flight grepped
`skills/agentic-apps-workflow/SKILL.md` — a scaffolder-relative path **no real
target project has** (the setup skill's project-side surface is `AGENTS.md`,
`.planning/`, `.codex/`, and `docs/decisions/` only; see `migrations/0008-plan-review-gate.md`
`## Notes`, T-08-38, for the full evidence trail). Every real install stuck at
`0.4.0` therefore aborts 0007 with `exit 3` before writing anything — no
`knowledge_capture` config block, no AGENTS.md ritual-tail section, and no
`0.5.0` version record. 0008's and 0009's own floor checks
(`^0\.(5|6)\.0$` / `^0\.(6|7)\.0$`) already read `.codex/workflow-version.txt`
correctly, but they can never pass for these installs because the version
record 0007 was supposed to advance never moved. This migration is the fix:
it re-delivers 0007's Steps 1, 2, and 4 payload — renumbered here to Steps 1,
2, and 3 — behind a corrected pre-flight, re-enabling 0008/0009's already-good
logic for the fleet.

**0007's Step 3 (the scaffolder version bump) is dropped, not re-delivered.**
It sed'd a target project's local `skills/agentic-apps-workflow/SKILL.md` —
the exact path this migration proves no target project has, and a MIGR-09
immutability violation (a migration must record the version in the TARGET
project, never bump this scaffolder's own files). See `## Notes` below.

**Migration 0007 is never edited (compatibility contract, `migrations/README.md`).**
This is a new forward migration, not a patch to 0007.

**Version-gate strictness — no payload-presence detection.** This migration's
pre-flight is a **verbatim reuse** of migration 0008's proven version-floor
pattern (`migrations/0008-plan-review-gate.md` lines ~54–93): gate on
`.codex/workflow-version.txt` reading the supported floor, accept the target
version for idempotent re-apply. It does **not** add a branch that detects a
missing `knowledge_capture` block or AGENTS.md ritual-tail section and does
not otherwise widen the gate. An operator who manually forced
`.codex/workflow-version.txt` to `0.5.0` to escape 0007's abort (and so is
already past this migration's floor, carrying none of 0007's payload) is
handled by documentation — `skills/update-codex-agenticapps-workflow/SKILL.md`
§Stage D's recovery runbook (MIGR-11) — never by a detection branch here.

**Why a 0.x minor bump into a slot another migration already occupies:** the
update engine applies a migration only when
`installed >= from_version AND installed < to_version`. Every install stuck by
0007's bug is at `0.4.0`, so a `0.4.0 -> 0.5.0` migration is the shape that
reaches the fleet via `$update-codex-agenticapps-workflow`. This is a
**version-backport**: 0010's `to_version` (`0.5.0`) is lower than 0009's
(`0.7.0`), even though 0010's filename sorts last. This does not change the
drift target — see `## Compatibility` below.

**Supported upgrade floor:** `0.4.0 -> 0.5.0`. Projects below `0.4.0` replay
the chain through 0006 first.

## Pre-flight

```bash
# Project root must be a git repo (repo-name derivation + atomic commit)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# jq is required for the config merge
command -v jq >/dev/null || { echo "ABORT: jq not found — required for the config merge"; exit 2; }

# Workflow project version is at the supported floor (0.4.0), or 0.5.0 for
# re-apply. DELIBERATE DIVERGENCE from 0007's floor check, which greps this
# repo's own scaffolder trigger skill's SKILL.md — a path NO target project
# has (the setup skill's project-side surface is AGENTS.md, .planning/,
# .codex/, and docs/decisions/ only; 0007's floor grep aborts with exit 3 on
# every real install for exactly this reason — see `## Notes`). This
# project's OWN durable version record, `.codex/workflow-version.txt`, is
# what the update skill itself reads (its Stage A step 1), and is what this
# floor check reads too — the same corrected pattern migration 0008 already
# proved (`migrations/0008-plan-review-gate.md:54-93`).
grep -qE '^0\.(4|5)\.0$' .codex/workflow-version.txt || {
  INSTALLED=$(cat .codex/workflow-version.txt 2>/dev/null)
  echo "ABORT: project version is $INSTALLED (need 0.4.0)."
  echo "       Apply prior migrations first via \$update-codex-agenticapps-workflow."
  echo "       Supported upgrade floor: 0.4.0 -> 0.5.0."
  exit 3
}

# Templates ship in the installed scaffolder (single source of truth).
CODEX="${CODEX_HOME:-$HOME/.codex}"
test -f "$CODEX/skills/setup-codex-agenticapps-workflow/templates/config-knowledge-capture.json" || {
  echo "ABORT: config-knowledge-capture.json template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
test -f "$CODEX/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md" || {
  echo "ABORT: agents-md-additions.md template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
```

## Steps

### Step 1: Seed the host-neutral `knowledge_capture` block into `.planning/config.json`

The destination is per-repo config (spec §15.2), never hardcoded in skill
logic. The `<repo-name>` placeholder is resolved to the repo directory name
at configuration time (§15.2: written out literally, never substituted at
runtime). Re-delivers 0007's Step 1 verbatim.

**Idempotency check:** `test -f .planning/config.json && jq -e '.knowledge_capture' .planning/config.json >/dev/null`
(Returns 0 when the block already exists — e.g. a claude co-install seeded it,
or a manual-0.5.0-escape operator already has it; its value is preserved
verbatim, this step is a no-op.)
**Pre-condition:** template present (checked in pre-flight); `jq` available.
**Apply:**
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
TEMPLATE="$CODEX/skills/setup-codex-agenticapps-workflow/templates/config-knowledge-capture.json"
REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
mkdir -p .planning

# Resolve <repo-name> in the template's note path, take just the block object.
KC="$(jq -c --arg name "$REPO_NAME" \
        '.knowledge_capture.note |= gsub("<repo-name>"; $name) | .knowledge_capture' \
        "$TEMPLATE")"

if [ -f .planning/config.json ]; then
  # Merge: add knowledge_capture, preserve every existing key (claude hooks etc.).
  jq --argjson kc "$KC" '. + {knowledge_capture: $kc}' \
     .planning/config.json > .planning/config.json.tmp \
    && mv .planning/config.json.tmp .planning/config.json
else
  # Codex-only repo: create the shared file with only the host-neutral block.
  jq -n --argjson kc "$KC" '{knowledge_capture: $kc}' > .planning/config.json
fi
```
**Rollback:** if `.planning/config.json` existed pre-step, `jq 'del(.knowledge_capture)' .planning/config.json > tmp && mv tmp .planning/config.json`; if this step created the file (codex-only), `rm -f .planning/config.json`.

### Step 2: Insert the "Knowledge Capture — Ritual Tail" section into `AGENTS.md`

The section text is **extracted from the scaffolder's `agents-md-additions.md`
template** (single source of truth) so a healed install is byte-identical to
a fresh one and the prose cannot drift. It is inserted inside the existing
`agentic-apps-workflow` marker block, immediately before the closing marker.
Re-delivers 0007's Step 2 verbatim.

**Idempotency check:** `grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md`
(Returns 0 when the section is already present — a fresh install got it from
the template via `0000-baseline` Step 3; this step is then a no-op.)
**Pre-condition:** `AGENTS.md` carries the marker pair
`grep -q '<!-- END: agentic-apps-workflow sections -->' AGENTS.md`
**Apply:**
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
TPL="$CODEX/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md"

# Extract the section from the template to a temp file: from its heading up to
# (excluding) the template's END marker. The trailing blank line before END is
# included, so it separates the inserted section from the project's END marker.
SECFILE="$(mktemp)"
awk '
  /^## Knowledge Capture — Ritual Tail \(spec §15\)/ {f=1}
  /^<!-- END: agentic-apps-workflow sections -->/    {f=0}
  f
' "$TPL" > "$SECFILE"

# Insert the section before the project's END marker. getline-from-file is
# portable (BSD/macOS awk rejects a multi-line -v assignment) — carried
# forward verbatim from 0007's Step 2; a "simplification" to `awk -v
# var="$(cat file)"` breaks every macOS install.
awk -v secfile="$SECFILE" '
  /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
    while ((getline line < secfile) > 0) print line
    ins=1
  }
  { print }
' AGENTS.md > AGENTS.md.0010.tmp && mv AGENTS.md.0010.tmp AGENTS.md
rm -f "$SECFILE"
```
**Rollback:** `git checkout -- AGENTS.md`. Manual anchor: delete from the line
`## Knowledge Capture — Ritual Tail (spec §15)` through the blank line before
`<!-- END: agentic-apps-workflow sections -->`.

### Step 3: Record the new project version

This is the project's durable version record, and the last step, per 0007's
content-steps-then-version-seal convention. Re-delivers 0007's Step 4,
renumbered — 0007's Step 3 (the scaffolder version bump) is **dropped**, not
renumbered; see `## Notes`.

**Idempotency check:** `grep -q '^0.5.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:**
```bash
echo "0.5.0" > .codex/workflow-version.txt
```
**Rollback:** `echo "0.4.0" > .codex/workflow-version.txt`

**There is no step that bumps a target project's local scaffolder trigger
skill's SKILL.md, and none should be added.** No target project has a local
`skills/` tree — the setup skill's project-side surface is `AGENTS.md`,
`.planning/`, `.codex/`, and `docs/decisions/` only (0008's own precedent,
`migrations/0008-plan-review-gate.md` `## Notes`, T-08-38). This repo's own
scaffolder version is bumped separately, as a direct edit in this phase's own
commit — never as a migration step shipped to other people's repos.

## Post-checks

```bash
# 1. Config block present, host-neutral, placeholder resolved (ALWAYS true on success)
jq -e '.knowledge_capture.enabled | type == "boolean"' .planning/config.json >/dev/null
! grep -qF '<repo-name>' .planning/config.json

# 2. Ritual-tail section wired into AGENTS.md (ALWAYS true on success)
grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md

# 3. Version healed to 0.5.0 (ALWAYS true on success) — no target-project
#    scaffolder-file check; see the Step 3 note above.
grep -q '^0.5.0$' .codex/workflow-version.txt
```

- Drift test green: this repo's own scaffolder trigger skill's SKILL.md
  `version` is decoupled from this migration's `to_version` — see
  `## Compatibility` (this migration is a version-backport, not the drift
  target).

## Skip cases

- **`from_version` mismatch** (project not at 0.4.0) → migration framework
  skips silently. Projects below 0.4.0 replay the chain through 0006 first.
- **Step 1 already present** (a claude co-install seeded `.planning/config.json`,
  or a manual-0.5.0-escape operator already has it) → Step 1 idempotency is
  positive; the existing block is preserved verbatim and **Steps 2 and 3 still
  run**.
- **Step 2 already present** (fresh install got it from the template, or a
  prior partial run applied it) → Step 2 is a no-op; **Steps 1 and 3 still
  run**.
- **Step 3 already present** (`.codex/workflow-version.txt` already reads
  `0.5.0`) → Step 3 is a no-op.
- **No vault on this machine** → not this migration's concern: the block is
  seeded regardless; the *skill's* graceful skip (spec §15.3) handles an
  absent vault folder at trigger time, never here.

## Compatibility

- **Additive (minor) bump** to `0.5.0`: no breaking change. Step 1 only adds a
  key (existing config keys preserved); Step 2 only inserts a section inside
  the existing marker block.
- **Host-neutrality:** the `knowledge_capture` block carries no host-specific
  keys, so codex and claude read the identical block from the shared
  `.planning/config.json` without collision — same contract as 0007.
- **Version-backport, NOT the drift target.** As a version-backport into the
  `0.4.0 -> 0.5.0` slot 0007 occupies, 0010's `to_version` (`0.5.0`) is
  **below** 0009's (`0.7.0`), the current drift target, even though 0010's
  filename sorts last among migration files. `migrations/run-tests.sh`
  `test_drift` selects the drift target by **semver-max `to_version`** across
  every migration file, not by filename sort, specifically to keep this
  backport from tripping a false drift mismatch (see `test_drift`'s own
  comment in `migrations/run-tests.sh` for the mechanism).
- Per migration immutability, the chain stays contiguous
  (`0000` → `0001` → … → `0009` → `0010`); 0010 fills the `0.4.0 -> 0.5.0`
  hop 0007 was meant to deliver, it does not replace 0007 in the file list.

## Notes

- **Testable** non-interactively via `test_migration_0010` in
  `migrations/run-tests.sh`: it extracts this document's own pre-flight,
  `applies_to`, and Step 1/2/3 Apply blocks (never a hand-transcribed copy),
  asserts none of them names `skills/agentic-apps-workflow` (D-07 — proves
  0007's bug is not re-introduced by copy-paste), and executes the extracted
  Apply blocks against a clean `0.4.0` sandbox carrying none of 0007's
  artifacts and no local `skills/` tree, asserting the config block, the
  AGENTS.md section, and the healed `0.5.0` version record all land.
- **Heals migration 0007's chain break, does not edit it.** Migration 0007
  (`migrations/0007-knowledge-capture.md`) is immutable per the compatibility
  contract; its pre-flight bug (grepping
  `skills/agentic-apps-workflow/SKILL.md`, a path no real target project has)
  stays in the historical record. This migration is the fix-forward: it
  re-delivers 0007's Steps 1, 2, and 4 payload behind a corrected pre-flight
  that reads `.codex/workflow-version.txt` exclusively — the same corrected
  pattern migration 0008 already proved — and touches no target-project
  `skills/` path anywhere.
- **0007's Step 3 (scaffolder version bump) is deliberately dropped, not
  renumbered forward.** It sed'd a target project's local
  `skills/agentic-apps-workflow/SKILL.md` — a MIGR-09 immutability violation
  (a migration records the version in the TARGET project, never bumps this
  scaffolder's own files; see `migrations/0008-plan-review-gate.md`'s own
  Step 4 precedent, which made the identical decision for the same reason).
- **No payload-presence detection branch, by design (D-01).** This
  migration's pre-flight is a strict version-floor gate, verbatim-reusing
  0008's proven pattern — it does not inspect whether `knowledge_capture` or
  the ritual-tail section are already present before deciding whether to run.
  An operator who manually forced `.codex/workflow-version.txt` to `0.5.0` to
  escape 0007's abort is out of this migration's reach (their project is past
  the floor) and is instead routed by
  `skills/update-codex-agenticapps-workflow/SKILL.md` §Stage D's recovery
  runbook (MIGR-11) to `--migration 0010` directly.
- **Mirrors** migration 0007 in payload, 0008 in pre-flight — this migration
  is a composite by design, not a fresh invention: the bug 0008 already
  diverged away from (T-08-38) is the exact bug 0010 exists to heal for every
  earlier migration still carrying it.

## References

- Core spec: `agenticapps-workflow-core/spec/15-knowledge-capture.md` (v0.7.0)
- Core ADR: `agenticapps-workflow-core/adrs/0017-knowledge-capture-obsidian.md`
- This repo's ADR: `docs/decisions/0008-knowledge-capture.md`
- Vault schema: `~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/CLAUDE.md`
- Migration this one re-delivers the payload of: `migrations/0007-knowledge-capture.md`
- Migration this one reuses the pre-flight pattern from: `migrations/0008-plan-review-gate.md`
- Standard: `docs/standards/gsd-binding-and-planning.md` §4 (namespaced config) + conformance checklist
