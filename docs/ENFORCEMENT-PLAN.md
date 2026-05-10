# Enforcement Plan — codex-workflow

This document records which `agenticapps-workflow-core/spec/02-hook-taxonomy.md`
gates fire for `codex-workflow`'s **own** development, which gates do not
apply (with rationale), and which `codex-*` skill is bound to each.
It is the host-side companion to `AGENTS.md`'s Workflow Enforcement
Hooks table.

The scaffolder repo dogfoods its own workflow per Phase 6 of the
build-out (`docs/dogfood-2026-05-10.md`).

## Conformance claim

`codex-workflow` claims **`full` conformance** to
`agenticapps-workflow-core` v0.1.0 per spec/09 because:

1. The trigger skill `agentic-apps-workflow` reproduces the four
   canonical-prose blocks verbatim (byte-match verified during
   Phase 1 — see PR #1).
2. Every declarative-contract MUST in spec/02, /06, /07, /08 is
   satisfied by some `codex-*` skill or by an `install.sh` /
   migration-framework mechanism (see binding table below).
3. Host-specific bindings exist for every gate **whose trigger
   condition can occur in this scaffolder's project type**. Gates
   whose triggers cannot occur are listed under "Spec Deltas" with
   the rationale per spec/09.
4. `skills/agentic-apps-workflow/SKILL.md` carries
   `implements_spec: 0.1.0` in frontmatter.
5. Each phase produces CONTEXT.md / PLAN.md / VERIFICATION.md /
   REVIEW.md as well-formed, machine-discoverable artifacts. (For
   the build-out itself the artifacts live in PR descriptions and
   commit messages; once codex-workflow ships, the scaffolder's
   own ongoing development uses `.planning/phases/<N>/` per
   project convention.)

## Gate-to-skill bindings (codex-workflow self-apply)

### Gates that fire on this repo's development

| Gate | Bound skill | When fires here | Notes |
|---|---|---|---|
| `brainstorm-architecture` | `codex-brainstorming` (architecture mode) | Adding a new skill, template, or migration | The Phase 0 ADR set is the reference shape |
| `tdd` | `codex-tdd` | Any task adding logic to `install.sh` or `migrations/run-tests.sh` | Markdown content (skills, templates, ADRs) does not require TDD |
| `verification` | `codex-verification` | Always — every PR | Evidence shapes here are typically grep results, file existence, and `run-tests.sh` output |
| `spec-review` | `codex-spec-review` | Always — every PR | Stage 1 of two-stage review |
| `code-review` | `codex-code-review` | Always — every PR | Stage 2; `codex exec` child process per ADR-0002 |
| `security` | `codex-cso` | When changing `install.sh` or any executable script | OWASP-aligned scan; for a scaffolder the relevant axes are: command injection, path traversal, secret exposure, unsafe `eval` of remote content |
| `branch-close` | `codex-finishing-branch` | Every PR | The PRs for Phases 1–6 each demonstrate this binding |

### Spec Deltas — gates whose trigger cannot occur

Per spec/09, gates that have no possible trigger in the scaffolder's
project type can be omitted with a documented justification. These
deltas do NOT downgrade the conformance claim from `full` to
`partial` because the spec explicitly permits omission when triggers
cannot occur (spec/09 final paragraph in "full" section).

| Gate | Bound skill (for downstream projects) | Why no trigger here |
|---|---|---|
| `brainstorm-ui` | `codex-brainstorming` (ui mode) | The scaffolder ships no UI. All contributors interact via CLI / git / markdown. |
| `design-shotgun` | `codex-design-shotgun` | Same — no visual surface to vary. |
| `design-critique` | `codex-design-critique` | Same — no UI to critique. |
| `ui-preview` | `codex-qa` (preview mode) | Same — no frontend code, no dev server. |
| `qa` | `codex-qa` (phase-qa mode) | Same — no dev server reachable on a local port. |
| `impeccable-audit` | `codex-impeccable-audit` | Same — no shipping UI surface. |
| `database-security` | `codex-database-sentinel-audit` (phase-scoped) | The scaffolder has no database, no schema, no RLS rules. |
| `db-pre-launch-audit` | `codex-database-sentinel-audit` (pre-launch) | Same. |

These eight bindings exist in the trigger skill's gate table because
**downstream projects** using codex-workflow may have UI / databases /
dev servers; the bindings are not vestigial. They simply don't fire
on the scaffolder's own development.

## Process notes

- Every PR for this scaffolder uses a feature branch per the global
  CLAUDE.md feature-branch + PR rule. Direct commits to main are
  reserved for the bootstrap phase (see commits prior to Phase 1).
- The two-stage review for codex-workflow's PRs runs Stage 1 in the
  authoring session and Stage 2 in a `codex exec` child process per
  ADR-0002. For PRs authored on Claude Code (as Phases 0–6 were),
  Stage 2 substitution is acceptable: a fresh Claude Code session
  with no prior session context can stand in for the independent
  reviewer until Codex sub-agent surfaces mature.
- Per-phase PRs: see PR #1 (trigger), PR #2 (gates), PR #3 (GSD
  entry-points), PR #4 (lifecycle + migrations + install), PR #5
  (Phase 6 self-apply, this PR's predecessor when this file is
  read in main).

## Drift detection

`agenticapps-workflow-core/tools/drift-report.sh` is the upstream
advisory check that compares canonical-block presence across known
host clones. Run it locally (from this scaffolder's parent
directory) to catch drift between the trigger skill's
canonical-prose blocks and the spec source of truth:

```bash
bash ~/Sourcecode/agenticapps-workflow-core/tools/drift-report.sh
```

Drift on canonical-prose blocks is a `gap` outcome at Stage 1
review and blocks PR merge until resolved.
