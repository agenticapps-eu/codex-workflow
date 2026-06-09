# Architecture decision records

ADRs for `codex-workflow`. Numbered sequentially: `NNNN-slug.md`.

The shape follows the AgenticApps workflow's ADR convention —
status, date, context, decision, consequences, references.

When a `codex-database-sentinel-audit` finding is accepted rather
than fixed (in projects USING this scaffolder), the accepting ADR
uses the
[`adr-db-security-acceptance.md`](../../skills/setup-codex-agenticapps-workflow/templates/adr-db-security-acceptance.md)
template shape — risk owner, re-audit date, compensating controls.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-codex-skill-naming.md) | Codex skill naming, layout, and packaging | Accepted |
| [0002](0002-stage2-independent-reviewer-on-codex.md) | Stage 2 independent reviewer mechanism on Codex | Accepted |
| [0003](0003-gsd-entry-points-as-prompts.md) | GSD entry points are skills, not prompts | Accepted |
| [0004](0004-observability-strategy.md) | §10 observability — delegate to agenticapps-observability via a Codex installer | Accepted |
| [0005](0005-adopt-observability-architecture.md) | Adopt core ADR-0014 observability architecture (generator layer via delegation) | Accepted |
| [0006](0006-secret-scanner-gitleaks.md) | Secret scanner: stay on gitleaks (adopt core ADR-0015) | Accepted |
