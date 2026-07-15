---
phase: 08-plan-review-gate
plan: 01
subsystem: infra
tags: [bash, gate-verifier, plan-review, spec-02, tdd, migration-harness]

# Dependency graph
requires: []
provides:
  - "skills/agentic-apps-workflow/scripts/check-plan-review.sh — repo-root self-location, D-05 four-step resolver, D-08/D-09 grandfather guards, allow-only (never exits 2)"
  - "migrations/run-tests.sh test_check_plan_review_resolver — 54-assertion resolver + grandfather regression suite, wired under the `check-plan-review` dispatcher filter"
  - "GSD_PLAN_REVIEW_DEBUG=1 debug surface (`repo-root:` / `resolved-phase:` stderr lines) — the assertion contract plan 08-02 also relies on"
affects: [08-02, 08-03, 08-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Tri-state status contract (0=unique/1=absent/2=ambiguous-terminal) for _match_phase_dir, signaled via $? not stdout emptiness"
    - "Portable cd+pwd -P canonicalization (_canon_dir) instead of realpath -m / readlink -f"
    - "Portable GNU/BSD stat dual-branch mtime helper (_mtime), consumed by a process-substitution while-read loop (never a pipe) for NUL-safe determinism"
    - "Section-bounded awk STATE.md parse: flag set on '## Current Position' (or the '## Current Phase' fallback), cleared on the next '##' heading"
    - "_cpr_case / _cpr_case_and_absent test-harness helpers: single pinned invocation shape capturing $? immediately after the subprocess call, with an --err-out out-path argument defaulting to a per-call mktemp"

key-files:
  created:
    - skills/agentic-apps-workflow/scripts/check-plan-review.sh
  modified:
    - migrations/run-tests.sh

key-decisions:
  - "Ported the reference resolver (../claude-workflow multi-ai-review-gate.sh) with three named corrections, not verbatim: D-06 heading fix, D-07 gsd-tools.cjs omission, and a third defect (the reference's line regex cannot match the canonical 'Phase: NN' line because the colon blocks [[:space:]]+) — corrected by anchoring on `^[Pp]hase:?[[:space:]]*[0-9]+`."
  - "Ambiguity in _match_phase_dir is a distinct terminal status (2), never conflated with absent (1) via stdout emptiness — round-2 review's hardening: returning empty for ambiguity let resolution silently fall through to newest-plan-by-mtime and pick one of the ambiguous directories anyway."
  - "Newest-plan-by-mtime tie-breaks lexically (never by find/ls enumeration order) so the result is deterministic and order-independent, not merely 'stable in practice'."
  - "Zero-padding operates on the integer part only (prepend a single '0' to the whole value), which is correct because the integer part is always the leading characters — this avoids a separate substring-splice step."

requirements-completed: ["core spec §02 (plan-review gate) — resolution order + grandfather rule"]

# Metrics
duration: 30min
completed: 2026-07-15
---

# Phase 08 Plan 01: Plan-Review Gate — Resolver + Grandfather Guards Summary

**Repo-root-locating D-05 four-step resolver (pointer → STATE.md → newest-plan-by-mtime → fail-open) with a tri-state ambiguity contract, decimal zero-padding, and all three D-08/D-09 grandfather guards, proven by a 54-case TDD suite — allow paths only, no REVIEWS.md enforcement yet.**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-07-15
- **Tasks:** 2 (RED, GREEN)
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- Built `check-plan-review.sh`, the programmatic half of the D-01 hybrid plan-review pre-execution gate: it locates its own repo root (`git rev-parse --show-toplevel`, then an upward `.planning/` ancestor walk, then fail-open) so a nested-subdirectory invocation reaches the identical verdict as a root invocation (T-08-28, the review finding this plan's `<root_location>` section exists to close).
- Implemented the D-05 four-step resolver with all three named corrections to the reference: D-06 (`## Current Position` heading, `## Current Phase` tolerated fallback), D-07 (no `gsd-tools.cjs` step — 4 steps not 5), and the previously-undocumented third defect (the reference's `[Pp]hase[[:space:]]+[0-9]+` regex cannot match the canonical `Phase: NN` line because the colon blocks `[[:space:]]+`; corrected to `^[Pp]hase:?[[:space:]]*[0-9]+`).
- Implemented the tri-state ambiguity contract in `_match_phase_dir` (0=unique, 1=absent, 2=ambiguous-terminal) exactly as hardened by cross-AI review round 2: an ambiguous match is a TERMINAL fail-open (no later step runs, no phase reported), never inferred from stdout emptiness, with an unconditional stderr diagnostic naming every match.
- Implemented the portable, NUL-safe, deterministic newest-plan-by-mtime step (pinned `_mtime` GNU/BSD dual-branch helper, process-substitution `while read` loop — never a pipe, which would discard the loop's selected value in a subshell — and lexical tie-break for determinism).
- Shipped all three D-08/D-09 grandfather guards (legacy bare-number layout, no-plans-yet, already-shipped via `*-SUMMARY.md`) as named, commented rules.
- Wrote `test_check_plan_review_resolver`, a 54-assertion suite in `migrations/run-tests.sh` covering every item above plus three T-08-01 path-safety escape cases (sibling-dir escape, `/tmp`-rooted escape, `..`-traversal), wired under a new `check-plan-review` dispatcher filter.

## Task Commits

Each task was committed atomically (TDD plan — RED then GREEN):

1. **Task 1 (RED): test_check_plan_review_resolver** — `a948127` (test)
2. **Task 2 (GREEN): check-plan-review.sh** — `7989f85` (feat)

## TDD Gate Compliance

RED gate confirmed: `a948127` (`test(RED): ...`) landed first, with `bash migrations/run-tests.sh check-plan-review` exiting 1 (54 FAIL, 0 PASS) because the verifier did not exist yet.
GREEN gate confirmed: `7989f85` (`feat(GREEN): ...`) landed after, with the same command exiting 0 (54 PASS, 0 FAIL) and the full harness exiting 0 (142 PASS, 2 SKIP, 0 FAIL — up from the pre-existing 88 PASS, 2 SKIP baseline).
No REFACTOR commit was needed; the GREEN implementation required no follow-up cleanup.

## Files Created/Modified

- `skills/agentic-apps-workflow/scripts/check-plan-review.sh` (new, executable, mode 100755) — the verifier: argv parsing (`--file`, ignored here), repo-root self-location, `_canon_dir`/`_is_contained`/`_mtime` portable helpers, `_match_phase_dir` (tri-state contract), `resolve_phase` (four steps), the three grandfather guards, and a marker comment where plan 08-02 inserts the REVIEWS.md check, escape hatches, and block message.
- `migrations/run-tests.sh` (modified) — added `_cpr_case`, `_cpr_check_resolved`, `_cpr_check_contains`, `_cpr_case_and_absent` helpers, `test_check_plan_review_resolver()` (54 assertions), and the `check-plan-review` dispatcher block.

## Decisions Made

- **Root-location mechanism (per `<root_location>`):** `git rev-parse --show-toplevel` (stdout+stderr guarded) first; if empty, walk upward from `$PWD` via `dirname` looking for the nearest ancestor with a `.planning` directory, stopping at `/`; if neither yields a root, fail open with a `GSD_PLAN_REVIEW_DEBUG` diagnostic (`repo-root: <unresolved> (...)`). Once resolved, the script `cd`s there so every subsequent step operates against a known root, not the caller's incidental cwd.
- **Final resolver step list (D-05, 4 steps, not 5 — D-07):** (1) explicit pointer `readlink .planning/current-phase`, tried as absolute then `.planning/`-relative, containment-checked against `.planning/phases` via `_is_contained` (separator-aware prefix test); (2) `.planning/STATE.md`, section-bounded awk parse anchored on the canonical `Phase:` line; (3) newest `*-PLAN.md` by mtime, portable + deterministic; (4) fail-open (return empty → caller exits 0).
- **Exact awk regex shipped for step 2**, including the section-bounding clause:
  ```awk
  /^##[[:space:]]+Current Position/ { in_section=1; next }
  /^##[[:space:]]+Current Phase/    { in_section=1; next }
  /^##/                              { in_section=0 }
  in_section && match($0, /^[Pp]hase:?[[:space:]]*[0-9]+(\.[0-9]+)?/) {
    s = substr($0, RSTART, RLENGTH)
    match(s, /[0-9]+(\.[0-9]+)?/)
    print substr(s, RSTART, RLENGTH)
    exit
  }
  ```
  The flag is set only on the two tolerated headings (`next` skips the generic reset rule on that same line) and cleared on any other `##` heading, so a `Phase:` line in a later section (e.g. `## Notes`) can never win. The value match is anchored at line-start (`^[Pp]hase:?...`), which is what makes it skip free prose like "Last activity: phase 03 shipped" (that line does not start with "Phase") without any additional special-casing.
- **Decimal-padding rule:** zero-pad only when the integer part (`${num%%.*}`) is a single character, by prepending one `"0"` to the *whole* value (`"0${num}"`) — this correctly pads only the integer part because the integer part is always the leading substring, so `8.1 → 08.1`, `8 → 08`, `12.3` and `08.1` are left untouched (their integer part is already 2 digits).
- **`_canon_dir` containment check's shape:** `_is_contained cand root` — exact-equality short-circuit, else a `case "${cand}/" in "${root}/"*)` prefix test (trailing-slash-aware, so `.planning/phases-evil` cannot pass as a child of `.planning/phases`).
- **Deterministic mtime selection's shape:** `find .planning/phases -maxdepth 2 -name '*-PLAN.md' -print0` fed into `while IFS= read -r -d '' cand; do ... done < <(...)` (process substitution, not a pipe, so `best`/`best_mtime` survive outside the loop). Each candidate's mtime comes from the pinned `_mtime` helper (`stat -c %Y || stat -f %m`); a candidate with an empty mtime is skipped, never compared as a string. A strictly newer mtime always wins; an equal mtime only replaces the current best if the candidate's path sorts lexically smaller (`[[ "$cand" < "$best" ]]`) — this converges to the same winner regardless of `find`'s enumeration order, satisfying "the result is stable" as a genuine invariant, not an accident of iteration order.
- **Debug-surface contract:** `GSD_PLAN_REVIEW_DEBUG=1` prints `repo-root: <dir>` immediately after root resolution, and — separately, centrally, after `resolve_phase` returns — `resolved-phase: <dir>` only when `CURRENT_PHASE` is non-empty and a real directory. Neither line is printed on any other path (including terminal-ambiguous fail-opens), which is the load-bearing property the ambiguity regression tests assert. Plan 08-02 must reuse this exact contract rather than re-deriving it.

## Deviations from Plan

None — plan executed exactly as written. All `<resolver_defects>` items (1 through 7) and the third resolver defect noted in `<resolver_defects>` were implemented as specified; no additional bugs, missing functionality, or blocking issues were discovered during execution that required a Rule 1/2/3 deviation.

## Issues Encountered

The `vendor/agenticapps-shared` git submodule was not initialized in this worktree (`migrations/run-tests.sh` sources helpers from it). Ran `git submodule update --init --recursive` before the first test invocation — a one-time environment setup step, not a plan deviation (the submodule pointer itself was already committed and unchanged).

## User Setup Required

None — no external service configuration required.

## Known Stubs

None. `check-plan-review.sh` is fully functional for every allow path this plan scopes; it deliberately never exits 2 (that is plan 08-02's scope, documented inline via the "END OF PLAN 08-01's SCOPE" marker comment, not a stub).

## Threat Flags

None. All new surface (repo-root self-location, the pointer containment check, the tri-state ambiguity contract) is covered by the plan's own `<threat_model>` (T-08-01, T-08-02, T-08-05, T-08-28) — no additional network endpoints, auth paths, or schema changes were introduced beyond what the plan's threat register already accounts for.

## Next Phase Readiness

- `check-plan-review.sh` is ready for plan 08-02 to extend in place: the REVIEWS.md frontmatter check, the `GSD_SKIP_REVIEWS=1` / `multi-ai-review-skipped` escape hatches, and the exit-2 block message land at the marked insertion point, after the grandfather guards and before the final `exit 0`.
- The `GSD_PLAN_REVIEW_DEBUG=1` debug contract (`repo-root:` / `resolved-phase:`) and the `_cpr_case` / `_cpr_case_and_absent` test helpers are established and documented above for 08-02 to reuse without re-deriving.
- No blockers. Note per this plan's own `<verification>` "Gate coverage" section: the live gate does not and cannot meaningfully guard phase 08's own later waves (bootstrap paradox) — that is expected, not a regression, and is not this plan's concern to fix.

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: skills/agentic-apps-workflow/scripts/check-plan-review.sh
- FOUND: migrations/run-tests.sh
- FOUND commit: a948127 (test RED)
- FOUND commit: 7989f85 (feat GREEN)
