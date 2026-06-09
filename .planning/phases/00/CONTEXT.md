# Phase 0 — CONTEXT: spec 0.4.0 catch-up

- Date: 2026-06-09
- Effort: bring codex-workflow from `implements_spec: 0.1.0` → `0.4.0`
- Branch: `feat/spec-0.4.0-catchup`
- Driver: the hand-off prompt (this session) + `agenticapps-workflow-core`
  CHANGELOG 0.1.0 → 0.4.0
- Target: `implements_spec: 0.4.0`, scaffolder `version 0.2.0`, contiguous
  migration chain `0001…0003`, core reference-implementations row flipped
  to "0.4.0 — full".

## Design decisions

These resolve the Phase 0 gray areas. Downstream phases act on them
without re-asking.

### §10 observability — Option B (delegate to agenticapps-observability)

**Decision:** consume `agenticapps-observability` "like claude-workflow,"
after adding a **second, Codex-targeted installer** to that repo. Recorded
in full as **ADR-0004**. This is a **delegation** (a *satisfied* §10 MUST
per §09), not a spec delta — `full` conformance preserved.

Important correction captured during discuss: this is **not "nothing to be
done."** The obs repo is Claude-only today (`install.sh` → `~/.claude/skills`
only). Option B = three deliverables (Phase 3):
1. **Upstream PR (obs repo):** a Codex install surface
   (`$CODEX_HOME/skills/observability`), mirroring codex-workflow's own
   `install.sh` shape; confirm the SKILL loads under Codex 0.130.0 and
   `init`/`scan` invocation prose has a Codex path.
2. **codex-workflow:** thin binding doc + **migration `0003`** that
   repoints a downstream project's **`AGENTS.md`** `observability:` block
   at the obs skill, with a pre-flight hard-abort (no auto-install) when
   the skill is absent — modeled on claude-workflow `0022`.
3. **Bookkeeping:** §10 recorded as a delegation in `ENFORCEMENT-PLAN.md`;
   ADR-0014 ported noting the delegation.

### §12 authoring conventions — Surgical Mermaid

**Decision:** render Mermaid `flowchart` blocks **only** in sections this
catch-up already edits or newly authors (the `codex-ts-declare-first`
skill's decision logic, the migration-touched routing in the trigger
skill if edited, the `gsd-execute-phase` pipeline if edited). **No bulk
conversion** — §12 explicitly does not require it (conformance applies to
files newly authored at/after 0.4.0 adoption). Judgment-heavy passages
stay in prose; every shipped flowchart has a labeled fallback edge and a
`REPORT` terminal.

### agenticapps-shared submodule — Adopt now

**Decision:** pull `agenticapps-shared` in as a git submodule during this
catch-up and unify the migration-runner harness on it (SPLIT-01 parity).
This is a scope expansion beyond bare 0.4.0 conformance, chosen
deliberately. The obs repo already vendors `agenticapps-shared` at
`vendor/agenticapps-shared/`, so the install/submodule-refresh pattern is
established and reusable. Sequencing: fold into Phase 5/6 (bookkeeping +
infra) so it does not block the spec-delta phases (1–4). Migration
immutability holds — existing `migrations/run-tests.sh` keeps working
until the harness is switched over in one reviewed step.

## Empirical checks (deferred v0.1.x follow-ups)

Codex CLI **0.130.0** confirmed installed (`/opt/homebrew/bin/codex`);
skills install to `~/.codex/skills/`. Both checks below need a controlled
fresh Codex session — **method documented here, run + recorded in ADR
appendices in Phase 6** (per hand-off Phase 6 verification).

1. **`policy.allow_implicit_invocation: false`** (ADR-0003 F2): confirm the
   five GSD entry-point skills do NOT auto-load into an unrelated fresh
   Codex session, and remain explicitly invocable via `$gsd-*`. Method:
   start a fresh `codex` session in an unrelated dir, inspect whether the
   GSD skill contexts are injected; invoke `$gsd-quick` to confirm
   explicit invocation still works.
2. **AGENTS.md root-down concat depth** (ADR-0001 appendix A2): confirm how
   many directory levels of `AGENTS.md` Codex 0.130.0 concatenates
   (repo-root → family → ~/.codex). Method: place sentinel strings in
   `AGENTS.md` at each level, start a session, observe which are present.

## Scope summary (8 phases)

Per hand-off, governed by `AGENTS.md` enforcement gates each phase.

| Phase | Deliverable | Net change from minimal catch-up |
|---|---|---|
| 0 | This CONTEXT.md + ADR-0004 | — |
| 1 | §11 canonical block in AGENTS.md + mirror + migration `0001` (sole version bumper → 0.2.0 / `implements_spec` 0.4.0) | — |
| 2 | `codex-ts-declare-first` skill (§13) + migration `0002` (additive) | — |
| 3 | §10 delegation: **obs-repo Codex installer (upstream PR)** + binding + migration `0003` + ADR-0014 port | Option B adds the upstream PR |
| 4 | §12 surgical Mermaid in edited/new sections | — |
| 5 | Conformance bookkeeping: `implements_spec: 0.4.0` everywhere, ENFORCEMENT-PLAN → 0.4.0 delegation row, ADR-0015 (gitleaks STAY, changelog note), version records, `[0.2.0]` changelog, core ref-impl PR | — |
| 6 | Fold deferred fixes: install.sh symlink-in-source-tree bug; record empirical-check results in ADR appendices; **adopt agenticapps-shared submodule** | shared submodule adds infra work |
| 7 | Release v0.2.0 / spec 0.4.0: tests green, two-stage review, tag, land core PR, refresh session-handoff | — |

## Hard constraints (carried from hand-off)

- Canonical-prose §11 block reproduced **verbatim** (diff-clean against
  core spec fence; no editorial changes).
- Migration immutability — chain stays contiguous `0000…0003`; a fix is a
  new migration, never an edit.
- Version is migration-coupled — `0001` is the single bumper to `0.2.0`;
  drift test enforces `SKILL.md version == latest migration to_version`.
- `implements_spec` moves `0.1.0 → 0.4.0` exactly once (Phase 1, bundled
  with §11). No partial applies.
- No core spec edits — only the reference-implementations row.
- Dogfood the gates every phase; produce CONTEXT/PLAN/VERIFICATION/REVIEW
  artifacts.

## Next step

`$gsd-plan-phase 1` — author PLAN.md for the §11 absorption (vendored
mirror + AGENTS.md injection + migration `0001`), reading this CONTEXT.md.
