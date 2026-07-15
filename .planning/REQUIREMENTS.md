# Requirements: codex-workflow — v0.7.0 Region-Aware §11 Placement

**Defined:** 2026-07-15
**Core Value:** Projects on the Codex host get the same spec-first gates, in the
same shape, as every other host — installed by scaffold or carried forward by
migration, without hand-editing.

## v0.7.0 Requirements

Requirements for this milestone. Each maps to a roadmap phase.

### Anchor Rule

- [ ] **ANCHOR-01**: The §11 block is inserted immediately before the first line that is either a `## ` heading or a `<!-- gitnexus:start -->` marker — whichever comes first
- [ ] **ANCHOR-02**: When the file has neither a `## ` heading nor a gitnexus marker, the block is appended at EOF
- [ ] **ANCHOR-03**: Replayed against healthy real-world AGENTS.md files with §11 stripped, the rule re-derives the block's current position exactly — zero churn — verified empirically *before* the migration is written
- [ ] **ANCHOR-04**: Replayed against a gitnexus-led AGENTS.md, the rule anchors above the region — verified empirically *before* the migration is written
- [ ] **ANCHOR-05**: The injected block remains followed by a `## ` heading, an anchored `<!-- gitnexus:start -->` marker, or EOF — and **every terminator that bounds the managed section for replace/rollback carries this same alternation**. Corrected 2026-07-15: the original wording ("a `## ` heading or EOF") is false by construction — MIGR-03 anchors the block immediately before a leading `gitnexus:start` marker, so a healed region-led file is followed by that marker, not a `## `. A terminator matching only `/^## /` runs past the marker and consumes the entire GitNexus region. The invariant is not preserved by this phase; it is **widened**. See ADR (DOC-01) and `../claude-workflow/docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` §"The invariant this breaks (corrected 2026-07-15 after Task 2 review)"

### Migration 0009

- [ ] **MIGR-01**: Migration 0009 declares `from_version: 0.6.0` / `to_version: 0.7.0` with a pre-flight gate accepting both installed versions
- [ ] **MIGR-02**: State A — a correctly anchored §11 block carrying current provenance is left byte-identical
- [ ] **MIGR-03**: State B — a §11 block inside a gitnexus region is moved above the region
- [ ] **MIGR-04**: State C — an absent §11 block is injected at the anchor
- [ ] **MIGR-05**: State D — a §11 heading with no provenance comment aborts with `exit 3` and leaves the file unmodified
- [ ] **MIGR-06**: Re-running 0009 on an already-healed file is a no-op — idempotency is provenance-present AND block-not-in-region
- [ ] **MIGR-07**: A §11 block that is healthy but merely off-anchor is left where it is
- [ ] **MIGR-08**: `.codex/workflow-version.txt` records `0.7.0` after the migration applies
- [ ] **MIGR-09**: This repo's own scaffolder version is bumped to 0.7.0 in the same change, keeping the version-coupling drift test green

### Fixtures

- [ ] **TEST-01**: Fixtures execute the migration's shell extracted from the migration document itself, never a transcribed copy
- [ ] **TEST-02**: The fixture suite fails against the naive anchor before migration 0009 exists (RED before GREEN)
- [ ] **TEST-03**: Ten cases are covered: gitnexus-led inject, inside-region move, healthy no-op (proves zero churn), absent instruction file, hand-pasted refusal, no-heading-EOF, **prose-mention-not-a-region** (forces the anchored `/^<!-- gitnexus:start -->$/` regex), **rollback-region-led** (Rollback must not orphan the region), **two-provenance-heal** (guards the `swallowed_own_h2` stale-state bug — two blocks must heal to one), and **corrupt-mirror-refused** (binds both D-28.1 guard layers: zero-byte via `test -s`, truncated via tail sentinel, healthy passes). Widened from six on 2026-07-15 (D-46): the last four are `claude-workflow`'s post-review additions, each encoding a defect it actually hit — it describes the first two as "the two gaps that let a green suite ship file-destroying bugs"
- [ ] **TEST-04**: The inlined anchor copy at `migrations/run-tests.sh:119` is replaced by document-sourced extraction

### Setup Parity

- [ ] **SETUP-01**: Setup's §11 placement is confirmed to derive solely from migration 0001's replay with no independent anchor, and that single-source fact is recorded so a future anchor change knows where to look (spec §08: setup end-state ≡ full replay)

### Documentation

- [ ] **DOC-01**: An ADR records the anchor decision, including the rejected "anchor before the region if one exists" alternative and why it violates §12's placement advisory
- [ ] **DOC-02**: CHANGELOG records the fix at release altitude

## Future Requirements

Deferred. Tracked but not in this roadmap.

### Enforcement

- **HOOK-01**: Bind `check-plan-review.sh` to the native `~/.codex/hooks.json` `PreToolUse` surface so the plan-review gate blocks unconditionally (carried from v0.6.0; ADR-0009 decision 9)

### CI

- **CI-01**: Replace the Phase 0 placeholder `.github/workflows/ci.yml` (`echo` + `exit 0`) with a real job running `migrations/run-tests.sh`, checked out with `submodules: recursive`

### Hardening

- **WR-03**: Replace the lexical-`..`-only `--file` symlink-traversal guard with a real path-resolution check (ADR-0009 decision 12)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Resolving the `implements_spec` version gap | Appears in 13+ files with no single authoritative one; separate work (cf. ADR-0019 "declared paths, not discovered"). Absorbing it blurs a placement fix into a spec-versioning change. |
| Editing migrations 0001 / 0004 | Immutable once shipped. Their `to_version` is long past so they never replay, and their pre-flight gate aborts the `--migration NNNN` force path. Fix forward only. |
| Moving a healthy §11 block that sits off the canonical anchor | No failure mode motivates it; it churns project files. |
| The "anchor before `gitnexus:start` if a region exists, else first `## `" rule | Rejected. When the region starts late, it drops §11 hundreds of lines down, violating §12's "near the top" advisory. The region is only the anchor when it comes first. |
| A setup-side anchor parity guard | Verified 2026-07-15: setup has no independent placement logic. `0000-baseline.md:102` is a plain append and `agents-md-additions.md` carries no §11. There is no second anchor to guard. SETUP-01 records the fact instead. |
| Retiring a CHANGELOG "known issues" entry | Verified 2026-07-15: CHANGELOG.md has no known-issues section. The source prompt's instruction is a no-op here. |
| Repairing a live broken repo | Verified 2026-07-15: §11 sits at L18, the region at L271–313. The region does not lead the file; the defect is latent on this host. |
| Back-filling phases 00–07 into ROADMAP.md | Predates this repo's GSD adoption; would invent unsourceable history. |

## Traceability

Which phases cover which requirements. Confirmed during roadmap creation
2026-07-15: this milestone is a single phase (Phase 9), not a placeholder. The
21 requirements were weighed against a split (e.g. anchor-validation vs.
migration vs. docs) but kept together because (a) v0.6.0 shipped as one
well-decomposed phase with 9 plans, the same order of magnitude as this
milestone's 21 requirements, and (b) the two hard ordering constraints —
validate the anchor rule empirically before writing the migration (ANCHOR-03/
04), and TDD RED (TEST-02) before the migration exists — are sequencing
constraints *within* a phase's plan waves, not natural phase boundaries; see
ROADMAP.md Phase 9's "Ordering constraints" note.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ANCHOR-01 | Phase 9 | Pending |
| ANCHOR-02 | Phase 9 | Pending |
| ANCHOR-03 | Phase 9 | Pending |
| ANCHOR-04 | Phase 9 | Pending |
| ANCHOR-05 | Phase 9 | Pending |
| MIGR-01 | Phase 9 | Pending |
| MIGR-02 | Phase 9 | Pending |
| MIGR-03 | Phase 9 | Pending |
| MIGR-04 | Phase 9 | Pending |
| MIGR-05 | Phase 9 | Pending |
| MIGR-06 | Phase 9 | Pending |
| MIGR-07 | Phase 9 | Pending |
| MIGR-08 | Phase 9 | Pending |
| MIGR-09 | Phase 9 | Pending |
| TEST-01 | Phase 9 | Pending |
| TEST-02 | Phase 9 | Pending |
| TEST-03 | Phase 9 | Pending |
| TEST-04 | Phase 9 | Pending |
| SETUP-01 | Phase 9 | Pending |
| DOC-01 | Phase 9 | Pending |
| DOC-02 | Phase 9 | Pending |

**Coverage:**
- v0.7.0 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-15*
*Last updated: 2026-07-15 after roadmap creation (Phase 9 confirmed as single-phase milestone)*
