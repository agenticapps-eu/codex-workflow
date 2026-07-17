---
phase: 10-ci-that-can-prove-failure
verified: 2026-07-16T00:00:00Z
status: passed
score: 11/11 must-haves verified
overrides_applied: 0
---

# Phase 10: CI That Can Prove Failure Verification Report

**Phase Goal:** Replace the Phase-0 placeholder workflow with real, remote CI that runs the full suite and is proven able to go red.
**Verified:** 2026-07-16
**Status:** passed
**Re-verification:** No — initial verification

Evidence for this phase is split between a committed file (`.github/workflows/ci.yml`, Plan 10-01 / CI-01) and imperative GitHub-side state (Plan 10-02 / CI-02). Both were checked directly rather than trusting SUMMARY.md narration: the workflow file was read and grepped, and the GitHub-side claims (branch protection, PR states, run logs) were independently re-queried live via `gh api` / `gh pr view` / `gh run view --log` in this verification session.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CI runs on `push` and `pull_request` to `main` (CI-01, roadmap SC1) | VERIFIED | `.github/workflows/ci.yml:3-7` — `on.push.branches: [main]`, `on.pull_request.branches: [main]`, unchanged from placeholder |
| 2 | CI checks out with `submodules: recursive` (CI-01, roadmap SC1) | VERIFIED | `.github/workflows/ci.yml:17-19` — `actions/checkout@v7` with `submodules: recursive`, no token/ssh-key input (public submodule) |
| 3 | CI runs `migrations/run-tests.sh` unfiltered on ubuntu-latest + macos-latest, both legs always completing (CI-01, roadmap SC1) | VERIFIED | `.github/workflows/ci.yml:10-15,30` — `strategy.fail-fast: false`, `matrix.os: [ubuntu-latest, macos-latest]`, `run: bash migrations/run-tests.sh` (no filter arg, so `test_drift` dispatches) |
| 4 | Test job's exit status equals the suite's exit status — no `\|\| true`, no `continue-on-error`, no informational bolt-on (CI-01, roadmap SC1) | VERIFIED | `grep -Ec '\|\|true\|continue-on-error'` on the file returns 0 matches; step is a bare `run: bash migrations/run-tests.sh` with no pipe |
| 5 | A single stable `ci-gate` job aggregates every matrix leg and fails unless all legs succeeded (CI-01) | VERIFIED | `.github/workflows/ci.yml:36-46` — `needs: [test]`, `if: always()`, explicit `needs.test.result != 'success'` → `exit 1` |
| 6 | GNU awk (gawk) installed on ubuntu only; macOS keeps BSD awk (CI-01) | VERIFIED | `.github/workflows/ci.yml:25-27` — step gated `if: matrix.os == 'ubuntu-latest'`; no gawk install step for macOS |
| 7 | The new workflow has produced at least one resolvable `ci-gate` run on GitHub (CI-02, D-11 precondition) | VERIFIED | Live `gh pr view 20 --json statusCheckRollup`: `test (ubuntu-latest)` SUCCESS, `test (macos-latest)` SUCCESS, `ci-gate` SUCCESS — re-queried directly, not taken from SUMMARY |
| 8 | CI observed going RED in the GitHub Actions UI on a throwaway PR reverting `test_drift` (CI-02, roadmap SC2) | VERIFIED | Live `gh run view 29496307386 --log` shows `run_drift_test: drift mismatch — skill_version=0.6.0 migration_to_version=0.7.0`, `FAIL drift mismatch`, `FAIL version split ... (V-03)` on both `test (ubuntu-latest)` and `test (macos-latest)` legs — confirms the drift gate ran remotely and failed, not merely a local claim |
| 9 | The throwaway PR was closed unmerged and its branch deleted; nothing landed on main (CI-02) | VERIFIED | Live `gh pr view 21`: `state: CLOSED`, `merged: null`. Live `gh api .../branches/ci-red-proof-throwaway` → 404 "Branch not found" (deleted). `git log origin/main` contains no throwaway commit — the only "drift/0.6.0" hits on main are unrelated pre-existing v0.6.0-milestone and V-03 commits (`b842755`, `fb6b148`, etc.), confirmed by inspection, not the throwaway mutation |
| 10 | `ci-gate` (and only `ci-gate`) is registered as the sole required status check on `main`'s branch protection (CI-02, roadmap SC3) | VERIFIED | Live `gh api repos/agenticapps-eu/codex-workflow/branches/main/protection --jq '{contexts,strict,admins,approvals}'` → `contexts: ["ci-gate"]` exactly (no per-leg names) |
| 11 | Branch protection has strict mode on, requires a PR (0 approvals), and includes administrators (CI-02) | VERIFIED | Same live query → `strict: true`, `admins: true`, `approvals: 0` |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` | Real CI workflow (matrix `test` job + `ci-gate` aggregation job) replacing the phase-0 placeholder, containing `submodules: recursive` | VERIFIED | File exists, parses as valid YAML (`python3 -c "import yaml..."` succeeded), contains exactly two jobs (`test`, `ci-gate`), `phase-0` string count = 0 |
| GitHub-side: RED-run evidence + branch-protection state | RED-run URL + branch-protection GET showing `ci-gate`/strict/enforce_admins/require-PR | VERIFIED | Confirmed live, not from SUMMARY text alone — see truths 7-11 above |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `.github/workflows/ci.yml` test job | `migrations/run-tests.sh` | `run: bash migrations/run-tests.sh` (unwrapped) | WIRED | Exact match found, no pipe/mask, exit code propagates directly |
| `.github/workflows/ci.yml` ci-gate job | test matrix job | `needs: [test]` + result check | WIRED | `needs: [test]`, `if: always()`, `needs.test.result != 'success'` gate present |
| `main` branch protection `required_status_checks.contexts` | `ci-gate` | `gh api` PUT then GET | WIRED | Live GET confirms `["ci-gate"]` exactly |
| throwaway branch reverting SKILL.md version | `test_drift` FAIL → test legs red → ci-gate red | `pull_request` to `main` runs head-branch workflow | WIRED | Live run log (`29496307386`) shows the exact `test_drift` FAIL message on both matrix legs, `ci-gate` concluded `failure` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CI-01 | 10-01-PLAN.md | Real CI workflow: matrix + submodules + unfiltered harness + unwrapped exit code | SATISFIED | Truths 1-6 above |
| CI-02 | 10-02-PLAN.md | CI proven able to go RED remotely + registered as required status check | SATISFIED | Truths 7-11 above |

Both phase requirement IDs (CI-01, CI-02) are declared in PLAN frontmatter, appear in REQUIREMENTS.md's Continuous Integration section, and are mapped to Phase 10 in the Traceability table. No orphaned requirements for this phase. (Note: REQUIREMENTS.md's own checkbox/traceability rows still read unchecked/"Pending" for CI-01/CI-02 — this is a milestone-level bookkeeping artifact, not a functional gap; the phase's own ROADMAP.md entry is already marked `[x]` completed. Flagged as info, not a blocker, since it does not affect goal achievement in the codebase or on GitHub.)

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | `grep -niE "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER"` on `.github/workflows/ci.yml` returned zero matches. No `|| true`, `continue-on-error`, empty handlers, or hardcoded-empty stubs present. |

### Behavioral Spot-Checks / Live Re-verification

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Branch protection state | `gh api repos/agenticapps-eu/codex-workflow/branches/main/protection --jq '{contexts,strict,admins,approvals}'` | `{"admins":true,"approvals":0,"contexts":["ci-gate"],"strict":true}` | PASS |
| Phase PR baseline GREEN | `gh pr view 20 --json state,statusCheckRollup` | `test (ubuntu-latest)` / `test (macos-latest)` / `ci-gate` all `SUCCESS` | PASS |
| Throwaway PR closed unmerged | `gh pr view 21 --json state,mergedAt` | `state: CLOSED`, `merged: null` | PASS |
| Throwaway branch deleted | `gh api repos/.../branches/ci-red-proof-throwaway` | 404 Branch not found | PASS |
| RED-run log shows `test_drift` FAIL | `gh run view 29496307386 --log \| grep drift` | `run_drift_test: drift mismatch ... FAIL drift mismatch ... FAIL version split ... (V-03)` on both matrix legs | PASS |
| Nothing landed on main | `git log origin/main --oneline \| grep -i 'drift\|throwaway\|0.6.0'` | Matches are pre-existing unrelated v0.6.0-milestone/V-03 commits (`b842755`, `fb6b148`, `2846fea`, `5ebcf66`, `667e789`, `afc17e7`, `98c06f5`) — none reference the throwaway PR or its commit `e6566d9` | PASS |
| YAML validity | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` | Parses cleanly, jobs = `['test', 'ci-gate']` | PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` declared or found for this phase, and the phase's own verification mechanism is GitHub-side `gh api`/`gh run`/`gh pr` state, which was exercised live above in place of a probe script.

### Human Verification Required

None. Both `checkpoint:human-verify` tasks in 10-02-PLAN.md required human confirmation during execution, which the SUMMARY records as completed ("Self-Check: PASSED"). This verification session independently re-confirmed the same GitHub-side facts live (branch protection API, PR states, run logs) rather than relying on that record — these are deterministic, API-checkable facts, not subjective UX/visual judgments, so no further human testing is required.

### Gaps Summary

No gaps. All 11 must-have truths (roadmap Success Criteria 1-3 plus the more granular PLAN-frontmatter truths for CI-01/CI-02) are verified directly against the committed workflow file and live GitHub state — not inferred from SUMMARY.md claims. The Phase-0 placeholder is fully removed, the real matrix + ci-gate workflow runs unwrapped and exercises `test_drift`, a RED run was independently confirmed in the Actions log (not just asserted), the throwaway PR/branch are confirmed gone with nothing landed on `main`, and branch protection is confirmed live to require exactly `ci-gate` with strict/enforce-admins/0-approval-PR settings.

One informational note (not a gap): REQUIREMENTS.md's per-requirement checkboxes and Traceability table still show CI-01/CI-02 as unchecked/"Pending" even though ROADMAP.md marks Phase 10 `[x]` complete. This is a documentation-sync item for milestone bookkeeping, not a functional deficiency — recommend updating REQUIREMENTS.md's checkboxes/traceability status when convenient, but it does not block proceeding to Phase 11.

---

*Verified: 2026-07-16*
*Verifier: Claude (gsd-verifier)*
