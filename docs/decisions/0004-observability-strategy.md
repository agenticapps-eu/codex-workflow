# ADR-0004 — §10 observability: delegate to agenticapps-observability via a Codex installer

- Status: Accepted
- Date: 2026-06-09
- Phase: 0 (spec 0.4.0 catch-up)
- Implements spec: `agenticapps-workflow-core` §10 (introduced 0.2.0; current 0.3.2)
- Supersedes: —
- Superseded by: —

## Context

To claim `implements_spec: 0.4.0`, codex-workflow must satisfy core spec
§10 (observability). §10.7 obliges every host to provide a **generator**
that scaffolds conformant wrappers, validates brownfield projects, applies
insertions on consent, and (from 0.3.0) maintains a baseline + delta scan.
codex-workflow v0.1.0 ships **no observability** at all — §10 is net-new.

Per spec/09, a host can satisfy a declarative MUST either by implementing
it directly or by **delegating** it to a host mechanism (a consumed skill,
a CI job, a reviewer agent). A delegation that is actually consumable
counts as *satisfied* — it preserves `full` conformance, it is not a spec
delta.

The reference host, `claude-workflow`, **extracted** observability out of
its scaffolder at v2.0.0 (SPLIT-03, migration `0022`). The generator now
lives in a standalone repo, `agenticapps-observability`, installed and
versioned independently. claude-workflow consumes it via a `requires:`
block (clone + `install.sh`), a pre-flight that hard-aborts if the skill
is absent, and a narrow `sed` that repoints the project's `CLAUDE.md`
`observability:` block at the `observability` skill. §10 is recorded as a
**delegation** to that separate install, and claude-workflow remains
`full`.

Two conformant paths were available to codex (the Phase 0 gray area):

- **Option A — native generator skill.** Author
  `skills/codex-add-observability/` in this repo (init / scan /
  scan-apply, per-stack templates, §10.5 Flush, §10.7.1 module-root
  resolution, §10.9 baseline + `--since-commit` delta + CI). Self-
  contained, no cross-repo dependency, but re-owns a generator the
  ecosystem is centralizing — and would itself need extracting in a
  later minor to track the reference architecture.

- **Option B — consume `agenticapps-observability`.** Delegate, exactly
  as claude-workflow now does. Less code to own long-term and aligned
  with the SPLIT trajectory — *but* the obs repo is **Claude-only
  today**: its `install.sh` writes exclusively to `~/.claude/skills`,
  with no `$CODEX_HOME` surface. Its `scan` subcommand already reads
  `AGENTS.md` for "pi/codex hosts" (`scan/SCAN.md:124`), so the runtime
  is closer to host-neutral than the install/dispatch plumbing. Option B
  therefore requires a small **upstream enablement**: a second,
  Codex-targeted installer on the obs repo.

## Findings

1. **The obs repo install surface is Claude-only.** `install.sh` line:
   `SKILLS_DIR="$HOME/.claude/skills"`; it symlinks `observability` →
   repo root and a legacy `add-observability` alias. Zero `$CODEX_HOME` /
   `~/.codex` references anywhere. (Investigation report, Phase 0.)

2. **Codex's loader scans `$CODEX_HOME/skills/<name>/SKILL.md` one level
   deep — the same shape as Claude's `~/.claude/skills/`.** codex-workflow's
   own `install.sh` already targets `${CODEX_HOME:-$HOME/.codex}/skills`.
   So a Codex installer for the obs repo is a near-mirror of the existing
   `install.sh` with a different destination root — genuinely small.

3. **The obs repo already vendors `agenticapps-shared`** as a git
   submodule (its `install.sh` runs `submodule update --init` before
   linking). This confirms the shared-submodule direction codex is also
   adopting (see CONTEXT.md), and means the Codex installer must perform
   the same submodule refresh guard.

4. **The runtime is partly host-aware already.** `scan` reads `AGENTS.md`
   when `CLAUDE.md` is absent. The remaining Claude-isms are in the
   dispatch/invocation prose (e.g. `claude /add-observability scan`
   invocation strings, the `~/.claude/skills/observability` slash-
   discovery invariant in `SKILL.md`) — these need Codex-equivalent
   guidance, not a logic rewrite.

5. **claude-workflow's consumption contract is the template to mirror:**
   migration `0022` — `requires: { skill: observability, install: clone
   + install.sh, verify: test -f .../observability/SKILL.md }`, a
   pre-flight hard-abort (exit 3) with the clone pointer when absent
   (no auto-install, decision D-03), and a `sed` repoint of the
   `observability:` block's `skill:` reference.

## Decision

**Option B — codex-workflow satisfies §10 by delegating to
`agenticapps-observability`, after adding a Codex install surface to that
repo.** "Two different installers" on the obs repo: the existing Claude
`install.sh` and a new Codex installer.

Three deliverables (Phase 3 of the catch-up):

1. **Upstream (`agenticapps-observability`):** add a Codex install surface
   — a `$CODEX_HOME/skills/observability` installer (a sibling
   `install-codex.sh`, or a host flag on the existing `install.sh`),
   mirroring codex-workflow's `install.sh` shape (symlink/copy/dry-run,
   idempotent, submodule-refresh guard, refuse-to-clobber). Confirm the
   `observability` SKILL.md loads under Codex 0.130.0 and that its `scan`
   /`init` invocation prose has a Codex equivalent. Shipped as a PR to
   the obs repo.

2. **codex-workflow binding + migration:** a thin binding doc (setup /
   update guidance pointing downstream Codex projects at the obs skill)
   plus **migration `0003`** that wires a downstream project — a
   `requires:` block with the Codex clone+install pointer, a pre-flight
   hard-abort when the obs skill is absent (no auto-install, mirroring
   D-03), and a repoint of the project's **`AGENTS.md`** `observability:`
   block. Modeled on claude-workflow `0022`.

3. **Bookkeeping:** record §10 as a **delegation** (not a spec delta) in
   `docs/ENFORCEMENT-PLAN.md`; port ADR-0014 into `docs/decisions/`
   noting the delegation framing.

## Alternatives rejected

- **Option A (native generator).** Rejected to avoid re-owning a
  generator the ecosystem has deliberately centralized into
  `agenticapps-observability`. Building it natively would duplicate
  per-stack templates, the §10.9 baseline machinery, and the Flush
  primitive that the standalone repo already implements and versions —
  and would then need its own extraction migration in a later minor to
  re-converge with the reference architecture. Option B reaches the same
  `full` conformance with far less surface to maintain.

- **Carry §10 as a spec delta under `partial`.** Rejected: the target is
  `full` 0.4.0 conformance, and delegation to a consumable obs skill is
  a *satisfied* MUST under §09, not an omission. A spec delta would be a
  weaker, incorrect claim once the Codex installer exists.

## Consequences

- **This catch-up now spans two repos.** The codex-workflow PR depends on
  landing the obs-repo Codex-installer PR first (or in lockstep). The
  pre-flight in migration `0003` fails closed if the obs skill is not
  installed, so a downstream project is never left in a half-wired state.

- **§10 conformance is owned here, implemented there.** codex-workflow
  remains the conformance claimant for §10; the wrapper generation,
  Flush, module-root resolution, and baseline/delta machinery are the
  obs repo's responsibility and version axis.

- **No per-stack templates in codex-workflow.** Unlike Option A, this
  repo ships no observability templates — consistent with claude-workflow
  post-2.0.0.

- **Future alignment is free.** When the obs repo gains richer Codex
  support, codex inherits it without a code change here — only the
  consumed version moves.

## References

- Phase 0 investigation report (obs repo Codex-awareness); spec
  `10-observability.md` §10.5/§10.7/§10.7.1/§10.9; `adrs/0014-observability-architecture.md`.
- claude-workflow `migrations/0022-observability-repoint-phase-sentinel.md`
  (repoint mechanism), `migrations/0011-observability-enforcement.md`
  (the pre-extraction in-scaffolder model that Option A would have mirrored).
- `agenticapps-observability/install.sh` (the Claude-only installer to
  mirror), `scan/SCAN.md:124` (existing `AGENTS.md` host-awareness).

## Open follow-ups

- **F1** — Confirm the obs `observability` SKILL.md loads cleanly under
  Codex 0.130.0 once the Codex installer symlinks it into
  `~/.codex/skills/`, and that `init`/`scan` invocation prose has a Codex
  path. (Phase 3, upstream PR.)
- **F2** — Decide the obs-repo Codex installer shape with that repo's
  maintainer: sibling `install-codex.sh` vs. a `--host codex` flag on the
  existing `install.sh`. (Phase 3.)
