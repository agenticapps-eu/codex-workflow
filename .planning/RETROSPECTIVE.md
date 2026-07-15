# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.6.0 — Plan-Review Gate

**Shipped:** 2026-07-15
**Phases:** 1 (Phase 8) | **Plans:** 9 (6 build + 3 gap-closure)
**Timeline:** 2026-07-14 → 2026-07-15 (~2 days, first commit `5c694e8` → merge `cf51c73`)

### What Was Built

- `check-plan-review.sh` — the spec §02 gate verifier: D-05 four-step phase
  resolver (pointer → STATE.md → newest-plan-by-mtime → fail-open), D-08/D-09
  grandfather guards, both escape hatches, traversal-safe `--file` bypass, and
  strict `<NN>-REVIEWS.md` evidence collection that blocks with exit 2.
- `codex-plan-review` — the producer skill that emits `<NN>-REVIEWS.md` with
  ≥2 vendor-diverse external reviewers, and refuses rather than emitting a
  one-reviewer file.
- Declarative `pre_execution.plan_review` binding in both config files, ritual
  text mirrored byte-identically into `AGENTS.md` and the trigger SKILL.md, and
  both bindings tables corrected to 16 distinct gates.
- Migration 0008 — the idempotent existing-install upgrade path (leaf-level
  config merge, template-extracted ritual insert, version bump to 0.6.0 in
  lockstep with the drift test).
- ADR-0009 recording the hybrid declarative+verifier decision, both rejected
  alternatives, and four accepted limitations.

### What Worked

- **Cross-AI plan review caught an over-claim before a line was written.**
  Round 2 of `08-REVIEWS.md` (Codex + OpenCode agreeing) drove the criterion-1
  rewording from "unconditional block" to "agent-mediated" *during replanning*,
  so the reviewed contract was the contract used at closure. The milestone's own
  subject matter proved its value on itself.
- **Verification that refuses to trust SUMMARY.md.** The verifier re-executed
  every claim from scratch against HEAD rather than reading the summaries. That
  is what surfaced two live fail-opens the build plans had reported as done.
- **Naming the bootstrap paradox up front** (ADR-0009 decision 8) instead of
  fudging a dogfood run. Phase 8's own grandfathered pass was explicitly not
  treated as evidence the gate works.
- **Splitting 08-05/08-06 for context budget** while keeping the version bump
  with 08-05, because `run_drift_test` hard-fails a SKILL.md/migration version
  mismatch — splitting them would have left the harness red across the wave
  boundary.

### What Was Inefficient

- **A third of the milestone (3 of 9 plans) was gap closure.** The six build
  plans shipped with two verified fail-opens in the REVIEWS.md strictness check
  — the exact check the gate's integrity depends on.
- **TDD suites passed while the code failed.** ~104 assertions across the
  resolver and enforcement suites did not catch CR-01 (CRLF/trailing-space
  frontmatter silently downgrading to the reviewer-check-free fallback) or
  WR-01 (`reviewers: [codex, codex-self]` counting as "2 distinct reviewers"),
  because every fixture used byte-perfect canonical input and a plausible
  vendor list. Both reproduced in minutes once someone tried hostile input.
  **Fixtures written only from the happy path test the author's assumptions,
  not the contract.**
- **Findings went silent between stages.** CR-01/WR-01/WR-02/WR-03/IN-01 were
  found by code review, then sat undocumented — neither fixed nor formally
  accepted — until verification failed a derived truth on them. Closing that
  cost a dedicated plan (08-09) whose entire job was recording dispositions.
- **Milestone bookkeeping drifted from reality.** STATE.md carried the unedited
  scaffold default (`milestone: v1.0`, `milestone_name: milestone`) plus
  self-contradictory progress (`6 plans / 9 completed / 0%`) while the repo was
  actually on the 0.6.0 line. Caught only at close, by inspection.

### Patterns Established

- **Tri-state status contracts signaled via `$?`, never stdout emptiness** —
  ambiguity (2) must never collapse into absent (1), or resolution silently
  falls through and picks one of the ambiguous candidates anyway.
- **Guard *ordering* is the fix, not guard presence** — `[ -L ]` must run
  strictly before `[ -f ]`, because `[ -f ]` dereferences and returns true for
  a live symlink.
- **Reject on shape, never normalize-then-test** — `..`-component rejection runs
  before the prefix+basename test, so a traversal resolving back onto a real
  canonical artifact is still rejected.
- **Producer/verifier contract anchors** — the reviews-skeleton marker pair in
  SKILL.md is extracted verbatim by a round-trip test, so the producer and
  verifier cannot drift apart silently.
- **Re-verification re-executes; it does not read summaries.**

### Key Lessons

1. **Write fixtures from the attacker's input, not the author's.** Both
   fail-opens lived in the space between "canonical input" and "input a real
   file might contain" (CRLF, trailing spaces, a same-vendor reviewer list).
2. **A finding that is neither fixed nor formally accepted is a silent
   regression waiting to happen.** Give every review finding an explicit
   disposition at the time it is found, not a plan later.
3. **An agent-mediated gate is a convention, not an enforcement boundary.**
   Until the `PreToolUse` hook lands, `check-plan-review.sh` stops only agents
   that choose to run it. ADR-0009 says so; the roadmap should keep saying so.
4. **Green does not mean verified.** This milestone merged on a *local* test run
   because CI is a placeholder that echoes and exits 0. The checkmark on PR #15
   certified nothing.
5. **Scaffold defaults become facts if nobody reads them.** `v1.0` was never a
   decision — it was a template value that would have been tagged into the
   product's version namespace had it not been checked at close.

### Cost Observations

- Not instrumented for this milestone — no model-mix or session-count data was
  captured, and none is invented here. Future milestones should record this at
  phase close if the metric is wanted.
- Observable proxy: 9 plans over ~2 days, of which 3 (33%) were unplanned gap
  closure driven by verification findings.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v0.6.0 Plan-Review Gate | 1 | 9 | First GSD-native phase in this repo; first milestone closed through the GSD workflow. Cross-AI plan review became a pre-execution gate rather than an informal step. |

### Cumulative Quality

| Milestone | Verification | Gap-closure plans | Notes |
|-----------|--------------|-------------------|-------|
| v0.6.0 | `passed` 7/7 (after re-verification; initial pass was `gaps_found` 6/7 + 1 failed derived truth) | 3 of 9 (33%) | Two live fail-opens found by verification, not by the 104-assertion TDD suites. |

### Carried Debt

| Item | Origin | Status |
|------|--------|--------|
| Gate is agent-mediated, not enforced (`PreToolUse` hook deferred) | D-02 / ADR-0009 decision 9 | Open — deferred to its own phase |
| CI verifies nothing (Phase 0 placeholder; "real checks in Phase 7" never happened) | pre-GSD legacy | Open — unscheduled |
| WR-03: `--file` symlink-traversal guard is lexical-`..`-only | 08-REVIEW.md | Accepted (ADR-0009 decision 12) with a concrete future fix |
| Upstream grandfather-conflation defect | 08-02 | Open question for a claude-workflow bug report |
| Phases 00–07 not in GSD roadmap | scaffold adopted at Phase 8 | Accepted by design — not to be back-filled |
