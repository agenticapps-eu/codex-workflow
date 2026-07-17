# Architecture decision records

ADRs for `codex-workflow`. Numbered sequentially: `NNNN-slug.md`.

The shape follows the AgenticApps workflow's ADR convention —
status, date, context, decision, consequences, references.

When a `codex-database-sentinel-audit` finding is accepted rather
than fixed (in projects USING this scaffolder), the accepting ADR
uses the
[`adr-db-security-acceptance.md`](../../skills/setup-codex-agenticapps-workflow/templates/adr-db-security-acceptance.md)
template shape — risk owner, re-audit date, compensating controls.

## Numbering convention

`ADR-NNNN` (this index) and `migration NNNN` (`../../migrations/`) are
**independent** numbering sequences — each starts at `0000` and increments on
its own; the two series are not synchronized, so their same-numbered entries
are unrelated unless a cross-reference says otherwise. Always qualify a
number in prose as `ADR-NNNN` or `migration NNNN`; never write a bare `NNNN`
— on its own it is ambiguous between the two series.

**Worked example (the current collision):** migration 0009
(`migrations/0009-spec-11-region-aware-placement.md`) is documented by
**ADR-0010**, not ADR-0009. **ADR-0009** (`0009-plan-review-gate.md`, below)
is a different subject entirely — the plan-review pre-execution gate. Reading
a bare "0009" in prose could mean either one; qualifying it removes the
ambiguity.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-codex-skill-naming.md) | Codex skill naming, layout, and packaging | Accepted |
| [0002](0002-stage2-independent-reviewer-on-codex.md) | Stage 2 independent reviewer mechanism on Codex | Accepted |
| [0003](0003-gsd-entry-points-as-prompts.md) | GSD entry points are skills, not prompts | Superseded by 0007 |
| [0004](0004-observability-strategy.md) | §10 observability — delegate to agenticapps-observability via a Codex installer | Accepted |
| [0005](0005-adopt-observability-architecture.md) | Adopt core ADR-0014 observability architecture (generator layer via delegation) | Accepted |
| [0006](0006-secret-scanner-gitleaks.md) | Secret scanner: stay on gitleaks (adopt core ADR-0015) | Accepted |
| [0007](0007-bind-upstream-gsd.md) | Bind upstream GSD + Superpowers; stop re-porting | Accepted |
| [0008](0008-knowledge-capture.md) | Knowledge capture ritual tail — spec §15 on the Codex host | Accepted |
| [0009](0009-plan-review-gate.md) | Bind the plan-review pre-execution gate on the Codex host | Accepted |
| [0010](0010-region-aware-spec-11-placement.md) | Anchor the §11 block above a leading GitNexus region | Accepted |
