# Phase 9: Region-Aware §11 Placement - Research

**Researched:** 2026-07-15
**Domain:** Migration authoring (bash/awk in markdown) for a spec-first scaffolder host; TDD fixture design; cross-repo defect propagation
**Confidence:** MEDIUM-HIGH — the phase domain itself is well-understood and CONTEXT.md's factual claims are ~95% verified against live files, but one **load-bearing claim central to D-21/ANCHOR-05 is independently confirmed false** by a same-day correction in the sibling repo this design is propagated from. See Conflicts.

## Summary

CONTEXT.md for this phase is unusually complete: 25 locked decisions with verified file/line citations, both rejected anchor alternatives, and a full canonical-refs section. This research's job was verification, not design — and verification surfaced one finding that changes the plan: **while this research was being written, `claude-workflow` shipped migration `0029-region-aware-spec-11-placement.md`** (file timestamp 13:44, three minutes after `codex-workflow`'s own `09-CONTEXT.md` was finalized at 13:42-43). CONTEXT.md's claim "migration 0029 does not exist" was accurate at the moment it was written (only RED fixtures existed at 13:39) but is now stale. This is not a minor timing footnote: the shipped 0029 contains a **documented, dated correction** ("An earlier draft of this spec claimed the rule was 'a one-alternation delta, so 0014's structural reasoning survives'... **That claim was false**, and it was load-bearing") to the *exact same claim* that `codex-workflow`'s own D-21 and the locked requirement ANCHOR-05 currently assert. See `## Conflicts With Locked Decisions` — this must go back to the user before planning locks task shapes around the wrong invariant.

Everything else CONTEXT.md asserts checks out: every file:line citation for the immutable machinery (0001, 0004, run-tests.sh, AGENTS.md, the spec mirror, SKILL.md, spec §12/§08) is correct to the line. The test suite is green at exactly 278 PASS / 1 SKIP / 0 FAIL as claimed. The now-shipped `claude-workflow` 0029 (and its test-fixtures/0029 directory, 8 fixtures + `common-verify.sh`) is a **massive de-risking asset** — it's no longer "an approved design" but a working, TDD'd, empirically-validated-across-6-repos reference implementation that `codex-workflow` can port mechanics from almost directly, including the specific awk idiom needed to correctly implement D-24's strip boundary (which, read literally, has a latent bug the sibling repo already hit and fixed: it must swallow the block's own `## ` heading before searching for the terminating `## `, or a naive implementation terminates immediately).

**Primary recommendation:** Before planning proceeds, take the invariant correction (ANCHOR-05 wording, D-21 rationale, D-24's strip terminator) back to the user per the framework's "surface, don't silently fix" rule — then plan using `claude-workflow`'s shipped 0029 as the primary mechanics reference (superseding the design doc, which is now merely the rationale trail behind it) alongside CONTEXT.md's locked policy decisions, which otherwise stand unchanged.

## Architectural Responsibility Map

This phase has no browser/frontend/API tiers — it is entirely repo-tooling / build-time infrastructure. Mapping onto the nearest applicable tiers:

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Anchor rule (where §11 lands in AGENTS.md) | Migration script (build-time) | Setup skill (SETUP-01 records, does not duplicate) | The anchor rule is pure text-transformation logic executed once per project by the migration runner; setup has no independent copy (D-43) so there is only one tier that owns it |
| Region predicate (in-region vs not) | Migration script (build-time) | — | Evaluated once, at migration-apply time, against the file on disk |
| Fixture verification | Test harness (`run-tests.sh`, local CI-equivalent) | — | `.github/workflows/ci.yml` is still a placeholder (CI-01, deferred); harness runs locally only |
| Version-state recording | Filesystem (`.codex/workflow-version.txt`) + `SKILL.md` frontmatter | — | Two files, one semantic fact — the version-coupling drift test enforces they agree |
| ADR / CHANGELOG | Documentation (repo root) | — | No runtime tier; purely a decision-record artifact |

## User Constraints (from CONTEXT.md)

<user_constraints>

### Locked Decisions

D-21 through D-45, numbering continues from Phase 8's D-01..D-20. Full text preserved verbatim in `.planning/phases/09-region-aware-11-placement/09-CONTEXT.md`; key ones repeated here for planner convenience (see Conflicts section for the one correction needed):

- **D-21:** Insert immediately before the first line that is either a `## ` heading or a `<!-- gitnexus:start -->` marker — whichever comes first; EOF if neither. *(Rationale sentence — "so the structural invariant survives: the block is still always followed by a `## ` or EOF" — is FALSE; see Conflicts.)*
- **D-22:** Two rejected alternatives, both recorded in the ADR: (1) "anchor before gitnexus:start if a region exists, else first `## `" — wrong because it drops §11 hundreds of lines down on a late-starting region; (2) "always immediately after the H1" — moves the block in every healthy repo for no benefit.
- **D-23:** §12's placement advisory is lower-case "should," not RFC 2119, not a conformance gate — state this precisely, don't overclaim.
- **D-24:** Structural strip boundary: provenance → own `## ` heading → everything up to the next `/^## /` line, or EOF. *(Needs the gitnexus:start alternation added to the terminator — see Conflicts.)*
- **D-25:** Rejected — 0004's content-sentinel strip (runaway-strip hazard if the sentinel line ever changes).
- **D-26:** Strip blind — no verbatim assertion; a drifted-but-managed block is 0004's problem, not 0009's.
- **D-27:** Re-vendor from the mirror after stripping (unifies States B and C into one code path).
- **D-28:** Pre-flight must verify the mirror exists; a State-B move silently repairs a drifted block as a stated side effect.
- **D-29:** Provenance stays hardcoded `@0.4.0` — content version, not spec version. Do not bump.
- **D-30:** Three branches, no per-state special-casing: (1) heading w/o provenance → `exit 3`; (2) current provenance AND not-in-region → skip; (3) otherwise → strip-if-managed-exists + inject.
- **D-31:** MIGR-07 falls out of the idempotency predicate, not a special case.
- **D-32:** Region predicate fails closed: `in_region = (prov_line > start_line) AND (end_line == 0 OR prov_line < end_line)`. Unterminated `gitnexus:start` counts as in-region.
- **D-33:** Absent AGENTS.md → informational skip, Step 2 (version bump) still runs. Deliberate divergence from 0004's pre-flight abort.
- **D-34:** This repo's native idiom — `test_migration_0009` in `run-tests.sh`, six cases synthesized via `printf` into `$tmp`. Reject porting claude-workflow's per-fixture directories.
- **D-35:** Port the extractor, not the layout — adapt `common-verify.sh`'s fence-scoped awk.
- **D-36:** Carry the shape assertion (assert extracted block contains `gitnexus:start`) — the antidote to Phase 8's dead-by-construction defects.
- **D-37:** TEST-04 scope = `run-tests.sh:119` only (0001's inlined copy). 0008's `~:985` copy is explicitly deferred, not in scope.
- **D-38:** Honor the double-sided idempotency contract (non-zero before, zero after).
- **D-39:** `from_version: 0.6.0`, `to_version: 0.7.0`; pre-flight accepts both.
- **D-40:** Frontmatter follows 0008's shape; `applies_to` lists AGENTS.md, `skills/agentic-apps-workflow/SKILL.md`, `.codex/workflow-version.txt`.
- **D-41:** Step 2 bumps scaffolder version, Step 3 records `.codex/workflow-version.txt` (0004's 3-step shape).
- **D-42:** State the supported upgrade floor `0.6.0 → 0.7.0`, single hop, in prose. Do not widen it to paper over the multi-hop chain-selection defect.
- **D-43:** Setup has no independent §11 placement logic — verified, `0000-baseline.md:102` is a plain append and `agents-md-additions.md` has no §11.
- **D-44:** §08 conformance is satisfied by construction (replay, not snapshot) — no parity guard needed. SETUP-01 is record-the-fact, not build-a-guard.
- **D-45:** Record, don't fix, the caveat that a freshly scaffolded project can't walk the full chain to 0.7.0 in one invocation today (multi-hop defect, deferred).

### Claude's Discretion

- The exact awk implementation of D-21/D-24/D-32 (anchor alternation, structural strip, line-number region predicate) — mechanics, not policy. **Resolved below in `## Discretion Resolved`, using claude-workflow's now-shipped 0029 as the field-tested reference.**
- Plan/wave decomposition, subject to the two hard orderings in ROADMAP.md (validate-before-write; RED-before-GREEN).
- Whether the empirical validation (ANCHOR-03/04) is a throwaway script or a committed harness addition — evidence must be recorded either way. **Resolved below.**
- ADR number (next free in `docs/decisions/`) and its exact section shape. **Resolved: ADR-0010** (`docs/decisions/` currently runs 0001-0009; 0009 is the highest, taken by Phase 8's plan-review-gate ADR).

### Deferred Ideas (OUT OF SCOPE)

- De-inline 0008's Step-3 insert-awk copy (`run-tests.sh` ~:985).
- Investigate migrations 0002/0003's `from_version == to_version` (dead migrations, pre-existing).
- The update skill's multi-hop chain-selection defect (carried from Phase 8).
- `implements_spec` 0.4.0 → 0.5.0+ version-gap resolution.
- Native `~/.codex/hooks.json` `PreToolUse` enforcement (HOOK-01).
- Real CI (CI-01) — placeholder still echoes and exits 0.
- WR-03 — lexical-`..`-only symlink guard.
- Upstream note to claude-workflow that codex implemented from the design, not the code. **This deferred item is now partially moot / needs updating — see Open Questions: claude-workflow shipped code during this phase's own research window, so "codex implemented from the design, not the code" will no longer be true once this phase executes; the upstream note should instead observe that the two hosts converged within the same day.**

</user_constraints>

## Project Constraints (from CLAUDE.md)

- **GitNexus impact analysis is MANDATORY before editing any symbol.** `run-tests.sh` is indexed (the repo carries 681 symbols / 718 relationships). TEST-04's edit to `test_migration_0001` (removing the inline anchor copy, replacing with document-sourced extraction — D-37) **edits an existing function** and therefore requires `gitnexus_impact({target: "test_migration_0001", direction: "upstream"})` before that edit, per AGENTS.md/CLAUDE.md's "Always Do" rule. Adding new functions (`test_migration_0009`) is a new symbol, not an edit, so impact analysis is not required for its creation, but `gitnexus_detect_changes()` is still mandatory before committing any wave that touches `run-tests.sh`.
- **NEVER rename symbols with find-and-replace.** Not applicable here (no symbol renames in this phase's scope) — noted for completeness.
- **Feature branches + PRs to main; never commit to main** — already the working state (`feat/spec-11-region-aware-placement`).
- Migration markdown files themselves (`.md` with embedded fenced bash) are unlikely to be indexed as GitNexus "symbols" in the function/class/method sense — the impact-analysis mandate binds most concretely to `run-tests.sh`'s bash functions, not to the migration documents' prose+shell content.

## Claim Verification

Every verification target from the task, checked against live files on 2026-07-15.

| # | Claim | Status | Detail |
|---|-------|--------|--------|
| 1 | `migrations/0001-inject-spec-11-coding-discipline.md:91` naive anchor `/^## / && !done` | **CONFIRMED** | Line 91 is exactly `  /^## / && !done {` |
| 2 | `migrations/0004-revendor-spec-11.md:68-74` content-sentinel strip awk | **CONFIRMED** | Lines 68-74 are exactly the `inblk`/sentinel-matching awk described |
| 3 | `migrations/0004-revendor-spec-11.md:77` naive anchor | **CONFIRMED** | Line 77 is `  /^## / && !done {` |
| 4 | `migrations/0004-revendor-spec-11.md:44` pre-flight abort | **CONFIRMED** | Line 44 is `test -f AGENTS.md || { echo "AGENTS.md missing — run migrations 0000/0001 first"; exit 1; }` |
| 5 | `migrations/run-tests.sh:119` inlined §11 anchor copy TEST-04 retires | **CONFIRMED** | Line 119 is `/^## / && !done {` (inside the awk starting line 118), inside `test_migration_0001` |
| 6 | `migrations/run-tests.sh:110-135` synthesized-fixture idiom (printf into `$tmp`) | **PARTIAL DRIFT (cosmetic)** | The idiom is real and present in `test_migration_0001`, but the actual `printf … > "$tmp/…"` calls sit at lines 95, 101, 106 — just above the cited range. Lines 110-135 contain the `assert_check`/injection-byte-identity portion of the same function, not the printfs themselves. Functionally the citation is fine as "this function is the model," but a planner citing an exact line for a printf call should use 95/101/106. |
| 7 | `migrations/run-tests.sh:960-1000` 0008's extraction-non-empty-before-assert (T-08-23) | **CONFIRMED** | Lines 968-977 contain exactly: extraction into `secfile`, then "Extraction from the REAL template must be non-empty BEFORE the insert is asserted... (T-08-23)" with the PASS/FAIL branch |
| 8 | `migrations/run-tests.sh:32` version-coupling drift policy note | **MINOR DRIFT (off-by-one)** | The sentence "The drift POLICY (version coupling is a hard fail) stays in this consumer" completes on **line 33**, not 32. Line 32 is the preceding clause ("...run_drift_test. The"). The comment block spans lines 30-33; cite 30-33 or 33, not 32 alone. |
| 9 | `AGENTS.md` §11 heading L18, provenance L17, managed markers L15/L269, GitNexus region L271-313 | **CONFIRMED** | All five line numbers exact: L15 `<!-- BEGIN: agentic-apps-workflow sections… -->`, L17 provenance, L18 `## Coding Discipline (NON-NEGOTIABLE)`, L269 `<!-- END: … -->`, L271 `<!-- gitnexus:start -->`, L313 `<!-- gitnexus:end -->` |
| 10 | Spec mirror: 79 lines, exactly one `## ` at L1, four `### ` subsections | **CONFIRMED** | File is 79 lines; L1 is the only `## ` line; four `### ` headings at L6, L22, L40, L57 |
| 11 | `templates/agents-md-additions.md` contains NO §11 | **CONFIRMED** | Full file read: runs `## Development Workflow` → `## Pre-execution Gate — Plan Review (spec §02)`, no Coding Discipline section anywhere |
| 12 | `migrations/0000-baseline.md:102` plain `cat … >> AGENTS.md` append | **CONFIRMED** | Line 102 is exactly `cat "${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md" >> AGENTS.md` |
| 13 | `skills/setup-codex-agenticapps-workflow/SKILL.md:109` post-check asserts `0.1.0` | **CONFIRMED** | Line 109 is exactly `` - `.codex/workflow-version.txt` reads `0.1.0` `` |
| 14 | `agenticapps-workflow-core/spec/12-authoring-conventions.md:93-97` placement advisory is lower-case "should," not RFC 2119, not a conformance gate | **CONFIRMED** | L93 heading "Placement of behavior-critical prose (advisory)", L95-97: "This requirement is advisory, lower-case 'should.' It is not RFC 2119 and not a conformance gate, but host implementations are encouraged to honor it." L105-106 name §11 explicitly |
| 15 | `agenticapps-workflow-core/spec/08-migration-format.md:25-45` end-state normative, replay AND snapshot both conformant | **CONFIRMED (line range slightly wide but content correct)** | The replay/snapshot conformance statement is at L27-33; ADR-0013/0018 supersession note at L42-45. L138-146 additionally confirms fixtures are a SHOULD ("ship a fixture pair… for every migration that operates on existing files") not a MUST — worth noting for D-34's framing |
| 16 | `../claude-workflow/migrations/` — confirm 0029 does NOT exist | **DRIFTED — MAJOR.** | **0029 now EXISTS.** `migrations/0029-region-aware-spec-11-placement.md` (13:44), full `test-fixtures/0029/` with **8** fixture dirs + `common-setup.sh` + `common-verify.sh` (13:39), and `test_migration_0029` wired into `run-tests.sh` (13:08). This was accurate when CONTEXT.md closed (~13:42-43) but changed within roughly one minute after. See Conflicts and Discretion Resolved — this is the single highest-value finding of this research pass. |
| 17 | `../claude-workflow/migrations/test-fixtures/0029/common-verify.sh` fence extractor to adapt | **CONFIRMED, and richer than described.** | Present, ~123 lines. Extracts THREE blocks per fixture (Step 1 Idempotency, Apply, Rollback), each with its own shape assertion (`spec-source: agenticapps-workflow-core`, `gitnexus:start`, `spec-source: agenticapps-workflow-core` respectively) — D-35/D-36 described adapting one extraction+assertion; the shipped version has three, one per block actually exercised by a fixture. Recommend porting all three, not just Apply's. |
| 18 | `../claude-workflow/docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` approved reference design | **CONFIRMED to exist, but now superseded by shipped code.** | Doc still says "Status: Approved (brainstorming → design approved 2026-07-15)" — that status line was never updated after 0029 shipped, but the doc's own body **already contains** the corrected invariant (see next row) — it is the design's *rationale trail*, and it is more current/correct than what CONTEXT.md carried forward from it. |
| 19 | CHANGELOG.md — confirm no "known issues" section exists | **CONFIRMED** | `grep -in "known issue" CHANGELOG.md` returns zero matches |
| 20 | `vendor/agenticapps-shared/migrations/lib/fixture-runner.sh` `extract_to()` is a git-show extractor, not a markdown-fence extractor | **CONFIRMED** | `extract_to(ref, path, out) -> 0 on git-show success, 1 otherwise` — confirmed by grep; it does not solve TEST-01 |
| 21 | `migrations/run-tests.sh` current pass count 278 PASS / 1 SKIP / 0 FAIL | **CONFIRMED** | Ran the full suite: `PASS: 278`, `SKIP: 1`, no FAIL line printed (harness omits the line at zero), exit code 0 |

### New finding not in the original verification list

**`claude-workflow`'s shipped `0029` design doc self-corrects the exact claim D-21/ANCHOR-05 make.** See `## Conflicts With Locked Decisions` — this is the load-bearing item.

## Conflicts With Locked Decisions

**One conflict.** It is real, dated, and independently confirmed by the sibling repo's own post-review correction on the same day this phase's CONTEXT.md was written. It must go back to the user, not be silently worked around.

### The invariant claim in D-21 is false, and ANCHOR-05 (a locked requirement, not discretion) is unsatisfiable as literally worded

**What's locked:**
- D-21: "...a one-alternation delta to the existing awk, **so the structural invariant survives: the block is still always followed by a `## ` or EOF**, which is what bounds the managed section for replace/rollback."
- ANCHOR-05 (REQUIREMENTS.md, ROADMAP success criterion 1): "The injected block remains followed by a `## ` heading or EOF, preserving the boundary that bounds the managed section for replace/rollback."

**Why it's false — derived directly from the phase's own MIGR-03 requirement:** In the gitnexus-led case (State B: region leads the file, e.g. `<!-- gitnexus:start -->` at line 1 before any `## `), D-21's own anchor rule inserts the block **immediately before `<!-- gitnexus:start -->`** — because that marker is "the first line that is either a `## ` heading or a `<!-- gitnexus:start -->` marker," and it comes before any `## `. After insertion, the line immediately following the injected block is the `<!-- gitnexus:start -->` marker itself — **not** a `## ` heading, **not** EOF. This is not an edge case; it is the exact scenario MIGR-03 exists to fix ("a §11 block inside a gitnexus region is moved above the region"). The invariant as stated in ANCHOR-05 is violated by construction on every State-B repair.

**Independent confirmation, dated the same day:** `claude-workflow`'s shipped `docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` (the very design this phase propagates) contains a section literally titled *"The invariant this breaks (corrected 2026-07-15 after Task 2 review)"*:

> "An earlier draft of this spec claimed the rule was 'a one-alternation delta, so 0014's structural reasoning survives: the block is still always followed by a `## ` line or EOF.' **That claim was false**, and it was load-bearing. ... Running Step 1's Rollback on a healed region-led file eats the start marker and the region's real content, leaving an orphaned `<!-- gitnexus:end -->` — an unpaired region. Verified empirically. The invariant is not preserved; it is **replaced**: *The block is always followed by a `## ` line, an anchored `<!-- gitnexus:start -->` marker, or EOF.*"

`codex-workflow`'s CONTEXT.md carried forward the **pre-correction** wording of the exact same claim. This is a timing accident (the correction landed in the sibling repo the same day, possibly after this repo's researcher/discuss-phase agent last read the design doc), not a reasoning error by the discuss-phase agent — but it means one locked decision and one locked success criterion currently assert something demonstrably false about the system being built.

**Downstream consequences if not corrected before planning:**
1. **D-24's strip terminator, read literally ("everything up to the next `/^## /` line, or EOF"), will runaway-strip a healed region-led file on re-run (MIGR-06 idempotency) or on Rollback.** If Step 1's strip pass only recognizes `/^## /` as a terminator, and the block was previously anchored right before `<!-- gitnexus:start -->` (State B already healed), the strip will skip straight past the marker and consume the entire GitNexus region — plus everything else — until it hits whatever `## ` heading comes *after* the region, or EOF. This is the exact "runaway-strip hazard" class D-25 rejected 0004's content-sentinel approach for — but it resurfaces here, in the *structural* boundary D-24 chose specifically to avoid it, because the structural boundary itself needs the same alternation the anchor rule needs and currently doesn't have it stated.
2. This is not hypothetical: it is the specific bug claude-workflow's own fixtures `07-prose-mention-not-a-region` and `08-rollback-region-led` were added, post-review, to catch. That review note reads: *"Fixtures 07 and 08 were added after the Task 2 review. They are the two gaps that let a green suite ship file-destroying bugs: no fixture covered Rollback at all, and none covered a file mentioning the marker in prose."*
3. ANCHOR-05 as currently worded cannot be honestly marked "satisfied" for State B once this is understood — success criterion 1 would need correcting alongside it.

**What does NOT need to change:** D-21's actual anchor *rule* (the alternation itself) is correct and matches the now-shipped, six-repo-validated `claude-workflow` implementation exactly. Only the **rationale sentence** in D-21 and the **wording of ANCHOR-05** are wrong — the fix is a documentation/requirement correction plus one mechanics detail (the strip terminator needs the same alternation), not a redesign.

**Recommendation to bring back to the user (not applied unilaterally by this research):**
- Reword ANCHOR-05 to: "The injected block remains followed by a `## ` heading, an anchored `<!-- gitnexus:start -->` marker, or EOF — preserving the boundary that bounds the managed section for replace/rollback."
- Reword D-21's rationale clause from "so the structural invariant survives" to "this widens 0001/0004's structural invariant rather than preserving it unchanged — see corrected invariant."
- Extend D-24's strip terminator to also match `/^<!-- gitnexus:start -->$/` (anchored), not just `/^## /`, so the strip pass and the anchor rule share the same terminator set — exactly mirroring the fix `claude-workflow` already shipped.
- Whether to also add the two extra fixture cases claude-workflow found necessary (`07-prose-mention-not-a-region`, `08-rollback-region-led`) beyond TEST-03's locked six is a real open question — see Open Questions and Discretion Resolved. This research recommends yes for prose-mention coverage (folds naturally into an existing fixture as a shape assertion, near-zero cost) and recommends a scoping decision for rollback coverage depending on what Rollback shape 0009 chooses (see Discretion Resolved: if Rollback = plain `git checkout AGENTS.md`, the rollback-eats-region bug class is structurally impossible and fixture 08's equivalent isn't needed).

No other locked decision conflicts with verified fact.

## Standard Stack

Not applicable in the conventional library-dependency sense — this phase ships no new package dependencies. The "stack" is the existing shell/awk/markdown migration format this repo already uses.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|---------------|
| `awk` (POSIX/BSD or GNU, whichever ships with the target shell) | n/a | Anchor insertion, structural strip, region predicate | Already the sole mechanism 0001/0004 use; no reason to introduce a new dependency for text surgery this small |
| `bash` / `sh` per migration's own fenced-block shebang convention | n/a | Migration Apply/Rollback/pre-flight blocks | Matches 0001/0004/0008's existing shape |
| `git` | already required (`test -d .git`) | Atomic commit per migration, `git checkout` rollback fallback | Existing repo convention |

### Package Legitimacy Audit

**Not applicable.** This phase installs no external packages (no `npm install`, `pip install`, etc.). Skipping the Package Legitimacy Gate per its own scope condition.

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────────────────┐
                    │   migrations/0009-*.md       │
                    │   (source of truth: the      │
                    │    migration document)        │
                    └───────────────┬───────────────┘
                                     │ awk fence-extraction (TEST-01)
                                     │ (D-35: adapt claude-workflow's
                                     │  common-verify.sh idiom)
                    ┌────────────────▼────────────────┐
                    │  run-tests.sh :: test_migration_0009 │
                    │  6 synthesized fixtures (D-34)   │
                    │  RED (pre-0009) → GREEN (post)   │──── TEST-02
                    └────────────────┬──────────────────┘
                                     │ eval'd extracted Apply block
                                     │ against printf-synthesized AGENTS.md
                    ┌────────────────▼────────────────┐
                    │   Pre-flight (D-28: mirror exists)│
                    │   Step 1: state-machine apply     │
                    │     A → skip (D-30.2)             │
                    │     B → strip + reinject (D-30.3) │
                    │     C → inject (D-30.3)           │
                    │     D → exit 3 (D-30.1)           │
                    │   Step 2: bump SKILL.md version    │
                    │   Step 3: record workflow-version  │
                    └────────────────┬──────────────────┘
                                     │
                    ┌────────────────▼──────────────────┐
                    │  Real project AGENTS.md (validated  │
                    │  empirically pre-write: ANCHOR-03/04)│
                    └─────────────────────────────────────┘
```

### Recommended Project Structure

No new directories. Files touched/added:
```
migrations/
├── 0009-spec-11-region-aware-placement.md   # NEW — the migration itself
└── run-tests.sh                              # MODIFIED — new test_migration_0009 fn;
                                                #   :119's inline copy converted (D-37)
docs/decisions/
└── 0010-*.md                                  # NEW — ADR (see Discretion Resolved)
CHANGELOG.md                                   # MODIFIED — DOC-02
skills/agentic-apps-workflow/SKILL.md          # MODIFIED — version 0.6.0 → 0.7.0 (D-41)
```

### Pattern: fence-scoped extraction with shape assertion (D-35/D-36, TEST-01)

The load-bearing pattern for TEST-01/TEST-04. Adapted directly from claude-workflow's now-shipped `common-verify.sh` (not merely the design doc — the actual working code):

```bash
# Source: ../claude-workflow/migrations/test-fixtures/0029/common-verify.sh (shipped 2026-07-15)
extract_0009_step1_apply() {
  awk '
    /^### Step 1/ { in1=1; next }
    /^### Step 2/ { in1=0 }
    in1 && /^\*\*Apply:\*\*/ { want=1; next }
    want && /^```/ { inb=1; want=0; next }
    inb && /^```$/ { exit }
    inb { print }
  ' "$MIGRATION_0009"
}

STEP1_APPLY="$(extract_0009_step1_apply)"
[ -n "$STEP1_APPLY" ] || { echo "PRE: could not extract Step 1 Apply block"; exit 1; }

# D-36: non-empty is not the same as correct — assert the extracted block
# actually carries the region-aware anchor logic, not e.g. the Rollback fence.
case "$STEP1_APPLY" in
  *'gitnexus:start'*) ;;
  *) echo "PRE: extracted block carries no gitnexus:start anchor — extractor drifted"
     printf '%s\n' "$STEP1_APPLY" | sed 's/^/       /'
     exit 1 ;;
esac
```

The shipped version extracts and shape-asserts **three** blocks per Step (Idempotency check, Apply, Rollback), each with its own `case` guard tuned to what that block should contain. Recommend porting the same three-block pattern, not just Apply, since Idempotency-check and Rollback are exactly as capable of silently drifting to the wrong fence as Apply is.

### Anti-Patterns to Avoid

- **Strip terminator matching only `/^## /`:** see Conflicts — this is a live, dated, cross-repo-confirmed bug class, not a hypothetical.
- **Unanchored `gitnexus:start` regex** (`/gitnexus:start/` instead of `/^<!-- gitnexus:start -->$/`): fires on prose mentions of the marker (this exact document — the migration `.md` file itself — will contain the literal string `gitnexus:start` in prose multiple times, per D-22/D-32's own text; PROMPT-0009 and CONTEXT.md already do). An unanchored match against a project's AGENTS.md that ever quotes or discusses the marker string in a comment would misjudge a healthy file as in-region. `claude-workflow`'s fixture `07-prose-mention-not-a-region` exists specifically because this bit them.
- **Verbatim assertion on strip** (rejected as D-26; do not reintroduce it) — the structural boundary is bounded by construction; adding a diff-gate against the mirror would make a drifted-but-managed block refuse to be placed, conflating 0004's problem with 0009's.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Fence-scoped extraction of a migration's own shell blocks | A bespoke sed/awk one-off per fixture | Port claude-workflow's `common-verify.sh` three-block extractor pattern (Idempotency/Apply/Rollback, each shape-asserted) | Already field-tested against the identical migration-document format (same frontmatter shape, same `### Step N` / `**Apply:**` markdown convention this repo also uses) |
| Region-aware anchor + strip awk | A fresh design from CONTEXT.md's D-21/D-24/D-32 prose alone | claude-workflow's shipped `0029` Step 1 Apply/Rollback awk, adapted for `AGENTS.md` path and the mirror path this host uses | It is now working code, not merely an approved design — it already carries the corrected terminator alternation this repo's D-24 is currently missing |

**Key insight:** This phase looked, at CONTEXT.md-authoring time, like "propagate an approved design, no working implementation to diff against." That premise flipped mid-research. The planner should treat `claude-workflow`'s `0029` + its 8 fixtures as the primary mechanics reference, and CONTEXT.md's D-21..D-45 as the *policy* layer (which cases to handle, what to skip, what to defer) — both should now agree, once the one correction above lands.

## Common Pitfalls

### Pitfall 1: Strip terminator narrower than the anchor's insertion terminator

**What goes wrong:** Idempotent re-run (MIGR-06) or Rollback on an already-healed, region-led AGENTS.md deletes the entire GitNexus region (and everything up to the next `## ` or EOF) instead of just the managed §11 block.
**Why it happens:** The anchor rule was widened (D-21: `## ` OR `gitnexus:start`) but the strip/terminator logic wasn't widened to match, because D-24's prose only mentions `## `.
**How to avoid:** Every awk terminator condition in Step 1 (Apply's strip pass) must recognize the exact same set the anchor rule recognizes: `/^## /` OR `/^<!-- gitnexus:start -->$/` (anchored) OR EOF.
**Warning signs:** A fixture that heals a gitnexus-led file, then re-runs the migration (or its rollback) and finds the region's own content missing from the output.

### Pitfall 2: Unanchored gitnexus marker regex

**What goes wrong:** A prose mention of `<!-- gitnexus:start -->` (e.g., in a comment explaining the anchor rule — which this very migration document will contain) gets misjudged as a real region boundary.
**Why it happens:** `grep`/`awk` pattern written as a substring match instead of `^...$`-anchored.
**How to avoid:** Anchor both `gitnexus:start` and `gitnexus:end` regexes with `^` and `$`.
**Warning signs:** A fixture where the migration document's own guidance text (or a project's own comment about GitNexus) sits near the top of a test AGENTS.md.

### Pitfall 3: Dead-by-construction fixture assertions (Phase 8's recurring defect, D-36's antidote)

**What goes wrong:** An assertion that can structurally never match — passes vacuously, reads as coverage, catches nothing. Hit three times in Phase 8 (08-05 twice, 08-09 by the plan-checker).
**Why it happens:** Assertion written against the wrong extraction, or against a pattern the code path never produces.
**How to avoid:** For every assertion added in this phase (fixture pass/fail, extraction non-empty, shape checks), prove it *can* fail — run it once against a deliberately wrong input (the naive-anchor pre-0009 state, or a synthetic wrong-shape extraction) and confirm it fails there before trusting it to pass elsewhere. This is exactly what TEST-02 (RED before GREEN) operationalizes at the suite level; D-36 operationalizes it at the individual-assertion level.
**Warning signs:** An assertion that has never been observed failing in this codebase's history.

## Code Examples

### The corrected structural strip terminator (recommended mechanics for D-24)

```bash
# Source: adapted from ../claude-workflow/migrations/0029-region-aware-spec-11-placement.md
# Step 1 Apply strip pass (lines 166-184 of the shipped migration), retargeted
# to this host's AGENTS.md / mirror paths. Note the swallowed_own_h2 guard:
# the block's OWN `## Coding Discipline (NON-NEGOTIABLE)` heading must be
# swallowed explicitly, or a naive "stop at the next /^## /" terminates on
# the block's own heading instead of the block after it.
awk '
  BEGIN { in_block = 0; swallowed_own_h2 = 0 }
  /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ {
    in_block = 1; next
  }
  in_block && !swallowed_own_h2 && /^## Coding Discipline \(NON-NEGOTIABLE\)$/ {
    swallowed_own_h2 = 1; next
  }
  in_block && swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/) {
    in_block = 0; swallowed_own_h2 = 0; print; next
  }
  in_block { next }
  !in_block { print }
' AGENTS.md > AGENTS.md.0009.strip && [ -s AGENTS.md.0009.strip ]
```

Note the `[ -s ... ]` non-empty guard after the strip — claude-workflow's shipped version requires this before allowing the stripped result to replace the file at all, aborting with `exit 3` and leaving `AGENTS.md` untouched otherwise. This is the same "extraction non-empty before anything downstream trusts it" discipline as T-08-23 (already a pattern this repo's own `run-tests.sh:968-977` uses for template extraction) — apply it symmetrically to the migration's own file-surgery output, not just to fixture-harness extraction.

### The region-aware anchor insert (D-21, unchanged from CONTEXT.md, confirmed correct)

```bash
# Source: adapted from claude-workflow 0029 Step 1 Apply, insert pass
awk -v prov="$PROV" -v mirror="$MIRROR" '
  BEGIN { inserted = 0 }
  !inserted && (/^## / || /^<!-- gitnexus:start -->$/) {
    print prov
    while ((getline line < mirror) > 0) print line
    close(mirror)
    print ""
    inserted = 1
    print
    next
  }
  { print }
  END {
    if (!inserted) {
      print ""
      print prov
      while ((getline line < mirror) > 0) print line
      close(mirror)
    }
  }
' AGENTS.md.0009.strip > AGENTS.md.0009.tmp && [ -s AGENTS.md.0009.tmp ] \
  && mv AGENTS.md.0009.tmp AGENTS.md
```

### Region predicate (D-32) — simpler equivalent actually shipped

CONTEXT.md's D-32 describes the predicate as line-number arithmetic (`prov_line > start_line AND (end_line == 0 OR prov_line < end_line)`), implying separate line-number extraction plus bash comparison. claude-workflow's shipped idempotency check computes the equivalent in one linear awk pass instead — simpler, and already field-tested:

```bash
# Source: ../claude-workflow/migrations/0029-region-aware-spec-11-placement.md Step 1 Idempotency check
[ -f AGENTS.md ] \
  && grep -q '<!-- spec-source: agenticapps-workflow-core@0\.4\.0 §11 -->' AGENTS.md \
  && ! awk '
       /^<!-- gitnexus:start -->$/ { r = 1; next }
       /^<!-- gitnexus:end -->$/   { r = 0; next }
       r && /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ { f = 1 }
       END { exit(f ? 0 : 1) }
     ' AGENTS.md
```

This single-pass state machine is fail-closed for the unterminated-region case by construction: if `gitnexus:end` never appears, `r` stays 1 for the rest of the file, so any provenance line after `gitnexus:start` is correctly flagged in-region all the way to EOF — the same outcome D-32's arithmetic formula specifies, reached without a separate line-number extraction step. Recommend this shape over the arithmetic formula: fewer moving parts, one linear scan, already validated.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|---------------|--------|
| Anchor before first `## ` heading only (0001/0004's naive anchor) | Anchor before first `## ` OR anchored `<!-- gitnexus:start -->`, whichever comes first | This migration (0009), mirroring claude-workflow's 0029 (shipped 2026-07-15) | Closes the latent block-destruction defect for any project whose instruction file leads with a GitNexus-managed region |
| "One-alternation delta preserves the structural invariant" | Invariant is *widened*, not preserved: block followed by `## `, anchored `gitnexus:start`, or EOF | Corrected in claude-workflow's design doc same-day (2026-07-15, "after Task 2 review") | Every strip/rollback terminator must carry the same alternation as the anchor, or it over-consumes on a healed region-led file |

**Deprecated/outdated:**
- The design doc's own "Status: Approved" header line is stale — it predates the doc's own in-body correction and the fact that 0029 has since shipped. Treat the doc's *body* (especially the "corrected 2026-07-15" section) as current; treat the header status line as informational only.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | claude-workflow's `0029` and its fixtures represent a stable, final shape (not itself mid-revision) | Discretion Resolved, Code Examples | If claude-workflow revises 0029 again before this phase executes, the ported mechanics could drift from the upstream source a second time — low risk given the file is dated today and already reflects a post-review correction, but worth a final re-check at plan-execution time, not just at research time |
| A2 | GitNexus indexes `run-tests.sh`'s bash functions as "symbols" subject to the CLAUDE.md impact-analysis mandate | Project Constraints | If GitNexus does not actually index shell functions (uncertain — the repo context states "0 execution flows" indexed), the impact-analysis step may be a no-op; low risk either way since running it is cheap and the instruction is unconditional ("MUST run impact analysis before editing any symbol") |

## Open Questions

1. **Should TEST-03's locked six fixtures be extended to include claude-workflow's two post-review additions (`07-prose-mention-not-a-region`, `08-rollback-region-led`)?**
   - What we know: claude-workflow added exactly these two after a review found the original six-case suite could still ship a file-destroying bug (unanchored marker match; untested Rollback on a region-led file).
   - What's unclear: TEST-03 as locked in REQUIREMENTS.md says "Six cases are covered: [exactly six named]" — this reads as prescriptive, not "at least six." Whether the user wants to lock in six (matching REQUIREMENTS.md literally) or expand to eight (matching the now-more-complete sibling suite) is a scope decision, not a research one.
   - Recommendation: bring this back with the Conflicts item above — folding in prose-mention coverage is near-zero cost (it can be a shape-assertion addition to an existing fixture rather than a new fixture file, given D-34's synthesized-fixture idiom). Rollback coverage depends on what shape 0009's Rollback takes — see next question.

2. **What shape should migration 0009's Rollback take — a custom awk strip (claude-workflow's shape) or the simpler `git checkout AGENTS.md` (0001/0004's shape)?**
   - What we know: 0004's Rollback is the one-liner `git checkout AGENTS.md`. 0001's is prose-described manual deletion or `git checkout`. Neither has an executable, fixture-tested Rollback awk. claude-workflow's 0029, by contrast, ships a full custom Rollback awk with the same strip-terminator-alternation requirement as Apply — and that Rollback awk is exactly what its fixture 08 exists to catch a bug in.
   - What's unclear: CONTEXT.md's D-24/D-30 don't specify Rollback's shape explicitly; D-41 says "0004's three-step shape" (which implies `git checkout`-style rollback, matching 0004, not claude-workflow's custom awk).
   - Recommendation: if 0009 follows 0004's precedent (`git checkout AGENTS.md` as Rollback — simplest, matches D-41's stated model, and this repo's own migration steps already carry that convention for AGENTS.md-touching migrations), the "Rollback eats the region" bug class is structurally impossible, because there is no custom Rollback awk to have that bug. This resolves Open Question 1's second half in favor of NOT needing an `08`-equivalent fixture. This is the simpler, lower-risk choice and this research recommends it, but it is the user's call since D-41 only says "3-step shape," not "rollback shape."

3. **Should the upstream note (deferred idea, CONTEXT.md) be revised now that the timing has changed?**
   - What we know: the original deferred note said "report that the source prompt's premise is stale... if claude-workflow ships 0029 differently from this design, the two hosts diverge." claude-workflow has now shipped, and it matches the design closely (with the one correction noted in Conflicts).
   - What's unclear: whether codex-workflow's PR/ADR should note the convergence explicitly (both hosts landed on the same fix within hours of each other, no divergence) rather than treating this as a still-open risk.
   - Recommendation: low-stakes, defer to the ADR-writing task — worth one sentence in ADR-0010 noting the timing rather than a new deferred-idea entry.

## Environment Availability

Skip condition met for the conventional external-service sense (no databases, no network services this phase depends on), but the phase does depend on sibling-repo state as a research/reference input:

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `awk` | All migration text-surgery | ✓ | system awk (verified via successful `awk` invocations during this research) | — |
| `git` | Atomicity contract, `git checkout` rollback | ✓ | repo is a git working tree (confirmed via `git status` in session context) | — |
| `../claude-workflow` repo checked out as sibling | Reference mechanics (D-35, this research's primary source) | ✓ | Present at `/Users/donald/Sourcecode/agenticapps/claude-workflow`, migration 0029 present and current | If absent in a future execution environment, fall back to the design doc alone (less current, missing the post-review correction) |
| `vendor/agenticapps-shared` submodule | `run-tests.sh` harness primitives | ✓ | Present; `run-tests.sh` ran successfully (278 PASS) | — |

**Missing dependencies with no fallback:** none.

## Validation Architecture

### Observable signals and sampling rate

This phase's correctness lives almost entirely in text-transformation logic (awk over markdown/HTML-comment-delimited regions), not in application behavior — so the primary observable signal is **fixture pass/fail against synthesized AGENTS.md shapes**, sampled at two rates:

- **Per task commit (fast, seconds):** run the single new test function in isolation — `migrations/run-tests.sh 0009` (the harness supports filtering by migration ID per its own usage comment). This should be the sampling rate for every task inside the plan's execution waves that touches the migration document or the fixture function.
- **Per wave merge / phase gate (full suite, still fast — this harness is local shell, not a build):** `migrations/run-tests.sh` with no filter — the full 278+ assertions plus the new ~6-9 fixture assertions for 0009, expect FAIL=0.
- There is no slower/CI-gate rate available yet: CI-01 (real CI running this harness) is explicitly deferred and the placeholder still exits 0 unconditionally. This phase, like v0.6.0, merges on a local green only. This is a known, accepted gap — not something to silently fix in scope, but worth stating plainly so the plan doesn't assume CI will catch a regression it currently cannot.

### The dead-by-construction hazard (D-36's antidote), and how to prove each assertion in this phase can fail

Phase 8 shipped two assertions that could never match (08-05, twice) plus a third caught only by the plan-checker (08-09) — all "passed" and read as coverage while testing nothing. D-36 states the antidote in one line: *"Non-empty is not the same as correct."* Concretely, for **every** assertion introduced in this phase:

1. **Extraction assertions (TEST-01/TEST-04):** before trusting `extract_0009_step1_apply` (or the idempotency/rollback equivalents) to gate a fixture, run it once against a deliberately wrong migration-document shape (e.g., temporarily point `MIGRATION_0009` at 0001's document, or a fixture markdown missing the `### Step 1` heading) and confirm the shape assertion (`case ... *'gitnexus:start'*` etc.) **fails loudly**, not silently returns empty-but-unchecked. This is exactly claude-workflow's shipped pattern (three separate `case` guards, one per extracted block) — port the guards, and additionally exercise each guard's failure branch once during implementation (not necessarily kept as a permanent fixture, but demonstrated and noted in the plan's evidence).
2. **The RED requirement (TEST-02) is this hazard's suite-level instance:** the fixture suite MUST fail against the current naive anchor (`/^## / && !done`) before 0009 exists. Concretely: write `test_migration_0009` and its fixtures against a migration document that doesn't exist yet (or against 0001's naive anchor copy as a stand-in), observe FAIL, *then* author 0009's actual anchor logic and watch the same fixtures turn GREEN. Recording this transition (a `test(RED)` commit before `feat(GREEN)`, matching claude-workflow's own verification-evidence convention: "`test(RED)` commit with fixtures failing against the naive anchor, then `feat(GREEN)`") is the auditable evidence this happened, not merely an asserted claim.
3. **Structural strip terminator (post-Conflicts-resolution):** once the strip terminator gains the `gitnexus:start` alternation, prove a fixture where the OLD (unwidened) terminator would have failed — i.e., a State-B re-run (MIGR-06 idempotency on an already-healed, region-led file) — actually exercises the widened code path and produces a byte-correct result with the region content intact. This is the single most important assertion in the whole phase, because it is the one CONTEXT.md's current wording would not have caught (see Conflicts).

### The double-sided idempotency contract (D-38)

Per `migrations/test-fixtures/README.md`'s Contract section (verified): for each of 0009's steps, the fixture suite must assert:
- The step's idempotency check returns **non-zero** against the before-state (not yet applied → apply).
- The step's idempotency check returns **zero** against the after-state (already applied → skip).

Concretely for Step 1's region-aware idempotency check specifically, this means asserting it in **all four states**, not just two: State A (non-zero-before/zero-after doesn't directly apply the same way since A is already "after" — assert it returns zero on a correctly-anchored, current-provenance fixture), State B (assert it returns **non-zero** even though provenance is present — because the block is in-region — this is the "provenance alone must not short-circuit the heal" conjunction the design doc calls "the whole point"), State C (non-zero, no provenance at all), State D (the conflict pre-flight, not the idempotency check, gates this one — separately asserted).

### How ANCHOR-03/04 empirical replay evidence is captured (resolved in Discretion Resolved below)

Recommendation: a **committed** (not throwaway) small validation script or a documented one-shot `run-tests.sh`-adjacent invocation, with its output captured into the plan's evidence trail (e.g., pasted into the ADR or a `09-VALIDATION-EVIDENCE.md` / commit message) — see Discretion Resolved for the concrete mechanism and why committed beats throwaway here.

## Security Domain

`security_enforcement` is absent from `.planning/config.json` → treat as enabled per the default. This phase is pure repo-tooling with no auth/DB/network surface, so most ASVS categories are not applicable — documented as such rather than silently omitted.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | Marginally yes | The migration's awk/sed operate on a file path (`AGENTS.md`) and a mirror path built from `${CODEX_HOME:-$HOME/.codex}` — both are fixed, non-user-supplied paths in the migration's own logic (no `--file` CLI argument in this migration's own scope, unlike `check-plan-review.sh`'s WR-03 symlink concern, which is out of scope here). No externally-controlled input reaches the awk/sed commands. |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----------------------|
| Temp-file race / partial-write corrupting `AGENTS.md` | Tampering (self-inflicted, not adversarial) | Existing convention already used by 0001/0004/0009's own drafted mechanics: write to a `.tmp` file, verify non-empty (`[ -s ... ]`), then `mv` atomically over the original — never redirect awk's output directly onto the file being read |
| Overly permissive glob/eval of extracted shell in the test harness (`eval "$STEP1_APPLY"`) | Tampering / Elevation of Privilege (only if the migration document itself were attacker-controlled) | Not a realistic threat surface here — the migration document is repo-committed, reviewed content, not user input; `eval` of extracted trusted-repo content is the same pattern this repo's own `run-tests.sh` already uses elsewhere (e.g., `assert_check`) |

No new threat surface is introduced by this phase; it is a straightforward extension of an existing, already-audited pattern (0001/0004/0008 all do the same class of file surgery).

## Discretion Resolved

Concrete recommendations for each item CONTEXT.md explicitly left to Claude's discretion.

### 1. Exact awk implementation (D-21 anchor alternation, D-24 structural strip, D-32 region predicate)

**Recommendation: port claude-workflow's shipped `0029` mechanics near-verbatim, retargeted to this host's paths, with the D-24 correction folded in.** See `## Code Examples` above for the three concrete blocks (strip-with-swallowed-own-heading, region-aware insert, single-pass region predicate). Rationale: these are no longer merely "an approved design" but working code, validated across six real repos in the sibling host, and already carrying a post-review fix for exactly the bug class D-24 is currently missing. Re-deriving this from CONTEXT.md's prose alone risks reproducing the same invariant mistake the sibling repo already made and fixed.

### 2. Whether ANCHOR-03/04's empirical validation is a throwaway script or a committed harness addition

**Recommendation: committed, not throwaway — but small.** Concretely: a short shell script (or a documented one-off block inside the plan's Wave 0 setup) that:
1. Takes this host's real `AGENTS.md` (or a copy of it) plus a synthetic gitnexus-led variant (constructed by moving the region to line 1, matching the "healthy" and "gitnexus-led" cases this project itself embodies).
2. Strips any existing §11 block using the candidate strip logic.
3. Re-runs the candidate anchor rule.
4. Asserts zero churn (byte-identical result) on the healthy case, and "anchored above the region" on the gitnexus-led case.

**Why committed over throwaway:** success criterion 1 explicitly requires this "has been validated empirically... before migration 0009 is written" to be **demonstrable**, not asserted — a throwaway script's output, once discarded, degrades back into an assertion the moment the session ends. A committed script (even a small one-off under e.g. `migrations/validate-0009-anchor.sh`, deleted or kept post-merge per plan preference) plus its captured output (pasted into the ADR, or into a `test(RED)`-adjacent commit message) gives the same evidentiary trail claude-workflow's own migration document points to as its precedent ("Reproduced end-to-end... Verified empirically, not reasoned about" — each claim in that design doc is backed by a described repro, not just an assertion). Recommend: write the script, run it, capture output into the ADR's "Validated" section, and it is the planner's call whether the script itself survives past the phase (a throwaway script with committed *evidence* satisfies the requirement even if the script itself doesn't ship).

### 3. ADR number and section shape

**Recommendation: ADR-0010** (`docs/decisions/` currently has 0001-0009; 0009 is Phase 8's plan-review-gate ADR, the highest existing number). Section shape should mirror ADR-0009's own structure (the most recent, GSD-native precedent in this repo) — decisions, rejected alternatives with reasoning, accepted limitations — per CONTEXT.md's own "Specific Ideas" guidance. Must include: both rejected anchor alternatives (D-22), the corrected invariant (post-Conflicts-resolution wording, not the original D-21 sentence), and the drift-repair side effect (D-28.2) as a stated consequence.

### 4. Whether to extend TEST-03 beyond six fixtures, and Rollback's shape (folded in from Open Questions, since both require a concrete recommendation)

**Recommendation:** keep Rollback simple — `git checkout AGENTS.md`, matching 0004's precedent and D-41's "3-step shape" framing — which makes the rollback-eats-region bug class structurally unreachable and removes the need for an `08`-equivalent fixture. For the six locked TEST-03 cases, fold an unanchored-marker regression check into `03-healthy-noop` or a lightweight addition rather than a full 7th fixture directory (this repo's synthesized-printf idiom, D-34, makes this cheap — a 7th `printf`-built case costs a few lines, not a new directory tree the way it would in claude-workflow's per-fixture-directory layout). Both of these are recommendations for the user to confirm alongside the Conflicts item, not applied unilaterally.

## Sources

### Primary (HIGH confidence)
- `/Users/donald/Sourcecode/agenticapps/codex-workflow/migrations/0001-inject-spec-11-coding-discipline.md` — read in full
- `/Users/donald/Sourcecode/agenticapps/codex-workflow/migrations/0004-revendor-spec-11.md` — read in full
- `/Users/donald/Sourcecode/agenticapps/codex-workflow/AGENTS.md` — read in full
- `/Users/donald/Sourcecode/agenticapps/codex-workflow/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md` — read in full
- `/Users/donald/Sourcecode/agenticapps/codex-workflow/migrations/run-tests.sh` — read relevant sections (1-140, 955-1005, 1827-1886), and executed (278 PASS / 1 SKIP / 0 FAIL, exit 0)
- `/Users/donald/Sourcecode/agenticapps/codex-workflow/migrations/0000-baseline.md`, `skills/setup-codex-agenticapps-workflow/SKILL.md`, `templates/agents-md-additions.md` — read relevant sections
- `/Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/spec/12-authoring-conventions.md`, `spec/08-migration-format.md` — read relevant sections
- `/Users/donald/Sourcecode/agenticapps/claude-workflow/migrations/0029-region-aware-spec-11-placement.md` — read in full (shipped code, not design doc)
- `/Users/donald/Sourcecode/agenticapps/claude-workflow/migrations/test-fixtures/0029/common-verify.sh`, `07-prose-mention-not-a-region/setup.sh` — read in full
- `/Users/donald/Sourcecode/agenticapps/claude-workflow/docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` — read (lines 1-245)
- `migrations/test-fixtures/README.md`, `migrations/README.md` — read/grepped for contract sections
- `.planning/config.json`, `.planning/config.codex.json` — read

### Secondary (MEDIUM confidence)
- `/Users/donald/Sourcecode/agenticapps/claude-workflow/docs/superpowers/plans/2026-07-15-migration-0029-region-aware-spec-11-placement.md` — grepped for `anchor-parity` references, not read in full

### Tertiary (LOW confidence)
- None — all findings in this research were verified directly against live repository files.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, existing awk/bash/git convention, directly verified
- Architecture: HIGH — mechanics ported from now-shipped, six-repo-validated sibling code
- Pitfalls: HIGH — the primary pitfall (strip-terminator alternation) is independently confirmed by a dated, same-day correction in the source design, not inferred
- Policy decisions (D-21..D-45 as a whole): MEDIUM-HIGH — 24 of 25 verified sound; one (D-21's rationale / ANCHOR-05's wording) requires a correction that must go back to the user before being locked into a plan

**Research date:** 2026-07-15
**Valid until:** Short — recommend re-verifying `claude-workflow`'s `0029` state (and this repo's own `run-tests.sh` pass count) immediately before plan execution begins, given how much changed within roughly one hour during this research session alone. 7 days is a generous upper bound for a repo moving this fast; treat 24-48 hours as the more realistic freshness window for the cross-repo reference specifically.
