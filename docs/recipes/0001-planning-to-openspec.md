---
id: 0001
slug: planning-to-openspec
title: Migrate a .planning/ (GSD) project to the OpenSpec front end — Codex host
from_version: "0.x (GSD front end)"
to_version: "1.0.0 (OpenSpec front end)"
vendored_from: agenticapps-workflow-core@1.0.0 docs/recipes/0001-planning-to-openspec.md
applies_to:
  - .planning/                # read-only; moved to docs/legacy-planning/ (never deleted)
  - openspec/                 # created: specs/, changes/, changes/archive/
  - docs/legacy-planning/     # created: the retained .planning/ history
  - AGENTS.md                 # product prose relocated per §19
  - .codex/hooks.json         # the §18 change-gate PreToolUse wiring
  - .git/hooks/pre-commit     # the agent-agnostic floor
requires:
  - tool: openspec
    verify: "openspec --version"
    install: "npm i -g @fission-ai/openspec"
  - tool: reviewer-clis
    verify: "claude --version && gemini --version"
    install: "install >= 2 external-vendor reviewer CLIs (claude / gemini / opencode — never codex, the implementing host)"
optional_for:
  - tag: db
    detect: "test -d supabase || test -d migrations/sql || grep -rqi 'rls' ."
    note: "no DB surface -> database-security stays unbound (§17 conditional)"
  - tag: ui
    detect: "test -d frontend || test -d src/components"
    note: "no UI surface -> the design gates stay unbound (§17 conditional)"
---

# Recipe 0001 — planning → OpenSpec (Codex host)

**This is a vendored adaptation**, not an original. The upstream is
`agenticapps-workflow-core@1.0.0` `docs/recipes/0001-planning-to-openspec.md`,
which is host-agnostic and explicitly asks each adopting host to fill in its
own hook wiring and install commands. This copy fills in Codex's, on the same
basis as `templates/spec-mirrors/`: a target project that runs this recipe may
not have the core repo checked out.

It applies to a **target project**, never to this scaffolder — `codex-workflow`
keeps its own `.planning/` in place (ADR-0011).

Migrating is **two tiers of work plus a do-no-harm rule**, in this order:

- **Tier 0 (do no harm):** the `.planning/` history is *moved*, never deleted.
- **Tier 1 (mechanical, scripted):** each completed `.planning/phases/<slug>/`
  becomes a completed `changes/archive/<date>-<slug>/`. Fully automatable.
- **Tier 2 (supervised):** `specs/<capability>/` is reconstructed by a
  human-supervised merge of related phases into capabilities. **Not** an
  unattended script — it requires judgment and ratification.

## Pre-flight

```sh
openspec --version                  || { echo "npm i -g @fission-ai/openspec"; exit 1; }
git rev-parse --is-inside-work-tree || { echo "run inside a git repo"; exit 1; }
test -d .planning/phases            || echo "note: no .planning/phases — greenfield adopt, skip Tier 1"
```

Do this on a branch. Nothing here pushes or opens a PR; that is the host's
`branch-close` / ship step, run after Tier 2 is ratified.

## Steps

### Step 1 (Tier 0): Move `.planning/` to `docs/legacy-planning/` — never delete

**Idempotency check:** `test -d docs/legacy-planning && ! test -d .planning`
**Pre-condition:** `test -d .planning`
**Apply:**

```sh
mkdir -p docs
git mv .planning docs/legacy-planning
printf '%s\n' \
  '# Legacy planning' '' \
  'The GSD-era `.planning/` tree was moved here on migration to the OpenSpec' \
  'front end (spec v1.0.0, recipe 0001). It is retained as effort history' \
  '(§19 Tier 0) and is never deleted. Current product truth now lives in' \
  '`openspec/specs/`.' > docs/legacy-planning/README.md
```

**Rollback:** `git mv docs/legacy-planning .planning && rm -f .planning/README.md`

> **Codex host note — two config files stay at `.planning/`.** The knowledge-
> capture ritual (§15) reads `.planning/config.json`, and the gate bindings
> live in `.planning/config.codex.json`. Both are *runtime* config, not
> history: move the phase history and keep these two at their original paths.
> ```sh
> mkdir -p .planning
> git mv docs/legacy-planning/config.json       .planning/config.json       2>/dev/null || true
> git mv docs/legacy-planning/config.codex.json .planning/config.codex.json 2>/dev/null || true
> ```

### Step 2 (Tier 1, scripted): Each completed phase → an archived change

**Idempotency check:** `test -d openspec/changes/archive && [ "$(ls -A openspec/changes/archive 2>/dev/null)" ]`
**Pre-condition:** `openspec --version >/dev/null && test -d docs/legacy-planning/phases`
**Apply:** run the mechanical converter below. It reads each
`docs/legacy-planning/phases/<slug>/` and writes a *completed*
`openspec/changes/archive/<date>-<slug>/`. It does **not** touch `specs/`
(that is Tier 2) and does **not** commit.

```sh
#!/usr/bin/env bash
# tier1-phases-to-archive.sh — mechanical, idempotent, no commit.
set -euo pipefail
PHASES="docs/legacy-planning/phases"
OUT="openspec/changes/archive"
mkdir -p "$OUT"
[ -d "$PHASES" ] || { echo "no phases to convert"; exit 0; }

for dir in "$PHASES"/*/; do
  slug="$(basename "$dir")"
  # Date the archive from the phase's own history, not wall-clock.
  date="$(git log -1 --format=%ad --date=short -- "$dir" 2>/dev/null || true)"
  [ -n "$date" ] || date="$(date -r "$dir" +%F 2>/dev/null || echo 0000-00-00)"
  target="$OUT/$date-$slug"
  if [ -d "$target" ]; then echo "skip (exists): $target"; continue; fi
  mkdir -p "$target"

  {
    echo "# $slug (migrated from GSD phase)"
    echo
    echo "> Reconstructed by recipe 0001 Tier 1 from \`$dir\`. This change"
    echo "> already shipped; it is recorded here as history."
    echo
    for f in CONTEXT.md SUMMARY.md; do
      [ -f "$dir$f" ] && { echo "## From $f"; echo; cat "$dir$f"; echo; }
    done
  } > "$target/proposal.md"

  {
    echo "# Tasks (migrated — completed)"
    echo
    if ls "$dir"*PLAN.md >/dev/null 2>&1; then
      grep -hE '^\s*[-*]\s*\[[ xX]\]' "$dir"*PLAN.md 2>/dev/null \
        | sed -E 's/\[[ ]\]/[x]/' || true
    else
      echo "- [x] (no PLAN.md found; phase recorded as complete)"
    fi
  } > "$target/tasks.md"

  # Carry evidence verbatim. On this host the phase's multi-AI review artifact
  # is `<NN>-REVIEWS.md`; it lands as REVIEWS.md alongside the archived change.
  for f in VERIFICATION.md REVIEW.md REVIEWS.md SECURITY.md; do
    [ -f "$dir$f" ] && cp "$dir$f" "$target/$f"
  done
  for f in "$dir"*-REVIEWS.md; do
    [ -f "$f" ] && cp "$f" "$target/REVIEWS.md"
  done
  echo "wrote: $target"
done
echo "Tier 1 complete. Review, then Tier 2 (specs) — do not archive-fold yet."
```

**Rollback:** `rm -rf openspec/changes/archive/*` (Tier 1 output only).

### Step 3 (Tier 2, SUPERVISED — not a script): Reconstruct `specs/<capability>/`

This step is **procedure, not automation.** A human (with an agent's help)
reconstructs the durable spec by **merging related phases into capabilities** —
the merge-not-mirror rule (§19). One phase ≠ one spec.

1. `openspec init --tools codex --profile core` if the slot does not exist.
2. Cluster the archived changes from Step 2 into **capabilities** — a coherent
   product surface (e.g. phases `03`, `03.5`, `03.6` →
   `specs/analysis-pipeline/spec.md`). Name capabilities by product surface,
   not by phase number.
3. For each capability write `specs/<capability>/spec.md` as the requirements
   the product satisfies **today**, drawing product truth from the clustered
   phases. **Exclude** what was never a product guarantee — operational
   logging, unbuilt plumbing, scaffolding (§19).
4. Relocate any **product guarantee** still living in `AGENTS.md` into the
   relevant spec as a requirement, leaving a pointer (§19 placement test).
   Leave process and the ADR ledger where they are.
5. Where the phase record is ambiguous or contradictory, **do not guess** —
   write the gap inline as a blockquote flag:

   ```markdown
   > [GAP: phase 04.5 CONTEXT says analysts self-register; phase 04.6 SUMMARY
   > says invite-only. Which is current truth? Needs ratification.]
   ```

6. `openspec validate --all` until green.
7. **Human ratification gate.** A human reviews every `> [GAP: …]`, resolves it
   in the spec, and explicitly ratifies the reconstructed `specs/` before
   anything is archive-folded. Tier 2 is **not** complete while any `[GAP: …]`
   remains.

**Idempotency check:** `openspec validate --all && ! grep -rq '\[GAP:' openspec/specs`
**Pre-condition:** Step 2 output reviewed; `openspec` available.
**Rollback:** `rm -rf openspec/specs/*` (specs are derived, not source).

### Step 4: Wire the retargeted change-gate (§18) — Codex specifics

**Idempotency check:**
`jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | any(test("hook-wrapper-openspec-gate"))' .codex/hooks.json`
**Pre-condition:** `test -d openspec`
**Apply:**

```sh
CODEX="${CODEX_HOME:-$HOME/.codex}"
CMD="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh"

mkdir -p .codex
[ -f .codex/hooks.json ] || echo '{}' > .codex/hooks.json
tmp="$(mktemp)"
# NOTE the NESTED hooks array. codex-cli silently DROPS the flat
# {"matcher","type","command"} form — no error, no warning.
jq --arg cmd "$CMD" \
  '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"apply_patch","hooks":[{"type":"command","command":$cmd}]}])' \
  .codex/hooks.json > "$tmp" && mv "$tmp" .codex/hooks.json

# The agent-agnostic floor — a PreToolUse hook cannot gate its own session.
install -m 0755 "$HOME/.agenticapps/git-hooks/pre-commit" "$(git rev-parse --git-path hooks)/pre-commit"
```

**Rollback:** remove only the entry whose nested `command` matches `$CMD`, and
delete the installed `pre-commit`.

> **Trust is a separate act.** codex-cli requires the operator to trust a
> project hook. Until they do, `/hooks` reports it as `Review`, not `Active`,
> and it **enforces nothing while looking installed**. Verify with `/hooks` in
> a fresh session. This is an observed failure mode, not a theoretical one.

## Post-checks

```sh
openspec validate --all                                   # green
! grep -rq '\[GAP:' openspec/specs                        # all ratified
test -d docs/legacy-planning && ! test -d .planning/phases
jq -e '.lifecycle.validate.change_gate' .planning/config.codex.json >/dev/null
jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | any(test("openspec-gate"))' .codex/hooks.json >/dev/null
test -x "$(git rev-parse --git-path hooks)/pre-commit"

# The §18 truth table, by DIRECT invocation (a hook cannot gate its own session)
GATE="$HOME/.agenticapps/bin/openspec-change-gate.sh"
printf '{"tool":"edit","tool_input":{"file_path":"src/x.ts"}}' | "$GATE"; echo "expect 2 under an un-reviewed active change: $?"
printf '{"tool":"edit","tool_input":{"file_path":"openspec/changes/x/proposal.md"}}' | "$GATE"; echo "expect 0 (exempt): $?"
```

- No product guarantee remains stranded in `AGENTS.md` (§19).
- ADR opportunity: draft a project ADR recording the adoption and the
  `implements_spec: 1.0.0` bump.

## Skip cases

- **No `.planning/` at all** → greenfield adopt: skip Tier 0 and Tier 1, run
  `openspec init --tools codex --profile core`, author `specs/` directly, wire
  the gate (Step 4).
- **Project already at `implements_spec: 1.0.0`** → skipped silently.
- **OpenSpec CLI absent** → skip with a note directing the user to install it;
  pre-flight fails closed. Note that the gate BLOCKS under an active change
  while it cannot assert validate-green — deliberately (§18).
- **Fewer than 2 reviewer CLIs on the machine** → Tier 1/2 still run; the gate
  will block the first code edit until reviews exist. `GSD_SKIP_REVIEWS=1` is
  the logged override.
