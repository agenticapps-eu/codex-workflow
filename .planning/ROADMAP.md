# Roadmap: codex-workflow

## Overview

`codex-workflow` is the OpenAI Codex CLI host binding for the AgenticApps
spec-first workflow defined by `agenticapps-workflow-core`. It is a thin binding
over upstream GSD and Superpowers (ADR-0007), not a re-port.

**Phases 00–07 are pre-GSD legacy and are deliberately not back-filled here.**
They shipped before this repo adopted GSD's project scaffold, and their record
lives in `.planning/phases/<NN>/` (bare-number layout) and `CHANGELOG.md`.
Reconstructing them as roadmap entries would invent history this file cannot
source. GSD roadmap tracking starts at Phase 8.

## Phases

**Phase Numbering:**
- Integer phases (8, 9, 10): planned work
- Decimal phases (8.1, 8.2): urgent insertions (marked INSERTED)

- [ ] **Phase 8: Plan-Review Gate** - Bind the core spec §02 `plan-review` pre-execution gate on the Codex host

## Phase Details

### Phase 8: Plan-Review Gate
**Goal**: Bind the core spec §02 `plan-review` pre-execution gate on Codex — a declarative binding in `.planning/config.codex.json` plus a programmatic verifier implementing the spec's resolution order and grandfather rule — closing the follow-up the spec names at `spec/02:105-109`.
**Depends on**: Nothing tracked in this roadmap (Phases 00–07 are pre-GSD legacy)
**Requirements**: core spec §02 (`plan-review` gate), §09 (conformance)
**Canonical refs**:
  - `docs/briefs/plan-review-gate.md` — approved design brief for this phase
  - `../agenticapps-workflow-core/spec/02-hook-taxonomy.md` — normative gate definition (lines 81–109)
  - `../agenticapps-workflow-core/spec/09-conformance.md` — conformance levels and gate-binding rules
  - `../agenticapps-workflow-core/adrs/0025-*` — resolver / grandfather rationale (referenced by spec/02)
  - `../claude-workflow/templates/.claude/hooks/multi-ai-review-gate.sh` — reference implementation (NOTE: its resolver step 2 greps `## Current Phase`, which no real STATE.md uses — do not port verbatim)
  - `docs/decisions/0007-bind-upstream-gsd.md` — thin-binding stance this phase must respect
  - `AGENTS.md` — host hook-bindings table
**Success Criteria** (what must be TRUE):
  1. A phase with plans and no reviews is blocked before its first code-touching edit
  2. A phase that already shipped (`*-SUMMARY.md` present) is allowed — never retroactively blocked
  3. A legacy bare-number phase is allowed
  4. `codex-plan-review` produces `<NN>-REVIEWS.md` carrying at least 2 independent external reviewers, and refuses rather than emitting a one-reviewer file
  5. Both escape hatches (`GSD_SKIP_REVIEWS=1`, `multi-ai-review-skipped`) allow the edit
  6. The resolver selects the active phase in the spec's documented order and fails open when nothing resolves
  7. `migrations/run-tests.sh` passes, including a `test_migration_0008` that is a no-op on second run
**Plans**: 5 plans in 4 waves

Plans:
- [ ] 08-01-PLAN.md — Verifier core: phase resolver (4 steps) + grandfather guards, TDD [wave 1] → criteria 2, 3, 6
- [ ] 08-02-PLAN.md — Verifier enforcement: REVIEWS strictness (D-13), escape hatches, block message, TDD [wave 2] → criteria 1, 5
- [ ] 08-03-PLAN.md — Producer skill `codex-plan-review` + ADR-0009 [wave 1] → criterion 4
- [ ] 08-04-PLAN.md — Declarative binding (`pre_execution`) + ritual wiring + 16-gate table (D-20) [wave 3] → criteria 1, 4
- [ ] 08-05-PLAN.md — Migration 0008 + `test_migration_0008` + version bump + CHANGELOG, TDD [wave 4] → criterion 7

## Progress

**Execution Order:**
Phases execute in numeric order: 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 8. Plan-Review Gate | 0/5 | In progress | - |
