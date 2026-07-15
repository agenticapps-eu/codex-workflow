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
carries the `hooks.pre_execution.plan_review` block, and the ritual section
already ships inside `agents-md-additions.md`. An install already at `0.5.0`
gets neither — this migration teaches an **existing install** the config
block and the ritual section so a migrated install reaches the same bound
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

### Step 3: Record `0.6.0` in `.codex/workflow-version.txt`

This is the project's durable version record, and the last step, per 0007's
content-steps-then-version-seal convention.

**Idempotency check:** `grep -q '^0.6.0$' .codex/workflow-version.txt 2>/dev/null`

**Pre-condition:** `.codex/` exists

**Apply:** `echo "0.6.0" > .codex/workflow-version.txt`

**Rollback:** `echo "0.5.0" > .codex/workflow-version.txt`

**There is no Step that bumps a target project's local scaffolder trigger
skill's SKILL.md, and none should be added.** No target project has a local
`skills/` tree — the setup skill's project-side surface is `AGENTS.md`,
`.planning/`, `.codex/`, and `docs/decisions/` only (see `## Notes` for the
full evidence trail). This repo's own scaffolder bump happens separately,
below, as a direct edit to this repo's own file in this same commit — never
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

# 3. Project version record bumped (ALWAYS true on success) — there is no
#    target-project scaffolder-file check; see the Step 3 note above.
grep -q '^0.6.0$' .codex/workflow-version.txt
```

- Drift test green: this repo's own scaffolder trigger skill's SKILL.md
  `version` (0.6.0) == latest migration `to_version` (0.6.0).

## Skip cases

Every skip is **step-local**. There is no migration-level skip predicate —
an earlier revision had one ("the whole migration skips when
`.hooks.pre_execution.plan_review` is already present") and it is wrong: the
atomicity contract (`migrations/README.md:103-113`) lets an operator choose
*skip-with-warning* on a failed step, recording the migration `partial` and
continuing — so a real install can legitimately have Step 1 applied and Step
2 not, and re-running to finish is the documented recovery path. A
whole-migration skip keyed on Step 1's artifact would make that recovery a
no-op that reports success, stranding the install half-migrated while
claiming it is current (T-08-39).

- **`from_version` mismatch** (project not at 0.5.0) → migration framework
  skips silently. Projects below 0.5.0 replay the chain through 0007 first.
- **Step 1 already present** (a fresh install got it from the template, or a
  prior partial run applied it) → Step 1 idempotency is positive; the
  existing block is preserved verbatim and **Steps 2 and 3 still run**.
- **Step 2 already present** (fresh install got the section from the
  template, or a prior partial run applied it) → Step 2 is a no-op; **Steps
  1 and 3 still run**.
- **Step 3 already present** (`.codex/workflow-version.txt` already reads
  `0.6.0`) → Step 3 is a no-op.
- **No verifier CLIs available on this machine** → not this migration's
  concern: the config block and ritual section are wired regardless; the
  producer skill's own graceful degradation (D-14, `< 2` reviewers → refuse)
  handles that at invocation time, never here.

## Compatibility

- **Additive (minor) bump** to `0.6.0`: no breaking change. Step 1 only adds
  a leaf key at `hooks.pre_execution.plan_review`, preserving every existing
  key at every level (sibling pre-execution gates, other hook groups,
  foreign top-level keys); Step 2 only inserts a section inside the existing
  marker block.
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
  drops the parent only when empty, the AGENTS.md section insert + its
  cksum-verified idempotent re-apply, the version-bump round-trip, a
  no-scaffolder-tree fixture (a sandbox shaped like a real target project
  with no local `skills/` directory), and a partial-application fixture
  proving every skip is step-local.
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
