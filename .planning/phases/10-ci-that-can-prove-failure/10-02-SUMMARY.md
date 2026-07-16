---
phase: 10-ci-that-can-prove-failure
plan: 02
status: complete
requirements: [CI-02]
completed: 2026-07-16
---

# Plan 10-02 Summary — RED-proof + branch protection (CI-02)

## What was delivered

CI-02 is fully satisfied: the new CI was proven able to go RED in the GitHub
Actions UI (not merely a local log), and `ci-gate` is now the sole required
status check on `main`'s branch protection with strict mode, require-PR (0
approvals), and enforce-admins. No files were committed by this plan — its
outputs are GitHub-side state (a persisted RED-run URL and the branch-protection
API state).

## Task 1 — RED-proof via throwaway drift-reverting PR

- **Precondition (D-11) established first.** Phase branch `docs/start-milestone-v0.8.0`
  was pushed and phase PR **#20** opened to `main`. The new `ci.yml` ran on the
  head branch and concluded **GREEN** — `test (ubuntu-latest)`, `test (macos-latest)`,
  and `ci-gate` all `success`. This made the `ci-gate` check name resolvable in
  GitHub's registry (baseline: the workflow passes normally).
- **RED proven.** Throwaway branch `ci-red-proof-throwaway` (cut from the phase
  branch, carrying 10-01's `ci.yml`) reverted `skills/agentic-apps-workflow/SKILL.md`
  `version: 0.7.0 → 0.6.0`. Opened as PR **#21** to `main`. The head-branch
  workflow ran the real suite and went red:
  - **RED run URL:** https://github.com/agenticapps-eu/codex-workflow/actions/runs/29496307386
  - `ci-gate` concluded `failure`; both `test` legs concluded `failure`.
  - Root cause confirmed in the remote job logs — the `test_drift` guard ran
    remotely and failed:
    ```
    run_drift_test: drift mismatch — skill_version=0.6.0 migration_to_version=0.7.0 (0009-spec-11-region-aware-placement.md)
      FAIL drift mismatch (see message above)
      FAIL version split: SKILL.md=0.6.0 but .codex/workflow-version.txt=0.7.0 (V-03)
    Summary → FAIL: 2 → ##[error]Process completed with exit code 1
    ```
    The `ci-gate` job log shows `test matrix did not fully succeed: failure → exit 1`.
- **Discarded cleanly.** PR #21 closed UNMERGED; `ci-red-proof-throwaway` deleted
  locally and on the remote. Verified the throwaway commit `e6566d9` is not
  reachable from `origin/main` and zero throwaway commits are on `main` — nothing
  landed. The phase branch's `SKILL.md` remains unmutated at `version: 0.7.0`.

## Task 2 — Register ci-gate as the sole required status check on main

Applied via `gh api --method PUT repos/agenticapps-eu/codex-workflow/branches/main/protection`
with the four required top-level keys (D-07..D-10):
`required_status_checks = {strict: true, contexts: ["ci-gate"]}`,
`enforce_admins = true`, `required_pull_request_reviews = {required_approving_review_count: 0}`,
`restrictions = null`.

**Branch-protection GET evidence (`.../branches/main/protection`):**

```json
{"contexts":["ci-gate"],"enforce_admins":true,"required_approvals":0,"restrictions":null,"strict":true}
```

- `required_status_checks.contexts` == `["ci-gate"]` exactly — no per-leg matrix
  names (`test (ubuntu-latest)` / `test (macos-latest)`), so a matrix rename can't
  silently unmatch the gate (D-04).
- `required_status_checks.strict` == `true` (D-07).
- `enforce_admins.enabled` == `true` (D-09).
- `required_pull_request_reviews.required_approving_review_count` == `0` (D-08).
- Registration performed only after Task 1 produced a resolvable `ci-gate` run (D-11).

## Consequence (intended, D-11)

`main` now hard-blocks direct pushes and un-gated merges for everyone (admins
included). `docs/start-milestone-v0.8.0` and every subsequent v0.8.0 phase must
merge to `main` via PR, and the `gsd-sdk query commit`-to-main footgun is closed.
Phases 11–14 must assume no direct pushes to `main`.

## Self-Check: PASSED

- Baseline `ci-gate` GREEN confirmed on PR #20 (workflow passes normally).
- `ci-gate` observed RED on PR #21 in the GitHub Actions UI/logs, caused by
  `test_drift` running remotely; PR closed unmerged, branch deleted, main untouched.
- Branch-protection GET returns `ci-gate` as the sole required check with strict,
  enforce-admins, and 0 required approvals — the plan's automated acceptance gate
  returned `PROTECTION_OK`.
