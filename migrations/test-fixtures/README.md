# Migration test fixtures

This directory holds the before/after fixture pairs that
`run-tests.sh` uses to verify migration idempotency checks behave
correctly.

## Contract

Every migration that operates on existing project files (i.e.
every migration except `0000-baseline`, which is interactive-only)
ships with a fixture pair:

- **Before-state** — the project's relevant files in the state
  produced by the previous migration's `to_version`. Extracted
  from a git ref pointing to that version.
- **Expected-after-state** — the same files in the state produced
  after the current migration applies. Extracted from a git ref
  on the branch that introduces this migration (typically the
  feature branch's HEAD).

For each step in the migration, `run-tests.sh` asserts:

- The step's idempotency check returns **non-zero** against the
  before-state (meaning: not applied yet, please apply).
- The step's idempotency check returns **zero** against the
  expected-after-state (meaning: already applied, skip).

This double-sided assertion catches:

- A check that's too permissive (matches the before-state, i.e.
  would skip a step that hasn't actually been applied).
- A check that's too strict (doesn't match the after-state, i.e.
  would re-apply a step that has been applied).

## Fixture sources

The harness extracts fixtures from git refs rather than checking
in static fixture files:

```bash
# Before-state: extract from the merge-base of HEAD and main
before_ref="$(git merge-base HEAD origin/main)"
# After-state: extract from HEAD (the migration's own branch)
after_ref="HEAD"
```

This approach has two benefits:

1. Fixtures stay in sync with templates automatically — when the
   templates change, the fixtures derived from them change.
2. No fixture-file maintenance — no copy-paste between
   `templates/*` and `test-fixtures/*`.

## Adding a new migration's fixture pair

1. Author the migration file (`migrations/NNNN-slug.md`) on a
   feature branch.
2. Update the templates (`templates/*`) to reflect the
   `to_version` state.
3. Add a `test_migration_NNNN` function to `run-tests.sh` that
   extracts the relevant template files into temp dirs at the
   `before_ref` and `after_ref`, then asserts each step's
   idempotency check.
4. Run `migrations/run-tests.sh NNNN` and confirm green.

## Why no static fixture files

Some migration frameworks check in static `before/` and `after/`
directories with copies of the relevant files. We don't, because
those copies drift from the templates (the source of truth) and
the drift is only caught when the test runs — at which point you
have to choose between updating the test or updating the template.
Extracting from git refs makes templates the single source of
truth.

## Limits

- Fixtures cannot capture state that lives outside the repo
  (e.g. `~/.codex/skills/`). For migrations that touch global
  state, the test harness falls back to a synthesized fixture
  (constructed at test time) or a SKIP with a documented
  manual-validation path.
- Fixtures cannot capture interactive input. `0000-baseline`
  requires user-question responses for placeholder substitution
  and is therefore SKIPped non-interactively; validation runs via
  a real `$setup-codex-agenticapps-workflow` invocation against a
  fresh test project.
