# Phase 12: Path Safety & Review Debt - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn the `--file` bypass guard in `check-plan-review.sh` into a real
symlink-resolution boundary check (WR-03), and close the four independently-scoped
`09-REVIEW.md` defects — each with its own mutation-proven proof, never batched
into one undifferentiated cleanup.

Delivers five requirements:
- **WR-03** — `--file` guard canonicalizes the path's *parent directory* (via the
  existing `_canon_dir` / `_is_contained` helpers) and rejects a symlink-resolved
  escape, replacing the lexical-`..`-only check. Reverses ADR-0009 decision 12.
- **REV-01 (WR-05)** — `validate-0009-anchor.sh`'s stdout is made genuinely
  deterministic; a full-script grep for every mirror-derived stdout value is
  mutation-proven.
- **REV-02 (IN-01)** — `extract_step_block` no longer prefix-matches `### Step 1`
  against `### Step 10`+, verified against a synthetic 10+-step document.
- **REV-03 (IN-02)** — CASE 1's previously-unasserted line drop is caught by a
  strictly-smaller-count assertion (no hardcoded line number), mutation-proven.
- **REV-04 (IN-03)** — `docs/decisions/README.md` corrected so an ADR number and a
  migration number can no longer be conflated.

**In scope:** the WR-03 real guard + its two fixtures (symlinked parent, sibling-
prefix collision); the four REV fixes each with independent proof; a minimal
in-place ADR-0009 marker recording d.12's reversal; the REV-04 README convention.

**Out of scope (locked upstream — do not re-open):**
- **TOCTOU races in WR-03** — the guard canonicalizes and boundary-checks; it does
  not attempt to defeat time-of-check/time-of-use. Do not build a second
  path-safety primitive (`.planning/REQUIREMENTS.md` §Out of Scope, WR-03 text).
- **DOC-03's full dated ADR-0009 Correction section** (d.9 superseded + d.12
  reversed + the global-vs-per-project factual correction) — written in full in
  **Phase 13**, where ADR-0009 lands last. Phase 12 makes only the minimal in-place
  d.12 touch (see D-08).
- **Editing migrations 0001/0004/0007/0009** — immutable. WR-05/IN-01/IN-02 fixes
  touch `validate-0009-anchor.sh` and `run-tests.sh` (test/validator scripts), not
  the migration documents.
- **IN-04** (predictable temp-file names in CWD) — closed in **Phase 14** by
  MARK-04's `mktemp` in the new paired-markers migration, by supersession. Not this
  phase.

</domain>

<decisions>
## Implementation Decisions

### WR-03 — guard shape & fail-mode
- **D-01 (guard shape — AUGMENT, not replace):** Keep the existing lexical
  `..`-component reject (`check-plan-review.sh:84-118`, already mutation-tested by
  T-08-37) as a cheap first-line check, THEN add parent-directory canonicalization +
  `_is_contained`. Belt-and-suspenders: the `..` check still fires when the parent
  dir does not exist (where `_canon_dir` returns empty and cannot help). Do **not**
  strip the `..` loop — that would regress the T-08-37 guarantee. Note: WR-03's
  requirement text says "replacing the lexical-`..`-only check"; this decision reads
  that as *superseding it as the symlink defense* while keeping the lexical check as
  a defensive floor. The ADR marker (D-08) must state this honestly.
- **D-02 (fail-mode — FALL THROUGH, never fail open):** When `--file`'s parent dir
  does not exist or cannot be canonicalized (`_canon_dir` → empty), the bypass
  simply does **not fire** — control falls through to normal phase resolution and
  the phase's real state decides. This is the existing documented semantics
  (`check-plan-review.sh:80-82`: "a rejected `--file` is NOT a block by itself").
  Never treat an un-canonicalizable parent as an `exit 2` block — that would
  false-block the legitimate new-file-in-a-new-dir case (executor creating
  `12-01-PLAN.md` before the dir exists). Failing open is the milestone's nemesis;
  falling through is fail-safe.
- **D-03 (symlink policy — RESOLVE-THEN-CONTAIN):** Canonicalize the parent
  (resolving all symlinks via the `cd … && pwd -P` idiom) and accept iff the result
  is contained in the allowed root. A symlink that resolves to **inside** the
  allowed tree is fine; only a symlink that **escapes** is rejected. This mirrors
  the current-phase pointer's canonicalize-and-contain treatment
  (`check-plan-review.sh:270-272`) and matches WR-03's wording ("rejects a
  symlink-*resolved* escape"). Do **not** apply the REVIEWS.md evidence guard's
  reject-any-symlink rule (`:470`) — that guard is deliberately asymmetric because
  evidence "has no legitimate reason to indirect"; a `--file` edit target does.

### WR-03 — containment root & ordering
- **D-04 (hoist repo-root above the bypass):** The `--file` bypass currently runs
  *before* repo-root self-location (`:84` vs `:167`), so there is no `$REPO_ROOT` to
  contain against. Move the repo-root self-location block up to just after the
  `GSD_SKIP_REVIEWS` emergency hatch (which MUST stay first, `:65`), then contain the
  canonicalized parent against `$REPO_ROOT/.planning`. This keeps the verdict
  cwd-independent — the script's own stated principle (`:157-164`: a nested-subdir
  invocation must reach the same verdict). Re-verify the existing T-08-* ordering
  assertions still hold after the reorder (the skip hatch stays step 1; the no-
  `.planning`-ancestor fail-open at `:183-187` simply moves earlier, same net result).
- **D-05 (allowed root — `$REPO_ROOT/.planning` ONLY):** Contain the canonicalized
  parent strictly within *this* repo's `.planning` tree. `_is_contained`'s
  separator-aware match covers both the top-level docs (`ROADMAP.md`, `PROJECT.md`,
  `REQUIREMENTS.md` at `.planning/`) and `phases/<NN>/*` alike. This **tightens** the
  guard: a nested/vendored `vendor/foo/.planning/X-PLAN.md` no longer bypasses (the
  old lexical `*/.planning/*` arm allowed it) — it now falls to the gate. This is an
  intentional correctness improvement (you should not bypass this repo's gate by
  naming a sub-project's planning doc). **Flag this `*/.planning/*` behavior change**
  in the phase SUMMARY and the ADR-0009 marker so it is not read as a silent
  regression.

### ADR-0009 — Phase 12 vs Phase 13 coordination
- **D-08 (minimal in-place marker, NO Correction section):** Phase 12 edits
  ADR-0009 decision 12 *in place* — add a `**Reversed (Phase 12, WR-03):** …` marker
  at decision 12 (`docs/decisions/0009-plan-review-gate.md:366-396`) and mark the
  matching Open-follow-up entry (`:428+`) resolved. It does **NOT** open the dated
  Correction section — Phase 13's DOC-03 authors that single consolidated Correction
  (d.9 superseded + d.12 reversed + the global-vs-per-project factual fix). This
  respects the roadmap sequencing ("this phase's ADR-0009 touch … lands before Phase
  13's … avoids two PRs racing the same file region") and keeps the Correction
  section written exactly once.
- **D-09 (marker must describe the mechanism actually shipped):** ADR-0009's current
  Open-follow-up describes a *speculative* fix — "walk each existing prefix
  directory of the `--file` value" (`:435-440`). Phase 12 ships a **different,
  simpler** mechanism: parent-directory canonicalization via `_canon_dir`/`pwd -P`
  (resolves symlinks anywhere in the parent chain in one shot). Per the milestone's
  docs-match-reality standard, the in-place marker MUST describe what was actually
  built (parent-canonicalization + `_is_contained`), not leave the walk-each-prefix
  description standing as if it were the plan.

### REV-04 — doc-fix depth
- **D-10 (normative convention subsection):** In `docs/decisions/README.md`, add a
  short subsection stating the ADR-NNNN and migration-NNNN series are **independent
  sequences**, AND prescribing the rule: always qualify as `ADR-NNNN` or
  `migration NNNN`, never a bare `NNNN`. Use the current off-by-one collision
  (ADR-0010 documents migration 0009; ADR-0009 is a different subject) as the worked
  example. This is actionable forward guidance — REV-04 is explicitly cited as the
  constraint the roadmapper honors when assigning Phase 13/14's new migration
  numbers — so a bare disambiguation sentence is too thin.

### REV-01 / REV-02 / REV-03 — locked by success criteria (no gray areas)
- **D-11 (REV-01 determinism = remove, not reword):** SC#2's requirement that
  `validate-0009-anchor.sh`'s stdout be "proven genuinely deterministic" via a
  mutation-proven full-script grep for every mirror-derived value forecloses
  WR-05's fix-option (b) (reword the comment). Phase 12 takes fix-option (a):
  **remove** the mirror-derived values from stdout — the `$(wc -l < "$MIRROR")`
  banner count (`:241`) and the derived `gitnexus:start at line 86` number in CASE
  2's PASS text — so a re-vendor (75→79 has already happened once) cannot invalidate
  the recorded evidence. The proof is a full-script grep asserting no mirror-derived
  value survives, mutation-proven (reintroduce one → RED; remove → GREEN).
- **D-12 (REV-02 delimiter fix):** `extract_step_block` (`run-tests.sh:110`) matches
  on the step delimiter too (`### Step N:` and `### Step N ` prefixes), preserving
  the no-escaping property, so `### Step 1` no longer prefix-matches `### Step 10`+.
  Proof: a synthetic 10+-step document — observed extracting `### Step 1` without
  matching `### Step 10` under the fix, failing under the old prefix match.
- **D-13 (REV-03 line-drop assertion):** Add a strictly-smaller-count assertion
  between strip and insert in CASE 1
  (`validate-0009-anchor.sh:249-264`):
  `[ "$(wc -l < strip)" -lt "$(wc -l < input)" ]` — **no hardcoded line number**
  (not the ADR's `313 → 232`). Mutation-proven: break the drop → RED; restore →
  GREEN.

### Claude's Discretion
- Fixture file naming/placement within `run-tests.sh` (and any `test-fixtures/`
  shape reuse) for the new WR-03 and REV tests — planner/executor discretion,
  provided each new assertion is independently mutation-proven and the verifier
  re-runs the RED→GREEN cycle rather than trusting the executor's claim.
- Exact wording of the ADR-0009 in-place marker and the REV-04 README subsection,
  within the contracts fixed by D-08/D-09/D-10.
- Whether the WR-03 containment helper factors into a small shared function or
  inlines at the bypass — as long as `_canon_dir`/`_is_contained` are *reused*, not
  reinvented (SC#1).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### WR-03 — the guard and its helpers
- `skills/agentic-apps-workflow/scripts/check-plan-review.sh` — the guard under
  repair. Read: the `--file` bypass block (`:84-118`, the lexical-`..` check being
  augmented), the `_canon_dir`/`_is_contained` helper defs (`:133-146`), their
  existing reuse at the current-phase pointer (`:270-272`), the repo-root
  self-location block being hoisted (`:167-190`), the `GSD_SKIP_REVIEWS` hatch that
  stays first (`:65-68`), and the REVIEWS.md reject-any-symlink guard (`:470`, the
  deliberately-asymmetric one NOT to copy for `--file`).

### The four REV fixes
- `migrations/validate-0009-anchor.sh` — REV-01 (stdout determinism, `:231-241`
  banner + CASE 2 PASS text) and REV-03 (CASE 1 line-drop assertion, `:249-264`).
- `migrations/run-tests.sh` — REV-02 (`extract_step_block`, `:110`; justification at
  `:80-91`). Also the harness all new fixtures register in (unfiltered, CI-run on
  ubuntu + macOS since Phase 10).
- `docs/decisions/README.md` — REV-04 (ADR/migration numbering convention, `:26-27`).

### Decision records
- `docs/decisions/0009-plan-review-gate.md` — decision 12 (`:366-396`, the accepted
  lexical-only limitation Phase 12 reverses) and the Open-follow-up entry (`:428+`,
  the speculative walk-each-prefix fix description D-09 corrects). Phase 12 makes the
  minimal in-place marker only; DOC-03's full Correction is Phase 13.

### Source-of-truth for every fix
- `.planning/phases/09-region-aware-11-placement/09-REVIEW.md` — the review that
  found all four REV defects and WR-03. Read the specific findings: WR-03 (the
  `--file` limitation is actually recorded in ADR-0009 d.12, not 09-REVIEW; see the
  ADR), WR-05 (REV-01, `:376-390`), IN-01 (REV-02, `:394-403`), IN-02 (REV-03,
  `:405-416`), IN-03 (REV-04, `:418-427`). Each finding carries its own reproduction
  and suggested fix.
- `.planning/REQUIREMENTS.md` §Path Safety & Review Debt (WR-03, REV-01..04) and
  §Out of Scope (TOCTOU, migration immutability, IN-04→Phase 14) — the locked
  requirement text, reads as acceptance criteria.
- `.planning/ROADMAP.md` §Phase 12 — the 5 success criteria and the ADR-0009
  sequencing Notes (Phase 12 before Phase 13; DOC-03 in Phase 13).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_canon_dir()` and `_is_contained()` (`check-plan-review.sh:133-146`) — the exact
  helpers WR-03 must reuse (SC#1: "reused rather than reinvented"). `_canon_dir` is
  the portable `( cd "$1" && pwd -P )` idiom (realpath/readlink-f absent/divergent on
  macOS); it resolves symlinks and `..` and prints nothing on a non-existent path.
  `_is_contained` is separator-aware — `.planning/phases-evil` cannot pass as a child
  of `.planning/phases` (T-08-01).
- `extract_step_block` (`run-tests.sh:110`) — REV-02's target; the literal-prefix
  design is justified at `:80-91` (no-escaping property to preserve).
- `run-tests.sh` mutation-proof idiom (break asserted line → RED → restore → GREEN)
  — carried from Phase 11 (D-05); every new WR-03/REV assertion follows it and the
  verifier re-runs the cycle independently.

### Established Patterns
- The `--file` bypass fail-through contract (`:80-82`): a rejected bypass is not a
  block; it falls to normal resolution. D-02 preserves this.
- cwd-independent verdicts (`:157-164`): the verifier locates its own repo root so a
  nested-subdir invocation reaches the same verdict. D-04's hoist keeps this true for
  the `--file` guard too.
- Determinism-for-re-runnable-evidence (validate-0009-anchor.sh's own stated intent,
  contradicted by its `wc -l` output — the exact WR-05/REV-01 defect).

### Integration Points
- New fixtures land in `run-tests.sh`, which Phase 10's CI executes unfiltered on
  ubuntu + macOS — so every new assertion here is CI-gated from the moment it lands.
- Phase 12's ADR-0009 in-place marker shares the file with Phase 13's DOC-03
  Correction; the roadmap sequences 12 before 13 to avoid a same-region PR race.

</code_context>

<specifics>
## Specific Ideas

- WR-03 augments rather than replaces the `..` check (D-01) — the user explicitly
  chose belt-and-suspenders over the requirement's literal "replace" wording, to
  protect the not-yet-created-parent case and the T-08-37 guarantee.
- The `*/.planning/*` tightening (D-05) is a deliberate, disclosed behavior change,
  not an accident — must be flagged, not silent.
- REV-01 removes the non-deterministic output (D-11), it does not reword the claim —
  the stronger of WR-05's two fix options, matching SC#2's "genuinely deterministic".

</specifics>

<deferred>
## Deferred Ideas

- **DOC-03 — the full dated ADR-0009 Correction section** (d.9 superseded, d.12
  reversed, global-vs-per-project factual fix) → **Phase 13**, where ADR-0009 lands
  last. Phase 12 makes only the minimal in-place d.12 marker (D-08).
- **IN-04 — predictable temp-file names in CWD** → **Phase 14**, closed by MARK-04's
  `mktemp` in the new paired-markers migration (by supersession, not by editing
  immutable migration 0009). Not this phase.
- **WR-01 — the strip's single-`##`-heading coupling to the mirror** (09-REVIEW.md
  `:292-315`) — a separate real defect, explicitly NOT folded into MARK scope
  (`.planning/REQUIREMENTS.md` §Out of Scope). Not in v0.8.0's Phase 12/14 mapping;
  left as open debt.

None of these are in scope for Phase 12.

</deferred>

---

*Phase: 12-path-safety-review-debt*
*Context gathered: 2026-07-17*
