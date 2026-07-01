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
| **GSD** (discuss/plan/execute/verify, `$gsd-*`, model profiles, `.planning/` state) | [`get-shit-done-multi`](https://github.com/shoootyou/get-shit-done-multi) in `--codex` mode (tracks TÂCHES upstream; alt: [`undeemed/get-shit-done-codex`](https://github.com/undeemed/get-shit-done-codex)) | `npx get-shit-done-multi --codex` |
| **Superpowers** (TDD, brainstorming, verification, code-review, finishing-branch, systematic-debugging) | [`obra/superpowers`](https://github.com/obra/superpowers) (Codex distribution) | per the Superpowers-for-Codex install |
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

## Codex invocation idiom — `$gsd-*`

Codex has no slash-command / `prompts/` directory (ADR-0003). The upstream GSD
distribution installs its entry points as **Codex skills** under
`$CODEX_HOME/skills`, invoked with the `$` shortcut: `$gsd-discuss-phase`,
`$gsd-plan-phase`, `$gsd-execute-phase`, `$gsd-quick`, `$gsd-debug`. The
AgenticApps trigger routes to these by name; this repo does not ship them.

## Planning layout — GSD-native phase subdirectories

The project state is exactly what the bound GSD distribution writes
(get-shit-done v1.42.3 layout), shared across hosts so a plan started on
claude/opencode continues on Codex:

```
PROJECT.md  REQUIREMENTS.md  ROADMAP.md  STATE.md
.planning/
  research/
  phases/<NN>-<slug>/            # e.g. 03-checkout/
    <NN>-CONTEXT.md              # /gsd-discuss-phase
    <NN>-<MM>-PLAN.md            # /gsd-plan-phase
    <NN>-RESEARCH.md  <NN>-VALIDATION.md  <NN>-VERIFICATION.md
    <NN>-<MM>-SUMMARY.md         # /gsd-execute-phase
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
                                      # then runs the GSD-multi installer and
                                      # notes the Superpowers install
#    (bash install.sh --skip-upstream  to install only the AgenticApps skills)

# 2. GSD (if not bound by install.sh, or to (re)pick model profiles)
npx get-shit-done-multi --codex       # installs $gsd-* under $CODEX_HOME/skills
                                      # requires Codex CLI >= 0.130.0

# 3. Superpowers for Codex — per its install; restart Codex to load

# 4. Per-project: $setup-codex-agenticapps-workflow   (migration install)
#    (or:          $update-codex-agenticapps-workflow  on an installed project)
```

## Open verification

- `get-shit-done-multi` is archived and its Codex docs are thin (it points to
  the maintained `gsd-build/get-shit-done`). Confirm the exact `--codex`
  installer command, the `$gsd-*` skill names it registers, and the precise
  `.planning/` filenames it emits against a live install before relying on
  cross-host byte-compatibility. If `get-shit-done-multi --codex` proves
  unsuitable, `undeemed/get-shit-done-codex` is the documented fallback.
- Whether Superpowers' Codex distribution namespaces its skills as
  `superpowers:*` exactly as referenced here (the gate bindings assume it).
