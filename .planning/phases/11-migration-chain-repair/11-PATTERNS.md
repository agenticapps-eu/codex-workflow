# Phase 11: Migration Chain Repair - Pattern Map

**Mapped:** 2026-07-16
**Files analyzed:** 3 (1 new, 2 modified — `run-tests.sh`'s edit is additive-function-plus-registration)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `migrations/0010-<slug>.md` (NEW) | migration (config/doc, versioned patch spec) | file-I/O / transform | `migrations/0008-plan-review-gate.md` (pre-flight) + `migrations/0007-knowledge-capture.md` (Steps 1/2/4 payload) | exact (composite: pre-flight from 0008, payload from 0007) |
| `skills/update-codex-agenticapps-workflow/SKILL.md` §Stage D (MODIFIED) | route/skill spec (documentation) | request-response (prose instructions, no code) | itself — existing Stage D (lines 72-87) and Failure modes (123-139) | role-match (style precedent only; no prior "recovery runbook" subsection exists anywhere in the repo) |
| `migrations/run-tests.sh` — new `test_migration_0010()` + dispatch registration (MODIFIED) | test (bash fixture harness function) | CRUD-ish / batch assertions over a synthesized sandbox | `test_migration_0008` (lines 953-1727, esp. the no-scaffolder-tree block 1651-1727) + `test_migration_0009`'s ported ` no-scaffolder-tree` ‑and‑ document-contract blocks (lines 3453-3651, 4527-4596) | exact |

**Important correction to the phase brief's file list:** there is **no `migrations/test-fixtures/*.md` (or similar) file to create**. `migrations/test-fixtures/` contains only `README.md`, which documents (lines 66-75 of that file) a deliberate house rule: **no static fixture files** — every fixture is synthesized inline inside its `test_migration_NNNN()` function in `run-tests.sh` via `mktemp -d` + heredocs, exactly as 0007/0008/0009 already do. MIGR-08's and 0010's fixtures belong **inside `run-tests.sh`** as a new `test_migration_0010()` function (and possibly a small addition to the existing `test_migration_0008()` if the Step-4 extraction assertion is added there instead — planner's call), not as new files under `test-fixtures/`.

## Pattern Assignments

### `migrations/0010-<slug>.md` (migration, file-I/O/transform)

**Primary analog for frontmatter + pre-flight:** `migrations/0008-plan-review-gate.md`
**Primary analog for Steps 1/2/4 payload:** `migrations/0007-knowledge-capture.md`

**Frontmatter pattern** (`migrations/0008-plan-review-gate.md:1-13`):
```yaml
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
```
0010 must set `id: 0010`, `from_version: 0.4.0`, `to_version: 0.5.0` (same floor 0007 was supposed to move), and `applies_to` listing exactly `.planning/config.json`, `AGENTS.md`, `.codex/workflow-version.txt` (D-03 — **no** `skills/**/SKILL.md` path anywhere, matching 0008's T-08-38 divergence).

**Pre-flight pattern — VERBATIM REUSE REQUIRED (D-01)** (`migrations/0008-plan-review-gate.md:54-93`):
```bash
## Pre-flight

# Project root must be a git repo (repo-name derivation + atomic commit)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# jq is required for the config merge
command -v jq >/dev/null || { echo "ABORT: jq not found — required for the config merge"; exit 2; }

# Workflow project version is at the supported floor (0.5.0), or 0.6.0 for
# re-apply. DELIBERATE DIVERGENCE from 0007's floor check, which greps this
# repo's own scaffolder trigger skill's SKILL.md — a path NO target project
# has ...
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
```
Copy this pattern **verbatim**, only reflooring the version-gate regex to `^0\.(4|5)\.0$` (0010's own floor: accept `0.4.0` for a fresh apply, `0.5.0` for idempotent re-apply — same shape as 0008's `^0\.(5|6)\.0$`), rewording the ABORT text to name `0.4.0`/`0.5.0` and 0010, and swapping the two template-existence checks for the two templates 0007 Steps 1/2 actually need (`config-knowledge-capture.json` + `agents-md-additions.md`, per 0007's own pre-flight below). **Do not** reintroduce 0007's `grep -qE '^version: 0\.(4|5)\.0$' skills/agentic-apps-workflow/SKILL.md` check (`0007-knowledge-capture.md:59-65`) — that grep against a path no real target project has is the exact bug 0010 exists to fix (D-03, D-07).

**0007's buggy pre-flight — reference ONLY, do not copy the floor line** (`migrations/0007-knowledge-capture.md:49-73`), template-existence checks (lines 67-72) are still valid and should be ported:
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
test -f "$CODEX/skills/setup-codex-agenticapps-workflow/templates/config-knowledge-capture.json" || {
  echo "ABORT: config-knowledge-capture.json template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
test -f "$CODEX/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md" || {
  echo "ABORT: agents-md-additions.md template missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
```

**Payload — Step 1 (config.json merge)**, copy near-verbatim from `migrations/0007-knowledge-capture.md:77-109` (idempotency check, pre-condition, Apply block resolving `<repo-name>` via `jq`, merge-or-create branch, Rollback).

**Payload — Step 2 (AGENTS.md ritual-tail insert)**, copy near-verbatim from `migrations/0007-knowledge-capture.md:111-151` (the `awk` extract-from-template-then-insert-before-END-marker two-pass pattern).

**Payload — Step 4 (version record), renumbered from 0007's Step 4 to 0010's Step 3** (0007 Step 3, the scaffolder version bump, is dropped per D-03) — `migrations/0007-knowledge-capture.md:166-171`:
```bash
### Step 4: Record the new project version

**Idempotency check:** `grep -q '^0.5.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:** `echo "0.5.0" > .codex/workflow-version.txt`
**Rollback:** `echo "0.4.0" > .codex/workflow-version.txt`
```
This is also the **exact step MIGR-08's fixture and 0010's own fixture assert exact content-equality against**.

**"No target-project `skills/` step" prose precedent** — copy the discipline, not the words, from `migrations/0008-plan-review-gate.md:336-342` and the Notes-section divergence writeup at `migrations/0008-plan-review-gate.md:470-487`, which is the existing precedent for documenting "this migration deliberately does not touch `skills/agentic-apps-workflow/SKILL.md`, unlike 0007" — 0010 should carry an equivalent Notes-section paragraph recording the fix and referencing 0007 by number.

---

### `skills/update-codex-agenticapps-workflow/SKILL.md` §Stage D (skill spec, request-response/doc)

**No prior analog exists for a "recovery runbook" subsection** — grepped the whole repo (`skills/*/SKILL.md`, `migrations/*.md`) for `Recovery`, `Troubleshooting`, `superseded by`, `stuck`; nothing found. This is new prose. Match the **structural style** of the existing skill doc, not a borrowed section:

**Stage D style precedent** (`skills/update-codex-agenticapps-workflow/SKILL.md:72-87`):
```markdown
### Stage D — Apply

9. **For each pending migration**, in `id` order:
   - For each step:
     - Idempotency check — skip with log line if applied
     - Pre-condition — fail with specific message if false
     - Apply — write the patch
     - Verify — re-run idempotency check post-apply (must now
       return 0)
   - On step failure: prompt user with retry / skip-with-warning /
     rollback options per the atomicity contract in
     `migrations/README.md`.
   - On migration completion: update `.codex/workflow-version.txt`
     to the migration's `to_version`. This is the durable
     record.
```

**Failure modes style precedent** (`skills/update-codex-agenticapps-workflow/SKILL.md:123-139`) — bold lead-in per bullet, terse imperative, one line of "why":
```markdown
## Failure modes

- **Running on an uninstalled project.** Pre-flight catches this;
  route to setup.
- **Pending migration with missing `requires`.** Surface the install
  command; do not silently skip — the migration may produce broken
  output.
```
Add the recovery runbook as a new numbered sub-step or bulleted block inside `### Stage D — Apply` (per D-04, concise — not a new top-level `##` section) covering the two operator states named in D-04(a)/(b): (a) stuck on 0007's permanent abort → re-run update, 0010 applies instead (0007 is superseded); (b) manual-0.5.0-escape operator → exact commands to obtain 0007's missing payload (effectively: re-run `$update-codex-agenticapps-workflow --migration 0010`, using the `--migration NNNN` flag already documented at `skills/update-codex-agenticapps-workflow/SKILL.md:110`).

---

### `migrations/run-tests.sh` — `test_migration_0010()` (test, batch/CRUD assertions)

**Analog for `extract_step_block` usage (MIGR-08's core mechanism):** `migrations/run-tests.sh:100-117`
```bash
# extract_step_block <doc_path> <step_number> <label>
# Prints the FIRST fenced block following a `**<label>:**` line within
# `### Step <step_number>`, scoped to end at `### Step <step_number+1>`.
extract_step_block() {
  local doc="$1" step="$2" label="$3"
  local next_step=$((step + 1))
  awk -v stepp="### Step ${step}" \
      -v nextp="### Step ${next_step}" \
      -v lblp="**${label}:**" '
    index($0, stepp) == 1 { in_step=1; next }
    index($0, nextp) == 1 { in_step=0 }
    in_step && index($0, lblp) == 1 { want=1; next }
    want && /^```/ { inb=1; want=0; next }
    inb && /^```$/ { exit }
    inb { print }
  ' "$doc"
}
```
And `extract_preflight_block` (`migrations/run-tests.sh:119-133`) for pulling 0010's own pre-flight fence — needed for the D-07 document-contract assertion.

**Live usage precedent (0009's own fixture)** — the exact call shape MIGR-08's fixture should copy (`migrations/run-tests.sh:3476-3479`):
```bash
local pf_block idem_block apply_block
pf_block="$(extract_preflight_block "$MIGRATION_0009" 2>/dev/null)"
idem_block="$(extract_step_block "$MIGRATION_0009" 1 "Idempotency check" 2>/dev/null)"
apply_block="$(extract_step_block "$MIGRATION_0009" 1 Apply 2>/dev/null)"
```
For MIGR-08, the equivalent extraction is 0008's **Step 4**:
```bash
local MIGRATION_0008="$REPO_ROOT/migrations/0008-plan-review-gate.md"
local m08_step4_apply
m08_step4_apply="$(extract_step_block "$MIGRATION_0008" 4 Apply 2>/dev/null)"
```
then gate on `assert_extracted_shape` (`migrations/run-tests.sh:142-`, non-empty + contains `.codex/workflow-version.txt`) before executing it in a sandbox seeded at `0.5.0` (pre-migration value per D-05) and asserting **exact** content equality (`cksum`/`diff`, not `grep -q`) against `0.6.0`.

**Mutation-proof discipline (manual dev-time step, not automated in the harness)** — confirmed via `.planning/research/PITFALLS.md:482` / `SUMMARY.md:41,80`: comment out (or delete) the migration's `echo "X.Y.Z" > .codex/workflow-version.txt` write line, re-run the fixture, observe RED, then restore and re-run to confirm GREEN. The verifier independently repeats this cycle rather than trusting a SUMMARY.md claim (`PITFALLS.md:451-491`, `676`). There is no code pattern for this in `run-tests.sh` to copy — it is a one-time authoring/verification ritual, not a persisted assertion.

**No-local-`skills/`-tree sandbox construction (D-07's required fixture shape)** — direct analog, 0008's own fixture (`migrations/run-tests.sh:1651-1727`):
```bash
local tmp2; tmp2="$(mktemp -d)"
mkdir -p "$tmp2/.planning" "$tmp2/.codex" "$tmp2/docs/decisions"
cat > "$tmp2/.planning/config.codex.json" <<'JSON'
{ "hooks": { "post_phase": { "spec_review": { "skill": "codex-spec-review" } } } }
JSON
cat > "$tmp2/AGENTS.md" <<'MD'
# AGENTS.md — no-scaffolder-tree fixture

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Session handoff

Existing content.

<!-- END: agentic-apps-workflow sections -->
MD
printf '0.5.0\n' > "$tmp2/.codex/workflow-version.txt"

if test ! -e "$tmp2/skills"; then
  echo "  ${GREEN}PASS${RESET} no-scaffolder-tree fixture has no local skills/ directory"
  PASS=$((PASS+1))
else
  echo "  ${RED}FAIL${RESET} no-scaffolder-tree fixture unexpectedly has a skills/ directory"
  FAIL=$((FAIL+1))
fi
```
0010's D-06 fixture is this shape but seeded at `0.4.0` instead of `0.5.0`, carrying **none** of 0007's artifacts (no `knowledge_capture` key, no ritual-tail section) — the clean pre-migration state — then asserting both the payload delivery and `.codex/workflow-version.txt == 0.5.0` post-apply.

**Document-contract assertion for D-07 (no `skills/agentic-apps-workflow` substring anywhere executable)** — direct analog, 0009's port of the same guard (`migrations/run-tests.sh:4583-4590`):
```bash
applies_to_block="$(awk '/^applies_to:/{f=1;next} f && /^[^ ]/{exit} f{print}' "$MIGRATION_0009")"
step2_apply_block="$(extract_step_block "$MIGRATION_0009" 2 Apply 2>/dev/null)"
sep_bad=0
printf '%s' "$applies_to_block" | grep -q 'skills/' && sep_bad=1
printf '%s' "$pf_block" | grep -q 'skills/agentic-apps-workflow' && sep_bad=1
printf '%s' "$apply_block" | grep -q 'skills/agentic-apps-workflow' && sep_bad=1
_m0009_ok "$sep_bad" "no-scaffolder-tree: MIGR-08/MIGR-09 separation — no executable surface ... names skills/agentic-apps-workflow/SKILL.md"
```
For 0010, extract `applies_to`, the pre-flight block, and every Step's Apply block (Steps 1, 2, 4 — 0010's renumbered Step 3), and assert none contains `skills/agentic-apps-workflow` (this is D-07's literal wording; match it exactly, not `skills/` generally, since `skills/` alone would false-positive on legitimate `$CODEX_HOME/skills/setup-codex-agenticapps-workflow/templates/...` references that both 0007 and 0008 correctly retain).

**`assert_check` / `run_check` primitives (shared lib, used by every `test_migration_NNNN`)** — `vendor/agenticapps-shared/migrations/lib/helpers.sh:49-79`:
```bash
run_check() {
  local fixture="$1" check="$2"
  ( cd "$fixture" && eval "$check" >/dev/null 2>&1 )
  return $?
}

assert_check() {
  local label="$1" check="$2" fixture="$3" expected="$4"
  run_check "$fixture" "$check"
  local actual=$?
  local pass=0
  case "$expected" in
    applied)     [ "$actual" = "0" ] && pass=1 ;;
    not-applied) [ "$actual" != "0" ] && pass=1 ;;
    *) echo "  ${RED}!${RESET} bad expected value: $expected"; FAIL=$((FAIL+1)); return ;;
  esac
  ...
}
```
Use for 0010's own double-sided idempotency assertions (Step-1/2/4 idempotency check false on before-state, true on after-state) — do not hand-roll a new assertion helper.

**Dispatch registration pattern** (`migrations/run-tests.sh:4668-4678`):
```bash
if [ -z "$FILTER" ] || [ "$FILTER" = "0009" ]; then
  test_migration_0009
fi
```
Add an equivalent `if [ -z "$FILTER" ] || [ "$FILTER" = "0010" ]; then test_migration_0010; fi` block immediately after 0009's, before the `check-plan-review` / `drift` / `layout` blocks.

---

## Shared Patterns

### Fence-scoped extraction (`extract_step_block` / `extract_preflight_block`)
**Source:** `migrations/run-tests.sh:100-133`
**Apply to:** `test_migration_0010` (MIGR-08's Step-4-of-0008 extraction) and any 0010-self-extraction used for the D-07 document contract.
Never hand-transcribe a step's Apply/Idempotency-check text into the test file — extract it from the real `.md` document (TEST-01 discipline, `migrations/run-tests.sh:61-77`).

### `assert_extracted_shape` (extraction non-empty AND contains a required substring)
**Source:** `migrations/run-tests.sh:142-` (definition), used at `migrations/run-tests.sh:3504-3555` (0009's usage)
**Apply to:** every extracted block in `test_migration_0010`, gated before any assertion that consumes it — a silently-empty extraction must FAIL loudly, not produce a vacuously-passing downstream check (Pitfall #5 / D-36).

### `assert_check` / `run_check` (double-sided idempotency assertion)
**Source:** `vendor/agenticapps-shared/migrations/lib/helpers.sh:49-79`
**Apply to:** every idempotency check 0010 ships (Steps 1, 2, 4).

### No-local-`skills/`-tree sandbox shape
**Source:** `migrations/run-tests.sh:1651-1681` (0008 original), ported at `migrations/run-tests.sh:4538-4562` (0009)
**Apply to:** 0010's fixture (D-06/D-07) and MIGR-08's fixture sandbox for the Step-4 extraction (the sandbox that seeds `.codex/workflow-version.txt = 0.5.0` and executes 0008's real Step 4 Apply block must not manufacture a `skills/` tree either, for the same reason).

### Mutation-proof discipline (comment-out-the-write-line → RED → restore)
**Source:** no code — a documented ritual in `.planning/research/PITFALLS.md:482`, `.planning/research/SUMMARY.md:41,80`.
**Apply to:** MIGR-08's fixture and 0010's Step 4 assertion. Must be independently re-run by the verifier, not accepted from a self-report.

### Migration document structure (frontmatter → Pre-flight → Steps → Post-checks → Skip cases → Compatibility → Notes → References)
**Source:** `migrations/README.md:47-100` (contract) and every existing `migrations/NNNN-*.md` file.
**Apply to:** `migrations/0010-*.md` in full — every step needs all four mandatory subsections (Idempotency check / Pre-condition / Apply / Rollback), per `migrations/README.md:73-80`.

---

## No Analog Found

| File / subsection | Role | Data Flow | Reason |
|---|---|---|---|
| Recovery-runbook prose inside `update-codex-agenticapps-workflow/SKILL.md` §Stage D | documentation | request-response | No prior "recovery runbook" / "troubleshooting" / "superseded migration" section exists anywhere in `skills/*/SKILL.md` or `migrations/*.md` — grepped repo-wide, zero hits. Use the Stage D / Failure-modes bullet style (bold lead-in + terse imperative) as the closest structural precedent (see Pattern Assignments above), not a borrowed section. |
| `migrations/test-fixtures/*` new files | — | — | Not applicable — this repo's established, documented convention (`migrations/test-fixtures/README.md:66-75`) is **no static fixture files**; everything is synthesized inline in `run-tests.sh`. Do not create files here for MIGR-08 or 0010. |

## Cautions for the Planner (drift-test interaction)

`test_drift` (`migrations/run-tests.sh:3217-3249`) delegates to `run_drift_test` (`vendor/agenticapps-shared/migrations/lib/drift-test.sh:34-63`), which picks the "latest migration" by **filename sort**, not by `to_version`:
```bash
latest_migration_file=$(ls "${migrations_dir}"/[0-9][0-9][0-9][0-9]-*.md 2>/dev/null | sort | tail -1)
```
Today `0009-*.md` sorts last and its `to_version: 0.7.0` matches `skills/agentic-apps-workflow/SKILL.md`'s current `version: 0.7.0` (confirmed: both files currently read `0.7.0`). Adding `0010-*.md` with `to_version: 0.5.0` will make it sort **last alphabetically**, and `run_drift_test` will then compare `SKILL.md`'s `0.7.0` against 0010's `0.5.0` — a drift-test FAIL, not because anything is broken, but because 0010 is a *backport* landing after later migrations by version. The planner must account for this in Phase 11's plan (e.g., an explicit, justified exception/assertion in `test_drift` or a documented rationale) — it is a real consequence of D-01's fixed `id: 0010`, flagged here because it directly touches the `test_drift` analog this phase's fixture work sits beside.

## Metadata

**Analog search scope:** `migrations/` (all `.md` + `run-tests.sh` + `README.md` + `test-fixtures/README.md`), `vendor/agenticapps-shared/migrations/lib/` (`helpers.sh`, `drift-test.sh`), `skills/update-codex-agenticapps-workflow/SKILL.md`, `.planning/research/{SUMMARY,PITFALLS}.md`
**Files scanned:** `0007-knowledge-capture.md`, `0008-plan-review-gate.md`, `0009-spec-11-region-aware-placement.md` (frontmatter + targeted sections), `run-tests.sh` (targeted non-overlapping reads: 1-150, 749-1008, 1638-1732, 3217-3276, 3453-3652, 4520-4600, 4640-4710), `helpers.sh`, `drift-test.sh`, `README.md` (migrations), `test-fixtures/README.md`, `update-codex-agenticapps-workflow/SKILL.md` (full)
**Pattern extraction date:** 2026-07-16
