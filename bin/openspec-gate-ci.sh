#!/usr/bin/env bash
# openspec-gate-ci.sh — CI driver for the §18 OpenSpec change-gate.
#
# Two steps, in this order and for a reason:
#
#   1. SCORE the gate with core's conformance harness.
#   2. RUN the gate in --ci mode.
#
# Step 1 is not ceremony. A drifted gate passes every repo it guards while
# enforcing nothing — issue #32 found five divergent copies on one machine, none
# conformant, each reporting clean. Scoring before trusting the verdict is the
# difference between "CI is green" and "CI checked something".
#
# THE GATE PATH IS REPO-LOCAL, DELIBERATELY. Unlike the pre-commit and
# PreToolUse surfaces — which prefer the shared ~/.agenticapps/bin/ copy so one
# machine-wide upgrade reaches every repo — CI must enforce with the copy it
# just scored. A GitHub Actions runner has no shared path at all, so preferring
# it would either fail open on every fresh runner or, once it existed, enforce
# with a copy CI never measured.
#
# --ci is WHOLE-REPO, not diff-scoped. Every active change must validate and
# carry >= 2 independent reviewers, regardless of which files the pull request
# touched. This replaced a driver that looped over changed files and piped a
# synthesized hook payload for each: that enforced, but it exercised the gate's
# HOOK path from a non-hook context, which §18's "demonstrable by direct script
# invocation" clause does not accept as a demonstration.
#
# Consequence worth knowing before it surprises you: a docs-only pull request
# fails while any active change is unreviewed, and a proposal-only pull request
# is red until REVIEWS.md lands. That is the rule working. Reviews come before
# code in this lifecycle, so the red window is the window in which the change
# genuinely is not ready to merge.
#
# Usage: bin/openspec-gate-ci.sh
#   (no base-ref argument — --ci does not diff)
#
# Exit: 0 = every active change validates and is reviewed; 1 = blocked.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

# This host's identity, so codex's own reviews do not satisfy the threshold.
export OPENSPEC_GATE_SELF="${OPENSPEC_GATE_SELF:-codex}"

GATE="$ROOT/bin/openspec-change-gate.sh"
HARNESS="$ROOT/tools/change-gate-conformance.sh"

# The gate is not vendored any more (ADR-0047): bin/ is a gitignored cache
# materialised from the core pin. Materialise before scoring, so this surface
# runs the bytes the installer would publish rather than whatever a checkout
# happens to contain. Idempotent and a no-op once correct.
#
# Fails closed exactly as the vendored check did. Unlike the local hooks this
# surface cannot be bypassed, so an unresolvable gate is a broken build, not a
# reason to wave the change through.
if ! "$ROOT/bin/materialise-core-artifacts.sh"; then
  echo "openspec-gate-ci: FAIL — could not materialise the gate from the core pin" >&2
  echo "  Diagnostics above. tools/core-vendor.manifest names the commit and the" >&2
  echo "  sha256; nothing runs unless the bytes verify against it." >&2
  exit 1
fi

if [ ! -x "$GATE" ]; then
  echo "openspec-gate-ci: FAIL — no gate at bin/openspec-change-gate.sh after materialising" >&2
  exit 1
fi

if [ ! -x "$HARNESS" ]; then
  echo "openspec-gate-ci: FAIL — no conformance harness at tools/change-gate-conformance.sh" >&2
  echo "  The harness is vendored from core alongside the gate. Without it we would be" >&2
  echo "  trusting a gate we never scored, which is exactly how the fleet drift went" >&2
  echo "  unmeasured. See the vendoring steps in core's gate README." >&2
  exit 1
fi

echo "openspec-gate-ci: scoring the gate before trusting its verdict"
# Run the harness in a CLEAN environment — specifically WITHOUT this host's
# OPENSPEC_GATE_SELF. The harness drives the gate with its own fixtures, and one
# row ("validate green + 2 reviewers -> allow") seeds reviewers `claude` and
# `codex`. With OPENSPEC_GATE_SELF=codex leaking in from this driver, the gate
# correctly excludes the codex review, the row sees 1 reviewer, and a perfectly
# conformant gate scores 27/28 — a false CI failure caused entirely by the
# measurement.
#
# The harness sets the variable itself for the rows that test self-exclusion, so
# unsetting it here removes ambient interference rather than skipping coverage.
# Core's gate README tells every host to set OPENSPEC_GATE_SELF and to run the
# harness; followed literally, in one shell, those two instructions conflict.
if ! env -u OPENSPEC_GATE_SELF bash "$HARNESS" "$GATE"; then
  echo "openspec-gate-ci: FAIL — the PINNED gate is not conformant with spec §18." >&2
  echo "  Do NOT hand-patch it: bin/ is a cache regenerated from the pin, so an edit" >&2
  echo "  there is erased on the next run and fixes nothing. Change it in" >&2
  echo "  agenticapps-workflow-core alongside a harness row, then advance core_commit." >&2
  exit 1
fi

# No spec slot => the repo has not adopted OpenSpec => nothing to gate.
if [ ! -d "openspec/changes" ]; then
  echo "openspec-gate-ci: no openspec/changes/ — repo has no spec slot yet, skipping"
  exit 0
fi

if "$GATE" --ci; then
  echo "openspec-gate-ci: OK — every active change validates (review evidence is advisory since gate 2.0.0)."
  exit 0
fi

echo "openspec-gate-ci: BLOCKED by the OpenSpec change-gate (§18)." >&2
echo "  Since gate 2.0.0 the ONLY blocking condition is 'openspec validate --all'." >&2
echo "  Review evidence is REPORTED, never enforced: a missing, stale or objecting" >&2
echo "  REVIEWS.md prints a NOTE and the gate still exits 0. So this failure means a" >&2
echo "  change does not validate — read the validator output above, not REVIEWS.md." >&2
echo "  This check is whole-repo: an invalid change blocks the build even if this" >&2
echo "  pull request did not touch it." >&2
exit 1
