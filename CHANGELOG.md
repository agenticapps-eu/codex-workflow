# Changelog

All notable changes to `codex-workflow` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repo cites `implements_spec: <version>` against
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
in every shipped artifact's frontmatter.

## [Unreleased]

### Pending

- v0.1.1 / v0.2.0 follow-ups
  - Restructure `install.sh` symlink mode so it does not write a
    secondary symlink inside the source tree (move templates into
    `skills/setup-codex-agenticapps-workflow/templates/` permanently;
    drop the secondary symlink step). See
    `docs/dogfood-2026-05-10.md`.
  - Empirical confirmation of `policy.allow_implicit_invocation: false`
    on the five GSD entry-point skills (the Codex loader respects the
    flag, but a fresh-session test has not yet run).
  - Empirical confirmation of AGENTS.md root-down concat depth on
    Codex 0.130.0 (per ADR-0001 appendix A2).
  - Plugin packaging — re-evaluate after Donald uses codex-workflow
    in the wild for a few cycles (per ADR-0001 F2).
  - Cross-host Stage 2 review via Claude Code MCP (per ADR-0002
    Option B; v0.1.0 ships `codex exec` only).

## [0.1.0] — 2026-05-10

Initial release. Full-conformance Codex CLI host implementation of
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
v0.1.0. Sibling of [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow)
and [`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow).

### Inventory

- 1 trigger skill — `agentic-apps-workflow` (canonical-prose blocks
  byte-matched against spec/01, /03, /04, /05)
- 13 gate-fulfilling skills — every spec/02 gate has a binding
- 5 GSD entry-point skills — explicit-only via
  `policy.allow_implicit_invocation: false`
- 2 lifecycle skills — `setup-codex-agenticapps-workflow`,
  `update-codex-agenticapps-workflow`
- 5 project-side templates
- Migration framework — `0000-baseline.md`, `run-tests.sh`,
  `test-fixtures/`, `README.md` (implements
  spec/08-migration-format.md)
- `install.sh` — symlinks skills into `$CODEX_HOME/skills/`
- 3 architecture decision records
- `docs/ENFORCEMENT-PLAN.md` documenting `full` conformance with
  Spec Deltas for gates whose triggers cannot occur on a UI-less
  DB-less scaffolder (per spec/09)
- `docs/dogfood-2026-05-10.md` — Phase 6 self-apply log

### Phase-by-phase

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

- Phases 4 + 5 — Lifecycle skills, migration framework, templates, install.sh
  - **Templates** at `templates/` — five project-side artifacts that
    setup copies into a fresh project:
    - `agents-md-additions.md` — workflow sections for project AGENTS.md
    - `workflow-config.md` — project-specific config with
      `{{PLACEHOLDERS}}` (project name / repo / client / budget /
      backend / frontend / database / LLM / quality bars / etc.)
    - `config-hooks.json` — `.planning/config.json` template binding
      every spec/02 gate to its `codex-*` skill
    - `adr-db-security-acceptance.md` — ADR template for accepting
      database-sentinel Critical/High findings (per ADR-0012)
    - `global-agents-additions.md` — optional `~/.codex/AGENTS.md`
      append for Option A install
  - **Migration framework** at `migrations/` — implements the
    declarative contract from
    `agenticapps-workflow-core/spec/08-migration-format.md`:
    - `README.md` — host-side manifestation of the migration format
      contract, with Codex paths
    - `0000-baseline.md` — six-step baseline migration (project
      workflow-config, .planning/config.json, AGENTS.md sections,
      docs/decisions/README.md, .codex/workflow-version.txt, optional
      global AGENTS.md additions)
    - `run-tests.sh` — fixture-based test harness; SKIPs the
      interactive-only baseline; runs repo layout sanity checks
    - `test-fixtures/README.md` — fixture contract (extract from git
      refs rather than static fixture files)
  - **Lifecycle skills** at `skills/`:
    - `setup-codex-agenticapps-workflow` — apply baseline migration
      to a fresh project; pre-flights Codex CLI + scaffolder install;
      gathers placeholder values; refuses to re-run on installed
      project
    - `update-codex-agenticapps-workflow` — apply pending migrations
      between project's recorded version and scaffolder version;
      supports `--dry-run`, `--migration NNNN`, `--from VERSION`
  - **`install.sh`** — symlinks every `skills/<name>/` into
    `$CODEX_HOME/skills/<name>/` (default `~/.codex/skills/`) plus a
    `templates/` symlink so migration apply steps can `cp` from a
    stable scaffolder path; idempotent; refuses to clobber non-symlink
    directories; `--copy` and `--dry-run` flags

- Phase 6 — Self-applied workflow + dogfood
  - **Real `bash install.sh`** run against `~/.codex/skills/`. 22
    entries created (21 skill symlinks + 1 templates symlink).
    Idempotent re-run confirms 0 installed / 22 skipped.
  - **AGENTS.md populated** — placeholder replaced with the
    populated structure (Development Workflow, Workflow Enforcement
    Hooks table marking which gates apply to the scaffolder vs which
    don't, Skill routing, Session handoff)
  - **`.planning/config.json`** seeded from
    `templates/config-hooks.json`
  - **`.codex/workflow-config.md`** authored with substituted values
    for codex-workflow's own metadata (project = codex-workflow,
    no UI, no DB, no dev server — gates whose triggers can't fire
    are documented as Spec Deltas in ENFORCEMENT-PLAN, NOT a
    `partial` conformance claim per spec/09)
  - **`.codex/workflow-version.txt`** = `0.1.0` (the durable record
    that `update-codex-agenticapps-workflow` will read on future
    upgrades)
  - **`docs/decisions/README.md`** — index of the three Phase 0 ADRs
  - **`docs/ENFORCEMENT-PLAN.md`** — gate-to-skill bindings for
    codex-workflow's own development; explicitly enumerates the 8
    gates that don't fire on this scaffolder (with rationale per
    spec/09); claims `full` conformance
  - **`docs/dogfood-2026-05-10.md`** — log of the Phase 6 self-apply
    plus a walk-through of a `$gsd-quick` micro-cycle (the README
    refresh that's part of this PR); records the open follow-ups
    for the AGENTS.md root-down concat verification and the
    `policy.allow_implicit_invocation: false` empirical check
  - **README refresh** (the dogfood micro-cycle) — Status, What
    ships, Layout, and Install sections updated to reflect the
    actual shipped state

- Phase 7 — Release
  - This CHANGELOG entry; final README pass
  - `v0.1.0` git tag
  - Repo flipped from private to public
  - Sibling PR against `agenticapps-workflow-core` updating the
    `reference-implementations/README.md` codex-workflow row from
    "repo not yet created" to "v0.1.0 shipped, full-conformance"
  - Follow-up issue opened against `agenticapps-dashboard` for
    Codex host detection in HostAdapter
