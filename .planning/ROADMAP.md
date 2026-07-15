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
mutation — the review tried to break them and could not.

**Provenance of the defects (corrected by 09.1-RESEARCH.md — the pre-research
claim that all were "inherited from upstream and ported faithfully" was wrong):**
CR-01 is genuinely upstream's and still live at `f9354cc` (file it). CR-02 was
upstream's but is **already fixed** at `f9354cc` (port the fix). **V-01 is ours** —
the port dropped upstream's `.claude/` prefix (do not file it). CR-03/V-02/V-03 are
ours. Phase 9's suite reported 314 PASS / 0 FAIL while the migration never ran on
any real project — that combination, not the individual bugs, is what this phase
is really correcting.

**Depends on**: Phase 9 (5/5 plans executed; 0009 exists and its suite is GREEN)

**Ordering constraints**:

1. **RED before GREEN, again.** The runaway must be captured as a *failing*
   fixture against the current 0009 before the awk is touched. Phase 9's own
   discipline; the repro is already written (16 lines → 4 lines, provenance
   present + drifted H2).
2. **Re-pin to `f9354cc`, then port what upstream already fixed.** (Corrected by
   09.1-RESEARCH.md — supersedes Phase 9's D-48.) **`8520f90` was a PR-branch
   commit that never landed on main.** PR #89 squash-merged as `f9354cc`, which is
   upstream HEAD. Upstream **already fixed CR-02** there: `PROV_RE` is anchored in
   all three sites and a `11-prose-mention-provenance` fixture ships with it —
   that is criterion 3, already written. **Port it; do not re-invent it.**
   **CR-01 is still live upstream** at `f9354cc:0029:222-241`, and upstream's new
   "Known limitations" section lists CRLF and fenced markers but *not* the runaway
   — they are unaware, not accepting. So the upstream bug report is **CR-01 only**.
   Re-check `origin/main` before locking the new pin: upstream revised 0029 four
   times in one afternoon.
3. **V-01 is OURS — do not file it upstream.** (Corrected by 09.1-RESEARCH.md.)
   Upstream greps `.claude/skills/agentic-apps-workflow/SKILL.md`, a path its own
   setup skill creates. **Our port dropped the `.claude/` prefix.** On the Codex
   host, skills install globally at `${CODEX_HOME}/skills/…` and the project
   version lives in `.codex/workflow-version.txt`; `skills/agentic-apps-workflow/`
   is *this scaffolder repo's own source tree*, which is why it looked right to its
   author. A porting error, not an inherited defect.
4. **No assertion weakening.** As in 09-04: the fixtures must be satisfied by the
   code, never the reverse.
   *Q3 resolved at planning time — the trap does not fire.* There is no
   `anchor-parity` count assertion in `run-tests.sh`; the only alternation check is
   a substring-presence gate. The MEDIUM-confidence research guess that a count
   assertion would break is falsified. Declining the un-latch rule keeps the
   alternation at 2 copies regardless. Plans still re-check the count deliberately
   and record it.
5. **A guard that cannot fail must not ship.** The inverse of constraint 4, and the
   lesson of CR-03/V-02: if a proposed guard is unreachable because an earlier gate
   always fires first, do NOT ship it as decoration — prove reachability by mutation,
   and remove it if nothing reaches it. Record the removal and its reasoning.

**Requirements**: ANCHOR-05, MIGR-01, MIGR-04, MIGR-06, MIGR-07, MIGR-08, MIGR-09, TEST-02, TEST-03, DOC-01

**Success Criteria** (what must be TRUE):

  0. **(BLOCKER, do first) 0009 actually runs on a real target project.** Its
     pre-flight reads the version floor from `.codex/workflow-version.txt` — the
     0008 precedent — not from a project-relative `skills/` path. No `skills/`
     path remains in pre-flight, Step 3, or `applies_to`. MIGR-08 (migration
     records the version) is separated from MIGR-09 (this repo's own bump), as
     0008 kept them. Proven by porting 0008's `no-scaffolder-tree` regression
     fixture (`0008 run-tests.sh:1633-1706`) and REMOVING `_m0009_mk_project`'s
     synthetic SKILL.md manufacture (`run-tests.sh:3366-3372`) — the suite must
     stop manufacturing a condition no real project has. That fixture must be
     observed FAILING against the current 0009 first.
  1. A fixture reproduces the runaway (provenance present, exact H2 drifted) and
     is observed FAILING against the current 0009 before any awk change.
  2. **Provenance present + exact H2 absent ⇒ REFUSE (abort exit 3), leaving
     AGENTS.md byte-identical.** (User ruling on RESEARCH Q1, 2026-07-15.) One rule
     covers *both* reproduced runaway shapes — drifted H2, and orphaned provenance
     with no following `## ` — because both are exactly "provenance present, exact
     H2 absent". This closes CR-01 **by construction**: a strip that refuses to run
     cannot run away. Consistent with 0009's existing never-overwrite-a-hand-paste
     conflict branch. The abort message must name the orphaned provenance line and
     tell the operator to restore the heading or remove the line.
     Rejected alternative: heal-and-duplicate (un-latch at the boundary and insert
     anyway) — no data loss, but silently leaves two similar §11 headings that a
     future migration's own conflict grep would trip on.
     **`END { if (in_block && !swallowed_own_h2) exit 1 }` is REQUIRED and is a
     MECHANISM, not defense-in-depth** — corrected at planning time, superseding
     this criterion's earlier framing and the RESEARCH/REVIEW recommendation.
     **The un-latch rule is NOT adopted.** With the refuse gate in place,
     un-latching at a structural boundary implements exactly the heal-and-duplicate
     semantics Q1 rejected: on the *mixed-provenance* shape it silently deletes the
     drifted block's body. Without un-latching, that shape latches and the END guard
     refuses — which is the correct outcome. Un-latching would also add a third copy
     of the alternation; declining it keeps the count at 2.
     **Falsifiability:** the refuse gate is a file-global grep, so it cannot see a
     file whose first block is healthy and whose second block has drifted (the exact
     H2 *is* present). Fixture `15-mixed-provenance-unresolved` is that shape and is
     the ONLY thing that makes the END guard falsifiable. Without it the END guard is
     a guard never observed catching anything — this phase's own defect class.
  3. The provenance regex is anchored, **ported from upstream `f9354cc`** along
     with its `11-prose-mention-provenance` fixture — proving a prose mention
     cannot trigger the strip. The anchor must NOT lose `@[^[:space:]]+`'s
     deliberate any-version match (idempotent re-runs across versions depend on it).
     **Fixture numbering (Q4):** upstream's ported fixture owns `11-`; criterion 6's
     idempotent re-run fixture must therefore take the next free number, not `11-`.
  4. **The post-strip integrity check can actually fail — or is deliberately removed
     as unreachable.** (Reframed at planning time from "implement an h2-count guard"
     to a *determination*, per constraint 5.) The original defect stands: 0009's
     `grep -q` validates the tmp AFTER the insert pass has re-added the heading it
     checks for, so it cannot fail. But with the refuse gate + END guard, every shape
     that would lose a foreign `## ` now aborts at `strip_rc == 4` first — which would
     make a replacement h2-count guard **dead by construction**. Shipping it anyway
     would reproduce CR-03 inside CR-03's own fix.
     Required: a mutation-based reachability test. If nothing reaches the guard,
     REMOVE it and record the rejection in ADR-0010. Criterion 4 is then satisfied by
     the `exit 4` diagnostic branch, whose falsifiability fixture 15 observes.
  5. `test -s`'s assertion is live: deleting the guard fails the suite. The
     document check skips comment lines, and case 10(a) isolates layer 1 from the
     tail sentinel (mirroring the version-gate control 12 lines earlier).
  6. `12-idempotent-rerun` exists (Q4 resolved: upstream's ported prose-mention
     fixture owns `11-`; fixture `07` is the *marker* twin, so `11-` is genuinely
     free for the port): narrowing the strip terminator fails the suite.
  7. MIGR-07's guard is live (V-02): `state-a` uses a genuinely **off**-anchor
     fixture so the `:3553` "D-31/MIGR-07" assertion can fail for the reason it
     claims.
  8. `.codex/workflow-version.txt` and `SKILL.md` agree (V-03), and the drift test
     reads the version file so a future split is caught.
  9. ADR-0010 records: the runaway; the D-26 correction ("bounded by construction"
     was false); the V-01 pre-flight regression against 0008's T-08-38 precedent,
     **recorded as a porting error (dropped `.claude/` prefix), not an inherited
     defect**; the Q1 refuse-vs-heal ruling with its rejected alternative; and
     **D-48's re-pin from `8520f90` (a PR-branch commit that never landed) to
     `f9354cc` (PR #89's squash merge)** — with CR-02's fix ported from it rather
     than re-invented.
  10. Upstream defect filed against `claude-workflow` for **CR-01 only** — CR-02 is
      already fixed at `f9354cc`, and V-01 is ours. The report should note that
      upstream's "Known limitations" omits the runaway, so this is new information
      to them.

**Plans**: 7 plans in 6 waves. Wave structure **structurally enforces** RED-before-GREEN
(ordering constraint 1): the two RED plans touch only `run-tests.sh` and the two GREEN plans
touch only `0009-*.md`, so a RED plan physically cannot fix what it reproduces. 09.1-01
(criterion-0 RED) gates 09.1-02 (GREEN); 09.1-04 (runaway RED) gates 09.1-05 (GREEN). Nearly
every plan touches `run-tests.sh` or `0009-*.md`, so same-file plans are wave-separated
rather than falsely parallelized; wave 2 is the only genuine parallelism.

- [x] 09.1-01-PLAN.md — Criterion 0 RED: strip `_m0009_mk_project`'s synthetic SKILL.md, port 0008's `no-scaffolder-tree` fixture; suite OBSERVED RED (MIGR-01, TEST-02) — wave 1
- [x] 09.1-02-PLAN.md — Criterion 0 GREEN: pre-flight floor reads `.codex/workflow-version.txt`; Step 2 deleted, MIGR-08/MIGR-09 separated (MIGR-01, MIGR-08, MIGR-09) — wave 2
- [x] 09.1-03-PLAN.md — Criterion 8: `test_drift`'s consumer-side third leg (free RED), V-03 version split closed (MIGR-09, TEST-02) — wave 2
- [x] 09.1-04-PLAN.md — Criteria 1/2/3/7 RED: fixtures 13/14/15 runaway + 11-prose-mention ported from `f9354cc`; off-anchor `state-a` + mirror single-`##` guard (ANCHOR-05, TEST-02, TEST-03, MIGR-07) — wave 3
- [x] 09.1-05-PLAN.md — Criteria 2/3/4 GREEN: anchored `PROV_RE`, the Q1 refuse gate, the END fail-closed guard, a distinguishable strip diagnostic (ANCHOR-05, MIGR-01, MIGR-04) — wave 4
- [ ] 09.1-06-PLAN.md — Criteria 5/6: `test -s` made live, `12-idempotent-rerun`; both proven by verified deletion mutations (MIGR-06, TEST-03, ANCHOR-05) — wave 5
- [ ] 09.1-07-PLAN.md — Criteria 9/10: ADR-0010 corrections, WR-02, upstream CR-01 filing (DOC-01) — wave 6

**Planning rulings** (2026-07-15, verified against live files):

- **Q3's inverse trap does not fire.** There is **no `anchor-parity` count assertion** in
  `run-tests.sh` — the only alternation check is `assert_extracted_shape … 'gitnexus:start'`
  (substring presence, not a count). The alternation stays at **2 copies** because the
  reviewer's un-latch rule is **not adopted**: it implements the rejected heal-and-duplicate
  semantics, RESEARCH reproduced that it is insufficient alone, and without it the
  mixed-provenance shape latches and the END guard refuses — which is the Q1 ruling's intent.
- **A4 confirmed.** Pre-flight guard 4 says *"is missing its final section"*; it does **not**
  contain `missing or empty`, so criterion 5's `case` can isolate the `test -s` layer.
- **D-48's new pin is safe to lock.** `git fetch` confirms `f9354cc` is still upstream
  `origin/main` HEAD (research freshness re-checked at planning time).
- **Q4 numbering.** `07-prose-mention-not-a-region` is the *marker* twin, so `11-` is free:
  `11-prose-mention-provenance` (upstream's port), `12-idempotent-rerun`, `13/14/15` runaway.
  The ROADMAP's criterion-6 label `11-idempotent-rerun` is **aliased to `12-`**.
- **Criterion 4 is a determination, not an assumption.** With refuse gate + END guard, the
  h2-count strip-integrity guard may be dead by construction. 09.1-05 Task 3 settles it by
  verified mutation and **removes the guard if nothing reaches it** — shipping an
  unfalsifiable guard here would reproduce CR-03 inside CR-03's own fix.
- **Research-added fixture 15 (`mixed-provenance-unresolved`)** is the ONLY shape the
  file-global refuse gate cannot see, and therefore the END guard's only falsifiability proof.
- **WR-01/Q2 folded in cheaply** (mirror single-`##` guard, 09.1-04 Task 3) — the refuse gate
  rests on that invariant. **WR-02 included** per orchestrator ruling, overriding RESEARCH's
  deferral. WR-05, IN-01..IN-04 and migration 0007 stay deferred.

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

**Requirements**: ANCHOR-01, ANCHOR-02, ANCHOR-03, ANCHOR-04, ANCHOR-05, MIGR-01, MIGR-02, MIGR-03, MIGR-04, MIGR-05, MIGR-06, MIGR-07, MIGR-08, MIGR-09, TEST-01, TEST-02, TEST-03, TEST-04, SETUP-01, DOC-01, DOC-02

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
| 9.1 §11 Strip Runaway (INSERTED)| v0.7.0    | 5/7 | In Progress|  |

## Known Follow-ups

### Scheduled into Phase 9.1 (BLOCKER — from 09-VERIFICATION.md)

- **V-01 — 0009 aborts on every project it exists to fix.** Reproduced: on a
  realistic target project (`AGENTS.md` + `.codex/`, no `skills/` tree), 0009's
  pre-flight gate at `:95-101` greps the **project-relative** path
  `skills/agentic-apps-workflow/SKILL.md` for its version floor, fails, and exits 3.
  **Step 1 — the entire §11 heal — never runs.** Same path is sed'd at `:369` and
  named in `applies_to` at `:9`.
  **This is a regression against an established, documented precedent.** Migration
  0008 names this exact defect (T-08-38, `0008:470-487`): "0007's pre-flight greps
  `skills/agentic-apps-workflow/SKILL.md` … **No target project has a local
  `skills/` tree** … aborts with exit 3 on every real install — **a defect this
  migration does not replicate**." 0008 reads `.codex/workflow-version.txt`
  instead. 0009 reintroduced 0007's bug in all three of its locations.
  **The suite cannot see it** because `run-tests.sh:3366-3372` `_m0009_mk_project`
  manufactures a synthetic `skills/agentic-apps-workflow/SKILL.md` in every 0009
  sandbox — the exact practice `run-tests.sh:918-919` refused for 0008 ("no 0008
  sandbox here manufactures a synthetic SKILL.md"). 0008's `no-scaffolder-tree`
  regression fixture (`:1633-1706`) was never ported. **314 PASS / 0 FAIL is fully
  consistent with a migration that never runs.**
  Root cause: MIGR-08 (the migration records the version) and MIGR-09 (**this
  repo's own** bump) were conflated into one step. 0008 kept them apart on purpose.
  **Relation to CR-01:** compounding, not duplicate. V-01 = it does not run on real
  projects. CR-01 = when it *does* run, it can destroy data.
  Fix: read the floor from `.codex/workflow-version.txt` per the 0008 precedent,
  drop the `skills/` path from pre-flight/Step 3/`applies_to`, separate MIGR-08 from
  MIGR-09, and port 0008's `no-scaffolder-tree` fixture so the suite stops
  manufacturing the condition reality lacks.
- **V-02 — MIGR-07's guard is vacuous.** Behavior is correct (verified live: exit 0
  on a genuinely off-anchor file), but the `state-a` fixture
  (`run-tests.sh:3509-3516`) is **on**-anchor, so the assertion at `:3553` labelled
  "D-31/MIGR-07" cannot fail for the reason it claims. Same dead-assertion class as
  CR-03.
- **V-03 — version split.** `.codex/workflow-version.txt` reads `0.6.0` while
  `SKILL.md:3` reads `0.7.0`. Diverges from the 0008 precedent (`98c06f5` bumped
  both); the drift test never reads the version file, so nothing catches the split.
  Same root confusion as V-01.

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

**Upstream note — CORRECTED by 09.1-RESEARCH.md (2026-07-15).** The pre-research
characterization below was wrong in two ways; both corrections are load-bearing:

- **`8520f90` never landed on main.** It was a PR-branch commit. PR #89 squash-merged
  as `f9354cc` = upstream HEAD. D-48's pin must move.
- **CR-02 is ALREADY FIXED upstream at `f9354cc`** — `PROV_RE` anchored in all three
  sites, shipped with a `11-prose-mention-provenance` fixture. **Port it, don't
  re-invent it.** Criterion 3 is largely handed to us.
- **CR-01 is still live upstream** (`f9354cc:0029:222-241`) — entry is now anchored,
  but the exit is still gated behind `swallowed_own_h2`. Upstream's "Known
  limitations" lists CRLF and fenced markers but **not** the runaway: they are
  unaware, not accepting. **File CR-01 upstream — and only CR-01.**
- **V-01 is NOT upstream's.** Upstream greps `.claude/skills/agentic-apps-workflow/
  SKILL.md`, a path its own setup skill creates; **our port dropped the `.claude/`
  prefix**. A codex-side porting error. Do not file it.

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
