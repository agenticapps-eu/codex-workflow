---
name: codex-systematic-debugging
version: 0.1.0
implements_spec: 0.1.0
description: |
  Four-phase debugging protocol — Observe → Hypothesize → Test →
  Conclude — that refuses to propose a fix until a discriminating test
  has named the root cause. Use whenever the user reports a bug,
  unexpected behavior, a stack trace, "it worked yesterday", or asks
  to debug / investigate / find the root cause. Auto-invoked by the
  `$gsd-debug` entry-point skill. Produces DEBUG.md with the four
  sections and the named root cause; the fix lands in a separate
  commit referenced from DEBUG.md.
---

# codex-systematic-debugging

This skill is **not** bound to a spec gate. It is the methodology
behind `$gsd-debug` — a four-phase debugging protocol that breaks the
most common LLM debugging failure mode: jumping to a fix before the
root cause is named and tested for.

## When to invoke

User reports a bug, regression, error, stack trace, "it was working
before", "this fails when", "why does this happen". The trigger skill
routes "fix the bug" tasks to `$gsd-debug`, which auto-invokes this
skill.

## What this skill does

Four phases, in order. **Do not skip ahead.** A skipped phase is the
single most common source of "the fix didn't work" outcomes.

### Phase 1 — Observe

Collect what is known. Do NOT propose a fix yet.

- Exact error message, stack trace, log lines (raw, not paraphrased)
- Repro steps that reliably trigger the bug
- Repro steps that reliably don't trigger it (the comparison case)
- The most recent change that could have introduced the regression
  (`git log` — but don't blame yet, this is observation)
- The system's state when the bug occurs (env vars, feature flags,
  user role, network conditions)

Write the observation to `DEBUG.md` under `## 1. Observation`. The
section is descriptive, not analytical.

### Phase 2 — Hypothesize

List candidate root causes. **At least two.** Single-hypothesis
debugging confuses confirmation with discovery.

For each hypothesis:
- What it claims is broken
- Why it would produce the observed behavior
- A discriminating test — a check whose outcome is different per
  hypothesis. "Does the bug repro with X disabled?" is a
  discriminator if the hypotheses disagree on whether it does.
- Likelihood ranking (rough: "very likely", "plausible",
  "long shot")

Write to `DEBUG.md` under `## 2. Hypotheses`.

### Phase 3 — Test

Run the discriminator for each hypothesis, in order from most likely
to least likely. **Each test runs against an unmodified system —
don't fix anything yet.** A discriminator that requires modifying the
system (e.g. "if I patch X, does Y stop happening") IS a test, but it
must be done as a temporary patch that is reverted after the test.

For each test:
- Command run (or action taken)
- Output (raw)
- Outcome — which hypotheses survive? Which are eliminated?

Write to `DEBUG.md` under `## 3. Tests`.

If all hypotheses are eliminated, return to Phase 2 with new
hypotheses informed by the test results. **Do not** revert to
"throw fixes at it until something works."

### Phase 4 — Conclude

State the named root cause. The conclusion MUST be:
- Specific (file:line if applicable; named subsystem otherwise)
- Tested (the surviving hypothesis from Phase 3, with the
  discriminating test cited)
- Distinct from the symptom (the symptom is the bug; the conclusion
  is what causes it)

Write to `DEBUG.md` under `## 4. Conclusion`. Author the fix as a
separate commit; the commit message references DEBUG.md.

## Required evidence (per spec/06 evidence rules)

- `DEBUG.md` exists for the bug
- All four sections are present and non-empty
- At least two hypotheses listed in Phase 2
- At least one discriminating test in Phase 3 with raw output
- Phase 4's named root cause is distinct from the Phase 1 symptom
  and is supported by Phase 3's test
- The fix commit references DEBUG.md (e.g. `fix: <one-liner>; see
  DEBUG.md`)

## Failure modes

- **Jumping to fix.** "I think it's X" without a discriminator is
  guessing. Write the hypothesis, write the discriminator, run it.
- **Single-hypothesis tunnel.** If only one hypothesis is "obvious",
  the search was too shallow. Force a second.
- **Treating the symptom as the root cause.** "The button doesn't
  work" is a symptom; "the click handler is bound to the wrong
  element due to a stale ref" is a root cause.
- **Modifying the system before Phase 3 finishes.** Tests run
  against an unmodified system; modifications are a separate
  conclusion-following action.
- **"This worked an hour ago" without examining the diff.** Phase 1
  observation includes the recent change; Phase 2 hypotheses
  include "the recent change introduced the bug" only if a
  discriminator can confirm it.

## Notes for the Codex host

- The skill body works for any kind of bug — UI, backend, infra.
  Domain-specific debugging tooling (browser devtools for UI,
  `pdb` / `delve` for code, log aggregators for distributed systems)
  fits inside Phase 3 as the discriminating test.
- For long-running systems where the bug doesn't reproduce locally,
  Phase 1 may need to wait on production observability data; record
  the wait explicitly rather than skipping forward.
