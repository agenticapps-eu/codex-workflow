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
`agenticapps-workflow-core` v0.4.0 per spec/09 because:

1. The trigger skill `agentic-apps-workflow` reproduces the **five**
   canonical-prose blocks verbatim — Step 0 Commitment Ritual,
   Rationalization Table, Red Flags, Pressure-Test (spec/01,/03,/04,/05),
   and **§11 Coding Discipline** (injected into `AGENTS.md` behind a
   provenance anchor, byte-matched against the vendored mirror
   `skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md`).
2. Every declarative-contract MUST in spec/02, /06, /07, /08, **/10,
   /12, /13** is satisfied by some `codex-*` skill, an `install.sh` /
   migration-framework mechanism, or a delegation:
   - **§10 (observability)** — delegated to the standalone
     `agenticapps-observability` skill (see "§10 Observability —
     delegated binding" below); a *satisfied* MUST per §09.
   - **§12 (authoring conventions)** — branchy workflows newly
     authored/edited at 0.4.0 render as Mermaid `flowchart`s
     (`codex-ts-declare-first` refusals; trigger Step 2 routing).
     Surgical scope per §12 (no bulk conversion required).
   - **§13 (declare-first TS)** — `codex-ts-declare-first` skill
     strengthens the `tdd` gate for new TS modules.
3. Host-specific bindings exist for every gate **whose trigger
   condition can occur in this scaffolder's project type**. Gates
   whose triggers cannot occur are listed under "Spec Deltas" with
   the rationale per spec/09.
4. `skills/agentic-apps-workflow/SKILL.md` carries
   `implements_spec: 0.4.0` in frontmatter; the gate skills, GSD
   entry-point skills, and lifecycle skills all cite
   `implements_spec: 0.4.0`.
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
| `tdd` (new TS module) | `codex-ts-declare-first` | A new TypeScript module's public API surface (spec §13) | Strengthens `tdd`: three atomic commits `declare(ts):` → `test(ts):` (RED) → `feat(ts):` (GREEN). Does not fire on this markdown scaffolder; bound for downstream TS projects |
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

## §10 Observability — delegated binding

§10 (introduced in core 0.2.0; current 0.3.2) obliges every host to
provide an observability **generator** (§10.7). codex-workflow satisfies
§10 by **delegation**, not by shipping its own generator — see **ADR-0004**
(decision) and **ADR-0005** (adoption of core ADR-0014's architecture).

| Spec area | How codex-workflow satisfies it | Mechanism |
|---|---|---|
| §10.1–10.6 wrapper interface, envelope, `traceparent`, instrumentation, operational reqs, destination independence | Delegated | `agenticapps-observability` skill (`$observability init`) |
| §10.5 `Flush(timeout)` primitive | Delegated | obs skill per-stack wrappers |
| §10.7 generator obligation | Delegated | obs skill; installed on Codex via `install-codex.sh` |
| §10.7.1 module-root path resolution | Delegated | obs skill |
| §10.8 project metadata block (`AGENTS.md`) | Host-managed | `$observability init` emits the anchored block (currently into `CLAUDE.md`); migration `0003` **relocates** it into `AGENTS.md` (the canonical Codex file), preserving init's real content, and repoints a stale skill ref. Flow: run `$observability init`, then `$update-codex-agenticapps-workflow`. The obs-init host-awareness (writing `AGENTS.md` directly) is a tracked obs-repo follow-up; until it lands, migration 0003's relocate closes the gap on the Codex side |
| §10.9 baseline + `--since-commit` delta + CI | Delegated | obs skill (`$observability scan --since-commit`, `.observability/baseline.json`) |

A delegation to a consumable skill is a **satisfied** §10 MUST per §09 —
**not** a spec delta. The obligation is met by the consumed skill;
codex-workflow remains the conformance claimant. This is distinct from the
eight "Spec Deltas" above (gates whose triggers cannot occur on this
scaffolder): §10 *is* satisfied, by delegation.

Setup/update guidance: `docs/observability-delegation.md`. Wiring:
`migrations/0003-delegate-observability.md`. Cross-repo enabler:
`agenticapps-observability` `install-codex.sh` (v0.12.0, PR #3).

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
