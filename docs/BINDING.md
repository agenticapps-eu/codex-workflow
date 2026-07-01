# codex-workflow as a binding (not a re-port)

As of this change, `codex-workflow` no longer re-implements GSD or Superpowers
for Codex. It **binds** to the maintained upstream distributions and ships only
the genuinely-AgenticApps layer on top. See
[ADR-0007](decisions/0007-bind-upstream-gsd.md) and the shared standard
[`docs/standards/gsd-binding-and-planning.md`](standards/gsd-binding-and-planning.md).

## Why

GSD (TÂCHES lineage) and Superpowers already support Codex and move fast.
Re-authoring them as `gsd-*` / `codex-*` skills meant tracking two upstreams by
hand — and it produced an invented `.planning/phases/<NN>/` layout whose plan
artifacts were not portable to the other hosts (a three-host benchmark confirmed
three different `.planning/` layouts). `claude-workflow` was never a re-port, and
`opencode-workflow` already moved to a binding; this change makes the Codex host
symmetric so all three share one portable project plan.

## The three layers

| Layer | Source | How it's installed |
|---|---|---|
| **GSD** (discuss/plan/execute, `/prompts:gsd-*`, `.planning/` state) | [`get-shit-done-codex`](https://github.com/RazvanBugoi/get-shit-done) (TÂCHES lineage; v1.4.1 verified on Codex CLI 0.142.0) | `npx get-shit-done-codex` (pick Global) |
| **Superpowers** (TDD, brainstorming, verification, code-review, finishing-branch, systematic-debugging) | [`obra/superpowers`](https://github.com/obra/superpowers) — the official `superpowers` Codex plugin (openai-curated marketplace) | `codex plugin add superpowers` |
| **AgenticApps** (spec-first trigger, gstack gates, spec/QA/DB/security gates, migration install) | this repo | `bash install.sh` + `$setup-codex-agenticapps-workflow` |

## What this repo still ships (the AgenticApps layer)

- `agentic-apps-workflow` — the spec-first trigger/router.
- gstack + AgenticApps gates with **no GSD/Superpowers equivalent**:
  `codex-cso`, `codex-qa`, `codex-design-shotgun`, `codex-design-critique`,
  `codex-database-sentinel-audit`, `codex-impeccable-audit`,
  `codex-spec-review`, `codex-ts-declare-first`.
- `setup-` / `update-codex-agenticapps-workflow` + the migration chain.

What was **removed** (now provided by upstream): the `gsd-*` skills (GSD) and
`codex-brainstorming`, `codex-code-review`, `codex-finishing-branch`,
`codex-verification`, `codex-tdd`, `codex-systematic-debugging` (Superpowers).
Gate bindings for these now point at the upstream skills — see the trigger
skill's Step 3 table and `.planning/config.codex.json`.

## Codex invocation idiom — `/prompts:gsd-*`

ADR-0003's premise ("Codex has no `prompts/` directory") is outdated: Codex CLI
(verified on 0.142.0) supports **custom prompts** under `$CODEX_HOME/prompts`,
invoked as `/prompts:<name>`. `get-shit-done-codex` installs its 18 GSD entry
points there — invoke them as `/prompts:gsd-discuss-phase`,
`/prompts:gsd-plan-phase`, `/prompts:gsd-execute-plan` (plus
`/prompts:gsd-new-project`, `/prompts:gsd-create-roadmap`,
`/prompts:gsd-progress`, `/prompts:gsd-help`, …). The AgenticApps trigger routes
to these; this repo does not ship them.

Notable naming: execute is **`gsd-execute-plan`** (not `gsd-execute-phase`), and
this distribution ships **no** `gsd-quick` or `gsd-debug` — tiny/small tasks
skip GSD orchestration (Step 1), and bug tasks route straight to
`superpowers:systematic-debugging`. AgenticApps gate skills are still Codex
**skills** invoked as `$skill-name` (e.g. `$codex-cso`).

## Planning layout — GSD-native phase subdirectories

The project state is exactly what the bound GSD distribution writes
(get-shit-done v1.42.3 layout), shared across hosts so a plan started on
claude/opencode continues on Codex:

```
PROJECT.md  REQUIREMENTS.md  ROADMAP.md  STATE.md
.planning/
  research/
  phases/<NN>-<slug>/            # e.g. 03-checkout/
    <NN>-CONTEXT.md              # /prompts:gsd-discuss-phase
    <NN>-<MM>-PLAN.md            # /prompts:gsd-plan-phase
    <NN>-RESEARCH.md  <NN>-VALIDATION.md  <NN>-VERIFICATION.md
    <NN>-<MM>-SUMMARY.md         # /prompts:gsd-execute-plan
    <NN>-UAT.md  <NN>-UI-SPEC.md  <NN>-SECURITY.md  …
  milestones/  quick/<NNN>-<slug>/
docs/decisions/NNNN-<slug>.md
```

This supersedes codex-workflow's earlier **invented** `.planning/phases/<N>/`
variant (a bare phase number with bare `PLAN.md` / `VERIFICATION.md`), which was
not byte-compatible with GSD or the other hosts. AgenticApps-specific artifacts
are written **inside** the phase directory alongside GSD's files:
`.planning/phases/<NN>-<slug>/REVIEW.md`, `QA.md`, `DB-AUDIT.md`,
`IMPECCABLE-AUDIT.md`, `screenshots/…`. Whatever the bound GSD distribution
writes is authoritative; the AgenticApps layer reads it and adds its evidence
alongside, it does not reshape it.

Host-specific state stays namespaced: `.planning/config.codex.json`, the
`.codex/` marker dir, `AGENTS.md`, and `.codex/session-handoff.md`.

## Coexistence (standard §4)

`AGENTS.md` is read by both Codex and opencode, so **codex + opencode cannot
share one working tree** — run them in separate worktrees. `codex + claude` is
fine (`AGENTS.md` + `.codex/` vs `CLAUDE.md` + `.claude/`), provided each host
reads its own `.planning/config.<host>.json` and its own
`.<host>/session-handoff.md`.

## Install order

```bash
# 1. AgenticApps layer (skills) + bind upstreams
bash install.sh                       # symlinks skills into $CODEX_HOME/skills,
                                      # then runs the get-shit-done-codex installer
                                      # and notes the Superpowers install
#    (bash install.sh --skip-upstream  to install only the AgenticApps skills)

# 2. GSD (if not bound by install.sh)
npx get-shit-done-codex               # interactive: pick Global (~/.codex)
#   non-interactive: npx -y -p get-shit-done-codex get-shit-done-cc --global
#   installs /prompts:gsd-* under $CODEX_HOME/prompts; verify: /prompts:gsd-help

# 3. Superpowers — official Codex plugin; restart Codex to load
codex plugin add superpowers           # from the openai-curated marketplace
#   verify: codex plugin list | grep superpowers

# 4. Per-project: $setup-codex-agenticapps-workflow   (migration install)
#    (or:          $update-codex-agenticapps-workflow  on an installed project)
```

## Verified vs open

**Verified (2026-07-01, Codex CLI 0.142.0):**

1. **GSD** — `get-shit-done-codex` v1.4.1 installed → 18 `/prompts:gsd-*` prompts
   under `~/.codex/prompts/` + resources under `~/.codex/get-shit-done/`, and GSD
   writes the `.planning/phases/<NN>-<slug>/` layout above. The naming quirks
   (`gsd-execute-plan`; no `gsd-quick`/`gsd-debug`) are reflected in the trigger
   skill's routing.
2. **Superpowers** — installed as the official `superpowers` Codex plugin
   (`codex plugin add superpowers`, openai-curated marketplace). Codex plugins
   namespace skills as `plugin:skill`, so the six gate bindings resolve exactly:
   `superpowers:brainstorming`, `superpowers:test-driven-development`,
   `superpowers:verification-before-completion`,
   `superpowers:requesting-code-review`,
   `superpowers:finishing-a-development-branch`,
   `superpowers:systematic-debugging`.

**Open:** the live cross-host testbed hand-off (claude→codex plan continuity on
the shared `.planning/`).

> **Package lineage note.** The brief named `get-shit-done-multi`, but that npm
> package is deprecated (→ `get-shit-done-cc`, also deprecated). The maintained
> Codex-native distribution is `get-shit-done-codex` (RazvanBugoi, TÂCHES
> lineage), which is what this repo binds.
