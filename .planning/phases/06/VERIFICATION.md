# Phase 6 — VERIFICATION: deferred fixes + agenticapps-shared

Verified on-disk 2026-06-09 (Codex 0.130.0).

## 6a — install.sh fixes

- **Templates restructure:** `templates/` moved (git-mv, history preserved) to
  `skills/setup-codex-agenticapps-workflow/templates/`; install.sh's secondary-
  symlink step removed; stale bug-artifact symlink + obsolete `.gitignore` rule
  removed. **Evidence:** `install.sh --dry-run` leaves `git status` unchanged
  (writes nothing in the source tree); templates resolve at the installed path
  `~/.codex/skills/setup-…/templates/`.
- **Dangling-symlink repoint:** `install_one` tests `-L` before `-e`.
  **Evidence:** on the relocated env, install.sh produced 21 REPLACE (repointed
  stale links to the new repo path), no `ln` errors, no BLOCKED; re-run
  idempotent (0 installed / 22 skipped).

## 6b — empirical checks (recorded in ADR appendices)

- **ADR-0001 A2 (concat depth):** CONFIRMED — Codex 0.130.0 concatenates
  AGENTS.md git-root-down to cwd (sentinel probe: ROOT+MID+DEEP in a git repo;
  DEEP-only in a non-git tree). F3 resolved.
- **ADR-0003 F2 (allow_implicit_invocation):** CONFIRMED honored — unrelated-
  session probe listed all 13 codex-* (default true) and ZERO gsd-* (false).
  F2 resolved.
- Bonus: the probes caught two Codex-loader compat bugs in the consumed obs
  skill (description >1024; legacy SKILL.md missing description) — fixed in
  agenticapps-observability PR #3.

## 6c — agenticapps-shared submodule

- **Evidence:** `vendor/agenticapps-shared` added as a submodule (pinned v1.0.0,
  `git submodule status`). `migrations/run-tests.sh` sources the shared
  `helpers.sh` / `fixture-runner.sh` / `drift-test.sh` (no local duplication of
  run_check/assert_check/extract_to; drift uses `run_drift_test` with the
  hard-fail policy kept in the consumer). install.sh refreshes the submodule
  (idempotent, non-fatal guard). README "Consumes" documents it.
- **No regression:** `bash migrations/run-tests.sh` → PASS 43 / FAIL 0 / SKIP 1
  (2 new layout checks for the shared libs); drift green.

## Gates

- `codex-verification` (this file). `codex-cso`: install.sh executable change —
  the dangling-symlink fix preserves refuse-to-clobber on non-symlinks; no eval
  of remote content; submodule refresh is non-fatal + git-dir-guarded.
