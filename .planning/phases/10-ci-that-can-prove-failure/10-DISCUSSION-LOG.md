# Phase 10: CI That Can Prove Failure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-16
**Phase:** 10-ci-that-can-prove-failure
**Areas discussed:** Matrix & fail-fast, Required-check topology, RED-proof method (CI-02), Branch-protection scope

---

## Matrix & fail-fast

### Q1 — Matrix behavior when one leg fails

| Option | Description | Selected |
|--------|-------------|----------|
| fail-fast: false | Both legs always run to completion; see which platform broke and how. | ✓ |
| Default fail-fast: true | Cancel the sibling leg the moment one fails; faster but hides platform-specificity. | |

**User's choice:** fail-fast: false
**Notes:** macOS is in the matrix specifically to surface BSD/GNU shell divergence; auto-cancelling defeats that.

### Q2 — How OS values are expressed

| Option | Description | Selected |
|--------|-------------|----------|
| strategy.matrix.os | Single job, `runs-on: ${{ matrix.os }}`; idiomatic, minimal YAML. | ✓ |
| Two separate named jobs | Fixed hand-chosen check names, but duplicated YAML. | |

**User's choice:** strategy.matrix.os

### Q3 — awk/gawk defensiveness

| Option | Description | Selected |
|--------|-------------|----------|
| Preemptive gawk install | Add gawk defensively; cheaper than a first-run "awk: command not found". | ✓ |
| Reactive — wait for first run | awk practically certain present; only add if a run fails. | |
| You decide | Judge at plan/execute time. | |

**User's choice:** Preemptive gawk install
**Notes:** Claude refinement (agreed inline): gawk install is **ubuntu-only** — macOS must keep BSD awk, since that divergence is the reason macOS is in the matrix. Installing gawk on macOS would mask the signal.

---

## Required-check topology

### Q1 — How required checks are structured over a matrix

| Option | Description | Selected |
|--------|-------------|----------|
| Aggregation gate job | `ci-gate` `needs: [test]`, require only `ci-gate`; stable, matrix-change-proof. | ✓ |
| Require both leg names directly | Register `test (ubuntu-latest)` + `test (macos-latest)`; brittle strings. | |

**User's choice:** Aggregation gate job
**Notes:** A required check that silently stops matching (renamed/skipped leg) reads as "not failing" — the aggregation gate closes that hole.

### Q2 — Strict mode (require branches up to date)

| Option | Description | Selected |
|--------|-------------|----------|
| Strict: on | PR must be current on main and pass CI there before merge. | ✓ |
| Strict: off | Required check must pass, but not necessarily against latest main. | |
| You decide | Pick based on main's activity. | |

**User's choice:** Strict: on

---

## RED-proof method (CI-02)

### Q1 — Mechanism for observing CI go red

| Option | Description | Selected |
|--------|-------------|----------|
| Throwaway PR, reverted guard, close unmerged | Nothing lands on main; red observed in Actions UI. | ✓ |
| Mutation on the real feature PR | Break-then-fix within Phase 10's own PR history. | |
| You decide | Cleanest reversible approach at execute time. | |

**User's choice:** Throwaway PR, reverted guard, close unmerged

### Q2 — Which guard to break

| Option | Description | Selected |
|--------|-------------|----------|
| test_drift | Version-coupling drift check (run-tests.sh:3217); central to milestone theme. | ✓ |
| A migration fixture assertion | Break an exact-content fixture assertion; less central. | |
| You decide | Whichever gives the clearest red. | |

**User's choice:** test_drift

---

## Branch-protection scope

### Q1 — Require a pull request before merging

| Option | Description | Selected |
|--------|-------------|----------|
| Require PR, 0 approvals | Force changes through a PR (CI must run), no mandated human approval; solo-friendly. | ✓ |
| Require PR, 1 approval | Also require a human approving review; stalls solo work. | |
| Status check only, no PR requirement | Minimal; leaves the direct-push-to-main hole. | |

**User's choice:** Require PR, 0 approvals
**Notes:** Directly closes the `gsd-sdk query commit`-to-main footgun flagged in the session handoff.

### Q2 — Include administrators

| Option | Description | Selected |
|--------|-------------|----------|
| Include administrators | Rules apply to everyone; no bypass. On-theme for enforcement. | ✓ |
| Exempt administrators | Admins can bypass; convenient escape hatch. | |
| You decide | Judge at execute time. | |

**User's choice:** Include administrators
**Notes:** Can still be toggled off manually for a genuine emergency.

---

## Claude's Discretion

- Exact workflow/job/step naming beyond the stable `ci-gate` required-check name; step ordering; whether gawk is a standalone step or folded into setup.
- Keeping the top-level workflow `name: ci` and the matrix job name (`test`, assumed by `ci-gate`'s `needs: [test]`).
- Dropping the ubuntu gawk step if the suite's awk usage proves POSIX-portable under ubuntu's default mawk.

## Deferred Ideas

- Shellcheck / lint / dependency caching in CI — out of v0.8.0 scope.
- Full scaffold-and-migrate E2E smoke test — scope expansion beyond CI-01; named as deferred.
- Requiring ≥1 human approval on PRs — declined for now (solo repo); revisit with regular contributors.
