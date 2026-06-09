# codex-workflow

OpenAI Codex CLI port of the AgenticApps spec-first workflow.

This repo is the Codex peer of [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow)
and [`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow).
It implements the canonical contract defined in
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
as native Codex skills.

## Status

**v0.2.0 / `agenticapps-workflow-core` spec 0.4.0 — catch-up complete
(tag pending Phase 7).** Builds on v0.1.0 (full conformance to spec
0.1.0) by absorbing the 0.2.0→0.4.0 spec deltas: **§11 Coding
Discipline** (canonical prose in `AGENTS.md`), **§13 declare-first
TypeScript** (`codex-ts-declare-first`), **§12 authoring conventions**
(surgical Mermaid), and **§10 observability** (delegated to the
standalone `agenticapps-observability` skill). The trigger skill, 14
gate skills, 5 GSD entry-point skills, 2 lifecycle skills, migration
framework (`0000`–`0003`), templates, and `install.sh` cite
`implements_spec: 0.4.0`. The scaffolder self-applies its own workflow.

See `docs/decisions/` for architecture decisions, `docs/ENFORCEMENT-PLAN.md`
for the gate-to-skill bindings on this scaffolder's own development,
and `CHANGELOG.md` for the artifact inventory at each tag.

## What ships at v0.2.0 (spec 0.4.0)

- **Trigger skill** (`agentic-apps-workflow`) — activates on any code
  task, emits the canonical commitment ritual, routes to the right
  gate skills; reproduces the **five** canonical-prose blocks verbatim
  (incl. §11 Coding Discipline in `AGENTS.md`)
- **14 gate skills** (`codex-*`) — native Codex implementations of
  TDD, **declare-first TypeScript (`codex-ts-declare-first`, §13)**,
  verification, two-stage review, brainstorming,
  design-shotgun, design-critique, CSO security, QA (with both
  per-task ui-preview and post-phase qa modes), impeccable-audit,
  database-sentinel-audit, systematic-debugging, finishing-branch
- **§10 observability** — delegated to `agenticapps-observability`
  (installed on Codex via its `install-codex.sh`); wired by migration
  `0003`. See `docs/observability-delegation.md`
- **5 GSD entry-point skills** (`gsd-*`) — explicit-only
  (`policy.allow_implicit_invocation: false`); see
  `docs/decisions/0003-gsd-entry-points-as-prompts.md` for why these
  are skills, not a separate `prompts/` surface
- **2 lifecycle skills** (`setup-codex-agenticapps-workflow`,
  `update-codex-agenticapps-workflow`) — bootstrap and migrate a
  project's AGENTS.md / `.planning/` / `.codex/` configuration
- **Migration framework** — implements
  `agenticapps-workflow-core/spec/08-migration-format.md`; ships
  `0000-baseline.md` … `0003-delegate-observability.md` (contiguous
  chain), fixture-based test harness with a drift test, atomicity +
  idempotency contracts
- **Templates** (under `skills/setup-codex-agenticapps-workflow/templates/`)
  — `agents-md-additions.md`, `workflow-config.md`, `config-hooks.json`,
  `adr-db-security-acceptance.md`, `global-agents-additions.md`,
  `spec-mirrors/`
- **`install.sh`** — symlinks the skills into `$CODEX_HOME/skills/`
  (templates ship inside the setup skill — no secondary symlink);
  refreshes the `agenticapps-shared` submodule; idempotent; repoints stale/
  dangling links; `--copy` and `--dry-run` flags

Every shipped artifact cites `implements_spec: 0.4.0` so conformance
is auditable.

## Consumes

- [`agenticapps-shared`](https://github.com/agenticapps-eu/agenticapps-shared)
  as a git submodule at `vendor/agenticapps-shared/` — the shared migration
  test-harness primitives (helpers, fixture-runner, drift-test). SPLIT-01
  parity with claude-workflow + agenticapps-observability.
- [`agenticapps-observability`](https://github.com/agenticapps-eu/agenticapps-observability)
  — the §10 observability generator, consumed by delegation (see
  `docs/observability-delegation.md`).

## Install

```bash
git clone https://github.com/agenticapps-eu/codex-workflow ~/Sourcecode/codex-workflow
cd ~/Sourcecode/codex-workflow
bash install.sh
# Restart Codex (or open a fresh session) to pick up the new skills.
```

Then in a fresh project: `$setup-codex-agenticapps-workflow`. In an
existing installed project, `$update-codex-agenticapps-workflow`.

## Layout

```
codex-workflow/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── AGENTS.md                   # workflow self-applied (Phase 6)
├── install.sh                  # symlinks skills/ into $CODEX_HOME/skills/
├── skills/                     # 1 trigger + 14 gate + 5 GSD + 2 lifecycle = 22
│   └── setup-codex-agenticapps-workflow/templates/  # project-side templates + spec-mirrors
├── migrations/                 # framework + 0000…0003 + run-tests.sh
├── vendor/agenticapps-shared/  # submodule — shared migration test harness
├── docs/
│   ├── ENFORCEMENT-PLAN.md     # gate bindings for this scaffolder's own dev
│   ├── observability-delegation.md  # §10 delegation setup/use guidance
│   ├── dogfood-2026-05-10.md   # Phase 6 self-apply log
│   └── decisions/              # ADRs (0001–0006)
└── .github/workflows/ci.yml    # CI
```

## License

MIT
