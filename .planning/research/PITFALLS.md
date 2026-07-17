# Pitfalls Research: v0.8.0 "Enforcement, Not Intention"

**Domain:** Nominal-enforcement debt in a spec-first workflow host binding (CI gating, migration chains, hook surfaces, AWK-based text-region editing, shell guard fixtures)
**Researched:** 2026-07-16
**Confidence:** HIGH (all findings sourced directly from this repo's own RETROSPECTIVE.md, PROJECT.md, 09-REVIEW.md, and the two migration files under discussion — no external ecosystem claims; this is a self-audit, not a survey)

## Why This Document Is Shaped Differently

This is not ecosystem research. v0.8.0 exists because the last two milestones
each shipped a green suite over code that didn't do what the suite claimed:
v0.6.0's 104 assertions used only byte-perfect fixtures and missed two
fail-opens; v0.7.0 shipped 314 PASS / 0 FAIL on a migration whose pre-flight
aborted `exit 3` on every real install, because the harness *manufactured the
precondition under test*. The repo's own countermeasure — **a guard is not
shipped until it has been observed failing** — is the standard every pitfall
below is measured against. Generic CI/shell advice is deliberately excluded;
every pitfall here is specific to one of the seven v0.8.0 fixes and has a
prevention traceable to an observed-failing or mutation-tested gate.

## Critical Pitfalls

### Pitfall 1: CI-01 goes green while testing nothing (the "third green" repeat)

**What goes wrong:**
`.github/workflows/ci.yml` is replaced with something that *runs* but still
certifies nothing, in any of these concrete shapes specific to this repo:
- The `checkout` step omits `submodules: recursive`. `vendor/agenticapps-shared`
  is absent, `run-tests.sh` hard-fails early on a missing dependency in a way
  that looks like an environment problem rather than a test failure, and a
  misconfigured job treats that early exit as "nothing to report" (e.g. a
  wrapper step that captures output and only checks for a magic string) rather
  than a failing job.
- A step is written as `./migrations/run-tests.sh || true`, or output is piped
  through something that always exits 0 (`| tee log.txt`, `| grep -c FAIL` with
  a downstream `exit 0`), so a job with real FAIL lines still shows green in
  the GitHub UI.
- The job's working directory is wrong (runs from repo root when
  `run-tests.sh` assumes it's invoked from `migrations/`, or vice versa), so
  the script silently no-ops or globs zero files, printing "0 tests found" as
  a false PASS rather than a failure.
- The drift check (`SKILL.md` version vs. latest migration `to_version`) is
  bolted on as informational (a `continue-on-error: true` step, or logged but
  not gated), so a version-bump omission is visible in logs but does not fail
  the job — exactly the shape v0.7.0 needed for `MIGR-08`/`MIGR-09` conflation
  to have been caught in CI rather than by human review.
- Caching (`actions/cache` keyed too broadly, or a container image reused
  across runs) serves a stale pass from a previous commit when the current
  commit's test run itself errors out before producing a result — the job
  reports the cache hit's outcome, not this commit's.
- The job is *added* but branch protection is never updated to require it, so
  a red CI-01 run does not actually block merge — the PR merges anyway on
  human override, reproducing "merged on a local green" one layer up (now
  "merged despite a remote red").

**Why it happens:**
The existing placeholder (`echo` + `exit 0` under a "real checks land in Phase
7" comment that was never honored) is the template for what "CI exists"
means in this repo's history — two milestones already passed review with it
present and inert. The retrospective's own language is explicit: CI-01 is "the
standing debt most implicated in this milestone's dominant failure mode."
Replacing a no-op with a job that merely *executes* (rather than one that is
provably able to *fail on a real regression*) satisfies "CI exists" without
satisfying "CI enforces."

**How to avoid:**
Treat CI-01 itself under the repo's own standard: **a guard is not shipped
until it has been observed failing.** Concretely:
1. Land the workflow, then open a throwaway PR (or a scratch branch) that
   introduces one deliberate regression — e.g. revert a single character in a
   passing fixture's expected value, or delete one guard line from a
   migration — and confirm the *GitHub Actions UI* shows red, not just that
   `run-tests.sh` prints FAIL to a log nobody reads. This is the CI-equivalent
   of the mutation gate that closed Phase 9.1's dead assertions.
2. Assert `submodules: recursive` is present by grep-testing the workflow YAML
   itself in `run-tests.sh` (a document-contract check on the CI config,
   mirroring the "match the guard's executable shape, not a comment" fix from
   CR-03) so a future edit that drops the submodule flag is caught by the
   local suite before it ever reaches GitHub.
3. Require the CI-01 job as a required status check on the branch protection
   rule for `main` — verify this via `gh api repos/:owner/:repo/branches/main/protection`
   or the GitHub UI, not by assuming "added a workflow" implies "gates merge."
4. Fail the job on the drift check with a hard `exit`, not a warning-only step.
5. Do not merge v0.8.0's own PR on a local green — this milestone is the first
   to have a real CI-01 to merge against; use it on itself.

**Warning signs:**
- The workflow YAML has no step that intentionally fails in a smoke test.
- `submodules:` is absent from the `checkout` action, or set to `false`
  (GitHub Actions' default) rather than `recursive`.
- Any `|| true`, `continue-on-error: true`, or piping through a command that
  always returns 0 appears anywhere in the job.
- Branch protection settings do not list the new job as a required check.
- The PR that lands CI-01 is itself merged before anyone has watched it go red
  once.

**Phase to address:**
The CI-01 phase, which PROJECT.md states **lands first** in v0.8.0 as the
prerequisite for trusting every other fix. This ordering is a milestone
constraint, not a suggestion — every later phase's "observed failing" claim is
only as credible as CI-01's own proof that it can fail.

---

### Pitfall 2: Migration 0007's fix repeats V-01 verbatim inside the new migration

**What goes wrong:**
0007's pre-flight (`0007-knowledge-capture.md:58-65`) greps
`skills/agentic-apps-workflow/SKILL.md` in the *target project's* working
directory — a scaffolder-relative path no real target project has (a target
project's surface is `AGENTS.md`, `.planning/`, `.codex/`, `docs/decisions/`
only, per PROJECT.md and 0008's own framing note at `0008:65-72`). 0008
already named and refused to replicate this exact bug, switching instead to
reading `.codex/workflow-version.txt` (0008:73). The new forward migration
that fixes 0007's chain break is written to have **its own** pre-flight, and
the most direct way to ship it wrong is to write that pre-flight the same way
0007's was written the first time:
- Grepping any `skills/**/SKILL.md` path relative to the target project's CWD,
  instead of `.codex/workflow-version.txt`.
- Copy-pasting 0008's or 0009's pre-flight block as a starting template
  (a reasonable move — they are the two migrations that already got this
  right) but forgetting to re-derive the version-floor grep for the specific
  version this new migration's `from_version`/`to_version` requires, so the
  floor accepts or rejects the wrong range.
- Writing the new migration's *fixture* the same way Phase 9's fixtures were
  written for 0009 before Phase 9.1: the test harness manufactures a
  `skills/agentic-apps-workflow/SKILL.md` file in the sandbox that no real
  install has (the exact malpractice `run-tests.sh:918-919` already refused
  once for 0009), which would let a reintroduced scaffolder-relative-path bug
  pass 100% green a second time.

**Why it happens:**
This is not a novel mistake to avoid — it is *the same author process*
(write migration → derive pre-flight by analogy to a nearby migration →
write fixture that asserts the happy path) that produced the bug the first
time, now applied to fixing it. The retrospective calls this out directly:
"When a past migration documents a defect and refuses to replicate it, read
the refusal before writing the next one... 0008 left a written warning naming
this exact bug, with a regression fixture attached. 0009 reintroduced it in
all three locations anyway." The failure is not ignorance of the bug — it is
that documenting a bug in prose does not, by itself, prevent a mechanically
identical bug three migrations later, because "0007's bug" and "this new
migration's pre-flight" are different files that nobody diffs against each
other by habit.

**How to avoid:**
1. The new migration's pre-flight version-floor check must grep
   `.codex/workflow-version.txt`, not any `skills/**/SKILL.md` path — this is
   a direct copy of 0008's fix (`0008:73-79`), not a fresh design.
2. Add a fixture that asserts this by *shape*, not by mention: check the
   pre-flight block's literal executable line references
   `.codex/workflow-version.txt` and does **not** contain any
   `skills/agentic-apps-workflow` or `skills/.*SKILL\.md` substring — mirroring
   CR-03's fix (match the guard's shape, not a comment that happens to contain
   the right words).
3. Run the new migration's fixture against a **sandbox that reflects a real
   target project's file layout** — i.e., do NOT create
   `skills/agentic-apps-workflow/SKILL.md` in the test fixture at all. If the
   pre-flight needs that file to exist for the test to pass, the test has
   reproduced the exact manufactured-precondition failure from v0.7.0 and the
   fixture itself is the defect.
4. Before merging, grep the new migration document for `skills/` and manually
   justify every hit against "does this path exist in a *scaffolded target
   project*, or only in *this scaffolder repo*" — this is the check V-01's
   root cause needed and never got.
5. Confirm via `git blame`/diff against `0008-plan-review-gate.md:54-79`
   verbatim, since that block is the known-good reference this repo has
   already validated in production.

**Warning signs:**
- The new migration's pre-flight contains the string `skills/agentic-apps-workflow/SKILL.md`
  anywhere outside of a comment explaining why it must NOT be used.
- The fixture's `setup_sandbox`-equivalent function creates a
  `skills/agentic-apps-workflow/SKILL.md` file that would not exist in a real
  target project scaffolded by this host.
- The suite is green but nobody has run the migration against an actual
  scaffolded fixture project (not the scaffolder's own repo) and inspected
  `.codex/workflow-version.txt` afterward.

**Phase to address:**
The Migration-0007-chain-break phase (new forward migration, next in the
chain after 0009 — likely numbered 0010). This phase must explicitly cite
0008:54-79 as the reference implementation and 0009's V-01/Phase-9.1 history
as the failure mode being avoided a third time.

---

### Pitfall 3: Floor-version gates abort on real installs (0007's twin failure, not just its path bug)

**What goes wrong:**
Distinct from Pitfall 2's exact-path repeat, this is the more general shape:
any newly written pre-flight version-floor grep that is too narrow (accepts
only one exact version string instead of a range spanning "current or
next-in-line," as 0008/0009 both correctly do with `^0\.(N|N+1)\.0$`) aborts
on a project that has already been partially migrated or sits one version
ahead due to a re-apply. WR-03 in `0009-spec-11-region-aware-placement.md:96-98`
is the concrete instance the repo already found: the abort message says
"(need 0.6.0)" when the gate actually accepts `0.6.0` **or** `0.7.0`,
misdirecting an operator on `0.7.1` to an unachievable target. A floor gate
that is technically correct in its `grep -qE` condition but wrong in its
*diagnostic message*, or one that uses `grep` without `-m1` and interpolates a
multi-line match into a single-line abort message, both count as "nominal" —
the guard fires, but tells the operator to do the wrong thing or prints
garbage.

**Why it happens:**
Floor checks are written once per migration by analogy, and the
diagnostic-message half is treated as cosmetic rather than load-bearing —
but for an operator debugging a failed migration in production, the message
IS the interface. Nobody fixture-tests prose.

**How to avoid:**
- Any new pre-flight floor gate must state its accepted range in both the
  `grep -qE` pattern and the abort message, generated from the same source
  value (not hand-duplicated), e.g. `echo "need 0.5.0 or 0.6.0"` derived from
  the same variable the regex uses, not restated by hand.
- Add `-m1` to every `grep -E '^version:'`/`^0\.` extraction used inside an
  abort message, per WR-03's fix.
- Add a fixture asserting the exact abort text for an out-of-range version,
  not just the exit code — this is what would have caught WR-03 originally
  (the exit code was correct; only the message lied).

**Warning signs:**
- An abort message names a single version when the regex condition accepts
  two.
- Any `grep -E '^version:'`-style extraction used in an interpolated string
  without `-m1`.

**Phase to address:**
Same phase as WR-03's fix (currently listed under the `09-REVIEW.md` debt
item, but WR-03's *symlink* item is separately scoped as its own numbered
fix — this version-message defect should be folded into whichever phase
touches `0009`'s pre-flight text, or the Migration-0007-chain-break phase if
that phase's own new floor gate is being hand-authored fresh).

---

### Pitfall 4: Paired §11 markers narrow the terminator and silently regress the widened three-way invariant

**What goes wrong:**
The Constraints section is explicit and already names the exact failure
shape: "the injected §11 block must remain followed by a `## ` heading, an
anchored `<!-- gitnexus:start -->` marker, **or** EOF... every terminator
that bounds it must carry this same three-way alternation." Paired
start/end markers are being introduced specifically to retire the
inference-based defect class (AG-01's region-tail hazard) — but implementing
"look for the end marker" as the *only* termination condition, rather than
adding it as a **fourth** alternative alongside the existing three, silently
narrows the alternation. Concretely:
- A new `<!-- coding-discipline:end -->` (or similar) marker is introduced,
  and the strip/insert AWK is rewritten to terminate solely on that marker,
  dropping the `## ` / `gitnexus:start` / EOF fallback that pre-existing
  (already-migrated) projects still rely on, because their §11 block was
  injected by 0001/0004/0009 and has no paired end marker yet.
- The new marker's own regex is written unanchored (repeating CR-02's exact
  mistake: a prose mention of the new end-marker string, e.g. in this very
  migration's own abort/help text, latches the strip the same way the
  provenance comment did).
- `12-idempotent-rerun` — named explicitly as "ANCHOR-05's only live coverage
  of the strip terminator's alternation" — is not re-run against the new
  paired-marker code path, or is modified/deleted rather than kept as a live
  regression guard, because it currently encodes assumptions from the
  region-only anchor world.
- The transition period (some projects have paired markers, others still
  have the old single-marker managed block) is not represented as its own
  fixture state; the migration only tests "brand new marker present" and
  "no marker at all," missing "old-style single marker, no end marker yet —
  must still terminate correctly using the pre-existing three-way alternation
  until this project's own migration adds the pairing."

**Why it happens:**
"Retiring the inference-based defect class" sounds like it should *replace*
the inference (the three-way alternation), when what it actually needs to do
is *add an unambiguous option* that inference-based termination falls back
to only when a pair isn't present yet — anything less leaves already-migrated
projects (the majority of the fleet, everyone at 0.7.0+) relying on the old
alternation, which must therefore keep working. The Constraints section
already documents this widening once (ANCHOR-05); the paired-marker work is
exactly the kind of "this area is now safe" mental model the retrospective's
Key Lesson 3 warns about — v0.7.0 hardened the anchor and shipped a
destruction bug in the adjacent strip mechanic. Paired markers hardening the
*strip's entry/exit* is the same adjacency risk one level further in.

**How to avoid:**
1. Treat the paired end-marker as a fourth alternative in the terminator
   alternation, never a replacement: `/^## /` **or** `/^<!--
   gitnexus:start -->$/` **or** the new end marker **or** EOF.
2. Anchor the new end-marker's regex on both ends from the start (learn CR-02
   directly — do not ship it unanchored and wait for a review to catch it a
   second time).
3. Keep `12-idempotent-rerun` running unmodified against the new code and add
   a sibling fixture, `13-mixed-marker-fleet` or similar, that exercises an
   AGENTS.md with the *old* single-marker managed block (no end marker) and
   asserts it still terminates correctly via the pre-existing alternation —
   this is the fixture that proves "widened, not narrowed."
4. Mutation-test the new terminator exactly as Phase 9.1 did: delete each
   alternative one at a time (the `## ` branch, the `gitnexus:start` branch,
   the new end-marker branch, the EOF fallback) and confirm each deletion
   independently turns `12-idempotent-rerun` (or its sibling) red. If any one
   deletion leaves the suite green, that alternative is dead weight the same
   way `test -s` was in CR-03.
5. Amend ADR-0010 with a dated Correction (per the established pattern from
   D-21/D-26) rather than silently rewriting the invariant's wording —
   the Constraints section is explicit that this document must be read
   "before narrowing any terminator."

**Warning signs:**
- The new migration's terminator AWK has fewer than four alternation branches
  once paired markers land, unless a fixture and ADR correction explicitly
  justify retiring one.
- `12-idempotent-rerun` is edited in the same PR that lands paired markers
  without an accompanying explanation of exactly what changed and why it
  still discriminates.
- No fixture exercises a project whose §11 block predates the pairing (no end
  marker present).
- The new end-marker regex is written without `^`/`$` anchors.

**Phase to address:**
The paired-§11-markers phase (ADR-0010's lead open follow-up, closing AG-01).
This phase inherits the Constraints section's structural invariant as a
hard acceptance criterion, not a nice-to-have — a PR that narrows the
alternation should fail CI-01 (once that lands) via `12-idempotent-rerun`
going red, which is the entire point of sequencing CI-01 first.

---

### Pitfall 5: HOOK-01 ships a config that is never invoked, or fires globally and blocks nothing scoped

**What goes wrong:**
ADR-0009's own rejection of Option B already names two of the three concrete
failure shapes, and a fourth is added by the general "asserted without
observing" pattern this repo has already been burned by once (ADR-0001's A2
on the `~/.codex/AGENTS.md` load path, corrected empirically in the current
Context section):
1. **Wrong event name / wrong hook surface shape.** `~/.codex/hooks.json`'s
   actual schema, event names, and matcher syntax on the installed codex-cli
   version are assumed from Claude Code's `PreToolUse` hook shape (the
   closest known analog) rather than observed on codex-cli directly. If the
   real schema differs (different key name, different matcher glob syntax, a
   different exit-code convention for "block" vs. "warn"), the hook config is
   syntactically accepted but never actually intercepts the tool call it's
   meant to gate — a config that parses cleanly and fires never.
2. **Not installed by the scaffolder.** The hook binding is written into
   `templates/config-hooks.json` or a new hooks template, but the scaffolder
   skill (`setup-codex-agenticapps-workflow`) is never updated to actually
   *write* `~/.codex/hooks.json` (a global, machine-scoped file, not a
   per-project one) during install — so every fresh scaffold and every
   migration replay both look correct in the repo's own template files while
   no real machine ever gets the hook registered.
3. **Global scope, unscoped.** ADR-0009 already flags this: "the hook is
   global, so it fires in every repo on the machine and must self-scope."
   If the shipped hook config omits a path/cwd matcher (or the matcher syntax
   is wrong per point 1), it either fires in every unrelated repo on the
   machine (false-positive blocking on projects with no plan-review gate at
   all) or, if codex-cli fails closed on a matcher error, fires nowhere.
4. **Trust-ledger silently skipped.** ADR-0009 names a sha256 trust ledger
   that "forces a re-grant every time a migration edits the hook config." If
   the new migration writes/edits `~/.codex/hooks.json` without accounting
   for this, either the install silently fails to activate (operator never
   re-grants, hook stays dormant) or — worse — the migration is written
   assuming no re-grant is needed because it was never observed on a real
   codex-cli install, and ships broken the same way ADR-0001's A2 did.
5. **Wrong exit-code convention.** `check-plan-review.sh` already returns a
   tri-state contract (`$?` — pass / block `exit 2` / fail-open) for the
   *agent-mediated* call path. If codex-cli's native hook surface interprets
   exit codes differently (e.g., only 0 vs. nonzero, collapsing the tri-state
   the resolver depends on), wiring the same script directly into the hook
   without an adapter either always blocks (fail-open case now blocks) or
   never blocks (ambiguous case now passes) — a silent contract mismatch, not
   a bug in the script itself.

**Why it happens:**
This repo has already made this exact category of mistake once and
documented it: "ADR-0001's A2 had asserted [the AGENTS.md load path] without
observing it" — verified only empirically, after the fact, on codex-cli
0.144.4. HOOK-01 asks for the same kind of claim (a runtime hook surface's
actual behavior) at a strictly higher stakes level: a *load path* being wrong
means one instruction is missed; a *hook surface* being wrong means an
entire enforcement mechanism silently degrades back to the "agent-mediated"
status quo HOOK-01 exists to supersede, while the ADR and the roadmap both
now claim it is "unconditional."

**How to avoid:**
1. Before writing any hook config, empirically observe `~/.codex/hooks.json`'s
   real schema, event names, matcher syntax, and exit-code convention on the
   actual installed codex-cli version — the same discipline that corrected
   ADR-0001's A2. Do this by consulting codex-cli's own docs/source (via
   Context7 if indexed, or the installed binary's `--help`/schema reference)
   and by a live smoke test, not by analogy to Claude Code's `PreToolUse`.
2. Ship a minimal *observed-failing* proof before the real gate: install a
   trivial hook that blocks something innocuous (e.g., a hook matching `ls`
   in a scratch repo) and confirm it actually intercepts on the real machine.
   Only once that is proven does wiring `check-plan-review.sh` into the same
   surface count as validated.
3. Explicitly test the self-scoping matcher against a **second, unrelated
   repo on the same machine** — confirm the hook does NOT fire there. This is
   the direct test of ADR-0009's named global-scope risk.
4. Confirm the scaffolder skill is updated to write/merge
   `~/.codex/hooks.json` on both fresh install and migration replay, and add
   a fixture asserting the file's content post-scaffold — mirroring MIGR-08's
   own fix (a fixture that runs the Apply block and asserts the written
   file, not just "correct by inspection").
5. Document the trust-ledger interaction explicitly in the ADR amendment (per
   PROJECT.md's plan to amend ADR-0009 d.9 → HOOK-01) — including whether a
   migration-driven edit requires a manual re-grant step the operator must be
   told about.
6. Restate ADR-0009 criterion 1 as "unconditional block" only after a real
   blocked-tool-call has been observed on a live codex-cli session, not on
   passing a unit test of the script in isolation.

**Warning signs:**
- No commit or test artifact shows a real (not simulated) codex-cli session
  where a tool call was actually intercepted by the new hook.
- The hook config's matcher is copied from a Claude Code `PreToolUse` example
  without a citation to codex-cli's own hook documentation or an empirical
  check against the installed binary.
- The scaffolder's install/migration steps write the hooks template into the
  repo but never touch `~/.codex/hooks.json` itself.
- No fixture exercises "hook fires in repo A, not in repo B" on the same
  machine.
- `check-plan-review.sh`'s exit codes are wired directly into the hook without
  an explicit statement of how codex-cli's hook surface maps exit codes to
  "block" vs. "allow" vs. "ambiguous."

**Phase to address:**
The HOOK-01 phase. Given CI-01 lands first per milestone constraint, and this
pitfall's prevention requires *manual, empirical, live-session* observation
that automated CI cannot substitute for, this phase should explicitly budget
time for a human-observed smoke test as a named acceptance criterion, not
just a code review pass.

---

### Pitfall 6: MIGR-08 (and any new fixture) asserts a value the setup already guarantees, or greps a file that always exists

**What goes wrong:**
MIGR-08 execution coverage is explicitly scoped as "a fixture that runs the
Apply block and asserts the written `.codex/workflow-version.txt`" —
"correct by inspection... but untested," flagged by Phase 9.1's verification
as "the one residual of the exact class that phase existed to close." Ways
this specific fixture (and any new fixture written for the other six v0.8.0
items) ships vacuous:
- The fixture's sandbox setup pre-creates `.codex/workflow-version.txt` with
  the *post-migration* value already in it (a copy-paste from a nearby
  fixture that sets up post-state for a different assertion), so the
  assertion "file contains the new version" passes whether or not the Apply
  block actually wrote anything.
- The assertion greps for the *file's existence* (`test -f
  .codex/workflow-version.txt`) rather than its *specific written content*
  matching the *new* version — passes even if the Apply step silently no-ops
  and the file is left at its pre-migration value from setup.
- The "mutation gate" is described in the plan/SUMMARY as having been run,
  but the actual delete-observe-restore cycle is never executed against a
  scratch clone — i.e., the fixture is asserted to have been mutation-tested
  by prose in a SUMMARY.md, mirroring exactly the failure mode Retrospective
  Key Lesson names for both milestones ("green does not mean verified" /
  "a suite can be fully green against software that never executes" — apply
  the same skepticism to a *test* as to the code, since the retrospective's
  Patterns Established section states "Re-verification re-executes; it does
  not read summaries").
- The document-contract check (if MIGR-08's fixture also asserts the
  migration document's Apply block *text* contains the right write) matches
  a comment or nearby prose string rather than the executable line — the
  exact CR-03 shape, generalized.

**Why it happens:**
This is the repo's single most-repeated failure mode across both prior
milestones (documented explicitly under "Recurring Failure Mode": "tests that
pass without exercising the thing they name"), and MIGR-08 is the literal
named residual of it. The natural failure vector for *this specific fixture*
is sandbox setup reusing boilerplate from a sibling fixture that already has
the target file in its final state, because writing sandbox setup from
scratch for every fixture is tedious and copy-paste is the path of least
resistance.

**How to avoid:**
1. The sandbox for MIGR-08's new fixture must start from the *pre-migration*
   version string in `.codex/workflow-version.txt` (whatever this migration's
   `from_version` is), never the post-migration value.
2. The assertion must diff the file's content before and after running the
   Apply block, not just check post-state existence or a `grep -q` for the
   new value alone (which could pass on a file that already held it).
3. Apply the mutation gate literally: comment out (or delete) the `echo
   "$NEW_VERSION" > .codex/workflow-version.txt` line inside the Apply block,
   re-run the fixture, and confirm it goes RED. Record the before/after in
   the plan's SUMMARY.md as PASS→FAIL evidence — an actual commit or terminal
   transcript, not a claim.
4. Since verification "re-executes; it does not read summaries" is already
   the repo's standard, the verifier for this phase should independently
   perform the same delete-observe-restore cycle on a scratch clone, exactly
   as Phase 9.1's verification did for the terminator alternation — do not
   accept the executor's mutation-test claim as sufficient on its own.
5. Extend the same discipline to every *other* new fixture this milestone
   adds (WR-03's guard, HOOK-01's hook-fires assertion, the paired-marker
   terminator fixtures, the new migration's floor-check fixture) — MIGR-08 is
   the named example, but the standard is milestone-wide per PROJECT.md's own
   text: "this repo's own standard applies to this milestone's work."

**Warning signs:**
- A fixture's sandbox setup function is copy-pasted from a sibling fixture
  without re-deriving which state variables are pre- vs. post-migration.
- Any assertion is `test -f <file>` or `grep -q <value>` where `<value>` could
  plausibly already be present from setup rather than from the code path
  under test.
- A SUMMARY.md claims "mutation-tested" or "observed failing" without a
  reproducible before/after (commit hash, terminal output, or a script that
  re-derives the same result).
- The verifier accepts a plan's self-reported mutation result rather than
  independently re-running the mutation.

**Phase to address:**
The MIGR-08-execution-coverage phase specifically, and as a cross-cutting
verification standard applied by whichever phase closes each of the other six
v0.8.0 items — this is the one pitfall that is genuinely milestone-wide rather
than tied to a single fix.

---

### Pitfall 7: WR-03's symlink guard is real-guard-shaped but still bypassable

**What goes wrong:**
WR-03's acceptance is explicitly reversed in v0.8.0 — replacing the
lexical-`..`-only check with "a real resolution guard." The retrospective
already names the general pattern this repo trusts ("guard *ordering* is the
fix, not guard presence — `[ -L ]` must run strictly before `[ -f ]`, because
`[ -f ]` dereferences and returns true for a live symlink"), but a
realpath/canonicalization-based guard specifically invites these bypasses if
implemented carelessly:
- **TOCTOU (time-of-check-to-time-of-use).** The guard resolves the path
  (`realpath`/`readlink -f`) once, validates it's inside the allowed root,
  then a later step in the same script re-opens the *original* (unresolved)
  path rather than the canonical one it just validated — an attacker who can
  race a symlink swap between the check and the use defeats the guard even
  though the guard itself is "correct."
- **Resolving after the check instead of before.** If the containment check
  runs against the *raw* `--file` argument and only *then* calls
  `realpath`/dereferences it for the actual read, the check validates a path
  that is not the one ultimately used — the canonical fix must validate the
  *resolved* path, not the literal argument.
- **Symlink in a parent path component, not the leaf.** A guard that only
  checks whether the final path component is a symlink (`[ -L "$file" ]`)
  misses a symlinked *directory* earlier in the path — e.g.
  `.planning/phases/08/PLAN.md` where `phases` itself is a symlink out of the
  project root. `realpath`/`readlink -f` resolves the whole chain and is
  required precisely because a leaf-only `[ -L ]` check (as WR-03's current
  lexical-`..`-only implementation effectively is) cannot see this.
- **`..` reappearing after canonicalization.** If containment is re-checked
  by string-matching the *resolved* absolute path for a leading prefix, but
  the prefix comparison is done as a naive substring check rather than a
  proper path-boundary check (`case "$resolved" in "$root"/*)`), a sibling
  directory that merely shares the prefix as a string
  (`/repo/.planning-evil/` vs. `/repo/.planning/`) can pass a substring-only
  containment test. This echoes the repo's own established pattern from
  v0.6.0: "Reject on shape, never normalize-then-test — `..`-component
  rejection runs before the prefix+basename test, so a traversal resolving
  back onto a real canonical artifact is still rejected." The equivalent for
  WR-03 is: validate containment on the fully-resolved path using a proper
  path-boundary comparison, not a string prefix.

**Why it happens:**
Realpath-based guards feel categorically stronger than lexical ones (they
are, for most attacks), which makes it easy to treat "we now call
`realpath`" as sufficient without separately verifying ordering (resolve
*before* checking, not after), scope (whole-path resolution, not leaf-only),
and comparison shape (path-boundary, not substring) — each of which is an
independent way for a "real" guard to still be bypassable. The repo's own two
already-established patterns (`[ -L ]` before `[ -f ]`; reject on shape before
normalize-then-test) are exactly the right instincts, but they were
established for a *different* class of check (containment via lexical `..`
rejection) and must be re-derived, not assumed to transfer automatically, for
a resolution-based check.

**How to avoid:**
1. Resolve the path once, early, with `realpath`/`readlink -f` (whichever is
   POSIX-portable per this repo's shell constraint), and perform every
   subsequent operation — the containment check AND the actual file read —
   against that single resolved value. Never re-derive or re-open the
   original unresolved argument after the check.
2. Compare containment with a path-boundary test
   (`case "$resolved" in "$root"/*) ... ;; esac`, or equivalent), never a bare
   string prefix (`${resolved#$root}` alone is insufficient without
   confirming a following `/` or exact match).
3. Write a fixture with a symlinked *parent directory* (not just a symlinked
   leaf file) pointing outside the allowed root, and confirm the guard
   rejects it — this is the specific case a leaf-only `[ -L ]` check cannot
   catch and the lexical-`..`-only guard being replaced likely also missed.
4. Write a fixture for the sibling-prefix-collision case
   (`/repo/.planning-evil/x` vs `/repo/.planning/`) to prove the containment
   check is boundary-aware, not substring-based.
5. Mutation-test: swap `realpath` for a no-op (or the earlier lexical-only
   check) and confirm the new symlinked-parent and sibling-prefix fixtures go
   RED — proving they discriminate the improvement, not just re-confirming
   what the old guard already caught.
6. Amend ADR-0009 decision 12 to record the reversal and cite the concrete
   TOCTOU/parent-symlink/prefix-collision cases considered and closed, per
   PROJECT.md's stated plan.

**Warning signs:**
- The guard calls `realpath` in one place but a later read/open in the same
  code path uses the original `$file` variable, not the resolved one.
- Containment is checked with `${resolved#"$root"}` or similar without also
  confirming the stripped prefix was followed by `/` or was an exact match.
- No fixture exercises a symlinked parent directory.
- No fixture exercises a sibling directory whose name is a string-prefix
  superset/subset of the allowed root's name.

**Phase to address:**
The WR-03 phase (acceptance-reversal item, ADR-0009 d.12 amendment).

---

## Moderate Pitfalls

### Pitfall 8: 09-REVIEW.md's four residual items regress independently if bundled into one "cleanup" plan

**What goes wrong:**
WR-05, IN-01, IN-02/IN-03 (info-only, unlikely to need code fixes), and IN-04
are different defect *shapes* and each has its own specific miss-mode if
treated as one undifferentiated "review cleanup" task:
- **WR-05 (banner determinism):** `validate-0009-anchor.sh`'s banner claims to
  be deterministic but embeds `wc -l < "$MIRROR"` and derived line numbers.
  The fix (drop the mirror line count from output, or narrow the
  determinism claim to "stable for a given mirror revision") is easy to ship
  only half — e.g. removing the line count from the banner text but leaving a
  derived "gitnexus:start at line N" PASS message elsewhere, so the claim is
  still contradicted by output the fix didn't touch. **Prevention:** grep the
  entire script for every place a mirror-derived number reaches stdout, not
  just the banner block, before declaring this closed.
- **IN-01 (`### Step 1` prefix-matching `### Step 10`):** harmless today (0009
  has 3 steps) but the fix ("match on the delimiter too") must be verified
  against a *synthetic* 10+-step document, since no real migration currently
  has that many steps — a fixture that only re-tests today's 3-step documents
  cannot discriminate the fix from a no-op. **Prevention:** the fixture must
  construct a document with `### Step 1` and `### Step 10` from a
  synthetic/generated document, not one of the real migration files.
- **IN-04 (predictable temp names / symlink attack):** the review itself
  scores this "low real-world risk... noted for completeness," and its
  suggested fix is `mktemp` in the project dir to preserve the
  `mv`-is-same-filesystem atomicity property. The risk of shipping this
  nominally is treating "switch to `mktemp`" as complete without re-verifying
  the atomic-`mv`-same-filesystem property still holds (a `mktemp` call
  without `-p .` or an equivalent in-project-dir flag could place the temp
  file on a different filesystem/tmpfs, breaking the atomicity the original
  fixed-name approach had). **Prevention:** a fixture asserting the temp file
  and the target file report the same `st_dev` (device number), or
  equivalently that `mv` (not `cp`+`rm`) is the operation actually used
  post-fix.
- **IN-03 (ADR/migration numbering collision):** the review's own fix
  recommendation is "no code change... consider an explicit numbering-is-
  independent note" — the pitfall here is *not* writing that note (treating
  "info" severity as "no action needed" when the milestone's downstream
  consumer — a future author reading `docs/decisions/README.md` — is exactly
  who the confusion affects). **Prevention:** confirm the note actually landed
  in `docs/decisions/README.md`, not just discussed.

**Why it happens:** Bundling four structurally different findings into one
generic "close the review debt" plan encourages treating them at uniform
depth, when the review's own severity levels (warning vs. info) do not map to
uniform effort — WR-05 and IN-04 need new fixtures with specific
discriminating power; IN-03 needs a documentation edit with no fixture at
all; IN-01 needs a synthetic document a real fixture doesn't yet have.

**Prevention:** Scope each of WR-05, IN-01, IN-02, IN-03, IN-04 as separate
named acceptance criteria within the phase, each with its own stated
verification method (fixture vs. doc-diff), rather than one criterion
"09-REVIEW.md items addressed."

**Phase to address:** The `09-REVIEW.md` debt phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Writing a new migration's pre-flight by copy-paste from the nearest prior migration without re-deriving the version-floor grep and diagnostic message from first principles | Faster to draft | Re-ships V-01's path bug or WR-03's message-mismatch bug in a new location | Never for the version-floor grep; acceptable only for boilerplate (jq/git-repo checks) that is genuinely identical across migrations |
| Treating a SUMMARY.md's "mutation-tested" claim as sufficient evidence at verification time | Saves the verifier from re-running the mutation | Reintroduces exactly the failure the mutation gate exists to prevent — "green does not mean verified" applies to test reports as much as to code | Never — Patterns Established already states verification re-executes, does not read summaries |
| Shipping the paired-§11-marker terminator as a replacement for the three-way alternation rather than a fourth branch | Simpler AWK, fewer branches to reason about | Regresses every already-migrated project (majority of the fleet) that has no end marker yet; silently reopens ANCHOR-05 | Never during the transition period; only after every live project has been migrated to carry the pair, which is likely a multi-milestone horizon |
| Marking HOOK-01 "done" on a passing unit test of `check-plan-review.sh` in isolation, without a live codex-cli session showing the hook actually intercepted a tool call | Avoids the friction of a manual/human-observed test in an otherwise automatable milestone | Reproduces ADR-0001 A2's exact "asserted without observing" failure at the enforcement layer this milestone exists to fix | Never — this is the one item in the milestone where a human-observed live test is a first-class acceptance criterion, not an optional nicety |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| GitHub Actions + `submodules: recursive` | Omitting the flag, or setting `submodules: true` (shallow, non-recursive) when `vendor/agenticapps-shared` itself has nested content the harness needs | Explicitly set `submodules: recursive` on the checkout step and assert its presence via a document-contract grep on the workflow YAML in the local suite |
| GitHub branch protection + a new required check | Adding the CI-01 job without adding it to the branch protection rule's required-checks list, so a red run doesn't block merge | After landing the job, verify via `gh api repos/:owner/:repo/branches/main/protection` (or the UI) that the new check name appears in required checks |
| `~/.codex/hooks.json` native hook surface | Assuming schema/event names/exit-code semantics by analogy to Claude Code's `PreToolUse`, as ADR-0001's A2 already did once for the AGENTS.md load path | Empirically observe the real schema on the installed codex-cli version before writing the hook config; smoke-test on a live session before claiming "unconditional block" |
| jq-based config merges (0007/0008 idiom) reused in the new migration | Assuming the merge idempotency check (`jq -e '.knowledge_capture'`) generalizes without re-deriving the correct key path for whatever block the new migration adds | Re-derive the idempotency check's `jq -e` path from the specific block being written, and fixture-test both the "already present" and "not yet present" branches independently |

## Performance Traps

Not applicable at the scale this milestone operates — all fixes are
CI/migration/shell-script correctness work on a low-volume internal tooling
repo, not a runtime-scale system. No performance traps identified; omitted
rather than padded with generic advice.

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| WR-03's realpath guard checks containment on the raw argument, then reads/writes the *original* unresolved path afterward (TOCTOU) | An attacker who controls a symlink target between check and use can redirect the operation outside the allowed root even though the guard logic is "correct" | Resolve once, operate on the resolved value everywhere downstream; never re-derive the original path post-check |
| CR-02-shaped defect reintroduced in the new paired-marker end-marker regex (unanchored match on a marker string) | A prose mention of the new end-marker text (e.g., in the migration's own abort/help output, or in a project's documentation of its own managed sections — the exact scenario CR-02's repro used) arms a destructive strip | Anchor every new marker/provenance regex with `^`/`$` from the first draft; add the "prose mention is not a region" fixture in the same PR that introduces the marker, not as a follow-up |
| HOOK-01's global hook fires unscoped across unrelated repos on the same machine | A gate meant for this workflow's projects silently blocks or misfires in unrelated repositories, or (if the matcher itself errors) fails open globally, downgrading enforcement everywhere at once rather than just failing to help in one repo | Explicitly test the self-scoping matcher against a second, unrelated repo on the same machine before considering HOOK-01 complete |
| IN-04's fixed-name temp files in the project CWD, if "fixed" with a careless `mktemp` call that doesn't stay same-filesystem | Breaks the atomic-`mv` property (temp file lands on a different filesystem than the target, forcing a non-atomic copy) while appearing to "fix" the symlink-follow risk | Use `mktemp -p .` (or equivalent in-project-dir flag) and add a fixture asserting `mv`, not `cp`, is the operation used to commit the result |

## "Looks Done But Isn't" Checklist

- [ ] **CI-01:** Workflow file exists and runs green — verify it has actually
      been observed to go RED on a deliberate regression, and that the job
      is a *required* status check on branch protection, not merely present.
- [ ] **Migration 0007's fix:** New migration document exists with a
      corrected pre-flight — verify the fixture's sandbox does NOT
      manufacture `skills/agentic-apps-workflow/SKILL.md`, and that the
      pre-flight greps `.codex/workflow-version.txt` exclusively.
- [ ] **HOOK-01:** `~/.codex/hooks.json` config is written by the scaffolder
      and migration — verify a live, human-observed codex-cli session shows
      a tool call actually intercepted, and that the same hook does NOT fire
      in a second, unrelated repo on the same machine.
- [ ] **Paired §11 markers:** New start/end marker regexes exist and are
      anchored — verify the terminator alternation gained a branch rather
      than losing one, via a fixture on a pre-existing (unpaired) project
      alongside the new-marker fixture, and that `12-idempotent-rerun` still
      passes unmodified or with a documented, justified change.
- [ ] **MIGR-08 execution coverage:** A fixture "runs the Apply block" —
      verify the fixture's sandbox starts from the pre-migration version
      string (not the post-migration one already present from setup), and
      that deleting the write line turns the fixture RED.
- [ ] **WR-03:** A realpath-based guard replaces the lexical-`..` check —
      verify containment is checked on the *resolved* path with a
      boundary-aware comparison, and that a symlinked *parent directory*
      fixture (not just a symlinked leaf) is rejected.
- [ ] **09-REVIEW.md items:** WR-05/IN-01/IN-04 marked closed — verify each
      against its own specific discriminating fixture (synthetic 10-step
      document for IN-01; same-`st_dev`/`mv`-not-`cp` check for IN-04; full
      grep of the script for every mirror-derived stdout line for WR-05), not
      a single generic "review debt closed" checkbox.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|-----------------|
| CI-01 merges as a placeholder that runs but can't fail | MEDIUM | Add the deliberate-regression smoke test retroactively; if it doesn't go red, the job needs a real rewrite, not a patch — treat as unshipped until it does |
| New migration repeats V-01's scaffolder-relative path | LOW | Fix-forward with a subsequent migration (immutability holds); do not edit the broken one. Same remediation pattern already proven for 0007 itself |
| Paired markers narrow the alternation and a real project's §11/GitNexus region is destroyed on next apply | HIGH (destructive, git-history-dependent recovery) | `git checkout` on the affected file if caught before the next commit (per 0009's own documented rollback caveat); otherwise this is unrecoverable from the tool alone and requires manual restoration from history — this is precisely why the fixture/mutation-gate prevention must run before merge, not after |
| HOOK-01 ships inert (never actually intercepts) | LOW (nothing breaks, but nothing gates either) | Downgrade the roadmap/ADR claim back to "agent-mediated" until a live smoke test passes; do not let the ADR amendment ship ahead of the observed proof |
| WR-03's realpath guard has a TOCTOU or parent-symlink gap discovered post-ship | MEDIUM | Same fix-forward discipline as migrations — patch the script (it is not an immutable migration document), add the missing fixture, and mutation-test the patch itself before closing |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|---------------|
| CI-01 green-but-toothless | CI-01 phase (lands first, milestone-wide prerequisite) | Deliberate-regression smoke PR goes red in the GitHub UI; required-status-check confirmed via branch protection API |
| Migration 0007 fix repeats V-01's exact path bug | Migration-0007-chain-break phase | Fixture sandbox does not manufacture `skills/agentic-apps-workflow/SKILL.md`; pre-flight document-contract check greps only `.codex/workflow-version.txt` |
| Floor-version gate diagnostic mismatches its own condition (WR-03-message shape) | Whichever phase authors the new migration's pre-flight, or the WR-03 phase if folded in | Fixture asserts exact abort text for an out-of-range version, not just exit code |
| Paired §11 markers narrow the three-way terminator alternation | Paired-§11-markers phase (ADR-0010 follow-up) | `12-idempotent-rerun` unmodified-or-justified; new fixture on a pre-existing unpaired project; mutation gate on each of the four alternation branches independently |
| HOOK-01 ships inert or unscoped | HOOK-01 phase | Live, human-observed codex-cli session shows real interception; self-scoping confirmed against a second unrelated repo |
| MIGR-08 (and other new fixtures) assert vacuously | MIGR-08-execution-coverage phase, applied as a milestone-wide standard | Sandbox starts pre-migration; delete-observe-restore mutation on the write line; independent re-execution by the verifier, not summary-trust |
| WR-03 symlink guard remains bypassable after "fix" | WR-03 phase | Resolved-path-only operations (no TOCTOU); boundary-aware containment; symlinked-parent-directory and sibling-prefix-collision fixtures both present and mutation-tested |
| 09-REVIEW.md items closed nominally (WR-05/IN-01/IN-04) | `09-REVIEW.md` debt phase | Each item verified by its own specific fixture/grep, not a single bundled checkbox |

## Sources

- `.planning/RETROSPECTIVE.md` — v0.6.0 and v0.7.0 milestone retrospectives,
  "Recurring Failure Mode," "Patterns Established," "Key Lessons," and
  "Carried Debt" sections (primary source for the nominal-enforcement
  pattern this entire document is built against).
- `.planning/PROJECT.md` — Current Milestone (v0.8.0) target features and
  constraints; Context section documenting ADR-0001 A2's "asserted without
  observing" failure on the AGENTS.md load path; Key Decisions table.
- `.planning/phases/09-region-aware-11-placement/09-REVIEW.md` — CR-01/CR-02/
  CR-03, WR-01..WR-05, IN-01..IN-04 findings and reproductions (primary
  source for Pitfalls 4, 8, and the WR-03/HOOK-01 analogical reasoning).
- `migrations/0007-knowledge-capture.md:49-73` — the pre-flight defect being
  fixed forward (source of Pitfall 2/3).
- `migrations/0008-plan-review-gate.md:54-93` — the corrected pre-flight
  pattern (`.codex/workflow-version.txt`, not a scaffolder-relative path),
  and its explicit framing note naming 0007's defect and deferring its fix.
- `docs/decisions/0009-plan-review-gate.md:40-110` — Option B (native hook)
  rejection reasoning: global scope, trust-ledger re-grant, and the
  resolver's tri-state exit-code contract (source of Pitfall 5).
- `.planning/ROADMAP.md` — Known Follow-ups / Carried out of v0.7.0 section,
  confirming AG-01, the 0007 defect, and the 09-REVIEW.md items were all
  explicitly deferred rather than resolved, and are now in scope.

---
*Pitfalls research for: codex-workflow v0.8.0 "Enforcement, Not Intention"*
*Researched: 2026-07-16*
