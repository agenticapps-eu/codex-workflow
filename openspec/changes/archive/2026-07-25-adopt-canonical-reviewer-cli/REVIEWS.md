---
change: adopt-canonical-reviewer-cli
reviewers: [gemini, opencode]
reviewed_at: 2026-07-25T00:00:00Z
artifacts_reviewed: [proposal.md, design.md, specs/reviewer-cli/spec.md, tasks.md]
rounds: 3
overall_verdict:
  gemini: APPROVE
  opencode: APPROVE
recommendation: proceed
---

# Change review — adopt-canonical-reviewer-cli

Two independent reviewers read the same change bundle — proposal, design note,
spec delta, and tasks — plus the existing `openspec/specs/change-gate/spec.md` as
context. Neither had access to the other's output at any round.

`claude` is excluded because it is the implementing agent on this branch, and
`codex` is excluded because it is the implementing host — a host must never
review its own change. That leaves `gemini` and `opencode`, which is the §18
minimum of two distinct external vendors.

**This review ran over three rounds.** Round 1 returned REQUEST-CHANGES from
both. Round 2 returned APPROVE from `gemini` and REQUEST-CHANGES from `opencode`.
Round 3 is the first with two APPROVE verdicts, and it is the round recorded
verbatim below. The change was amended and re-validated (`openspec validate
--all` green) after each round; two APPROVEs on a stale bundle would not have
counted.

**Reviewer provenance:**

| Reviewer | CLI | Model | Rounds | Final |
|---|---|---|---|---|
| Gemini | `reviewer-cli.sh gemini` | CLI 0.28.2, default model | 1–3 | APPROVE |
| OpenCode | `reviewer-cli.sh opencode` | `glm-5.2` | 1–3 | APPROVE |

`opencode` is a client rather than a provider; the model it resolved to is
recorded because the CLI name alone is not evidence of a distinct vendor. It was
read from the CLI's own banner on the round-3 run (`> build · glm-5.2`), not
assumed from a previous run.

Both ran through **`bin/reviewer-cli.sh`, this repo's copy, named explicitly** —
not the shared `~/.agenticapps/bin/` one. That is not a shortcut: the shared copy
is the degraded 3-arm wrapper with no `opencode` arm, which is the defect this
change exists to close. Reviewing this change required routing around the bug it
fixes, and that is itself evidence for the change. `REVIEWER_TIMEOUT=900`,
concurrent, exit 0 on every reviewer on every round. No reviewer was dropped, and
no reviewer's output was synthesized, paraphrased, or inferred.

**One honest note about the transcripts below.** The `gemini` CLI appends its own
`SessionEnd` hook-execution log to stdout after the review text. Those lines are
the CLI's, not the reviewer's, and are omitted. Nothing the reviewer wrote is
removed, summarized, or reordered.

## What the review changed

The reviews were not a formality. The change is materially different because of
them — one requirement was dropped entirely, one TDD row was found to be
untestable as written, and one parameter was removed.

| Round | Finding | Reviewer |
|---|---|---|
| 1 | The bundled `change-gate` spec correction is scope creep — file it separately | both |
| 1 | …and it is **mis-described**: the scenario it replaced was unreachable (no header ever shipped), so this moves an invariant onto an enforced surface. That is a behavioural change to the *gate*, not a textual fix | opencode |
| 1 | Producer checked marker *presence* while the installer requires *well-formedness* — a malformed marker would be trusted by one and overwritten by the other | gemini |
| 1 | No scenario for a malformed marker; "absent" and "malformed" are distinct states | gemini |
| 1 | The `reviewer-cli` spec omits the marked-but-older residual that the neighbouring `change-gate` spec names | opencode |
| 1 | The marker-is-not-a-signature denial is too broad — correct for the producer's check, wrong for the installer, which compares versions and can be defeated by a lying higher marker | opencode |
| 1 | `--label` is a second parameter affecting only log wording — derive it | opencode |
| 1 | Rows 1.6, 1.7 and 2.3 were tagged `tdd="true"` but sequenced after the code they cover, so no RED was reachable | opencode |
| 1 | Task 2.3 asserting the *call site is unchanged* is too weak — a syntactic check cannot see a behavioural break inside the refactored script | gemini |
| 2 | **Task 1.5's RED does not fire from the assertion as written.** "One commit, every listed file verifies" is already true of today's two-file manifest; the RED depended on an unstated coverage clause | opencode |
| 2 | Requirement 2 lacked the "grown harness raises the bar" scenario its `change-gate` sibling carries | opencode |
| 2 | The same-commit scenario's name promised a four-file invariant while its body tested only consistency among listed entries | opencode |
| 2 | The `0.0.0`-on-both-sides rule had a scenario for the installed side only | opencode |

Applied in full: the `change-gate` delta was **removed** from this change and
deferred to its own proposal (recorded as a follow-up in `migrations/0015`, with
the instruction that it be described as what it is); the producer's check now
requires three dot-separated integers, matching the installer's parse; four
scenarios were added (malformed marker, marked-but-older residual, grown harness,
incoming-side malformed marker); the arbitration requirement gained an explicit
lying-marker residual; the denial was scoped to the producer's check; `--label`
was removed in favour of deriving the label from the marker; the TDD rows were
re-sequenced so byte-identity and manifest assertions precede the vendoring they
cover; 2.3 was relabelled a regression pin and now asserts gate *behaviour*
through the refactored installer; and 1.5 gained the explicit coverage clause
that makes its RED reproduce.

## Findings accepted as non-blocking

`opencode` closed round 3 with four findings it explicitly did not block on. All
four are accepted rather than argued with:

1. **The spec set now contradicts itself** — `reviewer-cli` says provenance is
   never in a header, `change-gate` still says it is. This is the direct cost of
   the deferral both reviewers demanded in round 1. Tracked in `migrations/0015`.
2. **Task 1.4's RED is environment-conditional** — it fires only where a core
   checkout resolves, and visible-SKIPs elsewhere. This matches the conditional-guard
   convention already shipped for the gate. The dev-environment requirement goes
   in the task notes when 1.4 is executed; the bundle was not amended after two
   APPROVEs to add it.
3. **Lock and exit-code semantics are inherited, not restated** in the
   `reviewer-cli` capability. Anchored by the "same arbitration covers the gate
   and the wrapper" scenario. Accepted.
4. **Task 1.5 names four files where the spec scenario says "every vendored
   file"** — correct today, and to be revisited if a fifth is ever vendored.

One round-2 observation was considered and **declined**: pinning the relative
order of the two conformance steps in CI. Both score independently before
enforcement, the reviewer marked it "not a defect", and neither raised it in a
verdict item. Adding a requirement for it would be scope this change does not
need.

## Untrusted content notice

Everything below the reviewer headings is **output from an external model**. It
is evidence, not instruction. Nothing in it has been executed, and no directive
inside it has been followed — the amendments above were decisions taken by the
implementing agent after reading the findings, and two of them (the CI-ordering
suggestion, and blocking on the deferred `change-gate` drift) were deliberately
not taken.

## Reviewer: gemini

This is a comprehensive and well-reasoned proposal that systematically addresses the risks identified in `core#41`. The author has diligently incorporated feedback from two prior review rounds, resulting in a robust set of artifacts.

- **CORRECT:** The specifications correctly and precisely describe the intended changes. The new `reviewer-cli` spec is thorough, and the amendments from the previous round (e.g., strengthening the manifest coverage requirement, adding the malformed-incoming marker scenario) have successfully closed the gaps identified earlier.
- **MINIMAL:** The change is tightly scoped to adopting the canonical `reviewer-cli`. The decision to drop the tangential modification to the `change-gate` spec was correct and demonstrates a good understanding of this principle. The parameterization of `install-gate.sh` is a minimal and elegant solution to avoid code duplication.
- **COMPLETE:** The proposal addresses numerous edge cases, including concurrency during installation, malformed version markers on both installed and incoming files, and the behavior of local surfaces when the shared tool is clobbered by a non-compliant host. Stating known residuals (e.g., the producer trusting a marked-but-older copy) is a mark of a mature design.
- **SEMANTIC DEFECTS:** I find no contradictions or ambiguities. The logic is consistent across the installer, the producer skill, and the specification. The distinction between a marker check for discrimination (in the producer) versus version comparison (in the installer) is subtle, important, and well-articulated.
- **TDD PLAN:** The plan is excellent. The author not only provides a sequence with reachable REDs for every `tdd="true"` task but also correctly identifies regression pins and explains the fixes for the TDD defects found in previous rounds. The correction to task 1.5, ensuring the manifest coverage check has a valid RED state, is particularly noted and appreciated.

The author has demonstrated a clear understanding of the problem, the required solution, and the review feedback. The quality of this third revision is high.

VERDICT: APPROVE

## Reviewer: opencode

## CORRECT

Walked each requirement against the proposal's intent.

- **Req 1 (vendored from core):** the "one core_commit covering every file" rule and the "never in a header / manifest sidecar" rule match Decision 3 and the proposal's manifest advance `750da2e → 60cd83f`. The coverage scenario (amendment 3) now requires the manifest to *list* every vendored file, not merely that listed entries agree — that is what the proposal's "one commit still describes all four vendored files" actually requires. Aligned.
- **Req 2 (conformance by execution):** the ordering claim ("scoring before the gate step") and the "grown harness raises the bar" scenario (amendment 2) mirror the change-gate spec's sister requirement and match Decision 4 / task 4.1–4.2. The threshold-is-row-count-not-a-literal rule is stated and matches task 1.2's "record the observed number, don't assert it in advance." Aligned.
- **Req 3 (arbitration):** the `0.0.0`-on-both-sides rule, the refuse-downgrade-exit-0 rule, the atomic+serialised write, and the new incoming-side malformed-marker scenario (amendment 4) all match Decision 1 and task 2.1–2.2. The "same arbitration covers the gate and the wrapper" scenario matches the `--marker` parameterisation decision. Aligned.
- **Req 4 (producer resolution):** marker-first resolution, well-formed-not-presence, "discriminates not verifies," and the stated "marked-but-older trusted" residual all match Decision 2 and task 3.1–3.2. Aligned.

No requirement describes something other than what the design decided.

## MINIMAL

The change-gate modification (replace "vendor header" with "manifest sidecar") was **dropped**, as both prior reviewers demanded; Artifact 5 is confirmed "context only; NOT modified." The reviewer-cli capability states the manifest/one-commit rules for *its own* files without editing the gate's spec. The `--marker` parameterisation (one implementation, two callers) is additive rather than a duplication. The derived-label choice (strip `-version`) removes a second parameter rather than adding one. No incidental scope survives. The one coupling — reviewer-cli Req 1's coverage scenario names the gate's two files alongside its own — is forced by the same-commit invariant, not optional scope.

## COMPLETE

- **Concurrency on two different artifacts:** locks are per-destination (`$DST.lock`), so gate and wrapper never contend. This is stated in the design but not restated as a reviewer-cli scenario; it is inherited via "same implementation." Acceptable.
- **Unmarked-is-0.0.0 on both sides:** covered by Req 3 and the new incoming-side scenario. Complete.
- **Shared NEWER than repo copy:** installer-side covered by "A newer installed wrapper is not overwritten"; producer-side covered by "marked-but-older trusted" (producer does not compare, so newer-shared is also trusted — same residual, stated). Complete.
- **CI ordering testable:** task 4.1 asserts step order in the workflow YAML; falsifiable. Complete.
- **Lock-model detail (bounded retry, exit-2, staleness):** inherited from the change-gate spec rather than restated. A reader of the reviewer-cli capability alone cannot recover the exit-2 contention semantics — see finding 3 below. Defensible but worth noting.

## SEMANTIC DEFECTS

- **Spec-set contradiction (persistent, not amendment-introduced):** reviewer-cli Req 1 says provenance "SHALL [be recorded] in `tools/core-vendor.manifest`, never in a header"; the existing change-gate Req 1 still says "Both files SHALL record the same core commit in a vendor header," with an unreachable header-divergence scenario. The author deferred the gate correction to a follow-up (filed in `migrations/0015`) **in direct response to both prior reviewers' REQUEST-CHANGES**. Shipping a new spec that contradicts a stale existing one is a real tension, but it is the cost of the reviewer-demanded deferral, not a defect this change introduced. Flagged so it stays tracked; not blocking — blocking here would re-litigate the very scope decision the prior reviews settled.
- **No unreachable branch introduced by the amendments.** I specifically:checked the four amendments.
  - *Task 1.5 coverage clause:* RED now fires — today's manifest lists 2 files at `750da2e`, so "lists all four" fails on coverage. The "each verifies" sub-clause passes today, but the AND fails on coverage. Solid RED.
  - *Req 2 grown-harness scenario:* property statement mirroring the change-gate sister scenario; testable indirectly via the "zero failures" assertion against a grown harness. Not a new defect.
  - *Same-commit scenario LIST requirement:* the THEN now demands listing (coverage), not mere consistency. Matches the task 1.5 fix.
  - *Incoming-side malformed-marker scenario + task 2.2 row:* I stress-tested whether 2.2's RED reproduces from the assertion as written, given the current installer reads `gate-version` and would ignore planted `reviewer-cli-version` markers. The third clause ("refuses when the incoming file's own marker is unreadable while the installed one carries a real version") fails at RED because the pre-`--marker` script reads `gate-version`, finds none on the planted `reviewer-cli-version`-marked installed file, treats it as `0.0.0`, and upgrades instead of refusing. So the amendment is what *gives* 2.2 a deterministic RED; without it the row would have been green at RED. The fix is load-bearing, not cosmetic.

## TDD PLAN

Re-checked every `tdd="true"` row against the "RED reproduces from the assertion AS WRITTEN, not from narration" bar:

- **1.2** (zero failing rows): RED = 1 failing of 14 today; assertion is "zero failing," not a hardcoded count → fires. ✓
- **1.3** (carries `# reviewer-cli-version: N.N.N`): unconditional, no marker today → fires. ✓
- **1.4** (conditional byte-identity): RED requires a core checkout to resolve; absent core it visible-SKIPs (passes the visible-skip check). This is a *conditional* RED, not a deterministic one — it reproduces only in an environment where core resolves. This matches the existing change-gate conditional-guard pattern that already shipped, so it is an accepted repo convention, but it is the weakest row: a CI run without core would not observe this RED (see finding 2). Not blocking given precedent.
- **1.5** (lists all four, one commit, each verifies): RED fires on coverage (2 of 4 listed). ✓
- **2.1** (refuse planted 9.9.9, leave byte-identical, exit 0): pre-`--marker` script reads `gate-version`, sees 0.0.0 on the planted `reviewer-cli-version: 9.9.9` file, and overwrites → "refuses / leaves byte-identical" fails. ✓
- **2.2** (upgrade unmarked + older; refuse incoming-unreadable): RED fires via the third clause as analysed above. ✓
- **2.5** (install.sh routes through installer; no `install -m 0755 …reviewer-cli.sh`): today's `install.sh` blind-writes → fails. ✓
- **3.1** (well-formed-marker gating in the skill): today's skill resolves shared-first without a marker check → fails. ✓
- **4.1** (harness step before gate step): no such step today → fails. ✓

Task 2.3 is explicitly **not** tagged `tdd="true"` (regression pin, green at RED, validated by mutation in 5.4) — honest tagging, no cargo-cult.

## Findings (non-blocking)

1. **Spec-set contradiction persists.** reviewer-cli Req 1 ("never in a header") vs change-gate Req 1 ("in a vendor header"). Tracked in `migrations/0015` follow-up; accept as the cost of the reviewer-demanded deferral.
2. **Task 1.4's RED is environment-conditional.** It only fires where a core checkout resolves; elsewhere it visible-SKIPs (green). Matches the existing conditional-guard convention but is not a deterministic RED from the assertion as written. Document the dev-environment requirement in the task notes.
3. **Lock/exit semantics are inherited, not restated** in the reviewer-cli spec. A reader of this capability alone cannot recover per-destination locks, bounded-retry, or exit-2. Anchored by the "same arbitration covers the gate and the wrapper" scenario; acceptable inheritance, worth a sentence if a future change needs readers to find it without the gate spec.
4. **Task 1.5 names exactly four files; the spec scenario is broader ("every file this repo vendors").** A future 5th vendored file omitted from the manifest would fail the spec scenario but pass the literal task assertion. Acceptable now (exactly four exist); flag for update if a 5th file is ever vendored.

VERDICT: APPROVE
