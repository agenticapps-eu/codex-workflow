---
name: codex-verification
version: 0.1.0
implements_spec: 0.4.0
implements_gate: verification
description: |
  Refuse to mark a task complete until each `must_have` row in the
  phase's VERIFICATION.md has at least one piece of permitted-shape
  on-disk evidence (test output, grep result, curl response,
  screenshot path, file existence, or diff snippet). Use immediately
  before any task transitions to "complete" — including after every
  successful change in tiny tasks. The skill's job is to break the
  most common LLM failure mode: claiming "done" without producing
  evidence.
---

# codex-verification

This skill fulfills the `verification` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md)
and binds the evidence contract from
[`spec/06-evidence-rules.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/06-evidence-rules.md).

## When to invoke

Before any task transitions to a "complete" state. On Codex this
means before the agent emits a "task done" signal, marks the task
finished in the project's task tracker, or proceeds to the next task
in a queue. The skill ALSO fires before the phase as a whole closes —
the verification gate aggregates per-task evidence into the phase
verification document.

## What this skill does

1. **Read VERIFICATION.md.** Every must_have row is the contract; if
   the file is missing, the task is not yet specified well enough to
   complete — escalate.
2. **For each must_have row, collect evidence.** Use one of the six
   permitted shapes from spec/06:
   - **Test output** — command run + test names + RED/GREEN status; for
     TDD tasks both commit hashes
   - **Grep result** — grep command (with file scope) + matching lines
     with line numbers
   - **Curl response** — full curl command (URL, method, headers minus
     secrets) + HTTP status + relevant body fields
   - **Screenshot path** — file path + browser used + URL navigated to
     + one-line description
   - **File existence** — `test -f` / `ls` output proving artifact
   - **Diff snippet** — `git diff` output showing the asserted code
     change with file paths and line numbers
3. **Write the Evidence subrow inline.** Every must_have row gets at
   least one Evidence subrow directly underneath. Each Evidence subrow
   names its shape and contains the literal command output (or path)
   — not a paraphrase, not a summary, not a "verified" claim.
4. **Refuse completion if any must_have has zero Evidence rows.**
   This is the load-bearing function of the gate. The skill MUST NOT
   accept "implicit verification," "covered by tests," or "see commit
   message" without an Evidence subrow naming the specific shape.

## Required evidence (per spec/06)

- The phase's `VERIFICATION.md` (or host-equivalent) contains every
  must_have for the phase.
- Each must_have row has at least one Evidence subrow.
- Each Evidence subrow conforms to one of the six permitted shapes
  with the required content fields.
- A single artifact MAY satisfy multiple must_haves only if it
  genuinely demonstrates each must_have independently (e.g. a single
  screenshot showing two distinct UI states).

## Forbidden patterns (refuse these)

The following are non-conformant when used as the *sole* evidence for
a must_have. The skill MUST refuse to mark complete on:

- "Manually verified."
- "Tested locally."
- "Should work."
- "Looks good."
- "Trust me." / "I checked."
- An assertion of completion with no evidence shape at all.
- "Tests will be added later." (for TDD-marked tasks)
- "Verification skipped because the task was trivial."
- "Verification deferred to phase review."

## Failure modes

- "Trivial task → trivial evidence" is correct; "trivial task → zero
  evidence" is non-conformant. A one-line typo fix gets a one-line
  grep result showing the new spelling.
- A single "all verified" assertion at the bottom of the document
  collapses 1:1 evidence-to-must_have correspondence and is
  non-conformant.
- "Verification deferred to phase review" confuses per-task
  verification with the post-phase review gate. Both fire; neither
  substitutes for the other.

## Notes for the Codex host

The trigger skill's Verification Check section provides bash snippets
that re-run this skill's checks against on-disk artifacts. Use them
for batch audit (e.g. before opening a PR) — but real-time per-task
verification still runs through this skill, not the bash snippets.
