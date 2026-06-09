# Phase 1 — VERIFICATION: §11 Coding Discipline

All must-haves verified with on-disk evidence (run 2026-06-09).

## must_have: §11 canonical block appears verbatim in AGENTS.md

- **Evidence:** `grep -c '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md`
  → `1`; `grep -cE '^### [1-4]\. ' AGENTS.md` → `4/4`.
- **Evidence (byte-identity):** the injected block, extracted from
  `## Coding Discipline` through `...every diff.`, `diff`s clean against
  `templates/spec-mirrors/11-coding-discipline-0.4.0.md`
  (`run-tests.sh`: "injected §11 block is byte-identical to the mirror" PASS).

## must_have: mirror is byte-identical to the core spec canonical block

- **Evidence:** `diff <(sed -n '27,101p' core/spec/11-coding-discipline.md)
  templates/spec-mirrors/11-coding-discipline-0.4.0.md` → empty
  (`run-tests.sh`: "mirror == core spec §11 canonical block (verbatim)" PASS).

## must_have: provenance anchor present, near the top

- **Evidence:** `grep -B1 '^## Coding Discipline'` shows
  `<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->` immediately
  above the heading; the block is the first managed section (before
  `## Development Workflow`).

## must_have: migration 0001 authored, contiguous, testable

- **Evidence:** `migrations/0001-inject-spec-11-coding-discipline.md` exists;
  `from_version: 0.1.0` / `to_version: 0.2.0`; conflict pre-flight refuses
  the unmanaged-heading case (`run-tests.sh`: "conflict pre-flight detects
  unmanaged §11 prose" PASS); idempotency on provenance anchor (two PASSes).

## must_have: conformance claim bumped exactly once, coupled

- **Evidence:** `grep '^version:' SKILL.md` → `0.2.0`;
  `grep '^implements_spec:' SKILL.md` → `0.4.0`; both moved together in
  migration 0001 Step 2.

## must_have: drift test green

- **Evidence:** `run-tests.sh`: "SKILL.md version=0.2.0 ==
  0001-inject-spec-11-coding-discipline.md to_version=0.2.0" PASS.

## Full suite

- **Evidence:** `bash migrations/run-tests.sh` → **PASS: 20, FAIL: 0,
  SKIP: 1** (0000 interactive-only).
