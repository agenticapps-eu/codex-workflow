---
id: 0007
slug: knowledge-capture
title: Knowledge capture into the Obsidian vault — spec §15 (v0.4.0 -> 0.5.0)
from_version: 0.4.0
to_version: 0.5.0
applies_to:
  - .planning/config.json                      # seed the host-neutral knowledge_capture block
  - AGENTS.md                                   # insert the "Knowledge Capture — Ritual Tail" section
  - skills/agentic-apps-workflow/SKILL.md       # scaffolder version bump 0.4.0 -> 0.5.0
  - .codex/workflow-version.txt                 # record new project version
requires: []
optional_for: []
---

# Migration 0007 — Knowledge capture (v0.4.0 -> 0.5.0)

Implements core spec [§15](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/15-knowledge-capture.md)
(v0.7.0, core ADR-0017) on the Codex host: distill **1–5 transferable
learnings** to **one Obsidian note per repo** as the final step of the three
rituals — session handoff, plan completion, phase completion. The wiring is
prose the agent executes (spec §15 permits any mechanism); this migration
teaches an **existing install** the config block and the AGENTS.md ritual-tail
section. Fresh installs get both by construction — the `config-hooks.json` sits
in `.planning/config.codex.json` and the ritual-tail section ships in the
`agents-md-additions.md` template appended by `0000-baseline` Step 3, while this
migration (run last in the chain) seeds `.planning/config.json`.

**Config lives in the shared, host-neutral `.planning/config.json`, not
`.planning/config.codex.json`.** Codex namespaced its *hooks* to
`config.codex.json` (migration 0005, standard §4) so a codex + claude pair can
run one working tree without colliding. `knowledge_capture` is the opposite: it
must be the **same** block both hosts read (the vault note is one-per-repo,
shared across hosts — its `hosts:` frontmatter lists `[claude, codex, …]`). So
the block goes in `.planning/config.json`, which claude also writes; the two
hosts differ only by the `(codex)` / `(claude)` tag in the Log heading. Seeding
here is a `. + {knowledge_capture}` merge that preserves every existing key (a
claude co-install's hooks stay intact) and is skipped when the block already
exists (a claude-written block is left verbatim).

**Why a 0.x minor bump:** the update engine applies a migration only when
`installed >= from_version AND installed < to_version`. Every live project is at
`0.4.0` after 0006, so a `0.4.0 -> 0.5.0` migration is the shape that reaches the
fleet via `$update-codex-agenticapps-workflow`.

**Supported upgrade floor:** `0.4.0 -> 0.5.0`. Projects below 0.4.0 replay the
chain through 0006 first.

## Pre-flight

```bash
# Project root must be a git repo (repo-name derivation + atomic commit)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# jq is required for the config merge
command -v jq >/dev/null || { echo "ABORT: jq not found — required for the config merge"; exit 2; }

# Workflow scaffolder is at the supported floor (0.4.0), or 0.5.0 for re-apply.
grep -qE '^version: 0\.(4|5)\.0$' skills/agentic-apps-workflow/SKILL.md || {
  INSTALLED=$(grep -E '^version:' skills/agentic-apps-workflow/SKILL.md 2>/dev/null | sed 's/version: //')
  echo "ABORT: scaffolder version is $INSTALLED (need 0.4.0)."
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

The destination is per-repo config (spec §15.2), never hardcoded in skill logic.
The `<repo-name>` placeholder is resolved to the repo directory name at
configuration time (§15.2: written out literally, never substituted at runtime).

**Idempotency check:** `test -f .planning/config.json && jq -e '.knowledge_capture' .planning/config.json >/dev/null`
(Returns 0 when the block already exists — e.g. a claude co-install seeded it;
its value is preserved verbatim, this step is a no-op.)
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
template** (single source of truth) so a migrated install is byte-identical to a
fresh one and the prose cannot drift. It is inserted inside the existing
`agentic-apps-workflow` marker block, immediately before the closing marker.

**Idempotency check:** `grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md`
(Returns 0 when the section is already present — a fresh install got it from the
template via `0000-baseline` Step 3; this step is then a no-op.)
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
# portable (BSD/macOS awk rejects a multi-line -v assignment).
awk -v secfile="$SECFILE" '
  /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
    while ((getline line < secfile) > 0) print line
    ins=1
  }
  { print }
' AGENTS.md > AGENTS.md.0007.tmp && mv AGENTS.md.0007.tmp AGENTS.md
rm -f "$SECFILE"
```
**Rollback:** `git checkout -- AGENTS.md`. Manual anchor: delete from the line
`## Knowledge Capture — Ritual Tail (spec §15)` through the blank line before
`<!-- END: agentic-apps-workflow sections -->`.

### Step 3: Bump the scaffolder version (implements_spec unchanged)

**Idempotency check:** `grep -q '^version: 0.5.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.4.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0007.bak -E 's/^version: 0\.4\.0$/version: 0.5.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0007.bak
```
(`implements_spec` is unchanged — do NOT touch it. §15 wiring is real conformance
either way; `implements_spec` tracks the last full audit, unchanged here.)
**Rollback:** `sed -i.bak -E 's/^version: 0\.5\.0$/version: 0.4.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 4: Record the new project version

**Idempotency check:** `grep -q '^0.5.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:** `echo "0.5.0" > .codex/workflow-version.txt`
**Rollback:** `echo "0.4.0" > .codex/workflow-version.txt`

## Post-checks

```bash
# 1. Config block present, host-neutral, placeholder resolved (ALWAYS true on success)
jq -e '.knowledge_capture.enabled | type == "boolean"' .planning/config.json >/dev/null
! grep -qF '<repo-name>' .planning/config.json

# 2. Ritual-tail section wired into AGENTS.md (ALWAYS true on success)
grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md

# 3. Version bumped to 0.5.0 (ALWAYS true on success)
grep -q '^version: 0.5.0$' skills/agentic-apps-workflow/SKILL.md
grep -q '^0.5.0$' .codex/workflow-version.txt
```

- Drift test green: SKILL.md `version` (0.5.0) == latest migration `to_version` (0.5.0)

## Skip cases

- **`from_version` mismatch** (project not at 0.4.0) → migration framework skips
  silently. Projects below 0.4.0 replay the chain first.
- **Block already present** (a claude co-install seeded `.planning/config.json`)
  → Step 1 idempotency is positive; the existing block is preserved verbatim and
  Steps 2–4 still run.
- **Section already present** (fresh install got it from the template) → Step 2
  is a no-op; Steps 1, 3, 4 still run.
- **No vault on this machine** → not this migration's concern: the block is
  seeded regardless; the *skill's* graceful skip (spec §15.3) handles an absent
  vault folder at trigger time, never here.

## Compatibility

- **Additive (minor) bump** to `0.5.0`: no breaking change. Step 1 only adds a
  key (existing config keys preserved); Step 2 only inserts a section inside the
  existing marker block.
- **Host-neutrality:** the `knowledge_capture` block carries no host-specific
  keys, so codex and claude read the identical block from the shared
  `.planning/config.json` without collision (dual-host workflow-testbed finding;
  standard §4/§5).
- **Drift coupling:** as the highest-numbered migration file, 0007's
  `to_version` (0.5.0) is the drift target; `skills/agentic-apps-workflow/SKILL.md`
  is bumped to 0.5.0 in lockstep (`run-tests.sh` `test_drift`).
- Per migration immutability, the chain stays contiguous
  (`0000` → `0001` → … → `0006` → `0007`).

## Notes

- **Testable** non-interactively via `test_migration_0007` in
  `migrations/run-tests.sh`: it asserts the config merge resolves `<repo-name>`
  and preserves a pre-existing (claude) key, the AGENTS.md section insert +
  idempotent re-apply, and the version-bump round-trip.
- **Mirrors** claude-workflow's `0025-knowledge-capture` (the reference host) in
  its own idiom, per the core ADR-0017 downstream-hosts note. Codex ships no
  snapshot, so there is no snapshot drift-guard analog — the fresh-install path
  is conformant by construction (template carries the section; the chain seeds
  the config).

## References

- Core spec: `agenticapps-workflow-core/spec/15-knowledge-capture.md` (v0.7.0)
- Core ADR: `agenticapps-workflow-core/adrs/0017-knowledge-capture-obsidian.md`
- This repo's ADR: `docs/decisions/0008-knowledge-capture.md`
- Vault schema: `~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/CLAUDE.md`
- Sibling precedent: claude-workflow `migrations/0025-knowledge-capture.md`
- Standard: `docs/standards/gsd-binding-and-planning.md` §4 (namespaced config) + conformance checklist
