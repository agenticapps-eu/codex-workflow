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

## Milestone: v0.7.0 — Region-Aware §11 Placement

**Shipped:** 2026-07-16
**Phases:** 2 (Phase 9 + inserted Phase 9.1) | **Plans:** 12 (5 build + 7 gap-closure)
**Timeline:** 2026-07-15 → 2026-07-16 (~1 day, 111 commits, +16,799 / −137 across 61 files)

### What Was Built

- Migration `0009-spec-11-region-aware-placement.md` (`0.6.0` → `0.7.0`) — heals
  the §11 anchor across four states: no-op when correctly anchored, move when
  inside a GitNexus region, inject when absent, refuse (`exit 3`) on a hand-pasted
  block with no provenance.
- The region-aware anchor rule — insert before the first `## ` heading *or*
  `<!-- gitnexus:start -->` marker, whichever comes first; EOF fallback — plus
  `validate-0009-anchor.sh`, which proved it against real AGENTS.md files *before*
  the migration existed.
- A ten-case fixture suite that extracts each migration's shell from the document
  itself, retiring the inlined anchor copy at `run-tests.sh:119`.
- Phase 9.1's data-loss closures: anchored `PROV_RE` at all four sites (CR-02), a
  pre-surgery refuse gate plus a fail-closed `END{exit 4}` strip guard (CR-01), a
  live `test -s` contract check (CR-03), and `12-idempotent-rerun` — ANCHOR-05's
  only live coverage of the strip terminator's alternation.
- ADR-0010, with a dated in-place Correction of the two load-bearing errors review
  found in it.

### What Worked

- **Ordering constraints encoded as wave topology, not intention.** "Validate the
  anchor empirically before writing the migration" and "the suite must be RED
  before 0009 exists" were both enforced by `depends_on` — 09-01 and 09-03 gate
  09-04. The constraints held because the graph made violating them impossible,
  not because anyone remembered.
- **RED is auditable in commit order.** `a4b137f`/`2315393`/`185abfd`
  (`test(09-03): … (RED)`) precede `49b2fab` (`feat(09-04): … turns the suite
  GREEN`). The claim "we did TDD" is checkable from `git log` a year later, not a
  matter of trust.
- **The mutation gate found dead assertions that green suites hid.** Every
  load-bearing guard in 9.1 was proven by delete-observe-restore: narrowing the
  terminator alternation produced 2 FAIL; flipping `state-a`'s expected arg
  produced FAIL. Three assertions that read as coverage but could not fail were
  caught this way.
- **Verification re-derived rather than read, and did it with a scratch clone.**
  Because the phase's own subject was "assertions that cannot fail," the verifier
  mutated a scratch clone and re-ran the suite against the mutation instead of
  trusting the ADR's or SUMMARY's account of what a mutation showed. Self-applying
  the milestone's lesson to its own verification.
- **Inserting Phase 9.1 rather than shipping Phase 9.** Code review reproduced a
  data-loss defect in already-shipped code; the response was a phase, not a patch
  and a shrug. Every gap Phase 9's verification recorded was closed and dispositioned.
- **Five locked decisions were corrected mid-planning when research falsified
  them** — including D-21, whose *rationale* ("the invariant survives") was simply
  false: the invariant is widened, not preserved. Locked did not mean unfalsifiable.

### What Was Inefficient

- **Phase 9 shipped 314 PASS / 0 FAIL on a migration that never ran.** The
  pre-flight grepped a project-relative `skills/` path no real install has, so
  0009 aborted `exit 3` on every scaffolded project — the exact defect migration
  0008 had *named, documented, and refused to replicate* (T-08-38). The suite
  could not see it because the sandbox **manufactured the synthetic SKILL.md that
  made the broken path exist** — the precise practice 0008's harness had refused
  (`run-tests.sh:918-919`). A green suite was fully consistent with a migration
  that never executed.
- **58% of the milestone (7 of 12 plans) was gap closure** — up from 33% in
  v0.6.0. The five build plans shipped three reproducible data-loss paths in a
  migration whose entire purpose was preventing data loss.
- **The v0.6.0 lesson repeated in a new costume.** v0.6.0: "fixtures written only
  from the happy path test the author's assumptions, not the contract." v0.7.0:
  the fixtures tested a project shape that does not exist. Same failure, one level
  up — from *hostile input* to *hostile environment*.
- **A dead pin was cited four times before review caught it.** D-48 pinned
  upstream at `8520f90`, a PR-branch commit that never merged; PR #89 squashed as
  `f9354cc`. Everything downstream of the pin inherited the error.
- **CR-02 was re-invented, not ported.** It was already fixed upstream at
  `f9354cc` with its own fixture. Research caught this — but only after the phase
  had planned to solve it from scratch.

### Patterns Established

- **A guard is not shipped until it has been observed failing.** Presence of an
  assertion is not evidence of coverage; the only proof is watching it go red.
- **A sandbox must never manufacture the precondition under test.** If the harness
  creates the thing whose existence is the question, the suite measures the
  harness. This is the environmental twin of the happy-path fixture problem.
- **A migration records its version in the TARGET project; it never bumps this
  repo's own scaffolder.** MIGR-08 and MIGR-09 are separate concerns — conflating
  them shipped a Step that wrote scaffolder files into consumers' repos.
- **Porting errors masquerade as upstream defects.** V-01 looked like upstream's
  bug; it was our port dropping the `.claude/` prefix. Diff the path before filing.
- **Close a phase with a dated disposition record, not by re-scoring it in place.**
  `09-VERIFICATION.md`'s body is preserved as what was true on 2026-07-15; a Gap
  Closure Record appended 2026-07-16 dispositions each gap against a named 9.1
  plan. The history stays legible.
- **An outbound claim's acceptance criterion is the claim landing, not the draft
  existing.** Criterion 10 was left explicitly open rather than marked green on a
  drafted-but-unfiled report, and no URL was fabricated.

### Key Lessons

1. **Green means the assertions ran, not that the code did.** A suite can be
   fully green against software that never executes. Ask what would have to be
   true for this suite to pass while the feature is dead — then test *that*.
2. **When a past migration documents a defect and refuses to replicate it, read
   the refusal before writing the next one.** 0008 left a written warning naming
   this exact bug, with a regression fixture attached. 0009 reintroduced it in all
   three locations anyway. Institutional memory that nobody reads is decoration.
3. **The dangerous defect is next to the one you're fixing.** Phase 9 hardened the
   §11 anchor and shipped a block-destruction bug in the strip mechanic immediately
   adjacent. The mental model was "this area is now safe" — it covered one path.
4. **A locked decision's rationale is falsifiable even when its conclusion holds.**
   D-21's conclusion survived; its stated reason was false. Ship the correction, or
   the next person inherits the false reason and reasons from it.
5. **CI is still a placeholder, and it cost real money this time.** v0.6.0's lesson
   4 said "green does not mean verified" because CI echoes and exits 0. Two
   milestones have now merged on a local green. `CI-01` is no longer a nice-to-have;
   it is the standing debt most implicated in this milestone's dominant failure mode.

### Cost Observations

- Not instrumented — no model-mix or session-count data captured; none invented here.
- Observable proxy: 12 plans over ~1 day, of which 7 (58%) were unplanned gap
  closure driven by code-review and verification findings. Gap-closure share is
  rising milestone over milestone (33% → 58%), while the *cause* moved earlier:
  v0.6.0's gaps were found by verification, v0.7.0's by code review of shipped code.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v0.6.0 Plan-Review Gate | 1 | 9 | First GSD-native phase in this repo; first milestone closed through the GSD workflow. Cross-AI plan review became a pre-execution gate rather than an informal step. |
| v0.7.0 Region-Aware §11 Placement | 2 (1 inserted) | 12 | First use of an inserted decimal phase to close reproduced data-loss defects rather than shipping them. Ordering constraints became wave topology (`depends_on`), not prose. The mutation gate — delete, observe RED, restore — became the standard of proof for any load-bearing guard. |

### Cumulative Quality

| Milestone | Verification | Gap-closure plans | Notes |
|-----------|--------------|-------------------|-------|
| v0.6.0 | `passed` 7/7 (after re-verification; initial pass was `gaps_found` 6/7 + 1 failed derived truth) | 3 of 9 (33%) | Two live fail-opens found by verification, not by the 104-assertion TDD suites. |
| v0.7.0 | Phase 9 `gaps_found` → `gaps_closed_via_09.1` (21/21, 0 NOT-DELIVERED); Phase 9.1 `passed` 11/11, UAT 10/1, security 37/37 `threats_open: 0` | 7 of 12 (58%) | 314 PASS / 0 FAIL on a migration that never ran. Three data-loss paths found by code review *after* the code shipped. Suite closed at 369 PASS / 0 FAIL / 1 SKIP. |

### Recurring Failure Mode

The same defect class has now driven gap closure in both milestones: **tests that
pass without exercising the thing they name.**

| Milestone | Shape | Found by |
|-----------|-------|----------|
| v0.6.0 | Fixtures used byte-perfect canonical input; hostile input (CRLF, trailing spaces, same-vendor reviewers) walked through two fail-opens | Verification |
| v0.7.0 | Sandbox manufactured the precondition under test; assertions labelled for a requirement they could not discriminate (`state-a` on-anchor, `test -s`, mirror single-`##`) | Code review + mutation |

The countermeasure that worked — **the mutation gate** — is now standard. The
enabling condition that persists is `CI-01`: both milestones merged on a local
green, so nothing independent has ever checked either suite.

### Carried Debt

| Item | Origin | Status |
|------|--------|--------|
| Gate is agent-mediated, not enforced (`PreToolUse` hook deferred) | D-02 / ADR-0009 decision 9 | Open — deferred to its own phase (`HOOK-01`) |
| CI verifies nothing (Phase 0 placeholder; "real checks in Phase 7" never happened) | pre-GSD legacy | Open — unscheduled (`CI-01`). **Now implicated in v0.7.0's dominant failure mode; two milestones merged on local greens.** |
| WR-03: `--file` symlink-traversal guard is lexical-`..`-only | 08-REVIEW.md | Accepted (ADR-0009 decision 12) with a concrete future fix |
| Upstream grandfather-conflation defect | 08-02 | Open question for a claude-workflow bug report |
| Phases 00–07 not in GSD roadmap | scaffold adopted at Phase 8 | Accepted by design — not to be back-filled |
| MIGR-08 execution coverage — no fixture asserts the written `.codex/workflow-version.txt` | 09.1-VERIFICATION.md | Open — the one residual of the class Phase 9.1 existed to close |
| AG-01: strip eats `gitnexus:end` when §11 sits at a region's *tail* | 09.1-UAT.md | Accepted and disclosed (user ruling 2026-07-16). Unreachable via 0001/0004. Durable fix = paired §11 markers, ADR-0010's lead follow-up |
| Migration 0007's pre-flight defect (V-01's twin) | 09-VERIFICATION.md | Open — unscheduled; 0008 deferred it as "different migration, own scope" |
| 09-REVIEW.md WR-05 + IN-01..IN-04 | 09-REVIEW.md | Open — consciously scoped out of 9.1 |
| Upstream CR-01 (strip runaway in claude-workflow's 0029) | 09.1-07 | Filed — [claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90), OPEN, awaiting upstream |
