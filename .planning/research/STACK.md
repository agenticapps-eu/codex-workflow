# Stack Research

**Domain:** Internal tooling — external tool surfaces for v0.8.0 "Enforcement, Not Intention" (HOOK-01, CI-01). No application runtime or new language stack; this research pins two *host* surfaces this repo binds against.
**Researched:** 2026-07-16
**Confidence:** HIGH for both surfaces — verified against primary source (openai/codex repo, byte-identical at the exact pinned tag `rust-v0.144.4`) and cross-checked empirically against a live, locally installed `codex-cli 0.144.4` and its populated `~/.codex/config.toml` / `~/.codex/hooks.json`. GitHub Actions facts verified via `gh api` against the live `actions/checkout` repo and the target submodule's actual visibility.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| codex-cli native `PreToolUse` hook | 0.144.4 (repo's pinned version) | Programmatic, agent-independent block of a tool call before it executes — the surface HOOK-01 needs to stop being "agent-mediated" (ADR-0009 d.9) | It is real, stable, and enabled by default at 0.144.4 (see Finding 1 below) — this was previously an open question this repo had not observed |
| `actions/checkout@v7` | v7.0.0 (current major, released 2026-06-18) | Clones the repo plus the `vendor/agenticapps-shared` submodule in CI | Current major tag; `submodules: recursive` is the documented, correct key for CI-01's hard submodule dependency |
| GitHub-hosted `ubuntu-latest` runner | Ubuntu 24.04 image (as of researched date) | Executes `migrations/run-tests.sh` (bash) and the drift check it now includes | `jq` ships preinstalled (1.7.1) on this image; `awk` (mawk) is a base-Ubuntu package present on every Ubuntu image, including runner images — no extra install step needed for either |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jq` | 1.7.1 (ubuntu-latest preinstalled) | `run-tests.sh`'s config-edit fixtures (`migrations/run-tests.sh:314-363`) shell out to `jq -e`, `jq '...' file > tmp && mv`, etc. | Already gated: the script does `command -v jq \|\| SKIP` (not FAIL) around this block — CI passing does NOT by itself prove `jq` was present; verify the CI log shows 0 SKIP beyond the one documented `0000-baseline` SKIP |
| `sha256` hook-trust hashing | codex-cli internal, undocumented hash-input algorithm | Codex's hook trust ledger stores `trusted_hash = "sha256:<hex>"` per hook handler in `config.toml`'s `[hooks.state."<path>:<event>:<group_idx>:<handler_idx>"]` table (confirmed empirically, see Finding 4) | If HOOK-01 wants to pre-seed trust from a migration (skip the interactive `/hooks` approval step), the exact bytes hashed are NOT yet confirmed — spike required before relying on this |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `gh api` / `gh api repos/openai/codex/git/blobs/<sha>` | Pulling primary-source Rust at an exact git tag when a package registry/docs site might be stale or (per this repo's own precedent) simply wrong | Used throughout this research; recommended pattern for any future spike into codex-cli internals — faster and more authoritative than scraping docs pages, and works even when `contents` API 404s on old tags (fall back to `git/trees` + `git/blobs`) |
| `codex features` CLI subcommand | Inspects live feature-flag state (`hooks` stage/default) | Present at 0.144.4 (`codex features`); not yet exercised in this research beyond the source-level confirmation, but is the fastest local empirical check available inside any future spike |
| `/hooks` (interactive Codex TUI command) | Reviews and trusts a new/changed hook definition | This is the ONLY documented way to grant trust; no CLI flag or config-only bypass was found in the source read for this research (see Gap 2) |

## Installation

No new package installs are required for either surface:

```bash
# HOOK-01: no install. codex-cli 0.144.4 already ships hooks as Feature::CodexHooks,
# key "hooks", stage Stable, default_enabled: true (verified at the exact pinned tag).
# A project-scoped hooks.json is authored directly into the target project's
# .codex/hooks.json by a new migration — no codex-cli config.toml edit needed
# unless overriding the (already-true) default.

# CI-01: no install. ubuntu-latest ships jq; awk (mawk) is base Ubuntu.
```

```yaml
# .github/workflows/ci.yml — CI-01 shape (see Sources for verification of each key)
name: ci

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          submodules: recursive
          # No token/ssh-key needed: vendor/agenticapps-shared is a PUBLIC repo
          # (gh api repos/agenticapps-eu/agenticapps-shared → "private": false).
      - name: Run migration test harness (includes drift check)
        run: bash migrations/run-tests.sh
        # No separate "drift check" step is needed: test_drift() is already
        # dispatched inside run-tests.sh (migrations/run-tests.sh:3217) whenever
        # the harness runs with no filter arg. A bash step's own exit code IS
        # the job's pass/fail signal — no extra wiring required. run-tests.sh's
        # own tail: exit 1 on FAIL>0 or on "no tests ran"; exit 0 otherwise.
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| Project-scoped `<repo>/.codex/hooks.json` for HOOK-01 | User-global `~/.codex/hooks.json` | Only if the gate must apply across every repo on the machine unconditionally. ADR-0009 rejected native hooks partly on the belief the surface is "global rather than per-project" — **that belief does not survive contact with the source**: `<repo>/.codex/hooks.json` is a real, higher-precedence, additive config layer (see Finding 3). A project-scoped binding removes ADR-0009's self-scoping objection entirely and should be the default design, not the global file. |
| `permissionDecision: "deny"` JSON on stdout, exit 0 | Exit code `2` + stderr reason | The exit-2 shortcut is real and is exactly what the ADR-0009 verifier pattern (`check-plan-review.sh` exiting 2 on failure) already produces with zero rewrite — but it has a documented Windows-only failure mode reported against 0.144.x (legacy exit-2 path classified `PreToolUse Failed` and fails OPEN instead of blocking). This repo's CI/dev targets are not Windows, so exit-2 is acceptable, but the JSON form is the more robust long-term contract if that ever changes. |
| `actions/checkout@v7` | `actions/checkout@v4` (widely cited in older tutorials/training data) | Never, for a new workflow — v4 is two majors behind current (v5 released 2025-11-17, v6 2025-11-20, v7 2026-06-18, per `gh api repos/actions/checkout/releases`). Pin `@v7` unless a specific compatibility reason surfaces. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| Assuming codex-cli hooks are "experimental / disabled by default" | True of an EARLIER codex-cli version (several web sources describe this stage), but FALSE at the repo's pinned 0.144.4: `Feature::CodexHooks { key: "hooks", stage: Stable, default_enabled: true }`, verified byte-for-byte against the `rust-v0.144.4` git tag. Do not gate HOOK-01 design on toggling a feature flag that is already on. | Verify feature state per-version with `gh api repos/openai/codex/git/blobs/<sha>` against the exact pinned tag, or `codex features` locally, before trusting any cached claim (including this document, if the pin ever moves). |
| Treating `~/.codex/hooks.json` `PreToolUse` as Bash-only | One third-party blog (agenticcontrolplane.com) states this explicitly "by design." It is **contradicted by the primary source**: `codex-rs/core/src/tools/hook_names.rs::apply_patch()` shows the canonical `tool_name` for file edits is `"apply_patch"`, with `Write`/`Edit` accepted only as **matcher aliases**, not the payload's `tool_name` value — i.e. PreToolUse genuinely fires for file-edit tool calls, not just shell. MCP tool calls also fire it (per official docs and corroborating third-party sources). | Trust the primary-source `hook_names.rs` classification over any single blog post; a stale/incorrect blog claim was directly falsified here by checked-out source. |
| A templated `--file`-style argument on the hooks.json `command` string | `HookHandlerConfig::Command { command: String, ... }` is a **static string** — Codex does not template tool-call data into it. There is no equivalent of `{{tool_input.file_path}}` interpolation in the schema read from source. | The hook's `command` must be a wrapper script that reads the JSON payload from **stdin** (fields: `tool_name`, `tool_input`, `cwd`, etc.) and constructs `check-plan-review.sh --file "$path"` itself, e.g. via `jq -r '.tool_input.file_path // empty'`. This is a real (small) new artifact HOOK-01 must write, not a "wiring change" in the literal sense ADR-0009 hoped for — see Gap 1. |
| Assuming exit code `2` alone blocks | Verified in source (`pre_tool_use.rs::parse_completed`, `Some(2) => ...`): exit 2 blocks **only if stderr is non-empty**. Exit 2 with EMPTY stderr is treated as a hook **failure** (`HookRunStatus::Failed`, fails open — the tool call proceeds), not a block. Any other non-zero, non-2 exit code is also treated as a failure and fails open. | `check-plan-review.sh` already writes its rejection reason to stderr on `exit 2` (per ADR-0009 D-12/D-13 description) — confirm this holds for every exit-2 path before wiring, since a silent `exit 2` (no stderr) would silently fail OPEN instead of blocking, which is the exact "nominal enforcement" failure class this milestone exists to close. |

## Stack Patterns by Variant

**If HOOK-01 targets this repo's own dev loop (dogfooding) as well as scaffolded/migrated target projects:**
- Ship the wrapper + `hooks.json` fragment via a new forward migration (per this repo's migration-immutability constraint), writing to `<target>/.codex/hooks.json`, not `~/.codex/hooks.json`.
- Because project-layer hooks require "the project layer is trusted" before they load (a broader trust gate than per-hook trust — see Finding 3), a migration alone cannot silently activate the gate; a first-run interactive `/hooks` approval remains a real onboarding step. Document this rather than assume silent activation.

**If HOOK-01 needs the gate to apply even when the tool call is an `apply_patch`-shaped edit rather than a `Bash` command (e.g. blocking a plan-adjacent file write directly, not just a `git commit`):**
- Use a `matcher` of `"apply_patch"` (or the `"Write"`/`"Edit"` aliases) rather than `"Bash"` in the `PreToolUse` matcher group, and read `tool_input` shape for `apply_patch` calls (patch content / target path) instead of `tool_input.command`.
- This is a materially different `tool_input` shape than the Bash case (`{"command": ...}` vs. resolved patch/file fields) — the wrapper script needs two branches, not one, if it must cover both.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|------------------|-------|
| codex-cli 0.144.4 | Rust workspace tag `rust-v0.144.4` (`openai/codex`) | Confirmed identical source for `pre_tool_use.rs`, `hook_names.rs`, `hook_config.rs`, and the generated PreToolUse input/output JSON Schemas between this tag and the `main` branch snapshot read during this research — the hooks subsystem has not materially drifted around this pin. Re-verify if the repo's pin ever moves. |
| `actions/checkout@v7` | GitHub-hosted `ubuntu-latest` (24.04 image, current) | No known incompatibility; `submodules: recursive` + public submodule needs no `token`/`ssh-key` input. |
| `jq` 1.7.1 (ubuntu-latest) | `run-tests.sh`'s `jq -e`/`jq '...'` fixture usage | Confirmed compatible by inspection of the exact `jq` invocations in `migrations/run-tests.sh:314-363` — no `jq` feature used there is version-sensitive beyond baseline 1.6+ syntax. |

## Sources

**codex-cli hook surface (HOOK-01) — primary source, HIGH confidence:**
- `openai/codex` GitHub repo, read via `gh api` at the exact pinned tag `rust-v0.144.4` (commit `632c07017ed17f00ca6d911b754683dee785af69`):
  - `codex-rs/hooks/src/events/pre_tool_use.rs` — block/deny decision logic and its unit tests (exit-2-with-stderr, `permissionDecision: deny`, deprecated `decision: block`, fail-open cases for `allow`/`ask`/unsupported exit codes)
  - `codex-rs/hooks/schema/generated/pre-tool-use.command.input.schema.json` — stdin payload schema
  - `codex-rs/hooks/schema/generated/pre-tool-use.command.output.schema.json` — stdout payload schema
  - `codex-rs/core/src/tools/hook_names.rs` — canonical `tool_name` values (`Bash`, `apply_patch`, `spawn_agent`) and matcher-alias list (`Write`, `Edit` alias to `apply_patch`; `Agent` aliases to `spawn_agent`)
  - `codex-rs/config/src/hook_config.rs` — `hooks.json`/TOML schema (`MatcherGroup`, `HookHandlerConfig::Command{command, commandWindows, timeout, async, statusMessage}`, `HookStateToml{enabled, trusted_hash}`, `ManagedHooksRequirementsToml`)
  - `codex-rs/hooks/src/engine/discovery.rs` — confirms hooks are discovered per config layer (`ConfigLayerStack`, lowest-to-highest precedence) and are **additive across layers**, not replaced by higher-precedence layers
  - `codex-rs/features/src/lib.rs` (line ~966) — `Feature::CodexHooks { key: "hooks", stage: Stage::Stable, default_enabled: true }` at 0.144.4
  - `codex-rs/features/src/legacy.rs` — confirms `codex_hooks` is a retained legacy alias key for the same feature (both `hooks = true` and `codex_hooks = true` work at 0.144.4; `hooks` is canonical)
- **Local empirical verification** (this machine has `codex-cli 0.144.4` installed — `codex --version` confirmed): `~/.codex/hooks.json` exists and is actively populated by three unrelated third-party tools (nyx, termloop, superset) using exactly the schema derived from source (`PreToolUse`/`PostToolUse`/`SessionStart`/`Stop`/`UserPromptSubmit`/`PermissionRequest` event keys, `{hooks: [{type: "command", command, timeout}]}` shape); `~/.codex/config.toml` has `[features] hooks = true` and a populated `[hooks.state."<hooks.json path>:<event_snake>:<group_idx>:<handler_idx>"] trusted_hash = "sha256:<hex>"` table — this is the live, working trust ledger, not a documentation claim.
- Official docs (secondary corroboration, MEDIUM-HIGH — used to cross-check, superseded by source where they conflicted): `https://developers.openai.com/codex/hooks` (redirects to `https://learn.chatgpt.com/docs/hooks`), `https://learn.chatgpt.com/docs/changelog` (confirms `0.144.5` as latest at research time, hooks-related entries at `0.143.0`/`0.144.0`)
- Third-party corroboration on the exit-2 Windows caveat, MEDIUM confidence (single source, not independently reproduced against Windows): WebSearch summary citing a report that "on Codex 0.144.x for Windows, the legacy exit-2 path was classified PreToolUse Failed and then failed open, whereas minimal JSON denial blocks correctly"
- **Falsified/rejected source**: `agenticcontrolplane.com/blog/codex-cli-hooks-reference` claims PreToolUse is "Bash tool only... by design" — directly contradicted by the primary source (`hook_names.rs::apply_patch()`) and by the official docs. Treat this specific claim on that domain as wrong for 0.144.4.
- **Internal, now-superseded claim**: ADR-0009 (`docs/decisions/0009-plan-review-gate.md`, decision 9 and Option B) asserts the native hook surface is "global rather than per-project" — this research finds that claim does not hold: `<repo>/.codex/hooks.json` is a real, additive, higher-precedence config layer (`discovery.rs`). Flag for the ADR-0009 amendment HOOK-01 already plans (per PROJECT.md).

**GitHub Actions (CI-01) — HIGH confidence, verified via `gh api` against live GitHub state:**
- `gh api repos/actions/checkout/releases` — current major is `v7.0.0` (published 2026-06-18); `v6.0.3` (2026-06-02), `v6.0.2` (2026-01-09), `v6.0.1` (2025-12-02), `v6.0.0` (2025-11-20), `v5.0.1` (2025-11-17)
- `gh api repos/actions/checkout/contents/README.md` — confirms the exact input key: `submodules: ''` accepting `true` or `'recursive'`; `ssh-key`/`token` inputs available for private submodules (not needed here)
- `gh api repos/agenticapps-eu/agenticapps-shared` → `"private": false, "visibility": "public"` — no token/deploy-key required for submodule checkout
- WebFetch of `actions/runner-images` Ubuntu 24.04 readme — `jq 1.7.1-3ubuntu0.24.04.2` explicitly listed as a preinstalled apt package; `awk`/`gawk`/`mawk` not itemized in that doc's software list but is a standard base-Ubuntu package present on every Debian-derived image (MEDIUM confidence on the explicit itemization, HIGH confidence on practical presence)
- Local repo inspection: `migrations/run-tests.sh` (this repo) — confirms `test_drift` (line 3217) is dispatched inside the same harness invocation (no separate CI step needed for the drift check), and that the script's own exit code (`exit 1` on any FAIL or "no tests ran", `exit 0` otherwise, at the file's tail) is what a plain `run: bash migrations/run-tests.sh` step surfaces as job pass/fail
- `.gitmodules` (this repo) — `vendor/agenticapps-shared` at `https://github.com/agenticapps-eu/agenticapps-shared`
- `git submodule status` (this repo, local) — submodule already initialized at `v1.0.0` (`1f5d543`)

## Gaps to Address (flagged for a spike, not resolved here)

1. **The `--file` wiring is not a "wiring change," it is a new artifact.** ADR-0009 decision 9 and its Open Follow-ups describe the native-hook upgrade as pointing the hooks.json `command` at "this same verifier" with its `--file` argument "exist[ing] for exactly that." Source shows `hooks.json`'s `command` field cannot template tool-call data — the wrapper that reads stdin JSON and derives a `--file` value (from `tool_input.command` for Bash or `tool_input`'s patch/path fields for `apply_patch`) does not exist yet and must be designed and written as part of HOOK-01. Recommend scoping this explicitly as a deliverable, not treating it as free.

2. **Hook-trust pre-seeding is unconfirmed.** The trust ledger's exact hash algorithm (what bytes of the handler definition are hashed to produce `trusted_hash`) was not found in the portion of source read for this research. If HOOK-01 wants a migration to pre-trust its own hook (avoiding a manual `/hooks` approval step on every target project), this needs a dedicated spike: either locate the hashing code (`codex-rs/hooks` likely has a `trust`/`hash` module not yet read) or empirically reverse-engineer it (author a known hook, trust it interactively via `/hooks`, diff the resulting `trusted_hash` against candidate hash inputs).

3. **Whether "project layer trust" (a prerequisite for `<repo>/.codex/hooks.json` loading at all, per the official docs' "loaded only after the project layer is trusted") is the same gate as the per-hook `trusted_hash` state, a separate one-time repo-trust prompt, or both, was not fully disentangled from the source read here.** This directly affects whether a freshly-migrated target project's `.codex/hooks.json` binding activates automatically or requires two distinct manual approvals (repo trust + hook trust) on first run. Needs a live spike: run `codex` inside a fresh clone of a project carrying a new `.codex/hooks.json` and observe exactly what is prompted.

4. **`awk` on `ubuntu-latest` was not found explicitly itemized** in the runner-images software list this research fetched (only `jq` was). Practically certain to be present (mawk ships as a `Priority: important` Ubuntu package), but if CI-01's first run surfaces an `awk: command not found`, this is the first thing to check — trivially fixed with `sudo apt-get install -y gawk` as a defensive step if ever needed, at effectively zero cost to add preemptively.

---
*Stack research for: codex-workflow v0.8.0 — HOOK-01 (codex-cli native hook surface) and CI-01 (GitHub Actions CI)*
*Researched: 2026-07-16*
