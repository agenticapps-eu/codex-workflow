---
phase: 09-region-aware-11-placement
plan: 01
subsystem: migrations/validation
tags: [anchor-rule, empirical-validation, counter-assertions, gitnexus-region, awk]
requires: []
provides:
  - "migrations/validate-0009-anchor.sh — committed, re-runnable replay of D-21's anchor + D-24's terminator"
  - "09-VALIDATION-EVIDENCE.md — the recorded evidence Success Criterion 1 demands"
  - "ROADMAP hard ordering 1 discharged: 09-04 unblocked to author 0009's Step 1 Apply"
affects:
  - "09-04 (authors migration 0009's apply-block — was gated on this evidence)"
  - "09-02/09-03 (the validated rule is the one their fixtures must exercise)"
tech-stack:
  added: []
  patterns:
    - "Counter-replay: assert the WRONG rule FAILS; exit non-zero if it passes (D-36)"
    - "Deterministic stdout so a recorded evidence block stays re-run-diffable (T-09-04)"
    - "Scratch-dir-only writes; the real AGENTS.md is read-only (T-09-02)"
    - "§11 prose streamed from the mirror via getline, never transcribed"
key-files:
  created:
    - migrations/validate-0009-anchor.sh
    - .planning/phases/09-region-aware-11-placement/09-VALIDATION-EVIDENCE.md
  modified: []
decisions:
  - "Script stdout is deterministic (no SHA, no absolute path) — the SHA belongs in the evidence file header, or the record self-invalidates"
  - "REQUIREMENTS.md left to the orchestrator: a parallel wave-1 agent (09-02) shares that file, and ANCHOR-01/02 are not fully discharged until 0009 ships"
metrics:
  duration: ~10 min
  completed: 2026-07-15
  tasks: 3
  commits: 3
---

# Phase 9 Plan 01: Validate the Region-Aware Anchor Rule Empirically — Summary

Replayed D-21's anchor rule and D-24's widened strip terminator against this host's real
`AGENTS.md` and a synthesized gitnexus-led file, proved both wrong rules misbehave, and
recorded the verbatim output as committed evidence — discharging ROADMAP hard ordering 1
("validate before you write") before any line of migration 0009 exists.

## What Was Built

| Artifact | Purpose |
|---|---|
| `migrations/validate-0009-anchor.sh` | Committed replay harness (372 lines). Two positive cases, two counter-cases, five stable labels, non-zero exit on any failure. |
| `09-VALIDATION-EVIDENCE.md` | The recorded evidence: command, date, repo SHA, D-48 pin vs observed upstream HEAD, verbatim stdout, mutation demo, four claim/evidence pairs, gate statement. |

## The Five Replay Labels Observed

All five present, exit 0:

```
  PASS CASE 1 ZERO CHURN — candidate rule re-derives §11's current position byte-identically
  PASS CASE 2 ABOVE REGION — provenance at line 5 is above gitnexus:start at line 86; region intact and paired (start=1 end=1), body at line 93
  PASS COUNTER-CASE A (counter) NAIVE ANCHOR INSERTS INSIDE REGION — naive rule put provenance at line 10, INSIDE the region that opens at line 5 (the latent defect, observed live)
  PASS COUNTER-CASE B (counter) NARROW TERMINATOR EATS REGION — start marker DESTROYED (start=0) while gitnexus:end survives (end=1): an orphaned, unpaired region; region body content gone
  PASS WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=1 end=1), body at line 8, and the §11 block was still cleanly stripped (no provenance left)
```

**The two rules demonstrably disagree on identical input** — candidate anchors at line 5,
naive at line 10. That disagreement is what makes CASE 2's PASS mean something rather than
being a property any rule would satisfy.

**Zero churn is not vacuous:** the strip genuinely removes 81 lines (provenance + 79 mirror
lines + the single trailing blank 0001 injects — 313 → 232 lines), and the insert genuinely
re-adds them. A no-op strip would make the insert add a *second* block and fail the diff.

## Mutation Demonstration (Task 2 acceptance — counter-case B is live)

`narrow_strip`'s terminator (line 176) was temporarily widened with
`|| /^<!-- gitnexus:start -->$/`, making the "narrow" rule no longer narrow:

**Mutated run:**
```
  FAIL COUNTER-CASE B NARROW TERMINATOR EATS REGION — narrow terminator did NOT destroy the region (start=1 end=1, body line 8). The narrow rule behaved correctly, so D-24's alternation is not shown to be load-bearing and the WIDENED assertion below is dead-by-construction.
  PASS WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=1 end=1), body at line 8, and the §11 block was still cleanly stripped (no provenance left)

=== RESULT: 1 case(s) FAILED ===
MUTATED_EXIT=1
```

**Reverted run (script byte-identical to committed version):**
```
  PASS COUNTER-CASE B (counter) NARROW TERMINATOR EATS REGION — start marker DESTROYED (start=0) while gitnexus:end survives (end=1): an orphaned, unpaired region; region body content gone
  PASS WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=1 end=1), body at line 8, and the §11 block was still cleanly stripped (no provenance left)

=== RESULT: all cases PASSED ===
REVERTED_EXIT=0
```

The assertion tracks the rule, not the weather. No assertion in this plan is dead.

## SHA and Upstream Pin (D-48)

| | |
|---|---|
| **This repo's SHA at the recorded run** | `47c67fdef82794662590397b8c329b219df80e0f` |
| **D-48 pin (the reference actually used)** | `8520f90d235e0c50b0484b170d595ab6f2cd1173` |
| **Observed upstream HEAD** | `28b393b87885f3cfe3671c90fb112490c8c7e7e0` (branch `fix/0029-spec-11-region-aware-placement`) |
| **Pin is an ancestor of upstream HEAD** | yes |

**Upstream HEAD differs from the pin; the pinned content was used regardless.** All awk was
read via `git -C ../claude-workflow show 8520f90:...` — nothing at upstream HEAD was read in.

**D-48 was confirmed live during this plan's own execution.** Upstream HEAD was observed at
`496acfc9` when the plan started and `28b393b8` ~7 minutes later when evidence was recorded.
0029 moved *again, mid-execution*. D-48 anticipated four changes during the planning session;
this is a fifth. Pinning cost nothing; chasing would have been unbounded.

**Port fidelity verified against the pin** — the alternation appears at exactly three sites
upstream (`:202` strip, `:228` insert, `:302` rollback). The two load-bearing sites are both
ported; `:302` is correctly *not* ported (0009's Rollback is `git checkout AGENTS.md`, D-47).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Script banner emitted volatile output, making the evidence record self-invalidating**

- **Found during:** Task 2 (surfaced by the mutation demo, whose output carried a SHA that
  had already changed).
- **Issue:** My Task 1 script echoed `Repo: $REPO_ROOT` and `Repo SHA: $(git rev-parse HEAD)`
  into stdout. Task 3's acceptance requires the recorded fenced block to be byte-consistent
  with a fresh run. With a SHA in stdout, the record would be invalidated by *the very commit
  that records it*, and `$REPO_ROOT` diverges between a worktree and the main checkout — so
  T-09-04's "re-run and diff stdout" mitigation could never pass. The threat register calls
  truncated/stale records read-as-PASS a mitigated threat; my own design defeated that
  mitigation.
- **Fix:** Removed both volatile lines; banner is now deterministic. The SHA and repo path
  live in the evidence file's header, which is exactly where the plan's Task 3 ordering
  asks for them ("(2) this repo's SHA from `git rev-parse HEAD`").
- **Verified:** two consecutive runs diff clean; recorded block diffs clean against a fresh
  run.
- **Files modified:** `migrations/validate-0009-anchor.sh`
- **Commit:** `47c67fd`

### Environment Notes (not deviations)

- **Submodule init required in the worktree.** `vendor/agenticapps-shared` is not populated
  in a fresh worktree, so `migrations/run-tests.sh` hard-failed. Ran
  `git submodule update --init --recursive` (checked out `1f5d543`) — a checkout of an
  already-pinned submodule, no tracked-file change, no new dependency.
- **Harness baseline reads 277 PASS / 2 SKIP / 0 FAIL from the worktree, not 278 / 1 / 0.**
  Fully explained and *not* caused by this plan: the extra SKIP is
  `SKIP core spec repo not adjacent — mirror/core diff not checked`. `run-tests.sh:140`
  resolves the sibling core spec at `$REPO_ROOT/../agenticapps-workflow-core/...`; from a
  worktree nested three levels deeper that path does not exist, while it resolves fine from
  the main checkout (verified both). 277 + that 1 = the 278 baseline. **FAIL: 0 holds**, and
  this plan adds no assertions to the harness, as the plan's verification requires. Expect
  278 / 1 / 0 to return once merged to the main checkout.

## Verification Results

| Check | Result |
|---|---|
| `bash migrations/validate-0009-anchor.sh` exits 0, five labels | PASS (5/5) |
| `test -x migrations/validate-0009-anchor.sh` | PASS |
| D-24 two-site rule: non-comment `gitnexus:start -->$/` count ≥ 2 | PASS (2) |
| Script contains `getline line <`, not `Think Before Coding` | PASS (3 / 0) |
| `git status --porcelain AGENTS.md` empty after every task (T-09-02) | PASS |
| AGENTS.md untouched across all 3 commits (`git diff base..HEAD -- AGENTS.md`) | PASS (empty) |
| Evidence: `EVIDENCE-OK` (non-empty + all labels + `8520f90`) | PASS |
| Evidence block byte-consistent with fresh run stdout | PASS (diff clean) |
| Script output deterministic across consecutive runs | PASS (diff clean) |
| `migrations/run-tests.sh` FAIL count | PASS (FAIL: 0; see Environment Notes on 277/2) |
| `git status --porcelain` shows only `files_modified` | PASS (exactly 2 files) |

## Success Criteria

- [x] ANCHOR-03 satisfied with recorded evidence — zero churn on the real AGENTS.md
- [x] ANCHOR-04 satisfied with recorded evidence — above-region on a gitnexus-led file
- [x] ANCHOR-01/02's rule expressed executably and observed behaving on real + synthesized input
- [x] Both counter-cases observed failing the wrong rules — no assertion is dead
- [x] ROADMAP hard ordering 1 discharged — **09-04 may now author 0009's apply-block**

## Notes for the Orchestrator

- **REQUIREMENTS.md was deliberately NOT modified.** Plan 09-02 runs concurrently in wave 1
  and shares that file; a worktree-local edit would risk a merge conflict on a shared
  artifact. Recommended marking after the wave merges:
  - **ANCHOR-03, ANCHOR-04** → complete (this plan's evidence is exactly what they specify:
    "verified empirically *before* the migration is written").
  - **ANCHOR-01, ANCHOR-02** → keep Pending. This plan proves the rule executably; the
    requirements describe 0009's shipped behavior, which 09-04 authors.
- STATE.md and ROADMAP.md untouched, per the objective.

## Threat Flags

None. No new network, auth, file-access, or schema surface. The script is read-only against
the working tree (writes confined to `mktemp -d`), adds no dependency (`awk`/`git`/`bash`
were already required by the existing harness), and T-09-SC's package-install scope
condition is not met.
