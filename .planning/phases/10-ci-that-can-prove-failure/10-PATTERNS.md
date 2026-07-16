# Phase 10: CI That Can Prove Failure - Pattern Map

**Mapped:** 2026-07-16
**Files analyzed:** 1 (single source-file surface; branch-protection is an imperative `gh api` call with no committed-file analog)
**Analogs found:** 1 / 1 (self-analog: the file being replaced is its own closest structural precedent)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `.github/workflows/ci.yml` | config (CI workflow) | event-driven (push/PR trigger → batch test run) | `.github/workflows/ci.yml` (Phase-0 placeholder, same file, being replaced) | exact (same file, superseded shape) — cross-checked against the concrete worked example already drafted in `.planning/research/STACK.md:46-72` |
| (branch protection) | n/a — imperative `gh api` config, not a committed file | request-response (one-shot PUT + GET verify) | none (no committed file analog in this repo) | no-analog — see "No Analog Found" |

## Pattern Assignments

### `.github/workflows/ci.yml` (config, event-driven)

**Analog:** `.github/workflows/ci.yml` itself (Phase-0 placeholder, full file — 17 lines, read in full)

**Current placeholder (entire file, to be replaced):**
```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  phase-0:
    runs-on: ubuntu-latest
    steps:
      - name: Phase 0 — bootstrap-only
        run: |
          echo "phase-0: trivial CI placeholder; real checks land in Phase 7"
          exit 0
```

**What carries forward unchanged:** the top-level `name: ci` and the `on.push`/`on.pull_request` trigger block (lines 1-7) — CONTEXT.md's Claude's-Discretion section explicitly recommends keeping `name: ci` for minimal churn, and the trigger shape (`branches: [main]` on both push and PR) already matches D-01's requirement exactly. Only the `jobs:` block needs replacing.

**What must change:** the single trivial `phase-0` job (`echo ... exit 0`, an intentional always-green no-op) becomes a real `strategy.matrix` job named `test` (D-01, D-02) plus a `ci-gate` aggregation job that `needs: [test]` (D-04). The new job must NOT wrap the test invocation in anything that swallows its exit code — the placeholder's explicit `exit 0` is exactly the anti-pattern D-04/CONTEXT.md's "no `|| true`, no informational-only bolt-on" language warns against; the replacement step must let `bash migrations/run-tests.sh`'s own exit code propagate directly as the step (and therefore job) result.

**Concrete target shape** (worked and verified during research, not just theoretical — `.planning/research/STACK.md:46-72`; extend with matrix/gawk/ci-gate per CONTEXT.md D-01 through D-04):
```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    strategy:
      fail-fast: false          # D-02
      matrix:
        os: [ubuntu-latest, macos-latest]   # D-01
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
        with:
          submodules: recursive
          # No token/ssh-key needed: vendor/agenticapps-shared is PUBLIC
          # (gh api repos/agenticapps-eu/agenticapps-shared -> "private": false)
      # D-03: gawk on ubuntu ONLY — macOS keeps BSD awk deliberately
      - name: Ensure GNU awk (ubuntu only)
        if: matrix.os == 'ubuntu-latest'
        run: sudo apt-get update && sudo apt-get install -y gawk
      - name: Run migration test harness (includes drift check)
        run: bash migrations/run-tests.sh
        # No || true, no continue-on-error: the step's own exit code IS the
        # job's pass/fail signal. test_drift() is already dispatched inside
        # run-tests.sh whenever it runs unfiltered (migrations/run-tests.sh:3217,
        # main() dispatch at :4687-4689).

  ci-gate:                      # D-04 — stable required-check name
    needs: [test]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Require all matrix legs green
        run: |
          if [ "${{ needs.test.result }}" != "success" ]; then
            echo "test matrix did not fully succeed: ${{ needs.test.result }}" >&2
            exit 1
          fi
```
Note: the `ci-gate` step body above is illustrative of the aggregation contract (fail unless every matrix leg succeeded); CONTEXT.md leaves exact step naming/ordering to Claude's discretion (only the job name `ci-gate` and its `needs: [test]` dependency on the job named `test` are locked, per D-04's `needs: [test]` wording).

**Invocation-target pattern** — `migrations/run-tests.sh` (read in full: shebang/header lines 1-40, `test_drift` at lines 3213-3238, `main()` dispatch tail at lines ~4650-4711):

*Header / hard-fail-without-submodule pattern* (lines 20-39):
```bash
#!/usr/bin/env bash
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
...
cd "$REPO_ROOT"

# Shared harness primitives — agenticapps-shared submodule (SPLIT-01, per
# claude-workflow ADR-0035).
SHARED_LIB="$REPO_ROOT/vendor/agenticapps-shared/migrations/lib"
if [ ! -f "$SHARED_LIB/helpers.sh" ]; then
  echo "error: agenticapps-shared submodule not initialized." >&2
  echo "       Run: git submodule update --init --recursive   (or: bash install.sh)" >&2
  exit 1
fi
```
This confirms `submodules: recursive` on the checkout step is not optional — omitting it makes the harness hard-fail immediately with a clear, loud error rather than silently skip work. That is the exact mechanism CI-01 depends on to make "CI ran the real suite" verifiable.

*Dispatch — `test_drift` runs unconditionally when unfiltered* (tail of `main()`, near line 4685):
```bash
if [ -z "$FILTER" ] || [ "$FILTER" = "drift" ]; then
  test_drift
fi
```
Confirms: invoking `bash migrations/run-tests.sh` with no arguments (CI's invocation) always exercises `test_drift` — no separate CI step is needed to wire the drift check in.

*Exit-code contract — the whole reason no `|| true` is allowed* (final lines of the script):
```bash
if [ $FAIL -gt 0 ]; then
  exit 1
elif [ $PASS -eq 0 ] && [ $SKIP -eq 0 ]; then
  echo "  ${RED}NO TESTS RAN${RESET}"
  exit 1
else
  exit 0
fi
```
This is the load-bearing contract for D-04's "job's own exit status reflect the suite's": `run-tests.sh` already exits 1 on any FAIL *and* on the degenerate "no tests ran" case (guards against a silently-empty CI run reading as green). The CI step must invoke it directly (`run: bash migrations/run-tests.sh`) with no wrapping that could mask this exit code.

*The exact guard the RED-proof (D-06) reverts* — `test_drift()` (lines 3213-3229):
```bash
test_drift() {
  echo ""
  echo "${YELLOW}=== Drift — SKILL.md version == latest migration to_version ===${RESET}"
  if run_drift_test "$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md" "$REPO_ROOT/migrations"; then
    echo "  ${GREEN}PASS${RESET} SKILL.md version matches latest migration to_version"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} drift mismatch (see message above)"
    FAIL=$((FAIL+1))
  fi
  ...
}
```
The RED-proof throwaway branch (D-05/D-06) should mutate either the `SKILL.md` `version:` field or a `to_version` in the latest migration so `run_drift_test` returns false — this is a self-contained, fully reversible one-line-diff regression that flips `test_drift`'s PASS to FAIL and therefore flips `run-tests.sh`'s exit code from 0 to 1, which should surface as the `test` matrix legs failing and `ci-gate` failing in the Actions UI.

**Submodule dependency** — `.gitmodules` (read in full, 4 lines):
```
[submodule "vendor/agenticapps-shared"]
	path = vendor/agenticapps-shared
	url = https://github.com/agenticapps-eu/agenticapps-shared
```
Confirms the submodule is a public GitHub URL (no `token`/`ssh-key` checkout input needed), matching STACK.md's verified finding (`gh api repos/agenticapps-eu/agenticapps-shared` → `"private": false`).

---

## Shared Patterns

### Checkout with recursive submodules
**Source:** `.planning/research/STACK.md:60-64` (verified worked example, not an existing committed file — this repo has no prior `actions/checkout` usage to copy from since Phase-0's placeholder never checked out anything beyond the default)
**Apply to:** the sole `test` job's first step
```yaml
- uses: actions/checkout@v7
  with:
    submodules: recursive
```
Pin `@v7` (current major as of research date, verified via `gh api repos/actions/checkout/releases`) — do not use `@v4` from older training-data habits (STACK.md:80 explicitly flags this as a stale-pattern trap).

### Exit-code propagation (no swallowing)
**Source:** `migrations/run-tests.sh` tail (exit-code contract above)
**Apply to:** the `test` job's harness-invocation step, and the `ci-gate` aggregation step
Never append `|| true`, `continue-on-error: true`, or pipe through anything that resets `$?`. The suite's own exit code is the sole pass/fail signal (D-04's explicit prohibition; also SUMMARY.md Pitfall 1's "third green" failure mode).

### Matrix OS divergence, not homogenization
**Source:** CONTEXT.md D-01/D-02/D-03 (no existing codebase file — this is a new cross-cutting decision for this phase, recorded here since it applies to every step in the `test` job)
**Apply to:** every step inside the `test` job
`fail-fast: false` so both legs always complete; any defensive install (like gawk) must be conditioned with `if: matrix.os == 'ubuntu-latest'` — never applied uniformly, since uniform application would erase the exact BSD/GNU divergence signal the macOS leg exists to surface.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| branch-protection config (`main`, required check `ci-gate`, strict mode, require-PR, include-admins) | config (repo-admin API state, not a file) | request-response (one-shot `gh api` PUT + `gh api` GET to verify) | Not a committed source file — configured imperatively via `gh api repos/agenticapps-eu/codex-workflow/branches/main/protection` (PUT to set, GET to verify per D-10 / PITFALLS.md:80). No prior branch-protection call exists anywhere in this repo's history or docs to copy a payload shape from; the planner should treat PITFALLS.md:685 and CONTEXT.md D-07–D-10 as the authoritative decision source for the PUT body's keys (`required_status_checks.contexts: ["ci-gate"]`, `required_status_checks.strict: true`, `enforce_admins: true`, `required_pull_request_reviews` present with 0 required approvers), and must sequence this call *after* `ci.yml` exists and `ci-gate` has produced at least one resolvable run (D-11's sequencing note — the required-check name must exist in GitHub's check-name registry before it can be required). |

## Metadata

**Analog search scope:** `.github/workflows/`, `migrations/run-tests.sh`, `.gitmodules`, `.planning/research/STACK.md` (worked CI example), `.planning/research/PITFALLS.md` and `SUMMARY.md` (branch-protection verification method), `session-handoff.md` (sequencing/footgun context). No search outside this repository (family-isolation rule respected).
**Files scanned:** 5 (`.github/workflows/ci.yml`, `migrations/run-tests.sh`, `.gitmodules`, `.planning/research/STACK.md`, `.planning/phases/10-ci-that-can-prove-failure/10-CONTEXT.md`) + grep sweeps across `.planning/research/*.md` and `.planning/phases/**` for `gawk`, `actions/checkout`, and `branches/main/protection` references.
**Pattern extraction date:** 2026-07-16
