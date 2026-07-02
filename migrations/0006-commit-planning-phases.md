---
id: 0006
slug: commit-planning-phases
title: Commit phase artifacts — strip a whole-tree .planning/phases/ ignore (v0.3.0 -> 0.4.0)
from_version: 0.3.0
to_version: 0.4.0
applies_to:
  - .gitignore                                 # strip a whole-tree `.planning/phases/` ignore if present
  - skills/agentic-apps-workflow/SKILL.md      # scaffolder version bump 0.3.0 -> 0.4.0
  - .codex/workflow-version.txt                # record new project version
requires: []
optional_for: []
---

# Migration 0006 — Commit phase artifacts (v0.3.0 -> 0.4.0)

Phase artifacts under `.planning/phases/<NN>-<slug>/` (`<NN>-CONTEXT.md`,
`<NN>-<MM>-PLAN.md`, `<NN>-VERIFICATION.md`, and the AgenticApps gate outputs
`REVIEW.md`, `QA.md`, `DB-AUDIT.md`) are the **shared, cross-host project plan** —
the standard ([`docs/standards/gsd-binding-and-planning.md`](../docs/standards/gsd-binding-and-planning.md)
§5) lists them as committed state. A **whole-tree** `.planning/phases/` ignore
drops exactly the planning evidence another host or a future session picks the
work up from.

**Evidence (dual-host workflow-testbed benchmark, rounds 1+2, 2026-07-01/02):**
host projects carried `.planning/phases/` in `.gitignore`, and the testbed's own
notes mis-attributed it to "the GSD config." On codex the round-2 run had to
improvise `git add -f` to commit phase evidence; claude's evidence was not
committed at all; opencode un-ignored the path mid-run. See the shared
[ADR-0037](https://github.com/agenticapps-eu/claude-workflow/blob/main/docs/decisions/0037-commit-phase-artifacts.md)
and this repo's standard §5 amendment.

This migration makes the policy authoritative for **existing installs**: it
strips a whole-tree `.planning/phases/` ignore from the project's `.gitignore`
so the next normal `git add` / commit captures the evidence — `git add -f` is
then never needed. **Fresh codex installs are already conformant by
construction:** the codex scaffolder never writes a project `.gitignore` (setup's
atomic commit stages `.planning/` wholesale, and this repo's own committed
`.gitignore` ignores only `.planning/cache/`, `.planning/state/`, and the host
session-handoffs), so there is no seed to guard.

**Why a 0.x minor bump:** the update engine applies a migration only when
`installed >= from_version AND installed < to_version`. Every live project is at
`0.3.0` after 0005, so a `0.3.0 -> 0.4.0` migration is the shape that reaches the
fleet via `$update-codex-agenticapps-workflow`.

**Supported upgrade floor:** `0.3.0 -> 0.4.0`. Projects below 0.3.0 replay the
chain through 0005 first.

## Pre-flight

```bash
# Project root must be a git repo
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# Workflow scaffolder is at the supported floor (0.3.0), or 0.4.0 for re-apply.
grep -qE '^version: 0\.(3|4)\.0$' skills/agentic-apps-workflow/SKILL.md || {
  INSTALLED=$(grep -E '^version:' skills/agentic-apps-workflow/SKILL.md 2>/dev/null | sed 's/version: //')
  echo "ABORT: scaffolder version is $INSTALLED (need 0.3.0)."
  echo "       Apply prior migrations first via \$update-codex-agenticapps-workflow."
  echo "       Supported upgrade floor: 0.3.0 -> 0.4.0."
  exit 3
}
```

## Steps

### Step 1: Un-ignore phase artifacts in `.gitignore`

Remove any **whole-tree** `.planning/phases/` (or `.planning/` / `.planning/*`)
ignore line. Narrow ignores of specific scratch files UNDER the tree (e.g.
`.planning/phases/*/.codex-review.md`) are intentional and preserved — the sed
patterns are anchored to a bare directory line, so they do not match those.
Legitimate transient ignores (`.planning/cache/`, `.planning/state/`) are also
left untouched — they are narrower than the bare-`.planning/` anchor.

**Idempotency check (positive — no whole-tree phases ignore present):**
```bash
[ ! -f .gitignore ] || ! grep -qE '^[[:space:]]*/?\.planning/phases/?[[:space:]]*$' .gitignore
```
(Returns 0 when `.gitignore` is absent, or present and already clean — Step 1 is
then a no-op. A project that never ignored the tree needs no change.)

**Apply (only when a `.gitignore` exists and carries the offending line):**
```bash
if [ -f .gitignore ]; then
  sed -i.0006.bak -E \
    -e '/^[[:space:]]*\/?\.planning\/phases\/?[[:space:]]*$/d' \
    -e '/^[[:space:]]*\/?\.planning\/?[[:space:]]*$/d' \
    -e '/^[[:space:]]*\/?\.planning\/\*[[:space:]]*$/d' \
    .gitignore
  rm -f .gitignore.0006.bak
fi
```

After removal the previously-ignored artifacts become trackable; the next
`git add -A` / commit captures them (no `git add -f` needed). This migration does
not itself stage or commit — that is the workflow's normal commit step.

**Rollback:** `git checkout -- .gitignore` (the file is git-tracked in any
project that had one). If the project had no `.gitignore`, this step made no
change and there is nothing to roll back.

### Step 2: Bump the scaffolder version (implements_spec unchanged)

**Idempotency check:** `grep -q '^version: 0.4.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.3.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0006.bak -E 's/^version: 0\.3\.0$/version: 0.4.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0006.bak
```
(`implements_spec` is unchanged — do NOT touch it.)
**Rollback:** `sed -i.bak -E 's/^version: 0\.4\.0$/version: 0.3.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 3: Record the new project version

**Idempotency check:** `grep -q '^0.4.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:** `echo "0.4.0" > .codex/workflow-version.txt`
**Rollback:** `echo "0.3.0" > .codex/workflow-version.txt`

## Post-checks

```bash
# 1. No whole-tree phases ignore remains (ALWAYS true on success)
[ ! -f .gitignore ] || ! grep -qE '^[[:space:]]*/?\.planning/phases/?[[:space:]]*$' .gitignore

# 2. Version bumped to 0.4.0 (ALWAYS true on success)
grep -q '^version: 0.4.0$' skills/agentic-apps-workflow/SKILL.md
grep -q '^0.4.0$' .codex/workflow-version.txt
```

- Drift test green: SKILL.md `version` (0.4.0) == latest migration `to_version` (0.4.0)

## Skip cases

- **`from_version` mismatch** (project not at 0.3.0) → migration framework skips
  silently per the standard rule. Projects below 0.3.0 replay 0005 first.
- **No `.gitignore`, or one that never ignored the tree** → Step 1 is a no-op
  (idempotency anchor already positive); Steps 2–3 still bump the version.

## Compatibility

- **Additive (minor) bump** to `0.4.0`: no breaking change. Step 1 only removes a
  policy-violating whole-tree ignore line (surgical, anchored to a bare directory
  line) and preserves every other `.gitignore` entry — including narrow scratch
  ignores under the phases tree and `.planning/cache/` / `.planning/state/`.
- **Drift coupling:** as the highest-numbered migration file, 0006's `to_version`
  (0.4.0) becomes the drift target; `skills/agentic-apps-workflow/SKILL.md` is
  bumped to 0.4.0 in lockstep (`run-tests.sh` `test_drift`).
- Per migration immutability, the chain stays contiguous
  (`0000` → `0001` → `0002` → `0003` → `0004` → `0005` → `0006`).

## Notes

- **Testable** non-interactively via `test_migration_0006` in
  `migrations/run-tests.sh`: it asserts the whole-tree ignore is stripped, a
  narrow under-tree ignore and `.planning/cache/` survive, and the version bump +
  rollback round-trip.
- **Mirrors** claude-workflow's `0024-commit-planning-phases` and
  opencode-workflow's equivalent, per the shared ADR-0037 downstream-hosts note.
  Codex ships no snapshot, so it carries no snapshot drift-guard §6 analog — the
  fresh-install path is conformant by construction (no scaffolder `.gitignore`).

## References

- Standard: `docs/standards/gsd-binding-and-planning.md` §5 (shared state) + conformance checklist
- Shared ADR: claude-workflow `docs/decisions/0037-commit-phase-artifacts.md`
- Sibling precedent: claude-workflow `migrations/0024-commit-planning-phases.md`
- Evidence: `workflow-testbed` benchmark rounds 1+2 (2026-07-01/02)
