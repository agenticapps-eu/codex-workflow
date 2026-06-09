# ADR-0001 — Codex skill naming, layout, and packaging

- Status: Accepted
- Date: 2026-05-09
- Phase: 0 (research)
- Implements (eventual) spec: `agenticapps-workflow-core` v0.1.0
- Supersedes: —
- Superseded by: —

## Context

`codex-workflow` is the Codex CLI peer of `claude-workflow` and
`pi-agentic-apps-workflow`. Phase 0's first research question is the basic
shape of a Codex skill on disk: where it lives, what its frontmatter looks
like, what naming convention this scaffolder repo should adopt for the
trigger skill, the gate-fulfilling skills, and the lifecycle skills.

Verified against `codex-cli 0.130.0` and the canonical reference skills
preinstalled at `~/.codex/skills/.system/` — specifically `skill-creator`,
`skill-installer`, and `plugin-creator`.

## Findings

1. **Skills directory.** Codex auto-discovers user skills from
   `$CODEX_HOME/skills/` (default `~/.codex/skills/`). Each skill is a
   directory whose name matches the skill's frontmatter `name`. The system
   skills under `.system/` are preinstalled and immutable.

2. **SKILL.md is the only required file.** Frontmatter requires `name` and
   `description` — these are the two fields Codex reads to decide when a
   skill triggers. Optional bundled resources sit alongside in
   `scripts/`, `references/`, `assets/`, plus `agents/openai.yaml` for UI
   metadata. Everything else (README, INSTALLATION_GUIDE, CHANGELOG inside
   a skill folder) is explicitly discouraged by `skill-creator`.

3. **Naming rules** (from `skill-creator/SKILL.md`):
   - lower-case, digits, hyphens only; under 64 chars
   - prefer short verb-led phrases
   - namespace by tool when it improves clarity (e.g. `gh-address-comments`)
   - the skill folder name MUST equal the frontmatter `name`

4. **Distribution paths.** Two coexist:
   - **Loose skills** — install via `skill-installer` script
     (`scripts/install-skill-from-github.py --repo <owner>/<repo> --path <path>`)
     into `$CODEX_HOME/skills/<name>/`.
   - **Plugins** — bundle multiple skills + hooks + MCP + apps under
     `<plugin>/.codex-plugin/plugin.json`, registered through a
     `marketplace.json`. Plugins live at `<repo>/plugins/<name>/` (repo-local)
     or `~/plugins/<name>/` (home-local), with marketplace at
     `<repo-root>/.agents/plugins/marketplace.json` (or its `~/.agents/...`
     equivalent).

## Decisions

### D1 — Trigger skill name is host-neutral

The trigger skill that activates on every code task ships as
`agentic-apps-workflow` (no `codex-` prefix). This matches the names used
by `claude-workflow` and `pi-agentic-apps-workflow` so the conformance
citation in frontmatter (`implements_spec: <core-version>`) is what
distinguishes hosts, not the skill name. Cross-host docs and ADRs can
talk about "the trigger skill" without disambiguation.

### D2 — Gate-fulfilling skills use `codex-<gate>` prefix

The 13 skills authored in Phase 2 each fulfill one abstract gate from
`agenticapps-workflow-core/spec/02-hook-taxonomy.md`. They ship as
`codex-brainstorming`, `codex-tdd`, `codex-verification`,
`codex-spec-review`, `codex-code-review`, `codex-design-shotgun`,
`codex-design-critique`, `codex-cso`, `codex-qa`,
`codex-impeccable-audit`, `codex-database-sentinel-audit`,
`codex-systematic-debugging`, `codex-finishing-branch`.

The `codex-` prefix is intentional. Without it, a user with both
`claude-workflow` skills (in some shared dir) and Codex skills (in
`~/.codex/skills/`) installed would have to disambiguate by directory; a
prefix avoids ambiguity if a future tool lists "all known skills across
hosts."

### D3 — Lifecycle skills are `setup-codex-agenticapps-workflow` and `update-codex-agenticapps-workflow`

These match the Claude (`setup-agenticapps-workflow`) and pi
(`setup-pi-agenticapps-workflow`) sibling names. The `codex-` infix
identifies which host the skill manages, so a user invoking
`$setup-codex-agenticapps-workflow` from any other host's skill ecosystem
gets unambiguous routing.

### D4 — GSD entry points are skills, not prompts

Per ADR-0003. Skill names: `gsd-discuss-phase`, `gsd-plan-phase`,
`gsd-execute-phase`, `gsd-quick`, `gsd-debug`. No `codex-` prefix because
GSD is the user-facing namespace, parallel to claude-workflow's
`/gsd-discuss-phase` slash command.

### D5 — v0.1.0 ships loose skills + `install.sh`; plugin manifest is v0.2.0

This scaffolder distributes its skills as a flat `skills/` tree at the
repo root. The `install.sh` script symlinks (or copies, per host loader
behavior to be confirmed in Phase 5) each `skills/<name>/` directory into
`$CODEX_HOME/skills/<name>/`. The repo does NOT yet ship a
`.codex-plugin/plugin.json` or a `marketplace.json` because:

- The first goal is parity with `claude-workflow`'s install pattern
  (one symlinking script, easy to audit and reason about).
- Plugin packaging adds another layer (manifest, marketplace ordering,
  policy fields, install/auth gating) that is orthogonal to spec
  conformance.
- A v0.2.0 follow-up can re-package the same `skills/` tree as a plugin
  without breaking installs done via `install.sh`.

Tracked as a v0.2.0 milestone in `CHANGELOG.md` under "Pending."

### D6 — Frontmatter extension fields are documented even though Codex ignores them

Codex's loader reads only `name` and `description` from SKILL.md
frontmatter. This scaffolder also writes `version`, `implements_spec`,
and `implements_gate` into frontmatter so:

- Conformance against `agenticapps-workflow-core` is auditable by `grep`
  without parsing the body.
- Future tooling (the dashboard, the `update-` skill, conformance CI)
  has a stable place to read version data.
- A breaking change in core's spec version is visible in a single line.

Codex's loader will silently ignore the extra fields; this is documented
behavior of YAML frontmatter parsing and is consistent with how
`claude-workflow` and `pi-agentic-apps-workflow` use the same fields.

## Consequences

- **Verification gate impact.** The Phase 7 verification block in the
  scaffolder prompt expects `skills/codex-*/SKILL.md` for the gate
  skills — D2 satisfies this. The block expects
  `skills/agentic-apps-workflow/SKILL.md` for the trigger skill — D1
  satisfies this. The block expects `skills/setup-codex-…/` and
  `skills/update-codex-…/` — D3 satisfies this.
- **`prompts/` directory.** Per ADR-0003 the codex prompt's `prompts/`
  directory does NOT get created; GSD entry points join the `skills/` tree.
- **Plugin packaging.** Donald can ask Codex to install codex-workflow
  via `$skill-installer` against this repo (after v0.1.0 ships) using
  `--repo agenticapps-eu/codex-workflow --path skills/<name>` per skill.
  A single-command install is also possible via `install.sh`.

## Verification

- `~/.codex/skills/.system/skill-creator/SKILL.md` lines 60–73 (skill
  anatomy), 236–242 (naming rules), 12–17 (auto-discovery from
  `$CODEX_HOME/skills`).
- `~/.codex/skills/.system/skill-installer/SKILL.md` line 48
  (`Installs into $CODEX_HOME/skills/<skill-name>`).
- `~/.codex/skills/.system/plugin-creator/SKILL.md` lines 49–66
  (plugin folder layout).

## Appendix — Related Phase 0 environment findings

The codex-workflow scaffolder prompt also asked Phase 0 to verify two
environment-level facts about Codex CLI 0.130.0 that don't merit their
own ADRs but are recorded here so subsequent phases can cite them.

### A1 — MCP server registration mechanism

`codex mcp` is a top-level subcommand with `add`, `remove`, `list`,
`get`, `login`, `logout`. Registration shape:

```
codex mcp add <NAME> --url <URL>             # streamable HTTP server
codex mcp add <NAME> -- <COMMAND> [args...]   # stdio server
codex mcp add <NAME> --env KEY=VALUE -- <COMMAND>
codex mcp add <NAME> --bearer-token-env-var <ENV> --url <URL>
```

Registrations are persisted as `[mcp_servers.<NAME>]` blocks in
`~/.codex/config.toml`. Direct TOML editing is supported but the CLI
form is preferred because it round-trips cleanly through the loader's
schema check.

Phase 5's `install.sh` and `setup-codex-agenticapps-workflow` skill
will use `codex mcp add` (not direct TOML edits) so installs are
reversible via `codex mcp remove`.

### A2 — AGENTS.md root-down concat

Codex loads `~/.codex/AGENTS.md` (home-level) plus `<repo>/AGENTS.md`
(project-level) at session start. Whether nested AGENTS.md files —
e.g. `<repo>/.planning/phases/04/AGENTS.md` when working inside that
subtree — also load is **not yet confirmed by direct test on
0.130.0**. The `~/.codex/AGENTS.md` file is empty by default (0 bytes
on the install used to write this ADR), so empirical observation
hasn't surfaced concat behavior yet.

The scaffolder's setup skill assumes concat happens from project root
only and writes a single `<repo>/AGENTS.md`. Per-phase nested AGENTS.md
files are documented as **optional and unverified** in the
`agents-md-additions.md` template that ships in Phase 5; Donald can
experiment with nested AGENTS.md files in Phase 6 dogfood and
this ADR gets a follow-up note (or a new ADR-0004) once behavior is
confirmed.

#### A2 — RESULT (Phase 6, spec-0.4.0 catch-up, 2026-06-09; Codex 0.130.0)

**Confirmed: Codex concatenates `AGENTS.md` from the git repo root down
to the working directory — every level.** Experiment: a temp tree with
sentinel `AGENTS.md` files at three nested levels (`SENTINEL_ROOT`,
`SENTINEL_MID`, `SENTINEL_DEEP`), probed via
`codex exec -s read-only -C <deepest>` asking the model to echo the
sentinels it sees.

- **Git repo:** all three sentinels returned (ROOT + MID + DEEP). So
  nested per-directory `AGENTS.md` files DO load, anchored at the git
  root and accumulating down to cwd.
- **Non-git tree (`--skip-git-repo-check`):** only the cwd-level
  sentinel (DEEP) returned — without a git root there is no anchor for
  the upward walk, so only the working dir's `AGENTS.md` is read.

Implication: per-phase nested `AGENTS.md` reminders ARE viable in a git
project. The scaffolder's single-root `AGENTS.md` remains correct and
sufficient; nested files are an available enhancement, not required.
F3 resolved.

## Open follow-ups

- **F1** — Confirm during Phase 5 whether `install.sh` should symlink or
  copy. Symlinks let a user `git pull` to update; copies match the
  `skill-installer` script's behavior. Decision deferred until Phase 5.
- **F2** — Re-evaluate plugin packaging after v0.1.0 ships and Donald has
  used Codex with these skills for a few cycles. Track in a follow-up
  ADR-0004 if the choice gets revisited.
- **F3** — Confirm AGENTS.md root-down concat depth empirically during
  Phase 6 dogfood (see appendix A2). Update this ADR or open ADR-0004
  if nested loading IS supported and we want to use it for per-phase
  reminders.
