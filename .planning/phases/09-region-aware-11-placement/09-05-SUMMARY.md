---
phase: 09-region-aware-11-placement
plan: 05
subsystem: docs/decisions
tags: [adr, reasoning-trail, rejected-alternatives, corrected-invariant, changelog, setup-parity]
requires:
  - "09-04 (migration 0009 shipped — the decision this ADR records)"
  - "09-01 (09-VALIDATION-EVIDENCE.md — the evidence the ADR cites rather than restates)"
provides:
  - "docs/decisions/0010-region-aware-spec-11-placement.md — the anchor decision, BOTH rejections, the corrected invariant, the pin, the accepted limitations"
  - "docs/decisions/README.md — ADR-0010 indexed (an unindexed ADR is invisible)"
  - "CHANGELOG.md — 0.7.0 release-altitude entry above 0.6.0"
  - "skills/setup-codex-agenticapps-workflow/SKILL.md — SETUP-01 signpost (prose only)"
  - "ROADMAP Success Criterion 6 closed: SETUP-01 + DOC-01 + DOC-02"
affects:
  - "the next author who touches the anchor or any terminator over the §11 block"
tech-stack:
  added: []
  patterns:
    - "Record the rejected alternatives, not just the outcome — the obvious reading is one of the rejections"
    - "Record a corrected-false claim AS false rather than deleting it (T-09-17)"
    - "Cite recorded evidence; never restate its claims as fresh assertions"
    - "Bound a claim with its limitation in the same section (D-45)"
key-files:
  created:
    - docs/decisions/0010-region-aware-spec-11-placement.md
  modified:
    - docs/decisions/README.md
    - CHANGELOG.md
    - skills/setup-codex-agenticapps-workflow/SKILL.md
decisions:
  - "ADR states the invariant as WIDENED and quotes the earlier false claim, marking it false — deleting it would let the next author re-derive it"
  - "Coverage gaps recorded IN the ADR's Verification section, not only in this summary: the ADR is what a future author reads"
  - "Setup parity section placed between Consequences and Verification — it is a recorded fact, not a decision or an alternative"
metrics:
  duration: ~15 min
  completed: 2026-07-15
  tasks: 3
  commits: 3
---

# Phase 9 Plan 05: Record the Decision, the Setup Fact, and the Release Note — Summary

Wrote ADR-0010 recording the region-aware §11 anchor decision **with both rejected
alternatives and the corrected invariant** — the two things a decision-only record would
have left the next author to rediscover by shipping a file-destroying bug — plus SETUP-01's
single-source fact bounded by its honest limitation, and a release-altitude CHANGELOG entry.
Closes ROADMAP Success Criterion 6. Documentation-only; the suite did not move.

## What Was Built

| Artifact | Purpose |
|---|---|
| `docs/decisions/0010-region-aware-spec-11-placement.md` | 344 lines. The reasoning trail: 6 numbered decisions, 3 options (2 rejected), the widened invariant, the D-48 pin, setup parity, coverage gaps, 7 follow-ups. |
| `docs/decisions/README.md` | One Index row, matching its neighbours' format exactly. |
| `CHANGELOG.md` | `## [0.7.0] — 2026-07-15` under `### Fixed`, placed above `## [0.6.0]`. |
| `skills/setup-codex-agenticapps-workflow/SKILL.md` | A prose-only signpost at the place someone would wrongly look first. |

## The ADR's Decision List

1. **The anchor rule (D-21)** — insert before the first `(/^## / || /^<!-- gitnexus:start -->$/)`,
   EOF fallback. Anchored regex mandatory; a substring match fails only the prose-mention case,
   which is why it is easy to get wrong and never notice.
2. **The corrected invariant — WIDENED, not preserved.** The ADR's most important item, and the
   documentation-layer twin of the phase's highest-severity mechanic (T-09-17).
3. **The structural strip boundary (D-24/D-25/D-26)** — with D-25's rejected content sentinel
   and its runaway-strip reasoning, and D-26's strip-blind stance.
4. **Re-vendor from the mirror (D-27), guarded twice (D-28.1)** — why `test -f` was insufficient,
   and why the tail-sentinel check is *not* D-25's rejected sentinel in disguise.
5. **Rollback is `git checkout AGENTS.md` (D-47)** — framed in ADR-0009's decision-11/12
   "deliberate tradeoff, recorded" shape, with its cost stated (git-dependent; restores the whole
   file). Fixture 08 kept anyway as the regression guard.
6. **The upstream pin (D-48)** — full SHA, why, and the same-day convergence.

Both rejections are recorded as `### A.` / `### B.` options with reasoning — including **D-22.2
("always immediately after the H1"), the alternative the source prompt omitted entirely** and
therefore the one most likely to be re-proposed.

## D-23 Precision — the §12 Sentence, Quoted

The ADR characterizes §12 as an advisory and does **not** upgrade it to a conformance gate:

> What that violates, stated precisely: §12's placement rule is an **advisory**.
> `spec/12:95-97` says so in its own words — *"This requirement is advisory, lower-case 'should.'
> It is not RFC 2119 and not a conformance gate, but host implementations are encouraged to honor
> it."* Option A therefore fails an advisory this host chooses to honor, not a normative gate.
> Both the source prompt and the reference design phrase this loosely; this ADR does not, and
> does not upgrade the advisory to a conformance obligation in order to make the rejection sound
> stronger than it is.

**Verified at source, not inherited:** I read `spec/12-authoring-conventions.md:93-113` directly.
The quoted wording is verbatim from lines 95-97.

## T-09-17 — the False Claim Recorded AS False

The single occurrence of "invariant survives" in the ADR sits inside the passage recording it as
false (ADR lines 103-110):

> An earlier draft of this repo's own decision record claimed instead that the change was *"a
> one-alternation delta, so the structural **invariant survives**: the block is still always
> followed by a `## ` or EOF."* **That claim was false, and it was load-bearing.**

The corrected form is stated as a blockquote above it: *"The block is always followed by a `## `
line, an anchored `<!-- gitnexus:start -->` marker, or EOF."* The ADR explains in one sentence why
this matters — every terminator must carry the anchor's alternation, or a `/^## /`-only terminator
runs past the marker and consumes the entire region on an ordinary idempotent re-run.

## D-45 Honesty — the SETUP-01 Limitation, Quoted

The Setup parity section states the limitation rather than eliding it:

> **The limitation that bounds this claim (D-45), stated without hedging.** The update skill has a
> **multi-hop chain-selection defect**: it selects pending migrations *once* from the project's
> initial version and never recomputes the version after each hop. A freshly scaffolded project
> sits at `0.1.0`, so it selects only `0001`, applies it, lands at `0.2.0`, and then fails the
> final target-version check. **"Setup end-state ≡ full replay" therefore does NOT complete in one
> invocation today.** This ADR does not assert an end-state conformance this host cannot currently
> demonstrate — what is demonstrated is the single-source property above, not that a single
> `/update-codex-agenticapps-workflow` invocation walks a fresh project to `0.7.0`.

**D-43's claims were re-verified rather than inherited**, as the plan required: `0000-baseline.md:102`
is a plain `cat … >> AGENTS.md` append (read directly), and `agents-md-additions.md` returns **0**
occurrences of `Coding Discipline`/`spec-source` (its headings run `## Development Workflow` →
`## Pre-execution Gate — Plan Review (spec §02)`).

**D-44 verified at source too:** `spec/08-migration-format.md:27-33` names replay and snapshot as
the two conformant strategies, and `claude-workflow` really does ship
`migrations/check-snapshot-parity.sh` (confirmed present on disk) — so the replay-vs-snapshot
asymmetry the ADR records is a fact, not a rhetorical convenience.

## Honest Coverage Gaps — Recorded in the ADR, Not Just Here

Per the prompt's known-gaps brief, these are stated in the ADR's own Verification section, because
the ADR is what a future author reads:

- **No idempotent-re-run fixture** — `run-tests.sh` never re-applies Step 1 to an already-healed
  file, so **narrowing the strip terminator does NOT fail the suite**. Decision 2's hazard is
  demonstrated live only by `validate-0009-anchor.sh`'s counter-case B. Follow-up fixture
  `11-idempotent-rerun` is recorded in Open follow-ups. This is a deliberately uncomfortable thing
  to write in the same document that argues the terminator is the highest-severity mechanic — which
  is exactly why it is written there.
- **Step 3's version is untested** (MIGR-08) — mutating it fails nothing.
- **A latent `want`-flag leak** in the fence-scoped extractor for fenceless labels; unfixed.

## Suite Counts (final, this phase)

| | Worktree (observed here) | Main checkout (expected) |
|---|---|---|
| PASS | **313** | 314 |
| FAIL | **0** | 0 |
| SKIP | **2** | 1 |

`FAIL: 0` holds, and `PASS: 313 ≥ 278`. Run before any edit and after every task — **the counts
never moved**, which is the correct outcome for a documentation-only plan.

The 2nd SKIP is environmental and pre-explained by 09-01: `run-tests.sh:140` resolves the sibling
core spec at `$REPO_ROOT/../agenticapps-workflow-core/…`, which does not exist from a worktree
nested three levels deeper (`SKIP core spec repo not adjacent — mirror/core diff not checked`).
313 + that 1 = the 314 baseline. Not caused by this plan; expect 314/1/0 on merge.

## Verification Results

| Check | Result |
|---|---|
| `ADR-OK` (non-empty + `8520f90` + indexed) | PASS |
| ADR ≥ 80 lines | PASS (344) |
| Full pin SHA `8520f90d235e0c50b0484b170d595ab6f2cd1173` present (not short form) | PASS (2) |
| `immediately after the H1` (D-22.2) | PASS (2) |
| Corrected invariant `marker, or EOF` | PASS (1) |
| ≥ 3 `### ` options | PASS (3) |
| Every `invariant survives` inside the false-recording passage | PASS (1/1 — quoted above) |
| ADR → migration key_link `0009-spec-11-region-aware-placement` | PASS (added; initially 0) |
| Exactly one `0010` row in the Index | PASS (1) |
| `SETUP-OK` + `migrations/run-tests.sh layout` exit 0 | PASS (exit 0) |
| SETUP-01 evidence `0000-baseline` carried | PASS (3) |
| Limitation present (`multi-hop`, `0.1.0`) | PASS (2 / 3) |
| **No guard built** — SKILL.md diff prose-only, no shell, no post-check | PASS (markdown blockquote only) |
| `CHANGELOG-OK` incl. ordering assertion (0.7.0 above 0.6.0) | PASS (L25 vs L49) |
| `grep -ic 'known issue' CHANGELOG.md` | PASS (0 — none invented) |
| `grep -c 'swallowed_own_h2\|awk' CHANGELOG.md` | PASS (0 — mechanics stay out) |
| `git status --porcelain` on 0001 / 0004 / AGENTS.md | PASS (empty) |
| Full suite `FAIL: 0` after every task | PASS |

## Success Criteria

- [x] ADR-0010 records the decision, BOTH rejected alternatives, and the widened-invariant correction
- [x] ADR indexed in `docs/decisions/README.md` matching existing format
- [x] SETUP-01 pointer and DOC-02 CHANGELOG entry written at release altitude
- [x] Claims match the committed evidence; known coverage gaps stated honestly
- [x] Full suite still 0 FAIL — docs-only, nothing regressed
- [x] Each task committed individually; SUMMARY created
- [x] No modifications to shared orchestrator artifacts (STATE.md / ROADMAP.md / REQUIREMENTS.md untouched)

## Deviations from Plan

**None.** The plan executed as written. Three notes, none a deviation:

1. **The migration key_link initially failed and was fixed before commit.** The ADR referenced the
   migration as "migration 0009" but not by the path pattern `0009-spec-11-region-aware-placement`
   that `key_links` requires, so the grep returned 0. Added an explicit linked reference in Context.
   Caught by running the plan's own acceptance criteria rather than by assuming.
2. **Suite reads 313/0/2, not the plan's stated `SKIP: 1` / `PASS ≥ 278`.** Environmental worktree
   artifact, pre-diagnosed by 09-01 and by this plan's prompt. `FAIL: 0` and `PASS ≥ 278` both hold.
3. **Submodule init required** (`vendor/agenticapps-shared` unpopulated in a fresh worktree) — a
   checkout of an already-pinned submodule at `1f5d543`; no tracked-file change.

## Notes for the Orchestrator

- **STATE.md, ROADMAP.md, and REQUIREMENTS.md were deliberately NOT modified**, per the objective.
  Recommended marking after merge: **SETUP-01, DOC-01, DOC-02** → complete (this plan's artifacts are
  exactly what they specify). **ROADMAP Success Criterion 6** → closed.
- **`PROMPT-0009-spec-11-region-aware-placement.md` remains untracked** at the repo root; untouched.
- **Carry to the phase verifier:** the three `<human-check>` items are prose-quality judgments
  (ADR reads correctly; setup section is honest; CHANGELOG reads at release altitude). The automated
  greps bound only the mechanical half — the qualitative half is `/gsd:verify-work`'s.
- **The `11-idempotent-rerun` fixture is the highest-value follow-up this phase produced.** It is the
  one thing that would make decision 2's hazard fail the suite rather than only the standalone
  validation script.

## Threat Flags

None. No new network, auth, file-access, or schema surface — four markdown files. T-09-SC's
package-install condition is not met (no installs of any kind).

Threat register dispositions discharged: **T-09-17** (false invariant re-armed) — mandated wording
present, false claim recorded as false, occurrence read in context and quoted above. **T-09-18**
(unrecorded pin) — full 40-char SHA present. **T-09-19** (unbounded SETUP-01 claim) — limitation
present and quoted. **T-09-20** (scope creep into a parity guard) — SKILL.md diff is prose-only.
**T-09-21** (unindexed ADR) — exactly one Index row.

## Self-Check: PASSED

| Claim | Verified |
|---|---|
| `docs/decisions/0010-region-aware-spec-11-placement.md` exists | FOUND |
| `docs/decisions/README.md` exists | FOUND |
| `CHANGELOG.md` exists | FOUND |
| `skills/setup-codex-agenticapps-workflow/SKILL.md` exists | FOUND |
| Commit `6def8df` (Task 1 — ADR + index) | FOUND |
| Commit `fafb822` (Task 2 — setup parity) | FOUND |
| Commit `c11fe3c` (Task 3 — CHANGELOG) | FOUND |
| Working tree clean before SUMMARY | PASS |
