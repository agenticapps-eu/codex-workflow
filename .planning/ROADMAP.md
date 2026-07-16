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
- ✅ **v0.7.0 Region-Aware §11 Placement** — Phases 9, 9.1 (shipped 2026-07-16)

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

<details>
<summary>✅ v0.7.0 Region-Aware §11 Placement (Phases 9, 9.1) — SHIPPED 2026-07-16</summary>

- [x] Phase 9: Region-Aware §11 Placement (5/5 plans) — completed 2026-07-16
- [x] Phase 9.1: §11 Strip Runaway (INSERTED 2026-07-15) (7/7 plans) — completed 2026-07-15

Migration 0009 heals the §11 coding-discipline block's anchor so a leading
GitNexus region can no longer silently destroy it. The anchor rule — insert
before the first `## ` heading or `<!-- gitnexus:start -->` marker, whichever
comes first, EOF fallback — was validated empirically *before* the migration was
written (enforced as wave topology, not intention), and the fixture suite was
observed RED against the naive anchor before 0009 existed.

Phase 9's code review then reproduced a **different** block-destruction defect in
the mechanic adjacent to the one being hardened. Phase 9.1 was inserted to close
it: CR-01 (runaway strip to EOF), CR-02 (unanchored provenance regex), CR-03
(dead `test -s` assertion), plus V-01 — the pre-flight that aborted `exit 3` on
every real target project, meaning the migration never ran on the projects it
existed to fix.

21/21 requirements delivered. Phase 9 VERIFICATION scored 0 NOT-DELIVERED with 5
gaps deferred to and closed by 9.1 (ANCHOR-05, MIGR-01, MIGR-06, MIGR-07,
MIGR-08). Phase 9.1: verification 11/11; UAT 10 passed / 1 accepted-and-disclosed
(AG-01); security 37/37, `threats_open: 0`. Full suite 369 PASS / 0 FAIL / 1 SKIP.

Full phase detail — both phase goals, all success criteria, the ordering
constraints, and the wave breakdowns — is preserved verbatim in
[`milestones/v0.7.0-ROADMAP.md`](milestones/v0.7.0-ROADMAP.md).
Requirements: [`milestones/v0.7.0-REQUIREMENTS.md`](milestones/v0.7.0-REQUIREMENTS.md).
Decision record: [ADR-0010](../docs/decisions/0010-region-aware-spec-11-placement.md).

</details>

## Progress

| Phase                            | Milestone | Plans Complete | Status   | Completed  |
| -------------------------------- | --------- | -------------- | -------- | ---------- |
| 8. Plan-Review Gate              | v0.6.0    | 9/9            | Complete | 2026-07-15 |
| 9. Region-Aware §11 Placement    | v0.7.0    | 5/5            | Complete | 2026-07-16 |
| 9.1 §11 Strip Runaway (INSERTED) | v0.7.0    | 7/7            | Complete | 2026-07-15 |

## Known Follow-ups

Open debt only. Items scheduled into and closed by Phase 9.1 (V-01, V-02, V-03,
CR-01, CR-02, CR-03, the idempotent-rerun fixture, WR-02) are resolved — their
full reproduction records and closure evidence live in
[`milestones/v0.7.0-ROADMAP.md`](milestones/v0.7.0-ROADMAP.md),
`09-VERIFICATION.md`'s Gap Closure Record, and `09.1-VERIFICATION.md`.

### Carried out of v0.7.0 — not yet scheduled

- **AG-01 — region-tail strip hazard (accepted-and-disclosed, not fixed).** The
  strip eats `<!-- gitnexus:end -->` when §11 sits at a managed region's *tail*.
  Not reachable via migrations 0001/0004, which inject before the first `## ` and
  therefore land §11 at the region *head*. User ruling 2026-07-16: disclose in
  0009's Known limitations rather than fix. The durable fix — paired §11
  start/end markers, retiring the whole inference-based defect class — is
  ADR-0010's lead open follow-up.
- **Migration `0007` carries V-01's identical pre-flight defect** — a
  project-relative `skills/` path. `0008` deferred it explicitly: "different
  migration, own scope." Unscheduled.
- **`09-REVIEW.md` WR-05** — `validate-0009-anchor.sh`'s "deterministic banner"
  claim is contradicted by its own output.
- **`09-REVIEW.md` IN-01..IN-04** — `extract_step_block` prefix-matches `### Step 1`
  against `### Step 10`; CASE 1 drops a line unasserted; the ADR/migration
  numbering collision; predictable temp-file names in CWD.
- **`T-09.1-25` coverage claim** — the mitigation plan credits `0009:405`'s
  no-temp-files-left check as suite coverage, but it is a human-facing bullet, not
  an automated assertion. The underlying control (`rm -f` before every exit path)
  is real and verified in code.
- **Upstream CR-01 — filed, awaiting upstream action.**
  [claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90)
  is OPEN, scoped to CR-01 only. CR-01 is still live upstream
  (`f9354cc:0029:222-241`): entry is anchored, exit still gated behind
  `swallowed_own_h2`. Upstream's "Known limitations" lists CRLF and fenced markers
  but not the runaway — they were unaware, not accepting. V-01 was deliberately
  **not** filed: it is a codex-side porting error (upstream greps
  `.claude/skills/…`, a path its own setup skill creates — our port dropped the
  `.claude/` prefix), not upstream's defect.
  *Artifact note:* `09.1-07-SUMMARY.md` records criterion 10 as unsatisfied
  ("drafted, NOT filed") because the *executor's* filing attempt was denied over
  agent-relayed approval. The user filed it directly instead;
  `09.1-VERIFICATION.md` scored the criterion VERIFIED against the live issue.
  Verification is the later and authoritative record.

### Carried out of v0.6.0 — not yet scheduled

Tracked as Future Requirements in
[`milestones/v0.7.0-REQUIREMENTS.md`](milestones/v0.7.0-REQUIREMENTS.md) (that
milestone's archive holds the last Future Requirements list; `/gsd-new-milestone`
carries them into the next `REQUIREMENTS.md`):

- **The plan-review gate is agent-mediated, not enforced.** Per D-02 / ADR-0009
  decision 9, `AGENTS.md` ritual text instructs the verifier's invocation but
  nothing executes it, so an agent that omits the call is not blocked. The native
  `~/.codex/hooks.json` `PreToolUse` surface — pointed at this same verifier,
  which is why it already carries a `--file` argument — is deferred to its own
  phase. When it lands, criterion 1 can be restated as an unconditional block.
  Tracked as `HOOK-01`.
- **CI verifies nothing.** `.github/workflows/ci.yml` is still the Phase 0
  placeholder (`echo` + `exit 0`); its own comment promises real checks in
  "Phase 7", which never happened. `migrations/run-tests.sh` runs only locally —
  v0.6.0 and v0.7.0 were both merged on a local green, not a CI green. A real job
  needs checkout with `submodules: recursive`; the harness hard-fails without
  `vendor/agenticapps-shared`. Tracked as `CI-01`.
- **WR-03** (`--file` symlink-traversal guard is lexical-`..`-only) — accepted as
  a documented limitation, ADR-0009 decision 12, with a concrete future fix in
  that ADR's Open follow-ups. Tracked as `WR-03` in Future Requirements.
- **Upstream grandfather-conflation defect** — recorded as an open question for a
  `claude-workflow` bug report, not resolved unilaterally here.

---
*Last updated: 2026-07-16 after v0.7.0 milestone close*
