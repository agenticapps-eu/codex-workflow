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
- ✅ **v0.7.0 Region-Aware §11 Placement** — Phases 9, 9.1 (shipped 2026-07-16)
- 🚧 **v0.8.0 Enforcement, Not Intention** — Phases 10–14 (in progress)

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

<details>
<summary>✅ v0.7.0 Region-Aware §11 Placement (Phases 9, 9.1) — SHIPPED 2026-07-16</summary>

- [x] Phase 9: Region-Aware §11 Placement (5/5 plans) — completed 2026-07-16
- [x] Phase 9.1: §11 Strip Runaway (INSERTED 2026-07-15) (7/7 plans) — completed 2026-07-15

Migration 0009 heals the §11 coding-discipline block's anchor so a leading
GitNexus region can no longer silently destroy it. The anchor rule — insert
before the first `## ` heading or `<!-- gitnexus:start -->` marker, whichever
comes first, EOF fallback — was validated empirically *before* the migration was
written (enforced as wave topology, not intention), and the fixture suite was
observed RED against the naive anchor before 0009 existed.

Phase 9's code review then reproduced a **different** block-destruction defect in
the mechanic adjacent to the one being hardened. Phase 9.1 was inserted to close
it: CR-01 (runaway strip to EOF), CR-02 (unanchored provenance regex), CR-03
(dead `test -s` assertion), plus V-01 — the pre-flight that aborted `exit 3` on
every real target project, meaning the migration never ran on the projects it
existed to fix.

21/21 requirements delivered. Phase 9 VERIFICATION scored 0 NOT-DELIVERED with 5
gaps deferred to and closed by 9.1 (ANCHOR-05, MIGR-01, MIGR-06, MIGR-07,
MIGR-08). Phase 9.1: verification 11/11; UAT 10 passed / 1 accepted-and-disclosed
(AG-01); security 37/37, `threats_open: 0`. Full suite 369 PASS / 0 FAIL / 1 SKIP.

Shipped in PR #18 (`81404e4`), tagged `v0.7.0`. Merged with history rather than
squashed, so `09-03`'s RED commits still precede `09-04`'s GREEN on `main`.

Full phase detail — both phase goals, all success criteria, the ordering
constraints, and the wave breakdowns — is preserved verbatim in
[`milestones/v0.7.0-ROADMAP.md`](milestones/v0.7.0-ROADMAP.md).
Requirements: [`milestones/v0.7.0-REQUIREMENTS.md`](milestones/v0.7.0-REQUIREMENTS.md).
Decision record: [ADR-0010](../docs/decisions/0010-region-aware-spec-11-placement.md).

</details>

### 🚧 v0.8.0 Enforcement, Not Intention (In Progress)

**Milestone Goal:** Every gate this host claims to bind actually fires, every
migration actually runs, and every assertion has been observed failing — closing
the "nominal enforcement" debt class the last two milestones shipped on top of.

**Milestone-wide standard applied to every phase below:** a guard is not shipped
until it has been *observed failing*. Every new assertion is mutation-proven —
break the thing it checks, watch it go RED, restore, watch it go GREEN — and the
verifier independently re-runs that cycle rather than trusting an executor's
claim.

**Build order** (dependency-derived, not discretionary — see
`research/SUMMARY.md` "Implications for Roadmap"): Phase 10 (CI-01) lands first,
serial, blocking — nothing else in this milestone is "verified" until real,
remote CI exists. Phases 11, 12, 13 then parallelize (no shared file surface).
Phase 14 (paired §11 markers) lands last — not because anything depends on it,
but because it is the highest-consequence, most structurally novel change in the
milestone and most benefits from a CI-verified baseline.

- [ ] **Phase 10: CI That Can Prove Failure** - Replace the Phase-0 placeholder workflow with real, remote CI that runs the full suite and is proven able to go red
- [ ] **Phase 11: Migration Chain Repair** - Heal migration 0007's chain break for real installs and close MIGR-08's residual coverage gap
- [ ] **Phase 12: Path Safety & Review Debt** - Real symlink-escape guard for `--file`, plus the four independently-scoped 09-REVIEW.md fixes
- [ ] **Phase 13: Native Enforcement — Plan-Review Hook** - Bind the plan-review gate to codex-cli's native `PreToolUse` surface, project-scoped, superseding ADR-0009 d.9
- [ ] **Phase 14: Paired §11 Markers** - Explicit start/end markers bound the managed §11 block, retiring the inference-based defect class AG-01 belongs to

## Phase Details

### Phase 10: CI That Can Prove Failure
**Goal**: Real, remote CI exists and is proven able to go red — nothing else in
this milestone is "verified" until it does. Closes the retrospective's named
dominant failure mode across the last two milestones (merging on a local green).
**Depends on**: Nothing (first phase of v0.8.0; continues from Phase 9.1)
**Requirements**: CI-01, CI-02
**Success Criteria** (what must be TRUE):
  1. `.github/workflows/ci.yml` runs on push and pull_request to `main`, checks
     out with `submodules: recursive` (the harness hard-fails without
     `vendor/agenticapps-shared`), and runs `migrations/run-tests.sh` unfiltered
     (already exercising `test_drift`) on an ubuntu + macOS matrix — with the
     job's own exit status reflecting the suite's (no `|| true`, no
     informational-only bolt-on).
  2. A scratch PR carrying a deliberately reverted guard is observed failing in
     the GitHub Actions UI itself — not merely in a local log — proving CI can go
     RED, not just GREEN.
  3. The new check is registered as a required status check on `main`'s branch
     protection, confirmed via `gh api repos/:owner/:repo/branches/main/protection`.
**Plans**: TBD

### Phase 11: Migration Chain Repair
**Goal**: Every real install stuck between 0.4.0 and 0.5.0 can reach 0008/0009's
already-correct floor-check logic, and MIGR-08's execution-coverage gap — the one
residual of the exact can't-fail-assertion class Phase 9.1 existed to close — is
shut.
**Depends on**: Phase 10
**Requirements**: MIGR-10, MIGR-11, MIGR-08
**Success Criteria** (what must be TRUE):
  1. A fixture seeded at 0.4.0 with none of migration 0007's artifacts, run
     through the new forward migration, ends with 0007's Steps 1/2/4 payload
     present (config block + AGENTS.md ritual-tail section) and
     `.codex/workflow-version.txt` reading `0.5.0` — the fixture is observed
     failing against the unfixed chain (RED) before the new migration exists, and
     passing (GREEN) after.
  2. A document-contract fixture asserts the new migration's pre-flight literal
     executable line contains no `skills/agentic-apps-workflow` substring —
     proving it never repeats V-01's defect class (a scaffolder-relative grep no
     real target project satisfies).
  3. `update-codex-agenticapps-workflow/SKILL.md` Stage D documents the operator
     path for a project stuck on 0007's permanent pre-flight abort once the new
     migration supersedes the same `0.4.0→0.5.0` transition — readable as a
     defined, non-looping procedure, not a dead end.
  4. MIGR-08's fixture extracts migration 0008's Step 4 Apply block via
     `extract_step_block` (never a hand-copied transcription), executes it
     against a sandbox seeded at the pre-migration value, and asserts exact
     `.codex/workflow-version.txt` content equality — breaking the write line is
     observed RED, restoring it is observed GREEN.
**Plans**: TBD
**Notes**: The new migration is the next available migration ID — kept
distinct from any ADR number per REV-04's numbering-collision fix (Phase 12);
this phase does not itself claim a specific number, that is a plan-time
decision.

### Phase 12: Path Safety & Review Debt
**Goal**: The `--file` guard actually stops a symlink-based escape (not just a
lexical `..`), and the four independently-scoped `09-REVIEW.md` defects are each
closed with their own proof — not batched into one undifferentiated cleanup.
**Depends on**: Phase 10
**Requirements**: WR-03, REV-01, REV-02, REV-03, REV-04
**Success Criteria** (what must be TRUE):
  1. `--file`'s guard rejects a symlink-resolved parent-directory escape and a
     sibling-prefix collision — both previously passed by the lexical-`..`-only
     check — via the existing `_canon_dir`/`_is_contained` helpers, reused rather
     than reinvented. Each fixture is observed failing under the old check and
     passing under the new.
  2. `validate-0009-anchor.sh`'s stdout is proven genuinely deterministic: a
     full-script grep for every mirror-derived stdout value (not just the
     banner) is mutation-proven — a reintroduced non-deterministic value is
     observed RED, its removal observed GREEN.
  3. `extract_step_block`, exercised against a synthetic 10+-step document,
     extracts `### Step 1` without matching `### Step 10`+ — observed failing
     under the old prefix match, passing under the fix.
  4. CASE 1's previously-unasserted line drop is caught by a
     strictly-smaller-count assertion (no hardcoded line number) — breaking the
     drop is observed RED, restoring it is observed GREEN.
  5. `docs/decisions/README.md` is corrected so an ADR number and a migration
     number can no longer be conflated (REV-04) — the exact hazard this
     roadmapper was told to honor when assigning Phase 11/13/14's new migration
     numbers.
**Plans**: TBD
**Notes**: This phase's ADR-0009 touch (recording WR-03's d.12 reversal) is
sequenced to land **before** Phase 13's ADR-0009 touch, per research guidance —
avoids two PRs racing the same file region. DOC-03's full dated Correction
section (covering d.9 superseded, d.12 reversed, and the "global vs
per-project" factual correction) is written in full in Phase 13, where
ADR-0009 lands last; DOC-03 is mapped there for coverage accounting, not here.

### Phase 13: Native Enforcement — Plan-Review Hook
**Goal**: The plan-review gate blocks unconditionally on codex-cli's native
`PreToolUse` surface, installed project-scoped, superseding ADR-0009 decision
9's agent-mediated binding.
**Depends on**: Phase 10
**Requirements**: HOOK-01, HOOK-02, HOOK-03, DOC-03
**Success Criteria** (what must be TRUE):
  1. **[Spike, before design finalizes]** A short empirical spike resolves the
     two open trust-ledger gaps — the sha256 `trusted_hash` pre-seeding
     mechanics, and whether project-layer trust and per-hook trust are one gate
     or two — with findings recorded before the wrapper/migration design is
     finalized. (Author a known hook, trust it via `/hooks`, diff the ledger;
     run `codex` inside a fresh clone carrying a new `.codex/hooks.json` and
     observe exactly what is prompted.)
  2. A disallowed edit, driven through the real Codex CLI tool surface in a live
     human-observed session, is observably prevented end-to-end — not merely a
     script-level unit test passing.
  3. The wrapper script's `exit 2` fallback path is proven to always write
     non-empty stderr — a mutation that empties stderr is observed to fail OPEN
     (RED, the milestone's nemesis), and the fix is observed to fail CLOSED
     (GREEN).
  4. The `PreToolUse` entry installs into a project-scoped `<repo>/.codex/hooks.json`
     (merge-don't-clobber, per the `0000-baseline` Step 6 precedent) and the
     hooks feature flag is enabled; the binding is verified firing in the target
     repo AND verified NOT firing in a second, unrelated repo on the same
     machine.
  5. ADR-0009 carries a dated Correction section recording: decision 9
     superseded (HOOK-01's unconditional native block), decision 12 reversed
     (WR-03's real guard, Phase 12), and the factual correction of the "native
     hooks are global rather than per-project" claim (falsified by codex-cli's
     project-scoped `.codex/hooks.json` layer).
**Plans**: TBD
**Notes**: Research/spike-needed phase. Begin execution with the empirical
trust-ledger spike (Success Criterion 1) before finalizing wrapper/migration
design — recommend `--research-phase` or a dedicated spike plan first. The new
migration installed here uses the next available migration ID, kept distinct
from any ADR number (REV-04).

### Phase 14: Paired §11 Markers
**Goal**: The managed §11 block's extent is bounded by explicit markers, not
inferred from heading/terminator position — retiring the whole inference-based
defect class AG-01 belongs to, durably, rather than hardening one more instance
of it.
**Depends on**: Phase 10 (benefits from a CI-verified baseline). Sequenced last
in the milestone deliberately — not because Phases 11–13 block it, but because
it is the highest-consequence, most structurally novel change (new marker
convention, new idempotency shape) and most benefits from freshly re-established
fixture/mutation-gate discipline.
**Requirements**: MARK-01, MARK-02, MARK-03, MARK-04, DOC-04
**Success Criteria** (what must be TRUE):
  1. AG-01 (the region-*tail* strip hazard — the strip eating
     `<!-- gitnexus:end -->` when §11 sits at a managed region's tail) is
     reproduced failing under the pre-marker inference logic and observed
     passing under the marker-bounded logic — both fixture states are exercised,
     not just the final green one. Reverses the 2026-07-16 accepted-and-disclosed
     ruling.
  2. Each of the four terminator-alternation branches (`## ` heading | anchored
     `gitnexus:start` | EOF | new end marker, strictly additive) is
     mutation-tested independently — breaking each branch's detection is
     observed RED, restoring it is observed GREEN. This is the single
     highest-consequence pitfall in the milestone: narrowing the alternation to
     the marker alone would break every already-migrated project in the fleet.
  3. `12-idempotent-rerun` stays green — unmodified, or changed only with an
     explicitly mutation-justified equivalent — with no narrowing of the widened
     three-way alternation (the Constraints-section invariant).
  4. The paired-markers migration's Apply blocks use `mktemp` on the same
     filesystem (preserving atomic `mv`), closing IN-04 (predictable temp-file
     names in CWD) by supersession — confirmed without editing immutable
     migration 0009.
  5. ADR-0010 carries a dated Correction section closing its lead open
     follow-up: AG-01 is resolved by MARK-01..03.
**Plans**: TBD
**Notes**: Closing-marker syntax (e.g. mirroring the existing
`<!-- BEGIN/END: agentic-apps-workflow sections -->` idiom) is a plan-time
design decision, not yet chosen. The new migration here uses the next available
migration ID, kept distinct from any ADR number (REV-04).

## Progress

| Phase                                          | Milestone | Plans Complete | Status      | Completed  |
| ----------------------------------------------- | --------- | --------------- | ----------- | ---------- |
| 8. Plan-Review Gate                             | v0.6.0    | 9/9             | Complete    | 2026-07-15 |
| 9. Region-Aware §11 Placement                   | v0.7.0    | 5/5             | Complete    | 2026-07-16 |
| 9.1 §11 Strip Runaway (INSERTED)                | v0.7.0    | 7/7             | Complete    | 2026-07-15 |
| 10. CI That Can Prove Failure                   | v0.8.0    | 0/TBD           | Not started | -          |
| 11. Migration Chain Repair                      | v0.8.0    | 0/TBD           | Not started | -          |
| 12. Path Safety & Review Debt                   | v0.8.0    | 0/TBD           | Not started | -          |
| 13. Native Enforcement — Plan-Review Hook        | v0.8.0    | 0/TBD           | Not started | -          |
| 14. Paired §11 Markers                          | v0.8.0    | 0/TBD           | Not started | -          |

## Known Follow-ups

Open debt only. Items scheduled into and closed by Phase 9.1 (V-01, V-02, V-03,
CR-01, CR-02, CR-03, the idempotent-rerun fixture, WR-02) are resolved — their
full reproduction records and closure evidence live in
[`milestones/v0.7.0-ROADMAP.md`](milestones/v0.7.0-ROADMAP.md),
`09-VERIFICATION.md`'s Gap Closure Record, and `09.1-VERIFICATION.md`.

### Now scheduled into v0.8.0 (Phases 10–14)

Every item below carried out of v0.6.0/v0.7.0 unscheduled is now mapped to a
v0.8.0 phase — see `.planning/REQUIREMENTS.md` Traceability for the exact
REQ-ID → phase mapping.

- **AG-01 — region-tail strip hazard** (accepted-and-disclosed 2026-07-16, not
  fixed). → **Phase 14** (MARK-01..04, DOC-04). The acceptance is reversed by
  this milestone: paired §11 start/end markers are now the durable fix.
- **Migration `0007`'s pre-flight defect** (V-01's twin — a project-relative
  `skills/` path). → **Phase 11** (MIGR-10).
- **`09-REVIEW.md` WR-05** (banner determinism) and **IN-01..IN-04**
  (`extract_step_block` prefix-matching; CASE 1 unasserted line drop;
  ADR/migration numbering collision; predictable temp-file names in CWD). →
  **Phase 12** (WR-05 is REV-01; IN-01 is REV-02; IN-02 is REV-03; IN-03 is
  REV-04). IN-04 → **Phase 14** (closed by MARK-04's `mktemp`, by supersession,
  not by editing immutable migration 0009).
- **CI verifies nothing** (`.github/workflows/ci.yml` still the Phase-0
  placeholder). → **Phase 10** (CI-01, CI-02).
- **The plan-review gate is agent-mediated, not enforced** (ADR-0009 decision
  9). → **Phase 13** (HOOK-01, HOOK-02, HOOK-03, DOC-03).
- **WR-03** (`--file` symlink-traversal guard is lexical-`..`-only, ADR-0009
  decision 12). → **Phase 12** (WR-03). The acceptance is reversed by this
  milestone: a real resolution guard replaces the lexical check.

### Carried out of v0.6.0 — deferred beyond v0.8.0

Tracked as Future Requirements in `.planning/REQUIREMENTS.md`:

- **`MIGR-FUT-01`** — the update skill's multi-hop chain-selection defect: a
  project at 0.4.0 picks up only one migration per invocation rather than
  cascading 0007-fix→0008→0009 in a single pass (0008's own Notes). v0.8.0
  deliberately ships the weak chain-acceptance bar (each migration, run
  individually, completes without aborting) and names this as the deferred
  remainder.
- **Upstream grandfather-conflation defect** — recorded as an open question for
  a `claude-workflow` bug report, not resolved unilaterally here.

### Upstream — filed, awaiting action

- **CR-01** — [claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90),
  OPEN. Still live upstream at `f9354cc:0029:222-241`. Not v0.8.0 scope; tracked
  here only so it isn't lost.

---
*Last updated: 2026-07-16 — v0.8.0 "Enforcement, Not Intention" roadmap created:
Phases 10–14 mapped from all 19 in-scope v0.8.0 requirements (MIGR-FUT-01
deferred, not mapped). Phase numbering continues from 9.1 per PROJECT.md
constraint.*
