# Phase 8: Plan-Review Gate - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 8-Plan-Review Gate
**Areas discussed:** Verifier invocation point, Block response behavior, REVIEWS.md schema, Reviewer prompt scope

---

## Pre-discussion (brainstorming session, same day)

These were settled before `/gsd-discuss-phase` ran and were carried forward, not re-asked.

### Enforcement mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: declarative + verifier script | Binding in `config.codex.json` + `check-plan-review.sh` implementing resolver + grandfather | ✓ |
| Declarative only | Binding + skill + ritual text, no script | |
| Native Codex PreToolUse hook | Port the reference into `~/.codex/hooks.json` | |

**User's choice:** Hybrid
**Notes:** Native hook rejected for this phase on three grounds — `hooks.json` is global so it fires in every repo, the sha256 trust ledger forces a re-grant on every migration edit, and it introduces a second mechanism beside the declarative map all 15 gates use. Recorded as the documented upgrade path instead.

### Legacy layout handling

| Option | Description | Selected |
|--------|-------------|----------|
| Support both; grandfather legacy wholesale | Resolver globs both layouts; legacy always allowed | ✓ |
| GSD-native only; legacy falls to fail-open | Simplest, spec-literal, but inert in this repo | |
| Also migrate this repo's `.planning` to GSD-native | Fixes ADR-0007 p4, roughly doubles scope | |

**User's choice:** Support both; grandfather legacy wholesale
**Notes:** Matches the grandfather rule's stated intent — never retroactively block work in repos that shipped phases before the gate functioned.

### Reviewer composition

| Option | Description | Selected |
|--------|-------------|----------|
| Vendor-diverse external CLIs | `claude`/`gemini`/`opencode`, excluding `codex` | ✓ |
| `codex exec` children on distinct models | Mirrors ADR-0002 Stage 2, but same vendor — "external" contested | |
| Prefer external, fall back to `codex exec` | Always satisfiable; guarantee varies per machine | |

**User's choice:** Vendor-diverse external CLIs
**Notes:** Accepts a soft dependency on other vendors' CLIs, bounded by the escape hatches.

---

## Verifier invocation point

| Option | Description | Selected |
|--------|-------------|----------|
| AGENTS.md ritual text + trigger skill | Always-loaded surface; fires before first code-touching edit; matches the §15 precedent | ✓ |
| Ritual text + git pre-commit backstop | Adds an unrationalizable backstop; new per-repo install surface; fires later than spec | |
| `codex-plan-review` skill self-checks | No new surface, but circular — cannot catch an agent that skips review entirely | |

**User's choice:** AGENTS.md ritual text + trigger skill
**Notes:** `gsd-execute-plan` was ruled out before the question was asked — the GSD rituals are upstream prompts this repo does not own, the same constraint migration 0007 hit for §15. Accepted trade-off: enforcement still rests on agent compliance.

---

## Block response behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Hard stop, name the remedy | Print block message + remedy + both escape hatches, then stop | ✓ |
| Stop, then offer to run it | One consent prompt; but prompts in non-interactive `codex exec` / CI runs | |
| Auto-run review, then continue | Unconsented egress to two vendors; gate never actually stops anything | |

**User's choice:** Hard stop, name the remedy
**Notes:** Auto-running was weighted against explicitly because `codex-plan-review` ships plan content to other vendors' CLIs — that is external egress and should not happen on the agent's initiative.

---

## REVIEWS.md schema

| Option | Description | Selected |
|--------|-------------|----------|
| Adopt family schema; count reviewers, fall back to line check | Parse `reviewers:` frontmatter, block if <2; fall back to ≥5 lines when absent | ✓ |
| Adopt family schema; keep verifier loose | Existence + ≥5 lines only, exactly as the brief said | |
| Codex-native schema | Breaks codex+claude cross-host reading for no identified gain | |

**User's choice:** Adopt family schema; count reviewers, fall back to line check
**Notes:** This **supersedes** the loose-verifier decision in `docs/briefs/plan-review-gate.md`. Discovering a real REVIEWS.md in `agenticapps-dashboard` showed the `reviewers: []` frontmatter is a family-wide convention, not one producer's format — which invalidated the coupling objection the brief used to justify the loose check. The same file also revealed GSD's existing host self-skip convention (`CLAUDE_CODE_ENTRYPOINT=cli`), independently validating the earlier "exclude codex" choice.

---

## Reviewer prompt scope

| Option | Description | Selected |
|--------|-------------|----------|
| CONTEXT + plans + canonical refs | Adds ROADMAP-resolved refs so reviewers can check the plan against the spec it cites | ✓ |
| CONTEXT + plans only | Exactly the `/gsd-review` precedent; reviewers take the plan's word on spec claims | |
| Plans only | Reviewers lose rationale, re-litigate locked decisions | |

**User's choice:** CONTEXT + plans + canonical refs
**Notes:** Framing is explicitly adversarial. Accepted cost: larger prompt (the dashboard precedent ran ~250 KB).

---

## Claude's Discretion

- Codex self-skip detection mechanism (the env var analogous to `CLAUDE_CODE_ENTRYPOINT`).
- Exact verifier install path and symlink shape.
- Verifier behavior in `codex exec` / non-interactive contexts.

## Deferred Ideas

- Native `~/.codex/hooks.json` PreToolUse enforcement — own phase.
- §14 prompt-injection defense — applicability unadjudicated; `injection-guard` already Codex-installable.
- `implements_spec` 0.4.0 → 0.5.0 — needs the full audit the field represents.
- Migrate `.planning/phases/` 00–07 to GSD-native layout — closes ADR-0007 p4.
- Upstream bug report to `claude-workflow` — resolver step 2 greps `## Current Phase`; no STATE.md uses it.
- Upstream bug report to `agenticapps-workflow-core` — `spec/09:61` says 15 gates, `spec/02` defines 16; stale registry row for this host.
