---
name: codex-design-shotgun
version: 0.1.0
implements_spec: 0.1.0
implements_gate: design-shotgun
description: |
  Generate at least three rendered visual variants of a UI surface and
  let the user pick. Use when a phase has a UI plan and no UI-SPEC.md
  exists for the surface yet — the gate fires once per surface. Ships
  variants as screenshots, sketches, mockup URLs, or any combination
  the user can compare visually. Marks the chosen variant in
  CONTEXT.md or UI-SPEC.md. Pairs with `codex-design-critique` to
  filter sub-bar variants per ADR-0011 before the user picks.
---

# codex-design-shotgun

This skill fulfills the `design-shotgun` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md).

## When to invoke

A phase has at least one UI plan AND no `UI-SPEC.md` exists for the
surface being built. Re-firing on a surface that already has a
UI-SPEC.md is redundant; for an existing UI-SPEC.md, route to
`codex-design-critique` instead.

## What this skill does

1. **Identify the surface.** A "surface" is the smallest scoped UI
   region that has its own design decisions — a page, a modal, a key
   component, a route. One phase may ship multiple surfaces; one
   shotgun per surface.
2. **Pick a generation strategy.** The skill body supports three:
   - **Code-rendered variants** — generate three differently-styled
     React/HTML/etc. components and screenshot each via the project's
     dev server + browser tooling.
   - **Mockup-rendered variants** — generate three image mockups
     (Figma, Excalidraw, AI image generation) and reference them by
     URL or path.
   - **Sketch variants** — for early-stage UIs where rendered
     fidelity is overkill, three labeled sketches suffice.
   The strategy depends on the surface's current state: late-stage
   refinement wants code-rendered; new direction wants mockup or
   sketch.
3. **Generate ≥3 variants.** Vary on at least three of: layout
   density, hierarchy, color treatment, typography, motion, copy
   tone, primary affordance. Two variants of the same approach with
   different button colors do NOT count as two variants.
4. **Critique-filter the slate (ADR-0011).** Run `codex-design-critique`
   against each variant. Variants scoring below the project's quality
   bar (default ≥ 90 per ADR-0011, project-overridable in
   workflow-config) are eliminated from the slate before the user
   sees it. If filtering drops the slate below 3 variants, generate
   replacements until 3 survive.
5. **Present the surviving slate to the user.** Reference each
   variant by stable path or URL. Explain in one sentence what each
   variant is doing differently.
6. **User picks.** Mark the chosen variant in `CONTEXT.md` (early
   phase) or `UI-SPEC.md` (mid phase) under a "Chosen variant"
   heading. Eliminated variants stay in the document as historical
   reference; future surface refresh can revisit them.

## Required evidence (per spec/06)

- `CONTEXT.md` or `UI-SPEC.md` references at least three variants.
  Each reference is a permitted-shape evidence (screenshot path,
  mockup URL, sketch file path).
- The chosen variant is marked explicitly (e.g.
  `**Chosen variant: B — minimalist column layout**`).
- The pre-filter slate count is recorded if filtering ran (e.g.
  "5 variants generated; 2 eliminated by critique below quality bar
  90; 3 survived").

## Failure modes

- **Stopping at 1 or 2 variants.** Generate at least 3. If you cannot
  generate 3 distinct ones, the surface scope is wrong (too small or
  too vague) — surface it and split.
- **Cosmetic variations as separate variants.** See step 3.
- **Skipping the critique filter "to save time."** ADR-0011's whole
  point is filtering before the user anchors. Skipping it pulls the
  chosen design toward the median.
- **Letting all 3 variants score below the quality bar.** This means
  the generation step itself is producing slop. Stop, raise the bar
  on generation prompts (more specific direction, examples of the
  surface's prior art, explicit anti-pattern callouts), then
  regenerate.

## Notes for the Codex host

- Code-rendered variants typically need the project's dev server
  running and the browser tool available. The Codex sandbox should
  permit network and the project's port; surface escalation if
  needed.
- For AI image generation, the `imagegen` system skill is available
  by default; for higher-fidelity mockups, route to whatever
  Figma-style tooling the project has registered as MCP.
