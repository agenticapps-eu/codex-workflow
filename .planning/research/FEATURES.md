# Feature Research — v0.8.0 "Enforcement, Not Intention"

**Domain:** Internal tooling / migration-chain host binding (codex-workflow) —
sharpening the acceptance bar on seven already-scoped carried-debt items, not
discovering new product features.
**Researched:** 2026-07-16
**Confidence:** HIGH (all seven items grounded in direct source reads of
PROJECT.md, 09-REVIEW.md, RETROSPECTIVE.md, migrations 0007/0008,
migrations/README.md, run-tests.sh, check-plan-review.sh, and ADR-0009) —
no external ecosystem research was needed or performed; this is a codebase
audit, not a library/framework survey.

## Summary Table — Acceptance Bar Per Debt Item

| Item | Table-stakes acceptance (one sentence, testable) | Do NOT over-build |
|------|----|----|
| CI-01 | A GitHub Actions workflow on `push`/`pull_request` to `main`, checked out with `submodules: recursive`, runs `migrations/run-tests.sh` and the drift check, and the job fails (non-zero) when either does — proven by a scratch branch that reverts one guard and shows the workflow go red. | No lint, no shellcheck, no caching, no E2E "real scaffold + real update" smoke test in v0.8.0. A 2-OS matrix (`ubuntu-latest` + `macos-latest`) is borderline-table-stakes given this repo's own BSD/GNU portability comments — include it, it's ~3 lines, but do not add anything beyond OS matrix. |
| Migration 0007 chain break | A new forward migration (immutable-safe) whose pre-flight reads `.codex/workflow-version.txt` (0008's precedent) instead of the scaffolder-relative path, and whose Apply re-delivers 0007's Steps 1–2 payload (the `knowledge_capture` config block + AGENTS.md ritual-tail section) — proven by a fixture that starts a sandbox at `0.4.0` with none of 0007's artifacts, runs the extracted Apply blocks, and asserts both the config key and the AGENTS.md section exist, not just that the version file advanced. | Do not "fix" this by only bumping `.codex/workflow-version.txt` to a later number — that recreates the exact "recorded success without effect" bug class this milestone exists to close. Do not also silently re-deliver 0008's payload inside this same migration without saying so explicitly — see Dependencies below, this needs its own scoping decision. |
| HOOK-01 | `check-plan-review.sh --file <path>` is registered as a `PreToolUse` command in `~/.codex/hooks.json`, and a disallowed edit attempted through the real Codex CLI tool surface is observably blocked (non-zero hook exit prevents the tool call — not just a logged warning) — proven by an end-to-end run against a real `~/.codex/hooks.json`, not a unit test of the script in isolation. | Do not solve the general per-repo hook-scoping problem (ADR-0009 decision 9's "global, fires in every repo" concern) or build a trust-ledger re-grant automation. Point the existing global hook at the existing verifier and accept global scope; the verifier already self-locates its repo root and fails open outside a `.planning` tree. |
| Paired §11 markers | A new forward migration inserts explicit `<!-- BEGIN -->`/`<!-- END -->` markers bounding the §11 block on fresh and healed installs, and the strip/replace logic keys off those markers directly instead of inferring extent from heading + terminator alternation — proven by `12-idempotent-rerun` staying green and a new regression fixture reproducing AG-01 (§11 at a region's tail) that fails on the old inference logic and passes once markers bound the block. | Do not build a generic pluggable marker framework for arbitrary future managed blocks — scope the markers to §11 only, matching the existing outer `<!-- BEGIN/END: agentic-apps-workflow sections -->` idiom. Do not also fix WR-01 (mirror single-`##`-heading coupling) opportunistically in the same migration — it is a separate, unscoped carried item. |
| MIGR-08 execution coverage | A fixture extracts migration 0008's Step 4 `Apply` block verbatim via `extract_step_block` (the same mechanism already used for migration 0009), executes it in a sandbox pre-seeded at `0.5.0`, and asserts `.codex/workflow-version.txt` reads exactly `0.6.0` (content equality, not `grep -q` substring match) — proven non-vacuous by temporarily mutating 0008's Step 4 Apply text and observing the fixture go RED before restoring it, with that mutation run recorded as evidence. | Do not refactor migration 0008's Steps 1–3 fixtures (currently hand-replicated, not extracted) in the same pass — that is a larger, separately-scoped refactor beyond what this debt item names. |
| WR-03 | The `--file` bypass path canonicalizes the *parent directory* of `--file` (not the file itself, which may not yet exist) via the script's existing `_canon_dir` helper and rejects when the canonical result is not contained under `$REPO_ROOT/.planning` (via the existing `_is_contained` helper) — proven by a fixture where `--file` names a path through a symlinked directory component that resolves outside `.planning/` and is rejected, where the current lexical `..`-only check passes it. | Do not build new path-sandboxing primitives — reuse `_canon_dir`/`_is_contained`, already used for the `REVIEWS.md` resolution path, rather than inventing a second mechanism. Do not attempt to close TOCTOU races (symlink swapped between check and use); that is out of scope for a synchronous CLI verifier. |
| 09-REVIEW WR-05 + IN-01..04 | See per-item breakdown below — each is independently small; none touches a shipped/immutable migration file except IN-04, which cannot be "fixed in place" (see Dependencies). | Do not batch these into one omnibus change without individually observed-failing evidence per finding — each was found as a distinct, reproducible defect and each needs its own red-then-green proof. |

## Feature Landscape (per-item detail)

### 1. CI-01 — CI that can fail

**Table stakes:**
- `.github/workflows/ci.yml` replaces the Phase 0 `echo`/`exit 0` placeholder
  with a job that: checks out with `submodules: recursive` (the harness
  hard-fails without `vendor/agenticapps-shared`, per PROJECT.md
  Constraints), runs `migrations/run-tests.sh`, and runs the drift check
  (SKILL.md `version` vs. latest migration `to_version`).
- The workflow must fail the job (non-zero exit / red check) when either
  fails. This is checkable by reverting one already-fixed guard on a scratch
  branch and confirming the PR shows red — the same "observed failing"
  standard PROJECT.md requires of every guard in this milestone, applied to
  CI-01 itself.

**Important honesty note on what CI-01 would and would not have caught.**
The retrospective's dominant v0.7.0 failure — "314 PASS / 0 FAIL on a
migration that never ran" — was **not** an environment-drift bug. The
sandbox manufactured the very SKILL.md path whose absence should have made
migration 0009 abort; a clean CI checkout would have run the identical
fixture, with the identical manufactured precondition, and gone identically
green. **CI-01 alone would not have caught that specific defect.** What
closed it was Phase 9.1's mutation-gate practice (delete the guard, observe
RED, restore) — already established and correctly generalized in
PROJECT.md's constraint "a guard is not shipped until it has been observed
failing." CI-01's actual value is different and still real: it is
independent verification that the suite is green *outside* the author's own
machine and local state — catching `submodules: recursive` omissions, stale
local caches, BSD-vs-GNU shell divergence (this repo's own code comments
flag `stat -c` vs `stat -f`, `readlink -f` vs the portable `cd+pwd -P`
idiom, and BSD/macOS awk's rejection of multi-line `-v` assignments — real,
named portability hazards). Two milestones merging on a local green is the
retrospective's named "enabling condition" precisely because nothing
independent ever re-ran the suite in a reproducible environment — that is
the gap CI-01 closes, not fixture-design vacuity. Requirement text should
not overclaim CI-01 as a substitute for the mutation-gate discipline; it is
complementary.

**Nice-to-have vs. explicitly deferred:**
| Candidate | Classification | Reasoning |
|---|---|---|
| OS matrix (`ubuntu-latest` + `macos-latest`) | Borderline table-stakes — recommend include | The codebase's own comments repeatedly flag BSD/GNU divergence as a live hazard class (`stat`, `sed -i`, `readlink -f`, awk `-v`). A 2-OS matrix is a ~3-line GitHub Actions addition and directly covers a hazard this repo already names in-code. Low cost, on-theme. |
| Caching (npm/apt/etc.) | Nice-to-have, defer | No heavy dependency install; `jq` ships on both `ubuntu-latest` and `macos-latest` runners by default. Pure speed, not correctness. |
| Lint (markdownlint on migration docs) | Nice-to-have, defer | Orthogonal to "does the chain execute correctly" — scope creep relative to the stated CI-01 definition. |
| Shellcheck on standalone `.sh` files | Nice-to-have, defer to a later item | Real value (these are hand-written POSIX shell scripts with load-bearing portability idioms) but a distinct quality dimension from execution correctness, and some of the deliberate BSD-portability idioms may trigger shellcheck false positives that would need suppression tuning — not a same-day fit for "CI that can fail" as scoped. |
| Real scaffold-and-migrate E2E smoke test | Nice-to-have, explicitly out of PROJECT.md's stated CI-01 scope | Would have caught the *class* of bug 0007/0009 exhibited (pre-flight referencing a path no real install has) more directly than the fixture suite alone, because it exercises a genuinely fresh project rather than a hand-built sandbox. Worth flagging for a future item, but PROJECT.md's CI-01 text names only `run-tests.sh` + drift check — adding this now would be scope expansion beyond what was scoped, not a "smallest change." |

**Dependency:** CI-01 is explicitly first in PROJECT.md ("Lands first — it is
the prerequisite for trusting every other fix in this milestone") and every
other item's fixtures should merge only once they are red-then-green
*under real CI*, not only under a local run.

---

### 2. Migration 0007's chain break

**Confirmed mechanics (not just hypothesis).** 0007's pre-flight greps
`skills/agentic-apps-workflow/SKILL.md` — a path relative to the *installed
scaffolder* (`$CODEX_HOME/skills/...`), not the target project. No real
target project has a local `skills/` tree (0008's own Notes section states
this explicitly, citing `setup-codex-agenticapps-workflow/SKILL.md`'s
project-side surface as `AGENTS.md`, `.planning/`, `.codex/`,
`docs/decisions/` only). So 0007's pre-flight `grep` always fails on a real
install, and the pre-flight hard-aborts `exit 3` — this happens **before any
of 0007's four Steps run.** No config block, no AGENTS.md section, no
version bump: nothing from 0007 ever lands on a real install.

Because the abort is a hard exit (not one of the framework's silent
"from_version mismatch" skip cases), and because 0008's own pre-flight
floor requires `.codex/workflow-version.txt` to already read `0.5.0` or
`0.6.0` (a state 0007's abort prevents an install from ever reaching), **0008
and 0009 are also unreachable for every real install stuck below 0.5.0.**
This is not a single-migration stall; it severs the chain at 0007 for every
existing install between 0.4.0 and (would-be) 0.5.0. Fresh scaffolds are
unaffected — they are born at the current version and never replay this
migration.

**The fixture harness does not currently exercise this.**
`test_migration_0007` in `run-tests.sh` (lines 749–925) hand-replicates each
Step's logic against a synthetic sandbox and never invokes the document's
actual `## Pre-flight` block — it never even creates a
`skills/agentic-apps-workflow/SKILL.md` at the broken path, so the fixture
cannot observe the abort either way. This is the same defect class named in
the retrospective ("a sandbox must never manufacture the precondition under
test") applied retroactively: here the sandbox doesn't manufacture the
broken precondition — it just never touches the code path that would
exercise it at all.

**Table stakes — "the chain provably runs end to end" as an acceptance
criterion:**
- A new forward migration, immutable-safe (0007 itself is never edited),
  whose own pre-flight reads `.codex/workflow-version.txt` per 0008's
  precedent, not the scaffolder-relative path.
- Its Apply step(s) must **re-deliver 0007's actual payload** — the
  `knowledge_capture` config-block seed into `.planning/config.json` and the
  "Knowledge Capture — Ritual Tail" section insert into `AGENTS.md` — to
  installs the original abort skipped. Healing only the version pointer
  without delivering the payload reproduces exactly the "recorded success
  without effect" bug class named across both retrospective entries.
- It also drops 0007's MIGR-09 scaffolder-version-bump step, per PROJECT.md
  (that step wrote scaffolder files into consumer repos and 08's design
  deliberately kept MIGR-08/MIGR-09 apart).
- A fixture proves this by extracting the new migration's real Apply
  block(s) via the document-extraction pattern (not a hand-copy), running
  them against a sandbox seeded at `0.4.0` with no `knowledge_capture` block
  and no ritual-tail section, and asserting both artifacts exist afterward —
  not merely that a version file advanced.

**Open scoping question research could not fully resolve — flag for
requirement-writing, do not silently assume an answer:** 0008's own payload
(the `plan_review` config block, the AGENTS.md ritual section, and the
bindings-table corrections) is, by the same chain-severance logic, **also
never delivered to any real pre-0.5.0 install**, because 0008's pre-flight
floor (`0.5.0` or `0.6.0`) can never be satisfied by an install permanently
stuck at `0.4.0`. PROJECT.md's stated scope for this debt item names only
0007's payload ("Fix is a new forward migration per 0008's
`.codex/workflow-version.txt` precedent, which also drops 0007's MIGR-09
scaffolder-version bump") — it does not explicitly say the new migration
must also re-deliver 0008's plan-review-gate content. Two honest
possibilities: (a) the new healing migration re-delivers 0007's payload only
and bumps the install to `0.5.0`, after which the *existing* 0008 migration
(unedited, immutable) becomes reachable on the install's next update run and
delivers its own payload normally — this is the minimal, most
spec-conformant reading, and is almost certainly what "per 0008's precedent"
means; or (b) if the update skill's multi-hop chain selection (see next
paragraph) prevents a single invocation from reaching 0008 even after 0007
is healed, the fix needs explicit handling. Recommend (a) as the default
scoping unless the requirement author has reason to pick otherwise, but this
should be a stated decision, not an implicit one.

**Adjacent, already-flagged-as-separate defect worth surfacing, NOT proposed
for v0.8.0 scope:** 0008's own Notes independently record that the update
skill's migration-selection step computes the "pending" list once, up front,
from the project's *starting* version (`from_version ≤ project version AND
to_version > project version`), and 0008 "deliberately does not widen its
floor to paper over the update skill's multi-hop chain-selection defect —
that is a real, separately-scoped defect." Concretely: a project at `0.4.0`
running `$update-codex-agenticapps-workflow` once may only pick up 0007 (the
only migration whose `from_version` is `≤ 0.4.0` at selection time) and not
also 0008/0009 in the same invocation, unless the skill's selection logic
recomputes per-hop. This is NOT one of the seven v0.8.0 debt items and this
research is not proposing it be added — but it directly bears on how
strictly "the chain provably runs end to end" should be interpreted for
item 2's acceptance test: (i) weak interpretation — each migration, run
individually in `id` order (as the fixture suite already effectively does
via `--migration NNNN`-style isolated Apply-block execution), completes
without aborting; (ii) strong interpretation — one real invocation of
`$update-codex-agenticapps-workflow` against a `0.4.0` project reaches the
current version in one pass. Given the multi-hop selection defect is
explicitly out-of-scope elsewhere in this repo's own documentation, the
requirement should state interpretation (i) as the v0.8.0 acceptance bar and
name (ii) as a known, deliberately deferred gap — not silently claim (ii) is
achieved.

**Do NOT over-build:** do not use this debt item as cover to also fix the
multi-hop chain-selection defect (separately scoped, unrelated file/skill);
do not touch 0007's or 0008's shipped text (immutable).

---

### 3. HOOK-01 — the plan-review gate blocks natively

**Table stakes:** bind `check-plan-review.sh` (with its existing `--file`
flag, built for exactly this) to `~/.codex/hooks.json`'s `PreToolUse`
surface — the native, global runtime hook Codex CLI 0.144.4 ships and this
repo has so far declined to use (ADR-0009's option B, deliberately deferred,
not rejected: "It is the documented upgrade path — see decision 9 — and can
point at the same verifier this ADR authors").

**Observable success test (must be end-to-end, not a script-level unit
test):** with the hook registered, attempt — through the real Codex CLI tool
surface, not by invoking the script directly — an edit that the verifier is
supposed to block (e.g., editing a plan file mid-phase with no
`<NN>-REVIEWS.md` evidence and no escape hatch set). The tool call must be
observably prevented (the edit does not happen), not merely logged. This is
the "unconditional block" ADR-0009 criterion 1 originally wanted before
Round 2 review walked it back to "agent-mediated" — HOOK-01 restores that
original criterion and formally supersedes decision 9's acceptance.

**Do NOT over-build:**
- The gate is already scoped correctly by the verifier's own repo-root
  self-location and fail-open-outside-a-`.planning`-tree behavior
  (`check-plan-review.sh:167–190`) — do not build additional per-repo
  scoping on top of the hook registration; the existing script already
  handles "which repo am I in."
- Do not attempt to solve the sha256 trust-ledger re-grant friction ADR-0009
  names (a migration editing `~/.codex/hooks.json`'s content requires
  re-granting trust) as part of this item — that is a Codex CLI UX property,
  not something this repo's migration can design around; document it as a
  known operational cost of the native binding, not a defect to fix.
- Do not extend native `PreToolUse` binding to the other 15 declarative
  gates in the same change — HOOK-01's scope is the plan-review gate only.

---

### 4. Paired §11 start/end markers (AG-01's durable fix)

**What's being retired, precisely.** The current mechanism infers the §11
block's extent from three independent signals that must all stay in sync: a
provenance comment as entry condition, an exact heading match as the only
recognized exit condition, and a terminator alternation (`## `,
`gitnexus:start`, or EOF) as the outer boundary. Phase 9.1 already had to
patch two ways this can desynchronize (CR-01: entry fires without exit ever
firing, deletes to EOF; CR-02: an unanchored provenance regex lets prose
arm the same runaway) — and AG-01 (§11 at a region's *tail*, where the strip
can eat `gitnexus:end`) is a third instance of the same underlying class:
**the boundary is inferred, not stated.** PROJECT.md's framing — "retiring
the inference-based defect class rather than hardening instances" — is the
correct bar: this is not "patch AG-01," it is "make the class of bug
structurally impossible."

**Table stakes:**
- A new forward migration inserts explicit start/end markers (e.g.
  `<!-- BEGIN: spec-11 coding-discipline -->` / `<!-- END: spec-11
  coding-discipline -->`, matching this repo's existing outer-block idiom
  `<!-- BEGIN/END: agentic-apps-workflow sections -->`) bounding the §11
  block, on both fresh scaffolds going forward and healed existing installs.
- The strip/replace mechanism is rewritten to key off the explicit markers
  (extract everything between BEGIN and END, replace that span) rather than
  the current heading + terminator-alternation inference. This is what
  actually closes the defect class: a strip bounded by an explicit,
  unambiguous END marker cannot run away past it, cannot be tricked by a
  drifted heading, and does not depend on the terminator alternation at all
  for this block (the outer marker pair still needs it, per the widened
  invariant).
- Existing single-anchor installs (states A–D from migration 0009's own
  healing matrix) are healed non-destructively and idempotently — wrapping
  the block that is already correctly placed with the new marker pair,
  without re-triggering the old strip/insert machinery.
- Must respect PROJECT.md's stated transition constraint: the widened
  three-way terminator invariant still holds for whatever *outer* boundary
  remains inference-based during the transition, and `12-idempotent-rerun`
  (the live regression guard for the terminator alternation) must stay
  green.
- Regression proof for AG-01 specifically: a fixture placing §11 at a
  region's tail must be shown to fail under the OLD inference logic (i.e.,
  actually reproduce the eaten-`gitnexus:end` runaway once, per the
  "observed failing" standard) and pass once the new markers bound the
  block.

**Do NOT over-build:**
- Do not design a generic, pluggable "managed section marker" framework
  reusable for arbitrary future content blocks. Scope markers to §11
  specifically; the outer `agentic-apps-workflow sections` markers already
  cover the general case and are out of scope here.
- Do not fold WR-01 (the mirror-single-`##`-heading coupling — a real,
  documented, but separately-carried defect: the strip currently assumes
  the mirror source has exactly one `## ` line, and a second one would
  truncate the strip early and duplicate content) into this migration
  opportunistically just because the same code is being touched. It is not
  one of the seven v0.8.0 items; note it as a natural follow-up but do not
  silently absorb it.
- Do not attempt to also retroactively "fix" migration 0009's text —
  0009 is shipped and immutable; this is a new migration, full stop.

---

### 5. MIGR-08 execution coverage

**The exact gap.** `test_migration_0008` currently asserts the version-bump
step by hand-writing `echo "0.6.0" > .codex/workflow-version.txt` directly
in the test script (`run-tests.sh:1631`) rather than extracting and
executing the migration document's own Step 4 `Apply:` block. This means the
fixture proves the *test author's* restatement of the logic is correct, not
that the *document's* logic is correct — precisely the "can't-fail
assertion" class the retrospective's mutation-gate standard exists to catch.
The precedent for the correct pattern already exists in the same file:
`test_migration_0009` extracts real blocks via `extract_step_block
"$MIGRATION_0009" 1 Apply` (`run-tests.sh:3478–3479`) and executes the
extracted text rather than a hand copy.

**Table stakes — what the assertion must check to not be another
can't-fail assertion:**
1. Extract migration 0008's Step 4 `Apply:` block **from the document
   itself** via `extract_step_block`, not from a hand-typed restatement.
2. Execute the extracted text in a sandbox pre-seeded at `0.5.0` (a state
   where the assertion could plausibly fail — i.e., the file does not
   already read `0.6.0` before the Apply runs).
3. Assert **exact content equality** (`[ "$(cat
   .codex/workflow-version.txt)" = "0.6.0" ]`), not a `grep -q` substring
   match — a substring match would pass even if the file had trailing
   garbage, multiple lines, or embedded whitespace, none of which a strict
   equality check would tolerate.
4. Prove the assertion is non-vacuous per this repo's own standard: mutate
   0008's Step 4 Apply text (e.g., change the written value to `0.5.1`),
   re-run the fixture, observe it go RED, then restore. Record that this was
   done — presence of the assertion is not evidence of coverage until it has
   been watched failing, exactly as PROJECT.md's Key Decisions table states
   for the whole milestone.

**Do NOT over-build:** the debt item as scoped is Step 4 only ("a fixture
that runs the Apply block and asserts the written
`.codex/workflow-version.txt`"). Migration 0008's Steps 1–3 remain
hand-replicated in the existing fixture; retrofitting all four steps to the
extraction pattern in the same change is a larger, separately-motivated
refactor and should not be bundled in here.

---

### 6. WR-03 — real symlink-resolution guard

**Why the current guard is wrong, precisely.** The `--file` bypass path
(`check-plan-review.sh:84–118`) rejects only a literal `..` path *component*
in the raw string. It is deliberately lexical because a real path-resolution
check (`_canon_dir`, defined later in the same file at line 133) requires
the target to already exist via `cd` — and `--file` may legitimately name a
plan file about to be created. That constraint is real, but the current
guard over-corrects: a `--file` argument that names a path through a
**symlinked directory component** which resolves outside `.planning/`
(e.g. `.planning/phases -> /tmp/evil`) contains no literal `..` and is
accepted, even though it is exactly the class of traversal the guard exists
to stop.

**Table-stakes guard:** canonicalize the **parent directory** of `--file`
(which does exist, since a plan file is always created inside an existing
`.planning/phases/...` tree), not the file itself — this satisfies both
constraints simultaneously: it tolerates a not-yet-created target file while
still resolving any symlinked directory component in the path. Concretely:
1. Keep the existing lexical `..`-component reject as a cheap first filter
   (already correct, already ordered first).
2. Add: `_canon_dir "$(dirname "$CPR_FILE")"`, then verify the canonical
   result is contained under `$REPO_ROOT/.planning` via the **existing**
   `_is_contained` helper (already used elsewhere in this same script for
   the `REVIEWS.md` resolution path — reuse it, do not reinvent it).
3. A canonicalization failure (parent doesn't exist, or resolves empty) or a
   containment failure must **reject** the bypass (fall through to normal
   resolution — not silently authorize), matching this script's existing
   fail-closed posture for the `REVIEWS.md` symlink guard
   (`[ -L "$REVIEWS" ]` rejects outright, `check-plan-review.sh:459–475`).

**Proof:** a fixture where `--file` names a path through a symlinked
directory component resolving outside `.planning/` must be shown accepted
by the *current* lexical-only guard (observed failing on today's code) and
rejected once the resolution guard lands.

**Do NOT over-build:**
- Reuse `_canon_dir`/`_is_contained` — do not add a second path-safety
  primitive alongside the ones the script already trusts and tests.
- Do not attempt to close TOCTOU races (a symlink swapped between the check
  and the actual file read) — that is a different threat class, and this
  repo's own pattern elsewhere (the `[ -L ]`-before-`[ -f ]` ordering
  lesson from v0.6.0's retrospective) is about ordering guards correctly,
  not about defending against concurrent filesystem mutation in a
  synchronous single-invocation CLI verifier.

---

### 7. 09-REVIEW.md WR-05 + IN-01..IN-04

Each of these is small and independent; do not batch without individual
observed-failing evidence per finding.

**WR-05 — banner determinism (`validate-0009-anchor.sh:231–241`).**
The comment claims the evidence banner is deliberately deterministic (no
repo SHA, no absolute path) so a verifier can re-run and byte-diff it later
(T-09-04) — but the banner embeds `$(wc -l < "$MIRROR")` and derived line
numbers (e.g. "`gitnexus:start` at line 86"), both of which change whenever
the §11 spec mirror is re-vendored (already happened once: 75→79 lines).
**Table-stakes minimal fix — pick one and state which, do not leave both
implied:**
- (a) Drop the mirror line count and the derived line numbers from the
  banner/PASS text entirely, so the evidence file is genuinely
  revision-independent — the correct fix if the evidence file is meant to
  be diffed byte-for-byte across mirror re-vendors without regenerating a
  new baseline each time; or
- (b) Narrow the comment's claim to "stable for a given mirror revision" and
  document that the evidence file must be re-recorded whenever the mirror
  is re-vendored — the correct fix if per-revision evidence is actually the
  intended contract.
Given the evidence file's stated purpose (T-09-04: re-run and diff to prove
nothing silently changed), option (a) is the fix that actually delivers
that guarantee; option (b) is a docs-only correction that leaves the file
non-deterministic across the one mutation (mirror re-vendor) known to have
already happened once. Recommend (a) as table stakes; do not gold-plate by
also generalizing the banner format beyond this specific fix.

**IN-01 — `extract_step_block` prefix-matches `### Step 1` against `### Step
10` (`run-tests.sh:110`).**
`index($0, stepp) == 1` with `stepp="### Step 1"` also matches `### Step
10`…`### Step 19`. Harmless today (no migration has 10+ steps) but this is
shared test infrastructure other migrations (including item 4's new markers
migration) will use going forward. **Table-stakes fix:** match on the
delimiter too — compare against both `### Step N:` and `### Step N `
(trailing space) prefixes, preserving the existing no-escaping,
literal-prefix design intentionally chosen at `:80–91`. **Proof:** a
regression fixture with a synthetic document containing both `### Step 1`
and `### Step 10` must show the old matcher picking the wrong block
(observed failing) and the fixed matcher picking correctly.

**IN-02 — unasserted line-drop evidence (`validate-0009-anchor.sh:249–264`).**
ADR-0010 cites "the strip genuinely removes 81 lines (313 → 232)" as CASE
1's non-vacuity evidence, but the script never asserts that number — the
claim lives outside the artifact that's supposed to reproduce it.
**Table-stakes fix:** add the reviewer's own proposed cheap assertion
between strip and insert — `[ "$(wc -l < case1.strip)" -lt "$(wc -l <
case1-input.md)" ]` (strictly-smaller, not an exact byte count). **Do NOT
over-build:** do not hardcode the exact "81" line-drop figure as an
assertion — that number is coupled to the mirror's current size and would
break (for the wrong reason) the next time the mirror is re-vendored,
reproducing WR-05's own root cause inside a "fix" for a different finding.

**IN-03 — ADR/migration numbering collision (`docs/decisions/README.md`).**
`ADR-0009` (plan-review gate) and `migration 0009` (region-aware placement,
documented by `ADR-0010`) are independently numbered series that collide at
adjacent numbers. **Table-stakes fix, per the reviewer's own disposition:
no code change** — add one explicit line to `docs/decisions/README.md`
stating ADR numbering is independent of migration numbering. This is a
docs-only fix; do not touch `run-tests.sh`'s existing (correct, if
confusing) greps.

**IN-04 — predictable temp-file names in migration 0009's Apply blocks
(`migrations/0009-spec-11-region-aware-placement.md:273, 306`).**
**Scoping conflict worth flagging explicitly, not silently resolving:** the
literal finding location is inside migration 0009's own document text.
Migration 0009 shipped in v0.7.0 and, per PROJECT.md's compatibility
constraint ("Migrations are append-only and immutable once shipped — a
defect in a past migration is fixed by a new one, never by an edit"), is now
immutable — the same rule that protects 0001/0004/0007. **This finding
cannot be closed by editing 0009's `AGENTS.md.0009.strip` /
`AGENTS.md.0009.tmp` fixed names in place.** The practical path is that item
4 (paired §11 markers) already supersedes 0009's strip/insert Apply logic
with a new migration's own Apply blocks — **the recommended table-stakes
fix is to write item 4's new migration using `mktemp` inside the project
directory (not system `/tmp`, to preserve the same-filesystem atomic-`mv`
property the reviewer's own note calls out as worth keeping) from the
start, and record IN-04 as closed-by-supersession rather than
closed-by-edit.** 0009's shipped text is left exactly as-is, which is
correct and matches how AG-01 itself was disposed of (accepted-and-disclosed
until a superseding migration retires the whole mechanism). **Do NOT
over-build:** do not also retrofit `mktemp` into 0007's or 0008's shipped
`AGENTS.md.000N.tmp` idiom — those are separately immutable and not named by
this finding.

## Feature Dependencies

```
CI-01
  └──gates (trust)──> every other item's fixtures/proof
                       (PROJECT.md: "later phases gate on real CI
                       rather than a local green")

Migration 0007 chain-break fix
  └──unblocks (for real installs only, not fixture-suite testing)──>
        0008's plan-review payload actually reaching pre-0.5.0 installs
  └──independent in code from──> HOOK-01, WR-03, paired markers, MIGR-08
     (all four can be built/tested without 0007's fix landing first;
      the dependency is operational/real-install-reachability, not
      compile-time or test-fixture-time)

Paired §11 markers (item 4)
  └──supersedes──> migration 0009's strip/insert Apply blocks
  └──closes-by-supersession──> IN-04 (temp-file naming)
        (0009's own text stays immutable; IN-04 is resolved in the
        NEW migration's Apply blocks, not by editing 0009)
  └──must-stay-green-under──> 12-idempotent-rerun (widened terminator
        invariant, transition-period constraint)

MIGR-08 execution coverage
  └──reuses pattern from──> migration 0009's extract_step_block precedent
        (already established; item 5 is "do the same thing for 0008
        Step 4", not new design work)

WR-03 and HOOK-01
  └──both touch──> check-plan-review.sh
        (no functional dependency between them; coordinate merge order
        to avoid conflicting edits to the same file, not a hard gate)

IN-01 (extract_step_block boundary bug)
  └──should land before or alongside──> any new migration with ≥10 steps
        (currently none does; item 4's new markers migration is the
        most likely future candidate to trip this — cheap to fix now,
        cheap to regret later)

IN-02, IN-03
  └──fully independent──> no dependency on any other item
```

### Dependency Notes

- **CI-01 gates trust, not code.** Nothing else in this milestone requires
  CI-01's workflow file to exist before its own code can be written or
  tested locally — but per PROJECT.md's explicit ordering ("Lands first —
  it is the prerequisite for trusting every other fix in this milestone"),
  every other item's fixtures should be considered provisionally accepted
  only once shown green under the new CI, not only locally.
- **The 0007 chain-break fix and 0008's payload are logically coupled but
  should be a stated scoping decision, not an implicit one** (see item 2's
  "Open scoping question" above) — the safest default is: the new healing
  migration re-delivers 0007's payload only and advances the install to
  `0.5.0`; 0008 (unedited) becomes reachable on that install's next update
  pass. This should be written into the requirement text explicitly so it
  isn't rediscovered as a surprise during implementation.
- **Item 4 and IN-04 are the same piece of work seen from two debt items.**
  The paired-markers migration's own temp-file idiom is the practical
  closure mechanism for IN-04; do not plan them as two separate, unrelated
  units of work — sequence IN-04's "acceptance" as a sub-check inside item
  4's plan, not a standalone plan.
- **IN-01 is cheap insurance for item 4.** Fix it early (it's a two-line
  change plus a fixture) so the new paired-markers migration — whichever
  number it lands as — isn't the migration that first exposes the
  10-step boundary bug.

## MVP Definition (ordering within v0.8.0)

### Land First
- [ ] CI-01 — every subsequent item's proof should run under real CI, per
      PROJECT.md's explicit ordering.

### Land Early, Independent, Cheap
- [ ] IN-01, IN-02, IN-03 — pure test/doc-harness fixes, no dependency on
      anything else, no migration-immutability constraints, small enough to
      de-risk before the larger items.

### Core Enforcement Work
- [ ] Migration 0007 chain-break fix (with the 0007-vs-0008-payload scoping
      decision made explicit in the requirement text).
- [ ] MIGR-08 execution coverage (reuses an established extraction pattern
      — low design risk).
- [ ] WR-03 (reuses existing `_canon_dir`/`_is_contained` helpers — low
      design risk).
- [ ] HOOK-01 (requires an end-to-end proof against a real
      `~/.codex/hooks.json`, not just a unit test — higher verification
      cost than the others in this group).

### Structural, Higher Design Risk
- [ ] Paired §11 markers (item 4) — the largest single design surface in
      this milestone; closes AG-01 and, as a side effect, IN-04. Recommend
      landing after WR-03/MIGR-08/HOOK-01 have re-established confidence in
      the fixture-extraction and mutation-gate discipline on smaller
      surfaces first, since this item touches the most failure-prone code
      (the strip/insert mechanic that has already produced three
      independent data-loss defects across two milestones).

### Explicitly Deferred (not v0.8.0 scope — noted so it isn't silently
re-added)
- The update skill's multi-hop chain-selection defect (0008's own Notes;
  strong-interpretation blocker for "one invocation reaches current
  version").
- WR-01 (mirror single-`##`-heading coupling) — real, documented, not one
  of the seven items.
- Shellcheck / lint / caching in CI — nice-to-have, not part of CI-01's
  stated scope.
- Real scaffold-and-migrate E2E smoke test in CI — would have more directly
  caught the class of bug 0007/0009 exhibited, but is scope expansion
  beyond CI-01's stated definition; flag for a future item.

## Sources

- `.planning/PROJECT.md` (Current Milestone, Active requirements, Context,
  Constraints, Key Decisions) — direct read, HIGH confidence.
- `.planning/phases/09-region-aware-11-placement/09-REVIEW.md` — direct
  read, all seven findings (CR-01..03 excluded per milestone context, WR-01
  through WR-05, IN-01 through IN-04) — HIGH confidence.
- `.planning/RETROSPECTIVE.md` — v0.6.0 and v0.7.0 milestone entries, Carried
  Debt table, Recurring Failure Mode section — HIGH confidence.
- `migrations/0007-knowledge-capture.md`, `migrations/0008-plan-review-gate.md`
  — direct read, full text, including the explicit chain-break disclosure in
  0008's own Notes section — HIGH confidence.
- `migrations/README.md` — migration format, idempotency/atomicity contracts
  — HIGH confidence.
- `skills/update-codex-agenticapps-workflow/SKILL.md` — Stage A.4 pending-
  migration selection logic, grounding the multi-hop chain-selection
  observation — HIGH confidence.
- `migrations/run-tests.sh` (lines 749–925 `test_migration_0007`; lines
  1600–1650 `test_migration_0008` Step 4; lines 3453–3480+
  `test_migration_0009` extraction precedent; line 100–115
  `extract_step_block`) — direct read, grounding items 2, 5, 7 — HIGH
  confidence.
- `skills/agentic-apps-workflow/scripts/check-plan-review.sh` (lines 60–190,
  459–475) — direct read, grounding WR-03 and HOOK-01 — HIGH confidence.
- `docs/decisions/0009-plan-review-gate.md` (Options considered, Decision 1
  and 9) — direct read, grounding HOOK-01's native-hook precedent and its
  deliberate-deferral rationale — HIGH confidence.
- `.github/workflows/ci.yml` — direct read, confirming the Phase 0
  placeholder's exact current text — HIGH confidence.

No external/ecosystem research (Context7, WebSearch) was performed for this
task — the question is entirely internal to this repo's own already-built
mechanisms and already-scoped debt, consistent with the milestone context's
instruction not to re-research already-built features.

---
*Feature research for: codex-workflow v0.8.0 "Enforcement, Not Intention"*
*Researched: 2026-07-16*
