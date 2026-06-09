# Workflow config — {{PROJECT_NAME}}

This file is the project-specific configuration consumed by
`agentic-apps-workflow` and the `codex-*` gate skills. The
`setup-codex-agenticapps-workflow` skill creates it from this template
during initial setup; `update-codex-agenticapps-workflow` migrates it
between versions.

## Project metadata

| Field | Value |
|---|---|
| Project name | {{PROJECT_NAME}} |
| Repo | {{REPO}} |
| Client | {{CLIENT}} |
| Budget tier | {{BUDGET}} |
| Backend language | {{BACKEND}} |
| Frontend stack | {{FRONTEND}} |
| Database | {{DATABASE}} |
| LLM provider | {{LLM}} |

## Gate quality bars

These project-level overrides are read by the gate skills.

| Gate | Default | This project |
|---|---|---|
| `codex-design-critique` quality bar | ≥ 90 | {{DESIGN_CRITIQUE_BAR}} |
| `codex-impeccable-audit` quality bar | ≥ 90 | {{IMPECCABLE_BAR}} |
| `codex-qa` viewport widths | 1280, 390 | {{QA_VIEWPORTS}} |
| `codex-database-sentinel-audit` blocking severity | Critical, High | {{DB_BLOCKING}} |

Lowering the bar is permitted (e.g. for prototype phases) but
should be re-tightened before the project's first production
launch. The values above are honored by the relevant skills if set;
defaults apply when the value is `default` or missing.

## Backend language routing

The backend gate bindings vary by language. Fill the row that
matches `{{BACKEND}}`.

| Language | Test runner | TDD commit prefix | Notes |
|---|---|---|---|
| Go | `go test ./...` | `test(RED):` / `feat(GREEN):` | Use `t.Run` for table-driven |
| Python | `pytest` | same | `pytest -x` for fast-fail in TDD |
| TypeScript | `vitest` / `jest` | same | Snapshot tests count for UI TDD |
| Rust | `cargo test` | same | Use `#[test]` not benchmark wrappers |
| Other | (project-defined) | (project-defined) | Document below |

Project-defined override (if `{{BACKEND}}` is "Other"):

```
{{BACKEND_OVERRIDE}}
```

## External skill dependencies

The following upstream skills compose with this project's workflow.
Each is installed via `codex-workflow`'s install path or via
`$skill-installer`.

| Skill | Required when | Install command |
|---|---|---|
| `pbakaus/impeccable` (optional) | UI-shipping phases want the canonical 24-anti-pattern catalog | `$skill-installer --repo pbakaus/impeccable` |
| `Farenhytee/database-sentinel` (optional) | DB phases want the canonical 27-anti-pattern catalog | `$skill-installer --repo Farenhytee/database-sentinel` |

The `codex-workflow` gate skills carry inline catalogs as fallback;
upstream catalogs take precedence when installed.

## Notes

- The trigger skill cites `implements_spec: 0.4.0`. To bump the
  spec version, run `$update-codex-agenticapps-workflow` and follow
  its migration prompts.
- This file is project-specific — do not commit secrets, only
  configuration that should be visible to every contributor.
