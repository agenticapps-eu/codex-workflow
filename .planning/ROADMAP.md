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

- [ ] **Phase 9: Region-Aware §11 Placement** - Migration 0009 heals the §11 anchor so a leading GitNexus region can no longer silently destroy the block, with the anchor rule validated empirically before it is written (5/5 plans executed; NOT complete — code review reproduced a data-loss defect, see 09-REVIEW.md CR-01; closes via Phase 9.1)
- [ ] **Phase 9.1: §11 Strip Runaway** (INSERTED 2026-07-15) - Close the runaway-strip and unanchored-provenance data-loss paths that Phase 9's code review reproduced in the shipped 0009, kill the dead `test -s` assertion, and add the idempotent re-run fixture that makes the terminator alternation self-defending

## Phase Details

### Phase 9.1: §11 Strip Runaway (INSERTED)

**Goal**: Close the data-loss paths `09-REVIEW.md` reproduced in the shipped
migration 0009, so the migration cannot destroy user content in the states it
does not abort on — and make the suite capable of catching it if it regresses.

Phase 9 shipped a migration whose *stated* purpose is closing a latent
block-destruction defect, and its code review reproduced a **different** latent
block-destruction defect in the mechanic immediately adjacent to the one that was
hardened. The anchor rule and terminator alternation Phase 9 built hold up under
mutation — the review tried to break them and could not. The defects are inherited
from upstream and were ported faithfully.

**Depends on**: Phase 9 (5/5 plans executed; 0009 exists and its suite is GREEN)

**Ordering constraints**:

1. **RED before GREEN, again.** The runaway must be captured as a *failing*
   fixture against the current 0009 before the awk is touched. Phase 9's own
   discipline; the repro is already written (16 lines → 4 lines, provenance
   present + drifted H2).
2. **Fix locally, file upstream.** CR-01/CR-02 are byte-identical to
   `claude-workflow @ 8520f90:0029:192-210`. The local fix deliberately diverges
   from the D-48 pin — record the divergence in ADR-0010 and file the defect
   upstream so the six repos carrying 0029 are not left exposed.
3. **No assertion weakening.** As in 09-04: the fixtures must be satisfied by the
   code, never the reverse.

**Requirements**: ANCHOR-05, MIGR-04, MIGR-09, TEST-02, TEST-03, DOC-01

**Success Criteria** (what must be TRUE):

  1. A fixture reproduces the runaway (provenance present, exact H2 drifted) and
     is observed FAILING against the current 0009 before any awk change.
  2. The strip's entry and exit conditions are coupled: a provenance match that
     never finds its exact heading cannot latch `in_block` to EOF. Verified by
     the fixture from criterion 1 turning GREEN.
  3. The provenance regex is anchored, with a fixture-07 twin proving a prose
     mention of the provenance line cannot trigger the strip.
  4. The `grep -q` post-strip guard is no longer satisfiable by the insert pass
     re-adding the heading it checks for — i.e. it can actually fail.
  5. `test -s`'s assertion is live: deleting the guard fails the suite. The
     document check skips comment lines, and case 10(a) isolates layer 1 from the
     tail sentinel (mirroring the version-gate control 12 lines earlier).
  6. `11-idempotent-rerun` exists: narrowing the strip terminator fails the suite.
  7. ADR-0010 records the runaway, the D-26 correction ("bounded by construction"
     was false), and the deliberate divergence from the 8520f90 pin.
  8. Upstream defect filed against `claude-workflow`.

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
- [x] 09-03-PLAN.md — test_migration_0009: ten synthesized cases + four-state idempotency; suite OBSERVED RED (TEST-02, TEST-03) — wave 2
- [x] 09-04-PLAN.md — Migration 0009 authored, suite turns GREEN; scaffolder bumped to 0.7.0 (ANCHOR-05, MIGR-01..09) — wave 3
- [x] 09-05-PLAN.md — ADR-0010, SETUP-01 single-source record, CHANGELOG 0.7.0 (SETUP-01, DOC-01, DOC-02) — wave 4

## Progress

| Phase                          | Milestone | Plans Complete | Status      | Completed  |
| ------------------------------- | --------- | --------------- | ----------- | ---------- |
| 8. Plan-Review Gate             | v0.6.0    | 9/9             | Complete    | 2026-07-15 |
| 9. Region-Aware §11 Placement   | v0.7.0    | 5/5             | In progress | —          |
| 9.1 §11 Strip Runaway (INSERTED)| v0.7.0    | 0/0             | Not planned | —          |

## Known Follow-ups

### Scheduled into Phase 9.1 (from 09-REVIEW.md — data loss, urgent)

- **CR-01 — the strip runs away to EOF.** Reproduced independently: 16-line input
  → 4-line output, destroying `## Critical Project Rules` and `## Deployment`.
  The strip's entry condition (unanchored provenance substring) is decoupled from
  its exit condition (which requires `swallowed_own_h2`, set only by the *exact*
  `## Coding Discipline (NON-NEGOTIABLE)` heading). A drifted heading latches
  `in_block=1` forever and `in_block { next }` eats to EOF. **All three guards
  pass** — the `grep -q` on the tmp is satisfied by the *insert* pass re-adding
  the heading the guard looks for, and `[ -s ]` passes because output is
  non-empty — so `mv` commits the truncation. Reachable: the abort branch fires
  only when heading-present AND provenance-absent; the runaway needs the inverse.
  Falsifies ADR-0010 D-26's "bounded by construction". This is D-25's rejected
  bug class resurfacing inside the boundary chosen to prevent it.
- **CR-02 — the provenance regex is unanchored.** D-21 requires the *marker*
  regex be anchored and builds fixture 07 to detect it, but the *provenance*
  regex — the strip's entry condition, a strictly more dangerous position — is
  unanchored on both sides with no fixture-07 twin. A backticked prose mention
  deletes everything between it and the real block. Plausibility raised by 0009's
  own abort message, which tells operators to paste that exact line into AGENTS.md.
- **CR-03 — dead assertion.** The `test -s` pre-flight guard can be deleted and
  the suite stays green. Two causes: the document check `*'test -s'*` matches the
  pre-flight's own comments (`:108`, `:114`), and case 10(a) passes for the wrong
  reason (guard 4's tail sentinel also fails zero-byte with the same `exit 3`).
  **Decision: fix the assertion** — make the document check skip comment lines and
  control case 10(a) to isolate layer 1, the same way the harness already controls
  the version gate 12 lines earlier.
- **`11-idempotent-rerun` fixture.** The highest-value gap this phase produced.
  Without it, narrowing the strip terminator does NOT fail the suite — ANCHOR-05
  is covered live only by `migrations/validate-0009-anchor.sh` counter-case B.
  The difference between "the alternation is correct" and "the suite would catch
  it if it stopped being correct".
- **WR-02** — the setup-SKILL note cites "Step 6" for the `agents-md-additions.md`
  append; it is Step 3 (Step 6 is a different template to `${CODEX_HOME}/AGENTS.md`,
  skipped on Option B). Contradicts ADR-0010:265, which cites `0000-baseline.md:102`
  correctly.

**Upstream note required:** CR-01 and CR-02 are *faithful ports* — diffed against
`claude-workflow @ 8520f90:0029:192-210`, byte-identical modulo filename. They are
inherited upstream defects, not porting errors, and affect every repo carrying 0029.
File upstream in addition to fixing locally. Fixing locally diverges from the D-48
pin deliberately; record that divergence in ADR-0010.

### Carried out of v0.6.0

Not yet scheduled into a phase. These are **not** in
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
