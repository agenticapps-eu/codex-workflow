# AGENTS.md — codex-workflow

This is the **scaffolder repo** that ships the AgenticApps spec-first
workflow for the OpenAI Codex CLI host. It self-applies its own
workflow per Phase 6 of the build-out.

The trigger skill, gate skills, GSD entry points, and lifecycle skills
this repo authors are linked into `${CODEX_HOME:-$HOME/.codex}/skills/`
via `install.sh` (run from this repo's root). Codex auto-discovers
them on next session start.

The version of `codex-workflow` this repo's own development is
asserted against is recorded at `.codex/workflow-version.txt`.

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Development Workflow

This repo uses the AgenticApps spec-first workflow on the OpenAI
Codex CLI host. The trigger skill `agentic-apps-workflow` activates
on every code-touching task and emits the canonical commitment
ritual before any tool call. See
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
for the spec, this repo for the host-specific binding.

The version of `codex-workflow` this project was set up against is
recorded at `.codex/workflow-version.txt`.

## Workflow Enforcement Hooks (MANDATORY)

The `agentic-apps-workflow` trigger skill binds every spec/02 gate
to a `codex-*` skill. Project-specific gate bindings live in
`.planning/config.json`. Do not bypass a gate — accept-via-ADR is
the override path. Gates that do not apply to this scaffolder repo
(no UI, no DB, no auth) are documented in `docs/ENFORCEMENT-PLAN.md`
with the rationale.

| Gate | Bound skill | Applies to scaffolder? |
|---|---|---|
| brainstorm-ui | `codex-brainstorming` | No (no UI) |
| brainstorm-architecture | `codex-brainstorming` | Yes (when adding skills/templates/migrations) |
| design-shotgun | `codex-design-shotgun` | No (no UI) |
| design-critique | `codex-design-critique` | No (no UI) |
| tdd | `codex-tdd` | Yes (any logic in `install.sh` / `run-tests.sh`) |
| ui-preview | `codex-qa` (preview mode) | No (no UI) |
| verification | `codex-verification` | Yes (always) |
| spec-review | `codex-spec-review` | Yes (always) |
| code-review | `codex-code-review` | Yes (always) |
| security | `codex-cso` | Yes (executable scripts) |
| database-security | `codex-database-sentinel-audit` | No (no DB) |
| qa | `codex-qa` | No (no dev server) |
| impeccable-audit | `codex-impeccable-audit` | No (no UI) |
| db-pre-launch-audit | `codex-database-sentinel-audit` | No (no DB) |
| branch-close | `codex-finishing-branch` | Yes (always) |

## Skill routing

For any task in this scaffolder repo, route through the trigger
skill's task-size table:

- **Tiny** (typo, comment, README) → `codex-verification`
- **Small** (single-file logic) → `codex-tdd` → `codex-verification` → `codex-finishing-branch`
- **Medium** (new skill, new template, new migration) → `$gsd-discuss-phase` → `$gsd-plan-phase` → `$gsd-execute-phase`
- **Large** (cross-cutting refactor, new lifecycle, breaking changes) → same as medium plus `codex-cso` for any security-sensitive scripts

Bug reports route through `$gsd-debug` (the four-phase
Observe → Hypothesize → Test → Conclude protocol).

## Session handoff

At the start of every session, check for `session-handoff.md` in
the repo root. If it exists and was modified in the last 7 days,
read it before doing anything else and confirm what was found.

Before ending any session — when asked to exit, when the final
task is done, or when context is getting full — write a
`session-handoff.md` in the repo root. The file is in `.gitignore`
because it is a working artifact for cross-session continuity, not
a shipped scaffolder artifact.

<!-- END: agentic-apps-workflow sections -->
