# codex-workflow

## What This Is

`codex-workflow` is the OpenAI Codex CLI host binding for the AgenticApps
spec-first workflow defined by `agenticapps-workflow-core`. It is a thin binding
over upstream GSD and Superpowers (ADR-0007) — not a re-port of them. It ships a
scaffolder (`setup-codex-agenticapps-workflow`), a numbered migration chain that
carries existing installs forward, and the host-side skills and verifiers that
bind the core spec's gates on Codex.

Its users are AgenticApps projects that run on the Codex CLI host, plus the
maintainer propagating core-spec changes across host repos.

## Core Value

Projects on the Codex host get the same spec-first gates, in the same shape, as
every other host — installed by scaffold or carried forward by migration, without
hand-editing.

## Current Milestone: v0.7.0 Region-Aware §11 Placement

**Goal:** Ship migration 0009 so the spec §11 Coding Discipline block anchors
above a leading GitNexus region instead of inside it, closing a latent
block-destruction defect for projects this host scaffolds.

**Target features:**

- Migration `0009-spec-11-region-aware-placement.md` (`0.6.0` → `0.7.0`) healing
  all four states: no-op when correctly anchored, move when inside a region,
  inject when absent, refuse (`exit 3`) on a hand-pasted block with no provenance.
- The region-aware anchor rule, with its rejected alternative recorded.
- Empirical validation of the rule against real AGENTS.md files before the
  migration is written.
- A TDD fixture suite that extracts the migration's shell from the document
  rather than inlining a copy of it.
- An ADR recording the anchor decision.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ Spec §02 `plan-review` pre-execution gate bound on the Codex host —
  declarative binding + `check-plan-review.sh` verifier + `codex-plan-review`
  producer skill + migration 0008 — v0.6.0 (Phase 8), ADR-0009.
- ✓ Migration chain 0000–0008 with an atomicity contract, per-step idempotency
  checks, and a 278-assertion local harness (`migrations/run-tests.sh`).
- ✓ Spec §11 Coding Discipline injected verbatim from a byte-identical spec
  mirror rather than transcribed — migrations 0001/0004.
- ✓ Region-aware §11 anchor rule, validated empirically before adoption, and
  re-proven live under mutation in Phase 9.1 (narrowing the terminator
  alternation breaks `12-idempotent-rerun`) — v0.7.0 (Phases 9, 9.1), ADR-0010.
- ✓ Migration 0009 healing states A–D, and — after Phase 9.1 — actually running
  on real target projects: its pre-flight now reads `.codex/workflow-version.txt`
  instead of a scaffolder-only path no consumer has. Validated in Phase 9.1.
- ✓ Fixture suite sourced from the migration document, not a copy — extended in
  Phase 9.1 to 345 assertions, with the sandbox no longer manufacturing the
  precondition under test.
- ✓ ADR recording the anchor decision and its rejected alternative — ADR-0010,
  corrected in Phase 9.1 (D-26's "bounded by construction" claim was falsified
  and is now recorded as false; the dead `8520f90` pin re-pinned to `f9354cc`).

### Active

<!-- Current scope. Building toward these. See REQUIREMENTS.md for REQ-IDs. -->

- [ ] MIGR-08 execution coverage: no fixture runs Step 2's Apply block and
      asserts the resulting `.codex/workflow-version.txt` content. Correct by
      inspection and reachable now that V-01 is fixed, but untested — flagged by
      Phase 9.1's verification as the one residual of the exact class that phase
      existed to close.

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- **The `implements_spec` version gap** — `implements_spec` appears in 13+ files
  with no single authoritative one. Resolving it is separate work (cf. ADR-0019's
  "declared paths, not discovered"); absorbing it here would blur a placement fix
  into a spec-versioning change.
- **Editing migrations 0001/0004** — they are immutable. Their `to_version` is
  long past so they never replay, and their pre-flight gate aborts the
  `--migration NNNN` force path. Fix forward only.
- **Moving a healthy §11 block that merely sits off the canonical anchor** — no
  failure mode motivates it and it churns project files.
- **Back-filling phases 00–07 into ROADMAP.md** — they predate this repo's GSD
  adoption; reconstructing them would invent history.
- **The "anchor before `gitnexus:start` if a region exists, else the first
  `## `" rule** — rejected. When the region starts late in the file it drops §11
  hundreds of lines down, violating §12's placement advisory. The region is only
  the anchor when it comes first.

## Context

- **This host is currently safe; the defect is latent, not live.** Verified
  2026-07-15: `AGENTS.md` carries §11 at L18 and the GitNexus region at L271–313,
  so the region does not lead the file and nothing is being destroyed today. This
  milestone is a placement fix for projects *scaffolded by* this host, plus
  self-protection. Unlike claude-workflow, there is no broken repo to repair.
- **The defect:** the §11 injector anchors before the first `## ` heading. In an
  AGENTS.md that leads with a GitNexus block, that heading is `## Always Do`,
  *inside* `<!-- gitnexus:start -->…<!-- gitnexus:end -->`. The next
  `gitnexus analyze` regenerates the region and silently destroys the block.
- **Three naive-anchor sites** (`/^## / && !done`), all verified 2026-07-15:
  `migrations/0001-inject-spec-11-coding-discipline.md:91`,
  `migrations/0004-revendor-spec-11.md:77`, and — not named in the source prompt —
  `migrations/run-tests.sh:119`, which inlines its own copy of the injection awk.
  That third site is the exact drift hazard this milestone must not reproduce.
- **The setup path has no placement logic of its own** (verified 2026-07-15).
  `0000-baseline.md:102` is a plain `cat templates/agents-md-additions.md >>
  AGENTS.md` append, and that template contains no §11. §11 reaches a project only
  via migration 0001's replay. So unlike claude-workflow — which shipped an anchor
  fix into its migration but not its setup — there is no second anchor to keep in
  parity here. Open question for the brainstorm: whether setup always replays
  0000 → latest (`SKILL.md:111` phrases it conditionally), since that determines
  whether setup inherits 0009's fix for free.
- **Provenance idiom:** managed AGENTS.md content sits between
  `<!-- BEGIN: agentic-apps-workflow sections -->` and its END marker; the §11
  block additionally carries `<!-- spec-source: agenticapps-workflow-core@0.4.0
  §11 -->`.
- **Reference design:** claude-workflow's migration 0029, at
  `docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` in
  that repo. This is an ADR-0037-pattern propagation of it.

## Constraints

- **Compatibility**: Migrations are append-only and immutable once shipped —
  a defect in a past migration is fixed by a new one, never by an edit.
- **Tech stack**: POSIX shell + awk inside markdown migration documents; fixtures
  are bash (`migrations/run-tests.sh`). No new runtime dependencies.
- **Structural invariant**: the injected §11 block must remain followed by a `## `
  heading or EOF — that boundary is what bounds the managed section for
  replace/rollback in 0004 and any future revendor.
- **Process**: Feature branch + PR to main; never commit to main.
- **Dependencies**: The harness hard-fails without the
  `vendor/agenticapps-shared` submodule (`submodules: recursive`).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Thin binding over upstream GSD + Superpowers, not a re-port (ADR-0007) | Upstream evolves; a re-port forks and rots | ✓ Good |
| GSD roadmap tracking starts at Phase 8; 00–07 stay legacy | Back-filling would invent unsourceable history | ✓ Good |
| Plan-review gate is agent-mediated, not enforced (ADR-0009 d.9) | Native `PreToolUse` hook surface deferred to its own phase | ⚠️ Revisit |
| §11 injected verbatim from a spec mirror, never transcribed | Byte-identity with core spec is checkable; transcription drifts | ✓ Good |
| Region-aware anchor: first `## ` **or** `gitnexus:start`, whichever comes first | One-alternation delta preserves the structural invariant; the region-only alternative violates §12 placement | ✓ Good — held under mutation (Phase 9.1) |
| A migration records its version in the TARGET project (MIGR-08), never bumps this scaffolder's own files (MIGR-09) | Phase 9 conflated them and shipped a Step that wrote scaffolder files into consumers' repos; 0008 had kept them apart on purpose | ✓ Good — Step deleted in Phase 9.1 |
| A guard is not shipped until it has been observed failing | Phase 9 shipped 314 PASS / 0 FAIL on a migration that never ran; assertions that cannot fail read as coverage | ✓ Good — mutation gate, Phase 9.1 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Created: 2026-07-15 at the start of milestone v0.7.0 — this repo had no
PROJECT.md through v0.6.0 (see STATE.md); content here is sourced from ROADMAP.md,
STATE.md, ADR-0007, ADR-0009, and direct verification of the working tree.*
*Last updated: 2026-07-15 after Phase 9.1 (§11 Strip Runaway) — the last phase of
milestone v0.7.0. Migration 0009's data-loss paths are closed and the suite is at
345 PASS / 0 FAIL / 1 SKIP. Upstream CR-01 filed as
[claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90).
All v0.7.0 phases are complete; the milestone is ready for
`/gsd-complete-milestone`.*
