---
name: update-codex-agenticapps-workflow
version: 0.1.0
implements_spec: 0.4.0
description: |
  Update an installed codex-workflow project to the current scaffolder
  version by applying pending migrations between the project's
  recorded version and the scaffolder's. Use when the user runs
  "update workflow", "apply pending workflow migrations", "upgrade to
  the new scaffolder version", or after pulling a new release of
  codex-workflow. Reads `.codex/workflow-version.txt`, finds pending
  migrations in `${CODEX_HOME}/skills/update-codex-agenticapps-workflow/migrations/`,
  pre-flights required external skills, applies each step with diff
  preview + per-step confirm, bumps the version on success, commits
  atomically. Supports `--dry-run` for diff-only output.
---

# update-codex-agenticapps-workflow

This skill is the entry point for upgrading an installed codex-workflow
project to a newer scaffolder version. It applies only **pending**
migrations — those whose `from_version >` the project's
recorded version.

## When to invoke

User asks to update the workflow, OR the user has pulled a new
release of `codex-workflow` and wants to bring an existing project
forward. The skill refuses to run on a project that has no
`.codex/workflow-version.txt` and routes to
`$setup-codex-agenticapps-workflow` instead.

## What this skill does

### Stage A — Detect installed version

1. **Read `.codex/workflow-version.txt`.** The single line is the
   project's current scaffolder version (semver).
2. **If the file is missing**, route to
   `$setup-codex-agenticapps-workflow` and stop.
3. **Read the scaffolder version.** Read the trigger skill's
   `version:` frontmatter from
   `${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/SKILL.md`.
   This is the target version.
4. **Compute pending migrations.** List
   `${CODEX_HOME:-$HOME/.codex}/skills/update-codex-agenticapps-workflow/migrations/[0-9]*.md`,
   parse each migration's frontmatter, and select those whose
   `from_version` ≤ project version AND `to_version` > project
   version.
   - If none, log "project is up-to-date at version X" and exit.
   - If any, sort by `id` ascending; this is the apply order.

### Stage B — Pre-flight

5. **For each pending migration**, walk its `requires` field:
   - Run the `verify` command for each required external skill
   - If a required skill is missing, surface the install command
     and ask the user to install it before continuing
6. **Walk `optional_for`** to detect conditional groups; record
   per-tag detection outcomes for use in step apply.

### Stage C — Dry-run

7. **By default, run dry-run first.** For each pending migration:
   - For each step: run idempotency check, print the diff the apply
     block would produce, do not write
   - Aggregate all diffs in a single output the user can review
8. **Ask the user**: "Apply these migrations now?" — yes / no /
   selectively. The `--dry-run` flag short-circuits at this point
   without prompting.

### Stage D — Apply

9. **For each pending migration**, in `id` order:
   - For each step:
     - Idempotency check — skip with log line if applied
     - Pre-condition — fail with specific message if false
     - Apply — write the patch
     - Verify — re-run idempotency check post-apply (must now
       return 0)
   - On step failure: prompt user with retry / skip-with-warning /
     rollback options per the atomicity contract in
     `migrations/README.md`.
   - On migration completion: update `.codex/workflow-version.txt`
     to the migration's `to_version`. This is the durable
     record.

**Recovery — a migration whose pre-flight always aborts.** If a
project is stuck because a pending migration's pre-flight exits
non-zero on every run (for example, migration `0007`'s pre-flight
greps a scaffolder-relative path no real project has, so it always
aborts before writing anything), do not keep re-running it — it is a
known-superseded dead end, not a transient failure.

- **Stuck on `0007`'s abort.** Migration `0007` is superseded by
  migration `0010` for the same `0.4.0 -> 0.5.0` transition. Re-run
  `$update-codex-agenticapps-workflow` — the project's recorded
  version is still `0.4.0`, so `0007` no longer selects and `0010`
  applies instead, delivering `0007`'s intended payload with a
  corrected pre-flight. This terminates: once `0010` completes,
  `.codex/workflow-version.txt` reads `0.5.0` and `0007` is never
  pending again.
- **Manually forced to `0.5.0` to escape the abort.** If
  `.codex/workflow-version.txt` was hand-edited to `0.5.0` to get past
  `0007`'s abort, the project now reads `0.5.0` but is missing
  `0007`'s payload (the `knowledge_capture` config block and the
  AGENTS.md ritual-tail section). Apply `0010` explicitly:
  `$update-codex-agenticapps-workflow --migration 0010`. `0010`'s
  version floor accepts a `0.5.0` project for idempotent re-apply and
  delivers the missing payload without re-touching anything already
  in place.

### Stage E — Atomic commit

10. **Per migration, atomic commit.**

    ```bash
    git add <files-touched-by-this-migration>
    git commit -m "chore: codex-workflow migration NNNN — <slug> (X.Y.Z → X.Y.Z+1)"
    ```

    Per-migration commits make rollback granular: `git revert
    <commit>` reverts one migration cleanly.

11. **Final post-checks.** After all pending migrations applied:
    - `.codex/workflow-version.txt` matches the scaffolder version
    - All migration post-checks (each migration's `## Post-checks`
      block) pass

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Run Stage C (dry-run) and exit; do not write or commit. |
| `--migration NNNN` | Apply only the named migration (skip other pending). Useful for testing one migration in isolation. |
| `--from VERSION` | Override the project version detection (read from `.codex/workflow-version.txt` by default). Useful when the file was lost and the user wants to re-derive. |

## Required evidence (per spec/06)

- `.codex/workflow-version.txt` updated to the new version after
  successful apply
- One git commit per applied migration with the message
  `chore: codex-workflow migration NNNN — <slug> (X.Y.Z → X.Y.Z+1)`
- All migration post-checks pass
- The dry-run output (if produced) is captured to a temp file the
  user can re-inspect

## Failure modes

- **Running on an uninstalled project.** Pre-flight catches this;
  route to setup.
- **Pending migration with missing `requires`.** Surface the install
  command; do not silently skip — the migration may produce broken
  output.
- **Step idempotency check that's wrong.** A migration whose check
  doesn't behave correctly is non-conformant; the second run errors.
  Surface the contradiction; do not paper over it.
- **Auto-rollback without consent.** Forbidden — the atomicity
  contract requires user prompt. Partial-state recovery may be more
  useful than full revert.
- **Skipping the version bump after success.** The version file is
  the durable record; missing the bump leaves the project in an
  inconsistent state where the next update would re-apply the
  migration.

## Notes for the Codex host

- v0.1.0 ships with no incremental migrations beyond `0000-baseline`.
  This skill exits "up-to-date" on every project at v0.1.0 until
  v0.2.0 introduces the first incremental migration.
- The version comparison uses semver. Pre-release suffixes (e.g.
  `0.1.0-rc.1`) compare per semver rules.
- Per-migration commits compose with the project's existing PR
  workflow — the user can run update on a feature branch, get a
  series of migration commits, then PR them.
