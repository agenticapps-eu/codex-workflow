# Phase 6 — PLAN: fold in deferred v0.1.x fixes + adopt agenticapps-shared

Three sub-parts (per hand-off + Phase 0 "adopt now" decision).

## 6a — install.sh symlink-in-source-tree fix (in-repo)

- **Templates restructure (documented fix):** `git mv templates/` →
  `skills/setup-codex-agenticapps-workflow/templates/` (committed there); drop
  install.sh's secondary-symlink step. Migrations read the stable installed
  path `$CODEX_HOME/skills/setup-…/templates/` via the setup skill's own dir
  symlink — no install-time write inside the source tree. Removed the stale
  bug-artifact symlink and the now-obsolete `.gitignore` rule. Updated
  run-tests.sh template paths.
- **Dangling-symlink bug (surfaced during the fix):** `install_one` tested
  `-e` before `-L`; a dangling symlink (repo relocated to `agenticapps/`) read
  as absent, so stale links were never repointed (`ln -s` failed "File exists"
  while printing "LINK"). Fixed: test `-L` first → stale/dangling links are
  repointed. Verified: 21 REPLACE on the relocated env; idempotent re-run 0/22.

## 6b — empirical checks (fresh Codex session)

Record results in ADR appendices:
- `policy.allow_implicit_invocation: false` honored on a fresh Codex session
  (ADR-0003 F2) → ADR-0003 appendix.
- AGENTS.md root-down concat depth on Codex 0.130.0 (ADR-0001 A2) → ADR-0001
  appendix.

## 6c — agenticapps-shared submodule (pause point — user: adopt now)

- Add `agenticapps-shared` as a git submodule at `vendor/agenticapps-shared/`
  (matching the obs repo's layout); unify the migration-runner/drift harness on
  it where clean. Keep migration immutability; switch the harness in one
  reviewed step. install.sh gains the submodule-refresh guard (mirroring the
  obs install scripts).

## Gates fired

- `codex-verification` (VERIFICATION.md). `codex-cso` — install.sh is an
  executable script (the dangling-symlink fix is the security-relevant change:
  no clobber of non-symlinks; refuse-to-clobber preserved). Two-stage review.
