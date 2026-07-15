# Milestones

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
