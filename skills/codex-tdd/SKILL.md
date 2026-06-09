---
name: codex-tdd
version: 0.1.0
implements_spec: 0.4.0
implements_gate: tdd
description: |
  Run a test-first cycle for a single task: write the failing test
  first, commit it as `test(RED): …`, observe the failure, write the
  minimum code that makes the test pass, and commit it as
  `feat(GREEN): …`. Use when a plan task carries `tdd="true"` (or the
  user asks for "TDD", "red-green-refactor", "test first", "write the
  failing test", or any phrase that implies test-driven discipline).
  Refuses to write implementation code before the RED commit exists.
---

# codex-tdd

This skill fulfills the `tdd` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md).

## When to invoke

Any task with `tdd="true"` (or host-equivalent marker) on a plan
whose changeset will include logic verifiable by automated test.
Snapshot tests, browser-driven screenshot diffs, and visual regression
suites count as automated tests for TDD purposes — see the
rationalization-table row for "TDD is impractical for frontend."

## What this skill does

1. **Read the task.** Identify the smallest unit of behavior the test
   should pin down. If the task is too large to express as a single
   failing test, surface that to the user and split the task before
   continuing — RED → GREEN on a too-large task tempts skipping or
   over-claiming the test.
2. **Write the failing test.** Author the test first. Use the
   project's existing test framework, file naming, and harness. Do
   not write any implementation code yet.
3. **Verify the test fails for the right reason.** Run the test and
   inspect the output. The failure must be a *behavior* failure, not
   an *import* or *syntax* failure. If the test passes, the test is
   wrong — rewrite it. If the failure mode is a missing module, write
   the empty stub (no behavior) so the failure becomes the
   behavior-shaped one.
4. **Commit RED.** `git commit -m "test(RED): {{one-line behavior}}"`.
   The commit message MUST start with the `test(RED):` prefix so the
   verification scan can pair it later. The commit MUST contain only
   the test (and any empty stubs needed to make the test compile).
5. **Write the minimum implementation that makes the test pass.** No
   extra functionality, no speculative generalization, no
   refactoring. Just enough to flip the test to green.
6. **Run the test. Confirm green.** If still red, iterate steps 5–6.
   If green for the wrong reason (e.g. test was too lenient), go back
   to step 2.
7. **Commit GREEN.** `git commit -m "feat(GREEN): {{one-line
   behavior}}"`. The diff MUST contain only the implementation; no
   test changes.
8. **Optional refactor commit.** If the GREEN code is clearly
   improvable (rename, extract method, dedupe), `git commit -m
   "refactor: {{one-line description}}"`. Refactor MUST NOT change
   behavior; the test stays green throughout.

## Required evidence (per spec/06)

- One commit prefixed `test(RED):` whose runtime `pytest` /
  `vitest` / `jest` / `go test` / equivalent output demonstrably
  fails when run at that commit.
- One commit prefixed `feat(GREEN):` immediately following (no
  intervening unrelated commits) whose runtime test output shows
  the previously-failing test now passes.
- Both commit hashes referenced from the task's row in
  `VERIFICATION.md` under the Evidence subrow.
- Optional `refactor:` commit, also referenced if produced.

## Failure modes

The following rationalization-table rows are most likely to fire here
and MUST trigger STOP → DELETE → RESTART:

- "Code written before the test" (red flag 1)
- "Test added after implementation" (red flag 2)
- "Test passes on first run — no RED observed" (red flag 3)
- "Cannot explain why the test should have failed" (red flag 4)
- "Tests marked for 'later' addition" (red flag 5)
- "Keeping pre-written code as 'reference' while writing tests"
  (red flag 10)

If you notice yourself authoring implementation code while the failing
test does not yet exist on disk, stop. Delete the implementation,
write the test, then return to step 2.

## Notes for the Codex host

- The dev sandbox's default sandbox policy (read+write to project
  scope) is sufficient for steps 2–7. Step 3's test run may need
  network or auxiliary services depending on the project; surface and
  request escalation rather than skipping the verification.
- If the project's commit-message convention differs (e.g. uses
  `[red]` / `[green]` prefixes), use those — but still produce a
  paired sequence the verification scan can detect by its own host
  pattern.
