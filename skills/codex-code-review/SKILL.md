---
name: codex-code-review
version: 0.1.0
implements_spec: 0.1.0
implements_gate: code-review
description: |
  Stage 2 of the two-stage review: spawn an independent reviewer in a
  fresh `codex exec` child process to audit code quality —
  idiomaticness, naming, obvious bugs, style consistency, and a
  pass / pass-with-followups / block verdict. Use after
  `codex-spec-review` (Stage 1) has produced a clean or
  clean-with-followups outcome; refuses to run if Stage 1 reports
  unresolved gaps. The independent process is the gate's load-bearing
  property — implementer-authored Stage 2 is non-conformant per
  spec/07.
---

# codex-code-review

This skill fulfills the `code-review` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md)
and is bound by [`spec/07-two-stage-review.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/07-two-stage-review.md).
The independence requirement comes from
[ADR-0002](../../docs/decisions/0002-stage2-independent-reviewer-on-codex.md).

## When to invoke

After `codex-spec-review` (Stage 1) has produced a clean or
clean-with-followups outcome. If Stage 1 outcome was `gap`, fix or
accept via ADR first; do not skip ahead to Stage 2.

## What this skill does

1. **Confirm prerequisites.**
   - `REVIEW.md` exists in the phase directory and contains
     `## Stage 1 — Spec compliance` with outcome `clean` or
     `clean-with-followups`.
   - The phase's git history is in a clean state (no unstaged
     changes that would mislead the reviewer).
   - `codex` is on `PATH`. If absent, fall back to a "manual Stage 2
     required" note in REVIEW.md and surface to the user — do NOT
     silently skip the gate.
2. **Build the reviewer prompt.** The prompt MUST contain:
   - The `git diff <phase-base>..HEAD` for the phase
   - A pointer to `PLAN.md` and `CONTEXT.md`
   - The spec citation (`agenticapps-workflow-core` v0.1.0,
     spec/07-two-stage-review.md)
   - Explicit reviewer-mode framing: "You have not seen the
     implementing session's reasoning. You are the independent Stage
     2 reviewer. Produce a Stage 2 — Code quality section enumerating
     code-style consistency, naming concerns, obvious bugs, and a
     pass / pass-with-followups / block verdict. Link each finding
     to file:line."
3. **Run the reviewer.** Spawn:

   ```bash
   codex exec \
     --model "${REVIEWER_MODEL:-${CODEX_MODEL:-gpt-5.4}}" \
     --skip-git-repo-check \
     --sandbox read-only \
     "$(cat /tmp/codex-review-prompt-$$.txt)"
   ```

   The `--sandbox read-only` policy is sufficient — Stage 2 reads
   code, writes only the review document. `REVIEWER_MODEL` overrides
   the model so cross-model review (e.g. running a different model
   family for review than for implementation) is opt-in via env var.
4. **Capture the output.** The child process's stdout is the Stage 2
   review. Append it to REVIEW.md under
   `## Stage 2 — Code quality`. Include the actual `codex exec`
   command at the top of the section as a reproducibility receipt.
5. **Read the verdict.**
   - **pass** — clean to merge
   - **pass-with-followups** — merge OK but log followups in the PR
     description and the phase's NEXT.md (or equivalent)
   - **block** — fix the blocking issues, re-run Stage 1 + Stage 2

## Required evidence (per spec/06)

- `REVIEW.md` contains a top-level heading
  `## Stage 2 — Code quality`
- The section was authored by an independent agent invocation (the
  `codex exec` command appears verbatim at the top of the section)
- At least: code-style consistency notes, naming concerns,
  obvious-bug scan results, and a verdict line
- Findings link to `file:line` where possible

## Failure modes

- **Implementer-authored Stage 2.** Even a freshly re-prompted
  implementer in the same session shares conversation context.
  Non-conformant. The `codex exec` child process must run.
- **Same-model review with no `REVIEWER_MODEL` override.** Permitted
  but flagged in the review section as a known limitation —
  correlated blind spots. For high-stakes phases, override to a
  different model.
- **"We'll catch code-quality issues in PR review."** Non-conformant
  per spec/07 — Stage 2 is the gate; PR review is a separate human
  check that does not substitute.
- **Skipping Stage 2 because Stage 1 found blockers.** Stage 1
  blockers are fixed first, then BOTH stages re-run; Stage 2 is not
  optional.

## Notes for the Codex host

- The reviewer process consumes API budget independently from the
  implementer process. Two sessions in flight share Donald's
  rate-limit pool — surface this when running near a quota.
- `codex exec`'s flag surface is verified at v0.130.0. If a future
  Codex release changes the flag set, the bash invocation in step 3
  needs a one-line update; the gate's choice of mechanism (Option A
  in ADR-0002) does not change.
- Cross-host review via Claude Code MCP is deferred to v0.2.0
  (ADR-0002 Option B); use `REVIEWER_MODEL` env override as the
  documented v0.1.0 path for cross-model review.
