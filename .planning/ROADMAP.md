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

## Milestones

- ✅ **v0.6.0 Plan-Review Gate** — Phase 8 (shipped 2026-07-15)
- 🚧 **v0.7.0 Region-Aware §11 Placement** — Phase 9 (in progress)

## Phases

**Phase Numbering:**

- Integer phases (8, 9, 10): planned work
- Decimal phases (8.1, 8.2): urgent insertions (marked INSERTED)

<details>
<summary>✅ v0.6.0 Plan-Review Gate (Phase 8) — SHIPPED 2026-07-15</summary>

- [x] Phase 8: Plan-Review Gate (9/9 plans — 6 build + 3 gap-closure) — completed 2026-07-15

Bound the core spec §02 `plan-review` pre-execution gate on the Codex host: a
declarative binding in `.planning/config.codex.json` plus a programmatic
verifier (`check-plan-review.sh`) implementing the spec's resolution order and
grandfather rule, the `codex-plan-review` producer skill, and migration 0008 for
existing installs. VERIFICATION `passed` 7/7. Shipped in PR #15 (`cf51c73`).

Full phase detail — goal, canonical refs, all 7 success criteria, the criterion-1
deviation notice, and the wave breakdown — is preserved verbatim in
[`milestones/v0.6.0-ROADMAP.md`](milestones/v0.6.0-ROADMAP.md).
Decision record: [ADR-0009](../docs/decisions/0009-plan-review-gate.md).

</details>

- [ ] **Phase 9: Region-Aware §11 Placement** - Migration 0009 heals the §11 anchor so a leading GitNexus region can no longer silently destroy the block, with the anchor rule validated empirically before it is written

## Phase Details

### Phase 9: Region-Aware §11 Placement

**Goal**: Ship migration `0009-spec-11-region-aware-placement.md` so the spec §11
Coding Discipline block anchors above a leading GitNexus region instead of inside
it — closing a latent block-destruction defect for projects this host scaffolds
— with the anchor rule validated empirically against real files *before* the
migration is written, and a TDD fixture suite that sources the migration's shell
from the document itself rather than a transcribed copy.

**Depends on**: Phase 8 (the migration chain 0000–0008 that 0009's
`from_version: 0.6.0` pre-flight gate builds on)

**Ordering constraints this phase must respect** (not independent workstreams —
sequence matters):

1. **Validate before you write.** ANCHOR-03/04's empirical replay against real
   AGENTS.md files must complete, and confirm zero churn / correct
   above-region anchoring, *before* migration 0009's apply-block is authored.
   The source design is explicit that this is what caught a wrong alternative
   empirically in claude-workflow, not by review.
2. **RED before GREEN.** TEST-02's fixture suite must fail against the current
   naive anchor before migration 0009 exists, and only then turn green once
   0009 ships.
3. Fix-forward only: migrations 0001/0004 and `run-tests.sh`'s inlined awk
   copy are never edited in place; 0009 is a new migration, and TEST-04's
   document-sourced extraction replaces the `run-tests.sh:119` copy rather
   than patching it.

**Requirements**: ANCHOR-01, ANCHOR-02, ANCHOR-03, ANCHOR-04, ANCHOR-05,
MIGR-01, MIGR-02, MIGR-03, MIGR-04, MIGR-05, MIGR-06, MIGR-07, MIGR-08,
MIGR-09, TEST-01, TEST-02, TEST-03, TEST-04, SETUP-01, DOC-01, DOC-02

**Success Criteria** (what must be TRUE):

  1. The region-aware anchor rule — insert before the first `## ` heading or
     `<!-- gitnexus:start -->` marker, whichever comes first, else EOF — has
     been validated empirically against this host's real AGENTS.md files
     *before* migration 0009 is written: replay on the healthy file re-derives
     §11's current position with zero churn, and replay on a gitnexus-led file
     anchors above the region.
  2. A TDD fixture suite extracts migration 0009's shell directly from the
     migration document (never a transcribed copy), fails against the current
     naive anchor before 0009 exists, and passes all six required cases
     (gitnexus-led inject, inside-region move, healthy no-op, absent
     instruction file, hand-pasted refusal, no-heading-EOF) once 0009 ships.
  3. Migration 0009 heals all four states on a real AGENTS.md — no-op when §11
     is correctly anchored, move above the region when §11 sits inside one,
     inject at the anchor when §11 is absent, refuse with `exit 3` and leave
     the file unmodified when a §11 heading carries no provenance comment — is
     idempotent on re-run, and leaves a healthy-but-off-anchor block untouched.
  4. After migration 0009 applies, `.codex/workflow-version.txt` reads `0.7.0`,
     and this repo's own scaffolder version is bumped to `0.7.0` in the same
     change, keeping the version-coupling drift test green.
  5. The inlined anchor-awk copy at `migrations/run-tests.sh:119` is gone,
     replaced by extraction from the migration document — closing the drift
     hazard between the harness and the migration it tests.
  6. Setup's §11 placement is confirmed, in writing, to derive solely from
     migration 0001's replay with no independent anchor logic of its own; an
     ADR records the anchor decision and its rejected alternative, and
     CHANGELOG.md records the fix at release altitude.

**Plans**: 5 plans in 4 waves. Wave structure encodes the two hard orderings above:
09-01 (validate) and 09-03 (RED) both gate 09-04 (write/GREEN) via `depends_on`.

- [x] 09-01-PLAN.md — Empirical anchor replay against real + gitnexus-led AGENTS.md, with counter-replays; evidence recorded (ANCHOR-01..04) — wave 1
- [x] 09-02-PLAN.md — Fence-scoped document extractor + shape guards; retire the inlined anchor copy at run-tests.sh:119 (TEST-01, TEST-04) — wave 1
- [ ] 09-03-PLAN.md — test_migration_0009: ten synthesized cases + four-state idempotency; suite OBSERVED RED (TEST-02, TEST-03) — wave 2
- [ ] 09-04-PLAN.md — Migration 0009 authored, suite turns GREEN; scaffolder bumped to 0.7.0 (ANCHOR-05, MIGR-01..09) — wave 3
- [ ] 09-05-PLAN.md — ADR-0010, SETUP-01 single-source record, CHANGELOG 0.7.0 (SETUP-01, DOC-01, DOC-02) — wave 4

## Progress

| Phase                          | Milestone | Plans Complete | Status      | Completed  |
| ------------------------------- | --------- | --------------- | ----------- | ---------- |
| 8. Plan-Review Gate             | v0.6.0    | 9/9             | Complete    | 2026-07-15 |
| 9. Region-Aware §11 Placement   | v0.7.0    | 2/5 | In Progress|  |

## Known Follow-ups

Carried out of v0.6.0, not yet scheduled into a phase. These are **not** in
v0.7.0's scope (verified 2026-07-15 against the source prompt) and are now also
tracked as Future Requirements in `REQUIREMENTS.md`:

- **The gate is agent-mediated, not enforced.** Per D-02 / ADR-0009 decision 9,
  `AGENTS.md` ritual text instructs the verifier's invocation but nothing
  executes it, so an agent that omits the call is not blocked. The native
  `~/.codex/hooks.json` `PreToolUse` surface — pointed at this same verifier,
  which is why it already carries a `--file` argument — is deferred to its own
  phase. When it lands, criterion 1 can be restated as an unconditional block.
  Tracked as `HOOK-01`.
- **Phase 9 is the first genuinely gated phase.** ADR-0009 decision 8 records
  the bootstrap paradox: Phase 8's own grandfathered pass is not evidence the
  gate works.
- **CI verifies nothing.** `.github/workflows/ci.yml` is still the Phase 0
  placeholder (`echo` + `exit 0`); its own comment promises real checks in
  "Phase 7", which never happened. `migrations/run-tests.sh` (278 assertions)
  runs only locally — v0.6.0 was merged on a local green, not a CI green. A real
  job needs checkout with `submodules: recursive`; the harness hard-fails
  without `vendor/agenticapps-shared`. Tracked as `CI-01`.
- **WR-03** (`--file` symlink-traversal guard is lexical-`..`-only) — accepted
  as a documented limitation, ADR-0009 decision 12, with a concrete future fix
  in that ADR's Open follow-ups. Tracked as `WR-03` in Future Requirements.
- **Upstream grandfather-conflation defect** — recorded as an open question for
  a `claude-workflow` bug report, not resolved unilaterally here.
