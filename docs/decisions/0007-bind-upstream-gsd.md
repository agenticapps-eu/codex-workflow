# ADR-0007 — Bind upstream GSD + Superpowers; stop re-porting

- Status: Accepted
- Date: 2026-07-01
- Phase: — (binding refactor)
- Implements spec: `agenticapps-workflow-core` v0.4.0
- Supersedes: [0003](0003-gsd-entry-points-as-prompts.md) (the re-port stance)
- Superseded by: —
- Standard: [`docs/standards/gsd-binding-and-planning.md`](../standards/gsd-binding-and-planning.md)

## Context

`codex-workflow` originally **re-ported** GSD: it shipped its own
`skills/gsd-discuss-phase` / `gsd-plan-phase` / `gsd-execute-phase` /
`gsd-debug` / `gsd-quick` (ADR-0003) plus Superpowers-duplicate gate skills
(`codex-brainstorming`, `codex-tdd`, `codex-verification`,
`codex-finishing-branch`, `codex-code-review`, `codex-systematic-debugging`).
It also used an **invented** `.planning/phases/<N>/…` project layout (a bare
phase number with bare `PLAN.md` / `VERIFICATION.md`), diverging from GSD's real
`.planning/phases/<NN>-<slug>/<NN>-…` layout.

That divergence had two costs:

1. **Two fast-moving upstreams tracked by hand.** GSD (TÂCHES lineage) and
   Superpowers already support Codex and evolve quickly. Re-porting means
   perpetually chasing them and drifting.
2. **Non-portable plans.** A three-host benchmark (Codex / opencode / Claude)
   confirmed three different `.planning/` layouts. Codex's invented
   `.planning/phases/<NN>/` meant its plan artifacts were not byte-compatible
   with the other hosts, breaking cross-host plan hand-off.

`claude-workflow` was never a re-port (it consumes public GSD + the Superpowers
plugin), and `opencode-workflow` moved from a re-port to a binding
(`opencode-workflow/docs/BINDING.md`). This ADR brings Codex into line with the
shared standard so all three hosts share one portable project plan.

## Decision

**`codex-workflow` is a thin binding, not a re-port.**

1. **Bind GSD** from `get-shit-done-codex` (RazvanBugoi, TÂCHES lineage;
   `npx get-shit-done-codex`, pick Global). It installs 18 GSD entry points as
   Codex **custom prompts** under `$CODEX_HOME/prompts`, invoked as
   `/prompts:gsd-*` (verified v1.4.1 on Codex CLI 0.142.0). This supersedes
   ADR-0003's premise that Codex has no `prompts/` idiom. (The brief named
   `get-shit-done-multi`, but that npm package — and its successor
   `get-shit-done-cc` — are deprecated.)
2. **Bind Superpowers** for Codex — the official `superpowers` Codex plugin
   (`codex plugin add superpowers`, openai-curated marketplace; verified v6.1.0).
   Codex plugins namespace skills as `plugin:skill`, so gates that duplicate
   Superpowers rebind to `superpowers:*`:
   - `brainstorm-{ui,architecture}` → `superpowers:brainstorming`
   - `tdd` → `superpowers:test-driven-development`
   - `verification` → `superpowers:verification-before-completion`
   - `code-review` → `superpowers:requesting-code-review`
   - `branch-close` → `superpowers:finishing-a-development-branch`
   - bug / unexpected-behavior tasks → `superpowers:systematic-debugging`
     directly (this GSD distribution ships no `gsd-debug` prompt)
3. **Remove** `skills/gsd-*` and the six Superpowers-duplicate `codex-*` gate
   skills.
4. **Adopt GSD's native phase-subdirectory layout** (get-shit-done v1.42.3):
   `.planning/phases/<NN>-<slug>/` holding `<NN>-CONTEXT.md`,
   `<NN>-<MM>-PLAN.md`, `<NN>-VERIFICATION.md`, `<NN>-<MM>-SUMMARY.md`, etc.,
   plus `PROJECT.md` / `REQUIREMENTS.md` / `ROADMAP.md` / `STATE.md`,
   `.planning/research/`, `.planning/quick/`. This replaces codex-workflow's
   earlier **invented** `.planning/phases/<N>/` variant (bare number, bare
   `PLAN.md`), which was not byte-compatible with GSD or the other hosts.
   AgenticApps artifacts (`REVIEW.md`, `QA.md`, `DB-AUDIT.md`,
   `IMPECCABLE-AUDIT.md`, `screenshots/`) are written **inside** the phase
   directory alongside GSD's files.
5. **Namespace the hook config** to `.planning/config.codex.json` (standard §4)
   so a codex + claude tree can coexist.

## What this repo still ships (the AgenticApps layer)

- `agentic-apps-workflow` — the spec-first trigger/router.
- gstack/AgenticApps gates with **no** GSD/Superpowers equivalent:
  `codex-cso`, `codex-qa`, `codex-design-shotgun`, `codex-design-critique`,
  `codex-database-sentinel-audit`, `codex-impeccable-audit`,
  `codex-spec-review`, `codex-ts-declare-first`.
- `setup-` / `update-codex-agenticapps-workflow` + the migration chain.

## Consequences

- **Delivered as a migration** (`migrations/0005-bind-upstream-gsd.md`,
  `to_version` 0.3.0), idempotent + rollback + fixture, since `codex-workflow`
  installs via migrations. The trigger skill `version:` bumps to `0.3.0`.
- **`install.sh`** now runs the GSD-multi installer and notes the Superpowers
  install (see `docs/BINDING.md`), with `--skip-upstream` to opt out.
- **Enforcement parity** (standard §6): medium/large tasks keep the mandatory
  independent code-review gate + ADR — now bound to
  `superpowers:requesting-code-review` rather than the removed
  `codex-code-review`.
- **Provenance kept.** ADR-0003 and the repo's historical `.planning/phases/**`
  remain as build-history provenance; only the *kept skills* and *fresh-install
  outputs* move to the GSD-native layout.

## Verified vs open

- **Verified (2026-07-01, Codex CLI 0.142.0).** (1) `get-shit-done-codex` v1.4.1
  installed → 18 `/prompts:gsd-*` prompts under `~/.codex/prompts/` + resources
  under `~/.codex/get-shit-done/`, and GSD writes the
  `.planning/phases/<NN>-<slug>/` layout (naming quirks `gsd-execute-plan`; no
  `gsd-quick`/`gsd-debug` reflected in the trigger routing). (2) Superpowers
  installed as the official `superpowers` Codex plugin (`codex plugin add
  superpowers`) → all six referenced gates resolve as `superpowers:<skill>`.
- **Open.** The live cross-host testbed hand-off (claude→codex on the shared
  `.planning/`). Mirrors the "Open verification" caveat in
  `opencode-workflow/docs/BINDING.md`.

## References

- Standard: `docs/standards/gsd-binding-and-planning.md`
- Mirror: `opencode-workflow/docs/BINDING.md`, `opencode-workflow/docs/decisions/0007-snapshot-install.md`
- Brief: `docs/briefs/bind-upstream-gsd-multi.md`
- Superseded: `docs/decisions/0003-gsd-entry-points-as-prompts.md`
