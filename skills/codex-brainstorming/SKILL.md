---
name: codex-brainstorming
version: 0.1.0
implements_spec: 0.4.0
implements_gate: brainstorm-ui, brainstorm-architecture
description: |
  Surface at least two named alternatives with explicit trade-offs
  before any UI direction or architectural decision is committed to a
  plan. Use when a phase contains a UI plan and CONTEXT.md has no
  "Design alternatives" section, OR when a phase introduces a new
  service / model / integration / data shape and CONTEXT.md or
  RESEARCH.md has no "Architecture alternatives" section. The skill
  body branches on "ui" vs "architecture" mode based on the calling
  context. Fires before commitment to a single path is locked in.
---

# codex-brainstorming

This skill fulfills the `brainstorm-ui` and `brainstorm-architecture`
gates from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md).
One skill, two modes — the body branches on UI vs architecture.

## When to invoke

- **`brainstorm-ui` mode** — the phase contains at least one plan that
  introduces or modifies a frontend component, route, or visual
  surface, AND no prior CONTEXT.md exists with a "Design alternatives"
  section for this UI scope.
- **`brainstorm-architecture` mode** — the phase contains at least one
  plan that introduces a new service, model, integration, or data
  shape, AND no prior CONTEXT.md or RESEARCH.md exists with an
  "Architecture alternatives" section for this scope.

A phase MAY trigger both modes — author both sections. The two are
recorded in different files (CONTEXT.md for UI, RESEARCH.md or
CONTEXT.md for architecture) per spec/02.

## What this skill does

1. **Identify the decision under consideration.** A UI brainstorm is
   about visual surface and interaction; an architecture brainstorm is
   about how systems compose. Mixed concerns split into two
   brainstorms.
2. **Generate at least two genuinely distinct alternatives.** "Distinct"
   means the alternatives have different consequences — a different
   data shape, a different framework boundary, a different layout
   primitive. Two cosmetic variants of the same approach are not two
   alternatives.
3. **For each alternative, write trade-offs.** At minimum:
   - what this alternative optimizes for
   - what it sacrifices
   - the failure mode it introduces
   - the easiest path to recover if the choice turns out wrong
4. **Recommend, don't decide.** Surface a recommended alternative and
   the reason, but defer the choice to the user. The
   commitment-ritual block in the next code-touching turn names the
   chosen alternative explicitly.
5. **Write the section.** Use these skeletons:

   **UI mode** — append to `CONTEXT.md`:

   ```markdown
   ## Design alternatives — {{scope}}

   ### Alternative A — {{short name}}
   - Optimizes for: …
   - Sacrifices: …
   - Failure mode: …
   - Recovery path: …

   ### Alternative B — {{short name}}
   - Optimizes for: …
   - Sacrifices: …
   - Failure mode: …
   - Recovery path: …

   ### Recommendation: {{A | B | …}} because …
   ```

   **Architecture mode** — append to `RESEARCH.md` (or `CONTEXT.md` if
   the phase has no RESEARCH.md):

   ```markdown
   ## Architecture alternatives — {{scope}}

   ### Alternative A — {{short name}}
   - Approach: …
   - Optimizes for: …
   - Sacrifices: …
   - Failure mode: …
   - Recovery path: …

   ### Alternative B — {{short name}}
   - …

   ### Recommendation: {{A | B | …}} because …
   ```

## Required evidence (per spec/06)

- The phase's CONTEXT.md (UI mode) contains a `## Design alternatives`
  section with at least two named alternatives + trade-offs.
- The phase's RESEARCH.md or CONTEXT.md (architecture mode) contains
  a `## Architecture alternatives` section with at least two named
  alternatives + trade-offs.
- The recommendation line names the chosen alternative.

## Failure modes

- "I've already thought about alternatives." If the alternatives are
  not on disk, they are not on disk. Write them down.
- "There's only one obvious approach." Two genuinely distinct
  alternatives almost always exist; if you cannot articulate a second,
  the search was too shallow. Try varying: framework choice, data
  shape, layout primitive, deferred-vs-eager, push-vs-pull.
- "Two cosmetic variants count as two alternatives." They do not. The
  consequences must differ.
- Recommending one alternative without trade-offs collapses the
  brainstorm into a single-path decision. Write the trade-offs even
  for the recommendation.

## Notes for the Codex host

For UI brainstorms that need rendered visual variants, route to
`codex-design-shotgun` (the `design-shotgun` gate) instead of (or in
addition to) this skill. This skill produces *named alternatives with
trade-offs*; design-shotgun produces *rendered variants the user can
look at*. Phases that ship UI usually want both.
