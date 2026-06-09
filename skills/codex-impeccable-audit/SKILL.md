---
name: codex-impeccable-audit
version: 0.1.0
implements_spec: 0.4.0
implements_gate: impeccable-audit
description: |
  Post-implementation visual quality audit against the deployed
  component. Re-scores the seven design dimensions (typography, color,
  spatial, motion, interaction, responsive, UX writing) against the
  shipping code, runs the 24-item AI-slop anti-pattern scan, and
  blocks branch close on Red findings (per ADR-0011). Use after a
  UI-shipping phase's implementation is complete and the changes are
  visible in the dev server. May also be invoked retroactively against
  shipped UI to catch drift between mockup and implementation.
---

# codex-impeccable-audit

This skill fulfills the `impeccable-audit` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md)
and is bound by [ADR-0011](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0011-impeccable-design-quality-gate.md).
It is the **post-implementation** half of the design quality
contract; the pre-implementation half is `codex-design-critique`.

## When to invoke

- A phase's changeset modifies the visual surface of a shipping UI
  (typography, color, layout, spacing, motion), AND
- The implementation is complete (all tasks marked complete by
  `codex-verification`), AND
- The change is visible in the dev server.

MAY also be invoked retroactively on shipping UI that has not been
audited under this gate — surface drift between mockup intent and
implementation reality is a common gap.

## What this skill does

1. **Boot the dev server, navigate to the surface.** Same browser
   tooling as `codex-qa`. Capture screenshots at standard viewport
   sizes (1280×720 baseline; 390×844 mobile for responsive surfaces).
2. **Re-score the seven dimensions** (same dimensions as
   `codex-design-critique`) — this time against the SHIPPED code,
   not the spec or the mockup:
   - Typography, Color, Spatial, Motion, Interaction, Responsive,
     UX writing — each 0–100
3. **Run the 24-item anti-pattern scan.** Same catalog as
   `codex-design-critique`, applied to the rendered output. Flag
   each occurrence with:
   - Anti-pattern name
   - Where it appears (component / file / screenshot region)
   - Severity (Red — blocks branch close / Yellow — followup OK /
     Green — minor noise)
4. **Compare to mockup intent.** If a `UI-SPEC.md` and / or
   pre-implementation critique exist, diff the shipped output
   against the chosen mockup variant. Note any drift.
5. **Compute the composite score.** Same weighted mean as
   design-critique. Compare to the project's quality bar (default
   ≥ 90 per ADR-0011, project-overridable).
6. **Write the audit document** to
   `.planning/phases/<N>/IMPECCABLE-AUDIT.md`:

   ```markdown
   # Impeccable audit — phase {{N}}

   Auditor: codex-impeccable-audit v0.1.0
   Mode: post-implementation
   Surface: {{component / route}}
   Quality bar: ≥ {{N}}

   ## Scores (vs. shipped code)

   | Dimension | Score | Notes |
   |---|---|---|

   ## Anti-pattern flags

   | Severity | Anti-pattern | Location | Fix |
   |---|---|---|---|

   ## Mockup-to-implementation drift

   - Spec'd: …
   - Shipped: …
   - Drift severity: …

   ## Verdict

   <pass | pass-with-followups | block>
   ```
7. **Block branch close on Red findings.** Per ADR-0011, any Red
   anti-pattern flag blocks branch close until fixed or accepted via
   ADR.

## Required evidence (per spec/06)

- `IMPECCABLE-AUDIT.md` exists in the phase directory
- Scores recorded for all seven dimensions
- Anti-pattern flags enumerated with severity, location, fix
- Mockup-to-implementation drift section present (or noted as N/A
  if no UI-SPEC.md existed)
- Composite score and verdict explicit
- Referenced from REVIEW.md or VERIFICATION.md

## Failure modes

- **Auditing the spec instead of the shipped code.** Pre-impl
  critique is `codex-design-critique`. This gate is post-impl —
  audit what actually shipped.
- **Treating Red findings as advisory.** Per ADR-0011, Red blocks
  branch close. Accept via the database-security-acceptance ADR
  pattern (a generic acceptance ADR — even though that template was
  authored for DB findings, the pattern transfers).
- **Skipping because "the design-critique was clean."** Pre-impl and
  post-impl catch different drift. Both fire.
- **Anchoring on AI-default styling.** Purple gradients,
  Inter-everywhere, weak hierarchy from too many weights — score
  these honestly, not generously.

## Notes for the Codex host

- This skill shares infrastructure with `codex-qa` (browser
  tooling, dev server). Run them in sequence on a UI-shipping phase:
  qa → impeccable-audit. Same screenshots can be referenced from
  both reports.
- The 24 anti-pattern catalog ships inline with this skill until the
  upstream `pbakaus/impeccable` skill is installed; once installed,
  defer to it.
