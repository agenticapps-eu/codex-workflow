# Architecture Research — v0.8.0 Integration & Build Sequence

**Domain:** Migration-chain host binding (POSIX shell/awk embedded in markdown migrations; bash fixture harness; Codex CLI skill/hook surfaces)
**Researched:** 2026-07-16
**Confidence:** HIGH (all six questions settled against primary sources — migration documents, `run-tests.sh`, ADR-0009/ADR-0010, `09-REVIEW.md`, this repo's own `.codex/workflow-version.txt` — with one MEDIUM-confidence external fact flagged below)

This is not ecosystem/feature research. It answers: how do the seven v0.8.0 items
integrate with the existing migration chain, verifiers, and scaffolder, and in
what order should they be built. Every claim below cites the file and line it
rests on.

---

## Q1 — Migration 0007's chain-break blast radius: SEVERED, confirmed with evidence

**Verdict: the chain is severed for real existing installs upgrading from 0.4.0.**
This is not a fresh finding — it is already stated as fact, three times over, in
files this milestone's own predecessors shipped. Research's job here was to
verify the claims are true, not merely asserted, and to find the exact mechanism.

**The mechanism, precisely — and it's subtler than "0008 inherits 0007's bug":**

1. `0007`'s pre-flight greps `skills/agentic-apps-workflow/SKILL.md` (no
   `${CODEX_HOME}` prefix, not project-relative in any sense a real project
   has) — `migrations/0007-knowledge-capture.md:55-61`. No target project
   carries a local `skills/` tree; the setup skill's project-side surface is
   `AGENTS.md`, `.planning/`, `.codex/`, `docs/decisions/` only
   (`ADR-0010` Correction §3, `V-01`). This grep fails on every real install
   → `exit 3` → **0007's Step 1–4 never run, including Step 4 (`echo "0.5.0" >
   .codex/workflow-version.txt`)**. The version record stays at `0.4.0`.

2. **0008 and 0009 do NOT inherit 0007's specific bug.** Both were
   *deliberately written* to read `.codex/workflow-version.txt` instead of a
   scaffolder-relative path — `0008-plan-review-gate.md:69-79` names 0007's
   defect explicitly and says "a defect this migration does not replicate."
   `0009` does the same (`:94-98`) and cites `0008`'s precedent. So 0008/0009's
   *pre-flight mechanism* is correct.

3. **But the *value* they read was never advanced**, because 0007 never got
   past its own pre-flight. 0008's floor is `grep -qE '^0\.(5|6)\.0$'
   .codex/workflow-version.txt` (`0008:73`) — a project frozen at `0.4.0`
   fails this too, and aborts with its own `exit 3` (`0008:76`, message "need
   0.5.0"). 0009's floor (`^0\.(6|7)\.0$`) fails identically.

**So: 0008/0009 abort not because they replicate 0007's grep-path defect, but
because 0007 never delivered the version bump their (correct) floors depend
on.** The chain is severed at exactly the version-record layer PROJECT.md's
hypothesis names — confirmed, with the added precision that the break
propagates through *correct* code in 0008/0009, not copied bugs.

**Nothing else advances `.codex/workflow-version.txt` out of band.**
`update-codex-agenticapps-workflow/SKILL.md` Stage D step 9 ("On migration
completion: update `.codex/workflow-version.txt`") is prose *describing* the
same action each migration's own `### Step N: Record the new project version`
block performs (confirmed present in 0000, 0001, 0004, 0006, 0007, 0008,
0009) — it is not a second, independent writer. The `--from VERSION` flag
overrides only the *skill's* pending-migration selection; it does not patch
what a migration's own `## Pre-flight` block re-reads directly from disk. No
escape hatch exists short of a new migration.

**Self-application does not reproduce the bug — and that is itself evidence,
not a contradiction.** This repo's own `.codex/workflow-version.txt` reads
`0.7.0` (verified: `cat .codex/workflow-version.txt`). This repo *is* the
scaffolder — it genuinely has a `skills/agentic-apps-workflow/SKILL.md` at
its own repo root, so 0007's grep target exists here and its pre-flight
passes on self-application. The chain break is invisible to dogfooding by
construction; it is a defect that manifests only on the shape 0008/0009's own
fixtures deliberately construct ("no-scaffolder-tree fixture") and that
0009's V-01 regression already proved this project's suite can stay green
around ("314 PASS / 0 FAIL... fully consistent with a migration that never
ran," ADR-0010 Correction §3). **The new fix migration's fixtures must use
that same no-local-`skills/`-tree shape, never this repo's own tree, or the
suite will again manufacture false confidence.**

**Sizing the fix: large for 0007's own payload, NOT large across 0008/0009.**
Because 0007 never wrote *anything* (pre-flight aborts before Step 1), the fix
must re-deliver 0007's full payload — the `knowledge_capture` config-block
seed (Step 1), the AGENTS.md ritual-tail section insert (Step 2), and the
version record (Step 4) — using a corrected pre-flight. It must also **drop**
Step 3 (bumping `skills/agentic-apps-workflow/SKILL.md`'s own `version:`
field), which is the MIGR-09 violation PROJECT.md flags: a migration must
record the *target project's* version (MIGR-08) and never touch the
*scaffolder's own* files (MIGR-09) — the same conflation that produced V-01,
now caught before it ships a second time. **0008 and 0009 need no payload
redelivery of their own** — once the version record correctly reads `0.5.0`,
their own (already-correct) pre-flights and Steps apply normally through the
standard `$update-codex-agenticapps-workflow` flow.

**A real, previously unexamined operational gap this creates:** once the fix
migration exists, it and 0007 both satisfy `from_version <= 0.4.0 <
to_version` for a stuck project — **both are "pending" simultaneously**, and
the update skill selects by ascending `id`, so 0007 (lower id) is attempted
first and aborts every time. `migrations/README.md`'s atomicity contract
("if step N fails halfway... retry / skip-with-warning / rollback") is
written for **step**-level failure; whether a **migration-level pre-flight**
abort is even subject to that same three-way prompt, or instead hard-stops
the whole update invocation, is not stated anywhere in
`update-codex-agenticapps-workflow/SKILL.md` or `migrations/README.md`. This
is a real integration gap the fix migration's own plan must close — most
likely by amending `update-codex-agenticapps-workflow/SKILL.md`'s Stage D
description (that file is a **skill**, not a migration, so it is not bound by
migration immutability) to state explicitly: a migration whose own
pre-flight aborts is treated as blocked and the operator is pointed at the
migration that supersedes it. Flag this for the roadmap as a required task
inside the 0007-fix phase, not an afterthought.

---

## Q2 — New migrations, numbered what, versus edit/CI/fixture

**IN-03 constraint, applied:** ADR numbers (`docs/decisions/000N-*.md`) and
migration numbers (`migrations/000N-*.md`) are **independent series that
happen to share a numbering scheme** — `09-REVIEW.md:418-427` names this
exactly ("ADR-0010 documents migration 0009... the two series are numbered
independently and are now off by one at adjacent numbers"), with the
prescribed fix being **documentation, not renumbering**: an explicit line in
`docs/decisions/README.md` stating the two series are independent. New
migration numbers (`0010`, `0011`, …) **will** collide numerically with
existing/future ADR numbers (ADR-0010 already exists) — that is expected and
tolerated per IN-03's own resolution, not a defect to design around. The
`docs/decisions/README.md` note is itself one of this milestone's cheap,
correct deliverables (fixture-only/doc-only, consumes no migration ID).

**Per-item mapping:**

| Item | Kind | New migration? | Rationale |
|---|---|---|---|
| **0007 chain-break** | New forward migration | **Yes — `0010`** (`from_version: 0.4.0`, `to_version: 0.5.0`, same transition 0007 claimed) | Must slot at the exact version step 0007 occupies — a stuck project's floor is `0.4.0`, so the fix cannot target any later version (unlike 0009's "heal later" strategy, which works only because 0001/0004 *did* write content, just to the wrong place; 0007 wrote nothing). Re-delivers Steps 1/2/4 of 0007's payload; drops Step 3 (MIGR-09 violation). |
| **CI-01** | CI file edit | No | `.github/workflows/ci.yml` is one file; no project-side `applies_to` surface, so it is never a migration by the format's own contract (`migrations/README.md`'s frontmatter requires `applies_to` as project-side paths). |
| **HOOK-01** | New forward migration (global-file write, following an existing precedent) | **Yes — next available ID after the fixes above** (see build order) | Writing `~/.codex/hooks.json` + flipping the `[features]` flag in `~/.codex/config.toml` is a **global** (not per-project) write. Precedent already exists: `0000-baseline.md` Step 6 appends to the global `${CODEX_HOME}/AGENTS.md`, gated by `optional_for: option-a` with a `detect` shell test — the exact shape a new migration should copy. `0000` is immutable, so this cannot be added there; it needs its own migration so **both fresh and existing installs get it through the same file** (`migrations/README.md`: "no parallel setup-writes-one-shape / update-writes-different-shape path"). The wrapper script the hook actually invokes (self-scoping guard — see Q4) is scaffolder-side content (`skills/agentic-apps-workflow/scripts/`), shipped via `install.sh`, not migration-authored. |
| **Paired §11 markers (AG-01)** | New forward migration | **Yes** | Structurally identical to 0009: re-vendors the block via the *existing* strip (locating current extent via the terminator alternation — unchanged, immutable, still required as the detection path for un-migrated installs) and re-emits it with a new closing marker. ADR-0010's own Open follow-ups names this as "the recommended successor to 0009's guard-stacking... the migration already re-vendors the block, so it can emit the closing marker during the re-vendor it performs anyway." |
| **MIGR-08 execution coverage** | Fixture-only | No | PROJECT.md is explicit: "a fixture that runs the Apply block and asserts the written `.codex/workflow-version.txt`." Adds a `run-tests.sh` assertion; no migration document changes (0008 stays immutable, `run-tests.sh` is not). |
| **WR-03 (symlink guard)** | Skill/script edit + ADR amendment | No | `check-plan-review.sh` is a global scaffolder artifact (`$CODEX_HOME/skills/agentic-apps-workflow/scripts/`), referenced by path from every project, never copied per-project by a migration. Fixing its `--file` traversal guard is a script edit + fixture update + an ADR-0009 "Correction" section (d.12 reversal), following the exact in-place-amendment convention ADR-0010 already established in Phase 9.1. No project-side state changes, so no migration. |
| **09-REVIEW.md WR-05, IN-01, IN-02, IN-04** | Fixture/harness edits | No | All four are `run-tests.sh` / `validate-0009-anchor.sh` internals (banner determinism, `extract_step_block` prefix-matching, an unasserted line-drop, predictable temp names) — harness quality, zero project-side `applies_to` surface. |
| **09-REVIEW.md IN-03** | Doc-only | No | One line in `docs/decisions/README.md`. |

**Net new migration count: 3** (`0007`-fix, HOOK-01, paired-markers), consuming
IDs `0010`, `0011`, `0012` in that relative order (exact final numbers depend
on what lands first in the build sequence below — do not hardcode `0011`/`0012`
into a phase plan before `0010` actually merges, since `ls
migrations/[0-9]*.md | tail -1` is how the next ID is chosen, per
`migrations/README.md`'s own "Adding a new migration" step 1).

---

## Q3 — Paired §11 markers vs the widened three-way terminator invariant

**The terminator alternation is not retired by paired markers — it is
downgraded from "the only extent mechanism" to "the legacy-detection
fallback."** Two coexisting mechanisms, cleanly partitioned by version:

- **Un-migrated installs** (single opening `<!-- spec-source:
  agenticapps-workflow-core@0.4.0 §11 -->` provenance line, no closing
  marker) still rely on 0009's *unmodified, immutable* strip logic to locate
  the block's extent: swallow the block's own `## ` heading, then scan to the
  first line matching `(/^## / || /^<!-- gitnexus:start -->$/)`, or EOF
  (`0009:302-...`, the widened invariant PROJECT.md's Constraints section
  states verbatim). This code does not change. `12-idempotent-rerun`
  (`ADR-0010` Open follow-ups: "`11-idempotent-rerun` fixture... re-apply
  Step 1 to an already-healed region-led file and assert the region survives
  paired" — landed under this name per PROJECT.md's milestone context) tests
  exactly this un-migrated path's idempotency and **must stay green**,
  because every project that has not yet run the paired-marker migration
  still needs it.
- **Newly migrated installs** get an explicit closing marker emitted at
  re-vendor time (mirroring GitNexus's own `<!-- gitnexus:start
  -->`/`<!-- gitnexus:end -->` pairing, the design paired markers are
  explicitly modeled on). Once paired, extent is data, not inference: "delete
  between markers" replaces "scan to the next `## `/region/EOF." A future
  strip against an *already-paired* block should prefer the closing-marker
  boundary over the terminator alternation — the closing marker is strictly
  more precise and cannot be fooled by the exact hazards 0009 fought
  (drifted heading, region-tail placement).

**What heals existing single-anchor installs:** the same re-vendor mechanism
0009 already uses — strip via the (unchanged) terminator alternation,
re-insert via the (unchanged) anchor rule, but the re-insert step now also
writes the closing marker. This is additive to 0009's own code path, not a
rewrite of it: 0009 stays immutable: the new migration's Apply step
**invokes the same strip/insert shape as its own fresh code**, not a copy
of 0009's document (0007's transcription mistake — a second source of truth
that drifts — is the precedent this must avoid; extract logic the way
`run-tests.sh`'s `extract_step_block` extracts 0001's Apply block from the
document itself, or vendor the awk from the mirror-adjacent template, not
duplicate it inline a third time).

**The idempotency check for the new migration is the closing marker's
presence**, not the opening one: `grep -qE
'<!-- spec-source-end: agenticapps-workflow-core@[^[:space:]]+ §11
-->'` (or equivalent) — present → already paired, skip; absent → heal (which
may be a no-op strip+reinsert on an already-correctly-placed block, exactly
as 0009's own State-A "zero churn" case works today).

**Consequence for the invariant text in PROJECT.md's Constraints:** once
paired markers ship, a *third* sentence needs adding alongside the existing
widened-invariant paragraph — something like "a paired-marker block's extent
is delimited by its own closing marker; the three-way terminator alternation
remains the extent mechanism for any block not yet carrying one." This is a
documentation update the paired-markers migration's own plan should carry
(mirroring how 0009's plan updated the Constraints section in place), not a
silent drift.

---

## Q4 — HOOK-01 integration

**Where the native hook config lives:** `~/.codex/hooks.json`
(`${CODEX_HOME}/hooks.json`), gated by a feature flag in
`~/.codex/config.toml`. This repo's own docs (`docs/briefs/plan-review-gate.md:42-44`,
`ADR-0009:26-28`, `08-CONTEXT.md:35`) already record, from earlier empirical
investigation, that Codex CLI 0.144.4 ships `PreToolUse`/`PostToolUse`/
`SessionStart` events, a `[features] hooks = true` flag, a sha256 trust
ledger, and a `--dangerously-bypass-hook-trust` escape hatch — **global, not
per-project**, which is exactly why ADR-0009 deferred it rather than adopting
it directly for the plan-review gate.

**MEDIUM confidence, flagged for empirical re-verification before this phase
ships (per this repo's own established practice — ADR-0001's A2 "verified
empirically on codex-cli 0.144.4" precedent):** external documentation
found via WebSearch describes the enabling flag as `[features] codex_hooks =
true` and cites first shipping in v0.114, which does not exactly match this
repo's own already-recorded `[features] hooks = true`. This is a small but
load-bearing discrepancy — flip the wrong flag name and the hook silently
never fires, the exact "guard not shipped until observed failing" failure
mode this milestone exists to close. **Do not trust either source blind; the
phase that implements HOOK-01 must re-verify the current flag name and
`hooks.json` schema against the installed Codex CLI version directly** (e.g.
`codex --version`, then check `config-reference`/`hooks` docs for that exact
version) before wiring it, exactly as ADR-0001 did for the AGENTS.md load
path.

**How it invokes `check-plan-review.sh` with `--file`:** a `PreToolUse` entry
with a `matcher` (likely `Bash` or the apply-patch/file-edit surface) whose
`hooks[].command` points at a **wrapper script**, not `check-plan-review.sh`
directly — because the hook is global and must self-scope (fire only inside
codex-workflow-managed projects), while `check-plan-review.sh` itself has no
such guard today (it assumes it is being invoked from within a managed
project's CWD via ritual text). The wrapper's job: test for the managed-project
marker (`.codex/workflow-version.txt` or `.planning/config.codex.json`
presence) in the hook's working directory; if absent, exit 0 immediately
(not-our-repo, allow); if present, exec
`${CODEX_HOME}/skills/agentic-apps-workflow/scripts/check-plan-review.sh
--file <path-from-hook-payload>` and translate its exit code into the
hook's expected `hookSpecificOutput.permissionDecision` shape (`deny` on
`exit 2`, `allow` otherwise). `check-plan-review.sh` already carries `--file`
for exactly this purpose (`ADR-0009` decision 9, `check-plan-review.sh:16`)
— the verifier itself needs **no changes**, only a caller.

**How the scaffolder/migration installs it:** two coordinated writes, both
global (`${CODEX_HOME}`, never per-project), both following the
`0000-baseline.md` Step 6 precedent (`optional_for`-gated, idempotent,
`detect`-shell-tested):
1. `install.sh` ships the new self-scoping wrapper script alongside
   `check-plan-review.sh` (scaffolder-authored content, versioned with the
   scaffolder, not migration payload).
2. A new migration (per Q2) merges a `PreToolUse` entry into
   `${CODEX_HOME}/hooks.json` (creating the file if absent, preserving any
   existing entries a user or another tool installed — the same
   merge-don't-clobber discipline 0007's `knowledge_capture` seed already
   demonstrates for JSON) and sets the enabling feature flag in
   `~/.codex/config.toml`. Idempotency check: does `hooks.json` already carry
   an entry pointing at this wrapper's path.

**What gets superseded vs kept in ADR-0009:** decision 9's *architecture*
(hybrid: declarative binding stays the source of truth in
`config.codex.json`, `check-plan-review.sh` supplies the programmatic check)
is **kept** — HOOK-01 does not replace the verifier, it changes who calls it
unconditionally. What is **superseded**: the "agent-mediated... an agent that
never invokes the verifier is not blocked by it" qualifier (`ADR-0009:276-301`)
— once native `PreToolUse` invokes the wrapper on every matching tool call,
invocation is no longer conditional on the agent choosing to run the ritual
text. ROADMAP.md's criterion 1, reworded to an agent-mediated qualifier
during Phase 8 (per `v0.6.0-ROADMAP.md`'s deviation notice), is exactly what
HOOK-01 is documented everywhere as entitled to restate as an unconditional
block once it lands. Record this as a new **Correction** section appended to
ADR-0009 in place (the Phase-9.1-on-ADR-0010 convention), not a new ADR
number, per PROJECT.md's "amended, not superseded" instruction.

---

## Q5 — CI-01 integration

**One file:** `.github/workflows/ci.yml`, currently the Phase-0 placeholder —
a single `phase-0` job that echoes a promise ("real checks land in Phase 7")
and exits 0 unconditionally (verified: `cat .github/workflows/ci.yml`).

**What jobs:** minimally one job is sufficient and correct. `migrations/run-tests.sh`,
run with no filter argument, already executes **every** test function
including the drift check — confirmed by reading the dispatcher
(`run-tests.sh:4640-4691`): `test_migration_0000` through `_0009`, the three
`check-plan-review` fixture sets, `test_drift`, and `test_repo_layout` all
run unconditionally when `$FILTER` is empty, and the script's own exit code
is `1` if `$FAIL > 0`, else `0` (`run-tests.sh:4703-4712`). PROJECT.md's "plus
the drift check" phrasing is not asking for a *second* job — `test_drift` is
already one of the 369 assertions the single invocation produces. A second
job is defensible only for **failure isolation in the CI UI** (a red "drift"
job is a faster diagnostic than scrolling a 369-assertion log), which is a
reasonable enhancement but not required by the milestone's own success
condition ("a workflow running `migrations/run-tests.sh`... plus the drift
check").

**Recommended shape:**
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - run: bash migrations/run-tests.sh
```
A second `drift`-only job (`bash migrations/run-tests.sh drift`, using the
existing `$FILTER` argument the script already supports — `run-tests.sh:46-52`)
can run in parallel for UI clarity; it is not load-bearing since `test` already
covers it.

**Where the drift check lives today:** entirely inside `migrations/run-tests.sh`
(`test_drift`, `:3217`), which delegates its **mechanism** to
`vendor/agenticapps-shared/migrations/lib/drift-test.sh`'s `run_drift_test`
and keeps its **policy** ("version coupling is a hard fail") local
(`run-tests.sh:30-33`). No separate script or workflow file is needed for
CI-01 to cover it — the drift check is already reachable through the one
entry point CI-01 wires up.

**Interaction with the submodule:** `run-tests.sh` hard-fails at startup
(`exit 1`, before any test runs) if
`vendor/agenticapps-shared/migrations/lib/helpers.sh` is missing
(`run-tests.sh:34-39`), which is exactly the failure mode a non-recursive
checkout produces. `submodules: recursive` on `actions/checkout@v4` is not
optional — its absence is precisely the class of defect this milestone exists
to close (a guard that looks green locally because the developer's clone
already has the submodule initialized, but was never proven to fail in an
environment where it might not be). This is also the *evidence* for why
CI-01 must land first: every other item in this milestone is verified today
only by a local run of `run-tests.sh` inside a workspace that already has the
submodule — CI-01 is what makes "the suite is green" mean something to a
reviewer who did not run it themselves.

---

## Q6 — Build order

**Dependency graph, stated as constraints (not preferences):**

- CI-01 depends on nothing in this milestone. It validates every other
  item, so nothing after it can be trusted as "shipped" without it — this is
  PROJECT.md's own stated ordering rule, not a research recommendation.
- The 0007-fix migration depends on nothing else in this milestone
  functionally, but its *fixtures* must be authored using the no-local-`skills/`-tree
  shape (Q1) — a testing-discipline dependency, not a code dependency.
- MIGR-08 execution-coverage (fixture-only) has no code dependency on
  anything else; it can run any time after CI-01 exists to prove it.
- WR-03 (symlink guard) and the `09-REVIEW.md` cleanups (WR-05, IN-01,
  IN-02, IN-04, IN-03) are mutually independent script/fixture/doc edits with
  no shared file surface — safe to parallelize with each other and with the
  0007-fix migration.
- HOOK-01 depends on the wrapper script's self-scoping design being decided
  (Q4) but not on any other v0.8.0 item's code. It should NOT be built before
  its Codex-CLI-version facts (flag name, `hooks.json` schema) are
  empirically re-verified (Q4's flagged MEDIUM-confidence gap) — that
  verification is a prerequisite task inside its own phase, not a separate
  phase.
- Paired §11 markers depends on nothing else in this milestone, but is the
  most structurally novel item (new marker convention, new idempotency
  shape) and benefits from CI-01 already existing to catch any interaction
  with `12-idempotent-rerun` on a clean, submodule-complete run rather than a
  possibly-stale local one.
- The update-skill pre-flight-abort-handling gap surfaced in Q1 (whether a
  migration-level pre-flight failure is subject to the atomicity contract's
  retry/skip/rollback prompt) is a **prerequisite sub-task of the 0007-fix
  migration's own phase**, not a separate item — it only matters once 0007
  and its fix coexist as simultaneously-pending migrations, which is exactly
  what that phase creates.

**Proposed sequence** (phase numbers illustrative — actual numbers continue
from 9.1 → 10 per PROJECT.md's stated milestone constraint):

```
Phase 10 (serial, first, blocking):
  CI-01 — .github/workflows/ci.yml real workflow, submodules: recursive.
  Nothing else in this milestone merges as "verified" until this exists,
  per PROJECT.md's own stated ordering.

Phase 11 (parallelizable — 3 independent tracks, all depend only on
Phase 10 existing so their own PRs run on real CI):
  Track A: Migration 0010 — heal the 0007 chain break.
    - Redeliver 0007 Steps 1/2/4 with a corrected pre-flight
      (.codex/workflow-version.txt, not skills/agentic-apps-workflow/SKILL.md)
    - Drop the MIGR-09 scaffolder-version-bump step
    - Fixtures use the no-local-skills/-tree shape (Q1)
    - Amend update-codex-agenticapps-workflow/SKILL.md Stage D to state how
      a migration-level pre-flight abort (0007, permanently) is handled when
      a later pending migration (0010) covers the same transition
    - MIGR-08 execution-coverage fixture (small, same testing surface, ships
      alongside for convenience — no code dependency either way)
  Track B: WR-03 (symlink-resolution guard) + 09-REVIEW.md cleanups
    (WR-05, IN-01, IN-02, IN-04, IN-03) — script/fixture/doc edits only,
    ADR-0009 Correction section for the d.12 reversal.
  Track C: HOOK-01 — empirically re-verify the Codex CLI hook flag/schema
    first (Q4), then: self-scoping wrapper script, hooks.json merge +
    config.toml flag (new migration, next ID after Track A lands),
    ADR-0009 Correction section for the d.9 supersession.

Phase 12 (serial after Phase 11, or parallel with Track C if capacity
allows — no hard code dependency on A/B, but sequenced last because it is
the most structurally novel change and benefits from a CI-verified baseline):
  Paired §11 markers (AG-01) — new migration, closing-marker convention,
  ADR-0010 Correction section for the open follow-up closure. Must not
  regress 12-idempotent-rerun (unmigrated-install path stays on the
  terminator alternation, unchanged).
```

**Why this order and not CI-01-last-among-equals:** PROJECT.md states it
directly — CI-01 is "the prerequisite for trusting every other fix in this
milestone," and the retrospective it cites names local-green merging as
v0.7.0's dominant failure mode. Everything after Phase 10 is safe to
parallelize because none of Tracks A/B/C share a file surface: Track A
touches `migrations/0010-*.md` (new) + `run-tests.sh` fixtures +
`update-codex-agenticapps-workflow/SKILL.md`; Track B touches
`check-plan-review.sh` + its fixtures + `docs/decisions/0009-*.md` +
`docs/decisions/README.md` + `run-tests.sh`/`validate-0009-anchor.sh`; Track
C touches a new wrapper script + `install.sh` + a new migration +
`docs/decisions/0009-*.md` (a different section of the same file as Track
B's amendment — sequence B before C or resolve as two small PRs against the
same file, not a hard blocker). Paired markers is sequenced last not because
anything depends on it, but because it is the one item whose fixture
interaction with `12-idempotent-rerun` most benefits from running against a
CI-verified tree rather than a possibly-stale local submodule state — the
same class of risk CI-01 exists to close.

---

## Anti-Patterns to avoid (specific to this migration-chain domain)

### Anti-Pattern: transcribing a migration's shell into the test harness

**What people do:** copy a migration's awk/shell logic into `run-tests.sh` as
a second, hand-maintained "equivalent" for testing convenience.
**Why it's wrong:** this is exactly TEST-01/TEST-04's closed defect class —
a second source of truth drifts silently from the document it claims to
test. `run-tests.sh:119`'s old inlined copy of 0001's injection awk was
retired for this reason; `0008`'s Step-3 insert-awk copy (~`:985`) is a known,
deferred instance of the same class (D-37).
**Do this instead:** extract the real Apply/Idempotency-check block from the
migration document itself using `extract_step_block`/`extract_preflight_block`
(`run-tests.sh:100-133`), exactly as `test_migration_0001` and `test_migration_0009`
already do.

### Anti-Pattern: assuming a migration's own repo is a valid test fixture

**What people do:** test a migration's pre-flight or Apply behavior against
this repo's own working tree, on the theory that "if it works here it works."
**Why it's wrong:** this repo has a local `skills/` tree because it *is* the
scaffolder — a shape no consumer project has. It is precisely how V-01
shipped invisibly and how 0007's chain-break has stayed latent through every
prior review. A suite that stays green while a migration never runs is
"fully consistent with," not evidence against, the defect (ADR-0010,
Correction §3).
**Do this instead:** synthetic fixtures shaped like a real target project
(`0008`'s "no-scaffolder-tree fixture" is the reference shape) — no local
`skills/` directory, only `AGENTS.md`, `.planning/`, `.codex/`.

### Anti-Pattern: narrowing the §11 terminator alternation "to simplify"

**What people do:** notice the three-way alternation (`## ` heading |
anchored `gitnexus:start` | EOF) looks over-general for a specific case and
narrow it back to `/^## /` only.
**Why it's wrong:** this is the exact false-invariant mistake ADR-0010
records as "the single most important item in this ADR" — a narrowed
terminator runs straight past an anchored region marker on an already-healed
file and consumes the entire GitNexus region. `12-idempotent-rerun` exists
specifically to fail the suite when this happens; do not treat a passing
suite without that fixture as proof the narrowing is safe.
**Do this instead:** if a terminator needs to change, change the anchor rule
and the terminator rule together — they are "one decision, not two"
(ADR-0010 decision 2) — and confirm `12-idempotent-rerun` (or whatever
paired-marker successor tests the same hazard) still passes.

---

## Confidence summary

| Question | Confidence | Basis |
|---|---|---|
| Q1 (chain-break blast radius) | HIGH | Direct reads of 0007/0008/0009 pre-flight blocks, `update-codex-agenticapps-workflow/SKILL.md`, this repo's own `.codex/workflow-version.txt`, and ADR-0010's Correction §3 (V-01) — all primary sources, mutually consistent |
| Q2 (migration numbering vs edit/CI/fixture) | HIGH | `migrations/README.md`'s format contract (`applies_to` requirement), `09-REVIEW.md` IN-03, direct inspection of each item's actual file surface |
| Q3 (paired markers vs terminator invariant) | HIGH for the mechanism (design already specified in ADR-0010's Open follow-ups), MEDIUM for exact marker syntax (not yet chosen — `<!-- spec-source-end: ... -->` is this research's proposal, not a shipped fact) |
| Q4 (HOOK-01 integration) | HIGH for architecture (hybrid kept, wrapper needed, global scope), **MEDIUM for the exact Codex CLI flag name/schema** — flagged explicitly for empirical re-verification before implementation, per this repo's own ADR-0001 precedent |
| Q5 (CI-01 integration) | HIGH | Direct read of `ci.yml`, `run-tests.sh`'s dispatcher and exit-code logic, `.gitmodules` |
| Q6 (build order) | HIGH | Derived directly from Q1–Q5's evidence plus PROJECT.md's own stated CI-01-first constraint; no external speculation |

## Sources

- `.planning/PROJECT.md` (Current Milestone, Constraints, Context)
- `migrations/0007-knowledge-capture.md`, `migrations/0008-plan-review-gate.md`,
  `migrations/0009-spec-11-region-aware-placement.md` (frontmatter, pre-flight
  blocks, version-record steps)
- `migrations/0000-baseline.md`, `0001-inject-spec-11-coding-discipline.md`,
  `0004-revendor-spec-11.md`, `0006-commit-planning-phases.md` (version-record
  precedent chain 0.1.0 → 0.4.0)
- `migrations/README.md` (chain contract, idempotency/atomicity contracts,
  "no parallel setup/update shape" rule)
- `migrations/run-tests.sh` (dispatcher `:4640-4712`, `test_drift` `:3217`,
  extraction helpers `:100-174`, submodule hard-fail `:34-39`)
- `skills/update-codex-agenticapps-workflow/SKILL.md` (Stage A–E, the
  version-bump description, `--from`/`--migration` flags)
- `docs/decisions/0009-plan-review-gate.md` (ADR-0009, decisions 1, 9, 12;
  Open follow-ups)
- `docs/decisions/0010-region-aware-spec-11-placement.md` (ADR-0010,
  Correction §§1-5, decisions 1-6, Open follow-ups — paired markers,
  CI-01, multi-hop chain-selection defect)
- `docs/decisions/README.md` (ADR index, independent-numbering context)
- `.planning/phases/09-region-aware-11-placement/09-REVIEW.md` (WR-05, IN-01–IN-04)
- `.github/workflows/ci.yml`, `.gitmodules` (current CI placeholder, submodule config)
- `docs/briefs/plan-review-gate.md` (Codex CLI 0.144.4 hook-surface findings, `hooks.json` sketch)
- `CHANGELOG.md` (Unreleased backlog entries for HOOK-01 and CI-01, corroborating both were already known/scoped)
- This repo's own `.codex/workflow-version.txt` (`0.7.0`) and
  `skills/agentic-apps-workflow/SKILL.md` (`version: 0.7.0`) — direct
  verification that self-application does not reproduce the 0007 defect
- WebSearch: Codex CLI hooks documentation (`developers.openai.com/codex/hooks`,
  `developers.openai.com/codex/config-reference`) — MEDIUM confidence only,
  flagged for empirical re-verification (see Q4)

---
*Architecture research for: codex-workflow v0.8.0 "Enforcement, Not Intention"*
*Researched: 2026-07-16*
