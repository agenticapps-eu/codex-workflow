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

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **codex-workflow** (372 symbols, 372 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/codex-workflow/context` | Codebase overview, check index freshness |
| `gitnexus://repo/codex-workflow/clusters` | All functional areas |
| `gitnexus://repo/codex-workflow/processes` | All execution flows |
| `gitnexus://repo/codex-workflow/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
