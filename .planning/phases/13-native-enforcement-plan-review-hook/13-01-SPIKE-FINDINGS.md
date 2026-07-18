# 13-01 Spike Findings — codex-cli native PreToolUse trust ledger + apply_patch coverage

**Phase:** 13 — native-enforcement-plan-review-hook
**Success Criterion:** SC#1 — resolve the trust-ledger and apply_patch unknowns by
direct observation before the wrapper (13-02) and migration (13-03) designs finalize.
**codex-cli:** 0.144.4 (Homebrew) · **Machine:** this operator's macOS host
**Started:** 2026-07-18

This is a spike-note, not a RESEARCH.md rewrite. It answers the 4 SPIKE-REQUIRED
questions and states the Matcher decision that 13-02/13-03 consume.

---

## Environment + Pitfall 4 (Task 1 — recorded 2026-07-18, no live codex)

### codex-cli version & feature flags
- `codex --version` → **`codex-cli 0.144.4`** (matches RESEARCH.md env table).
- `codex features list` → **`hooks    stable    true`** — the hooks feature is
  enabled machine-wide on this host (its `stable`/`true` global default is what the
  A1 test in Task 2 must control for by forcing the flag off during the check).

### Trust-ledger entry shapes (verbatim from `~/.codex/config.toml`)
- **Gate A — project-directory trust.** 5 explicit entries, keyed by absolute path:
  ```toml
  [projects."/Users/donald/Sourcecode/frontend-nextjs"]
  trust_level = "trusted"
  [projects."/Users/donald/Sourcecode/codex-workflow"]        # <-- STALE (see Pitfall 4)
  trust_level = "trusted"
  [projects."/Users/donald/Sourcecode/agenticapps/workflow-testbed"]
  trust_level = "trusted"
  ...
  ```
- **Gate B — per-hook trust.** Entries keyed
  `<hooks.json-abs-path>:<event_snake_case>:<group-index>:<hook-index>`, each with a
  single `trusted_hash` line — confirming the 4-segment key format from RESEARCH.md:
  ```toml
  [hooks.state."/Users/donald/.codex/hooks.json:pre_tool_use:0:0"]
  trusted_hash = "sha256:b8fc2592cddc67ed4f32e87359a66fbe307c906d09ed12f7685db1b94e2d54bb"
  ```
- A pre-spike copy of `~/.codex/config.toml` (123 lines) is saved at
  `/tmp/gsd-phase13-spike/config.toml.pre-spike` for the Task 2 post-trust diff.

### Pitfall 4 — this repo's project-trust entry is STALE (CONFIRMED)
- `codex doctor` resolves **repo root → `~/Sourcecode/agenticapps/codex-workflow`**,
  project `codex-workflow`, `.git entry directory`.
- `~/.codex/config.toml` has **0 matches** for `agenticapps/codex-workflow`. The only
  `codex-workflow` trust entry is keyed to the STALE pre-reorg path
  **`/Users/donald/Sourcecode/codex-workflow`** — NOT the current real path
  **`/Users/donald/Sourcecode/agenticapps/codex-workflow`**.
- **Consequence for 13-05:** the current repo path is effectively untrusted. Before the
  SC#2 live session, the operator must re-trust the repo at its current path (a
  pre-flight step, separate from anything HOOK-03 installs), or the project-scoped
  `.codex/` layer (config, hooks, rules) will not load and the block will be
  misdiagnosed as a hook-install failure. **NOT re-trusted here** — recorded only.

### Scratch fixtures (never `~/.codex/hooks.json`)
- `~/.codex/hooks.json` sha256 verified **byte-identical before and after** Task 1
  (`07112ce1…6d778`) — the machine's live 3-vendor hooks file was never written.
- Two scratch git repos under `/tmp/gsd-phase13-spike/`, each with a `.codex/hooks.json`
  carrying ONE no-`matcher` `PreToolUse` group (fires for all tools) whose command is
  `echo "$(date) fired in <name>" >> <repo>/.codex/fired.log; cat`:
  - **`spike-repo`** — will be trusted in Task 2 (Gate A + Gate B observations).
  - **`spike-repo-2`** — identical content, deliberately left UNtrusted (Step 6).
- hooks.json schema used (matches codex's live shape):
  `{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"…"}]}]}}`.

---

## Interactive Observations (Task 2 — human-observed live codex sessions)

> **STATUS: PENDING — operator to fill.** Each block below is filled with a real,
> dated observation during the live `codex` sessions, then the operator types
> "observations recorded".

### STEP 3 — default trust_level for an unlisted project
_Run a trivial `codex` command inside `spike-repo` BEFORE adding any
`[projects."…spike-repo"]` entry. Record: interactive trust prompt? Did the hook fire
on first run, or only after an explicit trust action?_

- **Observation:** _(pending)_

### STEP 4 — trust flow + ledger diff (one operator action or two gates?)
_Trust the hook via `/hooks` (or the startup "1 hook is new or changed… Trust all and
continue" prompt). Immediately diff pre-trust vs post-trust `~/.codex/config.toml`._

- **Exact `[hooks.state.<key>]` entry written for this hook:** _(pending)_
- **Was a `[projects."…spike-repo"]` entry written at the SAME time (one action sets
  both Gate A + Gate B, or two distinct actions)?:** _(pending)_

### STEP 6 — untrusted-project case
_In `spike-repo-2` with NO trust action, confirm the hook does NOT fire; record whether
codex reports WHY (untrusted project = Gate A, vs untrusted hook = Gate B)._

- **Observation:** _(pending)_

### STEP 7 — apply_patch coverage (THE decisive observation)
_Point the hook command at `cat >> <repo>/.codex/payload.log`, then in a human-observed
`codex` session perform ONE file-creating edit via whatever tool codex naturally chooses.
Inspect the captured payload._

- **`tool_name` reported for the file edit:** _(pending — `apply_patch`? `Bash`? other?)_
- **Exact `tool_input` shape (patch text under `.input` / `.patch` / elsewhere; does it
  carry a parseable `*** Update File:` / `*** Add File:` path?):** _(pending)_
- **Deny visibility:** change the hook to actually deny and re-run — does the operator
  SEE the block-reason text, or only a generic denial?: _(pending)_

### A1 — project-scoped `[features] hooks = true` honored?
_In a trusted scratch repo, set ONLY a project-scoped `[features] hooks = true` in its
`.codex/config.toml` while forcing the machine-wide default OFF for the check (e.g.
`codex -c features.hooks=false features list` from inside the repo). Record whether
`hooks` reports ENABLED via the PROJECT layer specifically._

- **Observation:** _(pending)_

---

## Resolved Answers (Task 3 — frozen; consumed by 13-02 / 13-03)

> **STATUS: PENDING — filled after Task 2, with the offline sha256 determination.**

- **SPIKE item 1 — exact `trusted_hash` input:** _(pending — a/b/c: command string /
  compact-JSON hook object / normalized-TOML hook object)_
- **SPIKE item 2 — pre-seeding viability + one-gate-or-two:** _(pending)_
- **SPIKE item 3 — default trust_level for an unlisted project:** _(pending)_
- **SPIKE item 4 — apply_patch coverage + `tool_input` field name:** _(pending)_
- **sha256 hash-input determination:** _(pending — which of a/b/c matched observed hash)_
- **A1 (project-scoped feature flag honored):** _(pending — CONFIRMED / FALSIFIED)_
- **No `trusted_hash` was written into `~/.codex/config.toml` (Pitfall 3 honored):**
  _(to be affirmed in Task 3)_

**Matcher decision:** _(pending — the bold one-line decision naming the exact `matcher`
value(s) 13-03's hooks.json entry must carry, and stating yes/no on whether 13-02's
wrapper needs a `Bash`-command-parsing branch in addition to the apply_patch path.)_
