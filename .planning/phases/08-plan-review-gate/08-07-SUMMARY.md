---
phase: 08-plan-review-gate
plan: 07
subsystem: testing
tags: [bash, tdd, gap-closure, plan-review-gate, security-hardening]

# Dependency graph
requires:
  - phase: 08-plan-review-gate
    provides: "check-plan-review.sh verifier (08-01, 08-02) and its REVIEWS.md strictness contract (ADR-0009 decisions 11 and 15)"
provides:
  - "Tolerant frontmatter delimiter detection (CR/trailing-whitespace normalized on both opening and closing '---' comparisons) so a CRLF or trailing-space REVIEWS.md is parsed strictly instead of silently downgrading to the spoofable D-13 fallback"
  - "D-15 codex-identity exclusion in the distinct-reviewer count, applied after existing lowercase normalization, with a block message that names the excluded count and cites D-15"
  - "13 new regression fixtures in test_check_plan_review_enforcement pinning both fixes in both directions (fail-open closed, no over-correction)"
affects: [08-plan-review-gate verification re-run, any future phase depending on the plan-review gate's strictness contract]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Exclusion-not-allowlist for identity checks in a gate that already has documented escape hatches: excluding a known bad value protects against honest mistakes without risking false-blocking a legitimate but unrecognized vendor name"
    - "Mirrored normalization on both halves of a paired delimiter search (open + close) so a tolerance fix cannot itself introduce a new asymmetric MALFORMED misclassification"

key-files:
  created: []
  modified:
    - "skills/agentic-apps-workflow/scripts/check-plan-review.sh"
    - "migrations/run-tests.sh"

key-decisions:
  - "CR-01 fixed by normalizing CR + trailing whitespace on the opening '---' comparison AND mirroring the identical normalization onto the closing-delimiter awk search — asymmetric normalization would have traded a fail-open for a false MALFORMED report on some CRLF files."
  - "WR-01 fixed via exclusion (grep -vE '^codex([-_ ].*)?$') rather than a hard-coded vendor allowlist, per the plan's explicit reasoning: an allowlist would false-block a legitimate future vendor or a cross-host REVIEWS.md naming a reviewer this host doesn't recognize (ADR-0007 point 5), and buys nothing against a determined spoofer who has the same escape hatches available either way."
  - "The >=5-line D-13 fallback itself was left untouched — only the routing INTO it was narrowed. A dedicated fixture (frontmatter-less 6-line body) pins that it still exits 0."

requirements-completed: []

# Metrics
duration: ~15min
completed: 2026-07-15
---

# Phase 8 Plan 07: Close CR-01/WR-01 REVIEWS.md Fail-Opens Summary

**Tolerant CR/whitespace-normalized frontmatter delimiter matching plus D-15 codex-exclusion in the reviewer count, closing both verified fail-opens in check-plan-review.sh's REVIEWS.md strictness check.**

## Performance

- **Duration:** ~15 min (RED commit 11:32 UTC+2, GREEN commit 11:36 UTC+2)
- **Tasks:** 2 (RED, GREEN)
- **Files modified:** 2 (`migrations/run-tests.sh`, `skills/agentic-apps-workflow/scripts/check-plan-review.sh`)

## Accomplishments

- CR-01 closed: a REVIEWS.md whose opening `---` carries a trailing space or CRLF line ending is now routed to the strict frontmatter path (and blocked if under-reviewed) instead of silently falling through to the reviewer-check-free D-13 fallback.
- WR-01 closed: `reviewers:` entries that are codex-derived (`codex`, `codex-self`, `codex_foo`, `"codex bar"`, case-insensitive) are excluded from the distinct-reviewer count before the `>=2` floor test, per D-15.
- The block message, when codex-derived entries were excluded, now states the external-reviewer count, the number of excluded entries, cites D-15 by name, and suggests vendor-diverse remedy names (claude, gemini, opencode) — the operator can act on it instead of seeing a bare count.
- 13 new fixtures added to `test_check_plan_review_enforcement`: 4 pin the fail-open closures (initially FAIL, now PASS), 4 pin over-correction guards (already-passing, still passing), 4 pin the WR-01 identity cases (case-insensitivity, zero-margin, honest-mistake), 1 pins the retained D-13 fallback.
- The three exact repro commands from 08-VERIFICATION.md/08-REVIEW.md now exit 2 with an actionable message; the frontmatter-less >=5-line fallback still exits 0.

## Task Commits

Strict RED -> GREEN TDD gate sequence, verified in git log (`test(...)` precedes `feat(...)`):

1. **Task 1: RED — fixtures that reproduce both fail-opens** - `b25e151` (test)
2. **Task 2: GREEN — tolerant delimiters (CR-01) + D-15 codex exclusion (WR-01)** - `70ff2c9` (feat)

_No metadata-only commit yet — this SUMMARY.md is committed separately below per worktree protocol._

## Files Created/Modified

- `migrations/run-tests.sh` - Added 13 fixtures across 3 new sections (`Delimiter tolerance (CR-01 regression)`, `Reviewer identity / D-15 codex exclusion (WR-01)`, `D-13 fallback is RETAINED`) inside `test_check_plan_review_enforcement`, inserted after the existing malformed/absent-frontmatter block.
- `skills/agentic-apps-workflow/scripts/check-plan-review.sh` - Normalized the opening-delimiter first-line comparison (`tr -d '\r'` + trailing-whitespace strip); rewrote the closing-delimiter awk search to apply the identical normalization per-line before comparing to `---`; piped the extracted frontmatter block through `tr -d '\r'` so downstream parsing is encoding-independent; split the reviewer-count pipeline to separate codex-derived entries (`_cpr_reviewers_excluded`) from external ones (`_cpr_reviewers_external`) before the `-lt 2` test; extended the block message to name the D-15 exclusion when it fired.

## Decisions Made

- **Exclusion, not an allowlist, for WR-01.** A hard-coded vendor allowlist (only claude/gemini/opencode count) would silently false-block a legitimate future vendor or a cross-host REVIEWS.md naming a reviewer this host hasn't heard of — exactly the failure mode D-13 already warns against for the fallback. It also protects nothing against a determined spoofer, who could bypass the gate via the existing escape hatches (`GSD_SKIP_REVIEWS=1`, `multi-ai-review-skipped`) regardless. Exclusion targets exactly the honest mistake D-15 names: counting codex, the implementing host, as if it were an external reviewer.
- **Mirrored normalization on the closing delimiter, not just the opening one.** Fixing only the opening comparison would have left a CRLF closing `---` unmatched, misreporting a well-formed CRLF file as MALFORMED instead of parsing it strictly — the opposite failure mode (false block) from CR-01's fail-open. Both directions had to move together for "open and close agree" to hold.
- **Closing-delimiter behavior change (recorded per plan's `<action>` instruction):** a closing delimiter with a trailing space, which previously fell through byte-exact matching and was reported MALFORMED (blocking, exit 2), is now accepted as a valid closing delimiter once the normalization mirrors the opening one — the file is then parsed strictly and allowed or blocked on its actual reviewer content, not on the delimiter's whitespace. Verified during planning that no existing test pinned the old MALFORMED-on-trailing-space-close behavior, so nothing regressed.
- **Residual, named and not silently absorbed:** a REVIEWS.md produced on a different host that legitimately used `codex` as an external reviewer (e.g. `[codex, gemini]` written by claude-workflow in a shared tree) now blocks on this host, where it previously passed. This is D-15 applied exactly as written — from codex's own vantage, codex is always self-review — and both escape hatches remain available if this is a false positive in a specific cross-host scenario.
- **GitNexus impact analysis:** the MCP tools (`gitnexus_impact`, `gitnexus_detect_changes`) were not present in this executor's toolset (only Read/Write/Edit/Bash). Performed the equivalent check manually via `grep -rn` for the four touched internal variable names across the repo — all four are consumed only within `check-plan-review.sh` itself; no other script or doc references them programmatically. Blast radius confirmed confined to this one file and its dedicated `run-tests.sh` fixture suite.

## Deviations from Plan

None - plan executed exactly as written. All four "currently exits 0" repro fixtures were confirmed to fail during RED for the documented reason (silent exit 0 with no diagnostic stderr, verified by manually re-running each fixture against the pre-fix script and capturing stderr — none failed incidentally on a coverage or missing-plan message).

One incidental side effect was reverted, not a deviation from the plan's scope: an earlier `npx gitnexus analyze` invocation (attempted per CLAUDE.md's impact-analysis mandate, before finding the MCP tools were unavailable) regenerated `AGENTS.md`'s embedded GitNexus symbol-count banner. That edit was unrelated to this plan's `files_modified` list and was reverted with `git checkout -- AGENTS.md` before staging the task commit.

## Issues Encountered

None. The manual re-verification pass against the pre-fix binary (before Task 2's edit) confirmed all three exact repro commands from the task prompt reproduced live with the documented exit code and (for the exit-0 fail-opens) no diagnostic output — consistent with 08-VERIFICATION.md's and 08-REVIEW.md's findings, not an artifact of this session's fixtures.

## Known Stubs

None.

## Threat Flags

None — both threat-register entries T-08-40 and T-08-41 (mitigate dispositions) are the exact mitigations this plan implements; no new surface was introduced beyond what the plan's own `<threat_model>` already scoped. T-08-42 (the retained D-13 fallback, accept disposition) and T-08-43 (over-correction risk, mitigated by the guard fixtures) are both confirmed holding as designed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The verifier's REVIEWS.md strictness contract now matches what ADR-0009 decision 11 (D-13 fallback) and D-15 (codex exclusion) already state in prose — the code and the documented contract are aligned.
- `bash migrations/run-tests.sh` is green: 273 PASS / 2 SKIP / 0 FAIL (main-tree baseline was 260/1/0; the extra SKIP is the documented worktree artifact — missing sibling `agenticapps-workflow-core` repo, not a regression). `check-plan-review` suite alone: 136 PASS / 0 FAIL, including `test_check_plan_review_contract`'s real-artifact round trip against this repo's own zero-margin `08-REVIEWS.md` (`[gemini, codex, opencode]` -> 2 external after exclusion -> still exit 0).
- Ready for 08-VERIFICATION.md re-run against this gap closure, and for the remaining gap-closure plans 08-08/08-09 in this same wave.
- No architectural changes were introduced; this plan closes two code-review findings against an existing, already-shipped verifier.

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: skills/agentic-apps-workflow/scripts/check-plan-review.sh
- FOUND: migrations/run-tests.sh
- FOUND: .planning/phases/08-plan-review-gate/08-07-SUMMARY.md
- FOUND commit: b25e151 (test — RED)
- FOUND commit: 70ff2c9 (feat — GREEN)
