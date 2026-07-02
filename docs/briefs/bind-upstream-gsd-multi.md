# Brief — Bind codex-workflow to upstream GSD (get-shit-done-multi), stop porting

**Repo:** `codex-workflow` · **Type:** Claude Code / Codex execution brief
**Standard:** `docs/standards/gsd-binding-and-planning.md`
**Mirrors:** the `opencode-workflow` binding refactor (`docs/BINDING.md` there)

## Why

`codex-workflow` currently **re-ports GSD**: it ships its own
`gsd-discuss-phase` / `gsd-plan-phase` / `gsd-execute-phase` / `gsd-debug` /
`gsd-quick` skills (ADR-0003) using an invented layout `.planning/phases/<NN>/…`.
`claude-workflow` and `opencode-workflow` instead **bind** the maintained
upstream GSD distributions. That mismatch means codex's plan artifacts are not
portable to the other hosts (a benchmark confirmed three different `.planning/`
layouts). This brief brings codex into line with the shared standard.

## Goal

Make `codex-workflow` a **thin binding**, like `opencode-workflow`:

- **Bind** [`get-shit-done-multi`](https://github.com/shoootyou/get-shit-done-multi)
  in `--codex` mode (multi-CLI GSD with *unified project state*; requires Codex
  CLI ≥ 0.130.0). It installs the `$gsd-*` skills/agents under `~/.codex/skills`.
  (Alternative: `undeemed/get-shit-done-codex` if you prefer Codex-only vanilla.)
- **Remove** the custom `gsd-*` port; adopt GSD's native
  `.planning/phases/<NN>-<slug>/` layout per the standard §2 (codex's earlier
  **bare** `.planning/phases/<NN>/` — no slug — gains the `-<slug>` suffix).
- **Keep** only the AgenticApps layer: the spec-first trigger, the gstack/
  AgenticApps gates with no GSD/Superpowers equivalent (`codex-cso`, `codex-qa`,
  `codex-design-shotgun`, `codex-design-critique`,
  `codex-database-sentinel-audit`, `codex-impeccable-audit`, `codex-spec-review`,
  `codex-ts-declare-first`), snapshot install, and `AGENTS.md`.
- Also bind **Superpowers** for Codex (per the standard) and rebind the gate
  table entries that duplicate Superpowers to the upstream skills (mirror the
  opencode change: tdd → `superpowers:test-driven-development`, code-review →
  `superpowers:requesting-code-review`, brainstorming, verification,
  finishing-branch, systematic-debugging).

## Changes to make

Work through codex-workflow's own workflow (it self-applies). Run
`gitnexus_impact` before editing any symbol (this repo's CLAUDE.md).

1. **Remove the GSD port.** Delete `skills/gsd-*`. Rebind the trigger skill's
   task-size routing (`skills/agentic-apps-workflow/SKILL.md`) and
   `.planning/config.json` gate bindings so discuss/plan/execute/debug/quick
   point at the upstream `/gsd-*` commands (get-shit-done-multi), and the
   Superpowers-equivalent gates point at `superpowers:*`.
2. **Supersede ADR-0003.** Add `docs/decisions/NNNN-bind-upstream-gsd.md`
   marking ADR-0003 ("GSD entry points as skills") superseded, citing the
   shared standard.
3. **Adopt GSD's native `.planning/phases/<NN>-<slug>/` layout.** Replace the
   bare `.planning/phases/<NN>/` (no slug) references in the kept skills with the
   slugged form; read GSD-native artifacts *inside* the phase dir
   (`<NN>-CONTEXT.md`, `<NN>-<N>-PLAN.md`, `<NN>-VERIFICATION.md`), plus
   `PROJECT.md/REQUIREMENTS.md/ROADMAP.md/STATE.md`, `.planning/research`,
   `.planning/quick`. Do not reshape what GSD writes.
4. **Installer + config.** `install.sh` should run the GSD-multi installer
   (`npx get-shit-done-multi --codex` or the documented command) and note
   Superpowers install, mirroring `opencode-workflow/install.sh`'s "bind
   upstream" step. Namespace hook config to `.planning/config.codex.json` per
   the standard §4.
5. **Snapshot + migration.** codex-workflow installs via migrations today; ship
   this as a migration `NNNN-bind-upstream-gsd.md` (idempotency + rollback +
   fixture per `migrations/README.md`), bump the trigger skill `version:`, and
   update the setup templates so fresh projects bind rather than port. (Consider
   adopting the snapshot-install model too, matching claude/opencode — optional,
   separate brief.)
6. **Docs.** Add `docs/BINDING.md` (mirror opencode's) describing the three
   layers, install order, and the model/host specifics.

## Acceptance criteria

- No `skills/gsd-*` remain; gate table + `.planning/config.codex.json` reference
  `/gsd-*` (upstream) and `superpowers:*`; gstack/AgenticApps gates kept.
- A fresh codex install produces GSD-native `.planning/phases/<NN>-<slug>/`
  artifacts (slugged, not bare `.planning/phases/<NN>/`), byte-compatible with
  what claude/opencode produce.
- `docs/standards/gsd-binding-and-planning.md` conformance checklist passes.
- Migration has a green fixture; `gitnexus_detect_changes` shows only intended
  scope.
- The dual-host testbed can hand a plan from claude → codex (or opencode → codex)
  and the receiving host continues it from the shared `.planning/`.

## Non-goals

- Do not touch the gstack/AgenticApps gates' behavior (only their bindings where
  they duplicated Superpowers).
- Do not attempt codex + opencode in one working tree (standard §4: unsupported
  pair — both use `AGENTS.md`).
