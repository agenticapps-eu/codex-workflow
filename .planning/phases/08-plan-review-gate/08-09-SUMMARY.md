---
phase: 08-plan-review-gate
plan: 09
subsystem: documentation
tags: [adr, gap-closure, plan-review-gate, documentation-of-record]

# Dependency graph
requires:
  - phase: 08-plan-review-gate
    provides: "08-07's CR-01/WR-01 code fixes and 08-08's WR-02 code fix, whose actual behavior this plan records"
provides:
  - "ADR-0009 decision 11 amended: the >=5-line fallback's routing contract was aspirational until 08-07's CR-01 fix, not always-true; the fallback itself remains unchanged and deliberately spoofable"
  - "ADR-0009 decision 4 amended: WR-01's D-15 codex-exclusion fix recorded with exclusion-vs-allowlist reasoning and the cross-host [codex, gemini] residual named explicitly"
  - "ADR-0009 decision 5 amended: WR-02 recorded as reproduced-and-fixed, with its self-sealing idempotency-masking property explained"
  - "ADR-0009 new decision 12: WR-03 recorded as an accepted, documented limitation (agent-mediated gate bounds severity), with the concrete future fix carried to Open follow-ups"
  - "Both .planning/config.codex.json and skills/setup-codex-agenticapps-workflow/templates/config-hooks.json fires_when text (IN-01) now names the REVIEWS.md-evidence condition that actually drives the block, staying byte-identical in the plan_review block"
affects: [08-plan-review-gate verification re-run, any later phase or host reading ADR-0009 as the conformance record for the plan-review gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mirror decision 11's own framing for a new accepted-limitation decision (WR-03/decision 12): state the limitation plainly, say why it is bounded, and carry the concrete fix to Open follow-ups rather than leaving a reader to infer disposition from silence"
    - "Distinguish 'aspirational contract' from 'enforced contract' explicitly in an ADR amendment when a prior decision's stated behavior was found not to hold in practice (CR-01 against decision 11) — record the correction as a sub-point of the original decision, not a silent rewrite of it"

key-files:
  created: []
  modified:
    - "docs/decisions/0009-plan-review-gate.md"
    - ".planning/config.codex.json"
    - "skills/setup-codex-agenticapps-workflow/templates/config-hooks.json"

key-decisions:
  - "CR-01 recorded as a correction to decision 11, not a rewrite of it: decision 11's original text (an already-true statement of the fallback's spoofability) stays; a new sub-paragraph explains that the ROUTING INTO the fallback was, until 08-07, reachable via an authoring accident (CRLF/trailing-space), not only deliberate frontmatter omission — three independent live reproductions across code review, verification, and gap-closure planning."
  - "WR-01/D-15 recorded under decision 4 rather than as a standalone decision, since it amends the same verifier-strictness decision (D-12/D-13/D-14) it sits beside; the exclusion-vs-allowlist reasoning and the cross-host residual are both stated without hedging, per the plan's explicit instruction."
  - "WR-02 recorded under decision 5 (the existing-install migration story), naming the self-sealing idempotency-masking property as the reason it was fixed rather than accepted-and-documented, in contrast with WR-03."
  - "WR-03 given its own new decision (12) rather than folded into decision 9 or 10 — it is a distinct topic (a script's own traversal guard, not the egress boundary or the agent-mediation caveat) and needs its own accepted-limitation framing mirroring decision 11's, plus its own Open follow-ups entry."
  - "IN-01's fires_when replacement text says 'distinct external reviewers' (not just 'distinct reviewers') to reflect D-15's codex-exclusion — matching the shipped verifier is the entire point of the finding, per the plan's explicit instruction."
  - "Task 1's <verify> was a bare grep -c with no asserted minimum (flagged in <known_defect_to_avoid>). Tightened during execution: verified each of CR-01 (3x), WR-01 (2x), WR-02 (2x), WR-03 (3x), D-15 (5x) individually clears a >=2 floor — a real, failable assertion instead of one aggregate count that could pass on a single incidental substring match."

requirements-completed:
  - "core spec §02 (plan-review gate) — the declarative binding now describes the condition that actually drives the block"
  - "core spec §09 (conformance) — ADR-0009 is now this host's accurate conformance record, naming what the gap-closure fixes actually changed"

# Metrics
duration: ~25min
completed: 2026-07-15
---

# Phase 8 Plan 09: Record Gap-Closure Fixes and WR-03/IN-01 Dispositions Summary

**Amended ADR-0009 decisions 4, 5, and 11 to record what 08-07/08-08 actually did (not what was predicted), added a new decision 12 accepting WR-03 as a documented limitation, and corrected the fires_when text in both config files (IN-01) to name the REVIEWS.md-evidence condition that actually blocks.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2 (ADR amendment, IN-01 config fix)
- **Files modified:** 3 (`docs/decisions/0009-plan-review-gate.md`, `.planning/config.codex.json`, `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json`)

## Accomplishments

- Read `08-07-SUMMARY.md` and `08-08-SUMMARY.md` in full before writing any ADR prose, so the record follows what the executors actually did (e.g. 08-08 fixed all 4 inline awk occurrences in `run-tests.sh`, not the 2 originally cited by line number in its own plan's `<interfaces>` block — reflected accurately in decision 5's new paragraph, which describes the fix at the level of "migration doc + its mirror," matching what 08-08 shipped).
- Decision 11 gained a sub-paragraph making explicit that its own load-bearing sentence ("a present, well-formed frontmatter is authoritative") was aspirational until 08-07: the byte-exact `---` comparison meant a CRLF/trailing-space REVIEWS.md had frontmatter a human would call present and well-formed yet still fell through to the fallback. The fallback itself is stated as unchanged and still deliberately spoofable — only the routing into it narrowed.
- Decision 4 gained two paragraphs: the WR-01 defect and its D-15 exclusion fix, with the exclusion-vs-allowlist reasoning stated in full (an allowlist false-blocks legitimate future vendors and cross-host reviewer names; it buys nothing against a spoofer who has `multi-ai-review-skipped` regardless), and the residual named without hedging (a legitimately-codex-reviewed cross-host `REVIEWS.md` now blocks on this host where it previously passed).
- Decision 5 gained a paragraph recording WR-02 as reproduced (not merely code-inspection-suspected) and fixed, explaining the self-sealing idempotency-masking property that made it worth fixing rather than accepting.
- New decision 12 records WR-03 as an accepted, documented limitation — the call this plan was required to make rather than leave silent — mirroring decision 11's own "a limitation recorded is a limitation a later reader can act on" framing, and adds the concrete future fix to Open follow-ups.
- Both `.planning/config.codex.json` and `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` have their `fires_when` extended identically; `jq -S` diff of the `plan_review` block is empty; `implements_spec` untouched in both files (`0.1.0` in the live config, `0.4.0` in the template — pre-existing drift, out of scope).
- Bootstrap paradox (decision 8) and `implements_spec` (decision 6) confirmed unchanged: `git diff` against both commits shows insertions only, no deletions, in the ADR file.

## Task Commits

1. **Task 1: Record gap-closure fixes and WR-03 acceptance in ADR-0009** - `2a9028e` (docs)
2. **Task 2: IN-01 — fires_when describes the condition that actually blocks** - `3c02da6` (fix)

## Files Created/Modified

- `docs/decisions/0009-plan-review-gate.md` - Decision 4: +2 paragraphs (WR-01/D-15 fix, cross-host residual). Decision 5: +1 paragraph (WR-02 reproduced-and-fixed). Decision 11: +1 sub-paragraph (CR-01 aspirational-to-enforced correction). New decision 12: WR-03 accepted-limitation record. `## Verification`: +1 paragraph naming the new fixture coverage. `## Open follow-ups`: +1 entry (WR-03's future fix). 132 insertions, 0 deletions.
- `.planning/config.codex.json` - `hooks.pre_execution.plan_review.fires_when` extended to name the REVIEWS.md-evidence condition and "distinct external reviewers" (D-15-aware wording).
- `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` - Identical `fires_when` extension, kept byte-identical to the live config's `plan_review` block.

## Decisions Made

See `key-decisions` in frontmatter above. The most consequential: giving WR-03 its own new decision (12) rather than folding it into an existing one, so the accepted-limitation framing and its Open follow-ups entry have a clean home that future readers can find by decision number the same way they'd find decision 11's fallback disclosure.

## Deviations from Plan

**1. [Rule 2 - missing critical functionality, per `<known_defect_to_avoid>`] Tightened Task 1's bare-count `<verify>`.**
- **Found during:** Task 1, before committing.
- **Issue:** The plan's own `<verify>` for Task 1 was `grep -c "D-15\|WR-03\|CR-01" docs/decisions/0009-plan-review-gate.md` — an aggregate count with no asserted minimum, the exact pattern the plan-checker flagged as a dead-by-construction check (per `<known_defect_to_avoid>`, referencing plan 08-05's two awk patterns that silently passed and read as coverage).
- **Fix:** Verified each of the five required terms individually against a real, failable `>=2` floor: `CR-01` (3), `WR-01` (2), `WR-02` (2), `WR-03` (3), `D-15` (5) — all pass a threshold that would actually fail if any term's coverage were removed or reduced to a single incidental mention (e.g. a passing reference in a cross-link rather than a substantive disposition).
- **Files modified:** None beyond the plan's own scope — this was a verification-method change, not a code change.
- **Commit:** N/A (verification only, folded into Task 1's own review before commit `2a9028e`).

No other deviations. Plan executed as written otherwise.

## Issues Encountered

- `vendor/agenticapps-shared` git submodule was uninitialized at session start (same environment artifact 08-08-SUMMARY.md recorded). Ran `git submodule update --init --recursive` to check it out at its already-pinned commit before running `migrations/run-tests.sh` — a local checkout reading the existing `.gitmodules` pin, not a change to any tracked file; `git status --short` confirmed a clean tree both before and after.
- The GitNexus PostToolUse hook reported the index as stale after each commit and suggested `npx gitnexus analyze`. Per this session's explicit instruction (a prior executor's run of that command regenerated untracked `CLAUDE.md`/`.claude/skills/` byproducts and blocked the orchestrator's automated merge), this was NOT run. The staleness is expected and left for the orchestrator's central re-index.

## Known Stubs

None. This plan is documentation-of-record only; no code, no UI, no data flow was introduced.

## Threat Flags

None beyond the plan's own `<threat_model>` entries (T-08-46 repudiation, T-08-47 information disclosure, T-08-48 elevation-of-privilege-accept), all three of which are the exact mitigations/acceptances this plan implements. No new surface introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Every finding from `08-REVIEW.md` now has an explicit, non-silent disposition recorded in the codebase: CR-01 and WR-01 fixed (08-07) and recorded (this plan); WR-02 fixed (08-08) and recorded (this plan); WR-03 accepted and documented (this plan, new decision 12); IN-01 corrected (this plan). Nothing is left to inference or silence — the exact failure `08-VERIFICATION.md` named ("silence is what let CR-01 sit unaddressed").
- The bootstrap paradox (decision 8) and the agent-mediated criterion-1 admission (decision 9) remain intact and unsoftened, per this plan's explicit constraint.
- `implements_spec` stays `0.4.0` in the template and the pre-existing `0.1.0` drift in `.planning/config.codex.json` is untouched, per D-17/D-18 and this plan's explicit constraint.
- This is the final plan of the gap-closure cycle and of phase 08. `bash migrations/run-tests.sh` is green: 277 PASS / 2 SKIP / 0 FAIL, unchanged from the 08-08 baseline (documentation-only plan, no test fixtures added or removed). Working tree is clean; no untracked byproducts.
- Ready for the orchestrator to update `STATE.md`/`ROADMAP.md`/`REQUIREMENTS.md` and close out phase 08.

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: docs/decisions/0009-plan-review-gate.md
- FOUND: .planning/config.codex.json
- FOUND: skills/setup-codex-agenticapps-workflow/templates/config-hooks.json
- FOUND commit: 2a9028e (docs — ADR amendment)
- FOUND commit: 3c02da6 (fix — IN-01 config correction)
