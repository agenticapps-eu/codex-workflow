---
name: codex-spec-review
version: 0.1.0
implements_spec: 0.1.0
implements_gate: spec-review
description: |
  Stage 1 of the two-stage review: audit the phase's changeset against
  CONTEXT.md decisions, every must_have in VERIFICATION.md, the gate
  bindings, and the protocol-violation list (commitment ritual,
  brainstorm artifact, TDD commit pair). Use after all execution tasks
  complete and before any code-review pass. Writes the
  `## Stage 1 — Spec compliance` section into REVIEW.md. The
  implementer agent runs this stage in the same session; Stage 2
  (`codex-code-review`) MUST run independently afterwards.
---

# codex-spec-review

This skill fulfills the `spec-review` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md)
and is bound by [`spec/07-two-stage-review.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/07-two-stage-review.md).
It is **Stage 1** — the implementer's own pass against the spec.
Stage 2 is `codex-code-review` and MUST run in a separate agent
context.

## When to invoke

After the last task of the phase transitions to complete (per
`codex-verification`) and before phase verification closes. Order is
load-bearing: Stage 1 must complete before Stage 2 fires (per
spec/07).

## What this skill does

1. **Read the phase artifacts.**
   - `CONTEXT.md` — the design and architectural decisions
   - `PLAN.md` — the task list, gate triggers, must_haves
   - `VERIFICATION.md` — must_haves and their evidence
   - `git diff <phase-base>..HEAD` — what was actually shipped
2. **Walk the protocol-violation checklist.** For each item, write a
   pass/fail line in REVIEW.md Stage 1:
   - Commitment block emitted at the start of the implementing
     session?
   - Brainstorm gate fired (where applicable) and its CONTEXT.md
     "Design alternatives" / RESEARCH.md "Architecture alternatives"
     section is present with ≥2 named options?
   - Design-shotgun gate fired (where applicable) and ≥3 visual
     variants are referenced with the chosen variant marked?
   - TDD commit pair (`test(RED):` + `feat(GREEN):`) exists for every
     `tdd="true"` task?
   - UI-preview screenshot reference (where applicable) appears in
     each ui-touching commit message?
   - Security artifact exists (where applicable)?
   - Database audit artifact exists (where applicable)?
3. **Walk every must_have.** For each row in VERIFICATION.md, confirm:
   - The must_have was actually delivered by some commit in the
     diff
   - At least one Evidence subrow conforms to one of the six
     permitted shapes (per spec/06)
   - The Evidence content is real (the command actually ran, the
     screenshot file exists, the grep would actually match)
4. **Walk every PLAN.md task.** Each task is either complete with
   evidence, or explicitly carried forward as a should_have gap with
   an owner.
5. **Write the Stage 1 section.** Use this skeleton:

   ```markdown
   ## Stage 1 — Spec compliance

   Implementer: <self>
   Spec version: 0.1.0

   ### Protocol-violation flags

   - Commitment block: <pass | flag — reason>
   - Brainstorm gate (where applicable): <pass | flag — reason>
   - Design-shotgun gate (where applicable): <pass | flag — reason>
   - TDD commit pairs: <pass | flag — reason + missing pairs>
   - UI-preview gate (where applicable): <pass | flag — reason>
   - Security gate (where applicable): <pass | flag — reason>
   - Database-security gate (where applicable): <pass | flag — reason>

   ### must_have coverage

   | must_have | Status | Evidence shape |
   |---|---|---|
   | …          | covered | test output |
   | …          | gap     | (missing) |

   ### Outcome

   - <gap | clean | clean-with-followups>
   ```

6. **Decide the outcome.**
   - **clean** — all must_haves covered, no protocol-violation flags
   - **clean-with-followups** — clean Stage 1 but should_have gaps
     are documented in the PR description
   - **gap** — at least one protocol-violation flag or uncovered
     must_have. Stage 2 does not fire until the gap is closed; fix or
     accept via ADR.

## Required evidence (per spec/06)

- `REVIEW.md` exists in the phase directory
- It contains a top-level heading `## Stage 1 — Spec compliance`
- The section enumerates protocol-violation flags, must_have coverage,
  and an explicit outcome
- The section was authored by the implementer agent (this is the
  one stage where same-agent authoring is permitted; spec/07
  requires Stage 2 to be independent)

## Failure modes

- Collapsing Stage 1 + Stage 2 into one "review" section is
  non-conformant per spec/07.
- Skipping the protocol-violation checklist because "I followed the
  protocol" is exactly what the checklist is meant to catch — write
  the checks down.
- Treating Stage 1 as a high-level summary and deferring detail to
  Stage 2 inverts the order: Stage 1 is the detailed spec audit;
  Stage 2 is the independent code-quality pass.
