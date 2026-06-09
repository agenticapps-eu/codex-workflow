# ADR-NNNN: Accept database-security finding {{FINDING_SHORT_NAME}}

- Status: Accepted (risk owned)
- Date: {{YYYY-MM-DD}}
- Risk owner: {{NAME}}
- Re-audit due: {{YYYY-MM-DD}}
- Linear / issue: {{LINK_OR_DASH}}

## Context

The `codex-database-sentinel-audit` skill reported the following
finding during phase {{PHASE_OR_PRE_LAUNCH}}:

- **Severity**: {{Critical | High}}
- **Anti-pattern**: {{NAME_FROM_DB_AUDIT_MD}}
- **Location**: {{TABLE / RULE / POLICY / FUNCTION / CONFIG_KEY}}
- **Scanner output**: see
  `.planning/phases/{{N}}/DB-AUDIT.md` (or `docs/DB-AUDIT.md` for
  pre-launch).

Per [ADR-0012](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0012-database-sentinel-rls-audit-gate.md),
Critical and High findings BLOCK branch close (or pre-launch
clearance) unless explicitly accepted via this ADR pattern.

## Decision

Accept the finding without applying the recommended fix because
**{{ONE_OR_TWO_SENTENCE_RATIONALE}}**.

### What is accepted

The risk that {{ATTACKER_PROFILE}} could {{IMPACT}} via
{{ATTACK_VECTOR}}.

### Why the fix is being deferred

{{REASON — typical: legacy-data migration not yet ready, business
constraint requires public read, fix would break {{integration}}
which is being deprecated next phase, etc.}}

### Compensating controls

The following controls reduce the residual risk to a level the
risk owner is willing to carry until the re-audit date:

- {{CONTROL_1, e.g. application-level access check at the API
  layer means the table being world-readable at the DB layer is
  shadowed by app filtering}}
- {{CONTROL_2, e.g. monitoring alert on row-count change >N% per
  hour}}
- {{CONTROL_3, e.g. rate limit on public endpoint surfaces this
  table}}

### Re-audit plan

By **{{RE_AUDIT_DATE}}**, one of the following happens:

- The scanner output is re-checked; if the finding has been
  fixed (because the migration / deprecation completed), this
  ADR is closed and superseded by an ADR documenting the fix
- Or this ADR is renewed with an updated risk owner, updated
  compensating controls, and a fresh re-audit date

A renewal that doesn't update the compensating controls or the
re-audit date is non-conformant — the gate exists to prevent
indefinite deferral.

## Consequences

**Positive:**
- The phase ships without the recommended fix
- The deferred work is explicitly tracked with an owner and a date

**Negative:**
- Until the re-audit, the database carries known
  {{Critical | High}} severity exposure visible to the scanner.
  The compensating controls reduce but do not eliminate the
  exposure.

**Follow-ups:**
- Re-audit on {{RE_AUDIT_DATE}}
- {{ANY_OTHER_FOLLOWUP, e.g. "complete legacy-data migration
  by end of phase {{N+2}}"}}

## References

- DB-AUDIT.md: `.planning/phases/{{N}}/DB-AUDIT.md`
- ADR-0012 (host-agnostic gate definition):
  https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0012-database-sentinel-rls-audit-gate.md
- spec/02 `database-security` gate definition:
  https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md
