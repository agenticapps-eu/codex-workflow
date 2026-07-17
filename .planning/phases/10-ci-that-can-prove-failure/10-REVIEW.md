---
phase: 10-ci-that-can-prove-failure
reviewed: 2026-07-16T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - .github/workflows/ci.yml
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-07-16T00:00:00Z
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed `.github/workflows/ci.yml`, the new CI pipeline replacing the placeholder: a `test` job matrixed over `ubuntu-latest`/`macos-latest` (`fail-fast: false`), recursive submodule checkout, conditional GNU awk install, an unwrapped `bash migrations/run-tests.sh` invocation, and a `ci-gate` aggregation job gating on `needs.test.result`.

Core correctness claims in the file's own comments were spot-checked against the referenced script and hold up:
- `migrations/run-tests.sh` does exit `1` when `FAIL > 0` (or when nothing ran), and exits `0` otherwise — so "the suite's own exit code IS this step's pass/fail signal" is accurate, and the workflow can genuinely "prove failure" rather than always reporting green.
- `test_drift()` is in fact dispatched unconditionally when `run-tests.sh` runs unfiltered (confirmed in the dispatcher block), matching the comment at lines 32-34.
- `.gitmodules` confirms `vendor/agenticapps-shared` is the only submodule and its URL is a public `https://github.com/...` remote, matching the "PUBLIC, no token needed" comment — today.
- No untrusted, attacker-controlled `${{ github.event.* }}` values (PR titles, branch names, commit messages) are interpolated into any `run:` block, so there is no classic Actions script-injection vector here. The only interpolations (`matrix.os`, `needs.test.result`) are workflow-generated, not attacker-controlled.

No blocking defects were found. The gaps below are all hardening/robustness gaps: missing least-privilege `permissions:`, an unpinned (tag, not SHA) action reference, no job timeouts, and a cross-file invariant (submodule visibility) that is enforced only by a comment rather than by the workflow itself.

## Warnings

### WR-01: `actions/checkout` pinned to a mutable major-version tag, not an immutable SHA

**File:** `.github/workflows/ci.yml:17`
**Issue:** `uses: actions/checkout@v7` pins to a floating tag. Tags on GitHub are mutable — they can be moved (deliberately, by mistake, or via a compromised maintainer account) to point at a different commit without the version string changing. GitHub's own Actions security hardening guidance recommends pinning third-party (and ideally first-party) actions to a full-length commit SHA precisely to close this supply-chain gap. Since this action recursively checks out a submodule and its output feeds directly into the test step, a retagged `checkout` action would run with no visible diff in this file.
**Fix:**
```yaml
      - uses: actions/checkout@<full-40-char-sha> # v7.x.x — pin by SHA, not tag
        with:
          submodules: recursive
```

### WR-02: No `permissions:` block — jobs inherit default (possibly broader-than-needed) token scope

**File:** `.github/workflows/ci.yml:1-46` (no `permissions:` key anywhere)
**Issue:** Neither the workflow nor either job declares `permissions:`. Both jobs therefore run with whatever the repository/org default `GITHUB_TOKEN` permissions are. `test` only needs read access to check out code; `ci-gate` needs no repository access at all (it only reads job-context data, not `secrets.GITHUB_TOKEN`). Without an explicit least-privilege declaration, a future edit that adds a step using `secrets.GITHUB_TOKEN` (e.g., posting a PR comment, creating a release) would silently inherit whatever broad default is configured at the org/repo level instead of being forced to opt in to the specific scope it needs.
**Fix:**
```yaml
permissions:
  contents: read

jobs:
  test:
    ...
  ci-gate:
    permissions: {}
    ...
```

### WR-03: No `timeout-minutes` on either job

**File:** `.github/workflows/ci.yml:10-46`
**Issue:** Neither `test` nor `ci-gate` sets `timeout-minutes`. The GitHub Actions default job timeout is 360 minutes. `migrations/run-tests.sh` is a large (4700+ line) harness that shells out to `git`, `jq`, `awk`, subshells, and `mktemp`; a hang in any of those (network stall, an accidentally-interactive path — the harness's own comments note migration 0000 requires interactive input and is explicitly skipped, implying awareness that interactivity is a real hazard in this codebase) would occupy a runner for up to 6 hours per matrix leg before GitHub force-kills it, instead of failing fast.
**Fix:**
```yaml
  test:
    timeout-minutes: 15
    ...
  ci-gate:
    timeout-minutes: 5
    ...
```

### WR-04: Submodule public-visibility invariant is enforced only by a code comment, not by the workflow

**File:** `.github/workflows/ci.yml:19-21`
**Issue:** The comment asserts "No token/ssh-key needed: vendor/agenticapps-shared is PUBLIC" as justification for omitting a `token`/`ssh-key` input on `submodules: recursive`. This is currently true (verified against `.gitmodules`: single submodule, `https://` public remote), but it is an invariant about external repo state that the workflow itself never checks. If a second (private) submodule is ever added anywhere in the recursive tree, or the `agenticapps-shared` repo's visibility is flipped to private, every push and PR run — including runs from external contributor forks, which get no elevated token — starts failing at the checkout step with an opaque authentication error, and the comment becomes actively misleading documentation instead of a safety note. There is no assertion/step that would surface "submodule became private" as a clear, actionable failure distinct from a generic checkout error.
**Fix:** Either accept the risk explicitly (this may be fine for a small team), or add a lightweight guard, e.g. a step that curls the submodule repo's visibility via the GitHub API and fails with a clear message if it's ever non-public, so a visibility flip surfaces as an intentional check rather than a cryptic checkout failure.

## Info

### IN-01: No `concurrency` group to cancel superseded runs

**File:** `.github/workflows/ci.yml:1-8`
**Issue:** Rapid successive pushes to the same PR/branch queue up full duplicate two-leg matrix runs instead of cancelling the now-stale in-flight one. Not a correctness issue, but a common CI hygiene gap that clutters the checks list and wastes Actions minutes.
**Fix:**
```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### IN-02: `apt-get` install step is noisy and pulls in recommended extras

**File:** `.github/workflows/ci.yml:27`
**Issue:** `sudo apt-get update && sudo apt-get install -y gawk` doesn't pass `-qq`/`--no-install-recommends`, so every ubuntu run installs gawk's full recommended package set and produces verbose apt logs. Cosmetic only.
**Fix:** `sudo apt-get -qq update && sudo apt-get -y --no-install-recommends install gawk`

### IN-03: No manual trigger (`workflow_dispatch`)

**File:** `.github/workflows/ci.yml:3-7`
**Issue:** The workflow only fires on `push`/`pull_request` to `main`. There is no way for a maintainer to re-run the full matrix on demand against an arbitrary ref (e.g., to re-verify red-proof behavior after touching `vendor/agenticapps-shared` without pushing a new commit).
**Fix:** Add `workflow_dispatch:` to the `on:` block.

---

_Reviewed: 2026-07-16T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
