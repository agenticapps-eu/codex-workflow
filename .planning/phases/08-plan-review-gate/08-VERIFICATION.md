---
phase: 08-plan-review-gate
verified: 2026-07-15T08:59:53Z
status: gaps_found
score: 7/8 must-haves verified (7 ROADMAP success criteria + 1 derived "strictness-contract integrity" truth; the derived truth failed)
overrides_applied: 0
gaps:
  - truth: "The verifier's REVIEWS.md strictness check cannot be silently bypassed — no malformed-but-well-intentioned artifact and no vendor-identity spoofing can satisfy the '>=2 independent reviewers' floor the phase exists to enforce (derived from ROADMAP criterion 4 + ADR-0009 decisions 1/4/9's 'programmatic, deterministic enforcement' claim)"
    status: failed
    reason: >
      Independently reproduced two real fail-opens in
      skills/agentic-apps-workflow/scripts/check-plan-review.sh's REVIEWS.md
      evidence check, both outside the golden path the shipped test suite
      exercises, neither fixed nor formally accepted as a documented
      limitation anywhere in ADR-0009, the SUMMARYs, or ROADMAP.md.
      (1) CR-01 (already found by 08-REVIEW.md, re-verified here by direct
      execution, not merely re-read): the opening-frontmatter detection at
      check-plan-review.sh:539 is a byte-exact `[ "$first_line" = "---" ]`
      comparison. A REVIEWS.md with a trailing space or CRLF line ending on
      its very first line is silently treated as "no frontmatter" and
      collapses to the spoofable D-13 >=5-line fallback, which has no
      reviewer-count check at all. Reproduced live:
      `printf -- '--- \nphase: 9\nreviewers: [solo]\nplans_reviewed: []\n---\nbody\n' > 09-REVIEWS.md; bash check-plan-review.sh` -> exit 0
      with exactly one reviewer ("solo"). (2) WR-01, independently
      re-verified here (08-REVIEW.md marked it code-inspection-executed but
      this run repeats it standalone): the strict frontmatter path counts
      only distinct normalized strings in `reviewers:`, never checking
      vendor identity or excluding `codex` — the exact self-review D-15
      names as forbidden. Reproduced live with
      `reviewers: [codex, codex-self]` under well-formed frontmatter (no
      CRLF/whitespace trick needed) -> exit 0. Both defects mean the
      "verifier independently enforces the minimum" claim asserted by the
      phase's own test-suite output and by ADR-0009 decision 9's "the
      verdict is a deterministic exit code computed from repo state, not
      the agent's own judgment" is true only on the golden path, not in
      general.
    artifacts:
      - path: "skills/agentic-apps-workflow/scripts/check-plan-review.sh"
        issue: "Line 539 byte-exact '---' match (CR-01) and lines 550-561 distinct-string-only reviewer count with no vendor allowlist / no codex exclusion (WR-01) both let a file with effectively one real reviewer pass exit 0"
    missing:
      - "Normalize the opening-delimiter comparison (strip \\r and trailing whitespace before the '---' equality test), mirrored on the closing-delimiter awk search, per 08-REVIEW.md CR-01's suggested fix"
      - "Add a CRLF fixture and a trailing-space fixture to test_check_plan_review_enforcement so this class of regression is caught (08-REVIEW.md confirms none exists today)"
      - "Either validate reviewers: entries against the known vendor set and reject 'codex'/unrecognized names (WR-01 fix a), or explicitly record in ADR-0009 that arbitrary reviewer strings are accepted by design, the way decision 11 already does for the >=5-line fallback (WR-01 fix b)"
      - "Alternatively: an explicit ADR-0009 addendum accepting CR-01 and WR-01 as known, documented limitations (mirroring decision 11's treatment of the >=5-line fallback) if a code fix is deliberately deferred"
---

# Phase 8: Plan-Review Gate — Verification Report

**Phase Goal:** Bind the core spec §02 `plan-review` pre-execution gate on Codex — a declarative binding in `.planning/config.codex.json` plus a programmatic verifier implementing the spec's resolution order and grandfather rule — closing the follow-up the spec names at `spec/02:105-109`.

**Verified:** 2026-07-15T08:59:53Z
**Status:** gaps_found
**Re-verification:** No — initial verification

**Scope note on criterion 1:** Per the deviation notice recorded in ROADMAP.md on 2026-07-14 (before execution) and ADR-0009 decision 9, criterion 1 is verified here in its **relaxed, agent-mediated** form only: "the verifier returns exit 2 and the ritual instructs a hard stop *once the verifier runs*." This report does not claim, and the codebase does not deliver, an unconditional block — an agent that never invokes the verifier is not stopped by it. That is by design, not a gap.

**Bootstrap paradox:** Per ADR-0009 decision 8 and this task's explicit instruction, phase 08's own grandfathered pass (its plans each carry a `*-SUMMARY.md`, so the gate would exit 0 against phase 08 itself from wave 1 onward) is **not** treated as evidence the gate works, and its absence from a live dogfood run is **not** reported as a gap here. Real coverage is `migrations/run-tests.sh`'s synthetic fixtures plus my own scratch-fixture reproductions below.

## Goal Achievement

### ROADMAP Success Criteria (verbatim from ROADMAP.md, criterion 1 in its relaxed form)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | A phase with plans and no reviews is blocked before its first code-touching edit, via an agent-mediated programmatic check: verifier exits 2, ritual instructs a hard stop once it runs | ✓ VERIFIED | Direct execution against a scratch fixture (`.planning/phases/09-test-phase/09-01-PLAN.md`, no REVIEWS.md): `bash check-plan-review.sh` → exit 2 with block message naming the phase, the missing artifact, the remedy skill, and both escape hatches. `AGENTS.md` §"Pre-execution Gate — Plan Review" ritual text (lines 111-139) instructs "Exit 0 → proceed. Exit 2 → HARD STOP." Confirmed relaxed (not unconditional) framing matches the ROADMAP deviation notice — no claim of an execution-blocking hook surface exists in the codebase (`~/.codex/hooks.json` is not touched by this phase, confirmed by `git log`/file search). |
| 2 | A phase that already shipped (`*-SUMMARY.md` present) is allowed — never retroactively blocked | ✓ VERIFIED | Direct execution: added `09-01-SUMMARY.md` to the same fixture phase (which still had plans, no REVIEWS.md) → `bash check-plan-review.sh` exits 0. Source: `check-plan-review.sh:388-393`. |
| 3 | A legacy bare-number phase is allowed | ✓ VERIFIED | Direct execution: created `.planning/phases/10/PLAN.md` (bare-number layout, no dated `*-PLAN.md`), pointed `.planning/current-phase` at it → exit 0. Source: `check-plan-review.sh:375-380` (D-08/D-09 explicit legacy check, confirmed not merely an emergent glob property — the bare `PLAN.md` cannot match the `*-PLAN.md` glob used at step 3 of the resolver, so the explicit check is load-bearing). |
| 4 | `codex-plan-review` produces `<NN>-REVIEWS.md` carrying at least 2 independent external reviewers, and refuses rather than emitting a one-reviewer file | ⚠️ GAP (see derived truth below) | Literal producer-skill contract VERIFIED: `skills/codex-plan-review/SKILL.md` step 5 documents refusal below the 2-reviewer minimum and explicitly forbids writing a one-reviewer file; `migrations/run-tests.sh`'s `test_check_plan_review_contract` proves the skeleton (2+ reviewers, D-12 schema) round-trips through the real verifier at exit 0, and proves a reduced-to-one-reviewer variant of the same skeleton exits 2, and proves "producer refused (no REVIEWS.md written) -> exit 2." All three re-confirmed passing in a live `bash migrations/run-tests.sh` run. **However**, the verifier side of this same contract — "the gate refuses a one-reviewer file" as a general property, not just on the golden-path artifact shape — is demonstrably not robust; see the derived truth below (CR-01, WR-01), which is the reason this row is GAP rather than a clean VERIFIED. |
| 5 | Both escape hatches (`GSD_SKIP_REVIEWS=1`, `multi-ai-review-skipped`) allow the edit | ✓ VERIFIED | Direct execution against the blocking fixture from criterion 1: `GSD_SKIP_REVIEWS=1 bash check-plan-review.sh` → exit 0 with a stderr announcement (not silent). `touch <phase>/multi-ai-review-skipped; bash check-plan-review.sh` → exit 0, also announced. Source: `check-plan-review.sh:65-68`, `360-363`. |
| 6 | The resolver selects the active phase in the spec's documented order and fails open when nothing resolves | ✓ VERIFIED | Direct execution of all four resolver steps in isolation: (a) explicit `.planning/current-phase` symlink pointer wins and resolves correctly (`GSD_PLAN_REVIEW_DEBUG=1` confirmed `resolved-phase:` matches the pointer target); (b) with no pointer, `.planning/STATE.md`'s `## Current Position` / `Phase: NN` line resolves the phase (confirmed it correctly picked phase 09 and blocked, matching that phase's plans-without-reviews state); (c) with neither pointer nor STATE.md, the newest `*-PLAN.md` by mtime wins (re-touched an older phase's plan file to be newest; resolver picked it); (d) with an empty `.planning/phases` tree and no STATE.md/pointer, resolution fails open (exit 0). All four steps individually reproduced in scratch git repos, not merely read from source. |
| 7 | `migrations/run-tests.sh` passes, including a `test_migration_0008` that is a no-op on second run | ✓ VERIFIED | `bash migrations/run-tests.sh` run live: **260 PASS / 1 SKIP / 0 FAIL** (the 1 SKIP is `0000-baseline.md is interactive-only`, unrelated to this phase). `test_migration_0008` (lines 777-1200+ of `run-tests.sh`) asserts cksum-identical output on a second run for both the config-merge step (line 887: "second merge run is a no-op (cksum unchanged)") and the AGENTS.md ritual-section insert (line 1017: "second run of Step 2 is a no-op (cksum unchanged)"), plus a duplicate-insert guard and a rollback-preserves-siblings assertion. Read the assertion code directly; it is a real cksum comparison, not a predicate re-check that could pass on a duplicated section. |

**Score:** 6/7 ROADMAP criteria cleanly VERIFIED; criterion 4 has a substantive caveat (see derived truth).

### Derived Truth — Verifier Strictness-Contract Integrity (beyond the 7 literal ROADMAP criteria, per this task's explicit instruction to weigh 08-REVIEW.md's CR-01 finding into the verdict)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 8 | The verifier's REVIEWS.md evidence check cannot be bypassed by a malformed-but-plausible artifact or a vendor-identity spoof — it robustly enforces ">=2 independent, vendor-diverse reviewers" in general, not only on the artifact shape the shipped test suite happens to exercise | ✗ FAILED | Two independent live reproductions, both outside `run-tests.sh`'s existing coverage (confirmed via `grep` that no CRLF/trailing-space/codex-identity fixture exists in the enforcement test block): **CR-01** — `printf -- '--- \nphase: 9\nreviewers: [solo]\nplans_reviewed: []\n---\nbody\n' > 09-REVIEWS.md; bash check-plan-review.sh` → **exit 0** with exactly one reviewer (a trailing space on the opening `---` silently downgrades the strict path to the spoofable `>=5`-line fallback). **WR-01** — `reviewers: [codex, codex-self]` (well-formed frontmatter, no encoding trick) under a plans-without-summary fixture → **exit 0**, even though D-15 explicitly excludes `codex` as a forbidden self-reviewer and this pair is two distinct strings but zero genuine external reviewers. Neither defect is recorded as an accepted/known limitation in ADR-0009 (unlike the >=5-line fallback's own documented spoofability, decision 11) — both are unresolved. This is the "gate silently fails open" failure class the phase's own producer-skill documentation names as the thing to avoid (`skills/codex-plan-review/SKILL.md` "Failure modes" section), reproduced against the verifier rather than the producer. |

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.planning/config.codex.json` | `pre_execution.plan_review` binding, source of truth (D-01) | ✓ VERIFIED | `jq '.hooks.pre_execution'` shows `plan_review` with `skill`, `verifier`, `fires_when`, `evidence_artifact`, `min_reviewers: 2`, `escape_hatches` — matches the template byte-for-byte in the fields that matter. |
| `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` | Same binding, fresh-install path | ✓ VERIFIED | Identical `plan_review` block to the repo's own config, confirmed via `jq`. |
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` | Programmatic verifier: resolver, grandfather, escape hatches, REVIEWS.md strictness | ✓ VERIFIED (existence/substance/wiring) — see derived truth #8 for a caveat on one enforcement edge case | 616 lines, executable, invoked by `run-tests.sh` and named in `AGENTS.md`'s ritual text and `config.codex.json`'s `verifier` key. |
| `skills/codex-plan-review/SKILL.md` | Producer skill authoring `<NN>-REVIEWS.md`, D-12 schema, refusal below 2 reviewers | ✓ VERIFIED | Full 10-step procedure, reviews-skeleton marker pair extracted and round-tripped by `test_check_plan_review_contract`; explicit "Failure modes" section names emitting a one-reviewer file as dishonest and forbidden. |
| `docs/decisions/0009-plan-review-gate.md` (ADR-0009) | Records D-01 hybrid decision, rejected alternatives, agent-mediated caveat, bootstrap paradox | ✓ VERIFIED | All 11 decisions present; decision 9 explicitly states the agent-mediated limitation and ROADMAP criterion 1's rewording; decision 8 records the bootstrap paradox and forbids a manufactured dogfood. Does **not** record CR-01/WR-01 (see derived truth #8) — this predates the post-execution code review that found them. |
| `migrations/0008-plan-review-gate.md` + `migrations/run-tests.sh` `test_migration_0008` | Idempotent existing-install migration, no-op on second run | ✓ VERIFIED | See criterion 7 evidence above. |
| `AGENTS.md` bindings table (D-20) | 16 distinct gates, no duplicate `tdd` row | ✓ VERIFIED | Counted 16 data rows (lines 124-139), single `tdd` row, matches `spec/02`'s 16-gate count (not the stale "15" in `spec/09:61`, which ADR-0009 and CONTEXT.md both flag as an upstream bug, out of scope here). |
| `skills/agentic-apps-workflow/SKILL.md` trigger mirror | Plan-review row in a "Pre-execution" group, ritual text mirrors AGENTS.md | ✓ VERIFIED | `### Pre-execution` heading with the sole `plan-review` row (line 178-182); `diff` of the AGENTS.md ritual section against the template section is byte-identical. |

## Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `AGENTS.md` ritual text | `check-plan-review.sh` | Named stable path `${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/check-plan-review.sh`, invoked unconditionally | ✓ WIRED | Ritual text (lines 111-139) names the exact path and instructs unconditional invocation ("Run it every time. Do not pre-judge whether it applies."), matching D-03/D-04. |
| `migrations/run-tests.sh` | `check-plan-review.sh` | Subprocess invocation across resolver/enforcement/contract test functions | ✓ WIRED | Confirmed via live run: 3 dedicated test functions (`test_check_plan_review_resolver`, `test_check_plan_review_enforcement`, `test_check_plan_review_contract`) all present and passing. |
| `check-plan-review.sh` | `.planning/STATE.md` | awk parse anchored on `## Current Position`, `Phase:` line | ✓ WIRED | Reproduced directly (criterion 6 evidence, step b). |
| `.planning/config.codex.json` / template | `check-plan-review.sh` | `verifier` key names the script path | ✓ WIRED | Confirmed via `jq` on both files. |
| `migrations/0008-plan-review-gate.md` | `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md` | Section/table extraction at the installed template path | ✓ WIRED | `test_migration_0008`'s Step 2/3 assertions extract from the real template and assert byte-identical insertion; re-read the assertion code directly. |

## Anti-Patterns Found

Scanned all phase-08-modified files (`check-plan-review.sh`, `run-tests.sh`, `0008-plan-review-gate.md`, `codex-plan-review/SKILL.md`, `docs/decisions/0009-plan-review-gate.md`, `agentic-apps-workflow/SKILL.md`, `agents-md-additions.md`, `config-hooks.json`, `.planning/config.codex.json`, `AGENTS.md`, `CHANGELOG.md`, `.codex/workflow-version.txt`) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER`.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none in phase-08 files) | — | — | — | The one `PLACEHOLDER` hit in `CHANGELOG.md:442` is pre-existing prose describing an unrelated template feature (`workflow-config.md`'s `{{PLACEHOLDERS}}`), predating this phase — not a debt marker introduced here. |

No unreferenced debt markers found in phase-08 deliverables.

**Carried forward from 08-REVIEW.md (already found, not re-derived at length; independently spot-checked where noted):**
- **CR-01** (Critical) — re-verified live above (derived truth #8).
- **WR-01** (Warning) — re-verified live above (derived truth #8).
- **WR-02** (Warning, code-inspection only per the review; not independently re-executed here — no failing repro exists against this repo's own `AGENTS.md` or the shipped test fixture, per the review's own admission) — migration 0008 Step 3's table-edit pattern is not scoped to the specific validated header; a hypothetical `AGENTS.md` with an unrelated `|---|` table earlier in the file could be silently corrupted instead. Not independently reproduced; carried as-is.
- **WR-03** (Warning, partially executed per the review) — `--file` bypass's traversal guard rejects literal `..` components but not symlinked directory components. Bounded severity because the whole gate is advisory/agent-mediated. Not independently re-executed here; carried as-is.
- **IN-01** (Info) — `fires_when` text in the declarative binding omits the REVIEWS.md-evidence condition. Purely descriptive, no functional effect. Confirmed present in both `.planning/config.codex.json` and the template, unchanged.

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes | `bash migrations/run-tests.sh` | 260 PASS / 1 SKIP / 0 FAIL | ✓ PASS |
| Phase-with-plans-no-reviews blocks | `bash check-plan-review.sh` (scratch fixture) | exit 2, correct block message | ✓ PASS |
| SUMMARY-present phase allows | same fixture + `09-01-SUMMARY.md` | exit 0 | ✓ PASS |
| Legacy bare-number phase allows | scratch `phases/10/PLAN.md` | exit 0 | ✓ PASS |
| `GSD_SKIP_REVIEWS=1` hatch | env var + blocking fixture | exit 0, announced on stderr | ✓ PASS |
| `multi-ai-review-skipped` marker hatch | marker file + blocking fixture | exit 0, announced on stderr | ✓ PASS |
| Resolver step 1 (pointer) | symlink `.planning/current-phase` | resolved-phase matches pointer | ✓ PASS |
| Resolver step 2 (STATE.md) | `## Current Position` / `Phase: 09` | resolved phase 09, blocked correctly | ✓ PASS |
| Resolver step 3 (mtime) | re-touch older plan to be newest | resolver picked the newest | ✓ PASS |
| Resolver step 4 (fail-open) | empty `.planning/phases`, no STATE/pointer | exit 0 | ✓ PASS |
| CR-01 repro (trailing-space delimiter) | crafted 1-reviewer REVIEWS.md with `--- ` first line | exit 0 (should be exit 2) | ✗ FAIL (confirms gap) |
| WR-01 repro (codex self-review) | `reviewers: [codex, codex-self]`, well-formed frontmatter | exit 0 (should arguably be rejected per D-15) | ✗ FAIL (confirms gap) |

## Probe Execution

No `scripts/*/tests/probe-*.sh` convention exists in this repo, and no plan/SUMMARY references a probe script by that name. `migrations/run-tests.sh` is this project's equivalent runnable acceptance harness and is covered under Behavioral Spot-Checks / criterion 7 above.

## Requirements Coverage

This repo has no `.planning/REQUIREMENTS.md` (expected — GSD scaffold adopted starting at phase 8; not a gap). Requirement IDs are declared inline in each plan's frontmatter (`core spec §02`, `core spec §09`) and map directly to the ROADMAP criteria verified above. No orphaned requirement IDs found beyond the two named in the phase header.

## Known/Accepted Limitations (per task instructions — NOT reported as gaps)

- Grandfather guard's per-plan-vs-per-phase SUMMARY conflation (ADR-0009 decision 8b, open question, deliberately unresolved).
- `implements_spec` stays 0.4.0 while `.planning/config.codex.json` reads a pre-existing "0.1.0" (D-17, out of scope).
- Codex native `~/.codex/hooks.json` not adopted (D-01/D-02, explicit upgrade path documented).
- `.planning/phases/` 00-07 not migrated to GSD-native layout (D-18, deliberate).
- The `>=5`-line fallback's general spoofability (ADR-0009 decision 11) — this is the *documented, accepted* weakening; it is distinct from CR-01, which is an *undocumented* defect in when that fallback is reached at all.

## Human Verification Required

### 1. Disposition of CR-01 and WR-01 (Critical + Warning code-review findings, independently re-confirmed)

**Test:** Decide whether to (a) patch `check-plan-review.sh`'s delimiter comparison and reviewer-identity check now, adding the two missing regression fixtures to `test_check_plan_review_enforcement`, or (b) formally record both as accepted, documented limitations in an ADR-0009 addendum (mirroring how decision 11 already documents the `>=5`-line fallback's spoofability) before treating this phase as fully closed.

**Expected:** A deliberate decision recorded in the codebase (either a code fix + tests, or an ADR addendum) — not silence, since silence is what let CR-01 sit unaddressed between the code review and this verification pass.

**Why human:** This is a scope/risk-tolerance judgment call the phase's own operator/reviewer chain is set up to make (the same escalation pattern ADR-0009 decision 11 already models), not something a verifier should resolve unilaterally by either fixing code or waiving the finding.

## Gaps Summary

Six of seven literal ROADMAP success criteria are cleanly verified by direct, live execution against scratch fixtures — not by trusting SUMMARY.md claims. `migrations/run-tests.sh` is green at 260/1/0 exactly as claimed, and `test_migration_0008` is a genuine, cksum-verified no-op on second run. The resolver's four-step order, both grandfather guards, both escape hatches, and the fail-open path were all independently reproduced.

The one substantive gap is criterion 4's underlying "strictness contract": the verifier's REVIEWS.md evidence check — the specific mechanism the entire phase exists to add (D-01's rejection of "declarative-only" enforcement) — can be defeated two independent ways that are not on the golden path the shipped test suite exercises and are not recorded as accepted limitations anywhere in this phase's own documentation. Both were found by this phase's own post-execution code review (`08-REVIEW.md`) and neither has been fixed or formally accepted since. Given the entire point of this phase is a *programmatic, deterministic* backstop against the exact "gate silently fails open" failure class core ADR-0018 exists to close, shipping with two live, reproducible instances of exactly that failure class — undocumented — is the one place this verification declines to rubber-stamp the phase as unconditionally closed.

---

_Verified: 2026-07-15T08:59:53Z_
_Verifier: Claude (gsd-verifier)_
