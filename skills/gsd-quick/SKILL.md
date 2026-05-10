---
name: gsd-quick
version: 0.1.0
implements_spec: 0.1.0
description: |
  Run a tiny or small task with GSD discipline but without full phase
  planning overhead. Emits a minimum commitment-ritual block, routes
  directly to the gate skills the task actually triggers (TDD where
  applicable, verification always), and finishes with branch-close.
  Use for typo fixes, single-file logic changes, isolated bug fixes —
  anything that does not warrant a CONTEXT.md / PLAN.md / VERIFICATION.md
  trio. Typed by the user as `$gsd-quick "<one-line task>"`. Explicit-only
  (`policy.allow_implicit_invocation: false`).
---

# gsd-quick

This skill is the GSD entry point for tasks too small to warrant the
full discuss → plan → execute cycle, without abandoning the
discipline contract.

## When to invoke

User types `$gsd-quick "<one-line task description>"`. The trigger
skill's Step 1 task-size table classifies the request as **tiny**
(typo / comment / README tweak) or **small** (single-file logic
change, isolated bug fix, ≤ ~20 lines diff).

If the task is medium or large, refuse and route to
`$gsd-discuss-phase` instead — pretending a medium task is small is
how plans accumulate technical debt.

## What this skill does

1. **Confirm task size.** Read the user's one-liner. If it implies
   multiple files, new abstractions, or new behavior at a system
   boundary, surface the size mismatch and route to discuss/plan.
2. **Emit the commitment-ritual block.** Per spec/01 — first user-facing
   output, names the skill list, the task scope, and the verification
   evidence. Skip-protected.
3. **Route to gate skills based on size:**

   | Size | Skill chain |
   |---|---|
   | Tiny | `codex-verification` |
   | Small | `codex-tdd` (if logic verifiable by test) → `codex-verification` → `codex-finishing-branch` |

4. **Make the change.** For tiny: edit, verify (one-line evidence),
   commit. For small: run the TDD cycle (RED → GREEN → optional
   refactor), verify each must_have, commit per cycle.
5. **Verify.** `codex-verification` writes a one-or-two-line
   VERIFICATION-quick.md (or appends to a project-wide
   VERIFICATION.md if one exists) with the must_have + Evidence
   subrow.
6. **Branch close.** `codex-finishing-branch` composes a PR
   description scaled to the task — for a tiny typo fix, the PR body
   is one paragraph plus the link to the verification line.

## Output

- A feature branch with the change committed
- A one-or-two-line verification artifact (file path, grep result,
  test output)
- An opened PR with a minimal but conformant body

## Failure modes

- **Treating a medium task as quick.** The discipline contract
  preserves a planning artifact for anything that could go wrong;
  quick is for tasks where almost nothing can go wrong. If you find
  yourself rationalizing scope, surface it and route to discuss.
- **Skipping verification "because it's a typo."** Per spec/06,
  trivial tasks have trivial evidence; a one-line grep result IS
  evidence. Zero evidence is non-conformant regardless of size.
- **Skipping the commitment block.** Spec/01 applies to every
  code-touching turn including this one. The block takes 15 seconds.
- **Skipping branch-close.** Even tiny changes go through PR review;
  direct-to-main commits bypass the discipline contract for the
  reviewer's sake too.

## Notes for the Codex host

- For genuinely repository-bootstrap tiny work (e.g. the very first
  commit in a new repo), the commitment block still applies; the
  finishing-branch step may need to skip the PR (since there's no
  base branch to PR against yet) and surface that to the user.
