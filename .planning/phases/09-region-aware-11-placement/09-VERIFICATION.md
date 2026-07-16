---
phase: 09-region-aware-11-placement
verified: 2026-07-15T16:12:25Z
status: gaps_closed_via_09.1
score: 14/21 requirements DELIVERED, 5 DELIVERED-UNTESTED, 2 PARTIAL, 0 NOT-DELIVERED (as scored 2026-07-15, BEFORE Phase 9.1 ran)
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 14/21 DELIVERED, 5 DELIVERED-UNTESTED, 2 PARTIAL
  closed_by: phase 09.1-11-strip-runaway-inserted
  closed_date: 2026-07-16
  gaps_closed: [MIGR-01, MIGR-06, MIGR-07, MIGR-08, ANCHOR-05]
  gaps_remaining: []
  regressions: []
  note: >
    This body was written 2026-07-15T16:12 and is NOT re-scored in place — it is
    preserved as the record of what was true then. Every gap it names was
    explicitly deferred to Phase 9.1 by this document's own Gaps Summary
    ("Recommended: fold V-01 and V-02 into Phase 9.1's scope"), and 9.1 closed
    each. See the Gap Closure Record appended at the end of this file. This is a
    disposition record, not a fresh 21-requirement re-derivation.
gaps:
  - truth: "Migration 0009 applies to the projects this host scaffolds — the entire stated purpose of the phase"
    status: closed
    closed_by: "Phase 9.1 — 09.1-01 (2f4d9d5, dc540b7) + 09.1-02 (f1a1da8, 2fe23d4)"
    closed_date: 2026-07-16
    closed_evidence: >-
      V-01 closed. Pre-flight now reads `.codex/workflow-version.txt` per 0008:73-79
      (`0009:98`); Step 2's scaffolder bump deleted entirely and dropped from
      `applies_to`; `_m0009_mk_project` no longer manufactures a synthetic SKILL.md;
      0008's `no-scaffolder-tree` fixture ported. All four "missing" items below were
      done. Independently re-proven in UAT (09.1-UAT.md test 2) against a real
      target-project shape: pre-flight exit 0 at 0.6.0 and 0.7.0, exit 3 with the
      correct diagnostic at 0.2.1 — and the counterfactual, `git show f1a1da8^`'s
      pre-flight on the SAME sandbox, still aborts exit 3 ("version is unknown").
    reason_at_time: >-
      0009's pre-flight guard 2 greps the PROJECT-RELATIVE path
      `skills/agentic-apps-workflow/SKILL.md` for its version floor, and Step 2 seds
      that same path. No target project has a local `skills/` tree. On every real
      scaffolded project the pre-flight aborts with `exit 3` and Step 1 never runs.
      This is a byte-for-byte replication of migration 0007's documented defect —
      the one 0008 explicitly refused to replicate (`0008:470-487`, T-08-38) and
      built a regression-guard fixture for. The phase goal says the defect is LATENT
      on this host and 0009 exists "for projects this host scaffolds"; on exactly
      those projects, 0009 never executes. Reproduced live against a target-project
      shape (no `skills/` tree): `ABORT: workflow scaffolder version is unknown
      (need 0.6.0)` → exit 3.
      NOT covered by Phase 9.1's scope (which addresses CR-01/CR-02/CR-03,
      `11-idempotent-rerun`, ADR, upstream filing) — this gap is unscheduled.
    artifacts:
      - path: "migrations/0009-spec-11-region-aware-placement.md"
        issue: >-
          `:9` applies_to names `skills/agentic-apps-workflow/SKILL.md`;
          `:95-101` pre-flight greps it (aborts exit 3 on every real install);
          `:365-370` Step 2 idempotency/pre-condition/sed all target it.
          Identical in shape to `0007:10`, `0007:59-65`, `0007` Step 3.
      - path: "migrations/run-tests.sh"
        issue: >-
          `:3366-3372` `_m0009_mk_project` manufactures a synthetic
          `skills/agentic-apps-workflow/SKILL.md` at 0.6.0 in EVERY 0009 sandbox —
          precisely what 0008's suite refused to do (`:918-919`: "no 0008 sandbox
          here manufactures a synthetic SKILL.md"). All 10 TEST-03 fixtures
          therefore run against a project shape that does not exist in reality,
          which is why the suite is green.
    missing:
      - "Pre-flight floor must read `.codex/workflow-version.txt` (the durable per-project record the update skill's Stage A actually reads), as `0008:69-79` does — not a project-relative scaffolder path."
      - "Step 2 (scaffolder SKILL.md bump) must be removed from the migration and from `applies_to`. Per 0008's precedent the repo's own scaffolder bump is a DIRECT EDIT in the phase commit, never a migration step. MIGR-09 is already satisfied that way."
      - "Port 0008's `no-scaffolder-tree` regression fixture (run-tests.sh:1633-1706) to `test_migration_0009`: a sandbox with NO local `skills/` directory that must migrate end-to-end. Without it this defect class stays invisible."
      - "Stop manufacturing a synthetic SKILL.md in `_m0009_mk_project`, or the ported fixture is neutralized on arrival."
  - truth: "The suite's MIGR-07 assertion discriminates a healthy-but-off-anchor block"
    status: closed
    closed_by: "Phase 9.1 — 09.1-04 (d360fac)"
    closed_date: 2026-07-16
    closed_evidence: >-
      V-02 closed. `state-a` rewritten to place the block BELOW a real project heading
      with no region anywhere, isolating position as the sole variable. Proven
      falsifiable by verified mutation: expected arg flipped to "not-applied" → observed
      FAIL → restored → PASS. The assertion can now fail for the reason it claims.
    reason_at_time: >-
      The BEHAVIOR is correct — verified live: the Step 1 idempotency predicate
      returns exit 0 (skip) on a genuinely off-anchor healthy block. But the fixture
      labeled "D-31/MIGR-07" is ON-anchor: `state-a` (run-tests.sh:3509-3516) places
      the block before its first `## ` heading (`## Project Overview`), so the block
      sits AT the anchor. The assertion at `:3553` passes identically whether or not
      the off-anchor property holds — it cannot fail for the reason it claims to
      guard. Same dead-assertion class as CR-03, in a fixture whose comment
      (`:3549-3552`) asserts it is "ALSO MIGR-07's guard".
    artifacts:
      - path: "migrations/run-tests.sh"
        issue: "`:3509-3516` state-a fixture is on-anchor; `:3553` claims to guard MIGR-07's off-anchor case but cannot discriminate it."
    missing:
      - "A fixture whose §11 block sits BELOW the first `## ` heading (no region), asserted `applied` — the only shape that makes the MIGR-07 label load-bearing."
  - truth: "This repo's own version records are internally consistent"
    status: closed
    closed_by: "Phase 9.1 — 09.1-03 (fb6b148 RED, 7a1e7bc GREEN)"
    closed_date: 2026-07-16
    closed_evidence: >-
      V-03 closed. `.codex/workflow-version.txt` bumped 0.6.0 → 0.7.0 as a direct edit
      (MIGR-09), matching 0008's 98c06f5 precedent of bumping both records in one
      commit. `test_drift()` gained a consumer-owned third leg reading BOTH records and
      failing on mismatch — the exact blind spot named below. RED observed before GREEN
      (skill_v=0.7.0 / proj_v=0.6.0), and the leg proven falsifiable by verified
      mutation. UAT test 8: both read 0.7.0; `run-tests.sh drift` → 2 PASS / 0 FAIL.
    reason_at_time: >-
      `skills/agentic-apps-workflow/SKILL.md:3` reads `version: 0.7.0` but
      `.codex/workflow-version.txt` still reads `0.6.0`. This diverges from the 0008
      precedent, where commit 98c06f5 bumped BOTH in the migration's own commit. The
      drift test only couples SKILL.md to the latest migration's `to_version`
      (run-tests.sh:3194-3208) and never reads `.codex/workflow-version.txt`, so
      nothing catches the split. Low severity on its own; it is listed because it is
      the same root confusion as the blocker — conflating the scaffolder host's own
      version surface with a target project's.
    artifacts:
      - path: ".codex/workflow-version.txt"
        issue: "Reads 0.6.0 while the scaffolder SKILL.md reads 0.7.0; no test couples them."
    missing:
      - "Decide and record whether this repo self-applies 0009 (0008's precedent says yes → bump to 0.7.0), or state explicitly why 0009 is not self-applied."
deferred:
  - truth: "The strip terminator's alternation is enforced by the fixture suite (ANCHOR-05)"
    addressed_in: "Phase 9.1"
    evidence: "Phase 9.1 success criterion 6: '`11-idempotent-rerun` exists: narrowing the strip terminator fails the suite.'"
  - truth: "The strip cannot run away to EOF (CR-01)"
    addressed_in: "Phase 9.1"
    evidence: "Phase 9.1 success criteria 1-2: fixture reproduces the runaway and the strip's entry/exit conditions are coupled."
  - truth: "The provenance regex is anchored (CR-02)"
    addressed_in: "Phase 9.1"
    evidence: "Phase 9.1 success criterion 3: 'The provenance regex is anchored, with a fixture-07 twin.'"
  - truth: "`test -s`'s assertion is live (CR-03)"
    addressed_in: "Phase 9.1"
    evidence: "Phase 9.1 success criterion 5: \"`test -s`'s assertion is live: deleting the guard fails the suite.\""
human_verification:
  - test: "Decide the disposition of V-01: is migration 0009 intended to run on target projects at all, or was it authored against this repo's own layout deliberately?"
    expected: "If target projects are in scope (the phase goal says they are), V-01 must be scheduled into 9.1 alongside CR-01. If not, the phase goal and ROADMAP need rewording."
    why_human: "Scope decision. The evidence is unambiguous that 0009 cannot run on a target project; whether that inverts the phase's purpose is a product call."
    status: resolved
    resolved_date: 2026-07-16
    resolution: >-
      RESOLVED as "target projects ARE in scope" — the first of the two branches this
      item names. V-01 was scheduled into Phase 9.1 alongside CR-01 and closed there
      (09.1-01/09.1-02), and 9.1's ROADMAP entry made criterion 0 an explicit BLOCKER:
      "0009 actually runs on a real target project". The phase goal and ROADMAP did NOT
      need rewording — the goal was right and the implementation was wrong. Recorded in
      ADR-0010's Correction section as a codex-side PORTING ERROR (upstream greps
      `.claude/skills/…`, a path its own setup skill creates; our port dropped the
      `.claude/` prefix), against 0008's T-08-38 precedent for the same defect class.
---

# Phase 9: Region-Aware §11 Placement — Verification Report

**Phase Goal:** Ship migration `0009-spec-11-region-aware-placement.md` so the spec §11 Coding Discipline block anchors above a leading GitNexus region instead of inside it — closing a latent block-destruction defect **for projects this host scaffolds** — with the anchor rule validated empirically before the migration is written, and a TDD fixture suite that sources the migration's shell from the document itself.

**Verified:** 2026-07-15T16:12:25Z
**Status:** gaps_found (phase already reopened; 9.1 scoped)
**Re-verification:** No — initial verification

## Scope note

Per the verification brief, the already-recorded findings (CR-01 runaway strip, CR-02
unanchored provenance regex, CR-03 dead `test -s` assertion, missing
`11-idempotent-rerun` fixture, MIGR-08 untested, WR-02 "Step 6" citation) are **not
re-litigated here**. They are listed under `deferred` where Phase 9.1 covers them.

This report's contribution is **requirement traceability** — plus one blocker that
nothing else has caught.

---

## Requirements Coverage

All 21 IDs are claimed across the 5 plans' `requirements:` frontmatter, and all 21 are
declared in REQUIREMENTS.md against Phase 9. **No orphaned requirements** — every ID
mapped to Phase 9 in REQUIREMENTS.md:94-114 appears in at least one plan.

Verdict key: **DELIVERED** = implemented and covered by a discriminating test ·
**DELIVERED-UNTESTED** = behavior present and verified by hand, but no test would fail
if it regressed · **PARTIAL** = delivered in part, or delivered but non-functional in
its stated context · **NOT-DELIVERED** = absent.

| ID | Verdict | Evidence checked (file:line) |
|---|---|---|
| **ANCHOR-01** | DELIVERED | `0009:288` insert alternation `!inserted && (/^## / \|\| /^<!-- gitnexus:start -->$/)`. Fixtures 01/02/03 PASS. `validate-0009-anchor.sh` CASE 1+2 PASS (ran live, exit 0). |
| **ANCHOR-02** | DELIVERED | `0009:298-305` `END { if (!inserted) … }` EOF fallback. Fixture `06-no-heading-eof` PASS — provenance at line 5, below the 3 lines of pre-existing prose. |
| **ANCHOR-03** | DELIVERED | Ran `validate-0009-anchor.sh` live → `PASS CASE 1 ZERO CHURN — candidate rule re-derives §11's current position byte-identically`, exit 0. Recorded at `09-VALIDATION-EVIDENCE.md:84,153`. Ordering honored: plan 09-01 is wave 1; 09-04 (authoring) is wave 3. |
| **ANCHOR-04** | DELIVERED | `validate-0009-anchor.sh` CASE 2 live → provenance line 5 above `gitnexus:start` line 86, region paired (start=1 end=1). COUNTER-CASE A live → naive anchor puts provenance at line 10 **inside** the region: the assertion is proven live, not dead. |
| **ANCHOR-05** | DELIVERED-UNTESTED | Strip terminator `0009:265` carries the alternation; rollback is `git checkout` (`0009:361`) so it has no terminator to widen. Enforced live **only** by `validate-0009-anchor.sh` COUNTER-CASE B. No `11-idempotent-rerun` fixture ⇒ narrowing the terminator does not fail the suite. *(known; deferred to 9.1)* |
| **MIGR-01** | **PARTIAL** | Frontmatter `0009:5-6` `from_version: 0.6.0` / `to_version: 0.7.0` — correct. Pre-flight `0009:96` does accept both versions (`0\.(6\.0\|7\.0)`) — but greps `skills/agentic-apps-workflow/SKILL.md`, a path no target project has. **The gate is non-functional on every real install** (V-01, reproduced). |
| **MIGR-02** | DELIVERED | Idempotency predicate `0009:160-167`. Fixture `03-healthy-noop`: "AGENTS.md is BYTE-IDENTICAL after Apply (zero churn)" PASS. |
| **MIGR-03** | DELIVERED | `0009:255-307` strip+insert. Fixture `02-inside-region-move`: exactly ONE provenance line, moved above `gitnexus:start`, region paired. PASS. *(CR-01 caveat known)* |
| **MIGR-04** | DELIVERED | Unified inject path `0009:229-307`. Fixture `01-gitnexus-led-inject` PASS — provenance line 5 above start line 86, region body survived. |
| **MIGR-05** | DELIVERED | `0009:213-228` abort branch. Fixture `05-unmanaged-conflict`: exit exactly 3 **and** file byte-identical after refusal. Both directions asserted. PASS. |
| **MIGR-06** | DELIVERED-UNTESTED | Conjunctive predicate `0009:160-167` (provenance AND not-in-region) is present and correct. No `11-idempotent-rerun` fixture exercises a full re-run. *(known; deferred to 9.1)* |
| **MIGR-07** | DELIVERED-UNTESTED | **Behavior verified live by me**: built a genuinely off-anchor file (block below `## Project Overview`, no region) and ran `0009:160-167` → exit 0 (skip). Correct. **But the suite does not test it**: `run-tests.sh:3509-3516` `state-a` is ON-anchor, so the assertion at `:3553` labeled "D-31/MIGR-07" cannot discriminate. *(new — V-02)* |
| **MIGR-08** | DELIVERED-UNTESTED | Step 3 `0009:377-382` writes `0.7.0`. Untested *(known)*. Additionally **unreachable in production** via V-01. Also: this repo's own `.codex/workflow-version.txt` still reads `0.6.0` *(V-03)*. |
| **MIGR-09** | DELIVERED | `skills/agentic-apps-workflow/SKILL.md:3` → `version: 0.7.0`; `:4` `implements_spec: 0.4.0` correctly untouched. `test_drift` (`run-tests.sh:3198-3208`) PASS: "SKILL.md version matches latest migration to_version". |
| **TEST-01** | DELIVERED | `extract_step_block` `run-tests.sh:104`, `extract_preflight_block` `:124`, `assert_extracted_shape` `:142`. `MIGRATION_0009` `:3422` points at the real document. Every 0009 case executes extracted text via `_m0009_apply` `:3386-3388`. No transcribed copy found. |
| **TEST-02** | DELIVERED | Auditable commit shape: `a4b137f` / `2315393` / `185abfd` `test(09-03): … (RED)` precede `49b2fab feat(09-04): … turns the 0009 RED suite GREEN`. `1a5488a` records "suite intentionally RED per plan 09-03". Recorded at `09-VALIDATION-EVIDENCE.md:229` `RED OBSERVED`. |
| **TEST-03** | DELIVERED | All **ten** cases present and passing (ran `run-tests.sh 0009` live): 01-gitnexus-led-inject, 02-inside-region-move, 03-healthy-noop, 04-no-agentsmd, 05-unmanaged-conflict, 06-no-heading-eof, **07-prose-mention-not-a-region** (`:3819-3846`, emits `✓` via `assert_check` — present, contrary to a `PASS`-only grep), 08-rollback-region-led, 09-two-provenance-heal, 10-corrupt-mirror-refused (a/b/c). |
| **TEST-04** | DELIVERED | `run-tests.sh:119` no longer holds an inlined anchor awk — that range is now `extract_step_block`'s body. `test_migration_0001` sources 0001's own Step 1 Apply fence (`extract_step_block "$REPO_ROOT/migrations/0001-inject-spec-11-coding-discipline.md" 1 Apply`). |
| **SETUP-01** | DELIVERED | `skills/setup-codex-agenticapps-workflow/SKILL.md:129-134` records the single-source fact and points to ADR-0010. Corroborated: `0000-baseline.md:102` is a plain append; `agents-md-additions.md` carries no §11 — there is no second anchor. *(WR-02's "Step 6"→"Step 3" citation error known)* |
| **DOC-01** | DELIVERED | `docs/decisions/0010-region-aware-spec-11-placement.md` (377 lines) — records the anchor rule, the rejected "anchor before the region if one exists" alternative, §12's advisory status, and the D-48 pin `8520f90…` at `:5`, `:189`, `:214`. Index row `docs/decisions/README.md:27`. *(WR-04 known)* |
| **DOC-02** | DELIVERED | `CHANGELOG.md:25-47` — `## [0.7.0] — 2026-07-15`, release-altitude "Fixed" entry naming migration 0009 and linking ADR-0010, plus the operator upgrade path. |

**Totals:** 14 DELIVERED · 5 DELIVERED-UNTESTED (ANCHOR-05, MIGR-06, MIGR-07, MIGR-08, and MIGR-02/03 carry the known CR-01 caveat) · 2 PARTIAL (MIGR-01, and MIGR-08's production reachability) · **0 NOT-DELIVERED**.

Every one of the 21 IDs has real code behind it. **Nothing was claimed-but-absent.** The
phase's problem is not missing work — it is that the work targets the wrong project shape.

---

## V-01 — BLOCKER (new, unscheduled): 0009 aborts on every project it exists to fix

The phase goal is explicit that the defect is **latent** on this host and that 0009
exists "for projects this host scaffolds". Those projects are the only beneficiaries.
0009 cannot run on any of them.

**The mechanism.** `0009:95-101`:

```bash
SKILL_FILE=skills/agentic-apps-workflow/SKILL.md
grep -qE '^version: 0\.(6\.0|7\.0)$' "$SKILL_FILE" || { … exit 3; }
```

That path is project-relative. Reproduced against a sandbox shaped exactly like 0008's
own `no-scaffolder-tree` fixture (AGENTS.md + `.planning/` + `.codex/` + `docs/decisions/`,
no `skills/`):

```
ABORT: workflow scaffolder version is unknown (need 0.6.0).
       Apply prior migrations first via /update-codex-agenticapps-workflow.
→ exit 3, Step 1 never runs
```

`0009:369` Step 2 then seds the same non-existent path, and `0009:9` names it in
`applies_to`.

**Why this is not a new discovery for the repo — only for phase 9.** `0008:470-487`
documents this defect class by name:

> **Deliberate divergence from 0007's pre-flight and `applies_to`: this migration names
> no path under a target project's `skills/` tree, anywhere (T-08-38).** 0007's pre-flight
> greps `skills/agentic-apps-workflow/SKILL.md` for its version floor, and its own Step 3
> seds that same path. **No target project has a local `skills/` tree** … So 0007's floor
> grep hits a non-existent path and its pre-flight aborts with exit 3 on every real
> install — a defect this migration does not replicate.

0009 replicates it in all three places 0007 had it. The update skill confirms the correct
source: `skills/update-codex-agenticapps-workflow/SKILL.md:37` — "**Read
`.codex/workflow-version.txt`.** The single line is the [installed version]".

**Why the green suite cannot see it.** `run-tests.sh:3366-3372`:

```bash
_m0009_mk_project() {
  local p="$1/$2/proj"
  mkdir -p "$p/.git" "$p/skills/agentic-apps-workflow"
  printf -- '---\nname: agentic-apps-workflow\nversion: 0.6.0\n…' \
    > "$p/skills/agentic-apps-workflow/SKILL.md"
```

Every 0009 sandbox manufactures the file no real project has — the exact practice 0008's
suite refused (`run-tests.sh:918-919`: "This repo's own scaffolder bump is a direct edit
in plan 08-05's commit, never a migration step — **no 0008 sandbox here manufactures a
synthetic SKILL.md**"). 0008 also shipped the regression guard for it
(`run-tests.sh:1633-1706`); 09 did not port it. 314 PASS / 0 FAIL is therefore consistent
with a migration that never runs in production.

**Root cause.** MIGR-08 ("the migration records `0.7.0`") and MIGR-09 ("**this repo's own**
scaffolder is bumped in the same change") were conflated into one migration step. 0008
kept them apart deliberately: the scaffolder bump is a direct edit, the version record is
the migration's step. 0009 made the scaffolder bump Step 2 and then gated the whole
migration on it.

**Not deferred.** Phase 9.1's success criteria cover CR-01/CR-02/CR-03,
`11-idempotent-rerun`, ADR-0010's correction, and the upstream filing. None mention the
pre-flight, the `skills/` tree, or `applies_to`. V-01 is unscheduled.

---

## Probe / Behavioral Execution

| Check | Command | Result | Status |
|---|---|---|---|
| Full fixture suite | `bash migrations/run-tests.sh` | PASS: 314 · FAIL: 0 · SKIP: 1 (`0000-baseline.md is interactive-only`) | ✓ PASS |
| 0009 filter | `bash migrations/run-tests.sh 0009` | PASS: 34, all ten TEST-03 cases present | ✓ PASS |
| Anchor replay evidence | `bash migrations/validate-0009-anchor.sh` | `=== RESULT: all cases PASSED ===`, exit 0 — CASE 1 zero churn, CASE 2 above region, COUNTER-CASE A naive-inserts-in-region, COUNTER-CASE B narrow-terminator-eats-region | ✓ PASS |
| Drift coupling | `test_drift` | SKILL.md 0.7.0 == 0009 `to_version` | ✓ PASS |
| **0009 pre-flight vs. real target project** | verbatim `0009:95-101` in a no-`skills/` sandbox | `ABORT … exit 3` | **✗ FAIL (V-01)** |
| **MIGR-07 off-anchor behavior** | verbatim `0009:160-167` on a genuinely off-anchor file | exit 0 (skip) — behavior correct, suite fixture vacuous | ⚠ PASS-but-untested (V-02) |

---

## Gaps Summary

Phase 9 delivered a lot of real work: all 21 requirements have implementation behind
them, the empirical-before-writing discipline (ANCHOR-03/04) is genuinely honored with a
replay script that passes live and includes two counter-cases, and RED-before-GREEN
(TEST-02) is auditable in the commit graph. Nothing is claimed-but-absent.

The failure is one of **target**, not effort. Migration 0009 is written as though the
project it migrates were this repo — which is the one repo where the defect is *latent
and harmless*. On the scaffolded projects the phase goal names as the beneficiaries, it
aborts at pre-flight. The fixture suite cannot see this because it manufactures the very
file whose absence is the problem, and that manufacture is the specific practice the
previous migration's suite documented, refused, and guarded against.

This compounds the known CR-01 finding rather than duplicating it: CR-01 says the strip
destroys data *when it runs*; V-01 says it does not run at all on real projects. Both
must close before 0009 can be called shipped, and only CR-01 is scheduled.

Recommended: fold V-01 and V-02 into Phase 9.1's scope, and add a requirement — or a
suite-wide invariant — that no migration may name a path under a target project's
`skills/` tree, so 0007 → 0009 does not become 0007 → 0009 → 0011.

---

_Verified: 2026-07-15T16:12:25Z_
_Verifier: Claude (gsd-verifier)_

---

## Gap Closure Record — appended 2026-07-16 (Phase 9.1 complete)

The body above is preserved verbatim as the 2026-07-15 record. It is not re-scored;
this section records the disposition of each gap it raised. Phase 9's checkbox was
marked complete in ROADMAP.md on 2026-07-16 on this basis.

| Gap (as scored above) | This document's own note | Closed by | Independent evidence |
|---|---|---|---|
| **MIGR-01** `PARTIAL` — "greps `skills/agentic-apps-workflow/SKILL.md`, a path no target project has. The gate is non-functional on every real install (V-01)" | reproduced, unscheduled | `09.1-02` (`f1a1da8`) — pre-flight reads `.codex/workflow-version.txt` per `0008:73-79` | UAT test 2 (`09.1-UAT.md`): real target project at 0.6.0, no `skills/` tree → pre-flight **exit 0**. Counterfactual proven — the pre-fix pre-flight (`git show f1a1da8^`) on the SAME sandbox → `grep: skills/agentic-apps-workflow/SKILL.md: No such file or directory` → **exit 3**. |
| **MIGR-08** `PARTIAL` + untested — "unreachable in production via V-01. Also: this repo's own `.codex/workflow-version.txt` still reads `0.6.0` (V-03)" | two distinct defects | `09.1-02` (V-01) + `09.1-03` (`7a1e7bc`, V-03) | UAT test 8: both records read `0.7.0`; `run-tests.sh drift` PASSes and now hard-fails on a future split (third leg, mutation-proven). |
| **ANCHOR-05** untested — "No `11-idempotent-rerun` fixture ⇒ narrowing the terminator does not fail the suite. *(known; deferred to 9.1)*" | deferred by name | `09.1-06` (`b940f09`) — `12-idempotent-rerun` (numbered 12 per Q4; `11-` went to the ported upstream fixture) | Mutation gate: narrowing the terminator alternation (2→1) produced 2 FAIL with `start=0 end=1`; restored, suite 0 FAIL. Independently re-proven in `09.1-VERIFICATION.md` by scratch-clone mutation. |
| **MIGR-06** untested — "No `11-idempotent-rerun` fixture exercises a full re-run. *(known; deferred to 9.1)*" | deferred by name | same fixture | UAT test 7: second run exits 0, byte-identical to first, markers paired 1/1, exactly one provenance line. |
| **MIGR-07** untested — "`state-a` is ON-anchor, so the assertion labeled 'D-31/MIGR-07' cannot discriminate. *(new — V-02)*" | new finding | `09.1-04` (`d360fac`) — `state-a` rewritten genuinely off-anchor | Falsifiability proven by verified mutation (expected arg flipped → FAIL → restored → PASS). |

**This document's own recommendation was followed.** Its Gaps Summary reads:
*"Recommended: fold V-01 and V-02 into Phase 9.1's scope."* V-01 closed in `09.1-01`/`09.1-02`,
V-02 in `09.1-04`, and V-03 (found in the same pass) in `09.1-03`.

**Deferred, non-blocking — carried forward as debt, NOT closed:**

- `09-REVIEW.md` **WR-05** — `validate-0009-anchor.sh`'s "deterministic banner" claim contradicted by its own output.
- `09-REVIEW.md` **IN-01..IN-04** — `extract_step_block` prefix-matching `### Step 1` vs `### Step 10`; CASE 1's unasserted line drop; the ADR/migration numbering collision; predictable temp-file names in CWD.
- Migration `0007`'s identical pre-flight bug — `0008` deferred it explicitly ("different migration, own scope").

These were consciously scoped out by `09.1-07` and are recorded here so Phase 9's
completion does not silently absorb them. Review via `/gsd-audit-uat`.

**Phase 9.1's own state at closure:** verification 11/11 criteria passed; UAT 10 passed /
1 issue (AG-01, accepted-and-disclosed by user ruling); security 37/37 threats closed,
`threats_open: 0`. Full suite 369 PASS / 0 FAIL / 1 SKIP.

_Gap closure recorded: 2026-07-16_
