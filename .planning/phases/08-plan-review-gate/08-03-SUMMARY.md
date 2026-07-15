---
phase: 08-plan-review-gate
plan: 03
subsystem: infra
tags: [gsd, plan-review-gate, adr, skill-authoring, codex-workflow]

# Dependency graph
requires: []
provides:
  - "skills/codex-plan-review/SKILL.md — the plan-review gate's evidence-artifact
    producer skill (authored from scratch; upstream Codex GSD ships no
    gsd-review equivalent)"
  - "The reviews-skeleton marker pair inside SKILL.md — the load-bearing
    extraction anchor plan 08-02's test_check_plan_review_contract depends on"
  - "docs/decisions/0009-plan-review-gate.md — ADR recording the hybrid
    declarative+verifier binding decision, both rejected alternatives, and
    the phase's three accepted limitations"
affects: [08-02, 08-04, 08-05, 08-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "codex-* gate-producer skill shape mirrored from codex-spec-review
      (frontmatter, numbered procedure, Required evidence, Failure modes)"
    - "reviews-skeleton marker pair as a producer/verifier contract test anchor"
    - "ADR-0002 Options-considered (A/B/C) shape for decisions with rejected
      alternatives"

key-files:
  created:
    - skills/codex-plan-review/SKILL.md
    - docs/decisions/0009-plan-review-gate.md
  modified:
    - docs/decisions/README.md

key-decisions:
  - "Reviewer candidate list is claude, gemini, opencode (locked, D-15); codex
    is structurally excluded — never a candidate, so no self-skip env-var
    detection is needed or added"
  - "Reviewer timeout pinned at 300s default, overridable via
    CODEX_PLAN_REVIEW_TIMEOUT (single override mechanism, no second one
    invented)"
  - "Egress file boundary documented as advisory, not enforced — an
    affirmative operator confirmation gate is required before any
    transmission, but the manifest cannot constrain what an agentic
    reviewer CLI actually reads"
  - "ADR-0009 records exactly three reference-resolver defects, not seven —
    the four additional resolver requirements 08-01 adds are excluded from
    that count by design"
  - "ADR-0009 records the bootstrap paradox: no task in this phase fabricates
    a passing dogfood of the gate against phase 08 itself; phase 09 is the
    first genuinely enforced phase"
  - "The upstream grandfather-conflation defect is recorded as an open
    question for the claude-workflow bug report, not resolved unilaterally
    in this repo"

requirements-completed: ["core spec §02 (plan-review gate) — evidence artifact producer", "core spec §09 (conformance) — gate binding recorded by ADR"]

# Metrics
duration: 20min
completed: 2026-07-15
---

# Phase 08 Plan 03: Author the plan-review gate's producer skill and ADR Summary

**Authored `codex-plan-review` (the >=2-vendor-diverse-reviewer producer skill with a consent-gated, timeout-bounded, advisory-egress-documented procedure) and ADR-0009 (the hybrid declarative+verifier binding decision with all three accepted limitations recorded).**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-15T06:37:00Z
- **Completed:** 2026-07-15T06:50:50Z
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- `skills/codex-plan-review/SKILL.md` authored from scratch: a 10-step
  producer procedure (resolve inputs → enumerate egress → obtain affirmative
  consent → detect CLIs → refuse below minimum → build adversarial prompt →
  invoke independently → bound with timeout + provenance → write REVIEWS.md →
  record provenance honestly), a complete `reviews-skeleton` marker pair, a
  `## Required evidence` section, and a `## Failure modes` section.
- `docs/decisions/0009-plan-review-gate.md` authored: header + Context (spec
  obligation quote, 5 forces) + Options considered (A/B/C) + 11 numbered
  Decision sub-items + Consequences + Verification + Open follow-ups (with
  pasteable upstream defect reports).
- `docs/decisions/README.md` index gained the ADR-0009 row.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author skills/codex-plan-review/SKILL.md** - `04a10c0` (feat)
2. **Task 2: Author docs/decisions/0009-plan-review-gate.md** - `bae9bcc` (docs)

_Note: Task 2's commit also includes the docs/decisions/README.md index update, which the plan explicitly conditioned on the file carrying a per-ADR list (it does)._

## Files Created/Modified

- `skills/codex-plan-review/SKILL.md` - the plan-review gate's producer skill
- `docs/decisions/0009-plan-review-gate.md` - the ADR recording the gate's
  binding decision and accepted limitations
- `docs/decisions/README.md` - added the ADR-0009 index row

## Decisions Made

See `key-decisions` in frontmatter above. All decisions were either locked by
`08-CONTEXT.md` (D-01 through D-20) or explicitly delegated to this plan's
`<locked_discretion>` / `<review_findings_bound_here>` sections (reviewer
timeout value, codex self-skip mechanism) — no new architectural decisions
were made outside what the plan specified.

## Deviations from Plan

None - plan executed exactly as written. Every acceptance criterion in both
tasks was verified mechanically (grep/awk one-liners matching the plan's own
acceptance-criteria text) before committing; all passed on the first
iteration except one line-wrap issue in Task 1 (see below).

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a markdown line-wrap that broke a required literal-phrase match**
- **Found during:** Task 1 verification (acceptance criterion: `grep -ci 'before any transmission\|before transmitting\|before invoking' skills/codex-plan-review/SKILL.md` returns >= 1)
- **Issue:** The intended phrase "before any transmission" was split across a markdown line wrap ("...before any\n   transmission...."), so the single-line grep check returned 0.
- **Fix:** Reworded the sentence so "before any transmission" appears intact on one line.
- **Files modified:** skills/codex-plan-review/SKILL.md
- **Verification:** Re-ran `grep -ci 'before any transmission\|before transmitting\|before invoking' skills/codex-plan-review/SKILL.md` → returns 1.
- **Committed in:** `04a10c0` (part of Task 1 commit — the fix was made before the task was committed)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Purely a self-correction during verification before commit; no scope change.

## Issues Encountered

None.

## User Setup Required

**External services require manual configuration for the gate to function
(not for this plan's own commits, which required none).** Per the plan's
`user_setup` frontmatter: the operator must install at least two of
`claude`, `gemini`, `opencode` on PATH for `codex-plan-review` to be usable
(`codex` is excluded by design). Without two reviewers, the escape hatches
(`GSD_SKIP_REVIEWS=1` or a `multi-ai-review-skipped` marker) are the
documented remedy — never a one-reviewer `REVIEWS.md`. No `USER-SETUP.md`
was generated for this plan since it authors documents only and makes no
runtime calls itself.

## Load-Bearing Artifact Detail (for plan 08-02's contract test)

**Exact skill name:** `codex-plan-review`
**Reviewer candidate list as shipped:** `claude`, `gemini`, `opencode` (`codex` structurally excluded, never a candidate)
**Timeout value chosen:** 300 seconds (5 minutes) default, overridable via `CODEX_PLAN_REVIEW_TIMEOUT`

**The exact `reviews-skeleton` marker text** (verbatim, as it appears in `skills/codex-plan-review/SKILL.md`):

```
<!-- BEGIN: reviews-skeleton (extracted by test_check_plan_review_contract — keep verifier-parseable) -->
```
... (fenced ```` ```markdown ```` block containing the skeleton) ...
```
<!-- END: reviews-skeleton -->
```

**The skeleton it wraps** (frontmatter keys: `phase`, `reviewers` [flow style,
3 entries: `gemini`, `claude`, `opencode`], `reviewed_at`, `plans_reviewed`
[flow style, all six `08-0N-PLAN.md` files], `overall_verdict` [one entry
per reviewer], `recommendation`). Body: `# Cross-AI Plan Review — Phase 8:
Plan-Review Gate` heading, a provenance paragraph, a provenance table with a
Model column, an untrusted-content notice, one `## <Reviewer> Review`
section per reviewer (placeholder verbatim text), and a `## Consensus
Summary` section. Verified by extraction (`awk` between the markers, fence
lines stripped) to satisfy: first line is exactly `---`; frontmatter
contains no `...` placeholders; `reviewers:` is flow-style with >= 2
entries; `plans_reviewed:` is present.

## Next Phase Readiness

- Plan `08-04` can now write the config binding and ritual prose, naming
  `codex-plan-review` by exactly that name (verified in this plan's
  frontmatter: `name: codex-plan-review`).
- Plan `08-02`'s `test_check_plan_review_contract` can extract the
  `reviews-skeleton` marker block from `skills/codex-plan-review/SKILL.md`
  and run it through the real verifier — the marker pair, its exact wording,
  and the skeleton's validity were all verified mechanically in this plan
  (see acceptance-criteria checks run during execution).
- No blockers. This plan has no dependencies (`depends_on: []`) and ran in
  parallel with plan `08-01` per the phase's wave plan.

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: skills/codex-plan-review/SKILL.md
- FOUND: docs/decisions/0009-plan-review-gate.md
- FOUND commit: 04a10c0 (Task 1)
- FOUND commit: bae9bcc (Task 2)
