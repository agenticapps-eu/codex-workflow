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

## Current State

**Shipped: v0.7.0 Region-Aware §11 Placement** (2026-07-16) — Phases 9 + 9.1,
12 plans, 21/21 requirements. Migration chain now runs 0000–0009. Local suite:
369 PASS / 0 FAIL / 1 SKIP. Previous: v0.6.0 Plan-Review Gate (2026-07-15).

The §11 placement defect this milestone existed to close is closed, and the
data-loss defects the work itself surfaced are closed with it. §11 now anchors
above a leading GitNexus region; migration 0009 heals states A–D and — after 9.1 —
actually executes on real target projects rather than aborting `exit 3` on every
install.

**Active: v0.8.0 Enforcement, Not Intention** (started 2026-07-16) — see Current
Milestone below. Scope is the full carried-debt set: every gate this host claims
to bind, but does not enforce.

## Current Milestone: v0.8.0 Enforcement, Not Intention

**Goal:** Every gate this host claims to bind actually fires, every migration
actually runs, and every assertion has been observed failing — closing the
"nominal enforcement" debt class the last two milestones shipped on top of.

**Target features:**

- **`CI-01` — CI that can fail.** `.github/workflows/ci.yml` is still the Phase 0
  placeholder (`echo` + `exit 0`), under a comment promising "real checks land in
  Phase 7" — Phase 7 shipped and they never did. Replace it with a workflow
  running `migrations/run-tests.sh` (369 assertions) plus the drift check, on
  `submodules: recursive`. Two milestones have now merged on a *local* green;
  the retrospective names this as the enabling condition behind v0.7.0's dominant
  failure mode. **Lands first** — it is the prerequisite for trusting every other
  fix in this milestone.
- **Migration `0007`'s chain break.** Its pre-flight greps
  `skills/agentic-apps-workflow/SKILL.md`, a scaffolder-relative path no target
  project has; `0008:67` states outright that it "aborts with exit 3 on every real
  install." Hypothesis for research to settle: this may sever the chain rather
  than stall one migration — 0007 aborts → never writes `0.5.0` to
  `.codex/workflow-version.txt` → 0008's floor (`^0\.(5|6)\.0$`) aborts → 0009's
  floor (`^0\.(6|7)\.0$`) aborts, so every migration since 0007 is dead for
  existing installs upgrading from 0.4.0, and spec §15 knowledge capture never
  reached them. Fresh scaffolds are likely unaffected (born at current version).
  Fix is a new forward migration per 0008's `.codex/workflow-version.txt`
  precedent, which also drops 0007's MIGR-09 scaffolder-version bump.
- **`HOOK-01` — the plan-review gate blocks.** Bind `check-plan-review.sh` to the
  native `~/.codex/hooks.json` `PreToolUse` surface — it already carries `--file`
  for exactly this. Restates ADR-0009 criterion 1 as an unconditional block;
  supersedes d.9's "agent-mediated" acceptance.
- **Paired §11 start/end markers** — ADR-0010's lead open follow-up. Bound the
  managed block explicitly instead of inferring its extent, retiring the
  inference-based defect class rather than hardening instances. Durable fix for
  AG-01's region-tail hazard.
- **`MIGR-08` execution coverage** — a fixture that runs the Apply block and
  asserts the written `.codex/workflow-version.txt`. The one residual of the exact
  class Phase 9.1 existed to close.
- **`WR-03` — acceptance reversed.** A real symlink-resolution guard replacing the
  lexical-`..`-only check. ADR-0009 d.12 amended to record the reversal.
- **`09-REVIEW.md` debt** — WR-05 (banner determinism), IN-01 (`extract_step_block`
  prefix-matching `### Step 1` vs `### Step 10`), IN-02 (unasserted line drop),
  IN-03 (ADR/migration numbering collision), IN-04 (predictable temp-file names
  in CWD).

**Milestone constraints:**

- **Phase numbering continues from 9.1 → starts at Phase 10.** No reset.
- **Migration immutability holds.** 0007 is never edited; every fix is a new
  forward migration. Same for 0001/0004.
- **Paired markers must respect the widened three-way terminator invariant**
  during transition (see Constraints). `12-idempotent-rerun` is the live guard.
- **This repo's own standard applies to this milestone's work:** a guard is not
  shipped until it has been observed failing. With CI-01 landing first, later
  phases gate on real CI rather than a local green.
- Two ADRs get **amended, not superseded**: ADR-0009 (d.9 → HOOK-01, d.12 → WR-03)
  and ADR-0010 (AG-01 closure).

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

<!-- All scoped into v0.8.0 Enforcement, Not Intention. REQ-IDs assigned in
     REQUIREMENTS.md; phase mapping in ROADMAP.md. -->

**Every item below is in v0.8.0's scope** — the milestone deliberately takes the
whole carried-debt set rather than a slice, because these are one defect class
(enforcement that is nominal rather than real), not seven unrelated chores:

- [ ] **`CI-01`** — CI is still a placeholder; two milestones shipped on a local
      green. Lands first in the milestone.
- [ ] **Migration `0007`'s pre-flight defect** — scaffolder-relative path aborts
      `exit 3` on every real install (`0008:67`). Possibly a chain break rather
      than V-01's twin; research settles the blast radius.
- [ ] **`HOOK-01`** — plan-review gate is agent-mediated, not enforced (ADR-0009
      d.9). Bind to native `~/.codex/hooks.json` `PreToolUse`.
- [ ] **AG-01 / paired §11 markers** — region-*tail* strip hazard, accepted and
      disclosed 2026-07-16. Unreachable via 0001/0004, which land §11 at the
      region head. **The acceptance is now reversed:** paired start/end markers
      are the durable fix and are in scope.
- [ ] **MIGR-08 execution coverage** — no fixture runs the Apply block and asserts
      the resulting `.codex/workflow-version.txt` content. Correct by inspection
      and reachable now that V-01 is fixed, but untested. Flagged by Phase 9.1's
      verification as the one residual of the exact class that phase existed to
      close.
- [ ] **`WR-03`** — `--file` symlink-traversal guard is lexical-`..`-only.
      **Acceptance reversed** (was ADR-0009 d.12): gets a real resolution guard,
      and d.12 is amended to record the reversal.
- [ ] **`09-REVIEW.md` WR-05 + IN-01..IN-04** — banner determinism; extractor
      prefix-matching `### Step 1` vs `### Step 10`; unasserted line drop;
      ADR/migration numbering collision; predictable temp-file names in CWD.

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

- **The §11 placement defect is closed (v0.7.0).** It was: the injector anchored
  before the first `## ` heading; in an AGENTS.md leading with a GitNexus block
  that heading is `## Always Do`, *inside*
  `<!-- gitnexus:start -->…<!-- gitnexus:end -->`, so the next `gitnexus analyze`
  regenerated the region and silently destroyed the block. Migration 0009 heals
  it. This host was never live-broken — the defect was latent here (§11 at L18,
  region at L271–313, so the region does not lead the file) and the fix is for
  projects *scaffolded by* this host, plus self-protection.
- **Migration 0001/0004's naive anchor sites are immutable and stay as they are.**
  Migrations are fixed forward, never edited; 0009 heals what they produced. The
  third site — `migrations/run-tests.sh:119`, which inlined its own copy of the
  injection awk — was the real drift hazard and is retired (TEST-04): the suite now
  extracts each migration's shell from the document itself.
- **Setup has no placement logic of its own — confirmed and recorded (SETUP-01).**
  `0000-baseline.md:102` is a plain `cat templates/agents-md-additions.md >>
  AGENTS.md` append and that template carries no §11; §11 reaches a project only
  via migration 0001's replay. There is no second anchor to keep in parity, unlike
  claude-workflow (which shipped an anchor fix into its migration but not its
  setup). The v0.7.0 open question — whether setup always replays 0000 → latest —
  resolved: setup's end state ≡ full replay, so it inherits 0009's fix for free.
  The fact is recorded at `setup-codex-agenticapps-workflow/SKILL.md:129-134`
  pointing at ADR-0010, so a future anchor change knows where to look.
- **Provenance idiom:** managed AGENTS.md content sits between
  `<!-- BEGIN: agentic-apps-workflow sections -->` and its END marker; the §11
  block additionally carries `<!-- spec-source: agenticapps-workflow-core@0.4.0
  §11 -->`. The regexes matching it are anchored at all four sites (CR-02) — an
  unanchored match let a backticked prose mention trigger the strip.
- **Upstream relationship.** v0.7.0 was a port of claude-workflow's migration 0029,
  an ADR-0037-pattern propagation. Two lessons worth carrying: upstream's HEAD is
  `f9354cc` (PR #89's squash), *not* the `8520f90` PR-branch commit the phase
  originally pinned — a dead pin cited four times before review caught it; and our
  port dropped upstream's `.claude/` path prefix, producing V-01. Porting errors
  here look like upstream defects; check the prefix before filing.
- **This repo's own GitNexus content is not generated into AGENTS.md/CLAUDE.md**
  (2026-07-16, `38e3478`). `analyze --skip-agents-md` is standing. The one useful
  instruction (prefer the GitNexus MCP graph over blind grep) lives once in
  `~/.codex/AGENTS.md`, whose load path was verified empirically on codex-cli
  0.144.4 — ADR-0001's A2 had asserted it without observing it.

## Constraints

- **Compatibility**: Migrations are append-only and immutable once shipped —
  a defect in a past migration is fixed by a new one, never by an edit.
- **Tech stack**: POSIX shell + awk inside markdown migration documents; fixtures
  are bash (`migrations/run-tests.sh`). No new runtime dependencies.
- **Structural invariant (widened in v0.7.0 — read this before narrowing any
  terminator)**: the injected §11 block must remain followed by a `## ` heading,
  an anchored `<!-- gitnexus:start -->` marker, **or** EOF. That boundary is what
  bounds the managed section for replace/rollback in 0004 and any future revendor,
  and **every terminator that bounds it must carry this same three-way
  alternation**. The pre-v0.7.0 wording ("a `## ` heading or EOF") is false by
  construction: 0009 anchors the block immediately before a leading
  `gitnexus:start`, so a healed region-led file is followed by that marker, not a
  `## `. A terminator matching only `/^## /` runs past the marker and consumes the
  entire GitNexus region. v0.7.0 did not preserve this invariant — it widened it
  (ANCHOR-05). `12-idempotent-rerun` is its live guard: narrowing the alternation
  fails the suite.
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
| The §11 structural invariant is **widened**, not preserved | The original "followed by `## ` or EOF" wording is false by construction once §11 anchors above a leading region; a terminator matching only `/^## /` eats the whole GitNexus region | ✓ Good — corrected mid-planning after research falsified the stated rationale (ANCHOR-05) |
| Phase 9 closed on Phase 9.1's evidence rather than being re-scored in place | Every gap `09-VERIFICATION.md` recorded was deferred to 9.1 by that document's own Gaps Summary, and 9.1 closed each; closure recorded as a dated Gap Closure Record | ✓ Good — preserves what was true then, disposition is auditable |
| AG-01 (region-*tail* strip hazard) accepted and disclosed, not fixed | Not reachable via 0001/0004, which land §11 at the region head; the durable fix is paired §11 markers, which retires the class rather than patching this instance | — Pending — ADR-0010's lead open follow-up |
| Only CR-01 filed upstream; V-01 deliberately withheld | V-01 is a codex-side porting error (we dropped upstream's `.claude/` prefix), not upstream's defect — filing it would misattribute our bug | ✓ Good — [claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90) |
| GitNexus generated content kept out of AGENTS.md / CLAUDE.md | Regenerated regions churn managed files and are the very hazard §11 placement fights; `analyze --skip-agents-md` is standing | ✓ Good — `38e3478`; the one useful instruction lives once in `~/.codex/AGENTS.md`, load path empirically verified |

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
*Last updated: 2026-07-16 at the start of milestone v0.8.0 (Enforcement, Not
Intention). Current State now carries the milestone's goal, scope, and
constraints; Active was re-scoped from "carried debt, unscheduled" to "all of it,
in v0.8.0". Two acceptances are deliberately reversed by this milestone — WR-03
(ADR-0009 d.12) and AG-01 (ADR-0010's disclosed region-tail hazard) — and
ADR-0009 d.9's "agent-mediated" plan-review binding is superseded by HOOK-01.
Migration 0007's pre-flight defect was re-characterized during scoping: `0008:67`
states it aborts on every real install, which may sever the chain at 0007 rather
than stall one migration; flagged as a research question, not a finding.*

*Prior update: 2026-07-16 after v0.7.0 (Region-Aware §11 Placement) shipped and
was archived. Full evolution review performed at milestone close: the structural
invariant in Constraints was corrected (it stated the pre-v0.7.0 wording that
ANCHOR-05 falsified), Context was rewritten from milestone-scoped to current
state, six v0.7.0 decisions were logged, and Active was re-scoped to carried debt.
Suite at 369 PASS / 0 FAIL / 1 SKIP. Upstream CR-01 filed as
[claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90)
(OPEN).*
