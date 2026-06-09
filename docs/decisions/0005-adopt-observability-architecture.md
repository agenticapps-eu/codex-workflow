# ADR-0005 — Adopt core ADR-0014 observability architecture (generator layer via delegation)

- Status: Accepted
- Date: 2026-06-09
- Phase: 3 (spec 0.4.0 catch-up)
- Implements spec: `agenticapps-workflow-core` §10; ports core ADR-0014
- Supersedes: —
- Superseded by: —
- Related: ADR-0004 (the Option B decision this realises)

## Context

Core **ADR-0014 (observability-architecture)** is an *Accepted,
host-agnostic* decision. It mandates a **two-layer** model:

1. A normative, vendor-agnostic, host-agnostic **contract** in core spec
   §10 — the wrapper interface, the seven-field event envelope, W3C
   `traceparent` propagation, the four mandatory instrumentation points,
   the operational requirements (incl. the §10.5 `Flush` primitive),
   destination independence, and the §10.9 baseline/delta enforcement.
2. A per-host **generator** that scaffolds/vendors the wrapper per tech
   stack, wires trace middleware, validates brownfield projects with a
   confidence-ranked report applied only on consent, and maintains
   `.observability/baseline.json` + `--since-commit` delta scans.

ADR-0014 is explicit that the contract is host- and vendor-agnostic; the
generator is the per-host realisation. The reference host (claude-workflow)
**extracted** its generator into the standalone, independently-versioned
`agenticapps-observability` repo (SPLIT) and now consumes it.

This ADR records how codex-workflow adopts that architecture.

## Decision

**codex-workflow adopts core ADR-0014's two-layer architecture and
realises the generator layer by delegation to
`agenticapps-observability`** (per ADR-0004, Option B) rather than by
shipping a generator inside this scaffolder.

- **Contract layer (spec §10):** unchanged — codex-workflow consumes the
  core contract; it authors no §10 prose of its own.
- **Generator layer:** provided by the standalone obs skill, installed on
  Codex via that repo's `install-codex.sh` (added v0.12.0, PR
  agenticapps-observability#3), wired into a project by codex migration
  `0003`. codex-workflow ships **no** wrapper templates, Flush primitive,
  module-root resolver, or baseline machinery — those live and version in
  the obs repo.

This is a **binding/delegation** (a *satisfied* §10 MUST per §09), not a
spec delta.

## Alternatives rejected

- **Port ADR-0014 as a codex-native generator (Option A in ADR-0004).**
  Rejected — it would re-couple the generator into a host workflow,
  duplicating the obs repo and contradicting the SPLIT that ADR-0014's
  reference realisation established. See ADR-0004.
- **Copy ADR-0014 verbatim into this repo.** Unnecessary — ADR-0014 is
  host-agnostic core architecture; codex-workflow references it and
  records only the host-specific realisation (this ADR). The byte-source
  of the architecture stays in core.

## Consequences

- codex-workflow remains the §10 conformance claimant; the implementation
  (wrapper generation, Flush, module-root resolution, baseline/delta) is
  owned and versioned by the obs repo.
- The catch-up's only cross-repo change is the obs repo's Codex installer
  (agenticapps-observability#3); future obs improvements reach Codex with
  no code change here — only the consumed version moves.
- §10 is recorded as a delegation in `docs/ENFORCEMENT-PLAN.md`;
  downstream setup/update guidance lives in
  `docs/observability-delegation.md`.

## References

- Core `adrs/0014-observability-architecture.md` (the architecture ported).
- ADR-0004 (this repo) — the Option B delegation decision.
- codex `migrations/0003-delegate-observability.md` — the wiring.
- agenticapps-observability `install-codex.sh` / PR #3 — the Codex surface.
