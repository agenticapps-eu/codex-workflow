---
name: codex-cso
version: 0.1.0
implements_spec: 0.1.0
implements_gate: security
description: |
  Run an OWASP-aligned security audit at a phase boundary when the
  changeset touches authentication, storage, request handling, secret
  material, or LLM trust boundaries. Produces SECURITY.md with
  audited threat models and mitigation evidence. Use when the phase's
  diff includes auth flows, session handling, file/blob storage, API
  surfaces, environment variables/secrets, or LLM tool-use trust
  boundaries. Composes with `codex-database-sentinel-audit` (DB-specific
  sub-gate) per ADR-0012.
---

# codex-cso

This skill fulfills the `security` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md).
Database-specific concerns sub-gate to
`codex-database-sentinel-audit` per
[ADR-0012](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0012-database-sentinel-rls-audit-gate.md).

## When to invoke

The phase's changeset touches at least one of:
- Authentication or session handling (login, password, OAuth, JWT,
  cookie, session storage)
- Storage of any sort (file uploads, blob storage, KV, cache)
- Request handling at trust boundaries (route handlers, middleware,
  CORS, CSRF)
- Secret material (env vars, API keys, signing keys, encryption keys)
- LLM trust boundaries (prompt injection vectors, tool use, agent
  identity, output sanitization)

If the phase touches database schema, RLS, security definer
functions, or storage policies, ALSO invoke
`codex-database-sentinel-audit` as a peer gate (per ADR-0012).

## What this skill does

1. **Enumerate the threat model.** STRIDE per surface that the
   changeset touches:
   - **S**poofing — can an attacker impersonate a user, a service, a
     trusted origin?
   - **T**ampering — can an attacker modify data, requests, or stored
     artifacts?
   - **R**epudiation — can an attacker deny an action that they took?
   - **I**nformation disclosure — can an attacker read data they
     shouldn't?
   - **D**enial of service — can an attacker degrade availability?
   - **E**levation of privilege — can an attacker gain capabilities
     beyond their grant?
2. **Walk OWASP Top 10 (current edition).** For each, mark
   applicable / not-applicable, and if applicable, name the
   mitigation:
   - Broken access control
   - Cryptographic failures
   - Injection (SQL, command, template, LDAP, etc.)
   - Insecure design
   - Security misconfiguration
   - Vulnerable / outdated components
   - Identification / authentication failures
   - Software / data integrity failures
   - Security logging / monitoring failures
   - Server-side request forgery
3. **Scan dependencies.** Check the phase's lockfile diff for new
   dependencies. For each, verify there's no known CVE in the
   pinned version. Use the project's existing audit tooling (`npm
   audit`, `pip-audit`, `cargo audit`, `go list -m -u all`).
4. **Scan for secrets.** Check the diff for accidental commits of
   secrets — patterns like `sk_live_`, `xoxb-`, AWS access key
   format, JWT segments, private keys, `.env` files.
5. **LLM-specific checks.** If the phase touches LLM tool use or
   agent identity:
   - Are user-controlled strings concatenated into system prompts
     without sanitization?
   - Is the agent's tool surface scoped (read-only / write-with-confirm
     / never)?
   - Does the agent's output get rendered as HTML / executed as code
     anywhere downstream?
   - Are prompt-injection countermeasures (sanitization, instruction
     hierarchy, tool-permission scoping) documented?
6. **Write SECURITY.md.** Use the skeleton:

   ```markdown
   # Security audit — phase {{N}}

   Auditor: codex-cso v0.1.0
   Scope: {{surfaces touched}}

   ## STRIDE

   | Surface | S | T | R | I | D | E | Mitigation |
   |---|---|---|---|---|---|---|---|

   ## OWASP Top 10

   | Category | Status | Mitigation |
   |---|---|---|

   ## Dependency scan

   - Tool: npm audit / pip-audit / etc.
   - Output: <command output snippet>
   - New CVEs: <count>

   ## Secret scan

   - Patterns checked: …
   - Hits: <count, fix if non-zero>

   ## LLM trust boundary (if applicable)

   - …

   ## Verdict

   <pass | pass-with-followups | block>
   ```

## Required evidence (per spec/06)

- `SECURITY.md` exists in the phase directory
- It lists every applicable surface from the threat model
- For each finding, the mitigation is named (or the absence of one is
  flagged)
- The dependency scan output is a real command's real output
- The secret scan was actually run
- The verdict line is explicit

## Failure modes

- **Trusting framework defaults.** "Next.js handles CSRF" is not a
  mitigation — name the framework version, the specific built-in,
  and confirm it's enabled in the project's config.
- **Treating "no findings" as the only acceptable outcome.** Real
  audits produce findings. A SECURITY.md with zero findings either
  means the audit was shallow or the surface is genuinely
  unchanged — name which.
- **Skipping LLM trust-boundary checks because "we're not using
  agent loops."** Tool use, prompt construction, and output
  rendering all fall under the LLM trust boundary even outside agent
  loops.
- **Deferring "real security review" to a future phase.** Compounding
  technical debt; the security gate fires per-phase by design.

## Notes for the Codex host

- For DB-touching phases, invoke `codex-database-sentinel-audit` as
  well; SECURITY.md references DB-AUDIT.md but does not duplicate it.
- The dependency scan command depends on the project. Check the
  project's CLAUDE.md / AGENTS.md / package manifest to find which
  tooling is in use; use it.
