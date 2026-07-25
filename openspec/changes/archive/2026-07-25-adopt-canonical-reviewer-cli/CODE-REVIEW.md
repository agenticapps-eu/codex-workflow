# Stage-2 code review — adopt-canonical-reviewer-cli

**Date:** 2026-07-25 · **Status: NOT independently reviewed — the operator declined the egress.**

## What did not happen, and why it is recorded rather than papered over

§07 requires the implementation diff to be reviewed in an **independent context**.
`openspec validate` does not discharge it, and neither does `REVIEWS.md` — that
review read the *proposal*, before any code existed.

The implementation diff was **not** sent to `gemini` or `opencode`. The operator
was asked and declined, which is theirs to decide. Subagents were not authorised
this session either.

What follows is the implementing agent reading its own code. **That is not an
independent review and does not satisfy §07.** It is recorded as a self-check so
the gap is visible rather than implied by an artifact that looks like a review.
A reviewer of this PR should treat the diff as unreviewed by anyone but its
author.

## Self-check findings

Two defects were found and fixed during implementation, both in assertions rather
than in shipped behaviour. Both are recorded because a test that passes for the
wrong reason is worse than a missing test:

1. **The CI-ordering row compared a comment against a step.** It grepped for bare
   filenames, and the workflow names `bin/openspec-gate-ci.sh` in a header
   comment 60 lines above the step that runs it — so it reported a reversed order
   that did not exist. The workflow was already correct; the instrument was not.
   Fixed to match `run:` lines. (`d502c42`)
2. **The 0015 tests were registered inside the `0014` filter block**, so
   `run-tests.sh 0015` matched nothing and the rows were attributed to a
   migration that does not own them. (`01293c2`)

Mechanics checked by hand, all clean:

- `install.sh` is `set -uo pipefail` with no `-e`, so the `cli_rc=$?` capture
  after the installer call is safe — and it is the same pattern the gate's block
  already uses.
- The new install block sits **outside** the `if [ "$DRY_RUN" -eq 0 ]` guard, as
  the gate's does, because `install-gate.sh` handles `--dry-run` itself. Verified
  by running `bash install.sh --dry-run`: it reports
  `would install reviewer-cli 1.0.0 over 1.0.0 (refresh); nothing written`, exits
  0, and the shared file's sha256 is unchanged afterwards.
- `install-gate.sh` creates `$DEST_DIR` itself, so the block preceding the
  `mkdir -p "$AA_BIN"` is not an ordering bug.
- The new CI step interpolates no `${{ }}` expressions, so the workflow-injection
  class does not apply to it.

## What stands in place of the missing review

Not equivalent, and listed so the reader can judge the residual:

- **The change bundle had three rounds of genuine external review**, two of them
  REQUEST-CHANGES from both reviewers. That scrutiny landed on the design and the
  TDD plan — including catching a `tdd="true"` row whose RED did not reproduce —
  but it read no code.
- **A 12-mutation pass**, one per assertion group, each breaking exactly one
  thing. All 12 were caught; zero survivors. This is evidence the rows are
  load-bearing, not evidence the implementation is correct.
- **`test_migration_0014_arbitration` (19 rows) passed untouched** against the
  refactored installer, which is the regression cover for the only change to
  existing behaviour.
- **599 PASS / 0 FAIL / 1 SKIP**, `openspec validate --all` green, gate `--ci`
  green.
