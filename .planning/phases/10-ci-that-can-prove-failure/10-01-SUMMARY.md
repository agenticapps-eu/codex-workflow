---
phase: 10-ci-that-can-prove-failure
plan: 01
subsystem: infra
tags: [github-actions, ci, matrix-build, migration-test-harness]

# Dependency graph
requires: []
provides:
  - "Real .github/workflows/ci.yml (matrix `test` job + `ci-gate` aggregation job) replacing the Phase-0 placeholder"
  - "A stable `ci-gate` check name for branch-protection registration in Plan 10-02"
affects: [10-02-ci-that-can-prove-failure]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GitHub Actions matrix job (fail-fast: false) with a downstream `needs: [job]` + `if: always()` aggregation job as the single stable required-check name"
    - "Unwrapped exit-code propagation from a repo test harness — no `|| true`, no continue-on-error, no exit-code-masking pipe"

key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"

key-decisions:
  - "Kept name: ci and the entire on: trigger block unchanged from the placeholder — only the jobs: block was replaced, per plan interface notes"
  - "gawk install step gated strictly to matrix.os == 'ubuntu-latest'; macOS deliberately keeps its BSD awk so the divergence CI-01 exists to catch is exercised, not homogenized away"
  - "Reworded explanatory comment on the harness-invocation step to avoid literally containing the substrings '|| true' / 'continue-on-error' (even in negated prose), since the plan's automated verify gate greps for those substrings anywhere in the file including comments"

patterns-established:
  - "ci-gate aggregation job: needs: [test] + if: always() + explicit needs.test.result != 'success' check — the pattern any future job added to the matrix should also be wired into before ci-gate can be trusted as the sole required check"

requirements-completed: [CI-01]

# Metrics
duration: 6min
completed: 2026-07-16
---

# Phase 10 Plan 01: Real CI Workflow Summary

**Replaced the Phase-0 `echo … exit 0` CI placeholder with a real two-job GitHub Actions workflow: an ubuntu+macOS matrix `test` job that runs `migrations/run-tests.sh` unwrapped (369 assertions, including the drift check), and a `ci-gate` aggregation job that fails unless every matrix leg succeeded.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-16T10:59:00Z
- **Completed:** 2026-07-16T11:05:34Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- `.github/workflows/ci.yml` now checks out with `submodules: recursive` (public `vendor/agenticapps-shared`, no token/ssh-key needed), matching the harness's hard-fail-without-submodule contract.
- Matrix `test` job runs on `ubuntu-latest` + `macos-latest` with `fail-fast: false`, so both legs always complete and neither auto-cancels the other.
- GNU awk installed on ubuntu only (gated `if: matrix.os == 'ubuntu-latest'`); macOS keeps its BSD awk unchanged so the BSD/GNU divergence the matrix exists to surface is actually exercised rather than erased.
- `bash migrations/run-tests.sh` runs unwrapped — no `|| true`, no `continue-on-error`, no exit-code-masking pipe — so the suite's own exit code (1 on any FAIL or "no tests ran", 0 otherwise) is the step's and job's pass/fail signal directly. `test_drift` is already dispatched inside the harness whenever it runs unfiltered.
- New `ci-gate` job (`needs: [test]`, `if: always()`) fails unless `needs.test.result == 'success'`, giving branch protection (Plan 10-02) one stable, matrix-change-proof required check name.
- The old `phase-0` echo/`exit 0` no-op job is fully removed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace the placeholder jobs block with the matrix test job + ci-gate aggregation job** - `cda2df5` (feat)

**Plan metadata:** (this SUMMARY commit, see below)

## Files Created/Modified
- `.github/workflows/ci.yml` - Rewritten `jobs:` block: matrix `test` job (checkout w/ recursive submodules, conditional gawk install, unwrapped harness invocation) + `ci-gate` aggregation job. `name:` and `on:` trigger block unchanged.

## Decisions Made
- Kept `name: ci` and the `on:` block byte-for-byte from the placeholder (minimal churn, matches plan interface notes).
- Job names `test` and `ci-gate` are locked identifiers per the plan (D-04 depends on both); step names/ordering beyond that were my discretion, following the worked example in `research/STACK.md` and `10-PATTERNS.md`.
- Reworded an explanatory code comment (see Deviations below) to avoid tripping the plan's own literal-substring verify gate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reworded harness-step comment to avoid literal gate-breaking substrings**
- **Found during:** Task 1, running the plan's own `<verify><automated>` gate after first draft
- **Issue:** My first draft included an explanatory comment reading "No `|| true`, no `continue-on-error`, no exit-code-masking pipe: ..." — intended to document the absence of these anti-patterns. The plan's automated verification gate does `! grep -Eq '\|\| true|continue-on-error' .github/workflows/ci.yml`, which greps the whole file including comments, so my own negation-in-prose caused the gate to fail (it can't distinguish "this pattern is absent" prose from the pattern itself).
- **Fix:** Reworded the comment to convey the same meaning ("This step is deliberately unwrapped and unmasked: the suite's own exit code IS this step's ... pass/fail signal") without containing the literal flagged substrings.
- **Files modified:** `.github/workflows/ci.yml`
- **Verification:** Re-ran the full `<verify><automated>` one-liner from the plan; all clauses now pass, output `GATES_PASS`. Also confirmed YAML parses (`python3 -c "import yaml; yaml.safe_load(open(...))"`), `phase-0` string is gone, and no `token:`/`ssh-key:` keys are present.
- **Committed in:** `cda2df5` (Task 1 commit — the file was corrected before its single commit was made, so no separate fix commit was needed)

---

**Total deviations:** 1 auto-fixed (1 blocking — verify-gate false-positive on prose, not on functional YAML)
**Impact on plan:** No scope creep; purely a comment wording change to satisfy the plan's own literal-substring verification gate. Functional workflow content is exactly as specified in the plan's `<action>` and matches `10-PATTERNS.md`'s worked example.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required. This plan only writes a committed workflow file; the remote proof that it actually runs on GitHub, and branch-protection registration referencing `ci-gate`, are Plan 10-02's responsibility (sequenced after this file is live on the default branch via a PR).

## Next Phase Readiness
- `.github/workflows/ci.yml` is ready for Plan 10-02 (Wave 2): the RED-proof (a deliberate, reversible regression to `test_drift`'s inputs) and branch-protection registration requiring the `ci-gate` check both depend on this file existing and running on GitHub first.
- No blockers. Plan 10-02 needs this file merged into the branch that opens the PR — same-repo PRs run the head-branch workflow, satisfying that precondition once this branch/PR is up.

---
*Phase: 10-ci-that-can-prove-failure*
*Completed: 2026-07-16*

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml`
- FOUND: `.planning/phases/10-ci-that-can-prove-failure/10-01-SUMMARY.md`
- FOUND: commit `cda2df5` (Task 1)
- FOUND: commit `1cf6987` (plan metadata / SUMMARY)
