# Phase 11: Migration Chain Repair - Context

**Gathered:** 2026-07-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Heal migration 0007's chain break so real (non-scaffolder) installs stuck between
`0.4.0` and `0.5.0` can move forward, and close the MIGR-08 test-coverage gap.
Delivers three requirements: **MIGR-10** (new forward migration 0010 that re-delivers
0007's payload with a corrected pre-flight), **MIGR-11** (update-skill Stage D
documentation of the non-looping recovery path), and **MIGR-08** (a mutation-proven
fixture that executes migration 0008's Step 4 Apply block against a seeded sandbox).

**Root cause being fixed:** migration 0007's pre-flight greps a scaffolder-relative
path (`skills/agentic-apps-workflow/SKILL.md`) that no real target project has, so it
hard-aborts (exit 3) before writing anything — no config block, no AGENTS.md section,
no version bump. 0008/0009 read `.codex/workflow-version.txt` correctly, but their
floor checks can never pass because the version record 0007 was supposed to advance
never moved. This repo hid the bug because it uniquely has a local `skills/` tree
(it *is* the scaffolder) — the same "sandbox manufactures the precondition" failure
class the milestone exists to close.

**In scope:** migration 0010 (0007-fix), MIGR-08 coverage fixture, MIGR-11 Stage D docs.
**Out of scope:** HOOK-01/HOOK-02/HOOK-03 (later phase), paired §11 markers (Phase 14),
WR-03 / 09-REVIEW cleanups (Phase 12), REV-04 ADR/migration numbering-doc fix (Phase 12),
any multi-migration end-to-end harness, and healing the version pointer alone without
re-delivering 0007's payload (that reproduces the exact bug class).

</domain>

<decisions>
## Implementation Decisions

### Migration 0010 — version-gate strictness (the "manual 0.5.0 escape" edge)
- **D-01:** Migration 0010's pre-flight uses a **strict version-floor** that is a
  verbatim reuse of migration 0008's proven check (0008 lines ~73–79: gate on
  `.codex/workflow-version.txt` reading `< 0.5.0`, accept `0.5.0` only for idempotent
  re-apply). Do **not** add payload-presence detection (checking for a missing
  `knowledge_capture` config block or AGENTS.md ritual-tail) to the migration's code.
  Rationale: the requirement mandates a verbatim reuse of 0008's pattern; adding
  detection logic is exactly the "derive by analogy / widen the surface" move PITFALLS
  #2 warns against, and the manual-escape operator is a hypothesized edge, not a
  confirmed population.
- **D-02:** The operator who manually forced `.codex/workflow-version.txt` to `0.5.0`
  to escape 0007's abort (now at `0.5.0` with none of 0007's payload) is handled by
  **documentation, not code** — their recovery lives in MIGR-11's Stage D (see D-04),
  not in a new detection branch inside 0010.

### Migration 0010 — payload contract
- **D-03:** 0010 re-delivers 0007's **Steps 1, 2, and 4** — (1) the host-neutral
  `knowledge_capture` block into `.planning/config.json`, (2) the "Knowledge Capture —
  Ritual Tail" section into `AGENTS.md`, (4) the `0.5.0` record into
  `.codex/workflow-version.txt` — and **drops 0007's Step 3** (the scaffolder
  version-bump, a MIGR-09 immutability violation). The pre-flight must grep
  `.codex/workflow-version.txt` **exclusively** — never any `skills/**/SKILL.md` path.

### MIGR-11 — Stage D documentation depth
- **D-04:** MIGR-11's Stage D in `update-codex-agenticapps-workflow/SKILL.md` is a
  **concise recovery runbook** — the defined, non-looping steps plus exact commands.
  It must cover (a) the operator stuck on 0007's permanently-aborting pre-flight
  (0007 is superseded by 0010; re-run the update to apply 0010 instead), and
  (b) the manual-0.5.0-escape operator from D-02 (how to obtain 0007's missing payload).
  Enough to act on — not a one-line note (too thin for MIGR-11's "defined path" goal)
  and not exhaustive per-state prose (doc-rot risk).

### MIGR-08 & chain-proof — test scope
- **D-05:** MIGR-08's fixture extracts migration 0008's Step 4 Apply block via
  `extract_step_block` (never a hand-copied transcription), executes it against a
  sandbox seeded at the **pre-migration value** (`0.5.0`), and asserts **exact**
  `.codex/workflow-version.txt` content equality. Mutation-proven: break the write
  line → observe RED → restore; the verifier independently re-runs the cycle rather
  than trusting the executor's claim.
- **D-06:** The chain-healed proof scope is **payload delivery + version assertion**,
  not a new multi-migration end-to-end harness. The 0010 fixture starts from a clean
  `0.4.0` sandbox carrying **none** of 0007's artifacts, applies 0010, and asserts both
  (i) the config block + AGENTS.md ritual-tail section were delivered, and (ii)
  `.codex/workflow-version.txt` now reads `0.5.0`. The version assertion cheaply bridges
  to the chain claim (0008's floor check would now be satisfiable) without building a
  `0.4.0 → 0010 → 0008 → 0009` fixture — 0008/0009 are already independently tested,
  and research explicitly flags the full E2E chain fixture as over-build for v0.8.0.

### Anti-pattern guardrails (carried from research/PITFALLS — MUST hold)
- **D-07:** A document-contract fixture must assert 0010's pre-flight literal executable
  line does **not** contain any `skills/agentic-apps-workflow` substring (proves the
  original bug is not re-introduced by copy-paste). The 0010 fixture sandbox must **not**
  manufacture a local `skills/` tree — it must use the no-local-`skills/`-tree shape of a
  real target project.

### Claude's Discretion
- Migration 0010's exact ID is fixed at `0010` (next sequential migration ID; research
  names it "Migration 0010"). Migration IDs and ADR IDs have already diverged and are
  independent sequences — the ADR/migration numbering-doc reconciliation (IN-03/REV-04)
  is Phase 12's job, not this phase's.
- Fixture file naming/placement, exact runbook wording, and step ordering within 0010
  (beyond the locked payload/pre-flight contract) are the planner's/executor's discretion.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The chain break and its fix
- `migrations/0007-knowledge-capture.md` — the broken migration; Steps 1/2/4 payload to
  re-deliver, Step 3 to drop, and the scaffolder-relative pre-flight grep that is the bug.
- `migrations/0008-plan-review-gate.md` §Pre-flight (lines ~54–79) — the **verbatim**
  version-floor pattern 0010's pre-flight must reuse (`.codex/workflow-version.txt`
  exclusively; the "DELIBERATE DIVERGENCE from 0007's floor check" comment explains why).
- `migrations/0008-plan-review-gate.md` §Step 4 — the Apply block MIGR-08's fixture
  extracts via `extract_step_block` and asserts exact content equality against.
- `migrations/README.md` — the migration contract (`applies_to` surface, what is/ isn't a
  migration; confirms MIGR-08/doc/fixture work are not themselves migrations).

### Requirements & research
- `.planning/REQUIREMENTS.md` §Migration Chain Repair (MIGR-10, MIGR-11, MIGR-08) —
  the locked requirement text (reads as acceptance criteria).
- `.planning/research/SUMMARY.md` — chain-break mechanism (Q1), "exactly 3 new migrations"
  (Q2), build-order Track A, and the "explicitly do NOT over-build" list.
- `.planning/research/PITFALLS.md` — Pitfall #2 (0007-fix repeats V-01 verbatim) and
  Pitfall #5 (fixture asserts a value the setup already guarantees) — the two failure
  modes this phase must actively disprove.
- `.planning/research/ARCHITECTURE.md` — Migration 0010 (0007-fix) component notes.

### Update-skill documentation target
- `skills/update-codex-agenticapps-workflow/SKILL.md` §Stage D — where MIGR-11's concise
  recovery runbook lands.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `migrations/0008-plan-review-gate.md` pre-flight — copy the floor-check block directly;
  do not redesign it.
- `extract_step_block` (in `migrations/run-tests.sh` / shared helpers) — the mechanism
  MIGR-08's fixture uses to pull 0008's Step 4 Apply block instead of hand-copying.
- `migrations/run-tests.sh` — the harness that runs all fixtures unfiltered (already
  exercises `test_drift`); new fixtures register here and are what CI (Phase 10) now runs.
- `migrations/test-fixtures/` — existing fixture shapes to mirror (including the
  no-local-`skills/`-tree sandbox construction).

### Established Patterns
- Migration frontmatter `from_version` / `to_version` gating; 0010 slots at the exact
  `0.4.0 → 0.5.0` transition 0007 occupies (0007 wrote nothing to heal-from).
- Idempotency checks per step (0007 Step 4 used `grep -q '^0.5.0$'`); 0010 must be
  re-apply-safe using 0008's accept-floor-or-target pattern.
- Mutation-proof discipline (break the asserted line → RED → restore; verifier re-runs).

### Integration Points
- `.codex/workflow-version.txt` is the single source of truth every post-0007 migration
  reads; healing it (via 0010's Step 4) is what re-enables 0008/0009's own logic.
- Fixtures land in `run-tests.sh`, which Phase 10's CI executes on ubuntu + macOS.

</code_context>

<specifics>
## Specific Ideas

- Reuse 0008's pre-flight **verbatim** — the user/requirement is explicit that this is a
  direct copy, not a fresh design.
- The 0010 fixture must reproduce a real install's shape (no local `skills/` tree), the
  exact condition whose absence hid the original bug.

</specifics>

<deferred>
## Deferred Ideas

- Payload-presence backfill inside migration 0010 (heal manual-0.5.0-escape operators in
  code) — considered and rejected for this phase (D-01/D-02); handled by MIGR-11 docs
  instead. Could revisit if a real population of hand-hacked installs is confirmed.
- Full `0.4.0 → 0010 → 0008 → 0009` end-to-end chain fixture — deferred as over-build for
  v0.8.0 (D-06); 0008/0009 are independently tested.
- ADR/migration numbering-doc reconciliation (IN-03 / REV-04) — belongs to Phase 12
  (Path Safety & Review Debt).

None of these are in scope for Phase 11.

</deferred>

---

*Phase: 11-migration-chain-repair*
*Context gathered: 2026-07-16*
