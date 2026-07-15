# Brief — Bind the spec §02 `plan-review` pre-execution gate on Codex

**Repo:** `codex-workflow` · **Type:** Codex execution brief
**Author context:** conformance audit against `agenticapps-workflow-core` v0.7.0 (2026-07-14)

## Why

Core spec v0.5.0 added a `plan-review` pre-execution gate to `spec/02`. The spec
names this repo as an outstanding follow-up:

> **Host conformance (follow-up):** claude-workflow implements this resolver and
> grandfather guard as of spec 0.5.0 (ADR 0025 / migration 0016). codex-workflow
> and pi-agentic-apps-workflow MUST adopt the identical resolution order and
> grandfather rule to stay conformant — tracked as a follow-up, not yet
> implemented.
> — `spec/02-hook-taxonomy.md:105-109`

An audit confirms the gate is absent here: zero matches for `plan-review` across
the repo. The bindings table in `AGENTS.md:122-139` covers exactly the 15
pre-0.5.0 gates and jumps from `design-critique` straight to `tdd` — the
pre-execution slot does not exist. It is not recorded as a Spec Delta either, and
the trigger plainly can occur, since `.planning/phases/*/PLAN.md` files exist.

The gate exists to close an observed failure mode: cparx phases 04.9 → 05
silently dropped multi-AI plan review for 8 consecutive phases (core ADR-0018).

## Goal

Bind `plan-review` on the Codex host with real, testable enforcement, so the repo
holds the §02 content required for a future `implements_spec: 0.5.0` claim.

Out of scope, deliberately: bumping `implements_spec` (it tracks a full
conformance audit, not one gate — see `CHANGELOG.md:88-91`); wiring
`~/.codex/hooks.json`; migrating this repo's `.planning/phases/` layout.

## Findings that shape the design

1. **The codex hook model is declarative.** All 15 gates bind through
   `.planning/config.codex.json` (ADR-0007 point 5). No script executes it — the
   agent reads it. This is spec-legal: `spec/00:96-99` permits declarative hooks.
2. **Codex CLI has a native runtime hook surface, unused by this repo.** Codex
   0.144.4 ships `~/.codex/hooks.json` (`PreToolUse`/`PostToolUse`/`SessionStart`),
   a `[features] hooks = true` flag, a sha256 trust ledger, and
   `--dangerously-bypass-hook-trust`. It is global, not per-project.
3. **Upstream Codex GSD ships no `gsd-review`.** `get-shit-done-codex` installs 18
   prompts; `gsd-review` is not among them — the same gap ADR-0007 noted for
   `gsd-debug`. Binding upstream is not an option; the skill must be authored here.
4. **No `bin/gsd-tools.cjs` on Codex.** `~/.codex/get-shit-done/` holds
   references/workflows/templates only. The reference resolver's node-based state
   lookup has no codex analogue, which reduces the resolver from 5 steps to the
   spec's recommended 4.
5. **This repo's `.planning/phases/` is the pre-0005 bare-number layout**
   (`01/PLAN.md`, zero `*-SUMMARY.md` files), contrary to ADR-0007 point 4. Legacy
   `PLAN.md` does not match the `*-PLAN.md` glob, so legacy phases are currently
   grandfathered by accident of naming rather than by design.

## Decision

**Hybrid: declarative binding + a verifier script.** The binding in
`config.codex.json` stays the source of truth, consistent with the other 15 gates
and ADR-0007's thin-binding stance. A shell verifier supplies the programmatic
enforcement `spec/02:92-93` calls for, without inheriting the global-scope and
hook-trust problems a native `PreToolUse` hook would bring.

Rejected: **declarative-only** (declines the SHOULD; enforcement rests on agent
compliance — the exact failure ADR-0018 closes). Rejected: **native PreToolUse
hook** (global, so it fires in every repo and must self-scope; the trust ledger
forces a re-grant whenever the migration edits it; introduces a second mechanism
alongside the declarative one). The native hook is the documented upgrade path —
it can point at the same verifier later.

## Components

### 1. `skills/codex-plan-review/SKILL.md` — producer

Detects other-vendor CLIs (`claude`, `gemini`, `opencode`), excluding `codex`
itself since the implementing session is codex. Requires ≥2. Builds an
adversarial review prompt (plans + CONTEXT.md + spec citation), invokes each
reviewer, writes `<NN>-REVIEWS.md` with a per-reviewer provenance header (CLI,
model, timestamp).

With fewer than two reviewers available it reports and points at the escape
hatch. It never fabricates a reviewer, and never writes a one-reviewer file that
would satisfy a count check.

### 2. `skills/agentic-apps-workflow/scripts/check-plan-review.sh` — verifier

Referenced at the stable installed path
`${CODEX_HOME}/skills/agentic-apps-workflow/scripts/check-plan-review.sh`. The two
Unreleased migration-discovery fixes were both relative-path resolution bugs; this
follows the convention they established.

Resolution order, per `spec/02:97-99`:

| Step | Source |
|---|---|
| 1 | explicit pointer — `readlink .planning/current-phase` (absolute and `.planning/`-relative) |
| 2 | workflow state — `.planning/STATE.md` `## Current Phase`, awk, anchored on the Phase keyword |
| 3 | newest plan — `find -name '*-PLAN.md' -print0 \| xargs -0 ls -t \| head -1` |
| 4 | fail-open — nothing resolved → exit 0 |

Allow conditions, evaluated before the REVIEWS check:

| Condition | Rationale |
|---|---|
| legacy bare-number layout (`phases/<NN>/PLAN.md`) | pre-gate by definition; grandfathered explicitly, not by glob accident |
| `*-SUMMARY.md` present in resolved phase | phase already executed (core ADR-0025) |
| no `*-PLAN.md` at all | planning has not happened yet |

The legacy check is not redundant with step 3. Step 3's `*-PLAN.md` glob cannot
match a bare `PLAN.md`, so a legacy phase never resolves *through step 3* — but
steps 1 and 2 can resolve a legacy phase directory via the pointer or STATE.md.
The explicit check is what makes legacy grandfathering a stated rule rather than
an emergent property of a glob.

Otherwise: `*-REVIEWS.md` absent → **exit 2**, message naming both escape
hatches.

> **SUPERSEDED by `08-CONTEXT.md` D-13 (2026-07-14).** This section originally
> specified a loose verifier — existence and non-emptiness only — arguing that
> parsing reviewer count would couple the verifier to one producer's output
> format. That argument does not survive contact with the evidence: a real
> REVIEWS.md in `agenticapps-dashboard` shows the `reviewers: []` frontmatter is a
> **family-wide convention**, not a producer-specific format. The verifier
> therefore parses `reviewers:` and blocks below 2, falling back to the ≥5-line
> check only when frontmatter is absent. `min_reviewers` remains the producer's
> contract as well. See `08-CONTEXT.md` D-12/D-13/D-14 for the current rule.

### 3. Escape hatches

Both ported from the reference: `GSD_SKIP_REVIEWS=1` (session-level, emergency)
and a per-phase `multi-ai-review-skipped` marker file. These keep a machine
without two vendor CLIs from being hard-trapped by a gate it cannot satisfy.

### 4. Binding

New `pre_execution` group in `.planning/config.codex.json` **and** its template
`skills/setup-codex-agenticapps-workflow/templates/config-hooks.json`:

```json
"pre_execution": {
  "plan_review": {
    "skill": "codex-plan-review",
    "verifier": "${CODEX_HOME}/skills/agentic-apps-workflow/scripts/check-plan-review.sh",
    "fires_when": "phase has >=1 *-PLAN.md AND no *-SUMMARY.md exists",
    "evidence_artifact": "<NN>-REVIEWS.md",
    "min_reviewers": 2,
    "escape_hatches": ["GSD_SKIP_REVIEWS=1", "<phase>/multi-ai-review-skipped"]
  }
}
```

### 5. `AGENTS.md`

A Pre-execution section with the `plan-review` row, plus ritual text. The
duplicate `tdd` row collapses so the table reads 16 distinct gates, matching
`spec/02`.

### 6. Migration 0008 + ADR-0009

Migration 0008 is idempotent: `jq` merge of `pre_execution` (preserves existing
keys, skips if present); the AGENTS.md row extracted from the template rather than
a heredoc (single source of truth — the 0007 lesson); version bumps.
`implements_spec` is untouched.

ADR-0009 records the hybrid decision, both rejected alternatives, and names
Codex's native `PreToolUse` surface as the documented upgrade path.

## Testing

TDD — failing test first. `migrations/run-tests.sh` gains `test_migration_0008`
plus verifier tests against synthetic fixtures:

- each resolver step wins in its documented order
- fail-open when nothing resolves
- legacy layout allowed
- `*-SUMMARY.md` allowed
- plans without REVIEWS → exit 2
- REVIEWS present and non-empty → exit 0
- REVIEWS present but under the ≥5-line bar → exit 2 (an empty stub must not pass)
- both escape hatches
- migration second run is a no-op

Producer-side, `codex-plan-review` is tested separately for the `min_reviewers`
contract: fewer than two available CLIs must report and refuse, not emit a
one-reviewer REVIEWS.md.

## Consequences

- codex-workflow does not dogfood the gate on phases 00–07 — they stay legacy and
  grandfathered. Phase 08 (this work) is the first GSD-native phase, so it becomes
  the gate's first real test.
- The repo gains a soft dependency on other-vendor CLIs for producing REVIEWS.md.
  The escape hatches bound the blast radius.
- A second enforcement mechanism (verifier script) now sits alongside the
  declarative map. ADR-0009 records why, and when to collapse them.
