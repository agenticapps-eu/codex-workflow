# Phase 8: Plan-Review Gate - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 10 (2 new authored, 1 new script, 1 new ADR, 6 modified)
**Analogs found:** 9 / 10 (1 file — `check-plan-review.sh` — has no in-repo shell-script analog; ported from an out-of-repo reference with a named defect to avoid)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `skills/codex-plan-review/SKILL.md` | producer skill (gate producer, invokes external CLIs) | request-response (spawns `codex exec`-style child processes, writes an artifact) | `skills/codex-spec-review/SKILL.md` (structure) + `docs/decisions/0002-stage2-independent-reviewer-on-codex.md` (external-CLI-invocation precedent) | role-match (no `codex-*` skill invokes *other-vendor* CLIs yet; closest analog for skill shape + closest analog for the invocation mechanism are two different files) |
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` | verifier / gate script | request-response (stdin-independent, reads filesystem, exits 0/2) | `../claude-workflow/templates/.claude/hooks/multi-ai-review-gate.sh` (OUTSIDE this repo, reference only) | role-match, port-with-care (no shell script exists anywhere under `skills/` in this repo today — zero in-repo analogs; reference has a named defect, D-06) |
| `migrations/0008-*.md` | migration (config merge + doc insert + version bump) | batch / idempotent-transform | `migrations/0007-knowledge-capture.md` | exact |
| `docs/decisions/0009-*.md` | ADR | document | `docs/decisions/0008-knowledge-capture.md` | exact |
| `.planning/config.codex.json` | config | CRUD (declarative binding map) | `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` (its own template pair) | exact |
| `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` | config template | CRUD | (self — extend existing `hooks` object with new `pre_execution` group) | exact |
| `AGENTS.md` | doc (always-loaded ritual surface) | document | `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md` §"Workflow Enforcement Hooks" table + `migrations/0007` §Step 2 insert mechanics | exact |
| `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md` | template (single source of truth for ritual prose) | document | itself, §"Knowledge Capture — Ritual Tail" section (structurally identical precedent: a spec-numbered ritual section inserted before the END marker) | exact |
| `migrations/run-tests.sh` | test harness (bash function per migration + verifier fixtures) | batch / test | `migrations/run-tests.sh` `test_migration_0007()` (lines 573-732) | exact |
| `skills/agentic-apps-workflow/SKILL.md` | trigger skill (mirrors AGENTS.md ritual + bindings table) | document | itself, its own "Workflow Enforcement Hooks" table (lines ~27-41 in the template mirror) + §"Knowledge Capture — Ritual Tail" mirroring precedent | exact |
| `CHANGELOG.md` | doc | document | the two Unreleased "Fixed" entries (migration-discovery symlink fixes) | exact |

## Pattern Assignments

### `skills/codex-plan-review/SKILL.md` (producer skill, request-response)

**Analog 1 (skill shape):** `skills/codex-spec-review/SKILL.md`

**Frontmatter pattern** (lines 1-15):
```yaml
---
name: codex-spec-review
version: 0.1.0
implements_spec: 0.4.0
implements_gate: spec-review
description: |
  Stage 1 of the two-stage review: audit the phase's changeset against
  CONTEXT.md decisions, every must_have in VERIFICATION.md, the gate
  bindings, and the protocol-violation list...
---
```
Copy this shape for `codex-plan-review`: `name`, `version: 0.1.0`, `implements_spec: 0.4.0` (per D-17, do not bump), `implements_gate: plan-review`, a `description:` block naming the trigger condition and the artifact it writes (`<NN>-REVIEWS.md`).

**"When to invoke" + numbered procedure pattern** (lines 26-101): `codex-spec-review` structures its body as (1) read phase artifacts, (2) walk a checklist, (3) decide an outcome enum (`clean` / `clean-with-followups` / `gap`), (4) show the exact Markdown skeleton to write. Mirror this shape for `codex-plan-review`:
1. Detect available reviewer CLIs (`claude`, `gemini`, `opencode`; exclude `codex` per D-15 self-skip).
2. Build the adversarial prompt carrying `<NN>-CONTEXT.md` + all `<NN>-*-PLAN.md` + `Canonical refs` resolved from ROADMAP.md (D-16).
3. Invoke each available CLI; capture output + provenance (CLI, model, timestamp).
4. If `< 2` reviewers available: report and refuse — do not write a one-reviewer `REVIEWS.md` (D-14).
5. Write `<NN>-REVIEWS.md` per the D-12 schema (see Shared Patterns → REVIEWS.md schema below).

**"Required evidence" pattern** (lines 103-111): copy this closing-section shape verbatim in structure — state the exact frontmatter keys and body headings the verifier will check, so the skill is self-documenting against its own gate.

**Failure-modes section pattern** (lines 113-122): list the concrete failure modes for this skill — e.g. "emitting a REVIEWS.md with 1 reviewer to pass a naive line-count check," "fabricating a reviewer's output when its CLI errored," "silently dropping to the ≥5-line fallback when frontmatter parsing would have caught the shortfall."

**Analog 2 (external-CLI child-process invocation mechanism):** `docs/decisions/0002-stage2-independent-reviewer-on-codex.md`

**Child-process invocation pattern** (lines 114-131) — the only precedent in this repo for a Codex skill spawning an external CLI as an independent reviewer:
```
codex exec \
  --model "${REVIEWER_MODEL:-gpt-5.4}" \
  --skip-git-repo-check \
  --sandbox read-only \
  "$(cat <<'PROMPT'
You are running a Stage 2 code review. You have not seen the
implementing session's reasoning. Read the plan at PLAN.md, the
diff at HEAD, and the spec citation provided. Produce a REVIEW.md
Stage 2 section listing: (a) what the diff does, ...
PROMPT
)"
```
Adapt this shape per external CLI (`claude`, `gemini`, `opencode` — not `codex`, which is excluded per D-15): same pattern of heredoc-built adversarial prompt piped as the CLI's argument, model/flags substituted per vendor. Note ADR-0002's documented risk: "Stage 2 cannot run if `codex` is missing from PATH... MUST detect this and fall back to a clear message — not silently skip the gate." Apply the same discipline to each vendor CLI: detect availability before invoking, never fabricate output on failure.

**Self-skip detection (Claude's Discretion, D-CONTEXT):** The dashboard's real `REVIEWS.md` documents the *analogous* Claude-side mechanism in prose:
```
The skip rules in `~/.claude/get-shit-done/workflows/review.md` excluded
`claude` (this reviewer is itself running inside Claude Code CLI;
`CLAUDE_CODE_ENTRYPOINT=cli` triggers the self-skip).
```
(from `../agenticapps-dashboard/.planning/phases/DASH-11-coverage-trends-skill-drift/11-REVIEWS.md` lines 24-27). No codex-side env var equivalent to `CLAUDE_CODE_ENTRYPOINT` was found anywhere in this repo — this is genuinely open per CONTEXT.md's "Claude's Discretion" list. `codex-plan-review` excludes `codex` **structurally** (it only shells out to `claude`/`gemini`/`opencode`, never itself), which sidesteps needing an env-var detection at all — flag this as the simpler option to the planner.

---

### `skills/agentic-apps-workflow/scripts/check-plan-review.sh` (verifier script, request-response)

**Analog:** `../claude-workflow/templates/.claude/hooks/multi-ai-review-gate.sh` (OUTSIDE this repo — read-only reference, 174 lines, read in full)

**IMPORTANT — do not port verbatim.** Per D-06/D-07, this reference's resolver has two defects for this repo's port:
1. **Step 2 (lines 94-103) greps a dead heading.** `awk '/^##[[:space:]]+Current Phase/{f=1; ...}'` — but every real `STATE.md` in the fleet (`claude-workflow`, `agenticapps-dashboard`, `agenticapps-roadmap`, `bench-codex`) writes `## Current Position`, never `## Current Phase`. **Match `## Current Position`; tolerate `## Current Phase` as a fallback** (D-06).
2. **Step 3 (lines 105-111), the `gsd-tools.cjs` node-based state lookup, has no Codex analogue.** `~/.codex/get-shit-done/` ships references/workflows/templates and no `bin/`. **Omit this step entirely** (D-07) — collapsing the reference's 5-step resolver to the spec's 4 steps (explicit pointer → STATE.md → newest PLAN → fail-open).

**What to copy as-is (these parts are correct and should be ported faithfully):**

**Fail-open on malformed input** (lines 25-36) — adapt the JSON-guard idea to whatever invocation surface the verifier actually runs under (D-CONTEXT: "whether and how the verifier behaves in `codex exec` / non-interactive contexts" is this repo's own open discretion call — the reference's fail-open *philosophy*, not its literal `jq empty` JSON check, is the reusable part since this repo's verifier is a plain shell script, not a PreToolUse hook consuming stdin JSON):
```bash
if ! echo "$INPUT" | jq empty 2>/dev/null; then
  echo "[multi-ai-review-gate] malformed JSON on stdin, allowing edit (fail-open)" >&2
  exit 0
fi
```

**Explicit-pointer step** (lines 84-92) — resolution step 1, port faithfully:
```bash
p=$(readlink .planning/current-phase 2>/dev/null || true)
if [ -n "$p" ]; then
  [ -d "$p" ] && { echo "$p"; return 0; }
  [ -d ".planning/$p" ] && { echo ".planning/$p"; return 0; }
fi
```
This matches D-05's resolution order exactly (absolute and `.planning/`-relative).

**Newest-plan-by-mtime step** (lines 113-116) — resolution step 3 (this repo's step 3, since step "gsd-tools" is omitted per D-07):
```bash
newest=$(find .planning/phases -maxdepth 2 -name '*-PLAN.md' -print0 2>/dev/null \
          | xargs -0 ls -t 2>/dev/null | head -1 || true)
[ -n "$newest" ] && { dirname "$newest"; return 0; }
```

**Fail-open terminal step** (lines 118-120, 122-126) — resolution step 4 / D-05's "fail-open":
```bash
# 5. Nothing resolved.
return 0
...
CURRENT_PHASE=$(resolve_phase)
if [ -z "$CURRENT_PHASE" ] || [ ! -d "$CURRENT_PHASE" ]; then
  # No active phase pointer — allow (workflow not in active phase execution).
  exit 0
fi
```

**Escape hatches** (lines 45-46, 128-131) — port both verbatim, per D-11:
```bash
[ "${GSD_SKIP_REVIEWS:-}" = "1" ] && exit 0
...
[ -f ".planning/current-phase/multi-ai-review-skipped" ] && exit 0
[ -f "$CURRENT_PHASE/multi-ai-review-skipped" ] && exit 0
```

**Legacy + SUMMARY grandfather guards** (lines 133-142) — port verbatim, per D-08/D-09:
```bash
PLANS=$(find "$CURRENT_PHASE" -maxdepth 2 -name "*-PLAN.md" 2>/dev/null | head -1)
[ -z "$PLANS" ] && exit 0

SUMMARY=$(find "$CURRENT_PHASE" -maxdepth 2 -name "*-SUMMARY.md" 2>/dev/null | head -1)
[ -n "$SUMMARY" ] && exit 0
```
D-08 additionally requires an *explicit* bare-`phases/<NN>/PLAN.md` legacy-layout check (not present in the reference — the reference's legacy grandfathering is an accidental glob property per D-09's own note: `*-PLAN.md` cannot match a bare `PLAN.md`). Add a distinct check, e.g. `[ -f "$CURRENT_PHASE/PLAN.md" ] && [ ! -f "$CURRENT_PHASE"/*-PLAN.md 2>/dev/null ] && exit 0` (exact shape is an implementation detail; the pattern to copy is "make it a named, commented rule," not an emergent glob property).

**Block message + exit 2** (lines 144-159) — copy the message shape, adapting content to D-12/D-13's REVIEWS.md schema and D-14's `min_reviewers` contract:
```bash
REVIEWS=$(find "$CURRENT_PHASE" -maxdepth 2 -name "*-REVIEWS.md" 2>/dev/null | head -1)
if [ -z "$REVIEWS" ]; then
  echo "❌ Multi-AI Plan Review Gate: blocked edit during execution" >&2
  echo "" >&2
  echo "   Phase:     $CURRENT_PHASE" >&2
  echo "   File:      $FILE" >&2
  echo "   Missing:   $CURRENT_PHASE/<padded>-REVIEWS.md" >&2
  echo "" >&2
  echo "   The phase has *-PLAN.md files but no multi-AI plan review." >&2
  echo "   Run /gsd-review before continuing with execution." >&2
  echo "" >&2
  echo "   Override (emergency only): GSD_SKIP_REVIEWS=1 or touch" >&2
  echo "   .planning/current-phase/multi-ai-review-skipped" >&2
  exit 2
fi
```
Per D-04, this repo has no `/gsd-review` upstream prompt to name as the remedy — replace that line with the actual remedy command (`codex-plan-review` skill invocation) per D-03's ritual-text wiring.

**Loose-verifier fallback superseded by D-13** — the reference's final check (lines 161-172) is the *only correct part* to keep as a fallback, not the primary rule:
```bash
[ -f "$REVIEWS" ] || exit 0

if [ "$(wc -l < "$REVIEWS" | tr -d ' ')" -lt 5 ]; then
  echo "⚠ Multi-AI Plan Review Gate: REVIEWS.md present but suspiciously empty" >&2
  ...
  exit 0
fi
```
Per D-13, this must become the **fallback path only, and must block (exit 2), not warn-and-allow**, when frontmatter is absent: parse `reviewers:` from the frontmatter first (`< 2` → exit 2 naming both escape hatches); only fall back to this ≥5-line non-emptiness check when frontmatter itself is absent. The reference's own behavior here (warn + `exit 0`) is *not* what D-13 wants for the primary path — flag this delta explicitly to the planner since it is the single most load-bearing behavioral change from the reference.

**Stable installed path + committed symlink convention (D-CONTEXT: "exact verifier install path"):** follow the pattern in `skills/setup-codex-agenticapps-workflow/SKILL.md` lines 170-181 and the two `migrations -> ../../migrations` symlinks (verified present at `skills/setup-codex-agenticapps-workflow/migrations` and `skills/update-codex-agenticapps-workflow/migrations`, both `lrwxr-xr-x -> ../../migrations`). The verifier script itself lives at repo-root `skills/agentic-apps-workflow/scripts/check-plan-review.sh` (canonical source), and — mirroring the CHANGELOG's Unreleased fixes — must be referenced everywhere at the **stable installed path** `${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/check-plan-review.sh`, never a relative path from inside a target repo. Since `skills/agentic-apps-workflow/` is itself symlinked whole into `~/.codex/skills/` by `install.sh` (no separate per-file symlink needed — the `scripts/` subdirectory travels with the parent skill symlink automatically, unlike the `migrations/` case which needed its own symlink because migrations live in a *different* top-level directory).

---

### `migrations/0008-*.md` (migration, batch/idempotent-transform)

**Analog:** `migrations/0007-knowledge-capture.md` (full file read, 237 lines)

**Frontmatter pattern** (lines 1-14):
```yaml
---
id: 0007
slug: knowledge-capture
title: Knowledge capture into the Obsidian vault — spec §15 (v0.4.0 -> 0.5.0)
from_version: 0.4.0
to_version: 0.5.0
applies_to:
  - .planning/config.json
  - AGENTS.md
  - skills/agentic-apps-workflow/SKILL.md
  - .codex/workflow-version.txt
requires: []
optional_for: []
---
```
For 0008: `id: 0008`, `slug: plan-review-gate`, `from_version: 0.5.0`, `to_version: 0.6.0` (verify against current `skills/agentic-apps-workflow/SKILL.md` `version:` and bump one minor), `applies_to: [.planning/config.codex.json, AGENTS.md, skills/agentic-apps-workflow/SKILL.md, .codex/workflow-version.txt]`.

**Pre-flight guard pattern** (lines 49-73) — `jq` availability check, version-floor check via grep+sed, template-existence check at the *installed* `$CODEX/skills/...` path (not repo-relative) — copy this shape exactly, substituting `config-hooks.json` for `config-knowledge-capture.json` as the required template and pointing at `${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/check-plan-review.sh` as an additional required artifact (the verifier script itself must ship before the migration that wires it).

**`jq` merge-idempotency pattern for a nested block, preserving existing keys** (lines 77-109) — this is the exact shape D-19 calls for (`jq` merge of `pre_execution`, preserves existing keys, skips if present):
```bash
if [ -f .planning/config.json ]; then
  jq --argjson kc "$KC" '. + {knowledge_capture: $kc}' \
     .planning/config.json > .planning/config.json.tmp \
    && mv .planning/config.json.tmp .planning/config.json
else
  jq -n --argjson kc "$KC" '{knowledge_capture: $kc}' > .planning/config.json
fi
```
For 0008, target `.planning/config.codex.json`'s `.hooks` object (not `.planning/config.json`, since `pre_execution` is host-scoped like the other 15 gates — see D-01/D-19 and ADR-0007 point 5 codex-namespacing precedent), e.g. `jq '.hooks += {pre_execution: $pe}'` with an idempotency guard `jq -e '.hooks.pre_execution' .planning/config.codex.json >/dev/null` gating whether the step is a no-op.

**Template-extraction-not-heredoc pattern for the AGENTS.md insert** (lines 111-151) — this is the exact shape D-19 calls for ("the AGENTS.md section extracted from the template rather than a heredoc"):
```bash
SECFILE="$(mktemp)"
awk '
  /^## Knowledge Capture — Ritual Tail \(spec §15\)/ {f=1}
  /^<!-- END: agentic-apps-workflow sections -->/    {f=0}
  f
' "$TPL" > "$SECFILE"

awk -v secfile="$SECFILE" '
  /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
    while ((getline line < secfile) > 0) print line
    ins=1
  }
  { print }
' AGENTS.md > AGENTS.md.0007.tmp && mv AGENTS.md.0007.tmp AGENTS.md
rm -f "$SECFILE"
```
**Portability note carried forward from this analog:** the comment "getline-from-file is portable (BSD/macOS awk rejects a multi-line -v assignment)" — a multi-line section CANNOT be passed via `awk -v var="$(cat file)"` on macOS/BSD awk; this two-pass extract-to-tempfile-then-getline pattern exists specifically to work around that. Copy this exact mechanism for inserting the new "Pre-execution Gate — Plan Review (spec §02)" (or similarly spec-numbered) ritual section, with the heading regex changed to match the new section's exact heading text.

**Version-bump pattern** (lines 153-171) — copy verbatim, substituting version numbers; `implements_spec` stays untouched (D-17 — do NOT bump it, matching this analog's own explicit note "implements_spec is unchanged — do NOT touch it").

**Post-checks pattern** (lines 173-186) — copy the shape: idempotent jq assertions, `grep -q` for the new section heading, version-bump grep.

**"Skip cases" + "Compatibility" + "Notes" + "References" section shapes** (lines 190-237) — copy the document structure wholesale; particularly the "Testable non-interactively via `test_migration_NNNN`" convention and the "Mirrors claude-workflow's `0025-...`" sibling-precedent note (for 0008, the sibling is `claude-workflow`'s ADR-0025/migration-0016 per CONTEXT.md canonical refs).

---

### `docs/decisions/0009-*.md` (ADR)

**Analog:** `docs/decisions/0008-knowledge-capture.md` (first 60 lines read; structure is clear)

**Header pattern** (lines 1-5):
```markdown
# ADR-0008: Knowledge capture ritual tail — spec §15 on the Codex host

**Status**: Accepted  **Date**: 2026-07-06  **Linear**: —
**Core contract**: `agenticapps-workflow-core/spec/15-knowledge-capture.md` (v0.7.0), core ADR-0017
**Sibling host**: claude-workflow ADR-0038 (reference implementation)
```
For 0009: `# ADR-0009: Bind the plan-review pre-execution gate on the Codex host`, `**Core contract**: agenticapps-workflow-core/spec/02-hook-taxonomy.md §"Pre-execution gate" (lines 81-109)`, `**Sibling host**: claude-workflow ADR-0025 / migration-0016`.

**"Context" section pattern** (lines 7-30) — states the spec obligation, the sibling host's precedent, then numbers the forces that make this host's mirror non-trivial. For 0009, the forces are: (1) codex hooks are declarative-only, no native enforcement runtime bound yet (D-01/D-02); (2) no `gsd-tools.cjs` state lookup exists on Codex (D-07); (3) this repo's own `.planning/phases/` is legacy bare-number layout, making this phase the first real dogfood test (brief §Consequences).

**"Decision" section pattern** (lines 32-60+, numbered sub-decisions each with a one-line rationale) — mirror this numbered-decision-with-rationale shape for: (1) hybrid declarative+verifier mechanism, (2) resolver order + D-06 dead-code fix, (3) REVIEWS.md schema adoption (D-12/D-13), (4) existing-install migration story (0008). Each sub-decision should read like ADR-0008's: state the choice, then the one or two sentences of *why*, referencing spec line numbers.

Also read `docs/decisions/0007-bind-upstream-gsd.md` for the "thin-binding stance" language D-01 explicitly invokes and `docs/decisions/0002-stage2-independent-reviewer-on-codex.md` (read in full above) for the "Options considered" / "Decision" / "Consequences" / "Verification" / "Open follow-ups" ADR skeleton — ADR-0002 is a stronger structural analog than ADR-0008 for a decision with **multiple rejected alternatives** (Option A/B/C), which ADR-0009 will need since D-01 names two rejected alternatives (declarative-only, native PreToolUse hook).

---

### `.planning/config.codex.json` + `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` (config, CRUD)

**Analog:** the two files are already near-identical siblings (config-hooks.json is the template `.planning/config.codex.json` is instantiated from — confirmed by diff: only `implements_spec` differs, `0.4.0` in the template vs `0.1.0` in this repo's own config, a pre-existing drift CONTEXT.md flags as out of scope).

**Existing group shape** (`config-hooks.json` lines 5-107) — four top-level groups under `hooks`: `pre_phase`, `per_task`, `post_phase`, `finishing`, each a flat object keyed by gate-slug, each gate object carrying `skill`, `fires_when`, and gate-specific fields (`min_variants`, `stage`, `blocking_severity`, etc.). The new group must match this exact idiom:
```json
"pre_execution": {
  "plan_review": {
    "skill": "codex-plan-review",
    "verifier": "${CODEX_HOME}/skills/agentic-apps-workflow/scripts/check-plan-review.sh",
    "fires_when": "phase has >=1 *-PLAN.md AND no *-SUMMARY.md exists",
    "evidence_artifact": "<NN>-REVIEWS.md",
    "min_reviewers": 2,
    "escape_hatches": ["GSD_SKIP_REVIEWS=1", "<phase>/multi-ai-review-skipped"]
  }
}
```
(This exact block is already drafted in `docs/briefs/plan-review-gate.md` lines 140-151 — reuse verbatim, it matches the established idiom precisely. `verifier` is a new key not present in any of the other 15 gates — this is intentional per D-01's "hybrid" decision; every other gate is purely declarative (agent-read), this one alone carries a programmatic-verifier pointer.)

**Placement:** insert `"pre_execution": {...}` as a new top-level key of `hooks`, ordered before `pre_phase` (spec §02 lists gates in trigger-order: pre-execution fires before pre-phase's own children in the phase lifecycle — planner should confirm ordering against spec/02's own enumeration, but JSON key order is not semantically significant to any consumer found in this repo, so this is a readability preference, not a functional requirement).

**Update both files identically** — `.planning/config.codex.json` (this repo's own binding) and `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json` (what fresh installs get) must both gain the `pre_execution` block, matching the pattern already established by every prior gate (all 15 present in both files identically apart from the pre-existing `implements_spec` drift).

---

### `AGENTS.md` (doc, bindings table + ritual section)

**Analog 1 (bindings table row + gate-applicability idiom):** `AGENTS.md` itself, lines 122-139 (already read):
```markdown
| Gate | Bound skill | Applies to scaffolder? |
|---|---|---|
| brainstorm-ui | `superpowers:brainstorming` | No (no UI) |
...
| spec-review | `codex-spec-review` | Yes (always) |
| code-review | `superpowers:requesting-code-review` | Yes (always) |
```
Add a new row `| plan-review | \`codex-plan-review\` | Yes (always — dogfoods starting this phase) |` positioned per spec/02's gate ordering (pre-execution, i.e. before the `pre_phase` gates in trigger-time order, though the existing table's row order tracks `config-hooks.json`'s group order — `pre_phase` rows first, then `per_task`, then `post_phase`, then `finishing`; a `pre_execution` row logically precedes all of them). **D-20: collapse the duplicate `tdd` row** — the table currently lists `tdd` (line 128) and `tdd (new TS module)` (line 129) as two separate rows for what CONTEXT.md says should read as one gate's two-tier binding; verify against `config-hooks.json`'s own `per_task.tdd` shape (lines 29-38 of `templates/config-hooks.json`), which already nests `strengthened_by` as a sub-key of one `tdd` gate object rather than a sibling gate — the table should mirror that nesting, not duplicate the row.

**Analog 2 (ritual-section insertion mechanics):** `migrations/0007-knowledge-capture.md` Step 2 (excerpted above) — the same awk-based template-extraction-and-insert mechanism applies when the AGENTS.md ritual section is authored by hand for *this* repo's own `AGENTS.md` (not just the migration's automated path) — author the section text once in `agents-md-additions.md`, then either hand-copy it into this repo's `AGENTS.md` or run the migration script against this repo, per D-19's single-source-of-truth requirement.

---

### `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md` (template, ritual source of truth)

**Analog:** itself, the existing `## Knowledge Capture — Ritual Tail (spec §15)` section (lines 96-157, read in full above) — the single closest structural precedent in the whole repo for "a spec-numbered ritual section inserted into this template, later mirrored into `AGENTS.md` and the trigger `SKILL.md`."

**Section heading + spec-citation pattern** (line 96): `## Knowledge Capture — Ritual Tail (spec §15)`. For the new section: `## Pre-execution Gate — Plan Review (spec §02)` (exact wording is planner's call, but the `(spec §NN)` suffix convention should be preserved).

**"Mechanical — follow exactly" procedural framing** (line 113): `Procedure (mechanical — follow exactly):` followed by a numbered list with skip conditions called out explicitly as their own numbered/bulleted sub-items (lines 117-125 show the skip-condition enumeration pattern: `**Skip** — print at most one line ... and continue ... — when any holds:` followed by a bulleted list of conditions). Mirror this exactly for the plan-review ritual's own skip/escape-hatch enumeration (`GSD_SKIP_REVIEWS=1`, the marker file, and the grandfather conditions from D-08).

**Placement relative to the marker** (line 157, `<!-- END: agentic-apps-workflow sections -->`): the new section must land, like the Knowledge Capture section did, *before* this closing marker and *after* the existing ritual sections — append pattern, not prepend.

---

### `migrations/run-tests.sh` (test harness, batch/test)

**Analog:** `test_migration_0007()`, lines 573-732 (both reads combined — full function read)

**Function-skeleton pattern:**
```bash
test_migration_0007() {
  echo ""
  echo "${YELLOW}=== Migration 0007 — Knowledge capture (spec §15) ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-merge test not run"
    SKIP=$((SKIP+1)); return
  fi
  ...
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/.planning"
  ...
}
```
`test_migration_0008()` should follow this exact skeleton: `jq` availability guard with `SKIP`, an isolated `mktemp -d` sandbox with `trap ... RETURN` cleanup, `mkdir -p "$tmp/.planning"`.

**`assert_check` helper usage pattern** (lines 620-622, 628-630, 676-678, 695-697, 731-732) — the repo's existing idempotency-check idiom:
```bash
assert_check "idempotency: config.json has no knowledge_capture → needs seed" \
  "test -f .planning/config.json && jq -e '.knowledge_capture' .planning/config.json >/dev/null" \
  "$tmp" "not-applied"
```
Two calls per step: one asserting the pre-condition is "not-applied" before running the step's shell logic, one asserting "applied" afterward. Copy this pattern for each of 0008's steps (config merge, AGENTS.md insert, version bump) — this is the repo's TDD-for-migrations convention (brief's "TDD — failing test first" testing section maps directly onto this harness idiom).

**Inline fixture-via-heredoc pattern** (lines 615-617, 663-673) — synthetic `.planning/config.json` / `AGENTS.md` fixtures built with `cat > "$tmp/..." <<'JSON' / <<'MD'` heredocs, deliberately containing a pre-existing foreign-host key (`"host": "claude"`) to prove the merge preserves unrelated keys. Mirror this for 0008: build a synthetic `.planning/config.codex.json` fixture with a pre-existing gate under `hooks` (e.g. `spec_review`) to prove the `pre_execution` merge doesn't clobber it.

**Direct-assertion pattern for merge-preserving-keys** (lines 642-649) — for content assertions that aren't simple idempotency checks:
```bash
if ( cd "$tmp" && jq -e '.hooks.post_phase.code_review.stage == 2 and .host == "claude"' .planning/config.json >/dev/null ); then
  echo "  ${GREEN}PASS${RESET} pre-existing (claude) config keys preserved by merge"
  PASS=$((PASS+1))
else
  echo "  ${RED}FAIL${RESET} merge clobbered pre-existing config keys"
  FAIL=$((FAIL+1))
fi
```

**Verifier fixtures (new territory for 0008 — no direct precedent in `run-tests.sh` since no prior migration shipped a companion shell verifier):** structure these as a sibling `test_check_plan_review_*()` function (or a suite of small `assert_check` calls) exercising: each resolver step wins in its documented order; fail-open when nothing resolves; legacy layout allowed; `*-SUMMARY.md` allowed; plans without REVIEWS → exit 2; REVIEWS present with `reviewers:` frontmatter `>= 2` → exit 0; REVIEWS present with `< 2` reviewers → exit 2; REVIEWS present, no frontmatter, `>= 5` lines → exit 0; REVIEWS present, no frontmatter, `< 5` lines → exit 2; both escape hatches → exit 0. Build these as `mktemp -d` sandboxes with synthetic `.planning/phases/<NN>-x/` trees and synthetic `*-REVIEWS.md` fixtures, invoking `check-plan-review.sh` via `( cd "$tmp" && bash "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" ); echo "exit=$?"` and asserting on the captured exit code — this pattern has no existing precedent to copy verbatim in this repo (all existing migration tests assert on `jq`/`grep` file-content checks, not subprocess exit codes), so flag this to the planner as new test-harness surface, structurally consistent with but not copy-pasteable from `test_migration_0007`.

---

### `skills/agentic-apps-workflow/SKILL.md` (trigger skill, mirrors AGENTS.md)

**Analog:** its own existing "Workflow Enforcement Hooks" table mirror and its own "Knowledge Capture — Ritual Tail" section (confirmed present via the `applies_to:` entry in migration 0007's frontmatter: `skills/agentic-apps-workflow/SKILL.md`, bumped 0.4.0 -> 0.5.0 in that migration). This file mirrors `agents-md-additions.md`'s content 1:1 (same headings, same procedure text) — apply the identical `plan-review` bindings-table row and the identical `## Pre-execution Gate — Plan Review (spec §02)` section here, keeping both surfaces byte-identical to `agents-md-additions.md` per the single-source-of-truth discipline D-19 states explicitly ("the 0007 lesson").

---

### `CHANGELOG.md` (doc)

**Analog:** the two Unreleased "Fixed" entries (migration-discovery symlink fixes), lines 10-33 (already read in full above).

**Entry-shape pattern:**
```markdown
- **Wire update-path migration discovery.** `$update-codex-agenticapps-workflow`
  reads migrations from `${CODEX_HOME}/skills/.../migrations/`, but that path
  was empty — ... Added a committed symlink `skills/.../migrations -> ../../migrations`;
  since the whole skill dir is symlinked into `~/.codex`, migrations now resolve
  at the expected installed path (verified: ...). Canonical location and the
  drift/version coupling are unchanged (no version bump — ...). `run-tests.sh`
  gains a regression guard asserting the symlink resolves.
```
Bold one-line summary, then: what was broken, why it went unnoticed, the fix, what was verified, whether a version bump applied and why (or why not), what test coverage was added. Since 0008 IS a version-bumping migration (unlike the two Unreleased entries, which explicitly note "no version bump"), place the new entry under a new `## [Unreleased]` → `### Added` (or a fresh dated release section if this phase closes a release) rather than `### Fixed`, and explicitly state the `implements_spec` non-bump rationale inline, mirroring the existing CHANGELOG:88-91 language CONTEXT.md cites (`implements_spec` tracks a full conformance audit, not one gate).

## Shared Patterns

### `${CODEX_HOME:-$HOME/.codex}` path-resolution idiom
**Source:** used pervasively — `skills/agentic-apps-workflow/SKILL.md:377,439`, `skills/setup-codex-agenticapps-workflow/SKILL.md:44,80,165-173`, `migrations/0007-knowledge-capture.md:68,89,125`, `skills/update-codex-agenticapps-workflow/SKILL.md:12,43,46`
**Apply to:** `check-plan-review.sh`, migration 0008's pre-flight/apply steps, and the `verifier` path value in both `config-hooks.json` files.
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
```
Every reference to an installed-skill path in this repo uses this exact form, never a hardcoded `~/.codex`.

### Committed symlink for cross-directory skill assets
**Source:** `skills/setup-codex-agenticapps-workflow/migrations -> ../../migrations` and `skills/update-codex-agenticapps-workflow/migrations -> ../../migrations` (both verified present, `lrwxr-xr-x`), documented at `skills/setup-codex-agenticapps-workflow/SKILL.md:170-181`, and the CHANGELOG Unreleased entries.
**Apply to:** N/A for `check-plan-review.sh` itself — it lives *inside* `skills/agentic-apps-workflow/scripts/`, which travels automatically with the whole-directory symlink `install.sh` already creates for `skills/agentic-apps-workflow/` → no new symlink is needed, unlike the `migrations/` case (which needed one because migrations live in a sibling top-level directory, not inside the skill directory itself). Flag this distinction explicitly to the planner: **do not port a symlink step that isn't needed.**

### `jq` merge-preserving-existing-keys, config idempotency
**Source:** `migrations/0007-knowledge-capture.md` Step 1 (lines 77-109), tested by `test_migration_0007` lines 610-660.
**Apply to:** migration 0008's `.planning/config.codex.json` `pre_execution` merge.

### Template-extraction-not-heredoc for prose that also ships in a template
**Source:** `migrations/0007-knowledge-capture.md` Step 2 (lines 111-151); the macOS/BSD awk multi-line `-v` limitation this pattern works around is a load-bearing portability constraint, not a style choice.
**Apply to:** migration 0008's AGENTS.md ritual-section insert.

### REVIEWS.md schema (D-12)
**Source:** `../agenticapps-dashboard/.planning/phases/DASH-11-coverage-trends-skill-drift/11-REVIEWS.md` lines 1-27 (real, in-production example).
```yaml
---
phase: 11
reviewers: [gemini, codex]
reviewed_at: 2026-05-16T12:53:27Z
plans_reviewed:
  - 11-01-PLAN.md
  ...
overall_verdict:
  gemini: LOW
  codex: MEDIUM
recommendation: rework
---

# Cross-AI Plan Review — Phase 11 (Coverage trends + Skill drift + 10.6 polish)

Two independent AI reviewers (gemini, codex) read the full Phase 11 plan
bundle...

## Gemini Review
### 1. Summary
...
```
**Apply to:** both `codex-plan-review`'s output (the producer must write exactly this shape) and `check-plan-review.sh`'s frontmatter parse (the verifier must read exactly this shape, specifically the `reviewers:` array). Note the prose provenance pattern in the body's intro paragraph ("CodeRabbit and OpenCode are not installed on this host") — D-"specifics" in CONTEXT.md explicitly calls this out as useful and worth reproducing.

### Bash script header/safety conventions
**Source:** `./install.sh` lines 1-20 (`#!/usr/bin/env bash`, `set -uo pipefail`, tty-conditional color vars) and the reference `multi-ai-review-gate.sh` line 25 (`set -e`).
**Apply to:** `check-plan-review.sh` — this repo's one existing top-level shell script uses `set -uo pipefail` (not `set -e`) with tty-conditional `RED/GREEN/YELLOW/RESET` color vars; the reference hook uses plain `set -e`. Since `check-plan-review.sh` is a gate verifier (exit-code-driven, not colorized interactive output), `set -e` alone (matching the reference, since the whole file is 174 lines of guard clauses relying on early-return control flow rather than colored terminal output) is the closer fit — but confirm this doesn't fight the resolver's `|| true` idioms already present in the reference (lines 88, 100, 107, 115), which exist specifically to survive under `set -e`.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `skills/agentic-apps-workflow/scripts/check-plan-review.sh` | verifier script | request-response | Zero shell scripts exist anywhere under `skills/` in this repo today (`find skills -iname '*.sh'` returns nothing). The only in-repo bash-script precedent is repo-root `install.sh` (different role: installer, not gate verifier) and `migrations/run-tests.sh` (different role: test harness). The true role-and-data-flow analog is `../claude-workflow/templates/.claude/hooks/multi-ai-review-gate.sh`, which is OUTSIDE this repo and — per D-06/D-07 — must not be ported verbatim (dead-code resolver step 2, no-analogue resolver step 3). Treat it as a reference to port *with the two named corrections*, not as a drop-in analog. |

## Metadata

**Analog search scope:** `skills/`, `migrations/`, `docs/decisions/`, `AGENTS.md`, `CHANGELOG.md`, `.planning/config.codex.json` (this repo); `../claude-workflow/templates/.claude/hooks/`, `../claude-workflow/docs/decisions/`, `../agenticapps-workflow-core/spec/`, `../agenticapps-dashboard/.planning/phases/DASH-11-.../` (sibling repos, read-only reference per CONTEXT.md canonical_refs)
**Files scanned:** ~20 read/grepped directly; directory listings across `skills/`, `migrations/`, `docs/decisions/`
**Pattern extraction date:** 2026-07-14
**Verified non-existent (do not cite):** `skills/codex-code-review/SKILL.md` (a GitNexus index hit surfaced this path; confirmed absent via `find` — the index appears stale or references a deleted/renamed file. Only `skills/codex-spec-review/` exists.)
