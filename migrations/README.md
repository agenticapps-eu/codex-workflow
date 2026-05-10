# Migration framework

This directory holds **versioned migrations** that bring an installed
`codex-workflow` from one version to the next. Every change to the
scaffolder that affects projects on disk ships as a new migration
file here.

The contract this directory implements is
[`agenticapps-workflow-core/spec/08-migration-format.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/08-migration-format.md).
This README is the host-side manifestation, with paths translated
to Codex idioms.

The `setup-codex-agenticapps-workflow` and
`update-codex-agenticapps-workflow` skills both consume migrations
from this directory:

- **Setup** applies every migration from `0000-baseline.md` forward
  to the current scaffolder version.
- **Update** applies only **pending** migrations (those with
  `from_version >` the project's installed version).

There is no parallel "setup writes one shape, update writes a
different shape" code path. Both flows route through the same
migration files. See ADR-0013 in core.

---

## File naming

```
NNNN-{kebab-slug}.md
```

- `NNNN` — four-digit sequential ID (`0000`, `0001`, `0002`, …).
  Sequential IDs decouple "I have a new feature" from "what version
  number does that imply" — multiple migrations may fit inside one
  semver release.
- `kebab-slug` — short kebab-case description.
- Always Markdown (`.md`).

`0000-baseline.md` is special: it codifies the starting state of a
fresh project at v0.1.0 — the initial scaffolder version. Every
other migration is incremental.

---

## File format

See `agenticapps-workflow-core/spec/08-migration-format.md` for the
canonical format. The frontmatter shape:

```yaml
---
id: NNNN
slug: kebab-slug
title: Human-readable title
from_version: <semver | "unknown">
to_version: <semver>
applies_to:
  - <project-side path>
  - …
requires:
  - skill: <upstream-skill-name>
    install: "<install command>"
    verify: "<verify command>"
optional_for:
  - tag: <tag>
    detect: "<detect command>"
    note: "…"
---
```

Every step has four mandatory sections:

| Section | Purpose |
|---|---|
| **Idempotency check** | Shell command returning 0 if applied. Update flow skips applied steps without prompting. |
| **Pre-condition** | Shell command that must return 0 before apply. Errors with a specific message if false rather than silently producing wrong output. |
| **Apply** | The exact patch — markdown / JSON / file content / command. |
| **Rollback** | How to revert the step. Either a unique anchor to delete, or `git revert` / `git checkout` instruction, or `manual — see VERIFICATION.md`. |

---

## Idempotency contract

Every step MUST be safely re-runnable. Running the same migration
twice produces: 1 actual apply + 1 "skipped (already applied)" log.

The idempotency check is the contract. Use the appropriate shape:

- **Markdown insertions** — unique anchor string from the new
  content: `grep -q "^## Workflow Enforcement Hooks (MANDATORY)" AGENTS.md`
- **JSON modifications** — unique key path:
  `jq -e '.hooks.pre_phase.design_critique' .planning/config.json >/dev/null`
- **File creation** — file at expected path:
  `test -f templates/adr-db-security-acceptance.md`

A migration without working idempotency checks is non-conformant —
the update flow refuses to apply it twice; the second run errors.

---

## Atomicity contract

If step N fails halfway, the update skill prompts the user with
three options:

1. **Retry** — re-run step N (idempotent steps are safe to re-run)
2. **Skip with warning** — log the skip, continue with step N+1
   (the migration is recorded `partial` in the version-bump record)
3. **Rollback** — apply rollback patches for steps 1..N-1 (using
   each step's `Rollback` clause), restore project to pre-migration
   state

Default: prompt user. The skill never auto-rolls-back without
consent — partial-state recovery may be more useful than full
revert.

---

## Dry-run mode

`update-codex-agenticapps-workflow --dry-run` runs every step's
idempotency check and prints the diff each step would apply,
without writing or committing. This is the default-on-confirm
interactive mode: dry-run the whole chain, show diffs, then ask
"apply now?".

---

## Where the scaffolder lives

Migrations reference the scaffolder repo's own files using:

```
$CODEX_HOME/skills/<scaffolder-skill>/   # default ~/.codex/skills/<scaffolder-skill>/
```

`install.sh` symlinks the scaffolder skills into that path. Migrations
read templates from the scaffolder's `templates/` directory:

```
$CODEX_HOME/skills/setup-codex-agenticapps-workflow/templates/
```

The `setup-codex-agenticapps-workflow` skill carries a `templates/`
symlink to the scaffolder's top-level `templates/` so migration apply
steps can `cp` from a stable path.

---

## Where the installed version lives

Each project records its installed `codex-workflow` version at:

```
.codex/workflow-version.txt
```

A single line containing the semver (e.g. `0.1.0`). The update skill
reads this file via `cat`. Bare projects with no version file are
treated as `from_version=unknown` and routed through
`$setup-codex-agenticapps-workflow` rather than upgraded.

The trigger skill `agentic-apps-workflow` itself ships at the
scaffolder version; it is not pinned per-project. Projects pin the
scaffolder version they installed against; updating the scaffolder
applies pending migrations to bring the project forward.

---

## Test fixtures

`migrations/test-fixtures/` contains a fixture-based test harness
for migrations. See `test-fixtures/README.md` for the contract, and
`migrations/run-tests.sh` for the runner. Every migration that
operates on existing files (i.e. every migration except
`0000-baseline`) ships with a fixture pair (before-state,
expected-after-state) and a runner assertion that the migration
produces the expected end-state.

`0000-baseline.md` does not have a non-interactive test because it
requires user input via the host's question surface; correctness is
validated by running `$setup-codex-agenticapps-workflow` against a
real fresh project.

---

## Adding a new migration

1. Pick the next sequential ID (`ls migrations/[0-9]*.md | tail -1`)
2. Create `NNNN-slug.md` with frontmatter + steps + post-checks per
   the format above
3. Each step ships with idempotency check + rollback
4. Add a fixture pair under `migrations/test-fixtures/` covering the
   before-state and expected-after-state
5. Run `migrations/run-tests.sh NNNN` and confirm green
6. Bump the trigger skill's `version:` frontmatter at
   `skills/agentic-apps-workflow/SKILL.md` to the migration's
   `to_version`
7. Open a PR. Code review must include: dry-run output for the
   migration applied to a real existing project; test runner output
   green
