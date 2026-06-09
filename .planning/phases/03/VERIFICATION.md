# Phase 3 — VERIFICATION: §10 Observability (delegation)

Verified on-disk 2026-06-09. Full suite: `bash migrations/run-tests.sh` →
**PASS: 40, FAIL: 0, SKIP: 1**.

## must_have: Codex install surface exists upstream (the binding resolves)

- **Evidence:** `agenticapps-observability` `install-codex.sh` authored,
  run, and verified — `~/.codex/skills/observability/SKILL.md` present
  (`grep '^name: observability'`); idempotent re-run confirmed
  ("already linked"). PR: agenticapps-observability#3 (branch
  `feat/codex-install-surface`, VERSION → 0.12.0).

## must_have: migration 0003 wires a downstream project, additive + contiguous

- **Evidence:** `migrations/0003-delegate-observability.md`
  `from_version: 0.2.0` / `to_version: 0.2.0` (additive); chain
  `0000→0001→0002→0003` contiguous; `test_migration_0003` PASSes
  idempotency + jq apply/rollback + base-hooks-intact + Step-2 repoint +
  doc/ADR presence. Pre-flight hard-aborts (no auto-install) when the obs
  skill is absent (D-03 mirror).

## must_have: §10 recorded as a delegation (not a spec delta)

- **Evidence:** `docs/ENFORCEMENT-PLAN.md` "§10 Observability — delegated
  binding" section with a per-subsection mapping table and the explicit
  statement: "A delegation to a consumable skill is a **satisfied** §10
  MUST per §09 — **not** a spec delta." Distinguished from the eight
  trigger-cannot-occur Spec Deltas.

## must_have: ADR-0014 ported; setup guidance shipped

- **Evidence:** `docs/decisions/0005-adopt-observability-architecture.md`
  (adopts core ADR-0014's two-layer architecture, generator via
  delegation) + indexed in `docs/decisions/README.md`;
  `docs/observability-delegation.md` references the obs repo +
  `install-codex.sh` + `$observability init/scan`.

## must_have: drift stays green

- **Evidence:** `run-tests.sh`: "SKILL.md version=0.2.0 ==
  0003-delegate-observability.md to_version=0.2.0" PASS.

## must_have: SPLIT separation respected

- **Evidence:** codex-workflow ships NO wrapper templates / generator /
  baseline machinery (`ls templates/` has only spec-mirrors + the existing
  project templates; no observability/ generator). The obs repo owns the
  implementation; this repo only records the delegation + wires AGENTS.md.
