# Roadmap: codex-workflow

## Overview

`codex-workflow` is the OpenAI Codex CLI host binding for the AgenticApps
spec-first workflow defined by `agenticapps-workflow-core`. It is a thin binding
over upstream GSD and Superpowers (ADR-0007), not a re-port.

**Phases 00–07 are pre-GSD legacy and are deliberately not back-filled here.**
They shipped before this repo adopted GSD's project scaffold, and their record
lives in `.planning/phases/<NN>/` (bare-number layout) and `CHANGELOG.md`.
Reconstructing them as roadmap entries would invent history this file cannot
source. GSD roadmap tracking starts at Phase 8.

## Milestones

- ✅ **v0.6.0 Plan-Review Gate** — Phase 8 (shipped 2026-07-15)

## Phases

**Phase Numbering:**

- Integer phases (8, 9, 10): planned work
- Decimal phases (8.1, 8.2): urgent insertions (marked INSERTED)

<details>
<summary>✅ v0.6.0 Plan-Review Gate (Phase 8) — SHIPPED 2026-07-15</summary>

- [x] Phase 8: Plan-Review Gate (9/9 plans — 6 build + 3 gap-closure) — completed 2026-07-15

Bound the core spec §02 `plan-review` pre-execution gate on the Codex host: a
declarative binding in `.planning/config.codex.json` plus a programmatic
verifier (`check-plan-review.sh`) implementing the spec's resolution order and
grandfather rule, the `codex-plan-review` producer skill, and migration 0008 for
existing installs. VERIFICATION `passed` 7/7. Shipped in PR #15 (`cf51c73`).

Full phase detail — goal, canonical refs, all 7 success criteria, the criterion-1
deviation notice, and the wave breakdown — is preserved verbatim in
[`milestones/v0.6.0-ROADMAP.md`](milestones/v0.6.0-ROADMAP.md).
Decision record: [ADR-0009](../docs/decisions/0009-plan-review-gate.md).

</details>

## Progress

| Phase               | Milestone | Plans Complete | Status   | Completed  |
| ------------------- | --------- | -------------- | -------- | ---------- |
| 8. Plan-Review Gate | v0.6.0    | 9/9            | Complete | 2026-07-15 |

## Known Follow-ups

Carried out of v0.6.0, not yet scheduled into a phase:

- **The gate is agent-mediated, not enforced.** Per D-02 / ADR-0009 decision 9,
  `AGENTS.md` ritual text instructs the verifier's invocation but nothing
  executes it, so an agent that omits the call is not blocked. The native
  `~/.codex/hooks.json` `PreToolUse` surface — pointed at this same verifier,
  which is why it already carries a `--file` argument — is deferred to its own
  phase. When it lands, criterion 1 can be restated as an unconditional block.
- **Phase 9 is the first genuinely gated phase.** ADR-0009 decision 8 records
  the bootstrap paradox: Phase 8's own grandfathered pass is not evidence the
  gate works.
- **CI verifies nothing.** `.github/workflows/ci.yml` is still the Phase 0
  placeholder (`echo` + `exit 0`); its own comment promises real checks in
  "Phase 7", which never happened. `migrations/run-tests.sh` (278 assertions)
  runs only locally — v0.6.0 was merged on a local green, not a CI green. A real
  job needs checkout with `submodules: recursive`; the harness hard-fails
  without `vendor/agenticapps-shared`.
- **WR-03** (`--file` symlink-traversal guard is lexical-`..`-only) — accepted
  as a documented limitation, ADR-0009 decision 12, with a concrete future fix
  in that ADR's Open follow-ups.
- **Upstream grandfather-conflation defect** — recorded as an open question for
  a `claude-workflow` bug report, not resolved unilaterally here.
