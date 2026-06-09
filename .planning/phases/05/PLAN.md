# Phase 5 — PLAN: Conformance bookkeeping + ADR-0015 + version bump

Make the conformance claim coherent at 0.4.0 everywhere. Local (in-repo)
bookkeeping; the cross-repo core ref-impl PR is the agreed pause point.

## Tasks (local — done this phase)

1. Sweep `implements_spec: 0.4.0` across all skill frontmatter that carries
   it (20 skills; trigger + ts-declare-first already at 0.4.0 → 22 total).
   Audit: `grep -rn 'implements_spec: 0.1.0' skills/` returns nothing.
2. `config-hooks.json` top-level `implements_spec` → 0.4.0.
3. `.codex/workflow-version.txt` → 0.2.0.
4. `docs/ENFORCEMENT-PLAN.md` — conformance claim 0.1.0 → 0.4.0; five
   canonical-prose blocks (incl. §11); §10 delegated-binding section (Phase 3);
   §12/§13 satisfaction; §13 gate row.
5. ADR-0006 — port core ADR-0015 (secret scanner STAY on gitleaks; no code
   change); index it.
6. `README.md` — Status + What-ships → v0.2.0 / spec 0.4.0; 14 gate skills;
   migration chain 0000–0003; `implements_spec: 0.4.0`.
7. `CHANGELOG.md` — `[0.2.0]` entry enumerating §10/§11/§12/§13, migrations,
   drift test, ADR-0006; Unreleased keeps Phase 6/7 + backlog.

## Deferred to the checkpoint / later phases

- **Core ref-impl PR** (cross-repo `agenticapps-workflow-core`) — agreed
  pause point; opened at the checkpoint / Phase 7.
- install.sh symlink fix, empirical checks, agenticapps-shared submodule →
  Phase 6.
- Tag v0.2.0 → Phase 7.

## Gates fired

- `codex-verification` (VERIFICATION.md). Two-stage review. `codex-cso`/`qa`
  N/A (no executable/security code changed locally this phase).
