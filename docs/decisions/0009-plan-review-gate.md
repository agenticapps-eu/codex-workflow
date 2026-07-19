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

   **Gap-closure addition (D-15, WR-01).** The strict path enforced reviewer
   COUNT (`>=2` distinct entries) but not IDENTITY: `reviewers: [codex,
   codex-self]` is two distinct strings and zero genuine external
   reviewers — the exact self-review D-15 (`08-CONTEXT.md`) names as
   forbidden ("Exclude `codex` — the implementing host self-skips") — yet it
   passed at exit 0. Reproduced live twice: once during this phase's own
   code review, once again during gap-closure planning. Fixed in plan
   `08-07`: codex-derived reviewer entries (`codex`, `codex-self`,
   `codex_foo`, `"codex bar"`, matched case-insensitively) are now excluded
   from the distinct-count before the `>=2` floor test. Exclusion was chosen
   over a hard-coded vendor allowlist: an allowlist would silently
   false-block a legitimate future vendor, or a cross-host `REVIEWS.md`
   naming a reviewer this host doesn't recognize (the ADR-0007 point 5
   case) — exactly the failure mode D-13's hand-written-file tolerance
   above already exists to avoid. An allowlist also buys nothing against a
   determined spoofer, who already has `touch multi-ai-review-skipped`
   available and accepted under decisions 10/11. Exclusion closes exactly
   the honest mistake D-15 names — counting the implementing host as an
   external reviewer — and nothing more.

   **Residual, recorded and not silently absorbed.** A `REVIEWS.md`
   produced on another host that legitimately used `codex` as an external
   reviewer (e.g. `[codex, gemini]`, written by `claude-workflow` in a
   shared tree) now blocks on this host, where it previously passed. This
   is D-15 applied exactly as written: from codex's own vantage, codex is
   always self-review. Both escape hatches (`GSD_SKIP_REVIEWS=1`, a
   `multi-ai-review-skipped` marker file) remain available if this is a
   false positive in a specific cross-host scenario. This repo's own
   `08-REVIEWS.md` (`[gemini, codex, opencode]`) survives with exactly 2
   external reviewers after exclusion — zero margin — and
   `test_check_plan_review_contract` pins that round trip.

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

   **Gap-closure correction (WR-02).** `08-REVIEW.md` flagged, as
   code-inspection-only, that migration 0008 Step 3's bindings-table row
   insertion matched on the first `|---` line anywhere in a target
   `AGENTS.md`, not specifically the already-validated `| Gate |` bindings
   header — so an unrelated Markdown table preceding the bindings table
   could silently absorb the plan-review row. Reproduced live during
   gap-closure planning (a decoy-table fixture landed the row at the wrong
   line, one table too early), upgrading it from suspected to confirmed.
   The defect was self-sealing: Step 3's own idempotency check
   (`grep -q '^| plan-review' AGENTS.md`) would then find the misplaced row
   on every future run and mark the step permanently applied — masking a
   bindings table that never received the plan-review row, forever, with
   no re-run able to fix it. That self-sealing property is why this finding
   was fixed rather than accepted-and-documented, unlike WR-03 below. Fixed
   in plan `08-08` by gating the row insertion on a flag set only after the
   validated `| Gate |` header line is seen, correlating the insertion with
   the header the step already checked rather than the first structurally
   similar line in the file.

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

    **Gap-closure correction (CR-01): the preceding paragraph's contract
    was aspirational, not actual, until this phase's own gap-closure.**
    "A present, well-formed frontmatter is authoritative" describes intent
    that the byte-exact `---` comparison at (pre-fix)
    `check-plan-review.sh:539` did not deliver: a `REVIEWS.md` whose opening
    `---` carried a trailing space or a CRLF line ending had frontmatter a
    human would call present and well-formed, yet silently fell through to
    the reviewer-check-free fallback above anyway — reachable via an
    ordinary authoring accident (a Windows-edited file, a stray trailing
    space), not only via deliberate frontmatter omission. Found by this
    phase's own code review (CR-01), independently re-reproduced during
    verification, and reproduced a third time during gap-closure planning —
    three independent confirmations of the same live exit-0 result. Fixed
    in plan `08-07` by normalizing (stripping `\r` and trailing whitespace)
    the opening-delimiter comparison and mirroring the identical
    normalization onto the closing-delimiter `awk` search; normalizing only
    one side would have traded this fail-open for a false MALFORMED report
    on some CRLF files, the opposite failure mode. The fallback ITSELF is
    unchanged by this fix and remains exactly as spoofable as the paragraph
    above describes — the fix narrowed WHEN the fallback is reached, not
    what it accepts once reached; D-13 keeps the fallback for the
    hand-written cross-host case regardless. One further, intended
    consequence: a closing `--- ` (trailing space) that used to be
    misclassified MALFORMED (blocking, exit 2) is now accepted as
    well-formed once the opening and closing comparisons agree, and such a
    file is parsed strictly and allowed or blocked on its actual reviewer
    content instead of on delimiter whitespace.

12. **The `--file` bypass's traversal guard is lexical-`..`-only, not
    symlink-safe — a known, accepted, documented limitation (WR-03).**
    The bypass at `check-plan-review.sh:84-118` rejects a `--file` value
    containing a literal `..` path component, and its own comment block
    already scopes the claim exactly that far ("reject on the `..`
    component itself"). It does not detect a pre-existing symlinked
    directory component inside `.planning/phases/<phase>/` that resolves
    outside the tree without the literal string ever containing `..` — a
    textually-legitimate-looking `--file` value can still fire the bypass
    in that case. Executed directly during code review, confirmed live:
    `ln -s /tmp/outside .planning/phases/09-test-phase/evil-link && bash
    check-plan-review.sh --file
    ".planning/phases/09-test-phase/evil-link/some-PLAN.md"` exits 0.

    Deferred rather than fixed, mirroring decision 11's treatment of the
    `>=5`-line fallback: the whole gate is agent-mediated advisory text
    (decision 9) — an agent able to construct a crafted `--file` value is
    already able to skip the verifier entirely by simply not invoking it,
    so the traversal guard is a hygiene check against an accidental
    over-broad bypass, not a security boundary against a hostile caller.
    Canonicalize-and-contain, the pattern the resolver uses for
    `.planning/current-phase`, is not available at this call site: `_canon_dir`
    `cd`'s into a path and therefore requires it to exist, and `--file` may
    legitimately name a file about to be created. This is the same
    constraint the script's own comment block already states for why it
    checks the `..` component lexically instead of resolving the path —
    the ADR now agrees with the code rather than being silent about the
    gap between "traversal-safe" and "symlink-safe." A limitation recorded
    is a limitation a later reader can act on; a limitation only the
    planner knew about is a trap. The concrete future fix — reject any
    `--file` value with a symlinked existing prefix component, testable by
    walking and `[ -L ]`-testing each existing prefix directory without
    requiring the leaf to exist — is carried in Open follow-ups below.

    **Reversed (Phase 12, WR-03):** 2026-07-17. The guard now canonicalizes
    the `--file` value's parent directory (`_canon_dir`, the `cd ... && pwd
    -P` idiom) and rejects a symlink-resolved escape via `_is_contained`
    against `$REPO_ROOT/.planning` — reusing, not reinventing, the same
    helpers the current-phase resolver already used (this decision's own
    text above named that reuse as unavailable; it is now the shipped
    mechanism). This is NOT the walk-each-prefix-component fix speculated
    in the Open follow-up below (which is now superseded/resolved, not
    merely satisfied) — parent-directory canonicalization resolves
    symlinks anywhere in the parent chain in one shot without walking each
    component individually. The lexical `..` check (pre-Phase-12
    numbering, now `:166-176`) is retained as a defensive floor for
    the not-yet-created-parent case, not removed. NOTE: this also tightens
    the `*/.planning/*` bypass arm to `$REPO_ROOT/.planning` only — a
    nested/vendored `vendor/foo/.planning/X-PLAN.md` no longer bypasses
    (disclosed behavior change, not a silent regression). The dated
    Correction section covering d.9 superseded + this reversal + the
    global-vs-per-project fix lands in Phase 13 (DOC-03).

    **Extended (Phase 12 gap-closure, 12-04):** 2026-07-17. Independent
    verification (12-VERIFICATION.md, Priority Concern / WR-01) constructed
    the exact case this reversal had not yet covered and found it still
    exit-2-blocked: a `--file` value naming a plan artifact whose parent
    directory does not exist yet (so `_canon_dir` returns empty and the
    resolve-then-contain branch above never fires) fell through to
    `resolve_phase`, which could resolve an UNRELATED active phase (a
    phase dir with a `*-PLAN.md` but no `*-REVIEWS.md`) and block a
    legitimate not-yet-created in-tree plan file — a regression from the
    pre-Phase-12 script, which returned exit 0 for the identical input.
    The guard now adds a lexical `$REPO_ROOT/.planning`-rooted fallback
    that fires ONLY in that empty-`_canon_dir` branch: it accepts (exit 0)
    when the un-canonicalized, lexical parent is contained under
    `$REPO_ROOT/.planning`, restoring the pre-Phase-12 fail-safe-accept
    (never exit-2-block a legitimate not-yet-created path). The invariant
    from the first Reversed marker above is preserved, not reopened: this
    fallback fires only when the parent does NOT exist, so an EXISTING
    symlinked parent that resolves outside `.planning` still has a
    non-empty `_canon_dir` and is still rejected by the resolve-then-
    contain path (the WR-03 hole stays closed); and the fallback is rooted
    at `$REPO_ROOT/.planning` specifically (the same D-05 root, not a bare
    `*/.planning/*` glob), so a vendored `vendor/foo/.planning/...` whose
    parent does not exist still does not bypass. Mutation-proven
    RED (exit 2 with the fallback disabled) → GREEN (exit 0 restored) —
    see `migrations/run-tests.sh`'s not-yet-created-dir fixture and
    12-04-SUMMARY.md. No dated Correction section is opened here; that
    still lands in Phase 13 (DOC-03).

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

**Gap-closure additions.** `test_check_plan_review_enforcement` now also
covers delimiter tolerance (CR-01: CR/trailing-whitespace-normalized open
and close, in both directions — fail-open closed, no new false-MALFORMED
introduced) and the D-15 codex-identity exclusion (WR-01: case-insensitive
match, zero-margin count, the honest-mistake case), 13 fixtures total.
`test_migration_0008` now also covers the unrelated-preceding-table case
(WR-02: a decoy Markdown table before the bindings table no longer absorbs
the plan-review row), 4 assertions. Both fixture sets pin their respective
fixes in the direction that would regress silently if reverted.

## Open follow-ups

All recorded as follow-ups, not implemented in this phase. Each upstream
defect below carries the repo, the file and line, what is wrong, and the
executed evidence, so it can be filed upstream as-is rather than
reconstructed by hand.

- **WR-03's symlinked-prefix-component fix** (decision 12): reject any
  `--file` value with a symlinked existing prefix directory component, not
  only a literal `..` component. Testable without requiring the leaf to
  exist, by walking each existing prefix directory of the `--file` value
  and `[ -L ]`-testing it. Deferred, not fixed, in this gap-closure —
  decision 12 records why: the gate is agent-mediated, so this guard is
  hygiene against an accidental over-broad bypass, not a boundary against a
  hostile caller.

  **Resolved (Phase 12):** shipped as parent-directory canonicalization
  (`_canon_dir`/`_is_contained` against `$REPO_ROOT/.planning`), not the
  walk-each-prefix-component approach speculated above — see decision 12's
  Reversed marker.

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

## Correction

**Dated 2026-07-18 (Phase 13, HOOK-01/DOC-03).** This section is an in-place
addition to this existing ADR, not a new ADR number — this repo's numbering
convention (REV-04, `docs/decisions/README.md`) treats ADR and migration IDs
as independent, always-qualified sequences, and a Correction section edits
the ADR it corrects in place, exactly as Phase 12 already did twice on
decision 12 below.

1. **Decision 9 is SUPERSEDED.** Migration 0011 (Phase 13, HOOK-03) wires
   the plan-review gate onto codex-cli's native `PreToolUse` runtime hook
   surface, installed project-scoped, and the gate now blocks
   unconditionally at that surface — retiring decision 9's agent-mediated-
   only binding (`AGENTS.md` ritual text plus a verifier script an agent
   must choose to invoke). This does NOT retroactively validate decision
   9's rejection of option B at the time: the trust-ledger and
   self-scoping concerns it named were real considerations, confirmed as
   real gates by Phase 13's own spike findings
   (`13-01-SPIKE-FINDINGS.md`) — a two-gate model (project trust +
   per-hook `trusted_hash`) that had to be understood and designed around,
   not a phantom risk decision 9 invented. What no longer holds is
   decision 9's specific factual premise, corrected in item 3 below.

2. **Decision 12 was already REVERSED.** The `--file` bypass's
   symlink-traversal limitation decision 12 originally accepted as a known,
   documented gap was reversed by Phase 12 (WR-03) and further extended by
   Phase 12's own gap-closure (12-04) — see the existing `Reversed (Phase
   12, WR-03)` and `Extended (Phase 12 gap-closure, 12-04)` markers inline
   on decision 12 above, dated 2026-07-17, for the reversal's full
   mechanics. This Correction section records that reversal's existence
   only, to satisfy DOC-03's dated-Correction-section requirement — it does
   not repeat or re-explain the guard mechanics decision 12's own inline
   markers already document.

3. **Factual correction: native hooks are project-scoped, not only
   global.** Decision 9's premise that Codex's native `PreToolUse` surface
   is "global rather than per-project" is FALSE as of codex-cli 0.144.4 and
   should not be relied on going forward. `<repo>/.codex/hooks.json` and
   `<repo>/.codex/config.toml` are both documented, discovered,
   project-scoped layers (developers.openai.com/codex/hooks,
   developers.openai.com/codex/config-advanced), loaded IN ADDITION to the
   global `~/.codex/hooks.json`/`~/.codex/config.toml` layers, with project
   entries taking precedence on conflict. Migration 0011 (HOOK-03) uses
   exactly this project-scoped layer — the one decision 9 believed did not
   exist — which is what makes the unconditional block in item 1 possible
   without decision 9's original global-scope, fires-in-every-repo
   objection applying.
