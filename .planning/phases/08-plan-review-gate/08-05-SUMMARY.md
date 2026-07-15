---
phase: 08-plan-review-gate
plan: 05
subsystem: infra
tags: [gsd, plan-review-gate, migration, idempotency, codex-workflow]

# Dependency graph
requires:
  - phase: 08-plan-review-gate (08-02)
    provides: "check-plan-review.sh verifier (resolver, grandfather guards, REVIEWS strictness, block message)"
  - phase: 08-plan-review-gate (08-04)
    provides: "declarative pre_execution.plan_review binding + ritual section, byte-identical in config-hooks.json / agents-md-additions.md and this repo's own config.codex.json / AGENTS.md / SKILL.md"
provides:
  - "migrations/0008-plan-review-gate.md — steps 1-3 (config leaf-merge, AGENTS.md ritual insert, .codex/workflow-version.txt bump), idempotent, step-local skips only"
  - "test_migration_0008 in migrations/run-tests.sh — leaf-idempotency, sibling-gate-preserving merge/rollback, cksum-based no-op re-run, no-scaffolder-tree fixture (T-08-38 regression guard), partial-application fixture (T-08-39 regression guard)"
  - "this repo's own scaffolder bump to 0.6.0, in lockstep with the migration's to_version, in the same commit"
affects: [08-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Leaf-level jq deep merge for a nested hook group: `.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)` — preserves sibling gates at the leaf, unlike a shallow `.hooks`-level merge which would replace the whole pre_execution object"
    - "Structural rollback: `del(.hooks.pre_execution.plan_review)` then conditionally `del(.hooks.pre_execution)` only when the parent is empty — never an unconditional group delete"
    - "Step-local idempotency with no whole-migration skip predicate — each of the 3 steps checks its own artifact and none gates another, matching the atomicity contract's partial/skip-with-warning recovery path"
    - "Version-floor pre-flight reads the project's own durable record (.codex/workflow-version.txt) instead of a scaffolder-file path that does not exist in any real target project"

key-files:
  created:
    - migrations/0008-plan-review-gate.md
  modified:
    - migrations/run-tests.sh
    - skills/agentic-apps-workflow/SKILL.md
    - .codex/workflow-version.txt

key-decisions:
  - "Migration 0008 ships 3 steps, not 0007's 4 — no step or applies_to entry names a target project's local skills/ tree, since no real install has one (round-2 HIGH, T-08-38). The repo's own scaffolder bump is a direct edit in the GREEN commit, never a migration step."
  - "Config target is .planning/config.codex.json (host-scoped), diverging deliberately from 0007's host-neutral .planning/config.json, because pre_execution is scoped like the other 15 gates rather than shared cross-host like knowledge_capture."
  - "All four cross-AI-review merge-safety corrections landed verbatim: leaf-level idempotency check, leaf-level deep merge, structural (guarded) rollback, and step-local (never whole-migration) skip cases."

requirements-completed:
  - "core spec §02 (plan-review gate) — existing-install upgrade path (steps 1-3 of 4; 08-06 adds the table step)"

# Metrics
duration: ~35min
completed: 2026-07-15
---

# Phase 08 Plan 05: Migration 0008 (config merge + ritual insert + version record) Summary

**Wrote the idempotent existing-install upgrade path for the plan-review gate — a leaf-level config merge, a template-extracted AGENTS.md ritual insert, and a project version bump — with every merge-safety correction cross-AI review demanded, and bumped this repo's own scaffolder to 0.6.0 in the same commit to keep the drift test green.**

## Performance

- **Duration:** ~35 min (read + design + two task commits; excludes this summary)
- **Completed:** 2026-07-15
- **Tasks:** 2
- **Files modified:** 3 modified + 1 created

## Accomplishments

- `test_migration_0008` added to `migrations/run-tests.sh`: covers the leaf-level idempotency check (including the skip-when-a-sibling-exists case that a group-level check would miss), a merge-preservation fixture carrying a sibling `pre_execution` gate (`other_gate`), a different-group gate (`post_phase.spec_review`), and a foreign top-level key, a structural rollback assertion (removes only `plan_review`, drops the parent only when empty), `cksum`-based second-run no-op assertions for all three steps, a **no-scaffolder-tree fixture** (a sandbox shaped like a real target project with no local `skills/` directory — the regression guard for round 2's HIGH, T-08-38), and a **partial-application fixture** proving every skip is step-local (Step 1 applied / Step 2 not → Steps 2 and 3 still run; and the inverse), the regression guard for T-08-39.
- `test_repo_layout` extended with this phase's four new artifacts (`check-plan-review.sh`, `codex-plan-review/SKILL.md`, `migrations/0008-plan-review-gate.md`, `docs/decisions/0009-plan-review-gate.md`).
- `migrations/0008-plan-review-gate.md` written: 3 steps (config leaf-merge, AGENTS.md ritual insert, `.codex/workflow-version.txt` bump), mirroring 0007's document structure (frontmatter, pre-flight, steps with idempotency/pre-condition/apply/rollback, post-checks, skip cases, compatibility, notes, references), with two deliberate, commented divergences from 0007: the pre-flight version floor reads `.codex/workflow-version.txt` instead of a target-project scaffolder file no real install has, and there is no target-project SKILL.md step at all.
- This repo's own scaffolder bumped `0.5.0 -> 0.6.0` (`skills/agentic-apps-workflow/SKILL.md`) and this repo's own `.codex/workflow-version.txt` bumped to `0.6.0`, both as direct edits in the same commit as the migration — satisfying the `run_drift_test` coupling without shipping a migration step that touches anyone else's `skills/` tree. `implements_spec` stays `0.4.0` (D-17).
- Full harness green: **244 PASS / 2 SKIP / 0 FAIL** (`bash migrations/run-tests.sh`). `drift` and `layout` suites both green.

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): test_migration_0008 + no-scaffolder-tree fixture + repo-layout guards** - `beb297b` (test)
2. **Task 2 (GREEN): migration 0008 (steps 1-3) + this repo's scaffolder bump in lockstep** - `98c06f5` (feat)

_This SUMMARY.md is committed next (worktree mode: STATE.md/ROADMAP.md excluded, owned by the orchestrator after merge)._

## Files Created/Modified

- `migrations/0008-plan-review-gate.md` (created) - the migration document, 3 steps
- `migrations/run-tests.sh` (modified) - `test_migration_0008`, dispatcher wiring, `test_repo_layout` extension
- `skills/agentic-apps-workflow/SKILL.md` (modified) - `version: 0.5.0 -> 0.6.0` (direct edit, `implements_spec: 0.4.0` untouched)
- `.codex/workflow-version.txt` (modified) - `0.5.0 -> 0.6.0` (this repo's own project record, direct edit)

## Version state as shipped

- `skills/agentic-apps-workflow/SKILL.md`: `version: 0.6.0`, `implements_spec: 0.4.0` (unchanged, D-17)
- `.codex/workflow-version.txt` (this repo): `0.6.0`
- `migrations/0008-plan-review-gate.md`: `from_version: 0.5.0`, `to_version: 0.6.0`
- Drift test: `SKILL.md` `version` (0.6.0) == latest migration `to_version` (0.6.0) — green

## The jq merge and rollback expressions, as landed

**Idempotency check (leaf):**
```bash
jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null
```

**Apply (leaf-level deep merge):**
```bash
jq --argjson pe "$PE" \
   '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
   .planning/config.codex.json > .planning/config.codex.json.tmp \
  && mv .planning/config.codex.json.tmp .planning/config.codex.json
```

**Rollback (structural, guarded):**
```bash
jq 'del(.hooks.pre_execution.plan_review)
    | if (.hooks.pre_execution // {}) == {} then del(.hooks.pre_execution) else . end' \
   .planning/config.codex.json > .planning/config.codex.json.tmp \
  && mv .planning/config.codex.json.tmp .planning/config.codex.json
```

`$PE` is sourced via `--argjson` from the installed `config-hooks.json` template's `.hooks.pre_execution` object — never a heredoc'd literal.

## The exact ritual heading regex used (for 08-06's table-header discipline)

```
/^## Pre-execution Gate — Plan Review \(spec §02\)/ {f=1}
/^<!-- END: agentic-apps-workflow sections -->/      {f=0}
```
Section heading, verbatim: `## Pre-execution Gate — Plan Review (spec §02)` (confirmed present at `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md:158`).

## Step numbering as written

**1-3**, as this plan's scope requires:
1. Merge `pre_execution.plan_review` into `.planning/config.codex.json`
2. Insert the ritual section into `AGENTS.md`
3. Record `0.6.0` in `.codex/workflow-version.txt`

Plan `08-06` inserts the bindings-table step as Step 3 and renumbers this plan's Step 3 to Step 4, reaching a final 4-step shape. No gap or placeholder was left for it.

## The pre-flight version-floor check, as landed

```bash
grep -qE '^0\.(5|6)\.0$' .codex/workflow-version.txt || {
  INSTALLED=$(cat .codex/workflow-version.txt 2>/dev/null)
  echo "ABORT: project version is $INSTALLED (need 0.5.0)."
  echo "       Apply prior migrations first via \$update-codex-agenticapps-workflow."
  echo "       Supported upgrade floor: 0.5.0 -> 0.6.0."
  exit 3
}
```
Reads the project's own durable record (`.codex/workflow-version.txt`), never a scaffolder-file path — the deliberate divergence from 0007's `grep -qE '^version: 0\.(4|5)\.0$' <scaffolder-file>` form, which aborts with exit 3 on every real target project (T-08-38).

## Decisions Made

See `key-decisions` in frontmatter above. All were locked by `08-CONTEXT.md` (D-01/D-17/D-19), the plan's `<merge_safety>`/`<target_project_surface>` sections (round-2 review corrections), or the plan's own `<plan_split_note>` step-count contract.

## Deviations from Plan

**None affecting scope or behavior.** Two self-correction rounds during Task 1/Task 2 authoring, both caught by re-running this plan's own acceptance-criteria commands before committing:

**1. [Rule 1 - Bug] A multi-line JSON heredoc fixture in `test_migration_0008` placed a bare `}` at column 0, which is the exact end-of-function marker this repo's own acceptance-check idiom (`awk '/^test_migration_0008\(\)/{f=1} f&&/^}/{exit} f'`) scans for — truncating the extracted function body after only ~15 lines and silently hiding every assertion written after it (rollback, Step 2, Step 3, both extra fixtures) from that verification command.**
- **Found during:** Task 1, while running the plan's own acceptance-criteria greps against the freshly-written function before committing (checks for `other_gate` count, leaf-idempotency, rollback mentions, cksum count, etc. all came back near-zero despite the code being present and passing at runtime).
- **Fix:** Collapsed that one JSON fixture to a single line (no pretty-printed multi-line `}`), with a comment explaining why, so the function body is fully visible to the same `awk` extraction the acceptance criteria use.
- **Files modified:** `migrations/run-tests.sh`
- **Verification:** Re-ran the full acceptance-criteria grep battery; all counts came back correct (e.g. `other_gate` count 14, leaf-idempotency present, rollback mentions present, `cksum` count 18).
- **Committed in:** `beb297b` (Task 1, fixed before committing — not a separate commit)

**2. [Rule 1 - Bug] Migration 0008's prose mentioned the literal string `skills/agentic-apps-workflow` outside the `## Notes` divergence record and outside the `$CODEX`-rooted pre-flight checks (5 occurrences: pre-flight comment, the Step 3 "no target-project step" note, the Step 3 direct-edit description, a post-check comment, and the Compatibility drift-coupling note) — violating the plan's acceptance criterion that this string appear ONLY inside `## Notes` or on a `$CODEX`-qualified line.**
- **Found during:** Task 2, while running the plan's own `awk`/`grep` acceptance check for this exact constraint before committing.
- **Fix:** Reworded all 5 occurrences to describe "this repo's own scaffolder trigger skill's SKILL.md" without the literal `skills/agentic-apps-workflow` path prefix, preserving full meaning. A related occurrence of the literal string `hooks += ` (in an explanatory comment about the wrong shallow-merge form) was also reworded to avoid a false match against the plan's `grep -c 'hooks += '` == 0 criterion, and a bare, unguarded prose mention of `del(.hooks.pre_execution)` (explaining why the unconditional form is wrong) was reworded to avoid tripping the plan's structural rollback-guard check.
- **Files modified:** `migrations/0008-plan-review-gate.md`
- **Verification:** Re-ran all affected acceptance-criteria greps; all returned the required counts (0 for the forbidden patterns, correct positive counts for the required ones). Full harness re-run stayed green (244 PASS / 2 SKIP / 0 FAIL).
- **Committed in:** `98c06f5` (Task 2, fixed before committing — not a separate commit)

**Total deviations:** 2 auto-fixed (2 bugs, both Rule 1, both caught and corrected before the affected task's own commit — neither shipped in a broken state).

## Documented discrepancy in the plan's own acceptance-criteria text (not a deviation from the deliverable)

The plan's Skip-cases acceptance check —
`awk '/^## Skip cases/{f=1} /^## /{f=0} f' migrations/0008-plan-review-gate.md` —
is unconditionally empty for **any** input file, regardless of content: the second rule
(`/^## /{f=0}`) also matches the `## Skip cases` heading line itself (since it starts with
`## `), resetting `f` to 0 on the same line it was just set to 1, before any body line is
ever read. Verified: `printf '## Skip cases\n- Step 1 line\n## Next\n' | awk '/^## Skip cases/{f=1} /^## /{f=0} f'` prints nothing, for any input. This differs from the adjacent
`/^## Notes/{f=1} /^## References/{f=0}` idiom used elsewhere in the same criteria list, which
works correctly because its second pattern names a **specific** heading, not a generic `^## `.
Verified the migration document's actual content satisfies the criterion's **intent** using the
correctly-scoped equivalent (`/^## Skip cases/{f=1} /^## Compatibility/{f=0} f`): 0 matches for
"whole migration"/"entire migration", 8 matches for `Step [123]`. Not fixed in the plan file
(out of this task's file list) — flagging here so `08-06` or a future reviewer does not spend
time debugging a "failing" check that is dead by construction.

A second minor discrepancy: the plan's "same commit" criterion
(`git show --stat --name-only HEAD | grep -c '<path>'` returns 1) returns **2** for both
`migrations/0008-plan-review-gate.md` and `skills/agentic-apps-workflow/SKILL.md`, because the
commit message body itself names both paths in prose, and `git show --stat --name-only` includes
the commit message text above the file list. The underlying intent — both files land in exactly
one commit, together — is satisfied; `git diff --diff-filter=D --name-only HEAD~1 HEAD` (no
deletions) and `git show --stat --name-only HEAD` (each path appears exactly once in the actual
file list, ignoring the message body) both confirm this.

## Issues Encountered

`git submodule update --init --recursive` was required before `migrations/run-tests.sh` would run in this worktree (the `vendor/agenticapps-shared` submodule was not checked out) — environment setup, matching the same issue `08-04-SUMMARY.md` recorded, not a plan deviation.

## Deferred Ideas surfaced by this plan's round-2 corrections

Both belong in `08-CONTEXT.md`'s Deferred Ideas and in ADR-0009's follow-ups (neither file is in this plan's `files_modified`, so recorded here for hand-off rather than edited directly):

1. **Migration 0007 aborts in any target project without a local `skills/` tree.** Its `applies_to`, its pre-flight floor grep, and its own Step 3 all name `skills/agentic-apps-workflow/SKILL.md`, which the setup skill never creates in a project. Same class as the two `## [Unreleased]` migration-discovery fixes in `CHANGELOG.md` — and invisible for the same reason: `test_migration_0007` manufactures a synthetic `SKILL.md` at `run-tests.sh:729` (unchanged by this plan) and seds that. Found while planning 0008 (`08-REVIEWS.md` round 2, Codex, HIGH, against this plan). Real defect, different migration, own scope — fixing it means re-testing a shipped upgrade path. 0008 does not replicate it and does not repair it.
2. **`test_migration_0007`'s synthetic-`SKILL.md` fixture hides item 1** and should be replaced by a no-scaffolder-tree fixture of the shape this plan's Task 1 introduces, whenever item 1 is taken up.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Migration 0008 (steps 1-3) is written, idempotent, and green against the full harness; this repo's own scaffolder and drift test are in lockstep at 0.6.0.
- Plan `08-06` inserts the bindings-table step as Step 3, renumbers this plan's Step 3 to Step 4, adds the CHANGELOG entry, and closes ROADMAP success criterion #7. It should read this summary's "ritual heading regex" and "step numbering" sections rather than re-deriving them.
- No GSD prompt (`prompts/`, `get-shit-done/`) was edited; no `hooks.json` was created or edited; nothing under `.planning/phases/0[0-7]/` was touched; `ROADMAP.md`/`STATE.md` were not modified (worktree mode, owned by the orchestrator).
- No blockers for plan `08-06`.

---
*Phase: 08-plan-review-gate*
*Completed: 2026-07-15*

## Self-Check: PASSED

- FOUND: migrations/0008-plan-review-gate.md
- FOUND: migrations/run-tests.sh
- FOUND: skills/agentic-apps-workflow/SKILL.md
- FOUND: .codex/workflow-version.txt
- FOUND: .planning/phases/08-plan-review-gate/08-05-SUMMARY.md
- FOUND commit: beb297b (Task 1, test(RED))
- FOUND commit: 98c06f5 (Task 2, feat(GREEN))
