---
name: gsd-discuss-phase
version: 0.1.0
implements_spec: 0.4.0
description: |
  Run the GSD discuss step for a phase: surface open questions,
  assumptions, and ambiguities; ask the user just enough to fill the
  gaps; write the answers to CONTEXT.md so they survive into Phase
  Plan and Phase Execute. Use as the first step on any medium or
  large task — typed by the user as `$gsd-discuss-phase {N}` where
  `{N}` is the phase number from `ROADMAP.md`. Explicit-only
  (`policy.allow_implicit_invocation: false` in `agents/openai.yaml`).
---

# gsd-discuss-phase

This is the first GSD entry-point skill. It does NOT bind to a spec
gate; it produces the upstream artifact (`CONTEXT.md`) that the
brainstorm and design gates consume.

## When to invoke

User types `$gsd-discuss-phase {N}` (or invokes via the trigger
skill's Step 2 routing for a medium/large task). `{N}` matches a
phase entry in `ROADMAP.md`.

Per ADR-0003 this skill is explicit-only. The `agents/openai.yaml`
sets `policy.allow_implicit_invocation: false` so it does not
auto-load on every code task — only when the user names it.

## What this skill does

1. **Locate the phase.** Read `ROADMAP.md` (or the project's roadmap
   equivalent). Find phase `{N}`. If not found, surface the
   available phase numbers and stop.
2. **Read upstream context.** If prior phases have CONTEXT.md /
   PLAN.md / VERIFICATION.md / REVIEW.md artifacts, read them — the
   discussion should not re-litigate decisions that earlier phases
   recorded.
3. **Generate the open-question set.** Walk the phase's stated goal
   and tasks. For each, ask:
   - What assumptions am I making that the user might not share?
   - What would a senior reviewer flag as ambiguous?
   - What design alternatives exist that haven't been named?
   - What dependencies on other phases or on external services?
   - What "must work" cases are implied but not specified?
   - What "must NOT happen" cases need calling out?

   Aim for 5–10 questions. Fewer than 5 means the search was
   shallow; more than 10 overloads the user — split into a follow-up
   discuss round.
4. **Ask the user.** One question per logical group — do not flood
   with all questions at once. Use a structured prompt format the
   user can answer inline.
5. **Write `CONTEXT.md`.** Append (or create) at
   `.planning/phases/<NN>/CONTEXT.md`:

   ```markdown
   # Phase {{N}} — Context

   Goal: {{from ROADMAP.md}}

   ## Open questions resolved

   ### {{question}}
   {{user's answer}}

   ## Decisions

   - {{decision}} — {{rationale}}

   ## Design alternatives — {{scope}}

   *(when brainstorm-ui or brainstorm-architecture gates apply, this
   section gets filled by `codex-brainstorming` invoked from here)*

   ## Open follow-ups

   - {{any unresolved questions, with owner}}
   ```
6. **Route to brainstorm/design gates if applicable.** If the
   phase's tasks include UI work and CONTEXT.md has no "Design
   alternatives" section yet, invoke `codex-brainstorming` (UI
   mode). If architecture, invoke architecture mode. If a fresh UI
   surface, route to `codex-design-shotgun` next.

## Output

`.planning/phases/<NN>/CONTEXT.md` exists, lists resolved questions,
records decisions, and notes any unresolved follow-ups. The next step
is `$gsd-plan-phase {N}`, which reads this CONTEXT.md to author
PLAN.md.

## Failure modes

- **Asking generic questions.** "What are the requirements?" forces
  the user to do the search themselves. Ask specific, scoped
  questions like "Should the upload modal block on file size > 10MB
  or warn and allow override?".
- **Skipping discuss for "obvious" phases.** A phase whose discuss
  step is fully obvious is rare; usually the obviousness is the
  agent's confirmation bias. Run the step.
- **Treating CONTEXT.md as a transcript.** The output is structured
  decisions, not raw chat. Synthesize.

## Notes for the Codex host

- Codex's `AskUserQuestion`-equivalent (the harness's question
  surface) is the right tool when ≤4 questions need answers; for
  longer batches use a single structured prompt with numbered
  questions.
- This skill produces an artifact that survives across sessions; the
  next session starting from `$gsd-plan-phase {N}` reads CONTEXT.md
  rather than re-running discussions.
