---
name: setup-codex-agenticapps-workflow
version: 0.1.0
implements_spec: 0.1.0
description: |
  Bootstrap a fresh project with the codex-workflow scaffolding —
  apply the baseline migration to install the trigger skill's
  required project-side artifacts (AGENTS.md sections, .planning/config.json,
  .codex/workflow-config.md, docs/decisions/, .codex/workflow-version.txt).
  Use when a project is freshly cloned or initialized and the user
  asks to "set up the workflow", "add agenticapps workflow", "enable
  codex-workflow", "install the discipline layer", "scaffold this
  project", or anything else that means "I want this project to use
  codex-workflow from this point forward". Idempotent — refuses to
  re-run on a project that already has `.codex/workflow-version.txt`
  and routes to `$update-codex-agenticapps-workflow` instead.
---

# setup-codex-agenticapps-workflow

This skill is the entry point for bootstrapping a fresh project with
the codex-workflow scaffolding. It applies the baseline migration
(`migrations/0000-baseline.md`) and any additional migrations that
have shipped between scaffolder versions, leaving the project at the
current scaffolder version.

## When to invoke

User asks to set up the workflow on a project that does not yet have
a `.codex/workflow-version.txt` file. The trigger skill's
`agentic-apps-workflow` does NOT auto-route to setup — setup is an
explicit, user-driven act because it modifies project-side files
(AGENTS.md, .planning/config.json, .codex/) that the user expects to
review.

## What this skill does

### Stage A — Pre-flight

1. **Verify Codex CLI.** `codex --version` must succeed.
2. **Verify scaffolder install.** Confirm
   `${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/SKILL.md`
   exists. If not, instruct the user to clone codex-workflow and run
   `bash install.sh` from its root before retrying.
3. **Verify project state.**
   - Project must be a git repo (`test -d .git`).
   - Project must NOT already have `.codex/workflow-version.txt`. If
     it does, route the user to `$update-codex-agenticapps-workflow`
     and stop.
4. **Check optional gates.** Run the `optional_for` detection
   commands from `0000-baseline.md` and record the user's choice for
   each (e.g. Option A vs Option B install).

### Stage B — Gather placeholder values

5. **Ask the user** the questions in `0000-baseline.md` Step 1's
   placeholder table:
   - Project name
   - Repo URL (autofilled from `git remote get-url origin` if
     available; otherwise prompt)
   - Client (internal / external name)
   - Budget tier (free / paid / enterprise)
   - Backend language (Go / Python / TypeScript / Rust / Other)
   - Frontend stack (or "none" if backend-only)
   - Database (or "none")
   - LLM provider (anthropic / openai / google / other / none)

   For optional values, accept defaults if the user says "default" or
   skips:
   - design-critique quality bar (default 90)
   - impeccable-audit quality bar (default 90)
   - QA viewports (default 1280, 390)
   - DB blocking severity (default Critical, High)

### Stage C — Apply the baseline migration

6. **Walk `migrations/0000-baseline.md` step by step.** For each
   step:
   - Run the **idempotency check**. If it returns 0, log "skipped
     (already applied)" and continue.
   - Run the **pre-condition**. If it fails, error out with the
     pre-condition's specific message.
   - Show the user the **apply** block. In default-on-confirm
     interactive mode, dry-run the whole chain first; in
     `--no-confirm` mode, apply each step automatically.
   - Apply the patch. For Step 1 (workflow-config.md), substitute
     placeholders with the values from Stage B.
   - On failure: prompt the user with retry / skip-with-warning /
     rollback options per the atomicity contract in
     `migrations/README.md`.
7. **Skip Step 6** (global AGENTS.md additions) if the user picked
   Option B (per-project install) in Stage A's optional gate
   detection.

### Stage D — Post-checks and commit

8. **Run all post-checks** from `0000-baseline.md`:
   - `.codex/workflow-config.md` exists and has no unsubstituted
     `{{...}}` placeholders
   - `.planning/config.json` is valid JSON with the expected hook
     keys
   - `AGENTS.md` contains the `BEGIN: agentic-apps-workflow` marker
   - `docs/decisions/README.md` exists
   - `.codex/workflow-version.txt` reads `0.1.0`
9. **Atomic commit.** All baseline-migration changes go in a single
   commit:

   ```bash
   git add .codex/ .planning/ AGENTS.md docs/decisions/
   git commit -m "chore: install codex-workflow v0.1.0"
   ```

10. **Surface follow-ups.** Tell the user:
    - The project is now at `codex-workflow v0.1.0`
    - Next step: run `$gsd-discuss-phase 1` to start a planning
      session for the first phase
    - Future scaffolder updates: run
      `$update-codex-agenticapps-workflow` periodically; the skill
      reads `.codex/workflow-version.txt` and applies pending
      migrations

## Required evidence (per spec/06)

- `.codex/workflow-version.txt` exists with content `0.1.0`
- `.planning/config.json` is valid JSON with all `hooks` keys from
  the template
- `AGENTS.md` contains the marker pair
  `<!-- BEGIN: agentic-apps-workflow sections -->` ... `<!-- END: agentic-apps-workflow sections -->`
- `docs/decisions/README.md` exists
- The atomic commit is on the project's current branch with the
  expected files staged

## Failure modes

- **Re-running on an installed project.** The pre-flight check
  catches this; never auto-overwrite. Route to
  `$update-codex-agenticapps-workflow`.
- **Scaffolder not installed.** Surface the install path; do not
  silently skip steps that depend on the scaffolder.
- **Half-applied migration.** Per the atomicity contract, prompt
  user (retry / skip / rollback). Do not auto-rollback without
  consent — the user may prefer partial-state recovery.
- **Forgetting Step 6 distinction.** Option A (global) and Option B
  (per-project) are mutually exclusive for this step. Skip Step 6
  cleanly when the user picked Option B.

## Notes for the Codex host

- The default `$CODEX_HOME` is `~/.codex`. Migrations use the
  `${CODEX_HOME:-$HOME/.codex}` form so users with a non-default
  `$CODEX_HOME` get the same behavior.
- The `templates/` directory referenced from migrations lives at
  `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/`.
  `install.sh` symlinks the scaffolder's top-level `templates/` to
  this path so migrations can `cp` from a stable location.
- "Project name detection" can also pull from
  `package.json::name`, `pyproject.toml::project.name`,
  `Cargo.toml::package.name` — surface those as a prefilled
  default in the question rather than always asking from scratch.
