# Phase 2 — PLAN: §13 codex-ts-declare-first skill

- Spec: `agenticapps-workflow-core` §13 (SHOULD; names codex-workflow
  explicitly as a TS-targeting host — core CHANGELOG 0.4.0).
- Goal: ship `codex-ts-declare-first` (3 atomic phases + 3 refusals),
  bind it to the `tdd` gate, author additive migration `0002`.
- Model: claude-workflow `ts-declare-first/` (SKILL.md + 3 templates).

## Tasks

1. **Skill** `skills/codex-ts-declare-first/SKILL.md` — frontmatter
   `implements_spec: 0.4.0`, `implements_gate: tdd`. Three ATOMIC commits
   in order (declare → failing tests (RED) → impl (GREEN)); three refusals
   (collapsed-commits, impl-in-declare-file, no-observed-RED) rendered as a
   Mermaid `flowchart` (§12, newly authored); verification-gate integration
   table (the §06 evidence `codex-verification` checks). Codex idioms
   (`$codex-ts-declare-first`, codex-tdd/codex-verification refs).
2. **Three SEPARATE template files** — `example.declare.ts` (declare-only),
   `example.test.ts` (RED contract tests), `example.impl.ts` (impl). Separate
   files structurally enforce the three-commit shape on copy.
3. **Bind** — trigger Step 3 gate table (a `tdd (new TS module)` row);
   `templates/config-hooks.json` (`hooks.per_task.tdd.strengthened_by`).
   install.sh globs `skills/*/` → auto-included (confirm via --dry-run).
4. **.gitignore fix** — narrow `skills/*/templates` to
   `skills/setup-codex-agenticapps-workflow/templates` so the new skill's
   real template files are tracked (the install.sh restructure completes in
   Phase 6).
5. **Migration `0002`** — `from 0.2.0 → 0.2.0` (additive; rides on 0001).
   Per-project effect on Codex: wire the `strengthened_by` binding into
   `.planning/config.json` (skills are global via install.sh, so no
   per-project symlink unlike claude 0015). Pre-flight verifies the skill is
   installed + project ≥ 0.2.0.
6. **Harness** — `test_migration_0002` (idempotency + jq apply/rollback +
   base-binding-intact + 3-separate-templates + declare-only assertions);
   layout + dispatcher updated.

## §12 note

The skill is newly authored at 0.4.0, so its branchy refusal logic ships as
a Mermaid `flowchart` (REPORT terminal + labeled recovery edges) per §12.

## Gates fired

- `codex-verification` (VERIFICATION.md). `codex-tdd`/`codex-ts-declare-first`
  itself is the subject, not applied to author markdown. Two-stage review at
  the Phase 2+4 checkpoint. `codex-cso`/`codex-qa` N/A.

## Out of scope

- implements_spec sweep on config-hooks.json / gate skills → Phase 5.
- Implicit GSD-design-phase trigger wiring → future (noted in skill).
