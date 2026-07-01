<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Development Workflow

This project uses the AgenticApps spec-first workflow on the OpenAI
Codex CLI host. The trigger skill `agentic-apps-workflow` activates
on every code-touching task and emits the canonical commitment
ritual before any tool call. See
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
for the spec, [`codex-workflow`](https://github.com/agenticapps-eu/codex-workflow)
for the host-specific binding.

The version of `codex-workflow` this project was set up against is
recorded at `.codex/workflow-version.txt`.

## Workflow Enforcement Hooks (MANDATORY)

The `agentic-apps-workflow` trigger skill binds every spec/02 gate
to an upstream `superpowers:*` skill or a `codex-*` gate skill. GSD
(`/prompts:gsd-*` Codex prompts) and Superpowers are bound from upstream — this repo is a
thin binding, not a re-port (see `codex-workflow/docs/BINDING.md`).
Project-specific gate bindings live in `.planning/config.codex.json`.
Do not bypass a gate — accept-via-ADR is the override path.

| Gate | Bound skill | Scope |
|---|---|---|
| brainstorm-ui / brainstorm-architecture | `superpowers:brainstorming` | pre-phase |
| design-shotgun | `codex-design-shotgun` | pre-phase |
| design-critique | `codex-design-critique` | pre-phase |
| tdd | `superpowers:test-driven-development` | per-task |
| tdd (new TS module) | `codex-ts-declare-first` | per-task |
| ui-preview | `codex-qa` (preview mode) | per-task |
| verification | `superpowers:verification-before-completion` | per-task |
| spec-review | `codex-spec-review` | post-phase |
| code-review | `superpowers:requesting-code-review` | post-phase |
| security | `codex-cso` | post-phase |
| database-security | `codex-database-sentinel-audit` | post-phase |
| qa | `codex-qa` | post-phase |
| impeccable-audit | `codex-impeccable-audit` | post-phase |
| db-pre-launch-audit | `codex-database-sentinel-audit` | finishing |
| branch-close | `superpowers:finishing-a-development-branch` | finishing |

## Skill routing

For any task, route through the trigger skill's task-size table:

- **Tiny** (typo, comment, README) → `superpowers:verification-before-completion`
- **Small** (single-file logic) → `superpowers:test-driven-development` → `superpowers:verification-before-completion` → `superpowers:finishing-a-development-branch`
- **Medium** (multi-file feature) → `/prompts:gsd-discuss-phase` → `/prompts:gsd-plan-phase` → `/prompts:gsd-execute-plan`; the Stage-2 `superpowers:requesting-code-review` gate and an ADR for any locked decision are mandatory
- **Large** (cross-cutting) → same as medium plus `codex-cso`,
  `codex-database-sentinel-audit`, `codex-impeccable-audit` per
  applicable gates

Bug reports route directly through `superpowers:systematic-debugging`
(this GSD distribution ships no `gsd-debug` prompt; the four-phase
Observe → Hypothesize → Test → Conclude protocol).

## Session handoff

At the start of every session, check for `.codex/session-handoff.md`.
If it exists and was modified in the last 7 days, read it before doing
anything else and confirm what was found. **Only read the codex
handoff** — do NOT read a bare root `session-handoff.md` or another
host's handoff (e.g. `.opencode/session-handoff.md`); handoffs are
host-scoped so multiple hosts can share one working tree without
cross-contaminating context.

Before ending any session — when asked to exit, when the final
task is done, or when context is getting full — write
`.codex/session-handoff.md`. Format:

```markdown
# Session Handoff — YYYY-MM-DD

## Accomplished
- ...

## Decisions
- decision — why

## Files modified
- path — what changed

## Next session: start here
One paragraph on exactly where to pick up and what the first
action should be.

## Open questions
- ...
```

Keep it under 150 lines. Write the file directly — do not print
it to the terminal. This file survives session boundaries and is
the primary continuity mechanism across sessions.

<!-- END: agentic-apps-workflow sections -->
