---
id: 0005
slug: bind-upstream-gsd
title: Bind upstream GSD + Superpowers; remove the re-port; namespace the hook config
from_version: 0.2.1
to_version: 0.3.0
applies_to:
  - .planning/config.json
  - .planning/config.codex.json
requires:
  - skill: gsd (get-shit-done-codex)
    install: |
      Bind the upstream GSD distribution (installs the /prompts:gsd-* Codex
      prompts under ${CODEX_HOME:-$HOME/.codex}/prompts; verify /prompts:gsd-help):
        npx get-shit-done-codex                 # interactive: pick Global (~/.codex)
        # non-interactive: npx -y -p get-shit-done-codex get-shit-done-cc --global
      Also re-run the scaffolder install so the removed re-ported skills'
      symlinks go away and the kept AgenticApps skills relink:
        bash install.sh
    verify: "ls \"${CODEX_HOME:-$HOME/.codex}/prompts\" 2>/dev/null | grep -q '^gsd-' || echo 'bind GSD: run npx get-shit-done-codex'"
  - skill: superpowers (for Codex)
    install: |
      Install the Superpowers distribution for Codex so the superpowers:*
      gate bindings resolve (TDD, brainstorming, verification, code-review,
      finishing-branch, systematic-debugging). See docs/BINDING.md.
    verify: "echo 'verify: ask Codex \"tell me about your superpowers\"'"
optional_for: []
---

# Migration 0005 — Bind upstream GSD + Superpowers (stop re-porting)

`codex-workflow` originally **re-ported** GSD (`skills/gsd-*`) and the
Superpowers discipline skills (`codex-brainstorming`, `codex-tdd`,
`codex-verification`, `codex-finishing-branch`, `codex-code-review`,
`codex-systematic-debugging`), and invented a `.planning/phases/<NN>/`
layout. Per the shared standard
[`docs/standards/gsd-binding-and-planning.md`](../docs/standards/gsd-binding-and-planning.md)
and [ADR-0007](../docs/decisions/0007-bind-upstream-gsd.md), the host now
**binds** those upstreams and ships only the AgenticApps layer.

The scaffolder-side removal (deleting `skills/gsd-*` and the six
Superpowers-duplicate `codex-*` skills, rebinding the trigger skill's
Step 3 table, and updating `templates/config-hooks.json`) is delivered by
pulling this release and re-running `bash install.sh` (see the `requires`
block). The upstream GSD + Superpowers distributions provide the removed
capabilities.

This migration's **per-project** effect is twofold: it namespaces the hook
config to `.planning/config.codex.json` (standard §4) so a codex + claude
tree can coexist, and it rebinds the six Superpowers-duplicate gates to
`superpowers:*` in that config. Kept gate skills follow GSD's native
phase-subdirectory layout going forward — `.planning/phases/<NN>-<slug>/`
(get-shit-done v1.42.3) — replacing the invented `.planning/phases/<N>/`
variant.

## Pre-flight

```bash
# Project root must be a git repo
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# Project must already carry a hook config (baseline applied). Either the
# pre-0.3.0 name (config.json) or the namespaced name (already migrated).
test -f .planning/config.json || test -f .planning/config.codex.json \
  || { echo ".planning/config(.codex).json missing — run migration 0000 first"; exit 1; }

# jq is required for the config edit
command -v jq >/dev/null 2>&1 || { echo "jq required for this migration"; exit 1; }
```

## Steps

### Step 1: Namespace the hook config → `.planning/config.codex.json`

**Idempotency check:** `test -f .planning/config.codex.json && ! test -f .planning/config.json`
**Pre-condition:** `test -f .planning/config.json` (source present to rename)
**Apply:**
```bash
git mv .planning/config.json .planning/config.codex.json 2>/dev/null \
  || mv .planning/config.json .planning/config.codex.json
```
**Rollback:**
```bash
git mv .planning/config.codex.json .planning/config.json 2>/dev/null \
  || mv .planning/config.codex.json .planning/config.json
```

### Step 2: Rebind the six Superpowers-duplicate gates to `superpowers:*`

**Idempotency check:** `jq -e '.hooks.pre_phase.brainstorm_ui.skill == "superpowers:brainstorming"' .planning/config.codex.json >/dev/null`
**Pre-condition:** `.planning/config.codex.json` is valid JSON with a `.hooks` object
**Apply:**
```bash
tmp="$(mktemp)"
jq '
    .hooks.pre_phase.brainstorm_ui.skill           = "superpowers:brainstorming"
  | .hooks.pre_phase.brainstorm_architecture.skill = "superpowers:brainstorming"
  | .hooks.per_task.tdd.skill                      = "superpowers:test-driven-development"
  | .hooks.per_task.verification.skill             = "superpowers:verification-before-completion"
  | .hooks.post_phase.code_review.skill            = "superpowers:requesting-code-review"
  | .hooks.finishing.branch_close.skill            = "superpowers:finishing-a-development-branch"
' .planning/config.codex.json > "$tmp" && mv "$tmp" .planning/config.codex.json
```
**Rollback:**
```bash
tmp="$(mktemp)"
jq '
    .hooks.pre_phase.brainstorm_ui.skill           = "codex-brainstorming"
  | .hooks.pre_phase.brainstorm_architecture.skill = "codex-brainstorming"
  | .hooks.per_task.tdd.skill                      = "codex-tdd"
  | .hooks.per_task.verification.skill             = "codex-verification"
  | .hooks.post_phase.code_review.skill            = "codex-code-review"
  | .hooks.finishing.branch_close.skill            = "codex-finishing-branch"
' .planning/config.codex.json > "$tmp" && mv "$tmp" .planning/config.codex.json
```

## Post-checks

- `test -f .planning/config.codex.json` — namespaced config present
- `test ! -f .planning/config.json` — old name removed
- `jq -e '.hooks.per_task.tdd.skill == "superpowers:test-driven-development"' .planning/config.codex.json` — tdd rebound
- `jq -e '.hooks.post_phase.code_review.skill == "superpowers:requesting-code-review"' .planning/config.codex.json` — code-review rebound
- `jq -e '.hooks.pre_phase.design_shotgun.skill == "codex-design-shotgun"' .planning/config.codex.json` — kept gstack gates intact (not clobbered)
- `jq -e '.hooks.per_task.tdd.strengthened_by.skill == "codex-ts-declare-first"' .planning/config.codex.json` — §13 strengthener (if present from 0002) intact
- `ls "${CODEX_HOME:-$HOME/.codex}/prompts" | grep -q '^gsd-'` — upstream GSD prompts bound
- Drift test green: trigger SKILL.md `version` (0.3.0) == latest migration `to_version` (0.3.0)

## Skip cases

- **Already namespaced + rebound** (both idempotency checks pass) — the
  migration no-ops.
- **Config missing** — pre-flight aborts; run migration 0000 (setup) first.
- **Upstream not yet bound** — the config rebind still applies; the
  `superpowers:*` skills / `/prompts:gsd-*` prompts resolve once
  `bash install.sh` / `npx get-shit-done-codex` have run (see `requires`).

## Notes

- **Removed-skill symlinks.** After pulling this release, the global symlinks
  for the removed re-ported skills (`gsd-*` and the six Superpowers-duplicate
  `codex-*`) become dangling. `bash install.sh` relinks the kept skills; prune
  the stale links with:
  ```bash
  for l in "${CODEX_HOME:-$HOME/.codex}"/skills/*; do
    [ -L "$l" ] && [ ! -e "$l" ] && readlink "$l" | grep -q codex-workflow && rm "$l"
  done
  ```
- **GSD-native layout going forward.** Kept gate skills now write their
  artifacts **inside** GSD's phase directory
  (`.planning/phases/<NN>-<slug>/REVIEW.md`, `QA.md`, `DB-AUDIT.md`,
  `IMPECCABLE-AUDIT.md`), matching get-shit-done v1.42.3 and the other hosts —
  replacing codex-workflow's earlier invented `.planning/phases/<N>/` variant.
  Existing `.planning/phases/**` from before this release are left as
  provenance; nothing rewrites them.
- **Testable** non-interactively via `test_migration_0005` in
  `migrations/run-tests.sh` (rename + jq rebind/rollback on a synthetic
  config fixture, plus a kept-gate-intact assertion).
- Per migration immutability, the chain stays contiguous
  (`0000` → `0001` → `0002` → `0003` → `0004` → `0005`).
