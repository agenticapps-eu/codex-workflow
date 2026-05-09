# ADR-0002 — Stage 2 independent reviewer mechanism on Codex

- Status: Accepted
- Date: 2026-05-09
- Phase: 0 (research)
- Implements (eventual) spec: `agenticapps-workflow-core` v0.1.0 (spec/07)
- Supersedes: —
- Superseded by: —

## Context

`agenticapps-workflow-core/spec/07-two-stage-review.md` requires a
two-stage review:

- **Stage 1** — spec review by the same agent that wrote the work,
  pre-implementation. Confirms the plan matches the spec.
- **Stage 2** — code review post-implementation, by an *independent*
  reviewer. The independence requirement exists so the reviewer hasn't
  been primed by the implementation reasoning, the bug hypotheses, or
  the rationalizations that may have crept in during the work.

On Claude Code the answer is straightforward: spawn a `Task` subagent
with a fresh context. On Codex CLI 0.130.0 the answer is less obvious,
because Codex doesn't expose a `Task`-style subagent tool to the
running model. The `skill-creator` system skill nevertheless references
"launch subagents as a way to stress test the skill" — meaning the
mechanism exists, just under a different name and surface.

This ADR picks one mechanism for v0.1.0 and documents the alternatives
considered.

## Options considered

### Option A — `codex exec` child process with a different system prompt

Spawn a `codex exec` subprocess from inside the Stage 2 reviewer skill,
passing a tightly-scoped prompt that carries: (1) the diff, (2) the
plan, (3) the spec citation, (4) explicit reviewer-mode framing. The
child process gets a fresh conversation history and can run on a
different model via `--model gpt-5.4` (or any other).

Pros:

- Same machine, same tooling — no MCP overhead.
- Genuinely independent context: the child has no memory of the
  implementing session's reasoning.
- Model override (`--model`) lets Donald run cross-model review
  trivially (e.g., `gpt-5.4` for implementation, `gpt-5.3` for review)
  to break correlated blind spots.
- Output is machine-parseable (stdout) so the parent skill can ingest
  the review and either pass it to the user or write it to
  `REVIEW.md` Stage 2 section.

Cons:

- Requires `codex exec` to be on `PATH` inside the parent session's
  shell. Verified present at `/opt/homebrew/bin/codex` on Donald's
  setup; the install.sh in Phase 5 will hard-fail if `codex` is
  unavailable.
- The child runs with whatever sandbox policy the parent passes (or
  the global default). For review-only work — read code, write a
  REVIEW.md file — the read+write minimal sandbox is sufficient and
  aligns with Codex's `sandbox` subcommand defaults.
- Same model family means correlated blind spots if Donald doesn't
  pass `--model` for cross-model review. Documented as a known
  limitation.

### Option B — Cross-host review via Claude Code MCP

Register Claude Code as an MCP server (or have Claude Code register
itself as one). The Codex Stage 2 reviewer asks Claude Code, via MCP,
to run a focused review pass.

Pros:

- True cross-model independence (Sonnet/Opus reviewing GPT-5.4
  output).
- Genuinely separate process, separate authentication, separate
  rate-limit pool.

Cons:

- Requires Claude Code installed locally — extra dependency the
  scaffolder can't assume.
- MCP plumbing is more brittle than `codex exec`; if the MCP server
  hiccups, Stage 2 fails silently or with a confusing error.
- Adds a per-installation setup step (register Claude Code as MCP)
  that the scaffolder's `setup-codex-agenticapps-workflow` skill
  would have to handle.

### Option C — Wait for Codex to ship a native subagent / `Task` tool

The `skill-creator` system skill references subagents but doesn't
expose how a running skill should *invoke* one programmatically. It's
plausible Codex will ship a native subagent surface in a future
version.

Pros:

- Zero-overhead, fully integrated.

Cons:

- Speculative. v0.1.0 needs to ship now, on the Codex version Donald
  has installed (0.130.0). Waiting blocks the entire scaffolder.

## Decision

**Pick Option A — `codex exec` child process — for v0.1.0.**

The Phase 2 `codex-code-review` skill body specifies the Stage 2 step
as something close to:

```
Run an independent reviewer in a child Codex process:

  codex exec \
    --model "${REVIEWER_MODEL:-gpt-5.4}" \
    --skip-git-repo-check \
    --sandbox read-only \
    "$(cat <<'PROMPT'
You are running a Stage 2 code review. You have not seen the
implementing session's reasoning. Read the plan at PLAN.md, the
diff at HEAD, and the spec citation provided. Produce a REVIEW.md
Stage 2 section listing: (a) what the diff does, (b) whether it
matches the plan, (c) discrepancies between diff and plan, (d) any
spec violations you can detect from the cited spec section, (e)
verification commands the user should run.
PROMPT
)"
```

(Exact flag set confirmed during Phase 2 authoring, since `codex exec`
flag surface may evolve between 0.130.0 and the implementation date.)

## Consequences

- **Cross-model review is opt-in via `REVIEWER_MODEL` env var.** Default
  is the same model as the parent session. The skill body documents
  this and recommends overriding when the work is novel or
  high-stakes.
- **Stage 2 cannot run if `codex` is missing from PATH.** The skill
  body MUST detect this and fall back to a clear "manual Stage 2
  required" message — not silently skip the gate, which would violate
  the discipline contract the scaffolder is supposed to enforce.
- **Stage 2 cannot run on machines with rate-limit pressure.** Two
  Codex sessions in flight simultaneously share Donald's rate-limit
  pool. The skill body documents this and recommends running Stage 2
  immediately after Stage 1 when the parent session is otherwise
  idle.
- **MCP-based cross-host review (Option B) is deferred to v0.2.0**, at
  which point the codex-code-review skill body will document both
  paths and let Donald pick per project (env var or skill argument).

## Verification

- `codex exec --help` confirms `--model`, `--sandbox`, `-s`, and
  `--skip-git-repo-check` (last verified during Phase 0; flag surface
  re-checked in Phase 2 before authoring the skill body).
- `~/.codex/skills/.system/skill-creator/SKILL.md` lines 50–55 and
  386–415 document the subagent / forward-testing pattern that this
  ADR generalizes from "validation" to "Stage 2 review."

## Open follow-ups

- **F1** — Phase 2 will write the actual `codex exec` invocation. If
  flag surface changed between 0.130.0 and the authoring date, this
  ADR's Decision section gets a one-line update referencing the new
  flags; the choice (Option A) does not change.
- **F2** — Track v0.2.0 work to add MCP-based cross-host review as a
  documented alternative, with `setup-codex-agenticapps-workflow`
  asking the user whether to register Claude Code as an MCP server
  during install.
