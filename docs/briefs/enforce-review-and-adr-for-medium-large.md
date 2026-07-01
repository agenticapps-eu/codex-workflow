# Brief — Require the independent review gate + an ADR for medium/large tasks

**Repo:** `codex-workflow` · **Type:** Claude Code / Codex execution brief
**Author context:** cross-host workflow benchmark (2026-07-01)

## Why

A three-host benchmark (Codex vs opencode/GLM-5.2 vs Claude Code) ran the *same*
"medium" feature through each host's AgenticApps workflow. opencode and Claude
both fired the full gated loop — `discuss → plan → RED→GREEN → verify →
independent stage-2 code review → ADR` — and recorded the key design decision in
`docs/decisions/NNNN-*.md`. **Codex ran a valid but thinner loop:** it produced
`CONTEXT/PLAN/VERIFICATION`, did one RED→GREEN pair, but **skipped the
independent code-review gate and never wrote an ADR** (the decision lived only in
`CONTEXT.md`). That thinness is why it finished ~10× faster — but for a *medium*
task the workflow is supposed to require both. This brief closes that gap.

## Goal

For **medium** and **large** task sizes, make these two gates **mandatory**
(not skippable, accept-via-ADR is the only override):

1. **Independent stage-2 code review** (`codex-code-review`) must run and leave
   evidence (a `REVIEW.md`).
2. **An ADR** (`docs/decisions/NNNN-slug.md`) must record any locked design
   decision (ordering, schema, algorithm/policy choice, API shape). A decision
   captured only in `CONTEXT.md` is **not** sufficient for medium/large.

**Tiny** and **Small** tasks are exempt (keep them fast).

## Changes to make

Work through codex-workflow's own workflow (it self-applies). Before editing any
symbol, run `gitnexus_impact` per this repo's CLAUDE.md.

1. **Trigger skill routing** — `skills/agentic-apps-workflow/SKILL.md`, task-size
   table: for Medium and Large, list `codex-code-review` **and** "write/append an
   ADR for any locked decision" as **required** steps. State explicitly that
   `codex-verification` must refuse completion if either is missing.

2. **Gate config** — `.planning/config.json` (and the setup template
   `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json`): mark
   `post_phase.code_review` as non-skippable for medium/large, and add an
   `adr_required` rule (fires when the phase locks a design decision;
   evidence = `docs/decisions/NNNN-*.md`).

3. **Verification evidence** — `skills/codex-verification/SKILL.md`: for
   medium/large, add two required evidence shapes: `review_file` (a `REVIEW.md`
   from stage-2) and `adr_file` (a matching `docs/decisions/NNNN-*.md`).
   Verification fails if a medium/large phase locked a decision without an ADR,
   or completed without a review file.

4. **Ship as a migration** — codex-workflow installs via migrations. Add
   `migrations/NNNN-require-review-adr-medium-large.md` (idempotency check +
   rollback + fixture per `migrations/README.md`), bump the trigger skill
   `version:` to the migration's `to_version`, and update the setup templates so
   fresh projects get the enforcement. Run `migrations/run-tests.sh NNNN` green.

## Acceptance criteria (verifiable)

- The trigger skill's Medium/Large rows explicitly name `codex-code-review` +
  "ADR required" as mandatory, and say verification blocks without them.
- A medium task run produces both a `REVIEW.md` and a `docs/decisions/NNNN-*.md`;
  `codex-verification` fails a medium run that lacks either (demonstrate with the
  benchmark's "Checkout totals" task: it must now emit an ADR like the opencode
  and Claude runs did).
- Tiny/Small runs are unchanged (no forced review/ADR).
- New migration has a passing fixture; `detect_changes` shows only the intended
  scope; `run-tests.sh` green.

## Non-goals

- Do not touch Tiny/Small routing.
- Do not add a review gate to non-decision medium tasks' *ADR* requirement — the
  ADR is required only when a design decision is actually locked (the review gate
  is always required for medium/large).
