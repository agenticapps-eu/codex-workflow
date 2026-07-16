# Milestones

## v0.7.0 Region-Aware §11 Placement (Shipped: 2026-07-16)

**Phases completed:** 2 phases (9 + inserted 9.1), 12 plans

**Delivered:** Migration 0009 heals the §11 coding-discipline block's anchor so a
leading GitNexus region can no longer silently destroy it — with the anchor rule
validated empirically before it was written, and the adjacent data-loss defects
its own code review uncovered closed before close.

**Key accomplishments:**

- **Region-aware anchor rule, validated before it was written.** §11 now inserts
  immediately before the first `## ` heading *or* `<!-- gitnexus:start -->`
  marker — whichever comes first — with an EOF fallback. The ordering constraint
  was enforced as wave topology, not intention: `validate-0009-anchor.sh` ran in
  wave 1 and proved zero-churn re-derivation against real AGENTS.md files
  (ANCHOR-03/04) before authoring began in wave 3. Counter-cases proved the
  assertions discriminate rather than passing vacuously.
- **RED before GREEN, auditable in commit order.** The fixture suite failed
  against the naive anchor before migration 0009 existed (`a4b137f`/`2315393`/
  `185abfd` precede `49b2fab`). Ten fixture cases execute the migration's own
  shell extracted from the document itself — never a transcribed copy (TEST-01),
  retiring the inlined anchor at `run-tests.sh:119` (TEST-04).
- **Phase 9.1 closed three reproduced data-loss paths in the shipped 0009.**
  CR-01 (runaway strip on drifted/orphaned provenance), CR-02 (unanchored
  provenance regex, `PROV_RE` anchored at all four sites), and CR-03 — each first
  reproduced as a falsifiable RED fixture against the unfixed migration, then
  turned GREEN. A phase whose stated purpose was closing a block-destruction
  defect had shipped a *different* one in the adjacent mechanic; the review
  caught it.
- **The migration now actually runs on the projects it targets (V-01).** 0009's
  pre-flight had grepped a project-relative `skills/` path no real install has,
  aborting `exit 3` on every scaffolded project — a byte-for-byte replay of
  migration 0007's known defect. Pre-flight now reads
  `.codex/workflow-version.txt` per 0008's precedent, proven by UAT counterfactual
  against a real target-project shape.
- **Dead assertions killed, not just added to.** Three checks that read as
  coverage but could not fail were fixed: `state-a` rewritten genuinely off-anchor
  (V-02), the vendored mirror's unasserted single-`## ` invariant, and
  `12-idempotent-rerun` — ANCHOR-05's only live coverage of the strip
  terminator's alternation. Each proven by recorded delete-observe-restore
  mutation gates.
- **Decision record and release altitude.** ADR-0010 records the anchor rule, the
  rejected "anchor before the region if one exists" alternative, and §12's
  advisory status — including a dated in-place Correction of two load-bearing
  errors found during review. CHANGELOG.md carries the operator upgrade path.

**Verification at close:** Phase 9 — 21/21 requirements delivered (0
NOT-DELIVERED; 5 gaps deferred to and closed by 9.1). Phase 9.1 — verification
11/11; UAT 10 passed / 1 accepted-and-disclosed; security 37/37 threats closed,
`threats_open: 0`. Full suite 369 PASS / 0 FAIL / 1 SKIP.

**Stats:** 111 commits, 61 files changed (+16,799 / −137), 2026-07-15 → 2026-07-16.

### Known Gaps / Deferred

Consciously scoped out and carried forward as debt — recorded so this milestone's
close does not silently absorb them (see STATE.md Blockers/Concerns):

- `09-REVIEW.md` **WR-05** — `validate-0009-anchor.sh`'s "deterministic banner"
  claim contradicted by its own output.
- `09-REVIEW.md` **IN-01..IN-04** — `extract_step_block` prefix-matching
  `### Step 1` vs `### Step 10`; CASE 1's unasserted line drop; the ADR/migration
  numbering collision; predictable temp-file names in CWD.
- **Migration `0007`'s identical pre-flight defect** — V-01's twin. `0008`
  deferred it explicitly ("different migration, own scope"). Unscheduled.
- **AG-01** (UAT, accepted-and-disclosed by user ruling) — the strip eats
  `<!-- gitnexus:end -->` when §11 sits at a managed region's *tail*. Not
  reachable via migrations 0001/0004, which land §11 at the region head. Disclosed
  in 0009's Known limitations; the durable fix (paired §11 start/end markers,
  retiring the whole inference-based defect class) is ADR-0010's lead open
  follow-up.
- **`T-09.1-25`'s no-temp-files-left check** is a human-facing bullet, not an
  automated assertion. The underlying `rm -f` control is real and verified in code.

**Upstream CR-01 is filed, not outstanding.** The executor's own filing attempt was
denied (the approval reached it via a coordinator relay, not the user directly) and
`09.1-07-SUMMARY.md` records criterion 10 as unsatisfied on that basis — but the
user filed it directly as
[claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90),
scoped to CR-01 only. `09.1-VERIFICATION.md` scored criterion 10 **VERIFIED**
against the live issue; the URL is recorded in `09.1-UPSTREAM-CR-01.md:3` and
`ADR-0010:546`. The SUMMARY's "NOT filed" is the executor's local view, superseded
by verification. Noted here because the two artifacts read as contradictory.

---

## v0.6.0 Plan-Review Gate (Shipped: 2026-07-15)

**Phases completed:** 1 phases, 9 plans, 20 tasks

**Key accomplishments:**

- Repo-root-locating D-05 four-step resolver (pointer → STATE.md → newest-plan-by-mtime → fail-open) with a tri-state ambiguity contract, decimal zero-padding, and all three D-08/D-09 grandfather guards, proven by a 54-case TDD suite — allow paths only, no REVIEWS.md enforcement yet.
- Completed `check-plan-review.sh`'s block path: both escape hatches, the traversal-safe `--file` bypass list, ambiguity- and symlink-safe REVIEWS.md evidence collection, dual-YAML-style frontmatter parsing with distinct-reviewer counting and `plans_reviewed` coverage, and the exit-2 block message — proven by a 30+ case enforcement suite plus a producer↔verifier contract suite that runs this repo's real `08-REVIEWS.md` and the `codex-plan-review` skeleton through the shipped verifier.
- Authored `codex-plan-review` (the >=2-vendor-diverse-reviewer producer skill with a consent-gated, timeout-bounded, advisory-egress-documented procedure) and ADR-0009 (the hybrid declarative+verifier binding decision with all three accepted limitations recorded).
- Bound `pre_execution.plan_review` declaratively in both config files, authored the always-invoke ritual section once and mirrored it byte-identically into AGENTS.md and the trigger SKILL.md, and corrected both bindings tables to 16 distinct gates (D-20 tdd collapse).
- Wrote the idempotent existing-install upgrade path for the plan-review gate — a leaf-level config merge, a template-extracted AGENTS.md ritual insert, and a project version bump — with every merge-safety correction cross-AI review demanded, and bumped this repo's own scaffolder to 0.6.0 in the same commit to keep the drift test green.
- Taught migration 0008 the bindings-table corrections it was missing — a header-shape guard that fails closed rather than silently skipping, and all three row corrections (brainstorm split, tdd collapse, plan-review add) sourced from the same template as the prose — then recorded the whole gate at release altitude in CHANGELOG.md. This is the terminal plan of Phase 8: ROADMAP success criterion #7 is now met.
- Tolerant CR/whitespace-normalized frontmatter delimiter matching plus D-15 codex-exclusion in the reviewer count, closing both verified fail-opens in check-plan-review.sh's REVIEWS.md strictness check.
- Correlated migration 0008 Step 3's plan-review row insertion with its own already-validated `| Gate |` header (instead of the first `|---` line in the file) in both copies of the awk, closing a self-sealing silent-corruption defect reproduced during gap-closure planning.
- Amended ADR-0009 decisions 4, 5, and 11 to record what 08-07/08-08 actually did (not what was predicted), added a new decision 12 accepting WR-03 as a documented limitation, and corrected the fires_when text in both config files (IN-01) to name the REVIEWS.md-evidence condition that actually blocks.

---
