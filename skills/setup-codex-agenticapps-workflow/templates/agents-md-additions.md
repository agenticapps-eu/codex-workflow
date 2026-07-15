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
| plan-review | `codex-plan-review` | pre-execution |
| brainstorm-ui | `superpowers:brainstorming` | pre-phase |
| brainstorm-architecture | `superpowers:brainstorming` | pre-phase |
| design-shotgun | `codex-design-shotgun` | pre-phase |
| design-critique | `codex-design-critique` | pre-phase |
| tdd | `superpowers:test-driven-development` (strengthened by `codex-ts-declare-first` for new TS modules) | per-task |
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

## Knowledge Capture — Ritual Tail (spec §15)

Transferable learnings must not die in a `.codex/session-handoff.md` that the
next session overwrites. This step routes them to a cross-repo memory: **one
Obsidian note per repo** in the operator's vault. It is the FINAL step of three
rituals — run it AFTER, never before, the ritual's own artifact exists:

1. **Session handoff** — after `.codex/session-handoff.md` is written.
2. **Plan completion** — after a plan is marked complete under `.planning/`
   (GSD `/prompts:gsd-plan-phase`).
3. **Phase completion** — after the phase artifacts are committed
   (GSD `/prompts:gsd-execute-plan`).

The vault write is machine-local: it MUST NEVER be committed to the repo, and
it MUST NEVER fail, block, or roll back the ritual that triggered it — on any
failure print one warning line and continue.

Procedure (mechanical — follow exactly):

1. **Read the config.** Open `.planning/config.json` — the shared, host-neutral
   file, NOT `.planning/config.codex.json` — and read its `knowledge_capture`
   object. **Skip** — print at most one line
   `knowledge-capture: skipped (<reason>)` and continue the ritual — when any
   holds:
   - `.planning/config.json` is absent, or has no `knowledge_capture` block, or
   - `knowledge_capture.enabled` is `false`, or
   - the parent folder of `knowledge_capture.note` does not exist (expand a
     leading `~` against `$HOME`).
   NEVER create the parent folder: an absent vault means "not this machine",
   not "set up the vault".
2. **Distill 1–5 transferable learnings** from the ritual just completed. A
   learning qualifies ONLY if it would change how you, another agent, or
   another host works next time: gotchas whose root cause generalizes; decision
   rationale with reusable trade-offs; tooling/workflow insights (what made the
   agent fast or slow); wrong assumptions and what corrected them. Status
   updates, restatements of the plan, repo facts already in
   ADRs/handoffs/CHANGELOGs, and filler do NOT qualify. **If nothing clears the
   bar, write nothing** — no empty entries, no placeholders.
3. **Create the note on first write.** If the `knowledge_capture.note` file
   does not exist, create it from the skeleton at
   `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/obsidian-learnings-note.md`
   (fill the `<...>` fields and the dates; `hosts:` starts as `[codex]`).
4. **Prepend a Log entry** at the TOP of `## Log` (append-only — never edit or
   delete existing entries) with a heading of exactly this shape, `codex` as
   the host tag:
   `### YYYY-MM-DD — <handoff|plan|phase> — <short title> (codex)`
   and the learnings as bullets beneath it.
5. **Curate `## Key Learnings`:** dedupe, merge related items, promote log
   entries that earned it, demote or remove stale ones. Target ~10–20
   highest-value items — each a bolded short title plus one to three sentences
   carrying the transferable insight, not the status.
6. **Update frontmatter:** set `updated:` to today's date; ensure `codex`
   appears in the `hosts:` list (add it, preserving any hosts already listed —
   e.g. `[claude]` becomes `[claude, codex]`).
7. **Report** in one or two lines what was written (or why the step skipped).

Vault safety (hard rules): touch ONLY the configured note — never other repos'
notes, the folder's `CLAUDE.md`, or anything else in the vault. Never write
secrets, tokens, URLs with embedded credentials, or client-confidential data;
redact before writing.

## Pre-execution Gate — Plan Review (spec §02)

Multi-AI plan review must run BEFORE execution begins. This gate exists
because agent compliance alone did not hold: core ADR-0018 records that
cparx phases 04.9 through 05 silently dropped this review for 8 consecutive
phases, with no program ever catching the omission.

Procedure (mechanical — follow exactly):

1. **When** — before the FIRST code-touching edit of a phase. Not before
   `.planning/` artifact edits; not once per edit.
2. **Run the verifier** at the stable installed path
   `${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/check-plan-review.sh`.
   Always this path — never a path read out of the target repo's own config,
   and never a relative path. The verifier locates the repo root itself, so
   invoke it from wherever you are: no working-directory precondition applies.
3. **Run it every time. Do not pre-judge whether it applies.** The agent's
   job is to invoke. The verifier's job is to decide.
4. **Exit 0 → proceed. Exit 2 → HARD STOP.** Do not edit code. Do not
   auto-invoke external reviewers on your own initiative — that would ship
   plan content to other vendors without consent. The verifier prints the
   remedy; surface it to the operator and wait.
5. **The remedy** is the `codex-plan-review` skill, which writes
   `<NN>-REVIEWS.md` with at least 2 independent external reviewers.

**The verifier decides these for you** — you do not need to check any of
these; run the script and it will exit 0 on its own when:
- `GSD_SKIP_REVIEWS=1` is set, or a `multi-ai-review-skipped` marker exists
  in the phase directory (both emergency-only, both announce themselves)
- the phase is legacy bare-number layout, already shipped (a `*-SUMMARY.md`
  is present), has no `*-PLAN.md` at all, or nothing resolves

Both `GSD_SKIP_REVIEWS` and the `multi-ai-review-skipped` marker are
emergency-only escape hatches: each announces itself, and the marker file is
visible to `git status` and expected to be committed with a rationale. A
hatch is an auditable decision, not a silent bypass.

<!-- END: agentic-apps-workflow sections -->
