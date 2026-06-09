# Observability on Codex — delegated to agenticapps-observability

codex-workflow satisfies `agenticapps-workflow-core` **§10 (observability)**
by **delegating** to the standalone, host-neutral
[`agenticapps-observability`](https://github.com/agenticapps-eu/agenticapps-observability)
skill — not by shipping its own generator. This mirrors claude-workflow's
post-SPLIT direction. See **ADR-0004** (the decision) and **ADR-0005**
(adoption of core ADR-0014's architecture).

A delegation to a consumable skill is a *satisfied* §10 MUST under §09 —
not a spec delta. `full` conformance is preserved.

## Why delegation (and why it respects the SPLIT)

Observability was deliberately extracted into its own repo so it is
**owned and versioned independently** and consumed by host workflows.
codex-workflow stays a **pure consumer**: it ships no wrapper templates,
no generator, no baseline machinery. It only (a) requires the obs skill
to be installed and (b) records the delegation + wires a project's
`AGENTS.md`. Re-owning a generator inside codex-workflow is exactly what
the SPLIT avoided.

## Install (one-time, per machine)

The obs skill installs into the Codex skill dir via its **Codex
installer** (`install-codex.sh`, agenticapps-observability ≥ 0.12.0):

```bash
git clone https://github.com/agenticapps-eu/agenticapps-observability \
  "${CODEX_HOME:-$HOME/.codex}/skills/agenticapps-observability"
bash "${CODEX_HOME:-$HOME/.codex}/skills/agenticapps-observability/install-codex.sh"
# → ${CODEX_HOME:-$HOME/.codex}/skills/observability  (invoked as $observability)
```

Verify:

```bash
test -f "${CODEX_HOME:-$HOME/.codex}/skills/observability/SKILL.md" \
  && grep -q '^name: observability' "${CODEX_HOME:-$HOME/.codex}/skills/observability/SKILL.md"
```

## Wire a project (migration 0003)

`$update-codex-agenticapps-workflow` applies **migration 0003**, which:

1. Pre-flight hard-aborts (exit 3) if the obs skill is not installed (no
   auto-install — D-03 mirror).
2. Records the delegation in `.planning/config.json`
   (`hooks.observability.delegated_to = "observability"`).
3. **Relocates the §10.8 `observability:` metadata block** into `AGENTS.md`
   (the canonical Codex file): `$observability init` currently emits the
   anchored block into `CLAUDE.md`, and this step moves it to `AGENTS.md`
   preserving init's real content (destinations / policy / spec_version).
4. Repoints a stale `add-observability` skill reference in `AGENTS.md` if one
   exists.

**Recommended order:** run `$observability init` first (scaffolds the wrapper
and emits the metadata block), then `$update-codex-agenticapps-workflow` (so
migration 0003 relocates the §10.8 block into `AGENTS.md`). On a project that
has not run `init`, steps 3–4 no-op — a project with no observability has no
§10.8 obligation until it adds observability.

## Use (per project)

```bash
$observability init    # greenfield: scaffold the host-neutral wrapper/middleware
$observability scan    # brownfield: validate, baseline, delta (reads AGENTS.md on Codex)
$observability scan --since-commit main   # §10.9 delta scan for CI
```

The wrapper interface (§10.1–10.6), the `Flush(timeout)` primitive
(§10.5), module-root path resolution (§10.7.1), and the
`.observability/baseline.json` + delta machinery (§10.9) are all
implemented and versioned in the obs repo — codex-workflow inherits them
without owning them.

## Conformance bookkeeping

§10 is recorded as a **delegation** in `docs/ENFORCEMENT-PLAN.md`. The
obligation is met by the consumed skill; codex-workflow remains the
conformance claimant.

## Known follow-up

The obs skill's `init` Phase 6 currently emits the §10.8 metadata block
into `CLAUDE.md`. On Codex the block belongs in `AGENTS.md`; **migration
0003 relocates it there**, so §10.8 is satisfied on the Codex side today
(the relocate preserves init's real content). Making the obs `init` Phase 6
emit `AGENTS.md` directly under a Codex host — removing the relocate
round-trip — is a tracked obs-repo follow-up (see
agenticapps-observability#3).
