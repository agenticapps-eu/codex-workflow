# Phase 10: CI That Can Prove Failure - Context

**Gathered:** 2026-07-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the Phase-0 placeholder `.github/workflows/ci.yml` (currently a trivial
`echo … exit 0` job named `phase-0`) with real, remote CI that:

1. runs on `push` and `pull_request` to `main`,
2. checks out with `submodules: recursive` (the harness hard-fails without
   `vendor/agenticapps-shared`),
3. runs `migrations/run-tests.sh` **unfiltered** (which already exercises
   `test_drift`) on an **ubuntu + macOS** matrix,
4. lets the job's own exit status reflect the suite's — no `|| true`, no
   informational-only bolt-on,
5. is **proven able to go RED** (observed failing in the GitHub Actions UI, not
   just locally), and
6. is **registered as a required status check** on `main`'s branch protection.

Delivers CI-01 and CI-02. This is the serial, blocking first phase of v0.8.0 —
nothing else in the milestone is "verified" until real remote CI exists.

**Out of scope (locked by REQUIREMENTS.md / research SUMMARY.md):** CI lint,
shellcheck, caching, and a full scaffold-and-migrate E2E smoke test. The E2E
smoke would more directly have caught 0007's bug class but is explicit scope
expansion; named here so it isn't silently assumed delivered.
</domain>

<decisions>
## Implementation Decisions

### Matrix & fail-fast
- **D-01:** OS matrix expressed as `strategy.matrix.os: [ubuntu-latest, macos-latest]`
  with `runs-on: ${{ matrix.os }}` — one job definition, two runs. (Idiomatic;
  the two-OS set itself is locked by REQUIREMENTS.md decision 3.)
- **D-02:** `strategy.fail-fast: false` — both matrix legs always run to
  completion even when one fails. macOS exists specifically to surface BSD/GNU
  shell divergence, so we must see *which* platform broke; default fail-fast
  (auto-cancel the sibling leg) would defeat that.
- **D-03:** Preemptively ensure GNU awk on **ubuntu only** (e.g.
  `apt-get install -y gawk`; ubuntu's default is `mawk`). **macOS must keep its
  BSD awk** — that divergence is exactly what the matrix exists to catch, so do
  NOT install gawk on macOS. The runner-images doc itemizes `jq` but not `awk`;
  this closes the handoff's flagged awk-availability risk without masking the
  divergence signal. If the suite's awk usage turns out to be POSIX-portable and
  ubuntu's mawk already suffices, the gawk install is harmless but may be dropped
  at execute time.

### Required-check topology
- **D-04:** Add a small **`ci-gate` aggregation job** that `needs: [test]` (the
  matrix job) and fails unless every matrix leg succeeded. Register **only
  `ci-gate`** as the required status check on branch protection — NOT the
  per-leg names `test (ubuntu-latest)` / `test (macos-latest)`. Rationale: matrix
  leg names are brittle strings; a rename or OS-label change would silently stop
  matching the required-check config, and a required check that never runs reads
  as "not failing." The aggregation gate gives one stable name that is
  matrix-change-proof and can't be bypassed by a skipped/renamed leg.

### RED-proof mechanism (CI-02)
- **D-05:** Prove CI can go RED via a **throwaway branch that reverts a real
  guard**, pushed and opened as a PR, with the red run **observed in the GitHub
  Actions UI itself** (screenshot/link captured as evidence), then the **PR
  closed unmerged and the branch deleted** — nothing lands on `main`. Satisfies
  CI-02's "observed failing in the GitHub Actions UI, not merely a local log."
- **D-06:** The deliberate regression breaks **`test_drift`** (the version-coupling
  drift check; policy lives in this repo, wired at `migrations/run-tests.sh:3217`
  via the shared `run_drift_test` mechanism). It is the assertion CI-01 explicitly
  must exercise and is the on-theme gate for this milestone — breaking it proves
  the drift gate actually runs remotely. Fully reversible (revert the mutation,
  or just discard the throwaway branch).

### Branch protection (CI-02)
- **D-07:** **Strict mode ON** — "require branches to be up to date before
  merging." A PR must be rebased/updated on current `main` and pass CI there
  before merge, closing the "two PRs green separately but broken together" gap.
- **D-08:** **Require a pull request before merging**, with **0 required
  approvals** — force all changes through a PR so CI must run, but don't mandate
  a human approval (repo is frequently solo). Blocks direct-to-`main` pushes —
  which the handoff notes have already bitten this project via
  `gsd-sdk query commit` landing on `main`.
- **D-09:** **Include administrators** — protection rules apply to everyone,
  admins included; no bypass of `ci-gate` or direct push to `main`. Matches the
  milestone's "enforcement, not intention" thesis. (Can still be toggled off
  manually for a genuine emergency.)
- **D-10:** Sole required status check = **`ci-gate`** (see D-04). Verify
  registration via `gh api repos/agenticapps-eu/codex-workflow/branches/main/protection`
  (CI-02's stated confirmation method).

### Consequence to plan around
- **D-11:** Enabling D-07/D-08/D-09 means the current `docs/start-milestone-v0.8.0`
  branch and every subsequent v0.8.0 phase must merge to `main` **via PR** — and
  the `gsd-sdk query commit`-to-`main` footgun becomes hard-blocked. This is the
  intended outcome, but planning/execution for Phases 11–14 must assume no direct
  pushes to `main`. Sequencing note: turning on branch protection (D-07..D-10)
  only makes sense *after* CI-01's workflow exists and `ci-gate` has produced at
  least one run GitHub can see (otherwise the required check name won't resolve).

### Claude's Discretion
- Exact workflow/job/step naming beyond the required `ci-gate` check name (kept
  stable), step ordering, and whether the gawk step is a standalone step or
  folded into a setup step.
- Whether to keep the top-level workflow `name: ci` (recommended — minimal
  churn) and the internal job name for the matrix job (`test` assumed by D-04's
  `needs: [test]`).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap (locked scope)
- `.planning/REQUIREMENTS.md` — CI-01 and CI-02 full text; the milestone-wide
  "observed failing before shipped" mutation-proof standard; the Out of Scope
  section (no lint/shellcheck/caching/E2E smoke).
- `.planning/ROADMAP.md` §"Phase 10: CI That Can Prove Failure" — goal, depends-on,
  and the three success criteria (workflow shape, RED-proof, branch-protection
  registration).

### Research grounding (HIGH confidence, primary sources)
- `.planning/research/SUMMARY.md` — CI-01 fully de-risked: `actions/checkout@v7`
  + `submodules: recursive` against confirmed-public submodule, `jq` present on
  `ubuntu-latest`, drift already wired as `test_drift`; Pitfall 1 ("CI goes green
  while testing nothing") and its avoidance checklist; awk-availability gap
  (Gap 4).
- `.planning/research/STACK.md` — `actions/checkout@v7` (current major,
  2026-06-18) and `ubuntu-latest` (24.04) facts, verified live via `gh api`.
- `.planning/research/PITFALLS.md` — Pitfall 1 detail (omitted `submodules:
  recursive`, `|| true`, drift bolted on as informational, CI without
  branch-protection required-check registration).

### Code touched / referenced
- `.github/workflows/ci.yml` — the Phase-0 placeholder being replaced.
- `migrations/run-tests.sh` — the suite CI runs unfiltered; `test_drift` at
  `:3217`, dispatched in `main()` at `:4687`; hard-fails at top if
  `vendor/agenticapps-shared` submodule lib is absent (motivates `submodules:
  recursive`).
- `.gitmodules` — `vendor/agenticapps-shared` → public
  `https://github.com/agenticapps-eu/agenticapps-shared` (no token needed).
- `migrations/test-fixtures/README.md` — fixture contract (context for what the
  suite exercises).

### Session continuity
- `session-handoff.md` (repo root) — flags the `gsd-sdk query commit`-to-`main`
  recurrence (relevant to D-08/D-11) and the awk/gawk open item (D-03).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `migrations/run-tests.sh`: the single entry point CI invokes unfiltered. No new
  test script is needed — CI-01 is "a workflow file + a proof-it-can-go-red," per
  research. It already sources shared harness primitives from the submodule and
  runs all fixtures plus `test_drift`.
- `test_drift` (`run-tests.sh:3217`, via shared `run_drift_test`): the guard the
  RED-proof (D-06) reverts.

### Established Patterns
- The harness hard-fails with a clear error if
  `vendor/agenticapps-shared/migrations/lib/helpers.sh` is missing — so a
  checkout WITHOUT `submodules: recursive` would fail loudly (good), but the
  point is CI must clone the submodule so the suite actually runs. `submodules:
  recursive` is mandatory, not optional.
- Repo remote: `origin` = `https://github.com/agenticapps-eu/codex-workflow.git`
  → `owner/repo` = `agenticapps-eu/codex-workflow` for all `gh api` branch-
  protection calls.

### Integration Points
- New `.github/workflows/ci.yml` (matrix `test` job + `ci-gate` aggregation job)
  is the only source-file surface. Branch-protection changes are made via
  `gh api` (repo-admin operation), not a committed file.
</code_context>

<specifics>
## Specific Ideas

- The `ci-gate` aggregation-job pattern (a `needs:`-gated no-op job whose success
  requires every matrix leg) is the intended shape for a stable required-check
  name — chosen deliberately over registering brittle per-leg matrix check names.
- RED-proof evidence should be a link/screenshot of the **GitHub Actions UI run**
  showing the failed `ci-gate` (or failed leg feeding it), not a local terminal
  log — CI-02 is explicit that a local log does not satisfy it.
</specifics>

<deferred>
## Deferred Ideas

- **Shellcheck / lint / dependency caching in CI** — explicitly out of v0.8.0
  scope (REQUIREMENTS.md Out of Scope). A later milestone item if desired.
- **Full scaffold-and-migrate E2E smoke test** — would more directly catch the
  0007 bug class, but is scope expansion beyond CI-01; named as deferred, not
  silently assumed delivered.
- **Requiring ≥1 human approval on PRs** — considered and declined for now
  (D-08, solo repo); revisit if the project gains regular contributors.

None of the above expanded this phase's scope — discussion stayed within CI-01/CI-02.
</deferred>

---

*Phase: 10-ci-that-can-prove-failure*
*Context gathered: 2026-07-16*
