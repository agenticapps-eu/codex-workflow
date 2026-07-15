# Phase 9: Region-Aware §11 Placement - Context

**Gathered:** 2026-07-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship migration `0009-spec-11-region-aware-placement.md` (`0.6.0` → `0.7.0`) so the
spec §11 Coding Discipline block anchors above a leading GitNexus region instead
of inside it — closing a **latent** block-destruction defect for projects this
host scaffolds. The anchor rule is validated empirically against real files
*before* the migration is authored, and a TDD fixture suite sources the
migration's shell from the migration document rather than a transcribed copy.

This is a **placement** fix. It does not re-vendor §11's content (0004's job),
does not resolve the `implements_spec` gap, and does not edit migrations
0001/0004 (immutable — fix forward).

</domain>

<decisions>
## Implementation Decisions

Numbering continues from Phase 8's D-01..D-20 (see `../08-plan-review-gate/08-CONTEXT.md`).

### The anchor rule

- **D-21:** Insert immediately before the first line that is **either** a `## `
  heading **or** a `<!-- gitnexus:start -->` marker — whichever comes first; EOF
  if neither. A one-alternation delta to the existing awk, so the structural
  invariant survives: the block is still always followed by a `## ` or EOF, which
  is what bounds the managed section for replace/rollback.
- **D-22:** Two alternatives are rejected and **both** must be recorded in the ADR
  (the source prompt named only the first):
  1. *"Anchor before `gitnexus:start` if a region exists, else the first `## `."*
     Wrong: when the region starts late in the file it drops §11 hundreds of lines
     down. The region is only the anchor when it comes **first**.
  2. *"Always immediately after the H1."* (from the reference design) Moves the
     block in every healthy repo for no benefit and breaks the followed-by-`## `
     invariant.
- **D-23:** State §12's status **precisely** in the ADR. Verified at
  `spec/12-authoring-conventions.md:93-97`: the placement advisory is *"advisory,
  lower-case 'should'… not RFC 2119 and not a conformance gate."* The rejected
  alternative violates an **advisory**, not a normative gate. Do not overclaim —
  the prompt and reference design both phrase this loosely.

### Block strip boundary (State B)

- **D-24:** **Structural boundary.** The block spans: provenance comment → its own
  `## Coding Discipline (NON-NEGOTIABLE)` heading → everything up to the **next**
  `/^## /` line, or EOF. Verified viable: the mirror is 79 lines with exactly one
  `## ` (its own heading, L1); its four subsections are `### `, which does **not**
  match awk's `/^## /`. This makes the strip rest on the *same* invariant as the
  anchor (D-21) — one rule, two uses. It also naturally absorbs the single
  trailing blank line 0001 injects.
- **D-25:** **Rejected — 0004's content sentinel** (`/session-level discipline the
  model brings to every diff\.$/`). It couples the strip to §11's last prose line,
  and prose drift in that exact block is *why migration 0004 had to exist*. It
  also carries a **runaway-strip hazard**: 0004's awk is `inblk {next}` until the
  sentinel matches, so if that line ever changes the strip never terminates and
  **deletes the entire rest of the file**. 0004 escaped this only because its
  drift (75→79 lines) added blanks *inside* the block and left the closing line
  intact. Do not inherit this shape.
- **D-26:** **Strip blind — no verbatim assertion.** The structural boundary is
  bounded by construction, so a drifted block cannot cause a runaway. A
  drifted-but-managed block is 0004's problem, not 0009's; 0009 must not refuse to
  place a block because its content drifted. (Explicitly considered and declined:
  a `diff` against the mirror gating the strip with `exit 3`.)

### Re-injection source

- **D-27:** **Re-vendor from the mirror.** After stripping, re-inject fresh from
  `skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md`
  — exactly what 0001 and 0004 both do. This unifies **States B and C into one code
  path** (inject always reads the mirror; B simply strips first).
- **D-28:** Two consequences of D-27, both to be stated rather than left implicit:
  1. 0009's **pre-flight must verify the mirror exists** (0004's shape:
     `test -f "$MIRROR" || { …; exit 1; }`).
  2. A State-B move **silently repairs a drifted block** as a side effect. Record
     this in the ADR as a stated consequence, not an accident.
- **D-29:** The injected provenance stays `<!-- spec-source:
  agenticapps-workflow-core@0.4.0 §11 -->` — hardcoded `@0.4.0`, as 0001/0004 do.
  `0.4.0` is the block's **content** version and is unchanged; it is not the spec
  version. Do NOT bump it (D-17 from Phase 8 stands).

### The state machine

- **D-30:** The apply reduces to three branches — no per-state special-casing:
  1. §11 heading present **without** provenance → **`exit 3`**, file untouched
     (State D; inherits 0001's conflict rule — never overwrite a hand-paste).
  2. Current-version provenance present **AND** block not in a region → **skip**
     (State A).
  3. Otherwise → **strip-if-a-managed-block-exists + inject at the anchor**
     (State B = strip+inject; State C = inject).
- **D-31:** **MIGR-07 falls out of the idempotency predicate, not a special case.**
  A healthy-but-off-anchor block has provenance and is not in a region, so branch 2
  skips it. Do not add code to detect "off-anchor but healthy" — and do not move it.
- **D-32:** **Region predicate fails closed.** `in_region = (prov_line >
  start_line) AND (end_line == 0 OR prov_line < end_line)`. An unterminated
  `gitnexus:start` (no matching `end`) counts as **in-region**, so the block is
  moved above the start marker to safety. Same outcome as the well-formed case —
  no separate branch, no extra fixture. Rejected: fail-open (leaves the block
  inside something gitnexus may still regenerate — the exact defect this closes)
  and `exit 3` (adds a fifth state and blocks the version bump on a possibly
  benign shape).

### Absent instruction file

- **D-33:** **Informational skip, version bump still runs.** Step 1 reports "no
  AGENTS.md — no §11 placement to heal" and returns success; Step 2 still records
  `0.7.0`. This **diverges deliberately from 0004's pre-flight abort**
  (`0004:44`). Rationale: the update engine marks a migration pending iff
  `installed >= from_version && installed < to_version`, so an abort would strand
  the project at `0.6.0` **permanently** — 0010+ would never become pending.
  Matches the reference design's `04-no-claudemd` fixture.

### Fixtures

- **D-34:** **This repo's native idiom, not claude-workflow's.**
  `test_migration_0009` in `migrations/run-tests.sh`, with the six cases
  **synthesized at test time** via `printf` into `$tmp` — the documented fallback
  in `migrations/test-fixtures/README.md` ("Limits"), and what `run-tests.sh:110`
  already does. **Rejected: porting claude-workflow's per-fixture directories**
  (`test-fixtures/0029/01-gitnexus-led-inject/` …). That layout directly
  contradicts this repo's own contract — `test-fixtures/README.md` has a **"Why no
  static fixture files"** section rejecting exactly it — and would introduce a
  second, competing fixture idiom.
- **D-35:** **Port the extractor, not the layout.** Adapt
  `../claude-workflow/migrations/test-fixtures/0029/common-verify.sh` — awk scoped
  to `### Step 1` → `**Apply:**` → first fence, printing to the closing fence.
  `want` is cleared as soon as a fence opens so a ```bash→```sh change cannot latch
  onto the Rollback fence.
- **D-36:** **Carry the shape assertion — it is the point.** The reference's
  comment says it best: *"Non-empty is not the same as correct."* Assert the
  extracted block contains `gitnexus:start`; fail loudly with the extracted text
  if not. **This is the direct antidote to the dead-by-construction defect Phase 8
  hit three times** (08-05 shipped two awk acceptance patterns that could never
  match, so they silently passed and read as coverage; the plan-checker caught a
  third in 08-09). Every 0009 assertion needs the same treatment: prove it fails
  when it should.
- **D-37:** **TEST-04 scope = `run-tests.sh:119` only.** Convert that inlined §11
  injection copy to extract from **0001's** document. Note 0001 is legitimately
  naive and immutable, so a document-sourced test there faithfully asserts 0001's
  naive behavior — a fidelity improvement, not a behavior change, and no conflict
  with TEST-02 (which concerns *0009's* fixtures going RED). **Rejected:** also
  converting 0008's Step-3 insert-awk copy (~`run-tests.sh:985`) — real instance of
  the same class, but it widens a placement fix into harness refactoring across a
  278-assertion suite. Logged as a follow-up (see Deferred).
- **D-38:** Honor the README's **double-sided idempotency contract**: each step's
  check must return **non-zero** against the before-state and **zero** against the
  after-state. Catches both a too-permissive check (skips unapplied work) and a
  too-strict one (re-applies applied work).

### Mechanics

- **D-39:** `from_version: 0.6.0`, `to_version: 0.7.0`; pre-flight version gate
  accepts **both** (`^version: 0\.(6\.0|7\.0)$` shape) so an idempotent re-run on
  an already-migrated project does not abort. Mirrors 0008's shape.
- **D-40:** Frontmatter follows 0008: `id`, `slug`, `title`, `from_version`,
  `to_version`, `applies_to`, `requires`, `optional_for`. `applies_to` should list
  `AGENTS.md`, `skills/agentic-apps-workflow/SKILL.md`, `.codex/workflow-version.txt`.
- **D-41:** Step 2 bumps the scaffolder version and Step 3 records
  `.codex/workflow-version.txt` (0004's three-step shape). This repo's **own**
  scaffolder bumps to `0.7.0` in the same change to keep the version-coupling drift
  test green (the v0.6.0 precedent — drift policy is a hard fail).
- **D-42:** State the **supported upgrade floor** in the document prose, as 0008
  does: `0.6.0 → 0.7.0`, single hop. Do **not** widen the floor to paper over the
  update skill's multi-hop chain-selection defect (see Deferred).

### SETUP-01 — resolved, with a caveat to record

- **D-43:** **Setup has no independent §11 placement logic.** Verified:
  `0000-baseline.md:102` is a plain `cat templates/agents-md-additions.md >>
  AGENTS.md` append, and that template contains **no §11** (it runs `## Development
  Workflow` → `## Pre-execution Gate`). Setup applies **0000-baseline only** and
  lands the project at **`0.1.0`** (`SKILL.md:109` post-check). §11 arrives via
  **0001** in the subsequent update chain; 0009 runs last and heals it.
- **D-44:** **§08 conformance is satisfied by construction — no parity guard.**
  `spec/08-migration-format.md:27-33` makes the **end state** normative, not the
  mechanism, and names two conformant strategies: **replay** and **snapshot** (the
  latter requiring a CI drift guard). This host is **replay**; claude-workflow is
  **snapshot**, which is exactly why it needs `check-snapshot-parity.sh` and a new
  anchor-parity guard and **we do not**. SETUP-01 is a *record-the-fact*
  requirement, not a build-a-guard one.
- **D-45:** **Caveat that bounds SETUP-01's claim — record, do not fix.** Phase 8
  deferred the update skill's **multi-hop chain-selection defect** (it selects
  pending migrations *once* from the project's initial version and never
  recomputes). A freshly scaffolded project at `0.1.0` therefore selects only 0001,
  applies it, lands at `0.2.0`, and fails the final target check — so "full replay"
  does **not** complete in one invocation today. SETUP-01 must not assert
  end-state conformance it cannot demonstrate. State the limitation honestly.

### Claude's Discretion

- The exact awk implementation of D-21/D-24/D-32 (anchor alternation, structural
  strip, line-number region predicate) — mechanics, not policy.
- Plan/wave decomposition, subject to the two hard orderings in ROADMAP.md
  (validate-before-write; RED-before-GREEN).
- Whether the empirical validation (ANCHOR-03/04) is a throwaway script or a
  committed harness addition — but its **evidence must be recorded**, since
  "validated empirically" is a success criterion, not a claim to assert.
- ADR number (next free in `docs/decisions/`) and its exact section shape.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The design being propagated
- `../claude-workflow/docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` —
  the approved reference design. **Read first.** Note: its status is *"Approved
  (brainstorming → design approved 2026-07-15)"* and **claude-workflow's migration
  0029 does not exist yet** — `migrations/` has no 0029. This is **concurrent
  propagation of an approved design, not a port of shipped code.** There is no
  working implementation to diff against. Its "validated across 6 repos" refers to
  the *anchor rule*, not a shipped migration.
- `../claude-workflow/migrations/test-fixtures/0029/common-verify.sh` — the
  fence-extractor + shape assertion to adapt (D-35/D-36). Written RED: it points at
  a migration document that does not exist yet.
- `PROMPT-0009-spec-11-region-aware-placement.md` — the source prompt (repo root,
  **untracked**). Accurate on the defect and the anchor rule; **wrong that 0029
  exists**; **missed** the third anchor site (`run-tests.sh:119`) and the second
  rejected alternative; its setup-parity worry does not apply here (D-43/D-44).

### The normative spec
- `../agenticapps-workflow-core/spec/11-coding-discipline.md` — the canonical §11
  the mirror must equal byte-for-byte.
- `../agenticapps-workflow-core/spec/12-authoring-conventions.md` §"Placement of
  behavior-critical prose (advisory)" lines 93–113 — the placement advisory.
  **Lines 95–97 mark it advisory, non-RFC-2119, not a conformance gate** (D-23).
  Line 105–106 names §11 explicitly.
- `../agenticapps-workflow-core/spec/08-migration-format.md` lines 25–45 — end
  state is normative, not mechanism; replay and snapshot both conformant (D-44).
  Line ~141: fixtures required for every migration operating on existing files.

### The immutable machinery being fixed forward
- `migrations/0001-inject-spec-11-coding-discipline.md` — the original §11
  injector. **Naive anchor at :91** (`/^## / && !done`). Immutable.
- `migrations/0004-revendor-spec-11.md` — **the closest structural precedent**:
  strip-then-reinject. **Naive anchor at :77.** Its strip awk (:68-74) is the
  content-sentinel shape D-25 rejects. Its pre-flight (:44) is the abort D-33
  diverges from. Its 3-step shape (heal → bump scaffolder → record version) is what
  D-41 follows. Immutable.
- `migrations/0008-plan-review-gate.md` — current-generation shape: frontmatter
  (:1-13), the "Why a 0.x minor bump" and "Supported upgrade floor" prose (D-42).
- `migrations/README.md` — the atomicity contract (retry / skip-with-warning /
  rollback).

### Fixtures
- `migrations/test-fixtures/README.md` — **the fixture contract this phase must
  honor.** "Why no static fixture files" rejects claude-workflow's layout (D-34);
  "Contract" defines the double-sided idempotency assertion (D-38); "Limits"
  authorizes synthesized fixtures for state outside the repo.
- `migrations/run-tests.sh` — the harness (278 PASS / 1 SKIP / 0 FAIL). **:119** is
  the inlined §11 anchor copy TEST-04 retires (D-37). **~:985** is 0008's inlined
  Step-3 copy (deferred). :32/:43 document the shared-lib helpers.
- `vendor/agenticapps-shared/migrations/lib/fixture-runner.sh` — `extract_to()` is
  a **git-show** extractor (file at a ref), **not** a markdown fence extractor. It
  does not solve TEST-01; do not mistake it for the helper you need.

### This host's files
- `AGENTS.md` — §11 heading **L18**, provenance L17, managed markers L15/L269,
  GitNexus region **L271–313**. Region does not lead the file ⇒ **this host is SAFE;
  the defect is LATENT.** There is no broken repo here to repair.
- `skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md` —
  the payload. **79 lines; exactly one `## ` (L1); four `### ` subsections; last
  line is the sentinel D-25 rejects.**
- `skills/setup-codex-agenticapps-workflow/SKILL.md` — Stage C (:83-110) walks
  0000-baseline only; :109 post-check asserts `0.1.0`; :111 phrases the full chain
  conditionally (D-43).
- `migrations/0000-baseline.md` — :102 the plain append; :93 the marker idempotency
  check.
- `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md` —
  contains **no §11** (verified). Confirms D-43.

### Decision records
- `docs/decisions/0007-bind-upstream-gsd.md` — thin-binding stance.
- `docs/decisions/0009-plan-review-gate.md` — decision 8 (bootstrap paradox: Phase
  9 is the first genuinely gated phase); decision 9 (agent-mediated gate).
- `.planning/phases/08-plan-review-gate/08-CONTEXT.md` — D-17 (`implements_spec`
  stays 0.4.0), D-18 (no 00–07 migration), D-19 (template-extracted migration
  text), and the deferred list D-45 draws on.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`migrations/0004-revendor-spec-11.md`** — the strip-then-reinject shape 0009's
  State B needs, and the 3-step migration skeleton (heal → bump scaffolder → record
  version). Adapt the *structure*; reject its strip boundary (D-25) and its
  pre-flight abort (D-33).
- **`../claude-workflow/migrations/test-fixtures/0029/common-verify.sh`** — the
  fence extractor + shape assertion (D-35/D-36). ~50 lines, directly adaptable.
- **`migrations/run-tests.sh:110-135`** — the existing synthesized-fixture idiom
  (`printf` into `$tmp`, `assert_check`), and the model for `test_migration_0009`.
- **`migrations/run-tests.sh:960-1000`** — 0008's "extraction from the REAL template
  must be non-empty BEFORE the insert is asserted (T-08-23)" pattern. This repo
  **already** understands the extraction-emptiness hazard for *template content*;
  0009 extends the same discipline to the migration's *shell*.

### Established Patterns
- **Migration immutability / fix-forward** — a defect in a shipped migration is
  fixed by a new one, never an edit (0004 exists for exactly this reason).
- **Template-extracted migration text** (D-19, the 0007 lesson) — never heredoc
  prose that also ships in a template. 0009's §11 payload comes from the mirror.
- **Stable installed paths** — `${CODEX_HOME:-$HOME/.codex}/skills/…`; two real
  bugs were relative-path resolution failures.
- **Version coupling is a hard drift fail** — `run-tests.sh:32` notes the policy
  lives in this consumer; SKILL.md `version` must equal the latest migration's
  `to_version`.

### Integration Points
- `AGENTS.md` — the file being healed.
- `skills/agentic-apps-workflow/SKILL.md` — `version:` bump target (D-41).
- `.codex/workflow-version.txt` — records `0.7.0` (D-41).
- `migrations/run-tests.sh` — gains `test_migration_0009`; `:119` converted (D-37).
- `CHANGELOG.md` — DOC-02. **No "known issues" section exists** (verified), so the
  source prompt's "retire the known-issues entry" instruction is a **no-op** here.

</code_context>

<specifics>
## Specific Ideas

- The ADR should read like ADR-0009 does: record what was **decided**, the
  alternatives **rejected with their reasoning**, and the limitations **accepted**.
  Both rejected anchor alternatives (D-22) and the drift-repair side effect (D-28.2)
  belong in it.
- The reference design's own framing is worth keeping for the ADR's rejected-
  alternatives section: the region-only rule is *"the obvious reading of 'put it
  above the region', and wrong."*
- Prefer the reference's fixture names where they map cleanly
  (`01-gitnexus-led-inject`, `02-inside-region-move`, `03-healthy-noop`,
  `04-no-agentsmd`, `05-unmanaged-conflict`, `06-no-heading-eof`) — as **case
  labels inside `test_migration_0009`**, not as directories (D-34).
- `03-healthy-noop` must assert AGENTS.md is **byte-identical** — that is what
  proves zero churn, and it is the fixture that would catch an over-eager anchor.

</specifics>

<deferred>
## Deferred Ideas

- **De-inline 0008's Step-3 insert-awk copy** (`migrations/run-tests.sh` ~:985) —
  a real instance of the same drift class TEST-04 closes, but reaching into another
  migration's tests widens a placement fix into harness refactoring across a
  278-assertion suite. D-37 scopes Phase 9 to `:119`. Track it; do not silently
  leave it unrecorded.
- **Migrations 0002 and 0003 declare `from_version == to_version` (`0.2.0` →
  `0.2.0`)** — discovered while mapping the chain. Under the engine's
  `installed >= from && installed < to` rule they can **never** be pending: dead
  migrations. Pre-existing, unrelated to §11 placement, and unsafe to "fix" without
  understanding why they were authored that way. Worth its own investigation.
- **The update skill's multi-hop chain-selection defect** — carried from Phase 8's
  deferred list and now **verified to have a concrete consequence**: a freshly
  scaffolded project lands at `0.1.0` and cannot walk the chain to `0.7.0` in one
  invocation. Fixing it means changing the updater's selection loop to walk a
  contiguous chain recomputing the version after each hop, plus end-to-end fixtures.
  Its own scope. 0009's floor stays `0.6.0 → 0.7.0` (D-42), which is where every
  live project already sits after 0008 — so the defect does not block this phase.
- **`implements_spec` 0.4.0 → 0.5.0+** — appears in 13+ files with no single
  authoritative one. D-17 (Phase 8) already decided the field tracks a full
  conformance audit, not one gate. The source prompt is emphatic this must not be
  absorbed here.
- **Native `~/.codex/hooks.json` PreToolUse enforcement** (HOOK-01) — carried from
  v0.6.0; own phase.
- **Real CI** (CI-01) — `.github/workflows/ci.yml` is still the Phase 0 placeholder
  (`echo` + `exit 0`). `run-tests.sh` runs only locally, so Phase 9 will merge on a
  local green as v0.6.0 did unless this lands first.
- **WR-03** — `--file` symlink-traversal guard is lexical-`..`-only (ADR-0009
  decision 12).
- **Upstream: report that the source prompt's premise is stale** — it describes
  0029 as an existing migration to propagate. If claude-workflow ships 0029
  differently from this design, the two hosts diverge. Worth a note back to
  claude-workflow that codex-workflow implemented from the design, not the code.

### Reviewed Todos (not folded)
None — `todo.match-phase 9` returned zero todos.

</deferred>

---

*Phase: 9-Region-Aware §11 Placement*
*Context gathered: 2026-07-15*
*Prior decisions D-01..D-20 carried from `../08-plan-review-gate/08-CONTEXT.md`; this file starts at D-21.*
