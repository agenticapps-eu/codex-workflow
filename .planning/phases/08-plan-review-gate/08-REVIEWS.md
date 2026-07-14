---
phase: 8
round: 2
reviewers: [gemini, codex, opencode]
reviewed_at: 2026-07-14T17:57:00Z
plans_reviewed: [08-01-PLAN.md, 08-02-PLAN.md, 08-03-PLAN.md, 08-04-PLAN.md, 08-05-PLAN.md, 08-06-PLAN.md]
supersedes: round 1 (2026-07-14T12:46:46Z, commit 765999b — recoverable from git history)
---

# Cross-AI Plan Review — Phase 8: Plan-Review Gate (Round 2)

This is the **second** review round. Round 1 (12:46Z) reviewed five plans; the
plans were then revised in response (commit ab1f164) and 08-05 was split into
08-05/08-06 for context budget (commit 52725db). This round reviews all six
plans as they now stand.

Reviewers were given identical context — README, AGENTS.md, ROADMAP, 08-CONTEXT,
08-DISCUSSION-LOG, 08-PATTERNS, and all six PLAN.md files — and ran independently
without seeing each other's output. They were told a prior round had occurred and
instructed to judge the plans on their current merits rather than assume earlier
feedback was ignored. `claude` was skipped for independence: this review was
orchestrated from Claude Code. `coderabbit`, `qwen`, and `cursor` are not
installed; no local model server was reachable.

**Reviewer provenance:**

| Reviewer | CLI | Model | Notes |
|---|---|---|---|
| Gemini | `gemini -p -` | CLI default | Trailing SessionEnd hook logs stripped from stdout |
| Codex | `codex exec --skip-git-repo-check -` | `gpt-5.6-sol`, reasoning effort xhigh | Ran read-only sandboxed |
| OpenCode | `opencode run -` | `glm-5.2` (via GitHub Copilot) | — |

**Risk verdicts:** Gemini **LOW** · OpenCode **MEDIUM** · Codex **HIGH**

---

## Gemini Review

## Summary

This is an exceptionally thorough and mature set of implementation plans. They have been substantially improved in response to the previous review, systematically closing every identified high-risk gap. The plans now demonstrate a deep commitment to correctness, security, and testability through a rigorous TDD approach. The level of detail, from correcting subtle defects in the upstream reference implementation to honestly documenting the gate's own limitations (the "bootstrap paradox" and agent-mediated enforcement), is exemplary. The addition of a producer-verifier contract test and robust path-handling logic transforms the most critical components from plausible designs into verifiable contracts. The phase is well-decomposed into logical waves, dependencies are clear, and the threat models are specific and effectively mitigated.

## Strengths

-   **Systematic Risk Mitigation:** Every HIGH-severity concern from the previous review has been addressed with a specific, robust, and testable solution. This includes the verifier's root self-location (T-08-28), the corrected `jq` merge logic (T-08-22), the fail-closed handling of non-regular artifacts (T-08-09), and the honest rewording of the enforcement claim (T-08-33).
-   **Rigorous TDD & Contract Testing:** The plans enforce a strict RED/GREEN workflow for all new code. Crucially, the addition of `test_check_plan_review_contract` in plan `08-02` creates a round-trip test that proves the producer's output is valid input for the verifier, mechanically closing the highest-risk integration gap.
-   **Proactive Defect Correction:** The plans don't just port the reference implementation; they improve it. The discovery and correction of three distinct defects in the reference resolver—evidenced by a runnable `awk` proof in plan `08-01`—is a standout example of deep analysis.
-   **Intellectual Honesty:** The plans consistently and honestly confront their own limitations. The "bootstrap paradox" is documented in every relevant plan's verification section, preventing the team from claiming a false dogfood success. Similarly, the agent-mediated nature of the gate is recorded in the `ROADMAP`, `CHANGELOG`, and `ADR-0009`, aligning the project's claims with its actual capabilities.
-   **Security as a First-Class Concern:** The threat models are specific to each plan and have clearly driven design. Key security controls include the producer's affirmative consent gate for data egress (T-08-12), the verifier's path containment checks (T-08-01), audited escape hatches (T-08-07), and the explicit decision to have the ritual invoke a fixed verifier path rather than one from a target repo's config (T-08-17).

## Concerns

-   **(LOW) Upstream Defect Reporting is Not Tasked.** The plans and ADR are meticulous in identifying and documenting several defects in upstream dependencies (`claude-workflow`'s resolver, `agenticapps-workflow-core`'s gate count). However, these valuable findings are only recorded in this repo's "deferred items" list. There is no explicit task to consolidate and report these issues upstream, creating a risk that this cross-ecosystem knowledge will be lost. (Applies to: Phase-level process).

## Suggestions

-   Consider adding a final, non-blocking administrative task to plan `08-06`. This task would be to consolidate all identified upstream defects from `ADR-0009` and the deferred items list into a single draft issue or internal document for the operator to file. This would close the loop on the excellent analysis work already done and ensure the wider project ecosystem benefits from it.

## Risk Assessment

**Overall Risk: LOW**

The risk is low because the plans are comprehensive, internally consistent, and have been hardened against all previously identified high-severity risks. The rigorous TDD approach, including the vital producer-verifier contract test, provides a strong guarantee of correctness. The planning process itself has proven to be self-correcting and capable of deep, critical analysis. The remaining risk is negligible and relates to post-implementation process rather than technical execution. The phase is exceptionally well-prepared for a successful implementation.

---

## Codex Review

## Summary

The second-round plans are substantially stronger: earlier findings around root discovery, resolver parsing, reviewer strictness, consent, leaf-level merging, and honest enforcement claims were incorporated carefully. Wave ordering is sound and shared files are serialized correctly. However, the set is not execution-ready: several remaining contradictions can produce a bypass or make migration 0008 fail in real downstream projects even while the synthetic harness is green.

## Strengths

- The four-step resolver order and grandfather rule track spec §02 accurately, while correcting the known STATE.md and decimal-phase defects.

- Plans `08-01` and `08-02` have unusually strong adversarial coverage: nested cwd, ambiguous artifacts, malformed frontmatter, distinct reviewers, plan coverage, FIFOs, escape hatches, and producer/verifier round trips.

- Wave dependencies are correct. Files shared by `08-01`/`08-02`, `08-04`/`08-05`, and `08-05`/`08-06` are edited sequentially rather than concurrently.

- The migration leaf merge and rollback design correctly preserve sibling `pre_execution` gates. Version bump and drift coupling are kept in one commit.

- The plans honestly document the agent-mediated enforcement limitation, advisory egress boundary, bootstrap paradox, and deferred digest freshness. They do not pretend the live Phase 8 gate proves itself.

- The thin-binding stance is respected: no upstream GSD prompt is modified, and a local producer is authored only because Codex GSD has no corresponding review prompt.

## Concerns

- **HIGH — Migration 0008 operates on a scaffolder file that normal target projects do not contain.**  
  [08-05 Task 2](</Users/donald/Sourcecode/agenticapps/codex-workflow/.planning/phases/08-plan-review-gate/08-05-PLAN.md:518>) puts `skills/agentic-apps-workflow/SKILL.md` in the migration’s runtime steps and preconditions. The supplied setup skill defines project-side artifacts as `AGENTS.md`, `.planning/`, `.codex/`, and decisions—not a local `skills/` tree. The update skill also executes migration steps from the target project and already reads the installed trigger skill from `${CODEX_HOME}`. A normal downstream update will therefore fail even though `test_migration_0008` creates a synthetic `SKILL.md` and passes. The repository’s release-time SKILL version bump should remain in the implementation commit, but it should not be a target-project migration step.

- **HIGH — The bindings-table migration cannot produce the state its test requires.**  
  [08-06 Task 2](</Users/donald/Sourcecode/agenticapps/codex-workflow/.planning/phases/08-plan-review-gate/08-06-PLAN.md:336>) only replaces the two `tdd` rows and inserts `plan-review`, while leaving every other row untouched. The actual pre-0008 template has 15 rows, including one combined `brainstorm-ui / brainstorm-architecture` row. After collapsing `tdd` and adding `plan-review`, it still has 15 rows—not the 16-row fresh-install table required by the acceptance criteria. Step 3 must also replace the combined brainstorm row with the two template rows, or replace the complete recognized table body atomically.

- **HIGH — Ambiguous phase resolution lacks a terminal result.**  
  [08-01 Task 2](</Users/donald/Sourcecode/agenticapps/codex-workflow/.planning/phases/08-plan-review-gate/08-01-PLAN.md:521>) says `_match_phase_dir` returns empty for both “no match” and “ambiguous.” `resolve_phase` then treats empty as “continue” and falls through to newest-plan-by-mtime, potentially selecting one of the ambiguous directories after all. The resolver needs a tri-state contract: unique, absent, or ambiguous-terminal-fail-open. The test should assert that no `resolved-phase:` line appears and that the result remains allow after `08-02` enforcement is installed.

- **HIGH — Two verifier bypasses remain.**  
  [08-02 Task 2](</Users/donald/Sourcecode/agenticapps/codex-workflow/.planning/phases/08-plan-review-gate/08-02-PLAN.md:528>) uses `[ -f "$REVIEWS" ]`; `-f` follows symlinks, so a live symlink named `08-REVIEWS.md` pointing to any five-line file passes the fallback. Add an explicit `-L` rejection or canonical containment check. Separately, the `--file` bypass checks only a textual `.planning/` prefix and basename. A path such as `.planning/../docs/IMPLEMENTATION-PLAN.md` satisfies both checks. Reject `..` components or normalize the path before deciding, and add negative tests for both cases.

- **HIGH — Migration skip semantics can mark incomplete installs current.**  
  [08-05 Task 2](</Users/donald/Sourcecode/agenticapps/codex-workflow/.planning/phases/08-plan-review-gate/08-05-PLAN.md:539>) says the whole migration skips when `pre_execution.plan_review` already exists. Existing migration 0007 correctly makes only the corresponding step a no-op and continues later steps. Whole-migration skipping breaks recovery from partial application. Likewise, [08-06 Task 2](</Users/donald/Sourcecode/agenticapps/codex-workflow/.planning/phases/08-plan-review-gate/08-06-PLAN.md:336>) treats an unknown table header as a successful skip and then permits the version bump, leaving the project recorded at 0.6.0 without the table correction. Header mismatch should be a failed precondition requiring an explicit “skip with warning/partial” choice, not automatic success.

- **MEDIUM — The “real schema-conformant” review fixture is neither current nor fully conformant.**  
  [08-02 Task 1](</Users/donald/Sourcecode/agenticapps/codex-workflow/.planning/phases/08-plan-review-gate/08-02-PLAN.md:337>) copies the current `08-REVIEWS.md`, but that artifact lists five plan files while the phase now has six, and its frontmatter lacks the D-12 `overall_verdict` and `recommendation` keys. The synthetic test hides the missing sixth plan by creating only the five files listed in the artifact. Persist this second-round review with all six plans, and make the contract test assert every D-12 key and required body section—not only the two fields consumed by the verifier.

- **MEDIUM — The original success criterion 1 is amended rather than achieved.**  
  The current ROADMAP still says an unqualified block occurs before the first code edit. Plan `08-04` changes that criterion during execution to an agent-mediated check. That is an honest and reasonable decision, but phase closure should not claim all seven original criteria were met. Amend the ROADMAP now, before execution, so the reviewed contract is the contract later used for completion.

- **LOW — Two portability/drift assumptions remain inaccurate.**  
  `08-01` requires portable mtime comparison but does not pin the BSD/GNU `stat` fallback or require process substitution so the loop’s selected value survives. Also, `08-04` says the two config files differ only in `implements_spec`; the repository config additionally lacks the template’s `per_task.tdd.strengthened_by` block. That drift is out of phase scope, but the plan should not state it does not exist.

## Suggestions

1. Remove the target-runtime SKILL version step from migration 0008. Keep the repository SKILL bump in the same implementation commit for drift coupling, and add an end-to-end fixture representing a real target repo with no local `skills/` directory.

2. Make migration Step 3 transform all three table differences: add `plan-review`, collapse `tdd`, and split the combined brainstorm row. Prefer replacing the full table body after recognizing the exact legacy shape.

3. Give resolver helpers explicit status codes, for example: `0=unique`, `1=absent`, `2=ambiguous`. Treat status 2 as immediate fail-open.

4. Reject live symlink review artifacts and traversal-bearing `--file` paths; add regression cases for both.

5. Change every migration skip to step-local idempotency. Treat unrecognized document shape as a precondition failure or durable partial migration, never successful 0.6.0 completion.

6. Update `08-REVIEWS.md` from this second review and extend the producer contract test to validate the complete D-12 schema.

7. Pin a cross-platform `_mtime` helper and the non-subshell loop shape explicitly.

## Risk Assessment

**Overall risk: HIGH.** The architecture and sequencing are strong, and most first-round findings were genuinely resolved. The remaining issues are concentrated but consequential: one can make downstream migration fail, two permit gate bypasses, and two create false-success migration states. After those are corrected, the residual risk should fall to MEDIUM, dominated by the agent-mediated invocation model and prose-only external reviewer producer.

---

## OpenCode Review

## 1. Summary

The plans are unusually rigorous: red/green TDD pairing across two verifier suites, explicit honesty about three accepted limitations (agent-mediated enforcement, advisory egress, spoofable 5-line fallback), a fully traceable bootstrap-paradox admission with a "no manufactured dogfood" rule, and a threat register whose revised-after-review threats cite the finding that produced them. Wave ordering and `files_modified` are clean — sibling plans in the same wave touch disjoint file sets, and the 08-05/08-06 split (both editing `migrations/0008-*.md` + `run-tests.sh`) is well-justified and serial. The biggest substantive defect is a D-19/D-20 contract violation between the fresh-install path and the migrated path: plan 08-04 splits the brainstorm row in the template (Part A2) and removes the duplicate `tdd` row (Part A), but plan 08-06's migration step applies only the `tdd` collapse and the `plan-review` insert — leaving a v0.5.0 downstream install with a still-combined brainstorm row while fresh installs get a split one. 08-06's own assertion "the row count equals the template's row count" is unachievable against a realistic pre-migration fixture, so the test will either be unrealistic (constructed to already match the new template) or it will catch the gap as RED. Either way, the "migrated install reaches the same bound state as a fresh one" claim does not hold for row shape.

## 2. Strengths

- **Bootstrap paradox honesty.** Every plan that touches the verifier (08-01, 08-02, 08-04, 08-06) carries a "Gate coverage" section establishing that phase 08 is grandfathered against its own gate from wave 1's first SUMMARY onward, and forbids manufacturing a passing dogfood. The choice to root coverage in `test_check_plan_review_*` suites rather than the live repo is the correct call.
- **Reference port discipline.** Three named defects in the reference resolver (dead `## Current Phase` heading, missing `gsd-tools` step, colon-blocked regex) are corrected locally; the resolver-requirements added by review (root self-location, section bounding, decimal padding, ambiguity fail-open, mtime determinism) are deliberately *not* folded into ADR's "three defects" count. That boundary is asserted in 08-01's criteria and re-checked in 08-03's.
- **`set -u` discipline is stated as a cross-plan invariant.** The `${VAR:-}` mandate spanning 08-01 and 08-02, with an explicit "a single bare `$1` is a defect" reminder in 08-02, anticipates the silent-abort bypass failure.
- **Contract test ownership is explicit.** 08-03 produces the `reviews-skeleton` marker; 08-02 owns the round-trip test that extracts it. The plan refuses to add a duplicate test or a mock-CLI integration test, and the refusal is reasoned rather than hand-waved.
- **D-13 divergence is documented as the operationally load-bearing one.** The warn-and-allow → exit-2 change at the ≥5-line fallback is called out as the "single deliberate behavioral divergence from the reference" in 08-02, with a call-site comment instructing a future	reader not to "restore" it.
- **T-08-32 (ritual never teaches the agent to skip).** 08-04's `<enforcement_claim>` distinguishes the two failure modes — gate doesn't fire when invoked (ADR-0009's residual), and gate silently isn't invoked when the prose lets the agent decide. The "always invoke; verifier decides" rule is asserted section-scoped, including the deliberate divergence from the Knowledge Capture section's `**Skip** — when any holds:` shape.
- **Three-way byte identity.** 08-04 Task 3 fixed the earlier draft's two-way diff (template ↔ AGENTS.md) to a three-way diff with a non-emptiness guard, so the trigger SKILL.md cannot silently drift.
- **Merge safety corrections in 08-05.** The five review findings (leaf-idempotency, leaf-merge, leaf-rollback, sibling-gate fixture that actually catches 2 and 3, deferred multi-hop chain) are individually adjudicated and tied to specific `jq` shapes. The `cksum` POSIX pinning closes a class of BSD/GNU `sha256sum` and `md5` divergence.
- **08-06's header-shape guard.** Migration Step 3 declines rather than guesses: a target table whose header doesn't match the template's is left byte-identical and the skip is recorded. Asserting byte-identity via `cksum` (not row-absence) is the right shape — it catches mangling as well as omission.

## 3. Concerns

### HIGH

- **08-04 Task 2 Part A2 + 08-06 Step 3 — brainstorm split not propagated to migrated installs.** 08-04 splits the template's combined `brainstorm-ui / brainstorm-architecture` row into two separate rows, taking the template from 15→16 rows and bumping its distinct-gate count toward 16. But 08-06's Step 2 (Task 2) explicitly extracts only the `plan-review` row and the collapsed `tdd` row from the template; its `Apply` text says *"Leave every other row untouched"* — including the combined brainstorm row an install at 0.5.0 actually carries (inherited from the v0.4.0/v0.5.0 template, since neither 0007 nor 0008's prose step touches it). Net math for a realistic downstream install:
  - Pre-migration: combined brainstorm + 2 tdd rows + 12 others + 0 plan-review = 15 rows, 15 distinct gates
  - Post-migration (collapse tdd + add plan-review): combined brainstorm + 1 tdd + 12 others + 1 plan-review = **15 rows, 16 distinct gates**

  The fresh-install template post-08-04 has **16 rows, 16 distinct gates** (split brainstorm + 1 tdd + 12 others + 1 plan-review). The migrated and fresh states disagree on row shape — which is exactly the D-19/D-20 class the phase is supposed to close. Compounding: 08-06 Task 1's assertion *"the row count equals the template's row count"* (= 16) cannot pass against a fixture representative of a real v0.5.0 install (15 rows). The fixture would have to be constructed with split brainstorm to make the assertion hold — in which case it is not representative, and the test gives false confidence. Either resolution needs to land before this phase: (a) remove Part A2 from 08-04 entirely (the brainstorm-row split is outside the locked D-20 authority, which names only the tdd collapse — see below); or (b) extend 08-06's migration Step 3 to also split the brainstorm row, sourced from the template. The plan's `must_haves` claiming "A migrated install reaches the same bound state as a fresh one" is misleading as written.

- **08-04 Task 2 Part A2 — scope beyond locked decision D-20.** D-20 in 08-CONTEXT.md only locks "Collapse the duplicate `tdd` row." Part A2 introduces the inverse operation — splitting a combined row — on the authority that "config-hooks.json models them as two separate gates." The reasoning is sound, but no decision in 08-CONTEXT.md or the discussion log authorizes the brainstorm split, and the migration's not touching it (the HIGH above) confirms the asymmetry was not fully adjudicated. If 08-04 is bound by D-20's exact scope, Part A2 is over-reach; if it is intended, the migration has to mirror it.

### MEDIUM

- **08-06 Task 1 Step-2 idempotency pre fixture is under-specified re: brainstorm shape.** The fixture description (`| Gate | Bound skill | Scope |`, no `plan-review` row, two `| tdd` rows) does not say whether brainstorm is combined or split. Per the HIGH above, that ambiguity is what permits the test to be either realistic-failing or unrealistic-passing. Pin it: state which shape the fixture uses and that the assertion accounts for it (or fails noisily). If the fixture is the realistic "old template" shape, either the assertion changes to distinct-gate-count semantics, or the migration's Step 3 grows a brainstorm-split sub-step.

- **08-02 Task 2 — `plans_reviewed` coverage check shares the Summary-grandfather bypass issue.** The verifier requires `plans_reviewed:` to list every current `*-PLAN.md`, but only when frontmatter is present and well-formed. A bare `*-SUMMARY.md` blocks via the grandfather guard before the REVIEWS.md check runs (`<ordering>` step 5 sits before step 6), so the verifier never consults `plans_reviewed` for an already-shipping phase — the same defect family 08-06/ADR-0009's "grandfather-conflation defect" names upstream (per-plan SUMMARY + Summary-check precedes REVIEWS-check). Plan 08-02 acknowledges this grandfathers on the SUMMARY path but does not record that `plans_reviewed` freshness is *structurally unenforceable* once any SUMMARY exists for the phase — i.e., the freshness check fires only mid-flight, never for shipped phases. The plan should at minimum call this out: the coverage rule is "the cheap half of freshness" only for un-shipped phases, and ADR-0009's deferral of digest-based freshness should note that the *coverage* half is also bypassed post-SUMMARY.

- **08-05 Task 2 — `del(.hooks.pre_execution)` rollback placement.** The criteria require `grep -cE "del\(\.hooks\.pre_execution\)[^.]" migrations/0008-plan-review-gate.md` return 0 *outside the empty-parent conditional*, verified by reading the rollback block. That is a human-read check, not a mechanical one. If a future editor moves the `del(.hooks.pre_execution)` form above the conditional during the renumber 08-06 performs, the acceptance criteria will still pass mechanically (`grep -cE ... [^.]` only catches non-leaf forms; the leaf-del form had `.plan_review` after it). Either add a structural assertion that the bare `del(.hooks.pre_execution)` appears *only inside* the empty-parent conditional, or accept this as a documented reading-only invariant.

- **08-04 Task 2 Part D — re-wording a locked ROADMAP success criterion.** ROADMAP success criterion 1 is a spec obligation that was stated as "A phase with plans and no reviews is blocked before its first code-touching edit." 08-04 rewrites it to describe an agent-mediated check, justified by 08-REVIEWS.md's adjudication. The rewrite is *correct* given D-01/D-02, but ROADMAP criteria are typically treated as locked; the reworded text should at least carry a one-line notation that the original was relaxed by D-02 + Cross-AI adjudication, so a future reader sees the deviation was deliberate. (The plan does say "Keep it to one criterion line plus at most one clarifying sub-line" — but it doesn't say to note the change of strength.)

- **08-03 — timeout value is left to executor discretion.** `<review_findings_bound_here>` requires "a per-invocation timeout; a timeout is recorded as an unavailable reviewer" with "Choose a timeout generous enough for a real review and state it." Letting the executor pick a value is fine, but the provenance table format and the failure-mode enumeration are firm while the timeout is not — a slight inconsistency in firmness that invites drift across phases. Pin a default (e.g. 300s) with a comment that the operator may override, comparable to how `<interfaces>` pins `_canon_dir` exactly rather than leaving it to the executor.

### LOW

- **08-04 Task 2 Part D + 08-06 Task 3 — CHANGELOG altitude vs. ADR citation.** V/V finding V correctly compresses the three-defect paragraph to one sentence in the CHANGELOG. But criterion `awk '/^## \[Unreleased\]/{f=1} /^## \[0/{f=0} f' CHANGELOG.md | grep -ci 'Current Phase'` returns 0 and `grep -ci 'gsd-tools'` and `grep -ci 'colon'` return 0 — these forbid those tokens even when used inside a sentence pointing *at* the ADR ("see ADR-0009 for the heading, regex, and grandfather issues" would pass; "the dead `## Current Phase` heading — see ADR-0009" would fail). The intent is fine; the assertion is sharp enough to be brittle if the CHANGELOG names the defect at all in release altitude. Consider relaxing to "no enumeration, ≤ one sentence" rather than a token denylist.

- **08-05/08-06 — checksum comments may collide with the `sha256sum`/`md5sum` denylist.** The assertions require test streams to return 0 for `sha256sum` and `md5sum`. If an executor adds a comment like *"# use cksum, not md5sum, because macOS ..."*, the assertion fires even though the implementation is correct. Either allow those tokens inside `#` comment lines, or instruct the executor to avoid them in literal form. Reference: 08-05 Task 1 acceptance.

- **08-02 Task 1 — `_cpr_case` stderr exposure.** The helper is required to expose the captured stderr to callers asserting on debug lines, but the plan leaves the mechanism unspecified ("either return its path in a well-known variable or accept an out-path argument"). This is fine for execution, but each direction has subtle consequences: a `local` variable holding the path is scope-fragile across nested calls; an out-path argument lengthens the call signature. Pin one shape — out-path argument, defaults to a per-call `mktemp` — to prevent two implementers in different tasks choosing differently.

- **Cross-plan — `08-04` Task 1's `<interfaces>` block inserts a `$CODEX_HOME/.../check-plan-review.sh` path.** The config's `verifier` value uses the bare `${CODEX_HOME}` form intentionally (no shell expansion), per the explanation. The invocation prose in 08-04 Task 2 Part C uses the fallback form intentionally. Good — but the rationale is asserted as a "deliberate asymmetry" by the plan author; a one-line note in the config block (a JSON comment is unavailable, but the brief or ADR can carry the rationale) future-proofs against someone "harmonizing" the two.

## 4. Suggestions

1. **Resolve the brainstorm-split defect before execution.** Pick one: (a) remove Part A2 from 08-04 entirely, keeping the template's existing combined brainstorm row (the AGENTS.md(template) asymmetry is a pre-existing cosmetic inconsistency between this repo's two files; the phase's locked scope is D-19/D-20, and this isn't either); or (b) extend 08-06's Step 3 to extract the two brainstorm rows from the template and apply them to the target on top of the tdd-collapse + plan-review add. Option (a) is the smaller change, restores row-shape parity between fresh and migrated installs, and shrinks 08-04's scope.
2. **Tighten 08-06 Task 1's idempotency-pre fixture description** to name whether brainstorm is split or combined. If the brainstorm-split is removed (option a above), the fixture is the unambiguous "old template" shape and the row-count assertion is meaningfully equal between fixtures and post-edit template.
3. **Add one line to ADR-0009's deferred list acknowledging the `plans_reviewed`-freshness post-SUMMARY gap** — "the coverage half of freshness is bypassed once any SUMMARY exists for the phase, the same grandfather-conflation defect as the heading/regex issue." Otherwise a future reader may believe the coverage rule fires for shipped phases.
4. **Pin the producer timeout default** (e.g. 300s) in `<interfaces>` of 08-03, mirroring the `_canon_dir` pin's exactitude, and let the operator override via an env var or a documented constant.
5. **Note the strength-change in ROADMAP criterion 1 explicitly** (one inline parenthetical: "(reworded from an unconditional block per D-02; see ADR-0009 decision 9)"). This is lassen-on-drift: signal that the criterion is not the spec's verbatim phrasing.
6. **Resolve 08-06 Task 1's "row count = template's" ambiguity by replacing the assertion with "row count + distinct-gate-count" semantics** that are robust to the brainstorm question. Even after fix 1, asserting both row-count and distinct-count makes the test self-documenting.
7. **In 08-02 Task 1 acceptance**, relax the `sha256sum`/`md5sum` denylist to `[^#]*sha256sum` etc., or instruct the executor explicitly to avoid the literal tokens even in comments — same for 08-05 and 08-06.
8. **In 08-06 Task 2 acceptance**, change "`del(.hooks.pre_execution)` appears only inside the empty-parent conditional" from a human-read check to a structural one: assert `awk` finds the bare `del(.hooks.pre_execution)` line only when it is immediately preceded by `if.*==.*\{\}.*then` within N lines.

## 5. Risk Assessment

**MEDIUM.** The plans are well-engineered and unusually disciplined — the cross-AI review process genuinely improved them (merge-safety corrections, contract test ownership, three-way byte identity, ritual-prose always-invoke rule, deferred-update-chain-not-fixed-here). Most execution risks are owned and asserted. The single HIGH concern (the brainstorm-split fresh/migrated divergence, with an unachievable-or-unrealistic test) is concrete and caught by the plans' own assertions — which is either evidence the test will be authored wrong (unrealistic fixture) or that the divergence is intentionally unfixed (in which case the `must_haves` text "same bound state" is misleading). One plan-side decision (reset of wave 1 teachings via the producer's marker) depends on 08-03 finishing before 08-02 starts; the dependency graph reflects that, so the risk is sequencing, not the binding. Deferred items (native `hooks.json`, §14, multi-hop chain, grandfathe-conf defect upstream) are honestly attributed to their own phases rather than folded in. With the brainstorm-split issue resolved (suggestion 1, the smallest achievable), residual risk drops to LOW. Left as written, the phase will pass its own acceptance criteria but ship a row-shape divergence between fresh and migrated installs, which is exactly the D-19 failure class this phase exists to close — worth resolving before this phase is marked terminal.

---

## Consensus Summary

Three independent reviewers read the same six-plan bundle with no access to each
other's output. All three agree the revision round worked: the round-1 HIGH
consensus concern — that the producer and verifier shipped in the same phase with
nothing proving they compose — is **closed**. All three credit the
`test_check_plan_review_contract` round-trip test in 08-02 and the
`reviews-skeleton` marker ownership boundary between 08-03 and 08-02. Root
self-location, leaf-merge safety, and the honest enforcement claim are likewise
credited as genuinely resolved rather than papered over.

**The verdicts still diverge across the full range, and for the same reason as
round 1.** Gemini returned LOW with a single LOW-severity concern about a
process nicety, calling the phase "exceptionally well-prepared." That is a rubber
stamp and carries little independent signal — it found no new defect that the
other two found, in a bundle where the other two independently found the same
one. Codex (HIGH) and OpenCode (MEDIUM) both did adversarial work and **converged
on the same top defect from different directions**, which is the strongest signal
in this round.

### Agreed Strengths

Mentioned by 2+ reviewers:

- **Round-1 findings were genuinely closed, not deflected** — all three verify
  the specific fixes: verifier root self-location (T-08-28), the `jq` leaf-merge
  correction (T-08-22), fail-closed non-regular artifact handling (T-08-09), and
  the reworded enforcement claim (T-08-33).
- **The producer/verifier contract test closes round 1's top gap** — all three
  single this out. Gemini calls it the transformation "from plausible designs
  into verifiable contracts"; OpenCode credits the explicit ownership boundary
  (08-03 emits the marker, 08-02 extracts it) and the *reasoned* refusal to add a
  duplicate mock-CLI test.
- **Wave ordering and `files_modified` serialization are correct** — Codex and
  OpenCode both independently verified that 08-01/08-02, 08-04/08-05, and
  08-05/08-06 edit shared files sequentially, never concurrently, and both credit
  the 08-05/08-06 split rationale.
- **Reference port discipline — three defects corrected, and the boundary held** —
  all three credit correcting the dead `## Current Phase` heading, the missing
  `gsd-tools` step, and the colon-blocked regex. OpenCode specifically credits
  *not* inflating the ADR's "three defects" count with the review-added resolver
  requirements.
- **Bootstrap paradox honesty** — all three credit the per-plan "Gate coverage"
  sections and the explicit rule forbidding manufactured dogfood evidence.
- **Thin-binding stance (ADR-0007) respected** — Codex and Gemini both confirm no
  upstream GSD prompt is modified and the local producer exists only because
  Codex GSD has no corresponding review prompt.
- **Threat models are specific rather than boilerplate** — Gemini and OpenCode
  both name individual threats (T-08-12 consent gate, T-08-17 fixed verifier
  path, T-08-32 ritual-never-teaches-skip) as plausible and correctly mitigated.

### Agreed Concerns

Raised by 2+ reviewers — highest priority first:

1. **HIGH — The bindings-table migration cannot reach the fresh-install state it
   claims parity with.** This is the round's strongest consensus, reached
   independently by Codex and OpenCode with matching arithmetic. 08-04 Task 2
   Part A2 splits the template's combined `brainstorm-ui / brainstorm-architecture`
   row, taking the template 15→16 rows. 08-06 Step 3 applies only the `tdd`
   collapse and the `plan-review` insert, and its Apply text says *"Leave every
   other row untouched"* — so a real v0.5.0 install lands at **15 rows / 16
   distinct gates** while a fresh install is **16 rows / 16 gates**. 08-06 Task 1's
   assertion "row count equals the template's row count" is therefore
   *unachievable against a representative fixture*: the test either fails, or it
   passes only because the fixture was built with an already-split brainstorm row
   and is not representative. Both reviewers note this is precisely the D-19/D-20
   fresh-vs-migrated divergence class the phase exists to close, and that the
   `must_haves` claim "a migrated install reaches the same bound state as a fresh
   one" is misleading as written. **The two disagree on the fix — see Divergent
   Views.**

2. **MEDIUM — ROADMAP success criterion 1 is amended during execution rather than
   achieved.** Codex and OpenCode both flag that 08-04 Part D rewrites criterion 1
   from an unconditional block to an agent-mediated check. Both agree the rewrite
   is *correct* given D-01/D-02 — and both object to the timing and the silence.
   Codex: amend the ROADMAP **now, before execution**, so the reviewed contract is
   the contract used at completion; phase closure must not claim all seven
   original criteria were met. OpenCode: at minimum carry an inline notation
   ("reworded from an unconditional block per D-02; see ADR-0009") so a future
   reader sees the deviation was deliberate.

3. **MEDIUM — 08-06 Task 1's idempotency fixture is under-specified in exactly the
   place concern 1 lives.** OpenCode raises this directly; Codex's HIGH #2 implies
   it. The fixture description never says whether brainstorm is combined or split
   — and that ambiguity is what lets the test be either realistic-and-failing or
   unrealistic-and-passing. Pin the shape explicitly, and consider asserting
   *both* row count and distinct-gate count so the test is self-documenting and
   robust to the brainstorm question either way.

### Divergent Views

Where reviewers disagreed — worth adjudicating before execution:

- **How to fix the brainstorm-row divergence (concern 1).** OpenCode prefers
  **removing Part A2 from 08-04** — it is the smaller change, restores row-shape
  parity, shrinks 08-04's scope, and (OpenCode argues separately, as its own HIGH)
  Part A2 is *outside locked decision D-20*, which authorizes only "collapse the
  duplicate `tdd` row." Nothing in 08-CONTEXT.md or the discussion log authorizes
  the inverse split operation. Codex prefers the opposite: **extend 08-06 Step 3**
  to transform all three differences, ideally by replacing the recognized legacy
  table body atomically. This is a real fork — one shrinks the phase, one grows
  the migration. D-20's literal scope favors OpenCode; long-term
  template/config-hooks.json coherence favors Codex.

- **Overall risk, again spanning the full range** (Gemini LOW / OpenCode MEDIUM /
  Codex HIGH). OpenCode: residual drops to LOW once the brainstorm issue is
  resolved. Codex: residual falls to MEDIUM after his five corrections, dominated
  by the agent-mediated invocation model. Gemini found nothing blocking. Weight
  Codex and OpenCode; Gemini's review does not survive contact with the two
  concrete defects the others found.

- **Codex-only HIGH findings** (no second reviewer corroborated — evaluate on
  merit, not on vote count; Codex ran at xhigh reasoning and these are specific):
  - **Migration 0008 operates on a file target projects do not have.** 08-05 Task 2
    puts `skills/agentic-apps-workflow/SKILL.md` in the migration's runtime steps
    and preconditions, but the setup skill defines project-side artifacts as
    `AGENTS.md`, `.planning/`, `.codex/`, and decisions — no local `skills/` tree.
    A normal downstream update would fail while `test_migration_0008` passes on a
    synthetic `SKILL.md`. Fix: keep the repo SKILL bump in the implementation
    commit for drift coupling, but drop it from the target-project migration steps.
    *If correct, this is the most consequential finding in the round* — it means
    the harness is green and the product is broken.
  - **Two verifier bypasses remain.** `[ -f "$REVIEWS" ]` follows symlinks, so a
    symlink named `08-REVIEWS.md` pointing at any five-line file passes the
    fallback. And the `--file` bypass checks a textual `.planning/` prefix, so
    `.planning/../docs/IMPLEMENTATION-PLAN.md` satisfies it. Both need negative
    tests.
  - **Ambiguous phase resolution has no terminal state.** `_match_phase_dir`
    returns empty for both "no match" and "ambiguous"; `resolve_phase` treats
    empty as "continue" and falls through to newest-plan-by-mtime — potentially
    selecting one of the ambiguous directories anyway. Needs a tri-state contract
    (`0=unique, 1=absent, 2=ambiguous-terminal-fail-open`).
  - **Migration skip semantics can mark incomplete installs current.** 08-05 skips
    the *whole* migration when `pre_execution.plan_review` exists, where 0007
    correctly makes only the corresponding step a no-op. And 08-06 treats an
    unknown table header as successful skip, then permits the version bump —
    recording the project at 0.6.0 without the table correction.

- **OpenCode-only MEDIUM/LOW findings** worth folding in cheaply:
  - `plans_reviewed` freshness is **structurally unenforceable once any SUMMARY
    exists** (the grandfather guard at step 5 precedes the REVIEWS check at step
    6) — the same grandfather-conflation defect family the ADR names upstream.
    ADR-0009's deferred list should say the *coverage* half is bypassed too.
  - The producer timeout is left to executor discretion while everything around it
    is pinned — pin a default (e.g. 300s) as `<interfaces>` pins `_canon_dir`.
  - Several acceptance criteria are token denylists brittle enough to fire on a
    correct implementation: the CHANGELOG `grep -ci 'Current Phase'` check fails
    on a sentence *pointing at* the ADR, and the `sha256sum`/`md5sum` denylist
    fires on an explanatory comment. Relax to `[^#]*` forms or non-enumeration
    semantics.
  - `del(.hooks.pre_execution)` placement is a human-read check that a mechanical
    `grep` would not catch if a future editor moved it — make it structural.

- **Gemini-only LOW:** no task consolidates the upstream defects this phase found
  (in `claude-workflow`'s resolver and the core spec's gate count) into a report
  filed upstream — the findings live only in this repo's deferred list.

### Self-correcting note

Codex's MEDIUM about the 08-02 fixture — that it copies an `08-REVIEWS.md`
listing five plans when the phase now has six, and lacking the D-12
`overall_verdict` and `recommendation` keys — is **partially resolved by this
file**, which lists all six plans. The missing D-12 frontmatter keys remain a real
gap: this artifact is produced by `/gsd-review`, whose schema predates D-12. If
08-02 Task 1 is to copy a real artifact as its fixture, either this file gains the
D-12 keys or the fixture must be authored to the D-12 schema directly rather than
copied.
