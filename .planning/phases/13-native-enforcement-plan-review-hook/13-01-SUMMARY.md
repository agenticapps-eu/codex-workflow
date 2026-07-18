---
phase: 13-native-enforcement-plan-review-hook
plan: 01
type: execute
completed: 2026-07-18
requirements: [HOOK-01]
status: complete
---

# 13-01 Summary — Trust-ledger + apply_patch spike

**One-liner:** Froze the four SPIKE-REQUIRED unknowns by direct observation on
codex-cli 0.144.4 — `apply_patch` **is** covered by PreToolUse (payload under
`tool_input.command`), project-scoped `[features] hooks` **is** honored (A1 CONFIRMED),
trust is **two independent gates set by one approval flow**, and the `trusted_hash` input
proved **not black-box reproducible** — a negative result that closes the pre-seeding
question rather than blocking on it.

## What was decided

**Matcher decision (the line 13-02 and 13-03 consume):** 13-03's `hooks.json` entry
carries `"matcher": "apply_patch"`, and 13-02's wrapper needs **no** `Bash`-command-parsing
branch. STEP 7 proved `apply_patch` covers file edits, so RESEARCH.md Open Question 1's
condition for adding the Bash branch was never met.

## Observations by SPIKE item

| Item | Answer |
|---|---|
| 1 — exact `trusted_hash` input | **NOT REPRODUCIBLE black-box** (65 candidates failed) |
| 2 — pre-seeding + one-gate-or-two | Pre-seeding **not viable**; **two gates, one approval flow** |
| 3 — default trust_level | **PROMPT** (not silent either way) |
| 4 — apply_patch coverage | **COVERED**; field is `tool_input.command` |
| A1 — project `[features]` layer | **CONFIRMED** (project `false` beat global `true`) |

## Two findings that change downstream design

1. **An invalid-output hook FAILS OPEN.** codex reports `PreToolUse hook (failed)` and
   **still runs the tool**. HOOK-02's output contract is therefore load-bearing: allow =
   empty stdout / silent `exit 0`; deny = strictly valid `permissionDecision` JSON or a
   clean `exit 2`. Any malformed stdout silently disables the gate.
2. **Gate A alone does not fire a hook.** A newly-installed hook in an already-trusted
   project stays silent until the operator separately trusts the *hook*. 13-05's operator
   step must say "trust the hook", not "trust the repo". Hook trust does not gate tool
   execution — only whether the hook runs.

Also: `[features]` is strictly typed and fail-closed (a non-boolean value is a hard
startup error), so migration 0011 must write `hooks = true` and nothing else.

## Deviations from plan

- **Task 3's sha256 determination did not resolve to a/b/c.** The plan's acceptance
  criterion expected one of three forms to match. None did, nor did 56 further variants
  tested against a fixture with exactly-known bytes. Recorded as an explicit negative
  result rather than a guess. **Non-blocking:** pre-seeding a `trusted_hash` was already
  forbidden by Pitfall 3, so no downstream plan depends on the input — the question is
  closed from both directions.
- **Scratch fixtures were reaped from `/tmp` mid-plan** (between the Task 2 sessions and
  Task 3). Rebuilt with controlled bytes to make the hash determination exact rather than
  reconstructed. Consequence: the earlier fixtures' exact bytes are unrecoverable, so
  whether `trusted_hash` is purely content-derived or additionally salted could not be
  established. Treat it as opaque.
- **Task 1's `~/.codex/hooks.json` byte-identity criterion no longer holds.** Baseline
  `07112ce1…` → now `eb7adec8…`. Content inspection shows zero `gsd-phase13-spike`
  entries — only live vendor hooks (nyx, cmux/termloop, superset, herdr) — and the mtime
  post-dates the spike. Cause is unrelated vendor churn, not contamination. Disclosed
  rather than passed over.
- **Plan resumed mid-flight.** Task 1 and the Task 2 observations were committed across
  three earlier sessions; this run committed the in-flight work, closed A1, and froze
  Task 3. The safe-resume gate caught the missing SUMMARY.md before any re-dispatch.

## Key files

- `13-01-SPIKE-FINDINGS.md` — created; the frozen artifact 13-02/13-03 read

## Carried forward

- **13-02:** parse the patch blob from `tool_input.command`; honor the fail-open output
  contract exactly.
- **13-03:** `matcher: "apply_patch"`; write project-scoped `[features] hooks = true`
  alone; never touch the global config.
- **13-05 pre-flight (unchanged from Task 1):** this repo's trust entry is still keyed to
  the stale `/Users/donald/Sourcecode/codex-workflow` path. The operator must re-trust at
  the current `agenticapps/codex-workflow` path, and must trust the **hook** (Gate B),
  or the block will be misdiagnosed as a hook-install failure.
