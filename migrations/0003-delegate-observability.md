---
id: 0003
slug: delegate-observability
title: Delegate §10 observability to agenticapps-observability (Codex install)
from_version: 0.2.0
to_version: 0.2.0
applies_to:
  - .planning/config.json
  - AGENTS.md
requires:
  - skill: observability
    install: |
      git clone https://github.com/agenticapps-eu/agenticapps-observability \
        ${CODEX_HOME:-$HOME/.codex}/skills/agenticapps-observability && \
      bash ${CODEX_HOME:-$HOME/.codex}/skills/agenticapps-observability/install-codex.sh
    verify: "test -f \"${CODEX_HOME:-$HOME/.codex}/skills/observability/SKILL.md\" && grep -q '^name: observability' \"${CODEX_HOME:-$HOME/.codex}/skills/observability/SKILL.md\""
optional_for: []
---

# Migration 0003 — Delegate §10 observability to agenticapps-observability

`agenticapps-workflow-core` §10 (observability) obliges every host to
provide a **generator** (§10.7). Per ADR-0004, codex-workflow satisfies
§10 by **delegating** to the standalone, host-neutral
`agenticapps-observability` skill — the same way claude-workflow does
(its migration `0022`) — rather than re-owning a generator inside this
scaffolder. A delegation to a consumable skill is a *satisfied* MUST
under §09, not a spec delta; `full` conformance is preserved.

The Codex install surface is the obs repo's `install-codex.sh` (added in
agenticapps-observability v0.12.0), which symlinks the skill into
`${CODEX_HOME:-$HOME/.codex}/skills/observability`. This migration does
**not** auto-install it (mirroring claude-workflow D-03): it verifies the
skill is present and aborts with an actionable pointer if absent —
failing closed so a project is never left half-wired.

This migration is **additive** (`from 0.2.0 → 0.2.0`): it rides on the
0.2.0 / `implements_spec: 0.4.0` claim established by migration `0001`.
It does not move the version. The drift test stays green (latest
migration `0003` to_version 0.2.0 == trigger SKILL.md version 0.2.0).

Division of labour (mirrors claude-workflow):
- The **obs skill** owns observability — it scaffolds the host-neutral
  wrapper/middleware (`$observability init`) and validates + baselines
  (`$observability scan`, host-neutral; reads `AGENTS.md` on Codex).
- **This migration** records the delegation in the project's
  `.planning/config.json` and repoints the `observability:` metadata
  block's skill reference in `AGENTS.md` if a stale one exists. The
  metadata block itself (§10.8) is materialised in `AGENTS.md` for Codex
  projects by the host workflow (this migration / the obs init's
  host-aware Phase 6 follow-up), not by Claude-targeting `init`.

## Pre-flight (hard aborts on failure)

```bash
# Project root must be a git repo
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# Project must already be at >= 0.2.0 (migrations 0001/0002 applied)
test -f .planning/config.json || { echo ".planning/config.json missing — run migrations 0000–0002 first"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required for this migration"; exit 1; }

# The 'observability' skill must be installed as a SEPARATE install (D-03 mirror).
# No auto-install — abort with an actionable pointer if absent.
OBS="${CODEX_HOME:-$HOME/.codex}/skills/observability/SKILL.md"
if [ ! -f "$OBS" ] || ! grep -q '^name: observability' "$OBS"; then
  echo "ABORT: the 'observability' skill is not installed for Codex."
  echo "Install agenticapps-observability separately, then re-run:"
  echo ""
  echo "  git clone https://github.com/agenticapps-eu/agenticapps-observability \\"
  echo "    \"\${CODEX_HOME:-\$HOME/.codex}/skills/agenticapps-observability\""
  echo "  bash \"\${CODEX_HOME:-\$HOME/.codex}/skills/agenticapps-observability/install-codex.sh\""
  echo ""
  echo "Then re-run \$update-codex-agenticapps-workflow."
  exit 3
fi
```

Each abort exit-3 includes the remediation step. Pre-flight failures must
be resolved before the migration applies — it is not silently skipped.

## Steps

### Step 1: Record the §10 delegation in .planning/config.json

**Idempotency check:** `jq -e '.hooks.observability.delegated_to == "observability"' .planning/config.json >/dev/null`
**Pre-condition:** `.planning/config.json` is valid JSON with a `.hooks` object
**Apply:**
```bash
tmp="$(mktemp)"
jq '.hooks.observability = {
  "delegated_to": "observability",
  "implements_spec": "0.4.0",
  "host": "codex",
  "invoke": "$observability",
  "init": "$observability init",
  "scan": "$observability scan",
  "spec_section": "10",
  "note": "§10 satisfied by delegation to the standalone agenticapps-observability skill (ADR-0004); install via install-codex.sh"
}' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```
**Rollback:**
```bash
tmp="$(mktemp)"
jq 'del(.hooks.observability)' .planning/config.json > "$tmp" && mv "$tmp" .planning/config.json
```

### Step 2: Repoint a stale observability skill reference in AGENTS.md (conditional)

**Idempotency check (positive — repointed/absent):**
`! grep -qE '^[[:space:]]*skill:[[:space:]]*add-observability' AGENTS.md`
(Returns 0 when no stale `add-observability` skill reference remains — either
already repointed or the block was never present.)
**Pre-condition:** `grep -q '^observability:' AGENTS.md` (the project has an
`observability:` metadata block). A fresh Codex project has none yet — the block
is created later by `$observability init`; this step then no-ops.
**Apply:** in the `observability:` metadata block / Skills line ONLY, rewrite a
legacy `add-observability` skill reference to `observability`. Do NOT rewrite
historical prose elsewhere.
```bash
sed -i.0003.bak -E 's/(skill:[[:space:]]*)add-observability/\1observability/' AGENTS.md
rm -f AGENTS.md.0003.bak
```
**Rollback:** `git checkout AGENTS.md` (or reverse the substitution).

## Post-checks

- `jq -e '.hooks.observability.delegated_to == "observability"' .planning/config.json` — delegation recorded
- `jq . .planning/config.json >/dev/null` — config still valid JSON
- `! grep -qE '^[[:space:]]*skill:[[:space:]]*add-observability' AGENTS.md` — no stale skill ref
- `test -f "${CODEX_HOME:-$HOME/.codex}/skills/observability/SKILL.md"` — obs skill installed
- Drift test green: trigger SKILL.md `version` (0.2.0) == latest migration `to_version` (0.2.0)

## Skip cases

- **Already delegated** (idempotency check passes) — Step 1 no-ops.
- **`observability` skill absent** → pre-flight ABORTS (exit 3) with the
  separate-install pointer. NOT a silent skip and NOT an auto-install (D-03).
- **No `observability:` block in AGENTS.md** → Step 2's pre-condition fails; the
  repoint is skipped (nothing to repoint). The delegation record (Step 1) still
  applies; the block is created later by `$observability init`.

## Notes

Testable non-interactively via `test_migration_0003` in
`migrations/run-tests.sh` (idempotency + jq apply/rollback on a synthetic
config; conditional repoint on a synthetic AGENTS.md). Per migration
immutability the chain stays contiguous (`0000`→`0001`→`0002`→`0003`).

## References

- ADR-0004 (this repo) — the Option B delegation decision.
- ADR-0005 (this repo) — adoption of core ADR-0014 observability architecture.
- claude-workflow `migrations/0022-observability-repoint-phase-sentinel.md` —
  the repoint model this mirrors.
- agenticapps-observability `install-codex.sh` (v0.12.0) — the Codex install
  surface (PR agenticapps-observability#3).
- `docs/observability-delegation.md` — downstream setup/update guidance.
