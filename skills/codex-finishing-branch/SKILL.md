---
name: codex-finishing-branch
version: 0.1.0
implements_spec: 0.1.0
implements_gate: branch-close
description: |
  Compose a PR description from the phase artifacts (CONTEXT.md,
  PLAN.md, VERIFICATION.md, REVIEW.md, SECURITY.md, DB-AUDIT.md,
  IMPECCABLE-AUDIT.md, DEBUG.md as applicable), enumerate any
  remaining should_have gaps with owners, link every artifact, and
  open the PR. Use when a feature branch is ready to merge — all
  must_haves have evidence, both review stages have verdicts, and any
  blocking audit findings are fixed or accepted via ADR.
---

# codex-finishing-branch

This skill fulfills the `branch-close` gate from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md).

## When to invoke

Feature branch is ready to merge:

- All must_haves in VERIFICATION.md have at least one Evidence
  subrow (per `codex-verification`)
- REVIEW.md contains both `## Stage 1 — Spec compliance` and
  `## Stage 2 — Code quality` with non-`block` verdicts (per
  `codex-spec-review` and `codex-code-review`)
- SECURITY.md exists and verdict is non-`block` (where the security
  gate fired)
- DB-AUDIT.md has zero unaccepted Critical / High findings (where
  the database-security gate fired)
- IMPECCABLE-AUDIT.md has zero unaccepted Red findings (where the
  impeccable-audit gate fired)

If any of the above is `block` or missing, fix or accept-via-ADR
before invoking this skill — the gate's job is to compose, not to
absolve.

## What this skill does

1. **Enumerate the phase artifacts.** Walk
   `.planning/phases/<N>/*.md` and capture each artifact's path:
   - `CONTEXT.md` — design and architectural decisions
   - `PLAN.md` — task list and gate triggers
   - `RESEARCH.md` (if present) — architecture alternatives
   - `UI-SPEC.md` (if present) — chosen UI variant
   - `VERIFICATION.md` — must_haves and evidence
   - `REVIEW.md` — Stage 1 + Stage 2
   - `SECURITY.md` (if present)
   - `DB-AUDIT.md` (if present)
   - `IMPECCABLE-AUDIT.md` (if present)
   - `QA.md` (if present)
   - `DEBUG.md` (if a bugfix phase)
2. **Walk the should_have gaps.** Each PLAN.md task that was carried
   forward (not completed in this phase) gets a row in the PR
   description with: gap description, owner, target phase. If no
   gaps, write "None".
3. **Compose the PR body.**

   ```markdown
   ## Summary

   - <one-line per major shipped behavior>

   ## Phase artifacts

   - CONTEXT.md: <relative path>
   - PLAN.md: <relative path>
   - VERIFICATION.md: <relative path>
   - REVIEW.md: <relative path>
   - SECURITY.md: <relative path | N/A>
   - DB-AUDIT.md: <relative path | N/A>
   - IMPECCABLE-AUDIT.md: <relative path | N/A>
   - QA.md: <relative path | N/A>

   ## Verdicts

   - Stage 1 review: <clean | clean-with-followups>
   - Stage 2 review: <pass | pass-with-followups>
   - Security: <pass | pass-with-followups | N/A>
   - Database security: <pass | accepted-via-ADR-NNNN | N/A>
   - Impeccable audit: <pass | accepted-via-ADR-NNNN | N/A>
   - QA: <pass | pass-with-followups | N/A>

   ## should_have gaps carried forward

   | Gap | Owner | Target phase |
   |---|---|---|

   ## Test plan

   - [ ] <what the reviewer should manually validate>
   ```
4. **Open the PR.** Use `gh pr create --title "<phase-name>" --body
   "<composed body>"`. Title format follows the project's
   convention; if none, default to `Phase N: <one-line goal>`.
5. **Update the phase index.** Append the PR URL to the phase's
   `SUMMARY.md` (if the project tracks one) and to the project's
   `CHANGELOG.md` under "Unreleased" if a release-tracking workflow
   is in play.

## Required evidence (per spec/06)

- The PR description (or merge-request body) contains:
  - A summary of shipped scope
  - A link to every phase artifact
  - The verdict for every fired gate
  - The should_have gaps carried forward (or "None")
  - A test plan checklist

## Failure modes

- **Skipping the gap section.** "We'll catch it in the next phase"
  loses the breadcrumb. Write the gaps with owners.
- **PR body that paraphrases artifacts instead of linking them.**
  The artifacts ARE the evidence; the PR body points to them.
- **Opening the PR before all gates pass.** Block-verdict gates fix
  before this skill runs; "we'll address review feedback in the PR"
  conflates two distinct review stages with the human PR review.
- **Composing without reading the artifacts.** The PR body's truth
  comes from on-disk content; if you don't read them, you'll
  paraphrase from memory and the paraphrase will drift.

## Notes for the Codex host

- The `gh` CLI is the standard mechanism. If the project uses a
  different forge (GitLab, Gitea), use that forge's CLI.
- If the project's `AGENTS.md` documents a specific PR title /
  description convention, use it; otherwise default to the skeleton
  above.
- Phase 6's self-applied workflow uses this skill to open every PR
  in this repo — including the PRs for Phases 2–7 themselves.
