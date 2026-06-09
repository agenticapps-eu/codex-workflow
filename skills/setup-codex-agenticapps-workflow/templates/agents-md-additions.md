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
to a `codex-*` skill. Project-specific gate bindings live in
`.planning/config.json`. Do not bypass a gate — accept-via-ADR is
the override path.

| Gate | Bound skill | Scope |
|---|---|---|
| brainstorm-ui / brainstorm-architecture | `codex-brainstorming` | pre-phase |
| design-shotgun | `codex-design-shotgun` | pre-phase |
| design-critique | `codex-design-critique` | pre-phase |
| tdd | `codex-tdd` | per-task |
| ui-preview | `codex-qa` (preview mode) | per-task |
| verification | `codex-verification` | per-task |
| spec-review | `codex-spec-review` | post-phase |
| code-review | `codex-code-review` | post-phase |
| security | `codex-cso` | post-phase |
| database-security | `codex-database-sentinel-audit` | post-phase |
| qa | `codex-qa` | post-phase |
| impeccable-audit | `codex-impeccable-audit` | post-phase |
| db-pre-launch-audit | `codex-database-sentinel-audit` | finishing |
| branch-close | `codex-finishing-branch` | finishing |

## Skill routing

For any task, route through the trigger skill's task-size table:

- **Tiny** (typo, comment, README) → `codex-verification`
- **Small** (single-file logic) → `codex-tdd` → `codex-verification` → `codex-finishing-branch`
- **Medium** (multi-file feature) → `$gsd-discuss-phase` → `$gsd-plan-phase` → `$gsd-execute-phase`
- **Large** (cross-cutting) → same as medium plus `codex-cso`,
  `codex-database-sentinel-audit`, `codex-impeccable-audit` per
  applicable gates

Bug reports route through `$gsd-debug` (the four-phase
Observe → Hypothesize → Test → Conclude protocol).

## Session handoff

At the start of every session, check for `session-handoff.md` in
the project root. If it exists and was modified in the last 7
days, read it before doing anything else and confirm what was
found.

Before ending any session — when asked to exit, when the final
task is done, or when context is getting full — write a
`session-handoff.md` in the project root. Format:

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
