# Phase 8: Plan-Review Gate - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Bind the core spec §02 `plan-review` pre-execution gate on the Codex host: a
declarative binding in `.planning/config.codex.json` plus a programmatic verifier
implementing the spec's resolution order and grandfather rule, an authored
`codex-plan-review` producer skill, ritual wiring, migration `0008`, and an ADR.

This closes the follow-up the spec names at `spec/02:105-109`. It delivers the
§02 *content* required for a future `implements_spec: 0.5.0` claim — it does not
make that claim.

</domain>

<decisions>
## Implementation Decisions

### Enforcement mechanism

- **D-01:** Hybrid. The declarative binding in `.planning/config.codex.json` stays
  the source of truth (consistent with the other 15 gates and ADR-0007's
  thin-binding stance); a shell verifier supplies the programmatic enforcement
  `spec/02:92-93` calls for. Rejected: **declarative-only** (declines the SHOULD;
  enforcement rests on agent compliance — the exact failure core ADR-0018 closes)
  and **native `~/.codex/hooks.json` PreToolUse** (global so it fires in every
  repo and must self-scope; the sha256 trust ledger forces a re-grant whenever the
  migration edits it; introduces a second mechanism).
- **D-02:** Do not wire `~/.codex/hooks.json` in this phase. Codex CLI 0.144.4 does
  ship a native hook surface (`PreToolUse`/`PostToolUse`/`SessionStart`,
  `[features] hooks = true`, `--dangerously-bypass-hook-trust`) — ADR-0009 records
  it as the documented upgrade path, pointing at the same verifier.

### Verifier invocation

- **D-03:** `AGENTS.md` ritual text + trigger `SKILL.md`, fired before the first
  code-touching edit of a phase. `AGENTS.md` is root-down concatenated, so the
  instruction is always in context.
- **D-04:** Do **not** attempt to wire into `gsd-execute-plan` or any other GSD
  ritual — they are upstream prompts this repo does not own. This is the §15 /
  migration-0007 precedent and it is binding here.

### Resolver + grandfather

- **D-05:** Resolution order per `spec/02:97-99`: explicit pointer
  (`readlink .planning/current-phase`, absolute and `.planning/`-relative) →
  workflow state (`.planning/STATE.md`) → newest `*-PLAN.md` by mtime → fail-open.
- **D-06:** **Do not port the reference's step 2 verbatim — it is dead code.**
  `multi-ai-review-gate.sh:96` greps `^##[[:space:]]+Current Phase`; every real GSD
  `STATE.md` writes `## Current Position` (verified across `claude-workflow`,
  `agenticapps-dashboard`, `agenticapps-roadmap`, `bench-codex` — zero files
  anywhere use `## Current Phase`). Match `## Current Position`; tolerate
  `## Current Phase` as a fallback. Report upstream.
- **D-07:** The reference's `gsd-tools.cjs` state step has no Codex analogue —
  `~/.codex/get-shit-done/` ships references/workflows/templates and **no `bin/`**.
  Omit that step. This makes D-06 load-bearing: STATE.md is Codex's *only*
  workflow-state source, where on Claude the node step masks the bug.
- **D-08:** Grandfather explicitly — legacy bare-number layout
  (`phases/<NN>/PLAN.md`) → allow; `*-SUMMARY.md` present in resolved phase →
  allow; no `*-PLAN.md` at all → allow.
- **D-09:** The legacy check is not redundant with the mtime step. The `*-PLAN.md`
  glob cannot match a bare `PLAN.md`, so legacy never resolves *through step 3* —
  but steps 1–2 can resolve a legacy directory. The explicit check makes legacy
  grandfathering a stated rule rather than an emergent property of a glob.

### Block behavior + escape hatches

- **D-10:** `exit 2` → hard stop. Print the block message naming the remedy command
  and both escape hatches; the agent stops. Do **not** auto-invoke external
  reviewers — that would ship plan content to other vendors without consent.
- **D-11:** Port both escape hatches from the reference: `GSD_SKIP_REVIEWS=1`
  (session-level, emergency) and a per-phase `multi-ai-review-skipped` marker file.
  These keep a machine without two vendor CLIs from being hard-trapped.

### REVIEWS.md schema + verifier strictness

- **D-12:** Adopt the family-wide REVIEWS.md schema verbatim for cross-host
  compatibility (ADR-0007 p5 exists to support a codex+claude tree). Frontmatter:
  `phase`, `reviewers: []`, `reviewed_at`, `plans_reviewed: []`,
  `overall_verdict: {}`, `recommendation`. Body: `# Cross-AI Plan Review — Phase N
  (title)` then a `## <Reviewer> Review` section per reviewer, verbatim, plus a
  consensus synthesis.
- **D-13:** **Supersedes the loose-verifier decision in
  `docs/briefs/plan-review-gate.md`.** The verifier parses the `reviewers:`
  frontmatter array and blocks when fewer than 2. When frontmatter is absent
  (hand-written file), fall back to the ≥5-line non-emptiness check rather than
  false-blocking. The brief's coupling objection does not apply — the schema is a
  family-wide convention, not one producer's format.
- **D-14:** `min_reviewers` remains the producer's contract as well:
  `codex-plan-review` reports and refuses rather than emitting a one-reviewer file.

### Reviewer composition + prompt

- **D-15:** Vendor-diverse external CLIs (`claude`, `gemini`, `opencode`); require
  ≥2. Exclude `codex` — the implementing host self-skips. GSD already has this
  convention (on Claude, `CLAUDE_CODE_ENTRYPOINT=cli` triggers the self-skip).
- **D-16:** The prompt carries `<NN>-CONTEXT.md` + all `<NN>-*-PLAN.md` + the
  phase's `Canonical refs` resolved from ROADMAP.md, with explicitly adversarial
  framing ("assume the plan is wrong; find what breaks"). Reviewers must be able to
  check the plan against the spec text it cites.

### Scope / conformance

- **D-17:** `implements_spec` stays `0.4.0`. It tracks the last full conformance
  audit, not one gate (`CHANGELOG.md:88-91`).
- **D-18:** Do not migrate `.planning/phases/` 00–07 to GSD-native layout.
- **D-19:** Migration `0008`, idempotent: `jq` merge of `pre_execution` (preserves
  existing keys, skips if present); the AGENTS.md section extracted from the
  template rather than a heredoc (single source of truth — the 0007 lesson);
  version bumps.
- **D-20:** Collapse the duplicate `tdd` row in the `AGENTS.md` bindings table so it
  reads 16 distinct gates, matching `spec/02`.

### Claude's Discretion

- The codex self-skip detection mechanism (which env var identifies a codex
  session, analogous to `CLAUDE_CODE_ENTRYPOINT`).
- Exact verifier install path and symlink shape — follow the convention the two
  Unreleased migration-discovery fixes established (stable
  `${CODEX_HOME}/skills/.../` path, committed symlink), since both of those bugs
  were relative-path resolution failures.
- Whether and how the verifier behaves in `codex exec` / non-interactive contexts.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The gate being bound
- `../agenticapps-workflow-core/spec/02-hook-taxonomy.md` §"Pre-execution gate" (lines 81–109) — the normative `plan-review` definition: trigger, evidence artifact, binding guidance, resolution order, grandfather rule, and the host-conformance note naming this repo.
- `../agenticapps-workflow-core/spec/09-conformance.md` — conformance levels; the `full` rules for binding every applicable gate. NOTE: line 61 says "Section 02 enumerates 15 gates" — it enumerates 16. Upstream bug; do not treat 15 as authoritative.
- `../agenticapps-workflow-core/spec/00-overview.md` lines 96–99 — establishes that declarative hooks are spec-legal, which D-01 relies on.

### Reference implementation (port with care)
- `../claude-workflow/templates/.claude/hooks/multi-ai-review-gate.sh` — the reference resolver, grandfather guard, escape hatches, and exit codes. **Its step 2 is dead code (see D-06). Do not port verbatim.**
- `../claude-workflow/docs/decisions/0025-fix-multi-ai-review-gate-resolution.md` — why single-mutable-pointer resolution is non-conformant.
- `../claude-workflow/docs/decisions/0018-multi-ai-plan-review-enforcement.md` — the cparx failure this gate exists to close.

### This repo's constraints
- `docs/briefs/plan-review-gate.md` — the approved design brief. **D-13 supersedes its loose-verifier section.**
- `docs/decisions/0007-bind-upstream-gsd.md` — the thin-binding stance; point 4 (GSD-native layout), point 5 (namespaced hook config, codex+claude coexistence).
- `AGENTS.md` lines 117, 122–139 — the hook-bindings table this phase extends.
- `.planning/config.codex.json` — the declarative binding map (note: its own `implements_spec` reads `0.1.0` while its template reads `0.4.0` — pre-existing drift, out of scope).
- `migrations/0007-knowledge-capture.md` — the pattern to mirror: ritual-tail wiring on AGENTS.md + trigger skill, template-extracted migration text, `jq` merge idempotency.
- `CHANGELOG.md` lines 88–91 — why `implements_spec` is not bumped here.

### Artifact schema
- `../agenticapps-dashboard/.planning/phases/DASH-11-coverage-trends-skill-drift/11-REVIEWS.md` — a real REVIEWS.md exhibiting the family-wide schema D-12 adopts.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` — the template backing `.planning/config.codex.json`; the `pre_execution` block must land here *and* in this repo's own config.
- `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md` — where the AGENTS.md ritual section is authored so migrated == fresh (the 0007 single-source pattern).
- `migrations/run-tests.sh` — the harness (89 PASS / 0 FAIL / 1 SKIP at 0.5.0); gains `test_migration_0008` plus verifier fixtures.
- `skills/codex-spec-review/` — precedent for an authored `codex-*` gate skill, since upstream ships no `gsd-review` for Codex.

### Established Patterns
- **Declarative hook binding** — all 15 gates live in `config.codex.json` grouped `pre_phase` / `per_task` / `post_phase` / `finishing`. This phase adds a `pre_execution` group.
- **Stable installed paths** — the two Unreleased fixes replaced relative migration paths with `${CODEX_HOME}/skills/<skill>/...` plus a committed symlink. The verifier must follow this or it will not resolve from a target repo.
- **Template-extracted migration text** — never heredoc prose that also ships in a template.

### Integration Points
- `AGENTS.md` — bindings table + new ritual section (always-loaded surface).
- `skills/agentic-apps-workflow/SKILL.md` — trigger skill mirrors the ritual section.
- `.planning/STATE.md` — newly created this phase; it is what makes resolver step 2 exercisable in this repo at all.

</code_context>

<specifics>
## Specific Ideas

- The block message should read like the reference's: state what is missing, give the exact remedy command, then name both overrides as emergency-only.
- REVIEWS.md should record reviewer provenance honestly, including which CLIs were unavailable — the dashboard example does this in prose and it is useful.

</specifics>

<deferred>
## Deferred Ideas

- **Native `~/.codex/hooks.json` PreToolUse enforcement** — Codex ships the surface; point it at the same verifier. Needs a self-scoping guard (global hooks fire in every repo) and a trust-ledger story. Own phase.
- **§14 prompt-injection defense** — spec v0.6.0. Applicability turns on whether ADR-0002's `codex exec` reviewer path counts as an LLM prompt-building surface; the repo has never adjudicated it. `injection-guard` already ships to Codex via `agenticapps-observability/install-codex.sh`, so it is wiring, not authoring. Own phase.
- **`implements_spec` 0.4.0 → 0.5.0** — requires the full audit the field represents, not just this gate.
- **Migrate `.planning/phases/` 00–07 to GSD-native layout** — closes ADR-0007 point 4 non-compliance.
- **Upstream bug report to `claude-workflow`** — resolver step 2 greps a heading no STATE.md uses (D-06).
- **Upstream bug report to `agenticapps-workflow-core`** — `spec/09:61` says 15 gates; `spec/02` defines 16. Also the stale `reference-implementations/README.md` row for this host.

</deferred>

---

*Phase: 8-Plan-Review Gate*
*Context gathered: 2026-07-14*
