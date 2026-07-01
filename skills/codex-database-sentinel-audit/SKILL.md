---
name: codex-database-sentinel-audit
version: 0.1.0
implements_spec: 0.4.0
implements_gate: database-security, db-pre-launch-audit
description: |
  Database-specialist security audit in two modes. **phase-scoped
  mode**: when the security gate fires AND the phase scope matches
  supabase|postgres|mongodb|firebase|mysql, audit the changed surface
  for RLS / auth bypass / storage exposure / known CVEs (MongoBleed,
  pgBouncer, mysql_native_password drift) and produce DB-AUDIT.md.
  **pre-launch mode**: before first production launch and after any
  major DB migration, audit the FULL project surface (every supported
  backend). Critical or High findings BLOCK branch close per ADR-0012;
  override only via the database-security acceptance ADR template.
---

# codex-database-sentinel-audit

This skill fulfills both the `database-security` (post-phase
sub-gate) and `db-pre-launch-audit` (finishing) gates from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md)
and is bound by [ADR-0012](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0012-database-sentinel-rls-audit-gate.md).

## When to invoke

- **phase-scoped mode** — when `codex-cso` fires AND the phase scope
  matches `supabase|postgres|mongodb|firebase|mysql`. This skill
  runs as a sub-gate of `codex-cso`'s security gate (per ADR-0012);
  SECURITY.md references DB-AUDIT.md.
- **pre-launch mode** — before any first production launch and after
  any major DB migration. Scope is full project, not phase-scoped.

## What this skill does

1. **Detect the backend(s).** Read the project's manifest
   (`package.json`, `requirements.txt`, `Cargo.toml`, etc.) and
   environment config to identify which databases are in play.
   Supported: Supabase, self-hosted Postgres, MongoDB (self-hosted +
   Atlas), Firebase (Firestore / RTDB / Storage / Functions), MySQL.
2. **Probe safely.** No destructive queries. Read-only RLS introspection,
   role grant enumeration, configuration inspection, version
   detection.
3. **Walk the anti-pattern catalog.** 27 anti-patterns drawn from
   CVE-2025-48757 and 10 security studies. Each anti-pattern check:
   - Detects a specific misconfiguration (e.g. "RLS policy with
     `USING (true)` for SELECT")
   - Records severity (Critical / High / Medium / Low)
   - Provides exact-fix SQL DDL (or backend-equivalent config
     change) ready to apply
4. **Specific CVE checks.**
   - MongoBleed (CVE-2025-14847) — version + auth-mechanism check
   - pgBouncer CVE-2025-12819 — version + listen-addr check
   - mysql_native_password drift — auth plugin enumeration
   - Supabase RLS default-permissive (CVE-2025-48757) — policy
     audit per table
   - Firebase Firestore default-readable rules — rules file inspection
5. **Write DB-AUDIT.md** to `.planning/phases/<NN>-<slug>/DB-AUDIT.md`
   (phase-scoped) or `docs/DB-AUDIT.md` (pre-launch):

   ```markdown
   # Database audit — {{phase N | pre-launch}}

   Auditor: codex-database-sentinel-audit v0.1.0
   Mode: <phase-scoped | pre-launch>
   Backends detected: <list>
   Scope: <changed-surface | full-surface>

   ## Findings (severity-classified)

   ### Critical

   - **<finding>** — <where> — <fix SQL>

   ### High

   - **<finding>** — <where> — <fix SQL>

   ### Medium

   - …

   ### Low

   - …

   ## Verdict

   <pass | block (Critical/High count: N)>
   ```
6. **Block on Critical / High.** Branch close blocks until each
   Critical and High finding is either fixed or accepted via ADR.
   The acceptance ADR uses the database-security acceptance template
   pattern (canonical template TBD — for now, follow the shape used
   in this repo's `docs/decisions/0001-*.md` series, with explicit
   risk owner, re-audit date, and compensating-control documentation).

## Required evidence (per spec/06)

- `DB-AUDIT.md` exists at the path the mode dictates
- Each finding names: anti-pattern, location, severity, fix
- Severity counts are explicit (e.g. "2 Critical, 5 High, 3 Medium,
  1 Low")
- Verdict line is explicit
- For pre-launch mode: zero Critical AND zero High required to
  clear the gate (without an accepted-risk ADR)

## Failure modes

- **Treating findings as advisory.** Per ADR-0012, Critical and High
  block. Vibe-coded apps shipping default-permissive RLS is exactly
  what this gate exists to prevent.
- **Phase-scoped audit substituting for pre-launch.** Phase-scoped
  audits cover the changed surface; pre-launch covers everything
  (storage policies, role grants, anonymous access — dimensions
  that no single feature phase touches).
- **Skipping the CVE-specific checks.** MongoBleed, pgBouncer,
  mysql_native_password drift are version-pinning concerns even when
  the project's code didn't change.
- **Skipping the ADR override path.** When a finding is genuinely
  accepted (e.g. a public-readable table by design), document it as
  an ADR — silent acceptance erodes the audit trail.

## Notes for the Codex host

- The upstream `Farenhytee/database-sentinel` skill (when installed)
  carries the canonical 27-anti-pattern catalog and probe scripts.
  This skill reuses it when present; carries the catalog inline as
  fallback.
- Probes must be read-only — never destructive. If a probe would
  require destructive access, surface and skip rather than running
  it.
- For Supabase projects, the project's `service_role` key is
  required for RLS introspection — surface escalation if the env
  var isn't set rather than silently auditing only `anon`-readable
  surfaces.
