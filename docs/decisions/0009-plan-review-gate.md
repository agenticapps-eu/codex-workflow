# ADR-0009: Bind the plan-review pre-execution gate on the Codex host

**Status**: Accepted  **Date**: 2026-07-15
**Core contract**: `agenticapps-workflow-core/spec/02-hook-taxonomy.md` §"Pre-execution gate" (lines 81-109)
**Sibling host**: claude-workflow ADR-0025 / migration-0016

## Context

Core spec v0.5.0 added a `plan-review` pre-execution gate to `spec/02` and
names this repo as an outstanding follow-up:

> **Host conformance (follow-up):** claude-workflow implements this resolver
> and grandfather guard as of spec 0.5.0 (ADR 0025 / migration 0016).
> codex-workflow and pi-agentic-apps-workflow MUST adopt the identical
> resolution order and grandfather rule to stay conformant — tracked as a
> follow-up, not yet implemented.
> — `spec/02-hook-taxonomy.md:105-109`

`claude-workflow` is the reference host and already ships the resolver and
grandfather guard this ADR mirrors. Five forces make the Codex mirror
non-trivial rather than a drop-in port:

1. **The codex hook model is declarative.** All 15 pre-0.5.0 gates bind
   through `.planning/config.codex.json` (ADR-0007 point 5); no script
   executes it, the agent reads it. This is spec-legal (`spec/00:96-99`).
2. **Codex CLI 0.144.4 ships a native runtime hook surface this repo does
   not use** — `PreToolUse`/`PostToolUse`/`SessionStart`, global rather than
   per-project, with a sha256 trust ledger.
3. **Upstream Codex GSD ships no `gsd-review`** — the same gap ADR-0007
   noted for `gsd-debug`. Binding upstream is not an option; the producer
   skill is authored in this repo instead.
4. **No `bin/gsd-tools.cjs` on Codex**, so the reference resolver's
   node-based state-lookup step has no analogue — 5 reference steps become
   the spec's 4 (D-07).
5. **This repo's own `.planning/phases/` 00-07 is the pre-0005 bare-number
   layout**, so every prior phase is grandfathered and phase 09 is the
   gate's first genuinely enforced phase. Phase 08 itself is not — see
   decision 8 below (the bootstrap paradox).

## Options considered

### A. Declarative-only

Enforcement rests entirely on the agent reading and honoring the
`config.codex.json` binding, exactly like the other 15 gates. **Rejected**:
this declines the `spec/02:92-93` SHOULD, and rests enforcement on agent
compliance — the exact failure mode core ADR-0018 closes (cparx phases
04.9 → 05 silently dropped multi-AI plan review for 8 consecutive phases
with no programmatic check to catch it).

### B. Native `~/.codex/hooks.json` `PreToolUse`

Wire the gate into Codex's native runtime hook surface, which can genuinely
intercept a tool call before it executes. **Rejected for this phase,
deferred rather than declined**: the hook is global, so it fires in every
repo on the machine and must self-scope; the sha256 trust ledger forces a
re-grant every time a migration edits the hook config; and it introduces a
second enforcement mechanism alongside the declarative map without first
establishing what the verifier should even check. It is the documented
upgrade path — see decision 9 — and can point at the same verifier this ADR
authors.

### C. Hybrid: declarative binding + verifier script — chosen

The declarative binding in `config.codex.json` stays the source of truth,
consistent with the other 15 gates and ADR-0007's thin-binding stance; a
shell verifier supplies the programmatic enforcement `spec/02:92-93` calls
for, without inheriting native `PreToolUse`'s global-scope and trust-ledger
problems.

## Decision

1. **Hybrid mechanism (D-01).** The `config.codex.json` binding stays the
   source of truth, consistent with the other 15 gates and ADR-0007's
   thin-binding stance; a shell verifier
   (`skills/agentic-apps-workflow/scripts/check-plan-review.sh`) supplies the
   programmatic enforcement. The `pre_execution.plan_review` binding carries
   a `verifier` key — new; no other gate carries one — because this is the
   one gate in the family that pairs a declarative binding with a
   programmatic check rather than trusting agent compliance alone.

2. **Resolution order (D-05) and the reference's defects (D-06, D-07).**
   The verifier resolves the active phase in the spec's documented order:
   explicit pointer → `.planning/STATE.md` → newest `*-PLAN.md` by mtime →
   fail-open. Porting the reference (`multi-ai-review-gate.sh`) surfaced
   exactly three defects, corrected in this repo's port:
   - The reference greps `^##[[:space:]]+Current Phase`
     (`multi-ai-review-gate.sh:96`) — a heading no real `STATE.md` in the
     fleet writes; every one writes `## Current Position`. Fixed by matching
     `## Current Position` and tolerating `## Current Phase` as a fallback.
   - The reference's `gsd-tools.cjs` node-based state lookup
     (`multi-ai-review-gate.sh:105-111`) has no Codex analogue —
     `~/.codex/get-shit-done/` ships no `bin/`. Omitted entirely, which
     makes the heading fix load-bearing: `STATE.md` is Codex's *only*
     workflow-state source, where on Claude the node step masks the bug.
   - **The third defect, found while planning this phase:** even with the
     heading fixed, the reference's line regex
     `[Pp]hase[[:space:]]+[0-9]+(\.[0-9]+)?` cannot match the canonical
     `Phase: NN` line, because `[[:space:]]+` must match the character
     immediately after `hase`, and that character is a colon. Verified by
     execution: `echo 'Phase: 08 (Plan-Review Gate) — DISCUSSING' | awk
     '{if (match($0, /[Pp]hase[[:space:]]+[0-9]+/)) print "MATCH"; else print
     "NO MATCH"}'` prints `NO MATCH`. So the regex silently matches the
     first *incidental* prose mention of a phase number instead — verified
     against `claude-workflow`'s own `STATE.md`, where it resolves phase 24
     from the words "Phase 24 (most recent shipped)", the most recently
     *shipped* phase, not the active one. Fixed by tolerating an optional
     colon and anchoring on the canonical `Phase:` line rather than free
     prose. This is the D-06 fix's other half, not a new decision.

   The four additional items plan `08-01` adds — root self-location, STATE
   section bounding, decimal padding, ambiguity fail-open, mtime determinism
   — are resolver **requirements** this port must satisfy, closing gaps in
   this repo's own prior plan text. They are not reference defects and are
   excluded from the count above; this ADR records exactly three defects in
   `multi-ai-review-gate.sh` itself.

3. **Explicit grandfather rule (D-08/D-09).** A legacy bare-number phase
   (`phases/<NN>/PLAN.md`), a phase with an existing `*-SUMMARY.md`, and a
   phase with no `*-PLAN.md` at all are all explicitly allowed. The
   explicit legacy check is not redundant with the newest-plan-by-mtime
   step: the `*-PLAN.md` glob cannot match a bare `PLAN.md`, so a legacy
   phase never resolves *through* that step — but the pointer and
   `STATE.md` steps can still resolve one. Naming the check explicitly makes
   legacy grandfathering a stated rule rather than an emergent glob
   property.

4. **`REVIEWS.md` schema adoption and verifier strictness (D-12/D-13/D-14).**
   The verifier parses the family-wide `reviewers:` frontmatter array and
   blocks (`exit 2`) below 2 distinct entries; when frontmatter is absent
   entirely, it falls back to a `>= 5`-line non-emptiness check rather than
   false-blocking a hand-written file. **This supersedes the loose-verifier
   section of `docs/briefs/plan-review-gate.md`**, which argued that parsing
   reviewer count would couple the verifier to one producer's format. That
   argument does not survive contact with the evidence: two real
   in-production artifacts — `agenticapps-dashboard`'s `11-REVIEWS.md` and
   this repo's own `08-REVIEWS.md` — show `reviewers:` is a family-wide
   convention, not a producer-specific format. This is also a deliberate
   divergence from the reference, which warns and allows (`exit 0`) on a
   thin file where this host blocks (`exit 2`). Cross-AI review forced two
   further divergences, both toward fail-closed: a non-regular
   `*-REVIEWS.md` (a FIFO or socket) blocks rather than allowing, and the
   marker-file escape hatch is checked only at the containment-validated
   resolved phase dir, not also at a raw `.planning/current-phase/` path
   that could re-follow a rejected symlink.

5. **Existing-install migration story (D-19).** Migration 0008 is
   idempotent, template-extracted (per the 0007 single-source-of-truth
   lesson), and merges `pre_execution` at the **leaf** of `.hooks` rather
   than the top level. Review found the originally planned shallow merge
   (`.hooks += {pre_execution: $pe}`) would *replace* an existing
   `pre_execution` object wholesale and delete any sibling gate under it —
   directly contradicting D-19's own stated intent that migration 0008
   "preserves existing keys." The leaf-level merge and a rollback that
   removes only `.hooks.pre_execution.plan_review` implement D-19 correctly;
   they do not override it.

6. **`implements_spec` stays 0.4.0 (D-17).** It tracks the last full
   conformance audit, not one gate (`CHANGELOG.md:88-91`). This phase
   delivers the §02 *content* required for a future `0.5.0` claim; it does
   not make that claim here.

7. **Ritual-text wiring only (D-03/D-04).** The gate is invoked via
   `AGENTS.md` ritual text plus the trigger `skills/agentic-apps-workflow/SKILL.md`
   — never wired into `/prompts:gsd-plan-phase`, `/prompts:gsd-execute-plan`,
   or any other upstream GSD ritual, since those are upstream prompts this
   repo does not own. This is the same precedent §15 / migration-0007
   established for knowledge capture, and it is binding here.

8. **The gate does not gate its own construction phase — accepted, not
   worked around.**

   a. **The bootstrap paradox.** This fleet writes one `*-SUMMARY.md` per
      *plan*, not per phase (verified: `agenticapps-dashboard`'s DASH-11
      directory holds `11-01-SUMMARY.md` … `11-06-SUMMARY.md`). The
      grandfather guard (`multi-ai-review-gate.sh:141-142`) fires on ANY
      summary and sits **before** the `REVIEWS.md` check
      (`multi-ai-review-gate.sh:144-145`). Phase 08's own plans each write
      `08-0N-SUMMARY.md`, so from wave 1's completion onward the phase is
      grandfathered and the verifier exits 0 without ever reading
      `08-REVIEWS.md`. The gate is not even live until plan `08-02`'s GREEN
      commit, by which time that first summary already exists. No wave
      reordering fixes this — building the gate requires executing plans.
      **No task in this phase fabricates a passing dogfood run of the
      gate against phase 08 itself** — an artifact manufactured to satisfy
      a gate is precisely the laundering failure the producer's own threat
      register forbids. The phase's gate behavior is instead proven by
      `run-tests.sh`'s synthetic fixtures plus
      `test_check_plan_review_contract`'s real-artifact round trip. Real
      adversarial plan review of this phase **did** happen —
      out-of-band, run by the operator on the planning host before
      execution, producing `.planning/phases/08-plan-review-gate/08-REVIEWS.md`
      from three external reviewers (`gemini`, `codex`, `opencode`). Its
      findings were folded back into the plans before execution. Real
      review, simply not *caused by* the live gate. Phase 09 is the first
      genuinely enforced phase. The brief calls this phase the gate's
      initial live proving ground; that characterization is incorrect and
      is corrected here.

   b. **A newly discovered upstream design issue — recorded as an open
      question, not resolved here.** The grandfather rule conflates two
      different things: "this phase shipped before the gate existed" and
      "this phase's first plan just landed." With one `*-SUMMARY.md` per
      plan, **any** phase that adopts the gate mid-flight is silently
      disarmed from its second plan onward — and because the summary check
      precedes the `REVIEWS.md` check, `REVIEWS.md` is never consulted at
      all for such a phase. This affects `claude-workflow` equally; it is
      not Codex-specific. The open question — should the guard require a
      summary for *every* plan, or compare summary mtime against
      `REVIEWS.md`, or check ordering? — is carried upstream as a question
      for the `claude-workflow` bug report, not resolved unilaterally here:
      a one-host divergence in a rule that decides whether a gate fires
      would be worse than the shared bug, because the two hosts would
      silently disagree about what "grandfathered" means.

   c. **Cross-reference to decision 2.** Both the resolver's two-half defect
      (decision 2) and this grandfather-conflation defect are bugs in the
      same reference implementation (`multi-ai-review-gate.sh`), found by
      porting it. The port *corrects* the resolver, where the fix is local
      and the spec's documented order is unambiguous, but only *reports*
      the grandfather-conflation issue, where the fix would change
      cross-host gate semantics. This asymmetry is deliberate, not an
      oversight.

9. **The gate is agent-mediated by construction — say so, do not overclaim.**
   The mechanism is an `AGENTS.md` ritual instruction plus a verifier
   script. `AGENTS.md` is root-down concatenated, so the instruction is
   always in context — but nothing *executes* it. If the agent omits the
   invocation, no program runs and no edit is blocked. That is the same
   category of compliance failure core ADR-0018 documents. It is still
   worth shipping: a programmatic check an agent is instructed to run is
   strictly stronger than a declarative note an agent is instructed to
   honor (option A) — the verdict is a deterministic exit code computed
   from repo state, not the agent's own judgment about whether review
   happened. It closes the *drift* failure (the reviewer who forgets what
   the rule was) while leaving the *omission* failure open: **an agent that
   never invokes the verifier is not blocked by it.** `exit 2` is a hard
   stop once the verifier runs; it is not a guarantee that it runs.
   ROADMAP.md success criterion 1 was reworded accordingly (plan `08-04`)
   to describe an agent-mediated programmatic check rather than an
   unqualified block. The documented upgrade path is option B's native
   `~/.codex/hooks.json` `PreToolUse` hook, pointed at this same
   verifier — the verifier's `--file` argument exists for exactly that, so
   the upgrade is a wiring change, not a rewrite. It is deferred to its own
   phase (it needs a self-scoping guard, since global hooks fire in every
   repo, and a trust-ledger story for the sha256 re-grant the migration
   would force). When it lands, criterion 1 can be restated without the
   agent-mediated qualifier. Wiring a new enforcement surface in this phase
   was considered and rejected: D-01/D-02 already adjudicated it, and
   re-opening it here would make this phase the hooks phase.

10. **The egress file boundary is advisory, not technically enforced.**
    `codex-plan-review` enumerates the exact file set and vendor list,
    refuses paths outside the phase dir and the ROADMAP-declared canonical
    refs, refuses secret-shaped paths, and requires affirmative operator
    confirmation of the printed manifest before any transmission — consent
    is never implied by invocation. What the control is **not**: the
    reviewer CLIs are agentic, and passing them a file list does not
    constrain what they read — they can reach the whole working tree,
    `$HOME`, and tool configuration regardless of which paths the prompt
    names. This limit is not technically enforced and is stated without
    hedging. The evidence is this repo's own: during the review run that
    produced `08-REVIEWS.md`, the `opencode` reviewer ignored its prompt
    and spent roughly ten minutes autonomously reading the repository and
    executing `migrations/run-tests.sh` before being re-invoked with tool
    use explicitly discouraged — recorded in that file's own provenance
    table. A read-only review bundle — copying only approved files into a
    temporary directory and invoking each reviewer from there — was
    considered and deferred (see Open follow-ups): it would not constrain
    `$HOME` or tool-config access either, so it would buy a
    stronger-sounding claim rather than a stronger control, the opposite of
    what this disclosure is for. The honest residual: plan text reaches up
    to three vendors by design, bounded by the escape hatches for operators
    who decline it.

11. **The `>= 5`-line fallback (D-13) is a known, accepted spoofable
    weakening.** Any five-line file with no frontmatter satisfies it, and
    it is easy to spoof. D-13 keeps it deliberately so a hand-written
    `REVIEWS.md` — the cross-host compatibility case the family schema
    exists to serve (ADR-0007 point 5) — is not false-blocked. It is
    reachable only when frontmatter is entirely absent: malformed
    frontmatter blocks instead, and a present, well-formed frontmatter is
    authoritative. This trade is recorded here deliberately, not reopened —
    a limitation recorded is a limitation a later reader can act on; a
    limitation only the planner knew about is a trap.

## Consequences

Phases 00-07 stay legacy and grandfathered. Phase 08 is grandfathered
against its own gate too (decision 8), so **phase 09 is the gate's first
genuinely enforced phase**. The repo gains a soft dependency on other-vendor
CLIs, bounded by the two escape hatches (`GSD_SKIP_REVIEWS=1`, a
`multi-ai-review-skipped` marker file). A second enforcement mechanism (the
verifier script) now sits alongside the declarative map — decision 9 names
when to collapse them (once the native `PreToolUse` upgrade lands).
Enforcement is agent-mediated until then, and the egress boundary is
advisory (decision 10) rather than technically enforced.

## Verification

`migrations/run-tests.sh`'s `test_check_plan_review_resolver`,
`test_check_plan_review_enforcement`, `test_check_plan_review_contract`, and
`test_migration_0008`; and ROADMAP.md's 7 Phase 8 success criteria.

## Open follow-ups

All recorded as follow-ups, not implemented in this phase. Each upstream
defect below carries the repo, the file and line, what is wrong, and the
executed evidence, so it can be filed upstream as-is rather than
reconstructed by hand.

- **D-02's native `PreToolUse` surface** (decision 9) as the documented
  upgrade path to real enforcement, pointing at the same verifier — note
  the verifier's `--file` argument exists for exactly this, so the upgrade
  is a wiring change, not a rewrite. Needs a self-scoping guard (global
  `~/.codex/hooks.json` fires in every repo) and a trust-ledger story for
  the sha256 re-grant.

- **A read-only reviewer bundle** (decision 10): copy only approved files
  into a temporary directory and invoke each reviewer from there, with no
  access to the original repository. Considered and deferred — it would
  not constrain `$HOME` or tool-config access either, so it would buy a
  stronger-sounding claim rather than a stronger control. Revisit if a
  vendor ships a genuinely sandboxed non-interactive mode.

- **Digest-based review freshness.** The verifier's `plans_reviewed`
  coverage check confirms every current plan was listed at review time, but
  not that a plan's *content* is unchanged since. A content digest per plan,
  recorded at review time and re-checked at gate time, was considered and
  deferred — it needs a hashing scheme, a schema addition every host in the
  family would have to adopt (the D-12 schema is a cross-host convention,
  not this repo's to extend unilaterally), and an answer for the
  whitespace-only-edit case.

  **The coverage half of freshness is also bypassed post-summary** — the
  same grandfather-conflation defect family as decision 8b, in a second
  place. The `plans_reviewed` coverage check sits behind the grandfather
  guard (`multi-ai-review-gate.sh:141-142`), which fires on **any**
  `*-SUMMARY.md`, and this fleet writes one summary per plan. Once a phase
  ships its first plan, the verifier exits 0 at the grandfather step and
  never reaches the coverage check at all. Coverage therefore fires only
  for phases that have not yet shipped a single plan; it is structurally
  unenforceable once any SUMMARY exists for the phase. Without this note, a
  later reader who finds the coverage rule could reasonably assume it
  guards shipped phases too — it does not.

- **`codex-plan-review`'s own producer artifact predates the D-12 schema
  in one respect.** D-12 requires `overall_verdict:` and `recommendation:`
  in frontmatter. This repo's own `08-REVIEWS.md`, produced by the
  planning-host review process before this phase's D-12 schema was locked,
  carries neither key — so the artifact this fleet actually shipped for its
  own planning is not fully D-12-conformant. Plan `08-02`'s contract test
  deliberately asserts against it only the keys the verifier consumes, with
  the full-schema assertions carried by `codex-plan-review`'s own skeleton
  instead. Recorded here so a later reader does not read the split
  assertions as an oversight.

- **Upstream bug reports to `claude-workflow`** — the reference resolver
  defects, three total (decision 2), plus the grandfather-conflation defect
  (decision 8b), carried as an open question rather than resolved
  unilaterally:
  - Dead heading: `multi-ai-review-gate.sh:96` greps
    `^##[[:space:]]+Current Phase`, a heading no real `STATE.md` writes.
  - Colon-blocked line regex: `multi-ai-review-gate.sh:96-103`,
    `[Pp]hase[[:space:]]+[0-9]+` cannot match the canonical `Phase: NN` line
    and silently matches incidental prose instead — verified against
    `claude-workflow`'s own `STATE.md`, which resolves phase 24 from
    "Phase 24 (most recent shipped)."
  - Grandfather-conflation: `multi-ai-review-gate.sh:141-145` — the
    per-plan-summary grandfather guard precedes the `REVIEWS.md` check, so
    any phase adopting the gate mid-flight is silently disarmed from its
    second plan onward.

- **The `update-codex-agenticapps-workflow` skill's multi-hop migration
  chain** selects pending migrations once from the project's initial
  version and never recomputes the current version after each migration is
  applied — a 0.4.0 project selects migration 0007 but not 0008, applies
  0007, lands at 0.5.0, and fails the final target-version check. A real
  defect, found by this phase's cross-AI review, in a different skill,
  outside this phase's own criteria.

- **Upstream bug report to `agenticapps-workflow-core`** — `spec/09:61`
  states "Section 02 enumerates 15 gates," but `spec/02` defines 16 (the
  `plan-review` gate this phase binds is the 16th). Also the stale
  `reference-implementations/README.md` row for this host.

- **Migrating `.planning/phases/` 00-07 to GSD-native layout** — closes
  ADR-0007 point 4 non-compliance; deliberately out of scope for this
  phase (D-18).
