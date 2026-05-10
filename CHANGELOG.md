# Changelog

All notable changes to `codex-workflow` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repo cites `implements_spec: <version>` against
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
in every shipped artifact's frontmatter.

## [Unreleased]

### Added

- Phase 0 — Repo bootstrap and Codex CLI research
  - README skeleton, MIT LICENSE, .gitignore, AGENTS.md placeholder
  - Trivial CI workflow (`.github/workflows/ci.yml`) that prints the phase
    name; replaced with real CI in Phase 7
  - Three ADRs documenting the five Phase 0 research findings:
    - `docs/decisions/0001-codex-skill-naming.md` — skill directory paths,
      naming convention, packaging choice (loose skills + `install.sh` for
      v0.1.0; plugin manifest deferred to v0.2.0)
    - `docs/decisions/0002-stage2-independent-reviewer-on-codex.md` — Stage 2
      reviewer is implemented via `codex exec` child process with optional
      `--model` override; cross-host review via Claude Code MCP deferred
    - `docs/decisions/0003-gsd-entry-points-as-prompts.md` — Codex has no
      native `prompts/` surface; GSD entry points ship as skills with
      `policy.allow_implicit_invocation: false` and `default_prompt` in
      `agents/openai.yaml`
  - `research-complete` tag marks the end of Phase 0

- Phase 1 — Trigger skill
  - `skills/agentic-apps-workflow/SKILL.md` authored against
    `agenticapps-workflow-core` v0.1.0
  - Frontmatter cites `implements_spec: 0.1.0` per spec/09 conformance
  - Four canonical-prose blocks reproduced verbatim and byte-match
    confirmed against `agenticapps-workflow-core/spec/`:
    - Step 0 — Commitment Ritual (spec/01)
    - Rationalization Table (spec/03)
    - 13 Red Flags (spec/04)
    - Pressure-Test Scenarios (spec/05)
  - Step 1 (4-row task-size table), Step 2 (GSD entry-point routing),
    Step 3 (15-gate binding table mapping every spec/02 gate to a
    `codex-*` skill), Step 4 (ADR capture pointers), Verification
    Check (5 host-specific bash snippets covering commitment block,
    TDD commit pairs, Stage 2 evidence, per-`must_have` evidence,
    and `implements_spec` currency)

- Phase 2 — 13 gate-fulfilling skills
  - Each skill cites `implements_spec: 0.1.0` and an `implements_gate`
    field naming the spec/02 gate(s) it satisfies. Codex's loader reads
    only `name` and `description`; the extension fields are ignored at
    load and read by conformance audits per ADR-0001 D6.
  - **Every-phase skills** — `codex-tdd` (RED + GREEN commit pair),
    `codex-verification` (refuses completion without `must_have`
    evidence per spec/06), `codex-spec-review` (Stage 1 of the
    two-stage review per spec/07), `codex-code-review` (Stage 2,
    spawns independent reviewer via `codex exec` per ADR-0002)
  - **Pre-phase + design** — `codex-brainstorming` (≥2 named
    alternatives for UI or architecture per spec/02), `codex-design-shotgun`
    (≥3 visual variants), `codex-design-critique` (impeccable-style
    7-dimension scoring + 24-anti-pattern scan per ADR-0011)
  - **Security + QA** — `codex-cso` (OWASP-aligned phase audit),
    `codex-qa` (dual-mode: per-task `ui-preview` + post-phase
    `qa`), `codex-impeccable-audit` (post-implementation visual
    audit, blocks branch close on Red findings per ADR-0011),
    `codex-database-sentinel-audit` (dual-mode: phase-scoped sub-gate
    + pre-launch full-surface, blocks on Critical/High per ADR-0012)
  - **Methodology + finishing** — `codex-systematic-debugging`
    (Observe → Hypothesize → Test → Conclude four-phase protocol;
    not bound to a spec gate, invoked by `$gsd-debug`),
    `codex-finishing-branch` (composes PR description from phase
    artifacts; opens PR via `gh`)

- Phase 3 — 5 GSD entry-point skills (per ADR-0003: skills, not prompts)
  - Each skill ships as `skills/gsd-<verb>/SKILL.md` plus
    `agents/openai.yaml` carrying
    `policy.allow_implicit_invocation: false` and a
    `default_prompt` that names the skill as `$gsd-<verb>` per the
    Codex `openai_yaml.md` reference's explicit-mention rule.
  - **`gsd-discuss-phase`** — surfaces open questions, writes
    `CONTEXT.md` with resolved decisions; routes to
    `codex-brainstorming` when a brainstorm gate fires
  - **`gsd-plan-phase`** — reads `CONTEXT.md`, decomposes into
    tasks with gate triggers and must_haves, authors `PLAN.md`
    plus `RESEARCH.md` / `UI-SPEC.md` as needed; pre-flight checks
    that every required `codex-*` skill is installed
  - **`gsd-execute-phase`** — heavyweight wave executor; emits
    commitment block per task, fires applicable spec/02 gates,
    refuses task completion without `codex-verification` evidence,
    runs the post-phase pipeline (spec-review → code-review →
    security/qa/audits) and finishes with `codex-finishing-branch`
  - **`gsd-quick`** — for tiny/small tasks; minimal commitment
    block + direct route to `codex-tdd` / `codex-verification` /
    `codex-finishing-branch`; refuses medium/large tasks and
    routes to `gsd-discuss-phase` instead
  - **`gsd-debug`** — thin user-facing entry that hands off to
    `codex-systematic-debugging` (the four-phase protocol)

### Pending

- Phases 4–7 — setup/update lifecycle, migration framework, install.sh,
  self-applied workflow, v0.1.0 release
