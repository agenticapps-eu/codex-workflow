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

- [x] **Phase 8: Plan-Review Gate** - Bind the core spec §02 `plan-review` pre-execution gate on the Codex host (completed 2026-07-15)

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

  1. A phase with plans and no reviews is blocked before its first code-touching edit, via an **agent-mediated programmatic check**: the verifier returns exit 2 and the ritual instructs a hard stop *once the verifier runs*
  2. A phase that already shipped (`*-SUMMARY.md` present) is allowed — never retroactively blocked
  3. A legacy bare-number phase is allowed
  4. `codex-plan-review` produces `<NN>-REVIEWS.md` carrying at least 2 independent external reviewers, and refuses rather than emitting a one-reviewer file
  5. Both escape hatches (`GSD_SKIP_REVIEWS=1`, `multi-ai-review-skipped`) allow the edit
  6. The resolver selects the active phase in the spec's documented order and fails open when nothing resolves
  7. `migrations/run-tests.sh` passes, including a `test_migration_0008` that is a no-op on second run

<sub>**Deviation notice — criterion 1 was relaxed on 2026-07-14, before execution.** It originally read "A phase with plans and no reviews is blocked before its first code-touching edit" — an unconditional block. Reworded from an unconditional block per D-02; see ADR-0009 decision 9. The mechanism is `AGENTS.md` ritual text plus a verifier script: `AGENTS.md` is always in context, but nothing *executes* it, so an agent that omits the invocation is not blocked. D-02 defers the native `~/.codex/hooks.json` `PreToolUse` surface — pointed at this same verifier, which is why the verifier carries a `--file` argument — to its own phase; when it lands, criterion 1 can be restated as an unconditional block. Amended during replanning after Cross-AI plan review (`08-REVIEWS.md` round 2, Codex + OpenCode agreed) so the reviewed contract is the contract used at closure. **Phase closure must not claim the original unconditional criterion 1 was met.**</sub>

**Plans**: 6 plans in 5 waves

Plans:
**Wave 1**

- [x] 08-01-PLAN.md — Verifier core: phase resolver (4 steps) + grandfather guards, TDD [wave 1] → criteria 2, 3, 6
- [x] 08-03-PLAN.md — Producer skill `codex-plan-review` + ADR-0009 [wave 1] → criterion 4

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 08-02-PLAN.md — Verifier enforcement: REVIEWS strictness (D-13), escape hatches, block message, TDD [wave 2] → criteria 1, 5

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 08-04-PLAN.md — Declarative binding (`pre_execution`) + ritual wiring + 16-gate table (D-20) [wave 3] → criteria 1, 4

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 08-05-PLAN.md — Migration 0008 core: config leaf-merge + ritual insert + `test_migration_0008` + version bump in lockstep, TDD [wave 4] → contributes to criterion 7

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 08-06-PLAN.md — Migration 0008 bindings-table step (D-20) + CHANGELOG, TDD [wave 5] → closes criterion 7

<sub>08-05/08-06 were one plan; split for context budget (operator-approved). 08-06 depends on 08-05 rather than running beside it because both edit `migrations/0008-plan-review-gate.md` and `migrations/run-tests.sh` — same-wave siblings must not share `files_modified`. The version bump stays with 08-05 because `run_drift_test` compares the latest migration's `to_version` against SKILL.md's `version`, and this repo hard-fails a mismatch: splitting them would leave the harness red across the wave boundary.</sub>

## Progress

**Execution Order:**
Phases execute in numeric order: 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 8. Plan-Review Gate | 6/6 | Complete   | 2026-07-15 |
