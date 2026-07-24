---
id: 0013
slug: bind-openspec-v1
title: Bind the OpenSpec + Superpowers front end, retire the GSD planning engine (v0.9.0 -> 1.0.0)
from_version: 0.9.0
to_version: 1.0.0
applies_to:
  - .planning/config.codex.json                             # 0.x `hooks` tree -> 1.0.0 `lifecycle` tree
  - .codex/hooks.json                                       # PreToolUse retargeted to the §18 change-gate
  - AGENTS.md                                               # Development Workflow -> the OpenSpec loop
  - openspec/                                               # NEW — the three-slot spec slot (§16)
  - ~/.agenticapps/bin/                                     # NEW — the host-agnostic gate + reviewer wrapper
  - .git/hooks/pre-commit                                   # NEW — the agent-agnostic enforcement floor
  - .codex/workflow-version.txt                             # record new project version
  # Scaffolder-side (shipped by the release, not written into a target project):
  - skills/agentic-apps-workflow/SKILL.md                   # lifecycle + §17 gate mapping; version + claim 1.0.0
  - skills/codex-spec-review/                               # DELETED — structural role collapses into `openspec validate`
  - skills/codex-plan-review/                               # RENAMED -> skills/codex-openspec-change-review/
  - bin/openspec-change-gate.sh                             # NEW — the §18 enforcement surface
  - bin/reviewer-cli.sh                                     # NEW — </dev/null + timeout reviewer wrapper
  - bin/git-hooks/pre-commit, bin/openspec-gate-ci.sh       # NEW — the floor
  - docs/WORKFLOW.md, docs/recipes/0001-planning-to-openspec.md
  - docs/decisions/0011-openspec-superpowers-adoption.md    # the adoption ADR
requires:
  - tool: openspec
    verify: "openspec --version"
    install: "npm i -g @fission-ai/openspec"
  - tool: reviewer-clis
    verify: "claude --version && gemini --version"
    install: "install >=2 external-vendor reviewer CLIs the §18 gate's producer calls (claude / gemini / opencode — never codex, the implementing host)"
optional_for:
  - tag: db
    detect: "test -d supabase || test -d migrations/sql || grep -rqi 'rls' ."
    note: "no DB surface -> database-security stays unbound (§17 conditional)"
  - tag: ui
    detect: "test -d frontend || test -d src/components"
    note: "no UI surface -> the design gates stay unbound (§17 conditional)"
---

# Migration 0013 — Bind OpenSpec + Superpowers (v0.9.0 → 1.0.0)

This migration adopts `agenticapps-workflow-core` **spec v1.0.0**: the
OpenSpec + Superpowers front end (§16–§19, core ADR-0021). It replaces the 0.x
GSD phase engine as the **planning** discipline and leaves the **execution**
discipline untouched. See
[ADR-0011](../docs/decisions/0011-openspec-superpowers-adoption.md).

It is the largest migration in the chain. Three properties are worth stating
before the steps, because each is a place a careless replay goes wrong.

## What does NOT change

§01 (commitment ritual), §03 (rationalization), §04 (red flags), §05
(pressure-test), §06 (evidence rules) and §11 (Coding Discipline) carry forward
**verbatim**. TDD, the independent Stage-2 code review, the evidence rules, and
the §11 block behind its provenance anchor are all untouched. This migration
changes what you plan *with*, not how you build.

## The multi-AI review is kept — and is no longer a named gate

Spec §17 **forbids a standalone `plan-review` or `spec-review` gate** under
1.0.0. The port brief said "keep the plan-review gate." Both are satisfied:

- The **adversarial multi-AI review is KEPT**, re-expressed as the §18
  change-gate **predicate** — the gate allows a code edit only when
  `openspec validate --all` is green **AND**
  `openspec/changes/<slug>/REVIEWS.md` carries **≥2 `## Reviewer:` headings**.
- The **producer** is `codex-openspec-change-review` (the retargeted
  `codex-plan-review`), which critiques the change rather than a `*-PLAN.md`.
- It is **NOT a separately-named gate**. Same adversarial mechanism, one fewer
  moving part. ADR-0018's failure mode — a review silently skipped for eight
  consecutive units of work — stays closed.

## An installed hook is not an enforcing hook

Migration `0011`'s correction is the load-bearing precedent here, and this
migration inherits both halves of it:

1. **Schema.** codex-cli requires the matcher group to carry a **nested**
   `hooks` array — `{"matcher", "hooks":[{"type","command"}]}`. The flat form
   `{"matcher","type","command"}` is dropped **with no error and no warning**.
   Every selector below reads the command through the nested `(.hooks // [])[]`
   hop; a group-level read can never match its own output and would append a
   duplicate on every re-run.
2. **Trust.** codex-cli also requires the operator to *trust* a project hook.
   An untrusted entry sits at `Installed N / Active N-1 / Review 1` and
   enforces nothing while looking installed. **Post-check 6 is not optional.**

**Supported upgrade floor:** `0.9.0 → 1.0.0`. Projects below 0.9.0 replay the
chain through `0012` first.

## Pre-flight

```bash
command -v jq >/dev/null 2>&1 || { echo "ABORT: jq required for the hooks.json + config merges"; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ABORT: run inside a git repo"; exit 2; }
test -f .codex/workflow-version.txt || { echo "ABORT: not an installed project — run \$setup-codex-agenticapps-workflow"; exit 3; }
test -x "$HOME/.agenticapps/bin/openspec-change-gate.sh" \
  || test -f "${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/openspec-change-gate.sh" \
  || { echo "ABORT: gate artifacts missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
openspec --version >/dev/null 2>&1 \
  || echo "note: install openspec (npm i -g @fission-ai/openspec) — until then the gate BLOCKS under an active change, deliberately (§18)"
```

## Steps

### Step 1: Restructure `.planning/config.codex.json` to the OpenSpec lifecycle

**Idempotency check:** `jq -e '.lifecycle.validate.change_gate' .planning/config.codex.json >/dev/null`
**Pre-condition:** `jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null` (a 0.x GSD-shaped config)
**Apply:**

```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
TPL="$CODEX/skills/setup-codex-agenticapps-workflow/templates/config-lifecycle.json"
test -f "$TPL" || { echo "ABORT: config-lifecycle.json template missing — reinstall the scaffolder"; exit 4; }
cp "$TPL" .planning/config.codex.json
```

This is a wholesale restructure, not a field edit: the 0.x `hooks` tree
(pre_execution / pre_phase / per_task / post_phase / finishing) has no
field-level correspondence to the 1.0.0 `lifecycle` tree (propose / validate /
execute / archive / ship). Nothing repo-specific lives in this file — the
host-neutral `knowledge_capture` block lives in `.planning/config.json`, which
this migration never touches.

**Rollback:** `git checkout -- .planning/config.codex.json`

### Step 2: Remove gitnexus from every live surface

**Idempotency check:** `! test -d .claude/skills/gitnexus && ! test -d .gitnexus`
**Pre-condition:** none (fixes forward; a project with no gitnexus no-ops)
**Apply:**

```bash
git rm -r -q --ignore-unmatch .claude/skills/gitnexus 2>/dev/null || true
rm -rf .gitnexus
```

Historical records are **retained** per §08 supersede-don't-delete: migration
`0009` and `validate-0009-anchor.sh` (their gitnexus-led `AGENTS.md` fixtures
test the §11 anchor rule and must keep running), ADR-0010, the CHANGELOG
entries, and `docs/briefs/`.

**Rollback:** `git checkout -- .claude/skills/gitnexus 2>/dev/null; true` (the untracked `.gitnexus/` data dir is not restorable and is regenerable by its own tool)

### Step 3: Install the §18 change-gate and initialize the spec slot

**Idempotency check:** `test -x "$HOME/.agenticapps/bin/openspec-change-gate.sh" && test -d openspec/changes`
**Pre-condition:** none — the gate installs regardless; the `openspec init` half is skipped with a note when the CLI is absent
**Apply:**

```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
TPL="$CODEX/skills/setup-codex-agenticapps-workflow/templates"
mkdir -p "$HOME/.agenticapps/bin" "$HOME/.agenticapps/git-hooks"
install -m 0755 "$TPL/openspec-change-gate.sh" "$HOME/.agenticapps/bin/openspec-change-gate.sh"
install -m 0755 "$TPL/reviewer-cli.sh"         "$HOME/.agenticapps/bin/reviewer-cli.sh"
install -m 0755 "$TPL/git-hooks-pre-commit"    "$HOME/.agenticapps/git-hooks/pre-commit"
install -m 0755 "$TPL/git-hooks-pre-commit"    "$(git rev-parse --git-path hooks)/pre-commit"
if command -v openspec >/dev/null 2>&1; then
  test -d openspec || openspec init --tools codex --profile core --force
fi
```

The gate is ONE host-agnostic script installed at a single global path and
shared by every AgenticApps host; the per-host hook is thin wiring on top. The
`pre-commit` half is the **floor**: a PreToolUse hook is loaded at session start
and cannot gate the session that installed it.

**Rollback:** `rm -f "$HOME/.agenticapps/bin/openspec-change-gate.sh" "$HOME/.agenticapps/bin/reviewer-cli.sh" "$(git rev-parse --git-path hooks)/pre-commit"` and remove the generated `openspec/` slot + `.codex/skills/openspec-*`

### Step 4: Retarget the `PreToolUse` hook to the change-gate

**Idempotency check:** `jq -e --arg cmd "${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh" '(.hooks.PreToolUse // [])[] | (.hooks // [])[] | select(.command == $cmd)' .codex/hooks.json >/dev/null 2>&1`
**Pre-condition:** `test -f .codex/hooks.json` (0011 created it)
**Apply:**

```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
OLD="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
NEW="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh"
test -x "$NEW" || { echo "ABORT: wrapper missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
tmp="$(mktemp)"
# Drop only OUR 0.x entry (selected on its nested command, so a sibling
# vendor's group survives even if it shares the matcher), then append the
# retargeted one in the NESTED shape codex-cli actually loads.
jq --arg old "$OLD" --arg new "$NEW" '
  .hooks.PreToolUse = (
    [ (.hooks.PreToolUse // [])[]
      | select(([(.hooks // [])[] | .command] | index($old)) == null)
      | select(([(.hooks // [])[] | .command] | index($new)) == null) ]
    + [{"matcher":"apply_patch","hooks":[{"type":"command","command":$new}]}]
  )' .codex/hooks.json > "$tmp" && mv "$tmp" .codex/hooks.json
```

Both `$old` **and** `$new` are filtered out before the append, so the block is
self-idempotent: a re-run replaces its own entry rather than stacking a second
one. (`0011` shipped a selector that could not see its own output and would
have appended a duplicate on every re-run — the same defect, one line earlier.)

The wrapper is not sugar. Wire `hooks.json` straight at the gate and codex's
`apply_patch` payload — which carries the edited path *inside the patch blob*
at `tool_input.command`, not in a `file_path` field — parses to no path, so the
gate fails open by design (§18 fail-open-on-parse-error) and allows **every**
edit. The wrapper also converts a block into strictly valid
`permissionDecision: deny` JSON, because a codex hook that emits invalid stdout
fails open and runs the tool anyway.

**Rollback:** re-run the same jq with `$old` and `$new` swapped.

### Step 5: Retarget `AGENTS.md`'s Development Workflow section

**Idempotency check:** `grep -q 'docs/WORKFLOW.md' AGENTS.md`
**Pre-condition:** `grep -q '^## Development Workflow$' AGENTS.md`
**Apply:**

```bash
tmp="$(mktemp)"; body="$(mktemp)"
cat > "$body" <<'BODY'
This repo uses the AgenticApps spec-first workflow on the OpenAI Codex
CLI host. Product work moves through the **OpenSpec change lifecycle** —
propose → validate → Superpowers-execute → archive — and shipping (the
git commit / PR) is a separate act from archiving. `openspec/specs/` is
the durable statement of what the product guarantees; `openspec/changes/`
holds in-flight deltas; `changes/archive/` is history. Full explainer:
[`docs/WORKFLOW.md`](docs/WORKFLOW.md).

On any code-touching task the `agentic-apps-workflow` trigger skill
activates, emits the canonical commitment ritual before any tool call,
and carries the gate bindings, task-size routing, the stage-2
change-review procedure, and the knowledge-capture ritual — read them
there, not here. Project-specific bindings live in
`.planning/config.codex.json`. Do not bypass a gate — accept-via-ADR is
the override path.

No code is edited under an open change until `openspec validate --all` is
green **and** the change carries `REVIEWS.md` with >=2 independent
reviewers. That is enforced programmatically three ways: a `PreToolUse`
hook (`.codex/hooks.json`), a git `pre-commit` hook, and CI — all calling
the same `openspec-change-gate.sh`. The hook is faster feedback; the
pre-commit and CI checks are the guarantee, because a hook cannot gate the
session that installed it. Spec:
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
v1.0.0 §16-§19. Version stamp: `.codex/workflow-version.txt`.
BODY
awk -v bodyfile="$body" '
  # Fence-aware: a "## " line inside a code fence is content, not a heading.
  /^```/ { fence = !fence }
  !fence && /^## Development Workflow$/ {
    print; print ""
    while ((getline line < bodyfile) > 0) print line
    close(bodyfile)
    drop=1; next
  }
  drop && !fence && /^## / { drop=0 }
  drop && /^<!-- END: agentic-apps-workflow sections/ { drop=0 }
  !drop { print }
' AGENTS.md > "$tmp" && mv "$tmp" AGENTS.md
rm -f "$body"
```

The replacement body is passed through a **file**, never `awk -v`: BSD awk
rejects a multi-line `-v` value with `newline in string`, and the earlier
two-pass form of this step then wrote its second awk's output straight over
`AGENTS.md`, truncating it to zero bytes on the machine where it failed. One
pass, `getline` from a temp file, and `> "$tmp" && mv` — so a failure leaves
the original file intact.

The `## ` drop bound is fence-aware for the same reason migration `0012`'s
was: this host's installer template carries a fenced session-handoff example
whose lines start with `## `, and a transform that reads those as headings
ends the drop early and leaks the fence body into the file.

**Rollback:** `git checkout -- AGENTS.md`

### Step 6: Bump versions (0.9.0 → 1.0.0)

**Idempotency check:** `grep -q '^1.0.0$' .codex/workflow-version.txt`
**Pre-condition:** `grep -q '^0.9.0$' .codex/workflow-version.txt`
**Apply:**

```bash
printf '1.0.0\n' > .codex/workflow-version.txt
```

**Rollback:** `printf '0.9.0\n' > .codex/workflow-version.txt`

## Post-checks

```bash
# 1. Config is on the OpenSpec lifecycle; the 0.x standalone gates are gone.
jq -e '.lifecycle.validate.change_gate and .lifecycle.validate.multi_ai_review' .planning/config.codex.json >/dev/null
jq -e '.implements_spec == "1.0.0" and .front_end == "openspec"' .planning/config.codex.json >/dev/null
jq -e '(.hooks.pre_execution.plan_review // null) == null' .planning/config.codex.json >/dev/null

# 2. The gate is installed and the floor is wired.
test -x "$HOME/.agenticapps/bin/openspec-change-gate.sh"
test -x "$HOME/.agenticapps/bin/reviewer-cli.sh"
test -x "$(git rev-parse --git-path hooks)/pre-commit"

# 3. The hook entry exists, in the NESTED shape, pointing at the new wrapper.
#    Reading `.command` at GROUP level would never match — that is exactly the
#    defect 0011's correction fixed, and it is silent.
jq -e --arg cmd "${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh" \
   '(.hooks.PreToolUse // [])[] | (.hooks // [])[] | select(.command == $cmd)' .codex/hooks.json >/dev/null

# 4. The §18 truth table, by DIRECT invocation (a hook cannot gate its own session).
GATE="$HOME/.agenticapps/bin/openspec-change-gate.sh"
printf '{"tool":"edit","tool_input":{"file_path":"x.go"}}' | "$GATE"; test $? -eq 0   # no active change -> allow
printf '{"tool":"edit","tool_input":{"file_path":"openspec/changes/x/proposal.md"}}' | "$GATE"; test $? -eq 0   # exempt
printf '' | "$GATE"; test $? -eq 0                                                    # fail-open on parse error

# 5. Version stamp.
grep -q '^1.0.0$' .codex/workflow-version.txt
```

**Post-check 6 — OPERATOR VERIFICATION, REQUIRED. Not automatable.**

Steps 1–5 prove the hook is *installed*. They cannot prove it is *permitted to
run*. codex-cli gates project hooks behind operator trust, and an untrusted
entry looks identical to a working one everywhere except here:

1. Start a **fresh** Codex session in the project (hooks load at session start).
2. Run `/hooks`.
3. Confirm the `openspec-gate` entry reads **Active**. If the summary shows
   `Installed N / Active N-1 / Review 1`, it is installed and **enforcing
   nothing** — approve it before treating this migration as complete.

Until it is Active, the git `pre-commit` hook and the CI check are the only
enforcement. That is not a reason to skip this check; it is the reason the
floor exists.

- Drift test green: SKILL.md `version` (1.0.0) == latest migration `to_version` (1.0.0)
- `.codex/workflow-version.txt` == SKILL.md `version` (V-03)

## Skip cases

- **`from_version` mismatch** (project not at 0.9.0) → the framework skips
  silently; projects below 0.9.0 replay the chain through `0012` first.
- **Already at 1.0.0** (config has `.lifecycle.validate.change_gate`) → every
  step's idempotency check is positive; the migration no-ops.
- **openspec CLI absent** → Step 3's `openspec init` half is skipped with a
  note. The gate still installs, and its `validate` branch **blocks** under an
  active change until the CLI is present: an unvalidatable change must not pass
  the gate (§18). This is a deliberate block, not a bug.
- **No gitnexus present** → Step 2 no-ops.
- **No DB / UI surface** → the conditional gates stay unbound (§17).
- **Project has `.planning/` history to migrate** → this migration does NOT
  seed `openspec/specs/` from it. That is
  `recipes/0001-planning-to-openspec.md`, whose Tier 2 is human-supervised by
  design. Offer it after this migration completes; never run it unattended.

## Compatibility

- **Minor→major:** `implements_spec` 0.10.0 → **1.0.0** on the trigger skill;
  workflow `version` 0.9.0 → **1.0.0**. This is a front-end replacement, the
  largest change since baseline.
- **Gate skills keep citing `0.4.0`.** The §02 gate contracts they fulfil did
  not change under §17 — only their *fate* in the lifecycle did. Blanket-bumping
  them would assert a contract advance that never happened; §09 puts the host's
  conformance citation on the trigger skill alone.
- **`check-plan-review.sh` is retained, not retired.** One global skills dir
  serves every project on the machine, including projects that have not yet
  replayed this migration. Their gate is still the 0.x verifier and their
  evidence artifact is still `<NN>-REVIEWS.md`; the renamed producer skill
  keeps a 0.x fallback path for exactly that window.
- **Superpowers execution discipline unchanged** (§01/§03/§04/§05/§06/§11).
- **ADR-0009** (the 0.x plan-review gate) and **ADR-0010** (region-aware §11
  placement) are superseded by ADR-0011, not deleted.
- **Drift coupling:** as the highest-numbered migration, `0013`'s `to_version`
  (1.0.0) is the drift target; the trigger SKILL.md moves in lockstep.
