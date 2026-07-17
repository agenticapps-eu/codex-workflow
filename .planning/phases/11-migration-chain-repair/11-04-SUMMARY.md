---
phase: 11-migration-chain-repair
plan: 04
subsystem: docs
tags: [migrations, skill-spec, recovery-runbook]
requires: []
provides:
  - "SKILL.md Stage D recovery runbook consistent with Stage A's real selection algorithm"
  - "--migration NNNN flag documented boundary-override semantics"
affects:
  - "skills/update-codex-agenticapps-workflow/SKILL.md"
tech-stack:
  added: []
  patterns:
    - "Documentation-as-executable-spec: SKILL.md IS the apply behavior (no separate migration runner), so prose must be literally true against its own algorithm, not merely plausible"
key-files:
  created: []
  modified:
    - "skills/update-codex-agenticapps-workflow/SKILL.md"
decisions:
  - "Fix family: make the runbook honest (rewrite prose), NOT invent a Stage A supersession rule — a same-to_version supersession clause would be unsafe because migrations 0002/0003 legitimately share from_version==to_version==0.2.0 as additive co-residents; per 11-CONTEXT.md D-02 the manual-escape operator is handled by documentation, not code"
  - "Both stuck-operator states (still at 0.4.0; hand-forced to 0.5.0) resolve to the identical recovery command \`--migration 0010\`, differentiated only by why a bare re-run fails each one"
metrics:
  duration: "~15 min"
  completed: "2026-07-17"
---

# Phase 11 Plan 04: Fix Stage D recovery runbook consistency Summary

Rewrote `update-codex-agenticapps-workflow/SKILL.md`'s Stage D recovery bullets and the `--migration NNNN` flag definition so the "non-looping recovery path" claim is actually true against Stage A step 4's documented pending-migration-selection algorithm (which has no supersession rule), closing the SC#3/MIGR-11 blocker confirmed by 11-VERIFICATION.md.

## What Changed

**Task 1 — `--migration NNNN` flag definition (Flags table row).**
The old text ("Apply only the named migration (skip other pending). Useful for testing one migration in isolation.") read as a filter over an already-computed Stage A pending set. It was silently insufficient for the second recovery bullet: a project hand-forced to `0.5.0` never has `0010` in its pending set (Stage A's `to_version > project_version` boundary excludes `to_version == 0.5.0`), so the flag as previously documented could not deliver the promised recovery.

New row text documents three things explicitly:
1. It applies ONLY the named migration, skipping every other migration whether or not it is pending.
2. It OVERRIDES Stage A step 4's computation — bypassing the `to_version > project_version` boundary so it also matches `to_version == project_version` (idempotent re-apply).
3. Why: apply a corrected replacement for a permanently-aborting migration, or re-deliver a migration's payload to a project already at its `to_version`.

**Task 2 — Stage D recovery bullets (rewrite, not new section).**
Removed the false claim "0007 no longer selects and 0010 applies instead" (there is no supersession rule in Stage A, migrations/README.md, or any migration frontmatter — 0007 and 0010 both carry `from_version: 0.4.0` / `to_version: 0.5.0`). Rewrote both bullets to describe Stage A's actual mechanics:

- **Stuck on 0007's abort (still at 0.4.0):** Stage A computes both 0007 and 0010 as pending, sorts by id ascending, tries 0007 first, and it aborts every time — a plain re-run does NOT skip to 0010. Recovery: `$update-codex-agenticapps-workflow --migration 0010`, which applies only 0010 and terminates at `.codex/workflow-version.txt == 0.5.0`.
- **Hand-forced to 0.5.0:** Stage A's pending formula never selects 0010 here (`to_version 0.5.0` is not `> 0.5.0`), so a plain update reports "up-to-date" and silently delivers nothing. Recovery is the SAME command, `--migration 0010`, which — per the amended flag definition — bypasses the boundary and re-applies 0010 idempotently, delivering the missing `knowledge_capture` config block and AGENTS.md ritual-tail section.

Also removed the intro's residual "known-superseded dead end" framing (which implicitly asserted an algorithmic supersession Stage A does not implement) and replaced it with a cross-reference to the `--migration NNNN` flag row as the actual mechanism the recovery depends on.

Stage A step 4 (SKILL.md ~45-51) was left completely unchanged — no supersession clause was added, per the plan's rejected-alternative rationale (11-CONTEXT.md D-02, and the 0002/0003 same-to_version co-resident hazard).

## Verification

Both tasks' automated `<verify>` checks were run and passed before each commit:

- Task 1: flag row matches boundary-override semantics (`to_version`/`bypass`/`already at`/`re-apply`/`re-deliver`) AND Stage A section (grep between `### Stage A` and `### Stage B`) contains no `supersede`/`superseded`/`same to_version` clause.
- Task 2: no `0007 no longer selects` / `0010 applies instead` / `applies instead` phrasing survives anywhere in the file; `--migration 0010` appears at least twice (once per recovery bullet — confirmed 3 occurrences).

Additional manual checks:
- No code fences (` ``` `) introduced in the Stage D recovery block.
- Only `skills/update-codex-agenticapps-workflow/SKILL.md` was modified across both commits (`git status --short` confirms no other files touched).
- Full Stage D section re-read after both edits: the two recovery bullets, the flag's amended definition, and Stage A step 4's unchanged text are mutually consistent — a reader following either bullet verbatim reaches `--migration 0010`, and the flag definition explains why that command works in both cases.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance criteria were met without needing any Rule 1-4 auto-fixes.

## Self-Check

- FOUND: `skills/update-codex-agenticapps-workflow/SKILL.md` (modified, exists)
- FOUND: commit `9dd4120` (Task 1 — flag definition amendment)
- FOUND: commit `c7c51d5` (Task 2 — recovery bullets rewrite)

## Self-Check: PASSED
