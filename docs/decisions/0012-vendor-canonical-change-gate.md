# ADR-0012: Vendor the canonical §18 change-gate; stop maintaining a copy

**Status**: Accepted  **Date**: 2026-07-25  **Linear**: —
**Supersedes**: the local-gate posture recorded in `docs/GATE-KNOWN-GAPS.md` (deleted here)
**Upstream**: agenticapps-eu/agenticapps-workflow-core#33 (ADR-0022) · issue #26 · fleet tracker core#34

## Context

The §18 change-gate is one shared shell script that four host repos — `claude-`,
`codex-`, `opencode-`, `pi-agentic-apps-workflow` — install to a single path,
`~/.agenticapps/bin/openspec-change-gate.sh`.

It was never published from core. `gate/` was untracked and absent from core's
`origin/main`, so every host copied it from a local, unpublished directory. By
2026-07-25 there were **five divergent copies on one machine and none was
conformant**. Nothing detected this, because a drifted gate reports clean: it
passes every repo it guards while enforcing nothing.

This repo recorded its exposure rather than patching it. `docs/GATE-KNOWN-GAPS.md`
documented four defects with reproductions, and commit `54a2b37` pinned the
gate's sha256 so that re-syncing would turn the suite red and force
re-verification. That was the right call at the time — patching locally would
have made a sixth copy — and the pin did its job.

Core then resolved the fork in #33 / ADR-0022 by publishing
`reference-implementations/openspec-change-gate/` plus
`tools/change-gate-conformance.sh`, an executable conformance harness. Core's
implementation is composed from `pi-193` and `claude-184`'s reviewer counter,
deliberately *not* from this repo's 164-line variant, because adopting ours
wholesale would have deleted both enforcement floors in core.

### The full defect accounting

Measured on this branch, 2026-07-25. This repo's copy scored **16 of 28** rows.

| # | Defect | Effect | Now pinned by |
|---|---|---|---|
| GAP-1 | Gate resolved `$PWD`, never the repo root | `PreToolUse` failed open from any subdirectory | local assertion — **no harness row** |
| GAP-2 | `openspec/**` exemption matched any component named `openspec` | `src/openspec/app.ts`, `/tmp/openspec/evil.ts` and `..`-escapes freely editable while unsatisfied | 3 harness rows |
| GAP-3 | Reviewer counting counted headings | one vendor twice, fenced example blocks, and a bare `reviewers:` YAML line each cleared the threshold with zero reviews | 3 harness rows |
| GAP-4 | Whitespace non-JSON reached policy | blocked on a *parse* error, inverting §18 | local assertion — **no harness row** |
| — | Self-review counted | gate and §02 evidence verifier disagreed about who counts | 3 rows + `OPENSPEC_GATE_SELF` |
| — | `GSD_SKIP_REVIEWS=1` allowed over a red `validate` | shipped a change whose spec delta does not parse | 1 harness row |

GAP-2 and GAP-3 were live bypasses, not corner cases. GAP-1 and GAP-4 are the
ones worth remembering: **core's implementation fixes both, and core's harness
covers neither.** Verified by direct invocation against both copies —

| | ours (164 lines) | core (253 lines) |
|---|---|---|
| GAP-1 · code edit from a subdirectory | `0` ALLOW (wrong) | `2` BLOCK |
| GAP-4 · `not json at all` on stdin | `2` BLOCK (wrong) | `0` fail-open |

Adopting a 28/28 gate would have silently inherited coverage for four defects
and no coverage at all for two.

## Decision

**Stop maintaining a gate implementation in this repo. Vendor core's, verbatim,
and prove it by execution rather than by prose.**

1. **Vendor byte-identical, never hand-patch** (`bin/openspec-change-gate.sh`,
   `tools/change-gate-conformance.sh`). A host-local fix is how five copies
   diverged. Behaviour changes go to core with a matching harness row, then
   re-vendor.
2. **Provenance in a sidecar, not a header.** `tools/core-vendor.manifest`
   records core's commit and each file's sha256. A "vendored from `<commit>`"
   comment inside the file would itself break the byte-identity it claimed to
   record — a contradiction the reviewers missed and implementation exposed.
3. **Verify against the recorded commit, not a working tree.** A core checkout
   is a live workspace. While this was written, core sat on
   `fix/gate-symlinked-root-exemption`, mid-TDD, with an uncommitted gate
   scoring 29/31 — and a working-tree comparison reported divergence from a file
   that was never published. The check uses `git show <commit>:<path>`.
4. **The bar is zero failing rows, not a number.** The harness grows; a
   hardcoded `28/28` would be stale on arrival and would read as verification
   while verifying less than the instrument offers.
5. **All three surfaces use real mode dispatch** — hook, `--pre-commit`, `--ci`.
   No surface may synthesize a tool-call payload to reach hook mode from a
   non-hook context.
6. **`--ci` is whole-repo.** An unreviewed active change fails the build even if
   the pull request did not touch it.
7. **Per-surface gate paths.** CI enforces with the repo-local copy it just
   scored; the local surfaces prefer the shared install so one machine-wide
   upgrade reaches every repo.
8. **The shared copy is trusted only if it carries a valid `# gate-version:`.**
9. **`install.sh` refuses to downgrade** the shared path, atomically and under a
   bounded-retry lock (`bin/install-gate.sh`).
10. **`OPENSPEC_GATE_SELF=codex` is set by every surface**, not inherited.

## Alternatives Rejected

**Patch our 164-line copy to close the twelve failing rows.** Faster, and it
would have preserved diff-scoped CI. It also reproduces the exact failure this
change exists to end, and strands us again the next time core moves.

**Symlink to core rather than vendor.** Eliminates copy drift entirely, but
requires a core checkout at a predictable path on every consumer machine.
`install.sh` must work where only this repo exists.

**Keep diff-scoped `--ci` and upstream a `--ci-diff` mode.** Preserves today's
ergonomics at the cost of divergence at precisely the surface this change exists
to un-diverge, pending an upstream feature that may never land.

**Retain `GATE-KNOWN-GAPS.md` marked closed.** Maximally conservative on
provenance, but leaves a document whose title claims open gaps that no longer
exist. Its own closing step said to delete it once the gaps became hard
assertions. Its content lives in this ADR instead — the repo's *supersede, never
delete* convention names migrations and ADRs, which is where provenance belongs.

**Rely on the 28-row harness alone.** Would leave GAP-1 and GAP-4 — the two we
had actually measured — unpinned, which is how the fleet drift went unnoticed in
the first place.

## Consequences

**A docs-only PR can now fail.** Whole-repo `--ci` blocks while any active
change is unreviewed. Reviews land before code in this lifecycle, so the red
window is the window in which the change genuinely is not ready.

**Re-vendoring is cheap, and that is the point.** A copy plus a green suite.
Core's in-flight symlinked-root fix will land as a later `gate-version`; adopting
it should be minutes, not another fork.

**Vendoring is a snapshot, and snapshots go stale.** Mitigated by the harness in
CI and by the byte-identity leg — which is *conditional* on a core checkout and
SKIPs loudly without one. This is weaker than the sha256 pin in exactly one
respect, and the trade is deliberate: that pin also had to be hand-edited on
every legitimate re-vendor, and friction on the correct action is what kept this
repo on a defective gate.

**The fleet residual is closed for us, not for the fleet.** Arbitration stops
*this* host downgrading the shared path; the marker check keeps *our* floors off
a defective shared copy. Neither stops a non-arbitrating sibling from
overwriting that path for every other repo on the machine, and a
marked-but-older sibling copy is still trusted. Verified live: the shared gate on
this machine carries no marker at all, so the local floors are already falling
back to the repo-local vendored copy. Fully closing this needs all four hosts
adopted — tracked at core#34.

**Two upstream asks** follow from this work: harness rows for GAP-1 and GAP-4,
which no host's harness currently covers.
