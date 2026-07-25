---
id: 0014
slug: adopt-canonical-gate
title: Vendor core's canonical §18 change-gate; stop maintaining a copy (v1.0.0 -> 1.1.0)
from_version: 1.0.0
to_version: 1.1.0
applies_to:
  - ~/.agenticapps/bin/openspec-change-gate.sh              # now version-arbitrated, never blind-overwritten
  - .git/hooks/pre-commit                                   # rewired to the gate's --pre-commit mode
  - .codex/workflow-version.txt                             # record new project version
  # Scaffolder-side (shipped by the release, not written into a target project):
  - bin/openspec-change-gate.sh                             # REPLACED — vendored byte-identical from core
  - tools/change-gate-conformance.sh                        # NEW — vendored harness (the instrument)
  - tools/core-vendor.manifest                              # NEW — sidecar provenance: core commit + sha256
  - bin/install-gate.sh                                     # NEW — # gate-version arbitration, atomic + locked
  - bin/git-hooks/pre-commit                                # thin wrapper -> "$GATE" --pre-commit
  - bin/openspec-gate-ci.sh                                 # thin wrapper -> harness, then "$GATE" --ci
  - .github/workflows/openspec-gate.yml                     # conformance step before the gate step
  - skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh  # marker check + OPENSPEC_GATE_SELF
  - install.sh                                              # routes the gate install through install-gate.sh
  - docs/GATE-KNOWN-GAPS.md                                 # DELETED — history folded into ADR-0012
  - docs/decisions/0012-vendor-canonical-change-gate.md      # NEW — the adoption ADR
requires:
  - tool: openspec
    verify: "openspec --version"
    install: "npm i -g @fission-ai/openspec"
---

# Migration 0014 — Adopt the canonical §18 change-gate (v1.0.0 → 1.1.0)

Replaces this repo's hand-maintained change-gate with the reference
implementation `agenticapps-workflow-core` published in core#33 (ADR-0022), and
makes its conformance a continuously-executed check rather than a claim.

The full rationale, the six-defect accounting, and the rejected alternatives are
in [ADR-0012](../docs/decisions/0012-vendor-canonical-change-gate.md). The short
version: the gate was never published from core, so all four hosts copied it from
an unpublished local directory and it forked five ways. This repo's copy scored
**16 of 28** against core's harness, with three live bypasses.

## What does NOT change

- **The codex `PreToolUse` wrapper's `apply_patch` translation.** codex carries
  the edited path inside the patch blob at `tool_input.command`, which the gate
  cannot parse; hand it the raw payload and it fails open by design. That adapter
  is still load-bearing. It gains a marker check and `OPENSPEC_GATE_SELF`, and
  nothing else.
- **The multi-AI change review.** Still the §18 gate's predicate, still produced
  by `codex-openspec-change-review`, still ≥2 distinct external vendors.
- **`bin/reviewer-cli.sh`.** Known fleet drift (this repo ships a superset with
  `claude`/`opencode` arms); out of scope here and tracked separately.
- **`.planning/`.** Untouched.

## The one behavioural change to know about

`--ci` is **whole-repo**, not diff-scoped. An unreviewed active change fails the
build even when the pull request did not touch it, and a proposal-only pull
request is red until its `REVIEWS.md` lands.

That is stricter than the driver it replaces, and it is what §18's wording
requires. In this lifecycle reviews come before code, so the red window is the
window in which the change genuinely is not ready to merge.

## Two defects the harness does not cover

Core's implementation fixes GAP-1 (the gate resolved `$PWD` rather than the repo
root) and GAP-4 (whitespace non-JSON reached policy instead of failing open).
**Core's harness has a row for neither.** Both are asserted directly by
`test_migration_0014`, so a future re-vendor cannot regress them while still
passing every declared row.

## Pre-flight

```bash
# The OpenSpec CLI must exist — the gate blocks when it cannot verify.
openspec --version || npm i -g @fission-ai/openspec

# A core checkout enables the byte-identity leg. Without one the suite still
# runs conformance, provenance, and the GAP pins, and SKIPs identity LOUDLY.
ls "${AGENTICAPPS_CORE_ROOT:-../agenticapps-workflow-core}/reference-implementations/openspec-change-gate" \
  || echo "no core checkout — byte-identity will SKIP (not silently pass)"
```

## Steps

### Step 1: Vendor the gate and the harness from core

Vendor from `origin/main`, never from the working tree. A core checkout is a
live workspace and may sit mid-change on a feature branch — while this migration
was written, core was on `fix/gate-symlinked-root-exemption` with an uncommitted
gate scoring 29/31.

```bash
CORE="${AGENTICAPPS_CORE_ROOT:-../agenticapps-workflow-core}"
COMMIT="$(git -C "$CORE" rev-parse origin/main)"
mkdir -p tools

git -C "$CORE" show "${COMMIT}:reference-implementations/openspec-change-gate/openspec-change-gate.sh" \
  > bin/openspec-change-gate.sh
git -C "$CORE" show "${COMMIT}:tools/change-gate-conformance.sh" \
  > tools/change-gate-conformance.sh
chmod +x bin/openspec-change-gate.sh tools/change-gate-conformance.sh

# Sidecar provenance. The vendored files carry NO local header: a
# "vendored from <commit>" comment would itself break the byte-identity it
# claimed to record.
{
  echo "core_repo=agenticapps-eu/agenticapps-workflow-core"
  echo "core_commit=${COMMIT}"
  for f in bin/openspec-change-gate.sh tools/change-gate-conformance.sh; do
    printf 'file=%s sha256=%s\n' "$f" "$(shasum -a 256 "$f" | awk '{print $1}')"
  done
} > tools/core-vendor.manifest
```

### Step 2: Score the vendored gate before trusting it

```bash
bash tools/change-gate-conformance.sh bin/openspec-change-gate.sh
# Every declared row must pass. The bar is ZERO FAILURES, never a fixed count —
# the harness grows, and a hardcoded number reads like verification while
# verifying less than the instrument offers.
```

### Step 3: Rewire both floors to real mode dispatch

`bin/git-hooks/pre-commit` and `bin/openspec-gate-ci.sh` become thin wrappers.
Neither may synthesize a tool-call payload: §18 requires the gate be
demonstrable by direct script invocation, and enforcement reached through a
fabricated payload is not that.

Gate resolution differs per surface, deliberately:

- **CI** uses the **repo-local** copy it just scored. A runner has no
  `~/.agenticapps/bin/`, and enforcing with an unscored copy would defeat step 2.
- **`pre-commit` and `PreToolUse`** prefer `$OPENSPEC_CHANGE_GATE`, then the
  **shared** copy *if it carries a valid `# gate-version:` marker*, then
  repo-local.

The marker check is the transitional defence. Only this host arbitrates so far,
so a sibling can blind-write its unmarked pre-canonical copy over the shared
path; without the check, shared-first resolution would run our own floors on the
gate this migration replaces.

```bash
install -m 0755 bin/git-hooks/pre-commit "$(git rev-parse --git-path hooks)/pre-commit"
```

### Step 4: Install the arbitrating installer

```bash
# install.sh now routes the shared-gate install through bin/install-gate.sh:
#   installed >  incoming -> refuse, naming both versions and the force command
#   installed == incoming -> write (repairs a truncated same-version copy)
#   installed <  incoming -> write
# Absent/malformed markers are 0.0.0 on BOTH sides. Atomic (temp + mv) under a
# bounded-retry mkdir lock.
bash bin/install-gate.sh --dry-run bin/openspec-change-gate.sh \
  "$HOME/.agenticapps/bin/openspec-change-gate.sh"
```

### Step 5: Set `OPENSPEC_GATE_SELF=codex` on every surface

Set explicitly by the `PreToolUse` wrapper, the `pre-commit` hook, and the CI
workflow env — never inherited. A human running `git commit` has no such
variable, and a floor that counts codex's own reviews while CI does not is the
surface-dependent enforcement this gate exists to remove.

### Step 6: Retire the known-gaps record

```bash
git rm docs/GATE-KNOWN-GAPS.md
# test_gate_known_gaps and its sha256 pin are replaced by test_migration_0014.
# History moves to docs/decisions/0012-vendor-canonical-change-gate.md.
```

### Step 7: Bump versions (1.0.0 → 1.1.0)

```bash
sed -i '' 's/^version: 1\.0\.0$/version: 1.1.0/' skills/agentic-apps-workflow/SKILL.md
echo "1.1.0" > .codex/workflow-version.txt
```

## Post-checks

```bash
# 1. The vendored gate is conformant — zero failing rows, whatever the count.
bash tools/change-gate-conformance.sh bin/openspec-change-gate.sh

# 2. The floors use real modes and synthesize nothing.
grep -q -- '--pre-commit' bin/git-hooks/pre-commit && ! grep -q tool_input bin/git-hooks/pre-commit
grep -q -- '--ci'         bin/openspec-gate-ci.sh  && ! grep -q tool_input bin/openspec-gate-ci.sh

# 3. The two regressions no harness row covers.
#    From a SUBDIRECTORY the gate must still block; unparseable stdin must
#    fail OPEN. The pre-adoption copy returned 0 and 2 — the inverse.

# 4. The installer refuses a downgrade and leaves the file byte-for-byte intact.

# 5. Self-review is excluded at every surface.
grep -qE 'OPENSPEC_GATE_SELF=.*codex' bin/git-hooks/pre-commit
grep -qE 'OPENSPEC_GATE_SELF: *codex' .github/workflows/openspec-gate.yml

# 6. THE ONE STEP NO SCRIPT CAN DO. Start a FRESH codex session in the project,
#    run /hooks, and confirm the openspec-gate entry is Active, not "Review".
#    A hook loaded at session start cannot gate the session that installed it,
#    and it looks installed either way — this is ADR-0011's second defect. Until
#    it reads Active, the PreToolUse surface enforces nothing. The git
#    pre-commit and CI floors cover the gap meanwhile, and both are verified.
```

All of 1–5 are asserted by `test_migration_0014`,
`test_migration_0014_floors`, and `test_migration_0014_arbitration` in
`migrations/run-tests.sh`. Step 6 is the operator's.
