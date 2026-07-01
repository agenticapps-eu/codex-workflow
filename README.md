# codex-workflow

OpenAI Codex CLI binding of the AgenticApps spec-first workflow.

This repo is the Codex peer of [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow),
[`opencode-workflow`](https://github.com/agenticapps-eu/opencode-workflow), and
[`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow).
It implements the canonical contract defined in
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
and, as of v0.3.0, is a **thin binding** over upstream GSD + Superpowers
rather than a re-port — see [`docs/BINDING.md`](docs/BINDING.md).

## Status

**v0.3.0 / `agenticapps-workflow-core` spec 0.4.0 — shipped.** `codex-workflow`
now **binds** the maintained upstreams instead of porting them
([ADR-0007](docs/decisions/0007-bind-upstream-gsd.md), standard
[`docs/standards/gsd-binding-and-planning.md`](docs/standards/gsd-binding-and-planning.md)):
GSD from `get-shit-done-multi --codex` (the `$gsd-*` Codex skills; Codex CLI
≥ 0.130.0) and Superpowers from its Codex distribution. The re-ported `gsd-*`
skills and the six Superpowers-duplicate `codex-*` gates were removed; their
gate bindings now point at `superpowers:*`. Project state follows GSD's native
flat `.planning/` layout, and the hook config is namespaced to
`.planning/config.codex.json` so a codex + claude tree can coexist. The
scaffolder self-applies its own workflow.

Earlier: v0.2.1 (spec 0.4.0) absorbed §11 Coding Discipline, §13 declare-first
TypeScript, §12 authoring conventions, and §10 observability — see CHANGELOG.

See `docs/decisions/` for architecture decisions, `docs/BINDING.md` for the
three-layer binding, `docs/ENFORCEMENT-PLAN.md` for the gate-to-skill bindings
on this scaffolder's own development, and `CHANGELOG.md` for the artifact
inventory at each tag.

## What ships at v0.3.0 (spec 0.4.0)

The AgenticApps layer only — GSD (`$gsd-*`) and Superpowers (`superpowers:*`)
are bound from upstream (see `docs/BINDING.md`).

- **Trigger skill** (`agentic-apps-workflow`) — activates on any code
  task, emits the canonical commitment ritual, routes to the right
  gate skills; reproduces the four canonical-prose blocks verbatim
  (incl. §11 Coding Discipline in `AGENTS.md`)
- **8 gstack/AgenticApps gate skills** (`codex-*`) with no GSD/Superpowers
  equivalent — `codex-cso`, `codex-qa` (per-task ui-preview + post-phase qa),
  `codex-design-shotgun`, `codex-design-critique`,
  `codex-database-sentinel-audit`, `codex-impeccable-audit`,
  `codex-spec-review`, and **declare-first TypeScript** (`codex-ts-declare-first`, §13)
- **Bound upstreams** — GSD entry points `$gsd-discuss-phase` /
  `$gsd-plan-phase` / `$gsd-execute-phase` / `$gsd-quick` / `$gsd-debug`
  (from `get-shit-done-multi --codex`) and the Superpowers discipline skills
  (`superpowers:*`). Not shipped by this repo.
- **§10 observability** — delegated to `agenticapps-observability`
  (installed on Codex via its `install-codex.sh`); wired by migration
  `0003`. See `docs/observability-delegation.md`
- **2 lifecycle skills** (`setup-codex-agenticapps-workflow`,
  `update-codex-agenticapps-workflow`) — bootstrap and migrate a
  project's AGENTS.md / `.planning/` / `.codex/` configuration
- **Migration framework** — implements
  `agenticapps-workflow-core/spec/08-migration-format.md`; ships
  `0000-baseline.md` … `0005-bind-upstream-gsd.md` (contiguous
  chain), fixture-based test harness with a drift test, atomicity +
  idempotency contracts
- **Templates** (under `skills/setup-codex-agenticapps-workflow/templates/`)
  — `agents-md-additions.md`, `workflow-config.md`, `config-hooks.json`,
  `adr-db-security-acceptance.md`, `global-agents-additions.md`,
  `spec-mirrors/`
- **`install.sh`** — symlinks the skills into `$CODEX_HOME/skills/`
  (templates ship inside the setup skill — no secondary symlink); binds the
  upstream GSD + Superpowers distributions (`--skip-upstream` to opt out);
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
├── install.sh                  # symlinks skills/ + binds upstream GSD/Superpowers
├── skills/                     # 1 trigger + 8 gstack gates + 2 lifecycle = 11 (GSD/Superpowers bound from upstream)
│   └── setup-codex-agenticapps-workflow/templates/  # project-side templates + spec-mirrors
├── migrations/                 # framework + 0000…0005 + run-tests.sh
├── vendor/agenticapps-shared/  # submodule — shared migration test harness
├── docs/
│   ├── BINDING.md              # the three-layer binding (GSD + Superpowers + AgenticApps)
│   ├── standards/gsd-binding-and-planning.md  # shared cross-host standard
│   ├── ENFORCEMENT-PLAN.md     # gate bindings for this scaffolder's own dev
│   ├── observability-delegation.md  # §10 delegation setup/use guidance
│   ├── dogfood-2026-05-10.md   # Phase 6 self-apply log
│   └── decisions/              # ADRs (0001–0007; 0003 superseded by 0007)
└── .github/workflows/ci.yml    # CI
```

## License

MIT
