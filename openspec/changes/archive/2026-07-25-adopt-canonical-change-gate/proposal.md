## Why

This change implements **core §18** (`spec/18-retargeted-change-gate.md`) by
replacing this repo's hand-maintained copy of the change-gate with the canonical
reference implementation core published in
[agenticapps-workflow-core#33](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/33)
(ADR-0022, on `main` at `ae90483`).

`bin/openspec-change-gate.sh` here scores **16/28** against core's executable
conformance harness. Measured on this branch, 2026-07-25:

```
tools/change-gate-conformance.sh bin/openspec-change-gate.sh
  -> 16 passed, 12 failed, 0 inconclusive of 28 rows
```

The failures are not cosmetic. The full defect accounting — every pre-adoption
defect, where it came from, and what pins it after this change:

| # | Defect | Effect | Pinned after adoption by |
|---|---|---|---|
| GAP-1 | Gate is cwd-relative, never resolves the repo root | `PreToolUse` fails open from any subdirectory | **local assertion** (no harness row) |
| GAP-2 | `openspec/**` exemption matches any component named `openspec` | `src/openspec/app.ts`, `/tmp/openspec/evil.ts`, `..`-escapes all editable while unsatisfied | harness rows (3) |
| GAP-3 | Reviewer counting counts headings | one vendor twice, fenced example blocks, and bare `reviewers:` YAML each clear the threshold with zero reviews | harness rows (3) |
| GAP-4 | Whitespace non-JSON reaches policy | blocks on a *parse* error, inverting §18 | **local assertion** (no harness row) |
| — | Self-review counts toward the threshold | the gate and the §02 evidence verifier disagree about who counts | harness rows (3), plus `OPENSPEC_GATE_SELF` |
| — | `GSD_SKIP_REVIEWS=1` allows even when `validate` is red | ships a change whose spec delta does not parse | harness row (1) |

Six defects. GAP-1 through GAP-4 are the four recorded in
`docs/GATE-KNOWN-GAPS.md`; the last two were surfaced by core's harness. Twelve
harness rows cover four of them; **GAP-1 and GAP-4 are covered by no row at all**
and are pinned by assertions this repo owns.

GAP-1 and GAP-4 were verified directly against both copies on 2026-07-25:

| | ours (164 lines) | core (253 lines) |
|---|---|---|
| GAP-1 · code edit from a subdirectory | `0` ALLOW (wrong) | `2` BLOCK |
| GAP-4 · `not json at all` on stdin | `2` BLOCK (wrong) | `0` fail-open |

The root cause of all six is the same, and GAP-1 through GAP-4 are recorded with
reproductions in `docs/GATE-KNOWN-GAPS.md`: core's
`gate/` was untracked and absent from its `origin/main`, so all four hosts copied
it from a local unpublished directory and it forked five ways. That is now fixed
upstream — core publishes the gate, a `# gate-version:` marker for installer
arbitration, and an executable harness. This repo's job is to stop maintaining a
copy.

## What Changes

**Vendored verbatim from core, never edited here:**

- `bin/openspec-change-gate.sh` ← core's 253-line gate, `# gate-version: 1.2.0`
- `tools/change-gate-conformance.sh` ← the 28-row harness (new `tools/` dir)

**Rewired to use the gate's real mode dispatch** instead of synthesizing one fake
hook payload per file:

- `bin/git-hooks/pre-commit` → `exec "$GATE" --pre-commit`
- `bin/openspec-gate-ci.sh` → run the harness, then `"$GATE" --ci`
- `.github/workflows/openspec-gate.yml` → adds a step that scores the gate before
  trusting its verdict

Each surface also gets a **named gate path**: CI enforces with the repo-local copy
it just scored, while the two local surfaces prefer the shared install so one
machine-wide upgrade reaches every repo. A fresh Actions runner has no
`~/.agenticapps/bin/`, so leaving this unpinned meant CI would either fail open or
enforce with a copy it never scored.

**Behaviour change, deliberate:** `--ci` is whole-repo, not diff-scoped. Any
active change lacking two independent reviewers fails CI regardless of which
files the PR touched. Our lifecycle lands reviews before code, so this is green
in practice.

**New enforcement this repo did not have:**

- `install.sh` honours `# gate-version:` and **refuses to downgrade** the shared
  `~/.agenticapps/bin/openspec-change-gate.sh`. Every host writes that one path,
  so without arbitration it is last-writer-wins and a stale host silently reverts
  the fix for every agent on the machine. This is the hazard issue #26 was
  originally filed about.
- `OPENSPEC_GATE_SELF=codex`, so this host's own reviews stop counting toward the
  threshold.

**Removed:**

- `docs/GATE-KNOWN-GAPS.md` and `test_gate_known_gaps` — the sha256 pin existed
  only to force re-verification when the canonical landed. It has landed; the
  harness replaces the pin as the live assertion, and the gaps' history moves to
  ADR-0012 where this repo's convention keeps provenance.

**Not changing:** the codex `PreToolUse` wrapper's translation logic. It stays
because `apply_patch` carries its path inside the patch blob and the gate cannot
parse it — that adapter is still load-bearing. It gains only an
`OPENSPEC_GATE_SELF` export.

## Capabilities

### New Capabilities

- `change-gate`: what this repo guarantees about the §18 enforcement gate it
  ships — that the gate is vendored from core rather than maintained here, that
  its conformance is proven by executable harness rather than asserted in prose,
  that all three enforcement surfaces use its real modes, and that the installer
  cannot downgrade the shared copy.

### Modified Capabilities

<!-- None. openspec/specs/ is empty; this is the repo's first capability. -->

## Impact

- **Scripts:** `bin/openspec-change-gate.sh` (replaced), `bin/git-hooks/pre-commit`,
  `bin/openspec-gate-ci.sh`, `tools/change-gate-conformance.sh` (new), `install.sh`
- **Skills:** `skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh`
- **CI:** `.github/workflows/openspec-gate.yml`
- **Migration:** `migrations/0014-adopt-canonical-gate.md`, 1.0.0 → 1.1.0, with
  assertions in `migrations/run-tests.sh`
- **Docs:** `docs/decisions/0012-vendor-canonical-change-gate.md` (new),
  `docs/GATE-KNOWN-GAPS.md` (deleted), `CHANGELOG.md`
- **Downstream:** every project scaffolded by this repo, and — via the shared
  `~/.agenticapps/bin/` path — every AgenticApps host on the operator's machine.
- **Upstream:** a core issue proposing two harness rows for GAP-1 and GAP-4, which
  no host's harness currently covers.
