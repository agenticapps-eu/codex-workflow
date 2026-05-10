---
id: 0000
slug: baseline
title: codex-workflow baseline (v0.1.0 starting state)
from_version: unknown
to_version: 0.1.0
applies_to:
  - .codex/workflow-config.md
  - .codex/workflow-version.txt
  - .planning/config.json
  - AGENTS.md
  - docs/decisions/
requires: []
optional_for:
  - tag: option-a
    detect: "test -w \"${CODEX_HOME:-$HOME/.codex}/AGENTS.md\""
    note: "Step 6 appends a global AgenticApps section to ~/.codex/AGENTS.md. Skip if the user wants a per-project install only (Option B)."
---

# Migration 0000 — Baseline (v0.1.0)

This is the **baseline migration** for `codex-workflow`. Applied to a
fresh project, it brings the project to v0.1.0 — the state the
scaffolder ships before any incremental migrations run.

`setup-codex-agenticapps-workflow/SKILL.md` invokes this migration first
when bootstrapping a new project. Existing projects that already have
`.codex/workflow-version.txt` should NOT run 0000 — they are already
past the baseline; they need incremental migrations starting from
their installed version.

## Pre-flight

```bash
# Project root must be a git repo (atomic commit per migration assumes git)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# Refuse if already installed (use $update-codex-agenticapps-workflow instead)
test -f .codex/workflow-version.txt && \
  { echo "codex-workflow already installed; version: $(cat .codex/workflow-version.txt). Use \$update-codex-agenticapps-workflow."; exit 1; }

# Verify scaffolder skills are installed
test -f "${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/SKILL.md" || \
  { echo "scaffolder not installed — clone codex-workflow and run install.sh first"; exit 1; }
```

## Steps

### Step 1: Create `.codex/workflow-config.md` from template

**Idempotency check:** `test -f .codex/workflow-config.md`
**Pre-condition:** template exists at `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/workflow-config.md`
**Apply:** Copy the template and replace `{{PLACEHOLDERS}}` with project-specific
values gathered via interactive prompts. The setup skill is responsible for
gathering and substituting:

| Placeholder | Source |
|---|---|
| `{{PROJECT_NAME}}` | ask user: "Project name?" |
| `{{REPO}}` | `git remote get-url origin` (with fallback prompt) |
| `{{CLIENT}}` | ask user: "Internal or which client?" |
| `{{BUDGET}}` | ask user: "Budget tier (free / paid / enterprise)?" |
| `{{BACKEND}}` | ask user: "Primary backend language?" |
| `{{FRONTEND}}` | ask user: "Primary frontend stack?" |
| `{{DATABASE}}` | ask user: "Primary database?" |
| `{{LLM}}` | ask user: "Primary LLM provider?" |
| `{{DESIGN_CRITIQUE_BAR}}` | default `90` (project may override later) |
| `{{IMPECCABLE_BAR}}` | default `90` |
| `{{QA_VIEWPORTS}}` | default `1280, 390` |
| `{{DB_BLOCKING}}` | default `Critical, High` |
| `{{BACKEND_OVERRIDE}}` | only if BACKEND = Other |

```bash
mkdir -p .codex
cp "${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/workflow-config.md" .codex/workflow-config.md
# Then run interactive substitution per the table above
```
**Rollback:** `rm -f .codex/workflow-config.md && rmdir .codex 2>/dev/null || true`

### Step 2: Create `.planning/config.json` from template

**Idempotency check:** `test -f .planning/config.json && jq -e '.hooks' .planning/config.json >/dev/null`
**Pre-condition:** template exists at `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/config-hooks.json`
**Apply:**
```bash
mkdir -p .planning
cp "${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/config-hooks.json" .planning/config.json
```
**Rollback:** `rm -f .planning/config.json && rmdir .planning 2>/dev/null || true`

### Step 3: Append AGENTS.md sections from template

**Idempotency check:** `grep -q "BEGIN: agentic-apps-workflow sections" AGENTS.md`
**Pre-condition:** template exists at `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md`
**Apply:**
```bash
# Create AGENTS.md if missing
touch AGENTS.md

# Append sections (idempotency check above prevents double-append via the BEGIN marker)
echo "" >> AGENTS.md
cat "${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md" >> AGENTS.md
```
**Rollback:** `git checkout AGENTS.md` if it existed pre-step, else `rm -f AGENTS.md`. Manual removal anchor: delete from the line `<!-- BEGIN: agentic-apps-workflow sections` to `<!-- END: agentic-apps-workflow sections -->` inclusive.

### Step 4: Seed `docs/decisions/README.md`

**Idempotency check:** `test -f docs/decisions/README.md`
**Pre-condition:** project root is writable
**Apply:**
```bash
mkdir -p docs/decisions
cat > docs/decisions/README.md <<'EOF'
# Architecture decision records

ADRs for this project. Numbered sequentially: `NNNN-slug.md`.

The shape follows the AgenticApps workflow's ADR convention —
status, date, context, decision, consequences, references.

When a `codex-database-sentinel-audit` finding is accepted rather
than fixed, the ADR uses the
`adr-db-security-acceptance.md` template shape (see scaffolder
templates) — risk owner, re-audit date, compensating controls.
EOF
```
**Rollback:** `rm -f docs/decisions/README.md && rmdir docs/decisions 2>/dev/null || true`

### Step 5: Write `.codex/workflow-version.txt` with v0.1.0

**Idempotency check:** `grep -q '^0.1.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** Step 1 succeeded (`.codex/` exists)
**Apply:**
```bash
echo "0.1.0" > .codex/workflow-version.txt
```
**Rollback:** `rm -f .codex/workflow-version.txt`

### Step 6: Append global AGENTS.md additions (Option A install only)

**Skip condition:** if the project is per-project install (Option B), skip this step entirely. The setup skill detects this via the install-mode prompt.

**Idempotency check:** `grep -q "AgenticApps Workflow (Global)" "${CODEX_HOME:-$HOME/.codex}/AGENTS.md" 2>/dev/null`
**Pre-condition:** template exists at `${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/global-agents-additions.md`
**Apply:**
```bash
# Create the global AGENTS.md if missing
touch "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
echo "" >> "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
cat "${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/global-agents-additions.md" >> "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
```
**Rollback:** Manual — open `${CODEX_HOME:-$HOME/.codex}/AGENTS.md` and delete the appended block (anchored by `<!-- BEGIN: codex-workflow global section` to `<!-- END: codex-workflow global section -->` inclusive).

## Post-checks

- `test -f .codex/workflow-config.md && grep -v '{{' .codex/workflow-config.md | head -1` — placeholders substituted
- `jq -e '.hooks.pre_phase.brainstorm_ui' .planning/config.json` — config valid
- `grep -q "BEGIN: agentic-apps-workflow sections" AGENTS.md` — AGENTS.md updated
- `test -f docs/decisions/README.md` — ADR home seeded
- `cat .codex/workflow-version.txt` returns `0.1.0` — version recorded

## Skip cases

- **Project already installed** (pre-flight catches this) — exit
  with message pointing at `$update-codex-agenticapps-workflow`.
- **No git repo** — exit with message asking the user to `git init`
  first.
- **Scaffolder not installed** — exit with message pointing at
  `codex-workflow`'s `install.sh`.

## Notes

This migration cannot be tested non-interactively because Step 1
requires user-question responses. Validation is via running
`$setup-codex-agenticapps-workflow` against a real fresh project and
confirming the post-checks pass. See `migrations/test-fixtures/README.md`
for the broader test harness contract.
