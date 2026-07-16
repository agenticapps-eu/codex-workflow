---
gsd_state_version: 1.0
milestone: v0.8.0
milestone_name: Enforcement, Not Intention
status: planning
last_updated: "2026-07-16T07:38:32.288Z"
last_activity: 2026-07-16
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
  scope_note: >
    Zeroed at v0.8.0's start — these counts are MILESTONE-scoped and the roadmap
    has not been written yet. The roadmapper repopulates them.
    Do NOT paste `gsd-sdk query progress.bar` here: it is PROJECT-scoped
    (includes the pre-GSD legacy phases 00-07) and mixing the two scopes is what
    previously produced `completed_plans: 21` against `total_plans: 12` — more
    plans complete than exist. Shipped history: v0.6.0 = Phase 8 (9 plans);
    v0.7.0 = Phase 9 (5) + Phase 9.1 (7) = 12.
    NOTE: `state.milestone-switch` has now dropped this key twice (v0.7.0 close,
    v0.8.0 start). Re-add it by hand after every switch until the SDK preserves it.
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` and `.planning/ROADMAP.md` (both updated 2026-07-16
at v0.7.0's close). Shipped milestones are archived under `.planning/milestones/`.

This repo adopted GSD's project scaffold at Phase 8; Phases 00–07 are pre-GSD
legacy recorded in `.planning/phases/<NN>/` and `CHANGELOG.md`. See ROADMAP.md
Overview.

**Core value:** The OpenAI Codex CLI host binding for the AgenticApps spec-first
workflow — a thin binding over upstream GSD and Superpowers (ADR-0007).
**Current focus:** **v0.8.0 Enforcement, Not Intention** — every gate this host
claims to bind actually fires, every migration actually runs, every assertion has
been observed failing. Takes the *entire* carried-debt set (user ruling
2026-07-16, "do them all"): `CI-01` first, then migration 0007's pre-flight
defect, `HOOK-01`, paired §11 markers, MIGR-08 execution coverage, `WR-03`, and
the `09-REVIEW.md` WR-05 + IN-01..IN-04 debt. Two prior acceptances are
deliberately reversed — WR-03 (ADR-0009 d.12) and AG-01 (ADR-0010) — and ADR-0009
d.9 is superseded. Phase numbering continues from 9.1, so v0.8.0 starts at
**Phase 10**. See PROJECT.md "Current Milestone".

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-07-16 — Milestone v0.8.0 started

## Session Continuity

Last session: 2026-07-16
Stopped at: **v0.7.0 shipped.** Milestone archived (ROADMAP collapsed,
REQUIREMENTS archived and removed, PROJECT.md evolution review done,
RETROSPECTIVE updated), merged to `main` via PR #18 as merge commit `81404e4`,
and tagged `v0.7.0` (annotated, pushed). Merged **with history**, not squashed —
matching the `cf51c73`/`b842755` precedent and keeping the RED-before-GREEN
commit ordering (`a4b137f`/`2315393`/`185abfd` → `49b2fab`) auditable from
`git log` on main.
Resume file: None

## Accumulated Context

### Decisions

Full decision log lives in `.planning/PROJECT.md` (Key Decisions) — six v0.7.0
decisions were added there at close. Per-milestone lessons are in
`.planning/RETROSPECTIVE.md`.

### Blockers/Concerns

Open debt carried past v0.7.0. Full record in ROADMAP.md "Known Follow-ups";
each is also an unchecked item in PROJECT.md's Active list.

- ⚠️ **[v0.6.0 debt] `CI-01` — CI verifies nothing.** `.github/workflows/ci.yml`
  is still the Phase 0 placeholder (`echo` + `exit 0`). Two milestones have now
  merged on a *local* green. The retrospective names this as the enabling
  condition behind v0.7.0's dominant failure mode (a suite fully green against a
  migration that never ran). Needs `submodules: recursive`.

- ⚠️ **[Phase 9.1] MIGR-08 execution coverage.** No fixture runs the Apply block
  and asserts the resulting `.codex/workflow-version.txt` content. Correct by
  inspection and reachable now that V-01 is fixed, but untested — the one residual
  of the exact class Phase 9.1 existed to close.

- ⚠️ **[Phase 9, deferred] `09-REVIEW.md` WR-05 + IN-01..IN-04** — consciously
  scoped out of 9.1, carried forward as debt. Review via `/gsd-audit-uat`.

- ⚠️ **[Phase 9, deferred] Migration `0007` carries V-01's identical pre-flight
  defect** (a project-relative `skills/` path). `0008` deferred it explicitly:
  "different migration, own scope." Unscheduled.

- ⚠️ **[Phase 9.1] AG-01 — region-*tail* strip hazard.** Accepted-and-disclosed by
  user ruling 2026-07-16, not fixed. The strip eats `<!-- gitnexus:end -->` when
  §11 sits at a managed region's tail; not reachable via 0001/0004, which land §11
  at the region head. Disclosed in 0009's Known limitations. Durable fix (paired
  §11 start/end markers, retiring the inference-based defect class) is ADR-0010's
  lead open follow-up.

- ⚠️ **[Phase 9.1] `T-09.1-25`'s mitigation plan** credits `0009:405`'s
  no-temp-files-left check as suite coverage, but it is a human-facing bullet, not
  an automated assertion. The underlying control (`rm -f` before every exit path)
  is real and verified in code.

- ⚠️ **[Upstream] CR-01 filed, awaiting upstream** —
  [claude-workflow#90](https://github.com/agenticapps-eu/claude-workflow/issues/90),
  OPEN. Still live upstream at `f9354cc:0029:222-241`. Note the artifact conflict:
  `09.1-07-SUMMARY.md` records criterion 10 as unsatisfied because the *executor's*
  filing attempt was denied (agent-relayed approval); the user filed it directly
  and `09.1-VERIFICATION.md` scored it VERIFIED against the live issue.
  Verification is authoritative.

## Notes

- Legacy `.planning/phases/<NN>/` (bare-number) layout predates ADR-0007 point 4,
  which mandates GSD-native `<NN>-<slug>/`. Phase 08 is the first GSD-native
  phase. Migrating 00–07 is deliberately out of scope.

- Phase directories for v0.7.0 were **not** archived into
  `milestones/v0.7.0-phases/` at close — they remain in `.planning/phases/` as raw
  execution history. Use `/gsd-cleanup` to archive retroactively.

- **The structural §11 invariant was widened in v0.7.0, not preserved.** Any
  terminator bounding the managed §11 section must carry the full three-way
  alternation (`## ` heading | anchored `gitnexus:start` | EOF). Narrowing it to
  `/^## /` consumes the entire GitNexus region. `12-idempotent-rerun` is the live
  guard. See PROJECT.md Constraints before touching any terminator.

## Operator Next Steps

v0.7.0 is shipped, merged (PR #18 → `81404e4`), and tagged. Remaining:

1. `/clear`, then `/gsd-new-milestone` to scope the next milestone. Top
   candidate: `CI-01` — see Blockers/Concerns.

2. Optional: `/gsd-cleanup` to archive `.planning/phases/09*` into
   `milestones/v0.7.0-phases/` (left in place at close as raw execution history).

3. Optional: cut a GitHub Release for `v0.7.0` if wanted. Note the repo has
   tagged every version but only ever published a Release for v0.1.0, so tags —
   not Releases — appear to be the convention. Not done unilaterally.
