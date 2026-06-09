# ADR-0006 — Secret scanner: stay on gitleaks (adopt core ADR-0015)

- Status: Accepted
- Date: 2026-06-09
- Phase: 5 (spec 0.4.0 catch-up)
- Implements spec: ports core ADR-0015
- Supersedes: —
- Superseded by: —

## Context

Core **ADR-0015 (secret-scanner)** evaluated whether the AgenticApps
default secret-scanner CI gate should move from `gitleaks` to an
alternative (`betterleaks`). It began **Proposed** and was **ratified to
Accepted (2026-05-21)** with the outcome **STAY on gitleaks**: the
benchmark tied on true-positive recall and false-positive count, and one
criterion inverted in gitleaks' favour (it decodes inline base64 by
default). ADR-0015 is host-agnostic.

codex-workflow ships no secret-scanner code of its own — a secret-scan CI
gate is a *downstream project* concern, not a trigger that fires on this
markdown scaffolder. The catch-up's obligation here is only to record the
ratified outcome (per the core decision: codex mirrors "inherit the STAY
outcome without code changes; they only need to record the ratification
in their changelogs").

## Decision

**codex-workflow adopts core ADR-0015's outcome: `gitleaks` is the
default secret-scanner for downstream Codex projects.** No scanner code,
gate, or template changes in this repo. Downstream projects that add a
secret-scan CI gate SHOULD use `gitleaks`; existing `gitleaks` projects
SHOULD NOT migrate; hosts MAY evaluate alternatives locally.

While core ADR-0015 was still Proposed, hosts were instructed not to
switch defaults on Proposed status alone — moot now that it is Accepted.

## Consequences

- No code change in codex-workflow; recorded in `CHANGELOG.md` [0.2.0].
- If/when codex-workflow grows a downstream-project secret-scan gate
  binding, it defaults to `gitleaks` per this ADR.

## References

- Core `adrs/0015-secret-scanner.md` (Accepted, STAY on gitleaks).
- This repo `CHANGELOG.md` [0.2.0] — the ratification note.
