# Phase 11: Migration Chain Repair - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-16
**Phase:** 11-migration-chain-repair
**Areas discussed:** 0.5.0-escape handling, MIGR-11 Stage D depth, chain-proof scope

---

## Area selection

Presented three genuinely-open decisions (the rest of the phase is locked by
REQUIREMENTS.md + research). User selected all three to discuss.

---

## Migration 0010 — "manual 0.5.0 escape" edge

| Option | Description | Selected |
|--------|-------------|----------|
| Strict floor; document recovery | 0010 uses 0008's verbatim version-floor; recovery for hand-hacked 0.5.0 operators goes in MIGR-11 Stage D, not 0010's code | ✓ |
| Payload-presence backfill in 0010 | 0010 also detects missing payload and backfills at 0.5.0 — wider surface, deviates from 0008's pattern | |
| Strict floor only, no doc | Gate on <0.5.0 and document nothing — leaves hand-hacked operator with no path | |

**User's choice:** Strict floor; document recovery (recommended).
**Notes:** Keeps the required verbatim reuse of 0008:73–79 and avoids the copy-by-analogy trap (PITFALLS #2). The manual-escape operator is handled by MIGR-11 docs (D-02/D-04).

---

## MIGR-11 Stage D documentation depth

| Option | Description | Selected |
|--------|-------------|----------|
| Concise recovery runbook | Specific non-looping steps + exact commands; covers both superseded-0007 and manual-0.5.0 operators | ✓ |
| Brief supersession note | One or two lines — likely too thin for MIGR-11's "defined path" goal | |
| Full operator guide | Exhaustive per-state prose — heavier than required, doc-rot risk | |

**User's choice:** Concise recovery runbook (recommended).

---

## Chain-proof scope

| Option | Description | Selected |
|--------|-------------|----------|
| Payload proof + version assertion | Required 0.4.0 fixture asserts payload delivered AND version now reads 0.5.0 — cheap bridge to the chain claim | ✓ |
| Full end-to-end chain fixture | 0.4.0 → 0010 → 0008 → 0009 multi-migration harness — flagged as over-build; 0008/0009 already tested | |

**User's choice:** Payload proof + version assertion (recommended).

---

## Claude's Discretion

- Migration ID fixed at `0010` (next sequential; independent of ADR numbering).
- Fixture naming/placement, exact runbook wording, and intra-migration step ordering.

## Deferred Ideas

- Payload-presence backfill inside 0010 (revisit only if a real hand-hacked population is confirmed).
- Full 0.4.0→0010→0008→0009 end-to-end chain fixture (over-build for v0.8.0).
- ADR/migration numbering-doc reconciliation (IN-03 / REV-04) — Phase 12.
