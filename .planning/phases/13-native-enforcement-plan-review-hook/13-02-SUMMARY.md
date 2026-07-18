---
phase: 13-native-enforcement-plan-review-hook
plan: 02
subsystem: infra
tags: [codex-cli, hooks, bash, jq, mutation-testing, PreToolUse]

# Dependency graph
requires:
  - phase: 13-native-enforcement-plan-review-hook (plan 01)
    provides: "Frozen spike findings — Matcher decision (apply_patch, no Bash arm), tool_input.command field name, fail-open-on-invalid-stdout contract"
provides:
  - "skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh — thin PreToolUse adapter execing check-plan-review.sh unchanged"
  - "test_hook_wrapper_stderr_contract in migrations/run-tests.sh — mutation-proven fail-CLOSED stderr contract (SC#3)"
affects: [13-03 (migration 0011, installs this wrapper via hooks.json), 13-04, 13-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PreToolUse wrapper pattern: read stdin once, jq-only field extraction, exec the unchanged gate script, translate {0,2} exit contract to codex-cli's permissionDecision JSON shape"
    - "Mutation test via grep-located marker + portable sed pipe-to-new-file (never sed -i, never a hardcoded line number)"

key-files:
  created:
    - skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh
  modified:
    - migrations/run-tests.sh

key-decisions:
  - "No Bash-command-parsing branch in the wrapper — 13-01 spike's Matcher decision confirmed apply_patch IS covered by PreToolUse on codex-cli 0.144.4, so the Bash arm would be speculative dead code (RESEARCH.md Open Question 1)."
  - "Fallback exit-2 branch's stderr write is marked with a grep-locatable comment (FALLBACK-STDERR-MARKER) rather than relying on a hardcoded line number, so the mutation test in Task 2 stays valid as the wrapper grows."
  - "Deny path always exits 0 (block expressed via permissionDecision:deny JSON on stdout), never both a non-zero exit and stdout JSON simultaneously — matches RESEARCH.md's inferred mutual-exclusion design."

patterns-established:
  - "Wrapper-as-thin-adapter: all gate verdict logic (phase resolution, REVIEWS.md evidence, WR-03 path containment) stays in check-plan-review.sh; the wrapper only translates protocol shapes."
  - "GREEN/RED mutation test pairs for fail-closed contracts: assert the real implementation passes, then assert a targeted mutation is independently detectable as the failure mode being defended against."

requirements-completed: [HOOK-02]

# Metrics
duration: ~25min
completed: 2026-07-18
---

# Phase 13 Plan 02: PreToolUse Wrapper Adapter Summary

**New `hook-wrapper-plan-review.sh` adapts codex-cli's PreToolUse stdin/exit-code surface to the unchanged `check-plan-review.sh` gate, with its exit-2 fallback's fail-CLOSED stderr contract proven by a GREEN/RED mutation test in `migrations/run-tests.sh`.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-18
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- Authored `skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh`: reads PreToolUse stdin JSON once, derives `--file` only via the spike-confirmed `apply_patch` / `tool_input.command` path (no Bash arm — not needed per the frozen Matcher decision), execs `check-plan-review.sh` unchanged, and translates its `{0,2}` exit contract into codex-cli's `permissionDecision:"deny"` JSON shape (primary path) with a guaranteed-non-empty-stderr `exit 2` fallback.
- Added `test_hook_wrapper_stderr_contract` to `migrations/run-tests.sh`, mutation-proving SC#3: the real wrapper's fallback exits 2 with non-empty stderr (GREEN); a mutated copy with the fallback's `>&2` write neutralized (via a grep-located marker, not a hardcoded line number) exits 2 with EMPTY stderr, confirming the RED (fail-open) state is detectable.
- Verified manually: ALLOW path (silent exit 0, empty stdout), DENY primary path (valid `permissionDecision` JSON, exit 0), and FALLBACK path (exit 2, non-empty stderr) all behave per the plan's acceptance criteria.
- Full test suite: 408 PASS, 2 SKIP, 0 FAIL (`bash migrations/run-tests.sh`, exit 0).

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the PreToolUse wrapper adapter (matcher/parse per spike findings)** - `ba6db23` (feat)
2. **Task 2: Mutation-prove the fail-CLOSED stderr contract (SC#3)** - `69031d9` (test)

_Note: Task 2 is a single-commit TDD task — the mutation test itself asserts both the RED (fail-open, via a mutated copy of the wrapper) and GREEN (fail-closed, real wrapper) states in one run, rather than separate RED-commit/GREEN-commit history, since both directions are runtime assertions within the same test function, not a sequential implement-then-test cycle._

## Files Created/Modified
- `skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh` - New PreToolUse adapter: stdin JSON parsing (jq-only), apply_patch `--file` derivation, exec of the unchanged gate, exit-code/JSON translation, executable (`chmod +x`)
- `migrations/run-tests.sh` - Added `test_hook_wrapper_stderr_contract` (definition + dispatcher registration under filter `hook-wrapper-plan-review`)

## Decisions Made
- Followed the plan's exact wrapper shape (matching `13-RESEARCH.md`'s "DOC-RESOLVED: Wrapper Script Design (HOOK-02)" recommended snippet) with the spike's confirmed field name (`tool_input.command`) substituted for the `<FIELD_TBD>` placeholder.
- Omitted the speculative `Bash` matcher arm entirely per the frozen spike's Matcher decision, rather than leaving dead code in place "just in case."
- Used `jq -n --arg` for constructing the deny JSON (not hand-escaped string interpolation) to guarantee valid JSON even if the captured reason contains quotes or newlines — this is load-bearing given codex-cli's confirmed fail-open-on-invalid-stdout behavior.

## Deviations from Plan

None — plan executed exactly as written. The wrapper's shape, the spike-derived field name, the marker-based mutation test design, and the dispatcher registration all follow the plan's `<action>` and `<read_first>` guidance directly.

## Issues Encountered
- `vendor/agenticapps-shared` git submodule was not initialized in this worktree (needed by `migrations/run-tests.sh` for shared helpers). Ran `git submodule update --init --recursive` to make the test harness runnable — this is a pre-existing repo setup step, not a code change, and nothing was committed for it (the submodule pointer was already correct in the tree; only the local checkout was populated).

## User Setup Required

None - no external service configuration required. (This plan does not install the hook into any `hooks.json` — that is 13-03's scope.)

## Next Phase Readiness
- The wrapper script exists, is executable, and its fail-closed contract is mutation-tested — 13-03 (migration 0011) can now reference this file's stable path (`skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh`, shipped via `install.sh`'s symlink of the whole `skills/agentic-apps-workflow/` tree) when constructing the `hooks.json` `command` string.
- No blockers. The wrapper's `--file` derivation was verified against a manually-crafted `apply_patch` stdin payload; 13-03/13-05's live SC#2 session is still the first real end-to-end validation against actual codex-cli tool-call traffic.

---
*Phase: 13-native-enforcement-plan-review-hook*
*Completed: 2026-07-18*
