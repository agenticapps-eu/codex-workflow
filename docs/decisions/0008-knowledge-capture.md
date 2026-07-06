# ADR-0008: Knowledge capture ritual tail — spec §15 on the Codex host

**Status**: Accepted  **Date**: 2026-07-06  **Linear**: —
**Core contract**: `agenticapps-workflow-core/spec/15-knowledge-capture.md` (v0.7.0), core ADR-0017
**Sibling host**: claude-workflow ADR-0038 (reference implementation)

## Context

Core ADR-0017 added spec §15: every host writes 1–5 distilled, transferable
learnings to **one Obsidian note per repo**
(`~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/<repo-name>.md`)
at three ritual boundaries — session handoff, plan completion, phase
completion. Today those learnings die where they were made: `.codex/session-handoff.md`
is overwritten by the next session, and ADRs/CHANGELOGs capture repo-scoped
facts by design. Nothing carries a root cause from `fx-signal-agent` to an
agent in `cparx`, or a Codex insight to a Claude session in the same tree.

claude-workflow is the reference host and shipped §15 first (ADR-0038). Core
ADR-0017's downstream note obliges `codex-workflow` and `opencode-workflow` to
mirror it **in their own idiom**. Two forces make the Codex mirror non-trivial:

1. **Codex is a thin binding, not a re-port** (ADR-0007). The three rituals are
   driven by upstream GSD prompts (`/prompts:gsd-plan-phase`,
   `/prompts:gsd-execute-plan`) and the session-handoff instruction in
   `AGENTS.md` — none of which this repo can edit. The capture step therefore
   has to live on this repo's *own* always-loaded surfaces.
2. **Codex reads `AGENTS.md` root-down and loads skills on match.** The reliable
   home for a ritual tail that must fire on a plain session-handoff turn (which
   may not match the trigger skill) is the project `AGENTS.md`, with the trigger
   `SKILL.md` mirroring it for code-task turns.

## Decision

1. **Wiring is a prose section on two surfaces, not a hook.** A
   `## Knowledge Capture — Ritual Tail (spec §15)` section is added to (a) the
   trigger `skills/agentic-apps-workflow/SKILL.md` and (b) the project
   `AGENTS.md` (via the `agents-md-additions.md` template, and this repo's own
   `AGENTS.md` for self-application). §15 permits any mechanism; a prose step
   keeps the selectivity bar — an LLM judgment call — where an LLM executes it,
   needs no new runtime, and survives Codex's AGENTS.md concat model. The
   section embeds the note skeleton path and the exact skip conditions so it is
   mechanical enough for a lower-capability host to follow verbatim.
2. **Destination is config-routed, in the *shared* `.planning/config.json`.**
   Codex namespaced its *hooks* to `.planning/config.codex.json` (migration
   0005, standard §4) so a codex + claude pair can share a working tree. The
   `knowledge_capture` block is the deliberate opposite: it is **host-neutral**
   and lives in `.planning/config.json`, which claude writes too. The vault note
   is one-per-repo, shared across hosts (its `hosts:` frontmatter lists
   `[claude, codex, …]`); the two hosts must resolve the *same* destination and
   differ only by the `(codex)` / `(claude)` tag in the Log heading. Putting the
   block in a host-specific file would fork the destination and risk drift —
   exactly what the workflow-testbed dual-host finding warns against.
3. **Graceful skip (spec §15.3).** Block absent, `enabled: false`, or the vault
   parent folder missing → skip with at most one info line, never create the
   folder, never fail the ritual. The vault write is never committed.
4. **Existing installs: migration 0007** (0.4.0 → 0.5.0). Step 1 seeds the block
   into `.planning/config.json` as a `. + {knowledge_capture}` merge that
   preserves every existing key (a claude co-install's hooks stay intact) and is
   skipped when the block already exists (a claude-written block left verbatim).
   Step 2 inserts the section into `AGENTS.md` by **extracting it from the
   scaffolder's `agents-md-additions.md` template** — single source of truth, so
   a migrated install is byte-identical to a fresh one.
5. **Fresh installs: the migration chain.** Codex ships no snapshot; the setup
   skill applies the full chain (0000 → 0007). The section rides in the
   `agents-md-additions.md` template (appended by 0000-baseline Step 3) and 0007
   seeds `.planning/config.json`. Idempotency guards make the fresh path a no-op
   for Step 2 (section already present from the template).

## Alternatives Rejected

- **A Stop/PostToolUse-style hook.** Codex's thin binding has no such hook
  surface this repo owns, and the selectivity bar + Key-Learnings curation are
  judgment calls a shell hook cannot make. Spec §15 non-requirements bless a
  prose step.
- **Putting `knowledge_capture` in `.planning/config.codex.json`.** Forks the
  destination between hosts, breaks the "both hosts read the same block"
  guarantee, and contradicts spec §15.2's literal `.planning/config.json`.
- **Hardcoding the vault path in the skill.** Violates repo self-containment and
  breaks every machine that is not the operator's workstation — the exact reason
  core ADR-0017 made the path per-repo config.
- **Duplicating the section text inside migration 0007.** A self-contained
  heredoc drifts the moment the template changes; extraction from the scaffolder
  template keeps one canonical copy.

## Consequences

- v0.5.0 (minor, additive). The fleet reaches it via
  `$update-codex-agenticapps-workflow` (migration 0007); fresh installs get it
  from the chain. Repos opt out per-repo (`enabled: false`) or per-machine (no
  vault folder) without touching code.
- The vault-side `CLAUDE.md` in the learnings folder stays authoritative for the
  note format; the skill/AGENTS.md section and
  `templates/obsidian-learnings-note.md` mirror it and must be patched if it
  changes (the sync obligation core §15.4 documents).
- `implements_spec` in the skill frontmatter stays at `0.4.0`: it tracks the
  last full-conformance audit; §15 wiring is real either way, and bumping the
  citation to 0.7.0 requires auditing the §§ added in 0.5.0/0.6.0 — out of scope
  here.
- Drift coupling: migration 0007's `to_version` (0.5.0) is the drift target;
  the trigger skill `version:` is bumped to 0.5.0 in lockstep (`run-tests.sh`
  `test_drift`).
