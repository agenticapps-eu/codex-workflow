# The AgenticApps workflow on Codex (v1.0.0)

The short version: **OpenSpec owns what is true, Superpowers owns how you
build, Linear owns what is next.** Nothing overlaps, and each of the three is
replaceable without touching the others.

This document is the explainer `AGENTS.md` points at. The *procedures* live in
the `agentic-apps-workflow` trigger skill (loaded lazily, on code-touching
turns); this file is the map.

## The three slots

`openspec/` is the spec slot. It holds three kinds of content with three
different lifespans:

| Slot | Holds | Lifespan |
|---|---|---|
| `openspec/specs/<capability>/spec.md` | what the shipping product guarantees **right now** | durable |
| `openspec/changes/<slug>/` | an in-flight proposal to add / modify / remove requirements | transient |
| `openspec/changes/archive/<date>-<slug>/` | a shipped change, kept as the record of *how* a requirement came to be | immutable |

A reader asking "what does this system do today?" reads `specs/` **only**.
A capability is a product surface (`analysis-pipeline`, `role-based-access`),
not a single unit of work — related work merges into one capability rather than
mirroring one change to one spec.

## The loop

```
1 · propose  →  2 · validate  →  3 · execute  →  4 · archive  →  ship
```

| Stage | What happens | Entry point |
|---|---|---|
| **1 · propose** | Open a change and author `proposal.md`, `design.md`, the spec delta, and `tasks.md`. Brainstorming feeds the design note for UI or new architecture. | `$openspec-propose` (or `openspec new change <slug>`) |
| **2 · validate** | `openspec validate --all` must be GREEN **and** the change must carry independent multi-AI review — **before any code is written**. | `openspec validate --all`, then `codex-openspec-change-review` |
| **3 · execute** | Implement the tasks under the retained execution gates: TDD, verification evidence, independent code review, plus whatever the change's surface triggers. | `$openspec-apply-change` + `superpowers:*` |
| **4 · archive** | Fold the delta into `specs/` so the spec slot states the new truth, then archive the change. | `$openspec-sync-specs` → `$openspec-archive-change` |
| **ship** | Commit, PR, changelog. | `superpowers:finishing-a-development-branch` |

**`archive ≠ ship`.** Archiving folds the delta and moves the change directory
and produces **no git commit**. Shipping is the separate VCS act with its own
gate. Collapsing the two is a spec violation, not a shortcut.

## Stage 2 is the one with teeth

Stage 2 is only real if something enforces it. The **change-gate** blocks every
code edit while an active change is unvalidated or unreviewed:

> **allow** only when `openspec validate --all` is green **AND** the active
> change carries `REVIEWS.md` with **≥ 2** `## Reviewer:` headings.

| Situation | Decision |
|---|---|
| No active change | allow — out-of-change edits are permitted |
| The edit targets `openspec/**` | allow — you must be able to author the change while gated |
| Active change, validate RED | **block** |
| Active change, validate green, `REVIEWS.md` absent or < 2 reviewers | **block** |
| Active change, validate green, ≥ 2 reviewers | allow |
| `GSD_SKIP_REVIEWS=1` | allow — documented, **logged** override |
| Unparseable input | allow — fail-open on *parse* error only, never on policy |

One script owns that table: `bin/openspec-change-gate.sh`. Since 1.1.0 it is
**vendored byte-identical from `agenticapps-workflow-core`** and never edited
here — a host-local fix is how five divergent copies ended up on one machine,
none conformant (ADR-0012). Behaviour changes go to core with a matching
conformance-harness row, then we re-vendor. It is wired at three surfaces:

1. **`.codex/hooks.json`** — a `PreToolUse` hook on `apply_patch`, via
   `hook-wrapper-openspec-gate.sh`. Fastest feedback. **Hook mode.**
2. **`.git/hooks/pre-commit`** — catches any agent, and humans. **`--pre-commit`.**
3. **`.github/workflows/openspec-gate.yml`** — catches everything else. **`--ci`.**

2 and 3 are the *guarantee*; 1 is a convenience on top. A `PreToolUse` hook is
loaded at session start and **cannot gate the session that installed it**, so
an agent-level hook alone would leave a hole exactly when the workflow is being
adopted.

Three things about that wiring are easy to assume wrongly:

- **`--ci` is whole-repo, not diff-scoped.** Any active change lacking two
  reviewers fails the build *even if the pull request did not touch it*. So a
  docs-only PR can go red, and a proposal-only PR is red until its `REVIEWS.md`
  lands. That is the rule working: reviews come before code, so the red window
  is the window in which the change is genuinely not ready to merge.
- **Each surface resolves a different copy, deliberately.** CI uses the
  repo-local vendored gate — the one it just scored with the harness, since a
  runner has no `~/.agenticapps/bin/` and enforcing with an unscored copy would
  defeat the check. The two local surfaces prefer the shared install, so one
  machine-wide upgrade reaches every repo.
- **The shared copy is trusted only if it carries a `# gate-version:` marker.**
  All four hosts write that one path and only this one arbitrates so far, so a
  sibling can blind-write its unmarked pre-canonical copy over it. Without the
  marker check, shared-first resolution would run your floors on the gate this
  workflow replaced. `install.sh` refuses to downgrade the shared path for the
  same reason.

The gate's conformance is **executed, not claimed**: CI runs
`tools/change-gate-conformance.sh` against the vendored gate before trusting its
verdict, and every declared row must pass. The bar is zero failures rather than
a fixed count, so a re-vendored harness with more rows raises it automatically.

### Two codex specifics that are easy to get wrong

- **The wrapper is load-bearing.** codex's `apply_patch` payload carries the
  edited path *inside the patch blob* (`tool_input.command`), not in a
  `file_path` field. Wire `hooks.json` straight at the gate and the gate parses
  no path, fails open by design, and silently allows every edit. The wrapper
  translates the payload — and translates a block into
  `permissionDecision: deny` JSON, because a codex hook that emits invalid
  stdout also fails open and runs the tool anyway.
- **An installed hook is not an enforcing hook.** codex-cli requires the
  operator to *trust* a project hook. An untrusted entry reports
  `Installed N / Active N-1 / Review 1` and enforces nothing while looking
  installed. Check `/hooks` after wiring. The entry must also use the nested
  `{"matcher", "hooks":[{"type","command"}]}` shape — the flat form is dropped
  with no error and no warning.

## Why the multi-AI review survived

`openspec validate` is a **lint**: it checks the delta's structure against the
spec slot. It reads no intent, and no code. Dropping the adversarial review
because "validate is green" would re-open the failure ADR-0018 was written
about — a project that silently skipped its review for eight consecutive units
of work with nothing ever catching it.

So the review is kept, and retargeted: reviewers now critique the **change**
(proposal + spec delta) instead of a phase plan. In the pilot this caught a real
semantic defect in a spec delta *before a line of code existed*.

What changed is its *shape*. Spec §17 forbids a standalone `plan-review` gate
under 1.0.0, so the review is not a named gate — it is the **precondition the
change-gate checks**. Same adversarial mechanism, one fewer moving part.
`codex-openspec-change-review` produces the evidence; the gate enforces it.

Reviewers are ≥ 2 **distinct external vendors** — `claude`, `gemini`,
`opencode`. `codex` is never a reviewer here: a host does not review its own
change. Each runs through `reviewer-cli.sh`, which pins stdin to `/dev/null`
and bounds the run with a timeout (a reviewer CLI that hangs must not be able to
stall an edit). Nothing is transmitted to any vendor until the operator has
confirmed an explicit file manifest — and that manifest is advisory: it says
what we *intend* to send, not what an agentic reviewer CLI *will* read.

## The two reviews — do not conflate them

1. **Change review** (stage 2, this repo's `codex-openspec-change-review`) —
   reviews the *proposal and spec delta*, **before** code.
2. **Code review** (stage 3, `superpowers:requesting-code-review`) — reviews the
   *implementation diff* in an independent context, before archive.

Different failures, different agents, different inputs. Producing one never
discharges the other.

## Gate mapping at a glance

| §02 gate | Fate at 1.0.0 |
|---|---|
| `spec-review` | **collapsed** → `openspec validate --all` |
| `plan-review` | **collapsed** → the change-gate predicate (the review itself is kept) |
| `code-review`, `tdd`, `verification`, `security`, `branch-close` | **retained** |
| `brainstorm-*`, `design-*`, `impeccable-audit`, `ui-preview`, `qa`, `database-security`, `db-pre-launch-audit` | **conditional** — fire on their trigger |
| `ts-declare` (§13) | **demoted to a CI lint** |

`security` (`codex-cso`) is never conditional-away in a repo that ships product
code. `impeccable` and any Go skills are retained on the ADR-0021 **measured
trial** — under measurement, not conviction; a sustained negative signal is
grounds to revisit them.

The authoritative per-gate bindings live in the trigger skill (Step 3) and in
`.planning/config.codex.json`.

## Where prose belongs

Ask one question: **is this a product guarantee, or a way of working?**

- A **product guarantee** — something a user or downstream system relies on,
  that would be a bug if violated → `openspec/specs/<capability>/spec.md`.
- A **way of working** — a convention invisible to users (use TDD, run the
  security gate on auth changes) → `AGENTS.md`, subject to §12's economy rule.
- A **record of past effort** → history. On a migrated project the retained
  `.planning/` tree moves to `docs/legacy-planning/` — moved, never deleted.

This scaffolder keeps its own `.planning/` where it is: it is this repo's
development history, its migration tests read fixtures out of it, and the core
standard's guardrail is to keep it as backup.

## Linear coupling is loose, on purpose

A change **should** reference its Linear issue ID (in `proposal.md`, the slug,
or the ship commit) so a shipped requirement traces back to its roadmap item.
There is no sync, and none is required: not every change needs an issue, not
every issue needs a change, and state does not mirror. A missing reference is at
most a SHOULD gap.

## Adopting this in an existing project

`$setup-codex-agenticapps-workflow` (fresh) or
`$update-codex-agenticapps-workflow` (installed) scaffolds the slot, installs
the gate at all three surfaces, and lays down the collapsed gate set. A project
with existing `.planning/` history also runs the planning→openspec recipe, which
reconstructs `specs/` by **merging** related phases into coherent capabilities —
one-phase-one-spec would just recreate `.planning/`'s fragmentation inside
`specs/`.

## References

- Core spec §16 (spec slot), §17 (lifecycle & gate mapping), §18 (change-gate),
  §19 (placement & Linear) — `agenticapps-workflow-core`.
- [ADR-0011](decisions/0011-openspec-superpowers-adoption.md) — this host's
  adoption decision.
- [ADR-0009](decisions/0009-plan-review-gate.md) — the 0.x plan-review gate this
  supersedes.
- [`docs/BINDING.md`](BINDING.md) — how upstreams are bound rather than re-ported.
- [`docs/ENFORCEMENT-PLAN.md`](ENFORCEMENT-PLAN.md) — which gates cannot fire in
  this repo, and why.
