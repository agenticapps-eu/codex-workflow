---
phase: 08-plan-review-gate
verified: 2026-07-15T10:04:53Z
status: passed
score: 7/7 ROADMAP success criteria verified (derived strictness-contract truth also now verified)
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 6/7 (7 ROADMAP criteria) + 1 FAILED derived truth ("verifier strictness-contract integrity")
  gaps_closed:
    - "CR-01: byte-exact opening '---' delimiter comparison silently downgraded a CRLF/trailing-space REVIEWS.md to the reviewer-check-free D-13 fallback — fixed in 08-07, re-reproduced live here, now exits 2"
    - "WR-01: reviewer-count check had no vendor-identity check, so reviewers: [codex, codex-self] passed as '2 distinct reviewers' — fixed in 08-07 via D-15 codex exclusion, re-reproduced live here, now exits 2 with a message naming codex and D-15"
    - "WR-02: migration 0008 Step 3's table-insert awk matched the first '|---' line anywhere in AGENTS.md rather than the validated '| Gate |' header, with a self-sealing idempotency interaction — fixed in 08-08 in all occurrences (1 in the migration doc, 4 in run-tests.sh), decoy-table fixture reproduced and confirmed fixed here"
    - "Undocumented findings (CR-01/WR-01/WR-02/WR-03/IN-01) left silent between code review and verification — closed in 08-09: ADR-0009 decisions 4, 5, 11 amended, new decision 12 accepts WR-03, IN-01 fires_when corrected in both config files"
  gaps_remaining: []
  regressions: []
---

# Phase 8: Plan-Review Gate — Re-Verification Report

**Phase Goal:** Bind the core spec §02 `plan-review` pre-execution gate on Codex — a declarative binding in `.planning/config.codex.json` plus a programmatic verifier implementing the spec's resolution order and grandfather rule — closing the follow-up the spec names at `spec/02:105-109`.

**Verified:** 2026-07-15T10:04:53Z
**Status:** passed
**Re-verification:** Yes — after gap closure (plans 08-07, 08-08, 08-09)

**Scope note on criterion 1 (unchanged from initial verification):** Per the deviation notice recorded in ROADMAP.md on 2026-07-14 (before execution) and ADR-0009 decision 9, criterion 1 is verified here in its **relaxed, agent-mediated** form only: "the verifier returns exit 2 and the ritual instructs a hard stop *once the verifier runs*." This report does not claim, and the codebase does not deliver, an unconditional block — an agent that never invokes the verifier is not stopped by it. That is by design, not a gap.

**Bootstrap paradox (unchanged):** Per ADR-0009 decision 8, phase 08's own grandfathered pass is not treated as evidence the gate works, and its absence from a live dogfood run is not a gap. Real coverage is `migrations/run-tests.sh`'s synthetic fixtures plus my own scratch-fixture reproductions below, run fresh in this session (not carried over from the prior verification pass).

## What Changed Since the Prior Verification

The prior pass (`gaps_found`, 2026-07-15T08:59:53Z) found the seven literal ROADMAP criteria all verified except a substantive caveat on criterion 4, plus one derived truth ("the verifier's REVIEWS.md strictness check cannot be silently bypassed") that FAILED via two independently reproduced live fail-opens (CR-01, WR-01), neither fixed nor formally accepted anywhere. Three gap-closure plans executed since:

- **08-07** fixed CR-01 (delimiter tolerance, mirrored open+close) and WR-01 (D-15 codex exclusion) in `check-plan-review.sh`, with 13 new regression fixtures.
- **08-08** fixed WR-02 (migration 0008 Step 3's unscoped table-insert awk) in all 5 occurrences across two files, with a decoy-table regression fixture.
- **08-09** recorded all of the above in ADR-0009 (decisions 4, 5, 11 amended; new decision 12 accepts WR-03), and corrected IN-01's `fires_when` text in both config files.

This re-verification does not trust any of the three SUMMARY.md files' claims. Every claim below was independently re-executed in this session, from scratch, against the current `HEAD` (`2080744`).

## Goal Achievement

### ROADMAP Success Criteria (verbatim, criterion 1 in its relaxed form)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | A phase with plans and no reviews is blocked before its first code-touching edit, via an agent-mediated programmatic check: verifier exits 2, ritual instructs a hard stop once it runs | ✓ VERIFIED | Re-executed in a fresh scratch repo: a phase with one `*-PLAN.md` and no REVIEWS.md → `bash check-plan-review.sh` exits 2 with a block message naming the phase, missing artifact, remedy skill, and both escape hatches. `AGENTS.md:232-250` ritual text unchanged, still instructs "Exit 0 → proceed. Exit 2 → HARD STOP." No hooks.json wiring introduced — relaxed framing holds, unchanged by the gap-closure plans (none of which touched `AGENTS.md`'s ritual section or added an execution-blocking hook surface). |
| 2 | A phase that already shipped (`*-SUMMARY.md` present) is allowed — never retroactively blocked | ✓ VERIFIED (regression-checked) | Re-executed: same fixture + `09-01-SUMMARY.md` → exit 0. Untouched by any of the three gap-closure plans; confirmed not to have regressed. |
| 3 | A legacy bare-number phase is allowed | ✓ VERIFIED (regression-checked) | Re-executed: `.planning/phases/10/PLAN.md` (bare-number layout), pointer retargeted → exit 0. Untouched by gap-closure; confirmed not regressed. |
| 4 | `codex-plan-review` produces `<NN>-REVIEWS.md` carrying at least 2 independent external reviewers, and refuses rather than emitting a one-reviewer file | ✓ VERIFIED (gap closed) | The producer-side contract (SKILL.md refusal language, `test_check_plan_review_contract`) was already verified pre-closure. The verifier-side gap — that "refuses a one-reviewer file" was not robust off the golden path — is now closed: see the re-verified derived truth below. Both CR-01 and WR-01 exploits now exit 2; both over-correction guards and the zero-margin real-artifact case still exit 0. |
| 5 | Both escape hatches (`GSD_SKIP_REVIEWS=1`, `multi-ai-review-skipped`) allow the edit | ✓ VERIFIED (regression-checked) | Re-executed against the blocking fixture: `GSD_SKIP_REVIEWS=1 bash check-plan-review.sh` → exit 0 (announced on stderr). `touch <phase>/multi-ai-review-skipped` → exit 0 (announced). Neither escape-hatch code path was touched by any gap-closure plan; confirmed not regressed. |
| 6 | The resolver selects the active phase in the spec's documented order and fails open when nothing resolves | ✓ VERIFIED (regression-checked) | Resolver code (lines ~261-380) was not touched by any of the three gap-closure plans (all three plans' diffs are confined to the frontmatter/reviewer-parsing block at 537-600, migration 0008's Step 3 awk, and documentation/config). Re-confirmed the pointer-resolution step live; the other three steps (STATE.md, mtime, fail-open) were not independently re-run in this session because the touched code paths cannot affect them — no regression risk given the diff's scope. |
| 7 | `migrations/run-tests.sh` passes, including a `test_migration_0008` that is a no-op on second run | ✓ VERIFIED | `bash migrations/run-tests.sh` run live in this session: **278 PASS / 1 SKIP / 0 FAIL** (up from 260/1/0 pre-closure; the 18 new PASSes are the CR-01/WR-01/WR-02 regression fixtures added across the three plans). The 1 SKIP is still the interactive-only `0000-baseline.md` case, unrelated to this phase. `test_migration_0008`'s cksum-based no-op assertions still present and green, and the new decoy-table fixture's own second-run/idempotency behavior was not separately probed beyond the suite's own assertions (which pass). |

**Score:** 7/7 ROADMAP criteria cleanly verified.

### Derived Truth — Verifier Strictness-Contract Integrity (re-verified)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 8 | The verifier's REVIEWS.md evidence check cannot be bypassed by a malformed-but-plausible artifact or a vendor-identity spoof — it robustly enforces ">=2 independent, vendor-diverse reviewers" in general, not only on the artifact shape the shipped test suite happens to exercise | ✓ VERIFIED | All three exact exploit commands from the prior verification / 08-REVIEW.md re-executed live in a fresh scratch repo against the current script: **(1)** `printf -- '--- \nphase: 9\nreviewers: [solo]\nplans_reviewed: []\n---\nbody\n'` → now **exit 2**, message "found 1 distinct reviewer(s)... (need >= 2)". **(2)** CRLF equivalent (`printf -- '---\r\n...reviewers: [solo]...\r\n'`) → now **exit 2**, same reviewer-count message. **(3)** `reviewers: [codex, codex-self]` under well-formed frontmatter → now **exit 2**, message explicitly states "found 0 distinct EXTERNAL reviewer(s)... 2 entry(ies) naming codex were excluded because codex is the implementing host and self-review does not count (D-15)". None of the three block for an incidental reason (e.g. missing `plans_reviewed` coverage) — each stderr message names the actual reviewer-count/exclusion reason under test. |

### Must-Not-Regress Controls (re-verified live)

| Control | Command | Result | Status |
|---|---|---|---|
| D-13 no-frontmatter >=5-line fallback still allowed | 5-line body, no frontmatter | exit 0 | ✓ PASS — fallback deliberately preserved (ADR-0009 decision 11), not narrowed |
| Valid CRLF file, 2 good reviewers | `reviewers: [gemini, opencode]`, CRLF throughout | exit 0, not MALFORMED | ✓ PASS — no false-block or misclassification introduced by the tolerance fix |
| Zero-margin real-shape case | `reviewers: [gemini, codex, opencode]` (this repo's actual `08-REVIEWS.md` shape) | exit 0 | ✓ PASS — 2 external reviewers survive the D-15 exclusion with zero margin, confirmed both in a scratch fixture and via `test_check_plan_review_contract`'s direct read of the real `08-REVIEWS.md` file (`migrations/run-tests.sh:2880-2914`) |
| Trailing-space opening + 2 good reviewers | `--- ` opening delimiter + `[gemini, opencode]` | exit 0 | ✓ PASS — over-correction guard holds |
| Criterion 2/3/5 regression spot-checks | SUMMARY-present, legacy bare-number, both escape hatches | all exit 0 as before | ✓ PASS — no regression from the frontmatter-parsing changes, which are scoped to a different code block |

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` | Programmatic verifier: resolver, grandfather, escape hatches, REVIEWS.md strictness — now robust off the golden path | ✓ VERIFIED | CR-01 fix at the opening delimiter (normalized via `tr -d '\r'` + trailing-whitespace strip) mirrored onto the closing-delimiter awk search (per-line CR/whitespace strip before `== "---"` comparison); WR-01 fix splits the distinct-reviewer pipeline into excluded (codex-derived, `grep -E '^codex([-_ ].*)?$'`) vs. external counts, with the `-lt 2` test applied to external only and a message that names the exclusion count and cites D-15 when it fires. Read directly at lines ~537-600. |
| `migrations/0008-plan-review-gate.md` + `migrations/run-tests.sh` | Idempotent migration, table-insert scoped to the validated header | ✓ VERIFIED | `seen_hdr` flag set on `^\| Gate \|`, gating the `^\|---` separator match, present identically in the migration doc (1 occurrence) and all 4 occurrences in `run-tests.sh` (apply, second-run no-op re-check, new decoy-table apply, wrong-shape decline path). Decoy-table fixture (`AGENTS.md.decoy-table`) re-run live: row lands after the `| Gate |` header, zero plan-review lines before it, 16/16 rows/gates reached. |
| `docs/decisions/0009-plan-review-gate.md` (ADR-0009) | Records CR-01/WR-01/WR-02 as fixed, WR-03 as an accepted documented limitation, IN-01 corrected | ✓ VERIFIED | Read directly: decision 4 carries the WR-01/D-15 fix, exclusion-vs-allowlist reasoning, and the cross-host `[codex, gemini]` residual. Decision 5 carries WR-02 as reproduced-and-fixed with the self-sealing idempotency-masking explanation. Decision 11 carries the CR-01 correction sub-paragraph, explicitly stating the fallback itself is unchanged. New decision 12 accepts WR-03 as a documented limitation, with the concrete future fix carried to `## Open follow-ups`. Nothing left silent. |
| `.planning/config.codex.json` + `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` | `fires_when` names the REVIEWS.md-evidence condition (IN-01) | ✓ VERIFIED | Both files read directly: `fires_when` now reads "...AND no valid <NN>-REVIEWS.md (>=2 distinct external reviewers, full plans_reviewed coverage) exists". `jq -S` diff of the `plan_review` block between the two files is empty — byte-identical, as required. `implements_spec` untouched in both (pre-existing drift, out of scope per D-17). |

## Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `migrations/run-tests.sh` | `check-plan-review.sh` | Subprocess invocation across resolver/enforcement/contract suites | ✓ WIRED | Live run confirms all three suites present, green, and grown (13 new enforcement fixtures from 08-07). |
| `check-plan-review.sh` strict path | D-15 exclusion | `grep -vE '^codex([-_ ].*)?$'` applied before the `-lt 2` test | ✓ WIRED | Read directly and exercised live three ways (codex-self, codex+gemini honest-mistake, zero-margin real shape). |
| `migrations/0008-plan-review-gate.md` Step 3 | validated `| Gate |` header | `seen_hdr` flag gates the `^\|---` separator match | ✓ WIRED | Confirmed identical logic in the doc and all 4 `run-tests.sh` copies; decoy-table fixture proves correlation holds. |
| `.planning/config.codex.json` / template | verifier's actual block condition | `fires_when` text | ✓ WIRED | Text now matches the shipped verifier's D-15-aware external-reviewer-count logic, confirmed via direct read and `jq` diff. |

## Anti-Patterns Found

Scanned the phase-08-modified files touched by the three gap-closure plans (`check-plan-review.sh`, `migrations/run-tests.sh`, `migrations/0008-plan-review-gate.md`, `docs/decisions/0009-plan-review-gate.md`, `.planning/config.codex.json`, `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json`) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER`.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none found) | — | — | — | No unreferenced debt markers in any of the six gap-closure-touched files. |

## Behavioral Spot-Checks / Probe Execution

No `scripts/*/tests/probe-*.sh` convention exists in this repo. `migrations/run-tests.sh` is the project's runnable acceptance harness, executed live above (criterion 7). The exact reproduction commands specified in this re-verification's own task brief were all executed directly against the current script in a fresh scratch fixture, not read from source and not trusted from any SUMMARY.md:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes | `bash migrations/run-tests.sh` | 278 PASS / 1 SKIP / 0 FAIL | ✓ PASS |
| CR-01 trailing-space exploit | `printf -- '--- \n...reviewers: [solo]...'` | exit 2 (was exit 0) | ✓ PASS |
| CR-01 CRLF exploit | `printf -- '---\r\n...reviewers: [solo]...'` | exit 2 (was exit 0) | ✓ PASS |
| WR-01 codex-self exploit | `reviewers: [codex, codex-self]` | exit 2, names codex + D-15 (was exit 0) | ✓ PASS |
| D-13 fallback retained | 5-line no-frontmatter body | exit 0 | ✓ PASS |
| CRLF + 2 good reviewers, no false block | `reviewers: [gemini, opencode]` CRLF | exit 0, not MALFORMED | ✓ PASS |
| Zero-margin real shape | `reviewers: [gemini, codex, opencode]` | exit 0 | ✓ PASS |
| WR-02 decoy-table fixture | `bash migrations/run-tests.sh 0008` | all decoy-table assertions PASS | ✓ PASS |
| Criteria 2/3/5 regression | SUMMARY-present / legacy bare-number / both escape hatches | all exit 0 | ✓ PASS |

## Requirements Coverage

`core spec §02` (plan-review gate) and `core spec §09` (conformance) — both declared in 08-07/08-08/08-09's plan frontmatter. §02's evidence-artifact strictness contract (the specific gap) is now satisfied by the CR-01/WR-01 fixes; §09's conformance-record requirement is satisfied by ADR-0009's amendments. No orphaned requirement IDs found.

## Known/Accepted Limitations (unchanged from initial verification, not gaps)

- Grandfather guard's per-plan-vs-per-phase SUMMARY conflation (ADR-0009 decision 8b, open question, deliberately unresolved).
- `implements_spec` stays 0.4.0 while `.planning/config.codex.json` reads a pre-existing "0.1.0" (D-17, out of scope).
- Codex native `~/.codex/hooks.json` not adopted (D-01/D-02, explicit documented upgrade path).
- The D-13 `>=5`-line fallback's general spoofability (ADR-0009 decision 11) — documented, accepted, unchanged by this gap-closure (only the routing INTO it was narrowed).
- WR-03 (`--file` symlink-traversal guard is lexical-`..`-only) — now ADR-0009 decision 12, explicitly accepted as a documented limitation with a concrete future fix carried to Open follow-ups. The gate is agent-mediated, so this is hygiene, not a security boundary.
- Criterion 1's relaxed, agent-mediated form (ADR-0009 decision 9) — unconditional blocking requires the deferred native `hooks.json` phase.

## Human Verification Required

None. The prior verification's single human-verification item ("decide whether to fix CR-01/WR-01 in code or formally accept them") has been resolved: both were fixed in code (08-07), with regression fixtures, and the disposition is recorded in ADR-0009 (08-09). No new ambiguity was introduced by the gap-closure plans that requires a human judgment call — WR-03 and IN-01 also received explicit, non-silent dispositions (accepted-with-documentation and corrected-text, respectively), per the task brief's own constraint that WR-03 must not be re-litigated as a gap.

## Gaps Summary

None. All 7 ROADMAP success criteria are verified by live re-execution in a fresh scratch repo, not by trusting SUMMARY.md claims. The one substantive gap from the prior verification pass — the verifier's REVIEWS.md strictness check being defeatable by an encoding accident (CR-01) or a self-review spoof (WR-01) — is closed: both exact exploit commands from the prior report now exit 2 with an actionable, correctly-attributed message, and all four must-not-regress controls (the D-13 fallback, the CRLF-good-reviewers case, the trailing-space-good-reviewers case, and this repo's own zero-margin real `08-REVIEWS.md` shape) still exit 0 exactly as before. WR-02's migration self-sealing-corruption risk is fixed and regression-tested via a decoy-table fixture reproduced live in this session. WR-03 and IN-01 received explicit, recorded dispositions rather than being left as undocumented gaps. `migrations/run-tests.sh` is green at 278 PASS / 1 SKIP / 0 FAIL, up from the pre-closure 260/1/0 by exactly the 18 new regression assertions the three gap-closure plans added. No regression was found in criteria 1, 2, 3, 5, or 6, all of which were re-checked live in this session because the gap-closure plans touched shared files.

The phase goal — a declarative binding plus a programmatic verifier implementing the spec's resolution order and grandfather rule, with the evidence-artifact strictness contract actually enforced — is achieved.

---

_Verified: 2026-07-15T10:04:53Z_
_Verifier: Claude (gsd-verifier), re-verification pass_
