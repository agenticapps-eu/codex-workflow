# codex-workflow

OpenAI Codex CLI port of the AgenticApps spec-first workflow.

This repo is the Codex peer of [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow)
and [`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow).
It implements the canonical contract defined in
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
as native Codex skills.

## Status

**Pre-v0.1.0 — Phases 0–6 complete; tag pending Phase 7.** The
trigger skill, 13 gate skills, 5 GSD entry-point skills, 2 lifecycle
skills, migration framework, templates, and `install.sh` are all
shipped against `agenticapps-workflow-core` v0.1.0. The scaffolder
self-applies its own workflow per `docs/dogfood-2026-05-10.md`.

See `docs/decisions/` for architecture decisions, `docs/ENFORCEMENT-PLAN.md`
for the gate-to-skill bindings on this scaffolder's own development,
and `CHANGELOG.md` for the artifact inventory at each tag.

## What ships at v0.1.0

- **Trigger skill** (`agentic-apps-workflow`) — activates on any code
  task, emits the canonical commitment ritual, routes to the right
  gate skills
- **13 gate skills** (`codex-*`) — native Codex implementations of
  TDD, verification, two-stage review, brainstorming,
  design-shotgun, design-critique, CSO security, QA (with both
  per-task ui-preview and post-phase qa modes), impeccable-audit,
  database-sentinel-audit, systematic-debugging, finishing-branch
- **5 GSD entry-point skills** (`gsd-*`) — explicit-only
  (`policy.allow_implicit_invocation: false`); see
  `docs/decisions/0003-gsd-entry-points-as-prompts.md` for why these
  are skills, not a separate `prompts/` surface
- **2 lifecycle skills** (`setup-codex-agenticapps-workflow`,
  `update-codex-agenticapps-workflow`) — bootstrap and migrate a
  project's AGENTS.md / `.planning/` / `.codex/` configuration
- **Migration framework** — implements
  `agenticapps-workflow-core/spec/08-migration-format.md`; ships
  `0000-baseline.md`, fixture-based test harness, atomicity +
  idempotency contracts
- **Templates** — `agents-md-additions.md`, `workflow-config.md`,
  `config-hooks.json`, `adr-db-security-acceptance.md`,
  `global-agents-additions.md`
- **`install.sh`** — symlinks the skills + templates into
  `$CODEX_HOME/skills/`; idempotent; `--copy` and `--dry-run` flags

Every shipped artifact cites `implements_spec: 0.1.0` so conformance
is auditable.

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
├── skills/                     # 1 trigger + 13 gate + 5 GSD + 2 lifecycle = 21
├── templates/                  # 5 project-side templates
├── migrations/                 # framework + 0000-baseline + run-tests.sh
├── docs/
│   ├── ENFORCEMENT-PLAN.md     # gate bindings for this scaffolder's own dev
│   ├── dogfood-2026-05-10.md   # Phase 6 self-apply log
│   └── decisions/              # ADRs (0001–0003)
└── .github/workflows/ci.yml    # CI (trivial until Phase 7)
```

## License

MIT
