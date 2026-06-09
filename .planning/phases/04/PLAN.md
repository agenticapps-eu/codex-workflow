# Phase 4 — PLAN: §12 Authoring Conventions (surgical Mermaid)

- Spec: `agenticapps-workflow-core` §12 (SHOULD; bulk conversion NOT
  required; applies to files newly authored/edited at/after 0.4.0).
- Phase 0 decision: **surgical** — render Mermaid `flowchart` only in
  sections this catch-up edits or newly authors.

## What the catch-up edited (the surgical surface)

- `skills/codex-ts-declare-first/SKILL.md` — NEW: its branchy refusal logic
  already ships as a Mermaid `flowchart` (done in Phase 2). ✓
- `skills/agentic-apps-workflow/SKILL.md` — edited (Step 1 §11 ref, Step 3
  gate row). Its Step 1→Step 2 routing is a genuinely branchy workflow
  (≥2 decision branches + a gate-execution cycle + a "pick the higher size"
  fallback) → add a decision-skeleton flowchart.

## Tasks

1. Add a Mermaid `flowchart` to the trigger skill's Step 2 (the Step 1+2
   routing decision skeleton): intent branch (bug→$gsd-debug,
   quick→$gsd-quick, build→size), size branch (tiny/small/medium-large),
   the discuss→plan→execute path with an `execute ↔ gate` cycle, a labeled
   dotted fallback edge ("ambiguous: pick the HIGHER size"), and a REPORT
   terminal. KEEP the Step 1 + Step 2 criteria tables (judgment stays in
   prose per §12 — diagram = skeleton, tables = criteria).
2. Confirm the new §13 skill's flowchart satisfies §12 (labeled edges +
   REPORT). ✓ (Phase 2.)

## Explicitly NOT converted (surgical scope)

- `gsd-execute-phase` pipeline — NOT edited by this catch-up. §12 does not
  require bulk conversion; left for opportunistic conversion at its next
  significant rewrite.
- The Step 3 gate-binding table — a lookup table, not a branchy workflow
  with cycles/fallbacks; §12's flowchart SHOULD does not apply.

## Gates fired

- `codex-verification` (VERIFICATION.md). Two-stage review at the Phase 2+4
  checkpoint. `codex-cso`/`codex-qa` N/A.
