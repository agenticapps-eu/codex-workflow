# ADR-0011 — Adopt the OpenSpec + Superpowers front end (spec v1.0.0), retiring the GSD planning engine

**Status:** Accepted
**Date:** 2026-07-24
**Applies to:** `codex-workflow` (this repo) — the OpenAI Codex CLI host scaffolder
**Supersedes:** ADR-0009 (plan-review gate — retargeted, not dropped) and
ADR-0010 (region-aware §11 placement — its GitNexus premise is gone).
Retires the 0.x standalone plan-review gate *binding*; ADR-0003's framing of
the GSD prompts as the workflow entry point is now historical.
**Relates to:** `agenticapps-workflow-core` spec v1.0.0 §16–§19 and core
ADR-0021; migration `0013`; `docs/WORKFLOW.md`.

## Context

The 0.x line planned with the GSD `.planning/` phase engine as its front end:
roadmap → discuss → plan → execute, each phase a directory of artifacts.
`agenticapps-workflow-core` **v1.0.0** (§16–§19, core ADR-0021) replaces that
front end with **OpenSpec** while keeping the **Superpowers execution
discipline** unchanged — TDD, evidence rules, the independent Stage-2 code
review, the commitment ritual, and the §11 Coding Discipline block all survive
verbatim. Only the planning surface moves: from a bespoke phase engine to a
spec lifecycle whose CLI is the authority.

`opencode-workflow` adopted v1.0.0 first, as the pilot host. This ADR is the
**codex** instantiation. Where the pilot's shape and codex's runtime disagree,
codex's runtime wins and the divergence is recorded below — that is the whole
point of doing this per host rather than copying.

## Decision

**Bind OpenSpec upstream as the planning front end, re-express the adversarial
multi-AI review as the §18 change-gate predicate, collapse the redundant gates,
and remove gitnexus from every live surface.**

### OpenSpec binding (§16)

Bind OpenSpec **upstream, not vendored**. `install.sh` runs
`openspec init --tools codex --profile core` (CLI `@fission-ai/openspec`,
installed version **1.6.0**), which generates the per-project `openspec/` slot
and this host's command surface. The **CLI is authoritative over prose**: where
this ADR, a skill body, or the core standard describes a command, the installed
CLI wins.

**Recorded divergence (§16 requires the host to note it).** The core standard
describes an OPSX `/opsx:*` slash-command surface. On codex, CLI 1.6.0
generates **six project-local skills** under the repo's `.codex/skills/` —
`openspec-explore`, `-propose`, `-update-change`, `-apply-change`,
`-sync-specs`, `-archive-change` — invoked as `$openspec-propose` and so on.
There are no `/opsx:*` commands on this host. They are regenerable CLI output,
so they are gitignored here and never hand-edited.

### Lifecycle (§17)

`propose → validate → Superpowers-execute → archive`, then **ship** as a
distinct act. `archive` folds the spec delta and moves the change directory and
produces **no git commit**; shipping is the separate VCS step with its own
`branch-close` gate. Conflating them is a spec violation.

### The change-gate (§18, retargeted)

The real enforcement surface is a **host-agnostic shell script**,
`~/.agenticapps/bin/openspec-change-gate.sh`, byte-identical to the copy the
opencode host installs — one script, four hosts. It owns the exit-code truth
table: allow out-of-change; exempt `openspec/**` writes; block an active change
lacking validate-green **or** `REVIEWS.md` ≥ 2 reviewers; documented
`GSD_SKIP_REVIEWS=1` override; fail open on *parse* error only.

It is wired at three surfaces: the codex `PreToolUse` hook (`apply_patch`), a
git `pre-commit` hook, and CI. The latter two are the **floor** — a PreToolUse
hook is loaded at session start and cannot gate the session that installs it.

**Two codex facts make a naive wiring silently useless**, and both are why
`hook-wrapper-openspec-gate.sh` exists rather than pointing `hooks.json`
straight at the gate:

1. codex's `apply_patch` payload carries the edited path **inside the patch
   blob** (`tool_input.command`), not in a `file_path` field. Handed the raw
   payload, the gate parses no path and fails open by design — allowing every
   edit. Verified: the bare gate exits 0 on a real `apply_patch` payload the
   wrapper correctly denies. This is asserted in the test suite so it cannot
   silently regress.
2. A codex `PreToolUse` hook emitting invalid stdout **fails open** and runs the
   tool anyway. A block is therefore emitted as jq-built
   `permissionDecision: deny` JSON with exit 0.

Phase 13's `Source: native-hook` label and per-invocation log carry forward into
the new wrapper. They are what exposed a false positive where a prompt-based
self-check produced a block indistinguishable from native enforcement.

### plan-review reconciliation (stated explicitly, because it looks like a contradiction)

The port brief said "keep the plan-review gate." Spec §17 **forbids a standalone
plan-review or spec-review gate** under 1.0.0. These are reconciled, not traded:

- The **multi-AI adversarial review is KEPT**, re-expressed as the §18
  change-gate **predicate** (validate green AND ≥2 `## Reviewer:` headings).
- The **producer** is `codex-openspec-change-review` — the retargeted
  `codex-plan-review`, critiquing the change (proposal + spec delta) instead of
  a `*-PLAN.md`.
- It is **not a separately-named gate**. Same adversarial mechanism, one fewer
  moving part. ADR-0018's failure mode stays closed.

Every discipline the 0.x producer earned carries forward verbatim, because each
was written in response to something that actually happened: the egress manifest
and affirmative consent before transmission; the honest statement that the
manifest is *advisory* and cannot constrain an agentic reviewer CLI (this repo's
own `opencode` reviewer once spent ten minutes reading the repo and running the
test suite instead of reviewing); reviewer independence; refuse-below-two rather
than emit a one-reviewer file; never fabricate a verdict for a CLI that failed;
and honest provenance with a Model column. `codex` is never a reviewer here — a
host does not review its own change.

### Gate collapse (§17)

- `spec-review`'s structural role folds into `openspec validate --all`; the
  `codex-spec-review` skill is deleted.
- `cso` / security stays **always-on**.
- `database-sentinel`, `qa`, `design-critique`, `design-shotgun` and
  `impeccable` become **conditional** — fired by the change's surface, not run
  every time.
- `ts-declare-first` is **demoted to a CI lint**.
- `impeccable` and any Go skills are **retained behind the ADR-0021 measured
  trial** (MEASUREMENT.md) — under measurement, not conviction.

Gate skills keep citing `implements_spec: 0.4.0`. The §02 gate contracts they
fulfil did not change under §17 — only their *fate* in the lifecycle did.
Blanket-bumping them would assert a contract advance that never happened; §09
puts the host's conformance citation on the trigger skill alone. (This diverges
from the opencode host, which bumped all of its gate skills. Recorded here as a
deliberate difference rather than drift.)

### gitnexus removed

Removed from every live surface: `.claude/skills/gitnexus/` (6 skills) and the
~29 MB `.gitnexus/` directory including its `lbug` binary. Historical records
are **retained** per §08 supersede-don't-delete — migration `0009` and
`validate-0009-anchor.sh` (whose gitnexus-led `AGENTS.md` fixtures still test
the §11 anchor rule), ADR-0010, the CHANGELOG entries, and `docs/briefs/`.

### Versions

- `implements_spec` **0.10.0 → 1.0.0** on the trigger skill.
- Workflow `version` and `.codex/workflow-version.txt` **0.9.0 → 1.0.0**.

### Scaffolder guardrail

This repo **keeps its own `.planning/` in place**. §19's Tier-0 move to
`docs/legacy-planning/` binds a *product* repo adopting the spec slot; this
repo's `.planning/` is its own development history, its migration tests read
fixtures out of it, and the core standard's own guardrail for this work was
"keep `.planning/` as backup". Recipe `0001` (planning → openspec) is vendored
for **target** repos and exposed through the update skill; it is not run against
this scaffolder.

## Alternatives considered

- **Drop the multi-AI review, rely on `openspec validate`.** Rejected.
  `validate` is a lint over structure; it reads no intent and no code. This is
  precisely the regression ADR-0018 exists to prevent.
- **Keep `plan-review` as a named gate alongside the change-gate.** Rejected —
  §17 forbids it, and two enforcement surfaces for one obligation is how a gate
  ends up half-enforced.
- **Point `.codex/hooks.json` directly at the gate**, as the core standard's
  wiring snippet shows. Rejected on evidence: it fails open on every codex
  `apply_patch`. The snippet is correct for hosts whose payload carries a path
  field; codex's does not.
- **Delete `check-plan-review.sh` and the 0.x producer path.** Rejected. One
  global skills directory serves every project on the machine, including
  projects that have not replayed `0013` yet. Their gate is still the 0.x
  verifier and their evidence artifact is still `<NN>-REVIEWS.md`. The renamed
  producer carries a 0.x fallback for exactly that window.

## Consequences

- The `.codex/hooks.json` retarget **cannot gate the session that applies it**.
  The pre-commit hook and CI cover that window — which is why the gate is a
  script with two agent-agnostic backstops rather than a hook alone.
- **An untrusted hook enforces nothing and looks installed.** codex-cli gates
  project hooks behind operator trust; an untrusted entry reports
  `Installed N / Active N-1 / Review 1`. Migration `0013` carries a required,
  non-automatable operator post-check for this, and `install.sh` prints it as
  ACTION REQUIRED. This is a repeat of `0011`'s second defect and is treated as
  a known failure mode, not a footnote.
- The `reviewer-cli.sh` shipped here is a **superset** of the opencode copy
  (adds `claude` and `opencode` vendor arms, keeps `gemini` and `codex`). Both
  install to the same global path; the superset is backward-compatible in that
  direction but not the reverse. Reconciling this into one fleet copy is
  outstanding work, tracked as fleet drift rather than left implicit.
- Removing gitnexus reclaims ~29 MB and deletes a live MCP dependency, at the
  cost of graph-based code lookup — an accepted trade, with provenance kept.
- The trial is **measured** (ADR-0021, MEASUREMENT.md). `impeccable` and any Go
  skills are retained on that basis; a sustained negative signal is grounds to
  revisit their retention and, if the measured cost outweighs the benefit, the
  scope of this adoption.
