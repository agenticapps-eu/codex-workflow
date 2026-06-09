# Phase 5 — VERIFICATION: conformance bookkeeping (local)

Verified on-disk 2026-06-09. `bash migrations/run-tests.sh` → PASS 41 /
FAIL 0 / SKIP 1; drift green.

## must_have: no stale conformance claim

- **Evidence:** `grep -rn 'implements_spec: 0\.1\.0' skills/` → (none).
  22 skills carry `implements_spec: 0.4.0` (trigger + 14 gate + 5 GSD +
  2 lifecycle). `config-hooks.json` top-level `implements_spec: 0.4.0`
  (`jq -e` PASS).

## must_have: version records agree

- **Evidence:** `.codex/workflow-version.txt` = `0.2.0`; trigger SKILL.md
  `version: 0.2.0`; drift test PASS (version == latest migration
  `0003` to_version 0.2.0).

## must_have: ENFORCEMENT-PLAN claims 0.4.0

- **Evidence:** "claims **`full` conformance** to … v0.4.0 per spec/09";
  five canonical-prose blocks listed (incl. §11); §10 delegated-binding
  section; §12/§13 satisfaction; §13 gate row; `grep -q 'v0.4.0 per spec/09'`
  PASS.

## must_have: ADR-0015 ported

- **Evidence:** `docs/decisions/0006-secret-scanner-gitleaks.md` (STAY on
  gitleaks; no code change) + indexed in README; recorded in CHANGELOG.

## must_have: CHANGELOG + README current

- **Evidence:** `grep -q '^## \[0.2.0\]' CHANGELOG.md` PASS (enumerates
  §10/§11/§12/§13, migrations, drift test, ADR-0006); README Status +
  What-ships at v0.2.0 / spec 0.4.0, 14 gate skills, chain 0000–0003,
  `implements_spec: 0.4.0`.

## Deferred (agreed pause / later)

- Core `reference-implementations/README.md` PR — cross-repo pause point.
- install.sh fix / empirical checks / agenticapps-shared submodule — Phase 6.
- Tag v0.2.0 — Phase 7.
