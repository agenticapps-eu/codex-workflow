# Phase 3 — PLAN: §10 Observability (Option B — delegation)

- Spec: `agenticapps-workflow-core` §10 (generator obligation §10.7;
  introduced 0.2.0, current 0.3.2).
- Phase 0 decision (ADR-0004): **Option B** — delegate to the standalone
  `agenticapps-observability` skill after adding a Codex installer to it.
- Model: claude-workflow `migrations/0022` (repoint, no auto-install, D-03).

## Tasks

### Upstream (agenticapps-observability) — cross-repo
1. `install-codex.sh` — sibling of install.sh targeting
   `${CODEX_HOME:-$HOME/.codex}/skills/observability`; idempotent;
   refuse-to-clobber; submodule refresh; `$observability` invocation.
2. README "Host support" section; VERSION + SKILL.md → 0.12.0; CHANGELOG.
3. Branch `feat/codex-install-surface`, PR to `agenticapps-eu/agenticapps-observability`.

### codex-workflow (this repo)
4. `migrations/0003-delegate-observability.md` — additive (0.2.0→0.2.0):
   pre-flight hard-abort (no auto-install) if obs skill absent; Step 1
   record delegation in `.planning/config.json`; Step 2 conditional
   `AGENTS.md` skill-ref repoint. Mirrors claude-workflow 0022's D-03.
5. `docs/observability-delegation.md` — downstream setup/update guidance.
6. ADR-0005 — adopt core ADR-0014 architecture, generator layer via
   delegation; reference ADR-0004; index it.
7. `docs/ENFORCEMENT-PLAN.md` — §10 recorded as a **delegated binding**
   (satisfied MUST per §09, NOT a spec delta).
8. `test_migration_0003` + layout/dispatcher in run-tests.sh.

## Why this respects the SPLIT (the user's Phase-3 question)

Observability was extracted so it is owned + versioned independently and
consumed by host workflows. Adding a Codex installer to the obs repo makes
it genuinely multi-host (completes the separation); codex-workflow stays a
pure consumer (no generator, no templates). Re-owning a generator (Option
A) is what would have violated the SPLIT.

## Gates fired

- `codex-verification` (VERIFICATION.md). `codex-cso` — applies (Phase 3
  touches an executable install script in the obs repo); the install-codex.sh
  security axes (path traversal, clobber, remote content) were addressed by
  mirroring the audited install.sh (refuse-to-clobber, no eval of remote
  content, no secrets). Two-stage review at this phase. `codex-qa` N/A.

## Out of scope (deferred / flagged)

- obs `init` Phase 6 writing AGENTS.md directly on Codex — flagged as a
  follow-up in the obs PR; the §10.8 block is host-migration-managed for now.
- Conformance-claim version sweep in ENFORCEMENT-PLAN → Phase 5.
