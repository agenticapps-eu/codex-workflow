---
id: 0008
slug: plan-review-gate
title: Bind the plan-review pre-execution gate — spec §02 (v0.5.0 -> 0.6.0)
from_version: 0.5.0
to_version: 0.6.0
applies_to:
  - .planning/config.codex.json
  - AGENTS.md
  - .codex/workflow-version.txt
requires: []
optional_for: []
---

# Migration 0008 — Plan-review gate (v0.5.0 -> 0.6.0)

Implements core spec [§02](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md)
"Pre-execution gate" (lines 81-109) on the Codex host: multi-AI plan review
must run before execution begins, enforced by a hybrid mechanism — a
declarative binding plus a programmatic verifier (this repo's own ADR-0009,
`docs/decisions/0009-plan-review-gate.md`). Plan `08-04` made **fresh**
installs conformant by construction: the `config-hooks.json` template already
carries the `hooks.pre_execution.plan_review` block, the ritual section
already ships inside `agents-md-additions.md`, and that same template's
bindings table already reads 16 distinct gates (D-20 — the `tdd` collapse,
the `brainstorm-ui` / `brainstorm-architecture` split, and the `plan-review`
row). An install already at `0.5.0` gets none of this — this migration
teaches an **existing install** the config block, the ritual section, and
the bindings-table corrections so a migrated install reaches the same bound
state as a fresh one.

**Config lives in the host-scoped `.planning/config.codex.json`, NOT the
host-neutral `.planning/config.json` migration 0007 used.** This is a
deliberate divergence from 0007's destination, not an oversight: 0007's
`knowledge_capture` block had to be the **same** block both hosts read (the
vault note is one-per-repo, shared across hosts), so it went in the shared
`.planning/config.json`. `pre_execution` is the opposite — it is host-scoped
like the other 15 gates already living under `.planning/config.codex.json`'s
`hooks` object (D-01/D-19, ADR-0007 point 5's codex-namespacing precedent). A
reader coming from 0007 should not assume the same destination here.

**Why a 0.x minor bump:** the update engine applies a migration only when
`installed >= from_version AND installed < to_version`. Every live project is
at `0.5.0` after 0007, so a `0.5.0 -> 0.6.0` migration is the shape that
reaches the fleet via `$update-codex-agenticapps-workflow`.

**Supported upgrade floor:** `0.5.0 -> 0.6.0`. A project below `0.5.0` must
reach `0.5.0` first via the existing chain (0000 → … → 0007). This migration
deliberately does not widen its floor to paper over the update skill's
multi-hop chain-selection defect — that is a real, separately-scoped defect
(see `## Notes`), and this migration's contract is the single hop it
actually implements.

## Pre-flight

```bash
# Project root must be a git repo (repo-name derivation + atomic commit)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# jq is required for the config merge
command -v jq >/dev/null || { echo "ABORT: jq not found — required for the config merge"; exit 2; }

# Workflow project version is at the supported floor (0.5.0), or 0.6.0 for
# re-apply. DELIBERATE DIVERGENCE from 0007's floor check, which greps this
# repo's own scaffolder trigger skill's SKILL.md — a path NO target project
# has (the setup skill's project-side surface is AGENTS.md, .planning/,
# .codex/, and docs/decisions/ only; 0007's floor grep aborts with exit 3 on
# every real install for exactly this reason — see `## Notes`). This
# project's OWN durable version record, `.codex/workflow-version.txt`, is
# what the update
# skill itself reads (its Stage A step 1), and is what this floor check reads
# too.
grep -qE '^0\.(5|6)\.0$' .codex/workflow-version.txt || {
  INSTALLED=$(cat .codex/workflow-version.txt 2>/dev/null)
  echo "ABORT: project version is $INSTALLED (need 0.5.0)."
  echo "       Apply prior migrations first via \$update-codex-agenticapps-workflow."
  echo "       Supported upgrade floor: 0.5.0 -> 0.6.0."
  exit 3
}

# Templates ship in the installed scaffolder (single source of truth).
CODEX="${CODEX_HOME:-$HOME/.codex}"
test -f "$CODEX/skills/setup-codex-agenticapps-workflow/templates/config-hooks.json" || {
  echo "ABORT: config-hooks.json template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
test -f "$CODEX/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md" || {
  echo "ABORT: agents-md-additions.md template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }

# The verifier itself must ship before the migration that wires it — a
# config pointing at an uninstalled verifier is a gate that silently never
# fires (T-08-25).
test -f "$CODEX/skills/agentic-apps-workflow/scripts/check-plan-review.sh" || {
  echo "ABORT: check-plan-review.sh verifier missing — reinstall the scaffolder (bash install.sh)"; exit 5; }
```

## Steps

### Step 1: Merge `pre_execution.plan_review` into `.planning/config.codex.json`

The destination is the host-scoped config file, like every other gate in
`hooks` (see the framing note above on the destination divergence from 0007).

**Idempotency check (the LEAF, not the group):** a group-level check
(`jq -e '.hooks.pre_execution'`) would read "applied" on an install that
already has a sibling pre-execution gate but not `plan_review` — leaving it
unbound while reporting success. Check the leaf instead:
```bash
jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null
```
(Returns 0 when `plan_review` already exists — a fresh install got it from
the template, or this migration already ran; its value is preserved
verbatim, this step is a no-op.)

**Pre-condition:** template present (checked in pre-flight); `jq` available.

**Apply:**
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
TEMPLATE="$CODEX/skills/setup-codex-agenticapps-workflow/templates/config-hooks.json"

# $PE is the pre_execution object's CONTENTS (i.e. {"plan_review": {...}}),
# sourced from the installed template — never a heredoc'd literal (D-19).
PE="$(jq -c '.hooks.pre_execution' "$TEMPLATE")"

mkdir -p .planning
if [ ! -f .planning/config.codex.json ]; then
  echo '{"hooks": {}}' > .planning/config.codex.json
fi

# Leaf-level deep merge. NEVER assign the whole pre_execution object shallowly
# as one key of .hooks (e.g. `.hooks |= (. + {pre_execution: $pe})`) — that
# preserves `.hooks`'s OTHER GROUPS but REPLACES the whole pre_execution
# object, deleting any sibling gate inside it. Today pre_execution has one
# member so nothing is lost; the day core spec adds a second pre-execution
# gate, the shallow form deletes it on every install that has it (T-08-22).
# `// {}` handles the first-run case where pre_execution does not exist at
# all.
jq --argjson pe "$PE" \
   '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
   .planning/config.codex.json > .planning/config.codex.json.tmp \
  && mv .planning/config.codex.json.tmp .planning/config.codex.json
```

**Rollback:** remove only our leaf; drop the parent only if it is then
empty. Deleting the whole pre_execution object unconditionally would be
destructive to any sibling gate for the same reason the shallow merge is
(T-08-22):
```bash
jq 'del(.hooks.pre_execution.plan_review)
    | if (.hooks.pre_execution // {}) == {} then del(.hooks.pre_execution) else . end' \
   .planning/config.codex.json > .planning/config.codex.json.tmp \
  && mv .planning/config.codex.json.tmp .planning/config.codex.json
```

### Step 2: Insert the "Pre-execution Gate — Plan Review" ritual section into `AGENTS.md`

The section text is extracted from the scaffolder's `agents-md-additions.md`
template (single source of truth, D-19) so a migrated install is
byte-identical to a fresh one and the prose cannot drift. It is inserted
inside the existing `agentic-apps-workflow` marker block, immediately before
the closing marker — the same mechanism 0007's Step 2 uses.

**Idempotency check:**
```bash
grep -q '^## Pre-execution Gate — Plan Review (spec §02)' AGENTS.md
```
(Returns 0 when the section is already present — a fresh install got it from
the template; this step is then a no-op.)

**Pre-condition:** `AGENTS.md` carries the marker pair
`grep -q '<!-- END: agentic-apps-workflow sections -->' AGENTS.md`

**Apply:**
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
TPL="$CODEX/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md"

# Extract the section from the template to a temp file: from its heading up
# to (excluding) the template's END marker.
SECFILE="$(mktemp)"
awk '
  /^## Pre-execution Gate — Plan Review \(spec §02\)/ {f=1}
  /^<!-- END: agentic-apps-workflow sections -->/      {f=0}
  f
' "$TPL" > "$SECFILE"

# Insert the section before the project's END marker. getline-from-file is
# portable (BSD/macOS awk rejects a multi-line -v assignment) — carried
# forward verbatim from 0007's Step 2; a "simplification" to `awk -v
# var="$(cat file)"` breaks every macOS install.
awk -v secfile="$SECFILE" '
  /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
    while ((getline line < secfile) > 0) print line
    ins=1
  }
  { print }
' AGENTS.md > AGENTS.md.0008.tmp && mv AGENTS.md.0008.tmp AGENTS.md
rm -f "$SECFILE"
```

**Rollback:** `git checkout -- AGENTS.md`. Manual anchor: delete from the
line `## Pre-execution Gate — Plan Review (spec §02)` through the blank line
before `<!-- END: agentic-apps-workflow sections -->`.

### Step 3: Correct the AGENTS.md bindings table (D-20, all three corrections)

The table read 15 gates before spec §02 added `plan-review`, and it
duplicated `tdd` as two rows. Plan `08-04` corrected both defects — plus
split the template's own combined `brainstorm-ui / brainstorm-architecture`
row — in **fresh** installs, sourced once from `agents-md-additions.md`. An
existing install's table still reads whatever it read at `0.5.0`: 15 rows,
brainstorm combined into one row, two `tdd` rows, no `plan-review` row. This
step applies the same three corrections an existing install is missing,
every row read from the same template as Step 2's ritual section (D-19) —
never a heredoc'd literal.

**Shape guard first — and a mismatch is a FAILED PRECONDITION, not a
success.** Read the template's table header line. Locate the target's table
by the same header. If the target's header does not match, do not touch the
table: print a warning naming both headers and exit with a distinct
non-zero precondition code, routing to the update skill's per-step failure
prompt (retry / skip-with-warning / rollback,
`migrations/README.md:103-113`).

**Why not a silent skip:** an earlier revision treated an unrecognised
header as though the step had completed, which let the migration continue to
Step 4 and record the project at `0.6.0` — an install stamped current whose
table was never corrected, reading 15 gates while claiming 0.6.0, and
nothing ever revisits it because the version record says there is nothing
pending. A false "current" is worse than a reported failure. The step still
refuses to touch a table whose shape it does not recognise — that decline is
right, and OpenCode credited it as a strength — but its *status* is a failed
precondition, not a skip. If the operator chooses skip-with-warning at the
atomicity-contract prompt, the migration completes with the state recorded
`partial` — a documented, consented, durable outcome, never a silent one.

A downstream install's table came from the template and will match; this
repo's own hand-maintained `AGENTS.md` uses a different third column
(`Applies to scaffolder?` vs the template's `Scope`) and is exactly the kind
of target this guard exists to decline — see `## Notes` on why this
migration is never applied to this repo's own `AGENTS.md` in the first
place.

**Idempotency check:**
```bash
grep -q '^| plan-review' AGENTS.md
```
(Returns 0 when the table already carries a `plan-review` row — a fresh
install got it from the template, or this step already ran; this step is
then a no-op. **Step-local only** — it gates this step and nothing else.)

**Pre-condition:** the target's table header line matches the template's
(checked in Apply, below — a shape check, not a file-existence check).

**Apply:**
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
TPL="$CODEX/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md"

# The template's own header line — the shape every real fresh or migrated
# install's table must match.
TPL_HEADER="$(grep -m1 '^| Gate |' "$TPL")"
TARGET_HEADER="$(grep -m1 '^| Gate |' AGENTS.md)"

if [ "$TARGET_HEADER" != "$TPL_HEADER" ]; then
  echo "ABORT: bindings-table header mismatch — declining rather than guessing." >&2
  echo "  template header: $TPL_HEADER" >&2
  echo "  target header:   $TARGET_HEADER" >&2
  echo "  This is a FAILED PRECONDITION, not a successful step: choose retry," >&2
  echo "  skip-with-warning (records this migration 'partial'), or rollback." >&2
  exit 7
fi

# Rows extracted from the template — never a heredoc'd literal (D-19). All
# three corrections read from here: the two split brainstorm rows, the
# collapsed tdd row, and the plan-review row.
ROW_PLAN_REVIEW="$(grep -m1 '^| plan-review |' "$TPL")"
ROW_BRAINSTORM_UI="$(grep -m1 '^| brainstorm-ui |' "$TPL")"
ROW_BRAINSTORM_ARCH="$(grep -m1 '^| brainstorm-architecture |' "$TPL")"
ROW_TDD="$(grep -m1 '^| tdd |' "$TPL")"

# Apply all THREE corrections in one pass:
#   1. SPLIT the combined brainstorm row into the template's two rows.
#   2. COLLAPSE the duplicate tdd rows to the template's single row.
#   3. ADD plan-review as the first data row of the VALIDATED bindings table
#      (right after the separator that follows the '| Gate |' header this
#      step already checked above — not the first separator in the file).
# Leave every other row untouched. Net: 15 -> 16 -> 15 -> 16 rows / 16
# distinct gates, identical to a fresh install.
#
# The insertion is scoped to the validated header (WR-02, 08-REVIEW.md):
# matching only `/^\|---/` fires on the FIRST '|---' line anywhere in
# AGENTS.md, so a target repo whose file holds any OTHER Markdown table
# before the bindings table gets the plan-review row inserted into that
# unrelated table instead — leaving the real bindings table without it.
# Worse, this self-seals: the idempotency check above this pass
# (`grep -q '^| plan-review' AGENTS.md`) would then find the misplaced row
# on every future run and mark Step 3 already-applied forever, permanently
# masking that the bindings table never got the gate this migration exists
# to bind. Setting `seen_hdr` on the already-validated `| Gate |` header and
# gating the separator match on it correlates the insertion point with the
# header instead of leaving the two independent.
awk \
  -v pr="$ROW_PLAN_REVIEW" \
  -v bui="$ROW_BRAINSTORM_UI" \
  -v barch="$ROW_BRAINSTORM_ARCH" \
  -v tdd="$ROW_TDD" '
  /^\| Gate \|/ { seen_hdr=1 }
  /^\|---/ && seen_hdr && !ins_pr { print; print pr; ins_pr=1; next }
  /^\| brainstorm-ui \/ brainstorm-architecture \|/ { print bui; print barch; next }
  /^\| tdd \(new TS module\)/ { next }
  /^\| tdd \|/ { print tdd; next }
  { print }
' AGENTS.md > AGENTS.md.0008-table.tmp && mv AGENTS.md.0008-table.tmp AGENTS.md
```

**Rollback:** `git checkout -- AGENTS.md`. Manual anchor: this step only
rewrites data rows inside the existing bindings table — no heading, no
marker to bound a deletion — so a targeted revert means restoring the
pre-Step-3 table from git history; `git checkout -- AGENTS.md` also restores
Step 2's ritual section along with it, per Step 2's own rollback.

### Step 4: Record `0.6.0` in `.codex/workflow-version.txt`

This is the project's durable version record, and the last step, per 0007's
content-steps-then-version-seal convention — sealed after the table
correction, not before it.

**Idempotency check:** `grep -q '^0.6.0$' .codex/workflow-version.txt 2>/dev/null`

**Pre-condition:** `.codex/` exists

**Apply:** `echo "0.6.0" > .codex/workflow-version.txt`

**Rollback:** `echo "0.5.0" > .codex/workflow-version.txt`

**There is no step that bumps a target project's local scaffolder trigger
skill's SKILL.md, and none should be added.** No target project has a local
`skills/` tree — the setup skill's project-side surface is `AGENTS.md`,
`.planning/`, `.codex/`, and `docs/decisions/` only (see `## Notes` for the
full evidence trail). This repo's own scaffolder bump happened separately,
in plan `08-05`'s commit, as a direct edit to this repo's own file — never
as a migration step shipped to other people's repos.

**This repo's own scaffolder bump (direct edit, not a migration step, this
commit):** this repo's own scaffolder trigger skill's SKILL.md `version: 0.5.0` ->
`0.6.0` — the scaffolder `install.sh` publishes to `${CODEX_HOME}` and the
update skill reads as the target version — and this repo's own
`.codex/workflow-version.txt` -> `0.6.0`, the project record Step 3
maintains for everyone else. `implements_spec: 0.4.0` is left untouched
(D-17 — it tracks the last full conformance audit, not one gate).

## Post-checks

```bash
# 1. Config bound at the leaf, sibling gates and other groups intact
#    (ALWAYS true on success — the specific sibling/group content depends on
#    the install; this asserts the shape, not literal fixture values).
jq -e '.hooks.pre_execution.plan_review.min_reviewers == 2' .planning/config.codex.json >/dev/null

# 2. Ritual section wired into AGENTS.md (ALWAYS true on success)
grep -q '^## Pre-execution Gate — Plan Review (spec §02)' AGENTS.md

# 3. Bindings table corrected (D-20): exactly one plan-review row, one tdd
#    row, two brainstorm rows, and row count == distinct-gate count == 16 —
#    identical to a fresh install. This block assumes Step 3 completed; if
#    the operator instead chose skip-with-warning on Step 3's header-mismatch
#    precondition failure, the migration is recorded partial (per the
#    atomicity contract) and the table is intentionally left as it was — the
#    partial record, not this check, is authoritative in that case. Gate the
#    assertion on the recorded outcome, not on optimism: a post-check that
#    fails on a step the operator explicitly chose to skip would turn a
#    consented partial into a reported failure.
if grep -q '^| plan-review' AGENTS.md; then
  test "$(grep -c '^| plan-review' AGENTS.md)" = "1"
  test "$(grep -c '^| tdd |' AGENTS.md)" = "1"
  test "$(grep -ci '^| brainstorm-' AGENTS.md)" = "2"
fi

# 4. Project version record bumped (ALWAYS true on success) — there is no
#    target-project scaffolder-file check; see the Step 4 note above.
grep -q '^0.6.0$' .codex/workflow-version.txt
```

- Drift test green: this repo's own scaffolder trigger skill's SKILL.md
  `version` (0.6.0) == latest migration `to_version` (0.6.0).

## Skip cases

Every skip is **step-local**, with one exception: Step 3's header mismatch,
which is a **failed precondition**, not a skip (see below). There is no
migration-level skip predicate — an earlier revision had one (the migration
as a whole would skip when `.hooks.pre_execution.plan_review` is already
present) and it is wrong: the atomicity contract
(`migrations/README.md:103-113`) lets an operator choose *skip-with-warning*
on a failed step, recording the migration `partial` and continuing — so a
real install can legitimately have Step 1 applied and Step 2 not, and
re-running to finish is the documented recovery path. A migration-wide skip
keyed on Step 1's artifact would make that recovery a no-op that reports
success, stranding the install half-migrated while claiming it is current
(T-08-39).

- **`from_version` mismatch** (project not at 0.5.0) → migration framework
  skips silently. Projects below 0.5.0 replay the chain through 0007 first.
- **Step 1 already present** (a fresh install got it from the template, or a
  prior partial run applied it) → Step 1 idempotency is positive; the
  existing block is preserved verbatim and **Steps 2, 3, and 4 still run**.
- **Step 2 already present** (fresh install got the section from the
  template, or a prior partial run applied it) → Step 2 is a no-op; **Steps
  1, 3, and 4 still run**.
- **Step 3 already present** (the table already carries a `plan-review` row
  — a fresh install got it from the template, or a prior partial run applied
  it) → Step 3 is a no-op; **Steps 1, 2, and 4 still run**.
- **Step 3's table header does not match the template's — NOT a skip, a
  failed precondition.** The step declines to touch a table whose shape it
  does not recognise, but reports this as a precondition failure, not a
  successful step (T-08-40). Routes to the update skill's per-step failure
  prompt: retry / skip-with-warning (records the migration `partial`) /
  rollback. This repo's own hand-maintained `AGENTS.md` (`Applies to
  scaffolder?` header, not the template's `Scope`) is exactly the shape that
  would trigger this decline if it were ever a migration TARGET — which it
  is not; `08-04` corrected this repo's own `AGENTS.md` by hand, and this
  migration is never applied to this repo.
- **Step 4 already present** (`.codex/workflow-version.txt` already reads
  `0.6.0`) → Step 4 is a no-op.
- **No verifier CLIs available on this machine** → not this migration's
  concern: the config block, ritual section, and bindings table are wired
  regardless; the producer skill's own graceful degradation (D-14, `< 2`
  reviewers → refuse) handles that at invocation time, never here.

## Compatibility

- **Additive (minor) bump** to `0.6.0`: no breaking change. Step 1 only adds
  a leaf key at `hooks.pre_execution.plan_review`, preserving every existing
  key at every level (sibling pre-execution gates, other hook groups,
  foreign top-level keys); Step 2 only inserts a section inside the existing
  marker block; Step 3 only rewrites bindings-table rows it recognises,
  preserving every row it does not touch, and declines entirely (a failed
  precondition, never a silent success) rather than guess on an
  unrecognised table shape.
- **Host-scoped, unlike 0007:** the `pre_execution` block lives in
  `.planning/config.codex.json`, matching the other 15 gates, not the
  host-neutral `.planning/config.json` (see the framing note above).
- **Drift coupling:** as the highest-numbered migration file, 0008's
  `to_version` (0.6.0) is the drift target; this repo's own scaffolder
  trigger skill's SKILL.md is bumped to 0.6.0 in lockstep, in this same
  commit, as a direct edit to this repo (`run-tests.sh` `test_drift`).
- **Supported upgrade floor: 0.5.0 -> 0.6.0.** Every live project already
  sits at 0.5.0 after 0007.
- Per migration immutability, the chain stays contiguous
  (`0000` → `0001` → … → `0007` → `0008`).

## Notes

- **Testable** non-interactively via `test_migration_0008` in
  `migrations/run-tests.sh`: it asserts the leaf-level idempotency check
  (including the skip-when-a-sibling-exists case), merge preservation
  against a fixture carrying a sibling pre-execution gate, a different-group
  gate, and a foreign top-level key, rollback that removes only our leaf and
  drops the parent only when empty, the AGENTS.md ritual-section insert +
  its cksum-verified idempotent re-apply, the bindings-table step's
  header-shape guard (both the Scope-shaped target that applies and the
  `Applies to scaffolder?`-shaped target that declines and is left
  byte-identical), all three table corrections (brainstorm split, tdd
  collapse, plan-review add) with row-count == distinct-gate-count == 16,
  a row-for-row diff against the template, and a cksum-verified idempotent
  re-apply, the version-bump round-trip, a no-scaffolder-tree fixture (a
  sandbox shaped like a real target project with no local `skills/`
  directory), and a partial-application fixture proving every skip is
  step-local.
- **Deliberate divergence from 0007's pre-flight and `applies_to`: this
  migration names no path under a target project's `skills/` tree, anywhere
  (T-08-38).** 0007's pre-flight greps
  `skills/agentic-apps-workflow/SKILL.md` for its version floor, and its own
  Step 3 seds that same path. **No target project has a local `skills/`
  tree** — the setup skill's project-side surface is `AGENTS.md`,
  `.planning/`, `.codex/`, and `docs/decisions/` only
  (`setup-codex-agenticapps-workflow/SKILL.md`'s own description and
  post-checks), and the update skill reads the scaffolder version from
  `${CODEX_HOME}`, not the project, while executing migration steps in the
  project. So 0007's floor grep hits a non-existent path and its pre-flight
  aborts with exit 3 on every real install — a defect this migration does
  not replicate. This migration's floor reads `.codex/workflow-version.txt`
  instead, the durable per-project record the update skill itself uses, and
  carries no step touching any target project's scaffolder file. **Migration
  0007's identical bug is NOT fixed here** — different migration, own scope,
  recorded as a deferred item (fixing it means re-testing a shipped upgrade
  path).
- **Mirrors** claude-workflow's `0025-fix-multi-ai-review-gate-resolution` /
  `migration-0016` (the reference host) in this host's own idiom, per the
  core ADR-0007 downstream-hosts note. Codex ships no native `hooks.json`
  runtime in this phase (D-02); the fresh-install path is conformant by
  construction (the template already carries the config block and the
  ritual section; this migration seeds only existing installs).

## References

- Core spec: `agenticapps-workflow-core/spec/02-hook-taxonomy.md` §"Pre-execution gate" (lines 81-109)
- Core conformance: `agenticapps-workflow-core/spec/09-conformance.md`
- This repo's ADR: `docs/decisions/0009-plan-review-gate.md`
- Sibling precedent: claude-workflow `docs/decisions/0025-fix-multi-ai-review-gate-resolution.md` / `migrations/0016-*.md`
- Standard: `docs/standards/gsd-binding-and-planning.md` §4 (namespaced config) + conformance checklist
- Prior migration this one diverges from with care: `migrations/0007-knowledge-capture.md`
