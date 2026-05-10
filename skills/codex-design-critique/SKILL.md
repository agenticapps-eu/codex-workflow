---
name: codex-design-critique
version: 0.1.0
implements_spec: 0.1.0
implements_gate: design-critique
description: |
  Impeccable-style design critique against an existing UI-SPEC.md or
  set of design-shotgun variants. Scores against typography, color,
  spatial design, motion, interaction, responsive behavior, and UX
  writing dimensions; flags AI-slop tells (24 anti-patterns); produces
  a critique document that names at least one specific issue and its
  remediation. Use before implementation begins on a UI plan, OR as
  the filter step in a design-shotgun slate (per ADR-0011).
---

# codex-design-critique

This skill fulfills the `design-critique` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md)
and is bound by [ADR-0011](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0011-impeccable-design-quality-gate.md).
It is the **pre-implementation** half of the design quality contract;
the post-implementation half is `codex-impeccable-audit`.

## When to invoke

- A UI plan has an existing `UI-SPEC.md`, before implementation
  begins, OR
- As the filter step in `codex-design-shotgun` — each generated
  variant gets a critique pass; sub-bar variants drop from the slate
  before the user picks.

## What this skill does

1. **Identify the artifact under critique.** Either a single
   UI-SPEC.md (pre-implementation gate mode) or each variant from a
   design-shotgun slate (filter mode).
2. **Score against the seven dimensions.** Each dimension scored 0–100.
   - **Typography** — type pair, scale, line-height, weight contrast,
     OpenType feature use, font-loading discipline
   - **Color** — palette discipline, OKLCH hue/chroma/lightness
     coherence, dark-mode handling, contrast (WCAG AA minimum, AAA
     where text-heavy)
   - **Spatial design** — grid discipline, vertical rhythm, optical
     vs metric centering, white space as primary affordance
   - **Motion** — easing curves, duration banding, motion-reduction
     respect, purposeful (vs decorative) animation
   - **Interaction** — affordance clarity, state coverage (default,
     hover, focus, active, disabled, loading, empty, error), keyboard
     navigation
   - **Responsive** — fluid type, content-breakpoint reasoning, no
     "fits one viewport only" failures
   - **UX writing** — voice consistency, error message specificity,
     empty-state copy that explains what to do, microcopy that
     surfaces system state honestly
3. **Run the AI-slop anti-pattern scan.** 24 known AI-default tells:
   purple gradients, Inter-everywhere, weak hierarchy from too many
   weights, generic "card" components with no information density,
   skeleton loaders without skeleton-specific design, "Get started"
   CTAs that don't say what gets started, etc. Each anti-pattern flag
   reduces the relevant dimension score.
4. **Compute the composite score.** Default weighted mean across the
   seven dimensions (configurable in workflow-config). Compare to the
   project's quality bar (default ≥ 90).
5. **Write the critique document.** Skeleton:

   ```markdown
   # Design critique — {{surface}}

   Critic: codex-design-critique v0.1.0
   Spec version: 0.1.0
   Quality bar: ≥ {{N}}

   ## Scores

   | Dimension | Score | Notes |
   |---|---|---|
   | Typography | … | … |
   | Color | … | … |
   | Spatial | … | … |
   | Motion | … | … |
   | Interaction | … | … |
   | Responsive | … | … |
   | UX writing | … | … |
   | **Composite** | … | … |

   ## Anti-pattern flags

   - <flag-name> — <where it appears> — <suggested fix>

   ## Specific issue + remediation

   **Issue**: <one specific design issue>
   **Remediation**: <how to fix>

   ## Verdict

   - <pass | filter (below bar) | block (multiple critical anti-patterns)>
   ```
6. **In filter mode**: emit verdict back to `codex-design-shotgun` so
   it knows whether the variant survives. **In gate mode**: write the
   critique document to the phase directory and reference it from
   the phase artifacts.

## Required evidence (per spec/06)

- A critique document exists in the phase directory (or alongside the
  variant in filter mode)
- The document names at least one specific design issue and its
  remediation
- The composite score and dimension breakdown are recorded
- The verdict line is explicit (pass / filter / block)

## Failure modes

- **"Design looks fine" without scoring.** The gate's whole point is
  to surface specific issues; "fine" is a rationalization that
  collapses the seven dimensions into vibes.
- **Skipping anti-pattern scan because "this isn't AI-default
  design."** AI-slop tells creep into hand-authored designs too —
  the scan still applies.
- **Treating critique as "polish later."** This is the
  pre-implementation gate; after implementation `codex-impeccable-audit`
  fires. Both run; neither substitutes for the other.

## Notes for the Codex host

- The critique can run from a fresh Codex session (no implementation
  context bias) but does not require a separate process — design
  critique is not subject to the spec/07 independence rule (that rule
  governs Stage 2 *code* review, not design critique).
- The 24 anti-pattern catalog is the upstream `pbakaus/impeccable`
  catalog. If the upstream skill is installed and accessible in the
  Codex session, defer to its catalog; otherwise this skill carries
  the catalog inline.
