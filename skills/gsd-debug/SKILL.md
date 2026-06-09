---
name: gsd-debug
version: 0.1.0
implements_spec: 0.4.0
description: |
  GSD entry point for bugs, regressions, errors, and unexpected
  behavior. Auto-invokes `codex-systematic-debugging` (the four-phase
  Observe → Hypothesize → Test → Conclude protocol) and refuses to
  propose a fix until a discriminating test has named the root cause.
  Use whenever the user reports "this is broken", "this fails when",
  "why does X happen", "it was working yesterday", or asks to debug /
  investigate / find the root cause. Typed by the user as
  `$gsd-debug "<bug description>"`. Explicit-only
  (`policy.allow_implicit_invocation: false`).
---

# gsd-debug

This skill is a thin entry-point that hands off to
`codex-systematic-debugging`. Its only job is to be the user-typed
shortcut so debugging starts in the right protocol from the first
keystroke.

## When to invoke

User types `$gsd-debug "<bug description>"`. The trigger skill's
Step 2 routing also points "fix the bug" tasks here.

## What this skill does

1. **Emit the commitment-ritual block** with task size = `small` (or
   `medium` if the bug surface is broad). Skill list:
   `codex-systematic-debugging` → `codex-verification` →
   `codex-finishing-branch`.
2. **Hand off to `codex-systematic-debugging`.** That skill runs the
   four phases — Observe (collect symptoms, exact repro, system
   state), Hypothesize (≥2 candidate root causes + a discriminator
   for each), Test (run discriminators, eliminate hypotheses), and
   Conclude (name the root cause, fix, verify).
3. **After the fix lands**, invoke `codex-verification` to confirm
   the test that pinned the bug now passes (and no other tests
   regressed).
4. **Branch close.** `codex-finishing-branch` composes a PR
   description that links DEBUG.md and the fix commit. The PR body
   names the bug, the root cause, and the verification.

## Output

- `DEBUG.md` (from `codex-systematic-debugging`) with all four
  protocol sections
- The fix commit, with `fix: <one-liner>; see DEBUG.md` in the
  message body
- A regression test that pins the bug
- An opened PR linking DEBUG.md, the fix, and the regression test

## Failure modes

- **Bypassing the four-phase protocol.** "I think it's X, let me
  just patch it" is exactly the failure mode the protocol exists to
  break. `codex-systematic-debugging` refuses to propose a fix
  before a discriminating test has named the cause.
- **Missing regression test.** Every bugfix gets a regression test
  that would have caught the bug had it existed. The test pins the
  fix in place — without it, the fix can regress silently.
- **Symptom-named root cause.** "The button doesn't work" is a
  symptom; "the click handler is bound to the wrong element due to
  a stale ref" is a root cause. The conclusion section in DEBUG.md
  names the latter.

## Notes for the Codex host

- The four-phase protocol's phase 3 (Test) often requires running
  the project's test suite or browser tooling. Surface escalation
  for the relevant sandbox permissions — debug-time is exactly when
  shortcutting to "trust the model" goes wrong.
- For bugs that don't reproduce locally (production-only,
  intermittent), Phase 1 (Observe) may need to wait on
  observability data; record the wait explicitly in DEBUG.md rather
  than skipping ahead to a hypothesis.
