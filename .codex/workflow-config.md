# Workflow config — codex-workflow

This is the project-specific configuration consumed by
`agentic-apps-workflow` and the `codex-*` gate skills. The
`setup-codex-agenticapps-workflow` skill creates it from the template
during initial setup; `update-codex-agenticapps-workflow` migrates it
between versions.

For codex-workflow itself this file was authored as part of
**Phase 6 self-apply** (see `docs/dogfood-2026-05-10.md`); the
scaffolder is its own first user.

## Project metadata

| Field | Value |
|---|---|
| Project name | codex-workflow |
| Repo | https://github.com/agenticapps-eu/codex-workflow |
| Client | agenticapps-eu (internal) |
| Budget tier | oss |
| Backend language | bash + markdown (scaffolder; no application code) |
| Frontend stack | none |
| Database | none |
| LLM provider | openai (Codex CLI host) |

## Gate quality bars

These project-level overrides are read by the gate skills.

| Gate | Default | This project |
|---|---|---|
| `codex-design-critique` quality bar | ≥ 90 | n/a (no UI) |
| `codex-impeccable-audit` quality bar | ≥ 90 | n/a (no UI) |
| `codex-qa` viewport widths | 1280, 390 | n/a (no dev server) |
| `codex-database-sentinel-audit` blocking severity | Critical, High | n/a (no DB) |

The non-applicable gates are documented as Spec Deltas in
`docs/ENFORCEMENT-PLAN.md`. This is `full` conformance with
documented n/a entries — not a `partial` claim — because the gates
that do not fire have no trigger condition that can occur in this
project type (per spec/09).

## Backend language routing

The "backend" of this scaffolder repo is shell scripts plus markdown
content. There is no application logic in the traditional sense.

| Component | Test runner | TDD commit prefix | Notes |
|---|---|---|---|
| `install.sh` | `bash install.sh --dry-run` | `test(RED):` / `feat(GREEN):` | Dry-run is the smoke test |
| `migrations/run-tests.sh` | itself (it IS the harness) | same | Adding migrations means adding fixture pairs + harness assertions |
| Skill content (markdown) | spec byte-match diffs | n/a | Verification is via the trigger skill's Verification Check section |

Project-defined override: see above table.

## External skill dependencies

The following upstream skills compose with this scaffolder's intent.
None are required for this repo's own development; they are
referenced by gate skills as fallback catalogs.

| Skill | Required when | Install command |
|---|---|---|
| `pbakaus/impeccable` (optional) | UI-shipping projects USING this scaffolder want the canonical 24-anti-pattern catalog | `$skill-installer --repo pbakaus/impeccable` |
| `Farenhytee/database-sentinel` (optional) | DB-shipping projects USING this scaffolder want the canonical 27-anti-pattern catalog | `$skill-installer --repo Farenhytee/database-sentinel` |

## Notes

- The trigger skill cites `implements_spec: 0.1.0`. To bump the
  spec version, run `$update-codex-agenticapps-workflow` (against
  this scaffolder repo itself) and follow its migration prompts.
- `.codex/workflow-version.txt` records `0.1.0` — the scaffolder is
  asserting conformance against its own current cited spec version.
