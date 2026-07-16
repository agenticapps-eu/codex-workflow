# Requirements: codex-workflow — Milestone v0.8.0 "Enforcement, Not Intention"

**Defined:** 2026-07-16
**Core Value:** Projects on the Codex host get the same spec-first gates, in the
same shape, as every other host — installed by scaffold or carried forward by
migration, without hand-editing.

**Milestone goal:** Every gate this host claims to bind actually fires, every
migration actually runs, and every assertion has been observed failing — closing
the "nominal enforcement" debt class the last two milestones shipped on top of.

**Grounding:** Requirements are sourced from `.planning/research/SUMMARY.md`
(HIGH confidence, primary sources) and the three requirement-author decisions
taken 2026-07-16:
1. **0008-payload scope:** the 0007-fix migration heals 0007 only (Steps 1/2/4 +
   version record); 0008/0009 fire normally on the next update pass once the
   version record reads 0.5.0. Not re-delivering 0008's payload.
2. **Chain acceptance bar (weak):** each migration, run individually, completes
   without aborting on a real-target-shaped fixture. The update skill's multi-hop
   single-invocation cascade defect is a named, deliberately-deferred gap.
3. **CI matrix:** ubuntu + macOS (the suite's own comments flag BSD/GNU shell
   divergence).

**Milestone-wide standard (applies to every requirement below):** a guard is not
shipped until it has been *observed failing*. Every new assertion this milestone
adds must be mutation-proven — break the thing it checks, watch it go RED, restore
— and the verifier re-runs that cycle independently rather than trusting an
executor's claim. This is the exact discipline the milestone exists to enforce;
it is not optional per-item polish.

## v0.8.0 Requirements

### Continuous Integration (CI)

- [x] **CI-01**: A GitHub Actions workflow runs on push and pull_request to `main`,
      checks out with `submodules: recursive` (the harness hard-fails without
      `vendor/agenticapps-shared`), runs `migrations/run-tests.sh` unfiltered
      (which already exercises `test_drift`), on an ubuntu + macOS matrix, and the
      job's own exit status reflects the suite's — no `|| true`, no informational
      bolt-on.
- [x] **CI-02**: CI is proven able to go RED — a scratch PR carrying a deliberately
      reverted guard is observed failing in the GitHub Actions UI itself (not just
      a local run), and the new check is registered as a required status check on
      `main`'s branch protection (`gh api .../branches/main/protection`).

### Migration Chain Repair (MIGR)

- [x] **MIGR-10**: A new forward migration (next available ID) heals migration
      0007's chain break for existing installs — its pre-flight reads
      `.codex/workflow-version.txt` exclusively (a direct reuse of 0008's proven
      pattern, never a `skills/**/SKILL.md` grep), and it re-delivers 0007's
      Steps 1/2/4 payload (knowledge-capture config block + AGENTS.md ritual-tail
      section + `0.5.0` version record), dropping 0007's Step 3 MIGR-09
      scaffolder-version-bump violation.
- [ ] **MIGR-11**: `update-codex-agenticapps-workflow/SKILL.md` Stage D documents how
      a permanently-aborting migration-level pre-flight (0007) is handled once a
      superseding migration covers the same `0.4.0→0.5.0` transition — so an
      operator on a stuck 0.4.0 project has a defined, non-looping path forward.
- [ ] **MIGR-08**: A fixture extracts migration 0008's Step 4 Apply block via
      `extract_step_block` (not a hand-copied transcription), executes it against a
      sandbox seeded at the pre-migration value, and asserts exact
      `.codex/workflow-version.txt` content equality — mutation-proven by breaking
      the write line and observing RED. Closes the one residual of the exact
      can't-fail-assertion class Phase 9.1 existed to close.

### Native Enforcement — Plan-Review Hook (HOOK)

- [ ] **HOOK-01**: The plan-review gate blocks unconditionally on codex-cli's native
      `PreToolUse` surface — a disallowed edit, driven through the real Codex CLI
      tool surface in a live human-observed session, is observably prevented
      end-to-end (not merely a script-level unit test passing). Supersedes
      ADR-0009 d.9's agent-mediated binding.
- [ ] **HOOK-02**: A new wrapper script (shipped via `install.sh`) reads the hook's
      stdin JSON payload, derives the `--file` argument (hooks.json `command` is a
      static string with no templating), execs `check-plan-review.sh --file <path>`,
      and translates its result into the hook's `permissionDecision: "deny"` block
      shape as the primary path — with any exit-2 fallback path guaranteed to write
      non-empty stderr (exit 2 with empty stderr *fails open*, the milestone's
      nemesis).
- [ ] **HOOK-03**: A new forward migration installs the `PreToolUse` entry into a
      **project-scoped** `<repo>/.codex/hooks.json` (merge-don't-clobber, per the
      `0000-baseline` Step 6 precedent) and enables the hooks feature flag; the
      binding is verified firing in the target repo AND verified *not* firing in a
      second unrelated repo on the same machine.

### Paired §11 Markers (MARK)

- [ ] **MARK-01**: A new forward migration inserts explicit start/end markers bounding
      the managed §11 block (closing-marker syntax chosen at plan time to mirror the
      existing `<!-- BEGIN/END: agentic-apps-workflow sections -->` idiom), reusing
      migration 0009's re-vendor structure.
- [ ] **MARK-02**: §11 strip/replace logic keys off the explicit end marker as a
      **fourth** alternative alongside the existing three-way terminator alternation
      (`## ` heading | anchored `gitnexus:start` | EOF) — strictly additive, never a
      replacement. `12-idempotent-rerun` stays green (unmodified, or changed only
      with a mutation-justified equivalent), and each of the four alternation
      branches is mutation-tested independently.
- [ ] **MARK-03**: AG-01 (the region-*tail* strip hazard — the strip eating
      `<!-- gitnexus:end -->` when §11 sits at a managed region's tail) is closed: a
      fixture reproduces it failing under the pre-marker inference logic and passing
      under the marker-bounded logic. Reverses the 2026-07-16 accepted-and-disclosed
      ruling.
- [ ] **MARK-04**: The paired-markers migration's Apply blocks use `mktemp`
      (same-filesystem, preserving atomic `mv`), which closes IN-04 (predictable
      temp-file names in CWD) by supersession rather than editing the immutable
      migration 0009.

### Path Safety & Review Debt (WR / REV)

- [ ] **WR-03**: `check-plan-review.sh`'s `--file` guard canonicalizes the *parent
      directory* of the path (via the existing `_canon_dir` / `_is_contained`
      helpers) and rejects a symlink-resolved escape — replacing the lexical-`..`
      -only check. Reverses ADR-0009 d.12. Fixtures cover a symlinked parent
      directory and a sibling-prefix collision, not just a leaf symlink. (TOCTOU is
      explicitly out of scope — do not build a second path-safety primitive.)
- [ ] **REV-01**: WR-05 — `validate-0009-anchor.sh`'s stdout is genuinely
      deterministic: a full-script grep for every mirror-derived stdout value
      (not just the banner) confirms no non-deterministic content, mutation-proven.
- [ ] **REV-02**: IN-01 — `extract_step_block` no longer prefix-matches `### Step 1`
      against `### Step 10`+, verified against a synthetic 10+-step document.
- [ ] **REV-03**: IN-02 — the previously-unasserted line-drop in CASE 1 is asserted
      with a strictly-smaller-count check (no hardcoded line number), mutation-proven.
- [ ] **REV-04**: IN-03 — the ADR/migration numbering collision is corrected in
      `docs/decisions/README.md` so ADR numbers and migration numbers cannot be
      conflated (this is the constraint the roadmapper must honor when assigning
      MIGR-10 / HOOK-03 / MARK-01 migration numbers).

### Decision Records (DOC)

- [ ] **DOC-03**: ADR-0009 carries a dated Correction section recording: d.9
      superseded (HOOK-01 native block), d.12 reversed (WR-03 real guard), and the
      factual correction of its false "native hooks are global rather than
      per-project" claim (falsified by codex-cli's project-scoped `.codex/hooks.json`
      layer).
- [ ] **DOC-04**: ADR-0010 carries a dated Correction section closing its lead open
      follow-up — AG-01 is resolved by paired §11 markers (MARK-01..03).

## Future Requirements

Deferred beyond v0.8.0. Tracked, not in this roadmap.

### Update-skill robustness

- [ ] **MIGR-FUT-01**: The update skill's multi-hop chain-selection defect — a
      project at 0.4.0 picks up only one migration per invocation rather than
      cascading 0007-fix→0008→0009 in a single pass (0008's own Notes). This is the
      "strong" interpretation of "chain runs end to end"; v0.8.0 deliberately ships
      the weak bar and names this as the deferred remainder.

## Out of Scope

Explicit boundaries, with reasoning to prevent silent re-adding.

- **Re-delivering 0008's payload in the 0007-fix migration** — decided against
  (decision 1 above): once the version record reads 0.5.0, 0008 is itself correct
  and fires through the normal update flow. Duplicating it would re-implement
  0008's idempotency logic in a second place.
- **Editing migrations 0001/0004/0007/0009** — immutable once shipped. Every fix
  is a new forward migration (MIGR-10, HOOK-03, MARK-01). IN-04 is closed by
  MARK-04's `mktemp` in the new migration, not by editing 0009.
- **CI lint / shellcheck / caching, and a full scaffold-and-migrate E2E smoke
  test** — beyond CI-01's stated definition. The E2E smoke would more directly
  have caught 0007's bug class, but is scope expansion; named here so it isn't
  silently assumed delivered.
- **The general per-repo hook-scoping problem, and extending native binding to the
  other 15 declarative gates** — HOOK-01 scopes to the plan-review gate only.
- **A generic pluggable marker framework** — MARK scopes to §11 only. WR-01 (the
  mirror single-`##`-heading coupling) is a separate real defect, not folded in.
- **Closing TOCTOU races in WR-03** — the guard canonicalizes and boundary-checks;
  it does not attempt to defeat time-of-check/time-of-use.
- **The update-skill multi-hop cascade defect** — see Future Requirements; the weak
  chain bar is v0.8.0's deliberate ceiling.

## Traceability

<!-- Filled by the roadmapper: each REQ-ID → phase. -->

| REQ-ID | Phase | Status |
|--------|-------|--------|
| CI-01 | 10 | Complete |
| CI-02 | 10 | Complete |
| MIGR-10 | 11 | Complete |
| MIGR-11 | 11 | Pending |
| MIGR-08 | 11 | Pending |
| HOOK-01 | 13 | Pending |
| HOOK-02 | 13 | Pending |
| HOOK-03 | 13 | Pending |
| MARK-01 | 14 | Pending |
| MARK-02 | 14 | Pending |
| MARK-03 | 14 | Pending |
| MARK-04 | 14 | Pending |
| WR-03 | 12 | Pending |
| REV-01 | 12 | Pending |
| REV-02 | 12 | Pending |
| REV-03 | 12 | Pending |
| REV-04 | 12 | Pending |
| DOC-03 | 13 | Pending |
| DOC-04 | 14 | Pending |
| MIGR-FUT-01 | Deferred (Future Requirements) | Not in v0.8.0 |

**Coverage:** 19/19 v0.8.0 requirements mapped to Phases 10-14. `MIGR-FUT-01`
is Future Requirements scope, not v0.8.0 — listed above for completeness only,
not counted in the 19.
