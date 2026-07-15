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

<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->
## Coding Discipline (NON-NEGOTIABLE)

These four rules are reread every session because the failure modes
they prevent recur every session.

### 1. Think Before Coding

State assumptions explicitly before writing any line. When the request
is ambiguous, present the alternative interpretations and ask which
applies. When the request contradicts itself, surface the contradiction
rather than silently picking one side. When you are confused, stop and
ask — confusion is signal, not friction.

Anti-patterns this rule prevents:

- Diving into implementation without restating what was actually requested.
- Picking one reading of an ambiguous instruction silently and shipping it.
- Treating two contradictory requirements as if both can be satisfied without comment.
- Treating "I'll figure it out as I go" as a substitute for understanding the goal.
- Generating code first and asking clarifying questions only after a failure.

### 2. Simplicity First

Write the smallest thing that satisfies the request. No features
beyond what was asked. No abstractions for code with one caller. No
flexibility for callers that do not exist. No error handling for
scenarios that cannot occur given the code's invariants. The
senior-engineer test: would a senior engineer reviewing this say it is
overcomplicated for what was asked?

Anti-patterns this rule prevents:

- Adding a helper function "in case we need to call this from elsewhere later."
- Introducing a configuration option for behavior that has one consumer.
- Wrapping internal calls in try/catch when no internal caller throws.
- Designing for a hypothetical second consumer that does not exist.
- Replacing three similar lines with a parameterised abstraction.
- Shipping a "framework" when a function would do.

### 3. Surgical Changes

Touch only what you must to satisfy the task. Adjacent code is out of
scope. Match the existing style of the file you are editing rather than
the style you would have chosen. Clean up only the orphans your own
change created. If you notice an unrelated improvement, leave it as a
follow-up note, not a diff.

Anti-patterns this rule prevents:

- Reformatting untouched lines to "fix style" while editing nearby.
- Refactoring a function that the task did not name.
- Renaming a variable across the file because the new name is "better."
- Deleting code you decided is unused without verifying it has no callers.
- Pulling adjacent code into the diff because "while I'm here."
- Bundling a cleanup pass into a feature commit.

### 4. Goal-Driven Execution

Every task is a goal, not a list of imperative steps. Restate the goal
in a form that is verifiable from on-disk artifacts before writing any
code. For bug fixes: write the failing test that reproduces the bug
first, then make it pass. For performance work: capture the measurement
first, then change the code, then capture it again. For behavioral
changes: define the assertion the diff must satisfy before the diff
exists. "Done" is "the goal is verifiably satisfied," not "the code now
exists."

Anti-patterns this rule prevents:

- "Fix the bug" without a failing test that reproduces it.
- "Improve performance" without a measurement before and a measurement after.
- "Make it work" without a definition of "work" the diff can be checked against.
- Marking a task complete on the basis of "the code now exists" rather than "the goal is satisfied."
- Writing implementation before there is anything that can fail to confirm the goal is met.

These four rules apply to every code-touching turn. They do not
replace the commitment ritual, the rationalisation table, the red
flags, or the evidence rules — they sit alongside them as the
session-level discipline the model brings to every diff.

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
to an upstream `superpowers:*` skill or a `codex-*` gate skill. GSD
(`/prompts:gsd-*` Codex prompts) and Superpowers are bound from upstream — this repo is a
thin binding, not a re-port (see [`docs/BINDING.md`](docs/BINDING.md)
and [ADR-0007](docs/decisions/0007-bind-upstream-gsd.md)).
Project-specific gate bindings live in `.planning/config.codex.json`.
Do not bypass a gate — accept-via-ADR is the override path. Gates that
do not apply to this scaffolder repo (no UI, no DB, no auth) are
documented in `docs/ENFORCEMENT-PLAN.md` with the rationale.

| Gate | Bound skill | Applies to scaffolder? |
|---|---|---|
| plan-review | `codex-plan-review` | Yes (always — enforced from phase 09 onward) |
| brainstorm-ui | `superpowers:brainstorming` | No (no UI) |
| brainstorm-architecture | `superpowers:brainstorming` | Yes (when adding skills/templates/migrations) |
| design-shotgun | `codex-design-shotgun` | No (no UI) |
| design-critique | `codex-design-critique` | No (no UI) |
| tdd | `superpowers:test-driven-development` (strengthened by `codex-ts-declare-first` for new TS modules) | Yes (any logic in `install.sh` / `run-tests.sh`; TS-module strengthening applies when adding a TS module API) |
| ui-preview | `codex-qa` (preview mode) | No (no UI) |
| verification | `superpowers:verification-before-completion` | Yes (always) |
| spec-review | `codex-spec-review` | Yes (always) |
| code-review | `superpowers:requesting-code-review` | Yes (always) |
| security | `codex-cso` | Yes (executable scripts) |
| database-security | `codex-database-sentinel-audit` | No (no DB) |
| qa | `codex-qa` | No (no dev server) |
| impeccable-audit | `codex-impeccable-audit` | No (no UI) |
| db-pre-launch-audit | `codex-database-sentinel-audit` | No (no DB) |
| branch-close | `superpowers:finishing-a-development-branch` | Yes (always) |

## Skill routing

For any task in this scaffolder repo, route through the trigger
skill's task-size table:

- **Tiny** (typo, comment, README) → `superpowers:verification-before-completion`
- **Small** (single-file logic) → `superpowers:test-driven-development` → `superpowers:verification-before-completion` → `superpowers:finishing-a-development-branch`
- **Medium** (new skill, new template, new migration) → `/prompts:gsd-discuss-phase` → `/prompts:gsd-plan-phase` → `/prompts:gsd-execute-plan`; the Stage-2 `superpowers:requesting-code-review` gate and an ADR for any locked decision are mandatory
- **Large** (cross-cutting refactor, new lifecycle, breaking changes) → same as medium plus `codex-cso` for any security-sensitive scripts

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
`.codex/session-handoff.md`. The file is in `.gitignore`
because it is a working artifact for cross-session continuity, not
a shipped scaffolder artifact.

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
