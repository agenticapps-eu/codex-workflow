---
name: setup-codex-agenticapps-workflow
version: 1.0.0
implements_spec: 1.0.0
description: |
  Bootstrap a fresh project with the codex-workflow scaffolding —
  apply the baseline migration to install the trigger skill's
  required project-side artifacts (AGENTS.md sections, .planning/config.codex.json,
  .codex/workflow-config.md, docs/decisions/, .codex/workflow-version.txt),
  then walk the chain to the current version — which scaffolds the OpenSpec
  spec slot, installs the §18 change-gate at all three surfaces (PreToolUse
  hook, git pre-commit, CI), and lays down the collapsed 1.0.0 gate set.
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
(`0000-baseline.md`) and any additional migrations that
have shipped between scaffolder versions, leaving the project at the
current scaffolder version. Migration files are read from the stable
installed path — see **Notes for the Codex host** — never relative to
the project being set up.

## When to invoke

User asks to set up the workflow on a project that does not yet have
a `.codex/workflow-version.txt` file. The trigger skill's
`agentic-apps-workflow` does NOT auto-route to setup — setup is an
explicit, user-driven act because it modifies project-side files
(AGENTS.md, .planning/config.codex.json, .codex/) that the user expects to
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

6. **Walk the baseline migration
   `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/migrations/0000-baseline.md`
   step by step** (the stable installed path — do NOT read
   `migrations/…` relative to the project being set up). For each
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
   - `.planning/config.codex.json` is valid JSON with the expected hook
     keys
   - `AGENTS.md` contains the `BEGIN: agentic-apps-workflow` marker
   - `docs/decisions/README.md` exists
   - `.codex/workflow-version.txt` reads `0.1.0`

   When the chain reaches `1.0.0` (migration `0013`), also confirm the
   OpenSpec end state:
   - `openspec/` carries the three-slot layout (`specs/`, `changes/`,
     `changes/archive/`) and `openspec validate --all` runs clean
   - `test -x "$HOME/.agenticapps/bin/openspec-change-gate.sh"`
   - `.codex/hooks.json` names `hook-wrapper-openspec-gate.sh` in a
     **nested** `{"matcher", "hooks":[{"type","command"}]}` group — the flat
     form is dropped by codex-cli with no error and no warning
   - a `pre-commit` hook is installed in the project's git hooks dir
   - `jq -e '.lifecycle.validate.change_gate' .planning/config.codex.json`
   - the gate blocks by direct invocation:
     `printf '{"tool":"edit","tool_input":{"file_path":"x.go"}}' | ~/.agenticapps/bin/openspec-change-gate.sh`
     exits 0 with no active change, and 2 once a change is open without
     `REVIEWS.md`

   > **Note — where §11's placement comes from (do not add it here).**
   > Setup deliberately carries **no §11 Coding Discipline placement logic**.
   > `0000-baseline.md`'s **Step 3** (`:102`) is a plain append of
   > `templates/agents-md-additions.md`, and that template contains no §11 —
   > so setup lands the project at `0.1.0` with no §11 block and no anchor
   > rule of its own. §11 arrives via **migration `0001`** in the subsequent
   > update chain, and its placement (above any leading GitNexus region) is
   > healed by **migration `0009`**. GitNexus itself was removed from every
   > live surface at workflow `1.0.0` (ADR-0011), so a *new* project never
   > grows that region — `0009` stays in the chain for projects that already
   > carry one. The anchor rule has exactly one source:
   > the migration chain. If you are here to change where §11 lands, this is
   > the wrong file — see
   > [`docs/decisions/0010-region-aware-spec-11-placement.md`](../../docs/decisions/0010-region-aware-spec-11-placement.md)
   > and change the migration, not setup. Adding placement logic here would
   > create the second source of truth `spec/08` forbids.

9. **Atomic commit.** All baseline-migration changes go in a single
   commit:

   ```bash
   git add .codex/ .planning/ AGENTS.md docs/decisions/
   git commit -m "chore: install codex-workflow v0.1.0"
   ```

10. **Surface follow-ups.** Tell the user:
    - The project is now at the current `codex-workflow` version (the
      baseline lands `0.1.0`; the chain carries it to `1.0.0`)
    - **Trust the hook.** Start a fresh Codex session, run `/hooks`, and
      confirm the openspec-gate entry is **Active**, not "Review". An
      untrusted hook enforces nothing while looking installed — the git
      pre-commit and CI checks cover the gap until it is trusted.
    - Next step: open the first change — `$openspec-propose` (or
      `openspec new change <slug>`), then `openspec validate --all`, then
      `codex-openspec-change-review` before any code. See
      [`docs/WORKFLOW.md`](../../docs/WORKFLOW.md).
    - If the project has existing `.planning/` history, run the
      **planning→openspec recipe** (core `docs/recipes/0001-planning-to-openspec.md`,
      carried by `$update-codex-agenticapps-workflow`) to seed
      `openspec/specs/` — merging related phases into coherent
      capabilities, never one-phase-one-spec. `.planning/` is moved to
      `docs/legacy-planning/`, never deleted.
    - Future scaffolder updates: run
      `$update-codex-agenticapps-workflow` periodically; the skill
      reads `.codex/workflow-version.txt` and applies pending
      migrations

## Required evidence (per spec/06)

- `.codex/workflow-version.txt` exists with content `0.1.0` immediately
  after the baseline, and the chain's latest `to_version` once the full
  replay completes
- `.planning/config.codex.json` is valid JSON — with the `hooks` keys from
  the template at `0.1.0`, and the `lifecycle` tree (`front_end`,
  `openspec`, `lifecycle.validate.change_gate`) once `0013` has applied
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
- **Migrations path.** This skill reads its migrations at
  `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/migrations/`.
  A committed `migrations` symlink inside the skill dir points to the
  scaffolder's top-level `migrations/`; because `install.sh` symlinks
  the whole skill dir into `~/.codex`, they resolve at that stable path
  regardless of the target project's working directory. Every
  `migrations/…` / `0000-baseline.md` reference in this skill means that
  path — never read them relative to the project being set up. (The
  `$update-codex-agenticapps-workflow` skill uses the identical
  convention for its own `migrations` symlink.)
- "Project name detection" can also pull from
  `package.json::name`, `pyproject.toml::project.name`,
  `Cargo.toml::package.name` — surface those as a prefilled
  default in the question rather than always asking from scratch.
