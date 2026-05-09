# codex-workflow

OpenAI Codex CLI port of the AgenticApps spec-first workflow.

This repo is the Codex peer of [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow)
and [`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow).
It implements the canonical contract defined in
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
as native Codex skills.

## Status

**Pre-v0.1.0 — Phase 0 (research) complete; awaiting `agenticapps-workflow-core` v0.1.0
before authoring the trigger skill and gate skills.**

See `docs/decisions/` for Phase 0 architecture decisions and
`CHANGELOG.md` for the artifact inventory at each tag.

## What ships at v0.1.0

When core is ready and v0.1.0 is cut, this repo will ship:

- A trigger skill (`agentic-apps-workflow`) that activates on any code task,
  emits the canonical commitment ritual, and routes to the right gate skills
- Native Codex re-authors of the gate skills (brainstorming, TDD,
  verification, two-stage review, design, security, QA, debugging, branch
  finishing, impeccable + database-sentinel audits)
- GSD entry-point skills (`gsd-discuss-phase`, `gsd-plan-phase`,
  `gsd-execute-phase`, `gsd-quick`, `gsd-debug`) — see
  `docs/decisions/0003-gsd-entry-points-as-prompts.md` for why these are
  skills rather than a separate prompts surface
- Setup and update skills that bootstrap and migrate a project's
  `AGENTS.md` and `.planning/` configuration
- A migration framework that codifies the install state and applies
  versioned upgrades

Every shipped artifact will cite `implements_spec: <core-version>` so
conformance is auditable.

## Layout (Phase 0)

```
codex-workflow/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── AGENTS.md                   # populated in Phase 6 when self-applied
├── .github/workflows/ci.yml    # trivial until Phase 7
└── docs/
    └── decisions/
        ├── 0001-codex-skill-naming.md
        ├── 0002-stage2-independent-reviewer-on-codex.md
        └── 0003-gsd-entry-points-as-prompts.md
```

## License

MIT
