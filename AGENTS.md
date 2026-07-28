# AGENTS.md — codex-workflow

This is the **scaffolder repo** that ships the AgenticApps spec-first
workflow for the OpenAI Codex CLI host. It self-applies its own
workflow per Phase 6 of the build-out.

The trigger skill and the gate skills this repo authors are linked into
`${CODEX_HOME:-$HOME/.codex}/skills/` via `install.sh` (run from this
repo's root). Codex auto-discovers them on next session start. The same
script binds the OpenSpec CLI (the planning front end) and installs the
§18 change-gate.

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

This repo uses the AgenticApps spec-first workflow on the OpenAI Codex
CLI host. Product work moves through the **OpenSpec change lifecycle** —
propose → validate → Superpowers-execute → archive — and shipping (the
git commit / PR) is a separate act from archiving. `openspec/specs/` is
the durable statement of what the product guarantees; `openspec/changes/`
holds in-flight deltas; `changes/archive/` is history. Full explainer:
[`docs/WORKFLOW.md`](docs/WORKFLOW.md).

On any code-touching task the `agentic-apps-workflow` trigger skill
activates, emits the canonical commitment ritual before any tool call,
and carries the gate bindings, task-size routing, and the stage-2
change-review procedure — read them there, not here. Project-specific
bindings live in
`.planning/config.codex.json`; gates that do not fire on this project are
documented in `docs/ENFORCEMENT-PLAN.md`. Do not bypass a gate —
accept-via-ADR is the override path.

No code is edited under an open change until `openspec validate --all` is
green **and** the change carries `REVIEWS.md` with ≥2 independent
reviewers. That is enforced programmatically three ways: a `PreToolUse`
hook (`.codex/hooks.json`), a git `pre-commit` hook, and CI — all calling
the same `openspec-change-gate.sh`. The hook is faster feedback; the
pre-commit and CI checks are the guarantee, because a hook cannot gate the
session that installed it. Spec:
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
v1.0.0 §16–§19. Version stamp: `.codex/workflow-version.txt`.

## Session handoff

Read `.codex/session-handoff.md` at session start if newer than 7 days;
write it before ending a session. Only the codex handoff — never another
host's. Full protocol in the trigger skill.

<!-- END: agentic-apps-workflow sections -->
