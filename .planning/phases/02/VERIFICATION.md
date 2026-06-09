# Phase 2 — VERIFICATION: §13 codex-ts-declare-first

All must-haves verified on-disk (run 2026-06-09). Full suite:
`bash migrations/run-tests.sh` → **PASS: 31, FAIL: 0, SKIP: 1**.

## must_have: skill loads with the §13 contract

- **Evidence:** `grep '^name:'` → `codex-ts-declare-first`;
  `grep '^implements_spec:'` → `0.4.0`; `grep '^implements_gate:'` → `tdd`;
  `description` present. SKILL.md documents the three ATOMIC phases in order
  and the three refusals.

## must_have: three SEPARATE phase templates ship

- **Evidence:** `ls skills/codex-ts-declare-first/templates/` →
  `example.declare.ts`, `example.test.ts`, `example.impl.ts` (3 files).
  `run-tests.sh`: "three separate phase templates ship with the skill" PASS;
  "declare template is declare-only (no impl bodies)" PASS.

## must_have: bound to the tdd gate

- **Evidence:** trigger SKILL.md Step 3 has a `tdd (new TS module) →
  codex-ts-declare-first` row (`grep` PASS); `templates/config-hooks.json`
  `.hooks.per_task.tdd.strengthened_by.skill == "codex-ts-declare-first"`
  (`jq -e` PASS), base `.hooks.per_task.tdd.skill == "codex-tdd"` intact.

## must_have: installs via the scaffolder

- **Evidence:** `bash install.sh --dry-run` →
  `LINK codex-ts-declare-first -> .../skills/codex-ts-declare-first`.
  Templates tracked (not gitignored): `git check-ignore` returns non-match
  after narrowing the ignore rule.

## must_have: migration 0002 additive, contiguous, testable

- **Evidence:** `migrations/0002-add-ts-declare-first-skill.md`
  `from_version: 0.2.0` / `to_version: 0.2.0` (additive); chain `0000→0001→0002`
  contiguous; `test_migration_0002` PASSes idempotency + jq apply/rollback +
  base-binding-intact.

## must_have: drift stays green

- **Evidence:** `run-tests.sh`: "SKILL.md version=0.2.0 ==
  0002-add-ts-declare-first-skill.md to_version=0.2.0" PASS (latest migration
  is now 0002; version unchanged because 0002 is additive).

## must_have: §12 — newly-authored branchy logic is a flowchart

- **Evidence:** the Refusals section of the skill is a ```mermaid```
  `flowchart` with labeled recovery edges and a REPORT terminal; judgment
  ("no-observed-RED" investigation) stays in prose below the diagram.
