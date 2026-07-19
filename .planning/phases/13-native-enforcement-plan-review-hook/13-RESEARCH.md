# Phase 13: Native Enforcement — Plan-Review Hook - Research

**Researched:** 2026-07-17
**Domain:** codex-cli native `PreToolUse` hook surface (trust ledger, project-scoped config layering, exit-code contract) + shell wrapper design + migration authoring
**Confidence:** MEDIUM-HIGH — the two named trust-ledger gaps are now DOC-RESOLVED at the "shape of the mechanism" level via live inspection of an installed codex-cli 0.144.4 on this machine plus official docs and upstream source references; the *exact* hash algorithm and the *default* project-trust value remain genuinely SPIKE-REQUIRED (see below). Everything else (schema, exit-code contract, install precedent, wrapper design) is HIGH confidence.

## Summary

This phase's blocking risk was never "can codex-cli intercept a tool call" — that has been true since 0.129.0 and is `[features] hooks = true` by default on the machine this research ran on. The risk was the two named trust-ledger unknowns (ROADMAP SC#1). Both are now answered at the mechanism level, not by reading docs alone but by directly inspecting a live, in-use `~/.codex/config.toml` and `~/.codex/hooks.json` on this development machine (already carrying real hook installs from three unrelated tools — `nyx`, `termloop`, `superset` — which is itself useful ground truth for "merge-don't-clobber into someone else's hooks.json," SC#4's precedent). **The two gates are separate, confirmed via direct observation**: (1) `[projects."<abs-repo-path>"] trust_level = "trusted"|"untrusted"` gates whether the ENTIRE project-scoped `.codex/` layer (config, hooks, rules) loads at all; (2) `[hooks.state."<hooks.json-path>:<event>:<group-idx>:<hook-idx>"] trusted_hash = "sha256:..."` gates whether an INDIVIDUAL hook handler, once its file has loaded, is permitted to execute. This is a two-gate model, not one. Pre-seeding a `trusted_hash` non-interactively is possible but **explicitly undocumented and unsupported** — a live, open, unresolved upstream issue (openai/codex#21615) confirms other tool vendors already do exactly this by writing directly into `~/.codex/config.toml`, and this repo's own live config.toml shows three vendors (`nyx`, `termloop`, implicitly others) doing it today. Codex-cli's official docs also **directly falsify** ADR-0009's "native hooks are global rather than per-project" claim: `<repo>/.codex/hooks.json` and `<repo>/.codex/config.toml` are documented, discovered layers, closest-to-cwd wins on conflict — this is the DOC-03 factual correction.

What remains genuinely unresolved by documentation and requires the empirical spike: the exact byte-for-byte hash algorithm (full hook object vs. command string alone), the DEFAULT `trust_level` for a project with no explicit `config.toml` entry, whether `PreToolUse` actually fires for `apply_patch`/file-edit tool calls in this exact installed version (official docs say yes; one independent third-party source says no — a live contradiction that only a real session can settle), and whether stderr content (vs. exit code alone) changes how codex's own hook runner treats a block. A live worktree bug (openai/codex#27133) is also directly relevant to this repo's git-worktree-friendly workflow conventions and should be checked during the spike.

**Primary recommendation:** Sequence Phase 13 as three plans — (1) a short spike plan that runs the exact protocol below and freezes its findings into a spike-note before any wrapper code is written, (2) a wrapper + migration (0011) plan that installs `<repo>/.codex/hooks.json` merge-don't-clobber alongside `<repo>/.codex/config.toml`'s `[features] hooks = true`, both project-scoped, both reusing this repo's existing `check-plan-review.sh` unmodified, and (3) an ADR-0009 Correction + live human-observed-block plan (SC#2, SC#5) that closes DOC-03 and proves the end-to-end block.

## Architectural Responsibility Map

This phase's "capabilities" span CLI-host runtime tiers rather than a web app's tiers; the table below adapts the standard tier vocabulary to this domain.

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Intercept a tool call before execution | codex-cli native runtime (Rust, `codex-rs/hooks`) | — | Only the CLI's own process has a hook point before tool dispatch; nothing this repo ships can create that interception point |
| Project-directory trust decision | codex-cli runtime, `~/.codex/config.toml` `[projects.<path>]` | Operator (human, one-time interactive) | Stored per-machine, per-absolute-path, outside any repo; not something a migration can set on the operator's behalf |
| Per-hook trust decision | codex-cli runtime, `~/.codex/config.toml` `[hooks.state.<key>]` | Operator (human, via startup hooks-review flow or `--dangerously-bypass-hook-trust`) | Same as above — lives outside the repo, keyed by absolute hooks.json path |
| Argument translation (stdin JSON → `--file <path>`) + exit-code/JSON translation | New wrapper script (HOOK-02), shipped in `skills/agentic-apps-workflow/scripts/` | — | This is the one piece of new code this phase authors; it is a thin adapter, not gate logic |
| Gate verdict logic (resolve phase, REVIEWS.md evidence check) | Existing `check-plan-review.sh` (unchanged) | — | Already built, already mutation-tested through Phase 12; HOOK-02 must not re-implement any of it |
| Declarative install (merge into `.codex/hooks.json` + `.codex/config.toml`) | New migration 0011 (HOOK-03) | `setup-codex-agenticapps-workflow` templates (fresh installs) | Project-scoped file writes, merge-don't-clobber, mirrors 0000-baseline Step 6 and migration 0008's leaf-merge precedent |
| Decision record | `docs/decisions/0009-plan-review-gate.md` (in-place Correction section) | — | DOC-03; no new ADR number — this repo's own numbering convention (REV-04) treats ADR and migration IDs as independent sequences, and a Correction section edits the existing ADR in place, as Phase 12 already did twice |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HOOK-01 | Plan-review gate blocks unconditionally on codex-cli's native `PreToolUse` surface, observed end-to-end in a live human-observed session; supersedes ADR-0009 d.9 | "Exit-Code and JSON Contract" + "Hooks Discovery Order" sections below; SC#2's live-session requirement is explicitly a SPIKE/live-session item, not doc-resolvable — see Spike Protocol step 4 |
| HOOK-02 | New wrapper script reads stdin JSON, derives `--file`, execs `check-plan-review.sh --file <path>`, translates result to `permissionDecision: "deny"` primary path with a guaranteed-non-empty-stderr `exit 2` fallback | "Wrapper Script Design" + "PreToolUse stdin JSON Schema" + "Exit-Code and JSON Contract" sections; the `apply_patch` payload-shape contradiction is flagged as SPIKE-REQUIRED |
| HOOK-03 | New migration installs `PreToolUse` into project-scoped `<repo>/.codex/hooks.json` (merge-don't-clobber, `0000-baseline` Step 6 precedent) and enables the hooks feature flag; verified firing in target repo, not firing in an unrelated repo | "Hooks Discovery Order", "Project-Scoped Config Layering", "Migration 0011 Design" sections; the migration-number and version-bump recommendation is grounded in this repo's own `migrations/` directory state |
| DOC-03 | ADR-0009 dated Correction section: d.9 superseded, d.12 reversed (already done, Phase 12), and the false "global not per-project" claim corrected | "Global-vs-Project-Scoped: The Correction" section gives the exact citation and suggested wording; cross-references what Phase 12 already wrote so DOC-03 doesn't duplicate the existing Reversed marker |
</phase_requirements>

## Project Constraints (repo conventions — no CLAUDE.md present; AGENTS.md + ADR/migration conventions apply with equivalent authority)

- **Never edit an immutable, already-shipped migration file.** Migrations 0000–0010 are immutable; HOOK-03 is a NEW file, next available ID.
- **Migration ID vs ADR ID are independent, always-qualified sequences** (REV-04, `docs/decisions/README.md`). The new migration for HOOK-03 is `migration 0011` (next after `0010-heal-0007-knowledge-capture.md`), and DOC-03 is delivered as an in-place Correction section on the EXISTING `ADR-0009`, not a new ADR number.
- **Templates are the single source of truth for anything shipped to other repos' `AGENTS.md`/config** (the 0007 lesson, reused verbatim in 0008's Steps 2/3). If HOOK-03 needs any `AGENTS.md` ritual text or `config-hooks.json` template changes, they must be extracted from the installed scaffolder templates, never heredoc'd.
- **Leaf-level jq merges only, never shallow group replacement** (migration 0008 Step 1's documented defect and fix). The same discipline applies to merging a `PreToolUse` array into an existing `.codex/hooks.json` that may already carry other tools' hooks for the SAME event — this repo's own dev machine hooks.json proves this is a real, not hypothetical, collision surface (three vendors already share `SessionStart`/`Stop`/etc. arrays there).
- **`set -uo pipefail`, never bare `set -e`, in every gate-adjacent shell script** — a script that dies mid-resolution on an unguarded read is a silent bypass, the exact class of bug this milestone exists to close (T-08-05, carried into `check-plan-review.sh`'s own header comment). The new wrapper script must follow the same discipline.
- **Every terminal path is an explicit `exit 0` or `exit 2`; no other exit code is meaningful** in `check-plan-review.sh`'s existing contract. The wrapper must not introduce a third code without translating it back to one of these two before it reaches codex-cli.
- **CI matrix is ubuntu + macOS** (BSD vs. GNU shell divergence is a standing, named risk — `_canon_dir`, `_mtime` etc. already carry portable idioms for exactly this reason). The wrapper's own `_canon_dir`-style helpers, if any, must reuse the existing portable idioms rather than reinvent them.
- **Migrations are tested via `migrations/run-tests.sh`**, one `test_migration_NNNN` function per migration, executing the migration's own Apply blocks via `extract_step_block` against seeded sandbox fixtures — never a hand-copied transcription (11-02's own lesson, closing a `check-plan-review.sh`-adjacent defect class).

## codex-cli Version and Environment (VERIFIED, this machine)

| Property | Value | Source |
|---|---|---|
| codex-cli version | `0.144.4` (Homebrew install, `0.144.5` available) | `codex --version`, `codex doctor` — VERIFIED live |
| `hooks` feature flag | `stable`, `true` (enabled) on this machine | `codex features list` — VERIFIED live |
| `codex_hooks` legacy alias | still accepted, `true` in this machine's `config.toml` line 1 | VERIFIED live; matches docs' "deprecated alias" note |
| `~/.codex/hooks.json` | exists, already carries THREE unrelated vendors' hooks across `PermissionRequest`, `PostToolUse`, `PreToolUse`, `SessionStart`, `Stop`, `UserPromptSubmit` | VERIFIED live read of this file |
| `~/.codex/config.toml` `[hooks.state.*]` | 11 live `trusted_hash` entries present, auto-managed by `nyx` per an in-file comment | VERIFIED live |
| `[projects.*]` entries | 5 explicit `trust_level = "trusted"` entries, keyed by absolute path | VERIFIED live — **note:** this repo's OWN entry is keyed `/Users/donald/Sourcecode/codex-workflow`, not the current real path `/Users/donald/Sourcecode/agenticapps/codex-workflow` (this repo moved under a family-reorg at some point) — actionable finding, see Pitfall 4 |

This gives the research an unusual advantage over pure documentation research: every claim in the "Hook Trust Ledger" section below that is marked VERIFIED was confirmed against a real, in-production, multi-vendor `hooks.json`/`config.toml` pair on the machine this phase will be planned and executed on — not a synthetic fixture.

## DOC-RESOLVED: Hooks Discovery Order (project vs. global)

**[CITED: developers.openai.com/codex/hooks (redirects to learn.chatgpt.com/docs/hooks), developers.openai.com/codex/config-advanced]**

Codex discovers hooks from four locations, in this documented order of increasing precedence:

1. `~/.codex/hooks.json` (global, JSON file)
2. `~/.codex/config.toml` inline `[[hooks.<Event>]]` tables (global, TOML)
3. `<repo>/.codex/hooks.json` (project-scoped, JSON file)
4. `<repo>/.codex/config.toml` inline `[[hooks.<Event>]]` tables (project-scoped, TOML)

Per a third-party source cross-checked against the above [CITED, MEDIUM: agenticcontrolplane.com/blog/codex-cli-hooks-reference]: **"Both load, with repo entries overriding user entries for matching tools; there's no namespacing."** This means a project-scoped hook does not replace the global file wholesale — both fire — which is consistent with this repo's live `~/.codex/hooks.json` already carrying multiple vendors' entries for the same events without conflict (they are additive arrays per event, not a single winner-take-all key).

**This directly resolves DOC-03's factual correction requirement.** ADR-0009 decision 9 states the native surface is "global rather than per-project." That claim is FALSE as of codex-cli 0.144.4: `<repo>/.codex/hooks.json` and `<repo>/.codex/config.toml` are both documented, real, discovered layers. The correct framing for the Correction section: *global hooks fire in every repo (true, and still a real self-scoping concern for anyone relying on `~/.codex/hooks.json` alone), but project-scoped hooks ALSO exist and are the correct mechanism for a repo-local gate — HOOK-03 uses this project-scoped layer specifically to avoid the self-scoping problem ADR-0009 originally deferred on.*

## DOC-RESOLVED: Project-Scoped Config Layering

**[CITED: learn.chatgpt.com/docs/config-file/config-advanced]**

- `[features] hooks = true` is not on config-advanced's documented list of settings a project `.codex/config.toml` is forbidden from overriding (that list covers credential redirection, host-owned app metadata, provider auth, config profile selection, machine-local notification/telemetry commands — none of which overlap `hooks`). **[ASSUMED, from absence-of-prohibition, not an explicit confirmation]** that `[features] hooks = true` IS settable at project scope. This should be confirmed in the spike (write it, observe whether `codex features list` inside the repo reports `hooks` as enabled via the project layer specifically, distinct from the machine-wide default which is already `true` here).
- Layer precedence (documented): system/managed config → `~/.codex/config.toml` → profile overlay → project `.codex/config.toml` (closest-to-cwd wins if multiple exist on the walk from repo root to cwd) → CLI `-c` overrides. Project config wins over global for a shared key.
- **This repo already has an unrelated, same-named-but-different-purpose file: `.planning/config.codex.json`** (the DECLARATIVE gate binding map migration 0008 maintains — `hooks.pre_execution.plan_review`, etc.). This is NOT the same file as codex-cli's native `<repo>/.codex/hooks.json` or `<repo>/.codex/config.toml`. **Naming collision risk flagged as Pitfall 1 below** — the planner and any implementer must keep these conceptually and physically separate; HOOK-03 does not touch `.planning/config.codex.json` at all (a different concern layer — declarative-binding metadata for OTHER agents reading it, vs. codex-cli's own native enforcement config).

## DOC-RESOLVED (mechanism shape) / SPIKE-REQUIRED (exact values): Hook Trust Ledger

### What is VERIFIED (live machine + partial upstream source, HIGH confidence)

**The trust ledger is TWO SEPARATE GATES, not one:**

**Gate A — project-directory trust.** `~/.codex/config.toml`:
```toml
[projects."/Users/donald/Sourcecode/codex-workflow"]
trust_level = "trusted"
```
`[CITED: learn.chatgpt.com/docs/config-file/config-reference]`: *"Mark a project or worktree as trusted or untrusted (`"trusted"` | `"untrusted"`). Untrusted projects skip project-scoped `.codex/` layers, including project-local config, hooks, and rules."* This is a per-machine, per-absolute-path setting that gates whether the ENTIRE `<repo>/.codex/` layer is even read — config, hooks, and rules together, as one bundle. It cannot be set by a migration running inside the repo (it lives in the operator's home directory, keyed by an absolute path the repo doesn't control).

**Gate B — per-hook trust.** `~/.codex/config.toml`, live-observed on this machine:
```toml
[hooks.state."/Users/donald/.codex/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:b8fc2592cddc67ed4f32e87359a66fbe307c906d09ed12f7685db1b94e2d54bb"
```
`[VERIFIED: live read of this machine's ~/.codex/config.toml]` — 11 such entries exist, each keyed `<hooks.json-absolute-path>:<event-in-snake_case>:<group-index>:<hook-index-within-group>`. This confirms trust is tracked **per individual hook handler entry**, scoped to the specific file it came from — NOT one trust flag for the whole file, and NOT the same record as Gate A.

`[CITED, partial: github.com/openai/codex, codex-rs/config/src/hook_config.rs — HookStateToml struct with `enabled: bool` + `trusted_hash: String` fields; codex-rs/hooks/src/engine/mod.rs — a `ConfiguredHandler::run_id()` method building a key from event-name-label + display-order + source-path, and a comment establishing "hooks must be trusted to execute unless `bypass_hook_trust` is enabled."]` This corroborates the granularity (per-hook, keyed by source path + position) from the upstream Rust source itself, independent of the live-machine observation — two independent confirmations of the same shape.

**Escape hatch (documented, HIGH confidence):** `--dangerously-bypass-hook-trust` — *"Run enabled hooks without requiring persisted hook trust for this invocation. DANGEROUS. Intended only for automation that already vets hook sources."* `[VERIFIED: codex --help, this machine]`. This bypasses Gate B (and possibly Gate A too — SPIKE should confirm which). It is a per-invocation CLI flag, not a persistent state change — not useful for a real end-user's day-to-day session, but directly useful for the spike's own non-interactive testing.

### What is SPIKE-REQUIRED (genuinely not resolvable from docs alone)

1. **Exact hash input.** Is `trusted_hash` computed over the hook's `command` string alone, or over the full serialized hook object (matcher + type + command + timeout + statusMessage)? `[CITED, unconfirmed: openai/codex#21615 — "the trust hash is reproducible from the open-source implementation" but no algorithm/field-list given in the discussion]`. This determines whether HOOK-02's wrapper can change its OWN internal logic post-install without invalidating trust (if hash = command string only, a stable command string with logic delegated to the invoked script — which is exactly this design, since the wrapper execs `check-plan-review.sh` rather than embedding logic inline — is future-proof; changes to `check-plan-review.sh` itself never touch the hash).
2. **Pre-seeding support.** Whether writing a `[hooks.state.<key>] trusted_hash = "..."` entry directly into `~/.codex/config.toml` (matching a hash the wrapper computes itself, offline, using the same algorithm) is a viable install-time strategy for `setup-codex-agenticapps-workflow`/HOOK-03's migration, vs. relying on the interactive startup hooks-review flow (`"1 hook is new or changed. Hooks need review... Trust all and continue"` `[VERIFIED, binary strings: tui/src/startup_hooks_review.rs]`) firing once per install and requiring a human present. **This is explicitly unsupported and undocumented** — openai/codex#21615 is an OPEN issue asking OpenAI to provide a supported version of exactly this, filed by another integrator (`nyx`) who is ALREADY doing the unsupported workaround, visible on this very machine's config.toml. **Recommendation for the plan:** do NOT attempt to pre-seed `trusted_hash` in the migration itself (fragile, undocumented, breaks silently on a codex-cli version bump that changes the hash algorithm). Instead, HOOK-03's migration installs the hooks.json/config.toml content, and the SC#2 live-human-observed-session step is where the human runs `/hooks` (or answers the startup review prompt) once, exactly as any other new-hook install on this machine already requires. Document this as an expected one-time operator action in `AGENTS.md`/migration Notes, not a silent background install.
3. **Default `trust_level` for an unlisted project.** Genuinely undocumented. `[CITED: config-reference — no default stated]`. The spike must observe what codex does on first `codex` invocation inside a repo with no `[projects.<path>]` entry — does it prompt interactively (similar to "trust the files in this folder" flows in other CLI agents), silently default to trusted (plausible, since a bare `codex` session in a git repo with no explicit trust entry has clearly worked historically without an install-time prompt on this machine for OTHER trusted-by-default repos), or silently default to untrusted (which would mean HOOK-03's whole project-scoped install is a no-op until a human separately does something the migration cannot automate)? **This is the single highest-leverage unknown in the whole phase** — if project-scoped hooks are untrusted-by-default and require a manual first-trust step per clone, that changes HOOK-03's whole "verified firing in the target repo" success criterion into "verified firing in the target repo AFTER a one-time human trust step," which must be documented, not silently assumed away.
4. **`apply_patch` PreToolUse coverage — CONTRADICTORY sources, must be settled empirically.** `[CITED, HIGH: developers.openai.com/codex/hooks, via WebFetch]` states: *"For file edits through `apply_patch`, `matcher` values can use `apply_patch`, `Edit`, or `Write`; hook input still reports `tool_name: "apply_patch"`."* This says PreToolUse DOES cover file edits. But `[CITED, MEDIUM: agenticcontrolplane.com/blog/codex-cli-hooks-reference]` states the opposite: *"apply_patch edits are not covered by PreToolUse... recommends expressing edits via shell commands instead."* These two sources directly contradict each other. **This is the single fact HOOK-01/HOOK-02's entire premise depends on** — "a disallowed edit... driven through the real Codex CLI tool surface... is observably prevented" (SC#2) requires PreToolUse to actually see file-edit tool calls, not just `Bash` shell-command calls. The spike (or the live SC#2 session itself, which must happen anyway) MUST empirically confirm which is true on codex-cli 0.144.4 before the wrapper's `matcher` is finalized. If the third-party source is right, the `matcher` must cover `Bash` too (since codex can write files via shell redirects), and the wrapper's file-path derivation logic needs a Bash-command-parsing fallback path, not just an `apply_patch`-payload-parsing path.

## DOC-RESOLVED (HIGH confidence): Exit-Code and JSON Contract

`[CITED: developers.openai.com/codex/hooks via WebFetch, cross-checked against agenticcontrolplane.com and GitHub search snippets]`

- **Primary path — explicit JSON on stdout:**
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Destructive command blocked."
    }
  }
  ```
  This is the shape HOOK-02 names as "the primary path." `permissionDecision` can presumably also be `"allow"` (not directly quoted in the sources fetched, but implied by the enum name — verify in spike if the wrapper ever needs to emit an explicit allow rather than silent-exit-0).
- **Fallback path — exit code 2 + stderr:** *"You can also use exit code `2` and write the blocking reason to `stderr`."* This is the shape HOOK-02 names as the fallback, and the one SC#3's mutation test targets.
- **Exit code 0 / empty stdout:** *"Empty stdout is treated as a no-op success, allowing the tool call to proceed"* `[CITED, MEDIUM: search-result synthesis, cross-source]` — i.e., the wrapper does not need to emit anything on the allow path; a bare `exit 0` with no stdout is sufficient. This matches `check-plan-review.sh`'s own existing exit-0 contract exactly, so the wrapper's allow path is a pure passthrough.
- **Whether stderr is surfaced to the user/model:** `[CITED, explicitly incomplete: learn.chatgpt.com/docs/hooks via WebFetch]` — *"Stderr text is recorded but not explicitly surfaced to user/model in documented behavior."* **SPIKE-REQUIRED**: confirm in the live SC#2 session whether the operator actually SEES the block reason, or only sees a generic "tool call denied" with no text. This affects how much the `_cpr_block()`-style reason text in `check-plan-review.sh` actually reaches a human, and whether the wrapper needs to duplicate that reason into the `permissionDecisionReason` JSON field (primary path) specifically BECAUSE stderr on the fallback path is not guaranteed to be shown — which would make the primary-path-first design choice in HOOK-02 not just a nicety but load-bearing for operator visibility.
- **Precedence between JSON and exit code if a hook emits both:** not found in any source fetched. **SPIKE-REQUIRED** if the wrapper's design ever risks emitting both (it should not, by construction — HOOK-02's "primary path... with any exit-2 fallback path" phrasing already implies mutual exclusion: emit the JSON deny, OR fall back to bare exit 2, never both in the same invocation).

## DOC-RESOLVED (HIGH confidence): `PreToolUse` stdin JSON Schema

`[CITED: developers.openai.com/codex/hooks via WebFetch]`

Common fields across all hook events: `session_id`, `cwd`, `hook_event_name`, `model`, `permission_mode`, `transcript_path`.
`PreToolUse`-specific: `turn_id`, `tool_name`, `tool_use_id`, `tool_input` (a JSON value whose shape depends on `tool_name`).

For `Bash`: `tool_input.command` holds the shell command string. `[CITED, worked example from third-party source]`:
```python
payload = json.load(sys.stdin)
command = payload["tool_input"]["command"]
```

For `apply_patch`: the exact shape of `tool_input` was NOT resolved by any source fetched (neither official docs nor the third party gave the field name — official docs only confirm `tool_name: "apply_patch"` is reported, not what `tool_input` contains). **SPIKE-REQUIRED**: capture one real `apply_patch` PreToolUse payload (e.g. by pointing a throwaway hook at `cat >> /tmp/payload.log` and triggering a file edit) to see whether the patch text is under `tool_input.input`, `tool_input.patch`, or something else, and whether it contains a clean, parseable file path (codex's `apply_patch` format traditionally uses `*** Update File: <path>` / `*** Add File: <path>` header lines inside a text blob — if so, HOOK-02's `--file` derivation needs a small parser for that format, not a simple JSON-field lookup).

**Command templating:** `[CITED: agenticcontrolplane.com, cross-checked against HOOK-02's own requirement text]` — `hooks.json` `command` values are static strings with no per-invocation templating. This matches HOOK-02's premise exactly ("hooks.json `command` is a static string with no templating") and is why the wrapper reads the file path from **stdin JSON**, not from a templated argument.

## DOC-RESOLVED: Wrapper Script Design (HOOK-02)

Recommended shape, informed by the above and by `check-plan-review.sh`'s existing conventions (reuse, don't reinvent):

```bash
#!/usr/bin/env bash
# hook-wrapper-plan-review.sh — codex-cli PreToolUse adapter for check-plan-review.sh
set -uo pipefail

PAYLOAD="$(cat)"                      # stdin JSON, read once
TOOL_NAME="$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty')"

# --- derive --file, best-effort; absence of a derivable path is NOT an error ---
CPR_FILE=""
case "$TOOL_NAME" in
  apply_patch)
    # SPIKE-REQUIRED: exact tool_input field + patch-header parsing (see above)
    CPR_FILE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.<FIELD_TBD> // empty' | \
                sed -n 's/^\*\*\* \(Update\|Add\) File: //p' | head -1)"
    ;;
  Bash)
    # only if the apply_patch-not-covered hypothesis is confirmed true in the
    # spike; otherwise this branch is dead code and should be removed, not
    # left in as speculative complexity
    ;;
esac

if [ -n "$CPR_FILE" ]; then
  OUT="$("${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/check-plan-review.sh" --file "$CPR_FILE" 2>&1 1>/dev/null)"
else
  OUT="$("${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/check-plan-review.sh" 2>&1 1>/dev/null)"
fi
RC=$?

if [ "$RC" -eq 0 ]; then
  exit 0   # allow, no output needed — matches check-plan-review.sh's own contract
fi

# BLOCK — primary path: explicit deny JSON on stdout.
REASON="$(printf '%s' "$OUT" | tr '\n' ' ' | sed 's/"/\\"/g')"
if [ -n "$REASON" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$REASON"
  exit 0
fi

# FALLBACK — SC#3's target. Reachable ONLY if $OUT was somehow empty (the
# underlying check-plan-review.sh contract guarantees _cpr_block() always
# writes a reason before exit 2, so this should be unreachable in practice —
# but "should be unreachable" is exactly the class of assumption this
# milestone's mutation-testing discipline exists to not trust blindly).
echo "plan-review hook wrapper: BLOCKED (exit 2) — check-plan-review.sh exited $RC with no captured reason; blocking closed, not open" >&2
exit 2
```

**Mutation test for SC#3:** comment out (or `>/dev/null`-redirect) the `echo ... >&2` line in the fallback branch, run a fixture that forces the fallback path (e.g. stub `check-plan-review.sh` to exit 2 with empty stdout+stderr), and assert the wrapper's own stderr is non-empty whenever its exit code is 2 — RED when the echo is removed, GREEN when restored. This is testable as a pure shell unit test with a stubbed `check-plan-review.sh`, **no live codex-cli invocation required** — consistent with this repo's existing `migrations/run-tests.sh` fixture-and-stub pattern (e.g. `test_migration_0008`'s no-scaffolder-tree fixture).

**Don't hand-roll:** JSON construction. This repo's migrations already depend on `jq` (migration 0008's pre-flight hard-requires it); the wrapper should too, both for reading stdin and — if REASON text needs proper JSON-string escaping beyond the `sed` above — for building the output JSON (`jq -n --arg reason "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'` is safer than hand-escaping quotes).

## DOC-RESOLVED: Migration 0011 Design (HOOK-03)

- **Next migration ID: `0011`.** `[VERIFIED: ls migrations/*.md, this repo]` — highest existing file is `0010-heal-0007-knowledge-capture.md` (a version-backport, `to_version: 0.5.0`, deliberately not the drift target per Phase 11's own decision log). The real drift target / highest `to_version` across the chain is migration `0009-spec-11-region-aware-placement.md`'s `0.7.0`, matching this repo's own `.codex/workflow-version.txt` (`0.7.0`, VERIFIED). **Recommendation, not a locked decision:** migration `0011` should carry `from_version: 0.7.0, to_version: 0.8.0`, consistent with this being the milestone's own version (`v0.8.0`) and with `test_drift`'s semver-max convention (Phase 11's own fix, `0011`'s `to_version` becomes the new drift target and this repo's own scaffolder trigger skill version must bump in lockstep, exactly as 0008/0009 did).
- **Two files to write/merge**, both genuinely new (this repo does not currently have either):
  1. `<repo>/.codex/hooks.json` — the codex-cli NATIVE format (top-level `{"hooks": {"PreToolUse": [...]}}`), containing ONE new entry pointing at the wrapper script. **Must merge, not clobber**, per `0000-baseline.md` Step 6's own precedent (append-if-absent to a global `AGENTS.md`, idempotency-checked) and per this repo's OWN live dev-machine `~/.codex/hooks.json` proving multiple tools legitimately share one file's per-event arrays. A target project MAY already have a `.codex/hooks.json` from an unrelated tool (this is not hypothetical — this exact machine has one) — the merge must be a `jq` array-append onto `.hooks.PreToolUse`, matched by the wrapper's own command string for idempotency (re-running must not duplicate the entry), analogous to migration 0008 Step 1's leaf-level jq merge discipline.
  2. `<repo>/.codex/config.toml` — set `[features] hooks = true` at PROJECT scope (not touching the operator's `~/.codex/config.toml` at all — see "Project-Scoped Config Layering" above). If the file doesn't exist, create it; if it exists (e.g., an operator already has project-scoped MCP/sandbox settings there), merge only the `[features]` table, don't clobber other tables. **This is a NEW file type for this repo's migrations** — 0000-baseline and 0008 only ever wrote `.codex/workflow-config.md`, `.codex/workflow-version.txt`, `.planning/config.json`/`.planning/config.codex.json`, and `AGENTS.md`. TOML merging needs either `jq`-via-a-toml-shim (not standard) or a small `python3 -c` / `awk` block-append (append-a-table-if-absent, matching the pattern `AGENTS.md`'s marker-block insertion already uses for idempotent section insertion). Recommend the awk append-if-absent pattern over introducing a new TOML-parsing dependency.
- **"Verified firing in the target repo AND NOT firing in a second unrelated repo"** (SC#4) is directly testable without a live codex session for the NOT-firing half (a second repo with no `.codex/hooks.json` obviously has no entry — trivial), but the FIRING half requires either (a) a live human-observed session (SC#2 already requires this) or (b) `codex exec --dangerously-bypass-hook-trust` in a scripted fixture that captures whether the wrapper was invoked (e.g. by having the wrapper append to a log file as a side effect during the test only, gated behind a test-only env var — do not ship that logging in the real wrapper). **Recommend using the SC#2 live session to also produce SC#4's positive evidence**, rather than building a second, parallel automation path for a live-CLI fact that already requires a human present once.

## Global-vs-Project-Scoped: The Correction (DOC-03)

Exact citation to record in ADR-0009's Correction section, cross-referenced so it does not duplicate Phase 12's existing Reversed markers on decisions 12 (WR-03) and does not touch decision 11 (unrelated):

> **Correction (Phase 13, HOOK-01/DOC-03), dated 2026-07-17+.** Decision 9's claim that Codex's native `PreToolUse` surface is "global rather than per-project" is FALSE as of codex-cli 0.144.4 and should not be relied on going forward: `<repo>/.codex/hooks.json` and `<repo>/.codex/config.toml` are both documented, discovered, project-scoped layers (developers.openai.com/codex/hooks, developers.openai.com/codex/config-advanced), loaded in addition to the global `~/.codex/hooks.json`/`~/.codex/config.toml` layers, with project entries taking precedence on conflict. This correction does not retroactively validate decision 9's REJECTION of option B at the time — the trust-ledger and self-scoping concerns decision 9 named were real (see Phase 13's own spike findings) — but the specific factual premise "global, not per-project" no longer holds, and HOOK-01 supersedes decision 9's agent-mediated-only design using exactly the project-scoped layer decision 9 believed did not exist. Decision 12 (the `--file` symlink-traversal limitation) was already reversed by Phase 12 (see the existing Reversed marker inline on decision 12, 2026-07-17) — this Correction section records that reversal's existence for the dated-Correction-section requirement (DOC-03) without repeating its content.

## Common Pitfalls

### Pitfall 1: Two files named similarly, two entirely different systems
**What goes wrong:** `.planning/config.codex.json` (this repo's existing declarative gate-binding map, host-scoped, read by AGENTIC AGENTS as advisory config) gets confused with `<repo>/.codex/hooks.json` / `<repo>/.codex/config.toml` (codex-cli's OWN native, binding, runtime-enforced config). They live in different directories (`.planning/` vs `.codex/`), serve different consumers (agent-read convention vs. CLI-enforced), and HOOK-03 only ever touches the latter.
**Why it happens:** Both have "codex" and "config" in the name; both are JSON/JSON-ish; both live in this same repo.
**How to avoid:** Name the new migration's `applies_to` frontmatter explicitly as `.codex/hooks.json` and `.codex/config.toml` (with the leading dot, distinct from `.planning/config.codex.json`), and never let a task description abbreviate either as just "the config file."
**Warning signs:** A diff that touches `.planning/config.codex.json` inside a plan whose stated goal is the native hook install is very likely a mistake.

### Pitfall 2: Assuming `apply_patch` is covered by `PreToolUse` without checking this version
**What goes wrong:** The wrapper's `matcher`/parsing logic is built entirely around `apply_patch`, and file edits silently never trigger the hook at all — an unconditional-looking gate that is actually a no-op for the exact tool call it exists to block.
**Why it happens:** Official docs say yes; at least one independent, plausible-sounding source says no. Both cannot be simultaneously true for the same version, and only a live session on THIS installed codex-cli version resolves it.
**How to avoid:** Resolve this in the spike or as the very first check of the SC#2 live session, before any other wrapper behavior is validated. If `apply_patch` is not covered, the matcher needs `Bash` too (codex can edit files via shell), and the `--file` derivation needs a shell-command-parsing fallback.
**Warning signs:** A "successful" SC#2 session where the block only ever happens for `Bash`-tool edits, never for a direct file-write tool call, and nobody checked whether that gap is expected or a silent gate failure.

### Pitfall 3: Treating `--dangerously-bypass-hook-trust` or pre-seeded `trusted_hash` as a supported install mechanism
**What goes wrong:** The migration or `setup-codex-agenticapps-workflow` silently writes a `trusted_hash` entry into the OPERATOR's `~/.codex/config.toml` to skip the interactive trust prompt, mirroring the `nyx`/`termloop` workaround visible on this machine — and it breaks silently on the next codex-cli version bump that changes the hash algorithm, with no signal to the operator that their gate quietly stopped enforcing anything (a hash mismatch just means "not trusted," which per Gate B semantics means the hook is SKIPPED, not blocked — the exact fail-open shape this milestone exists to close).
**Why it happens:** It is technically possible today (openai/codex#21615 confirms other tools do it), and skipping a one-time human approval step is tempting for a "fully automated install" narrative.
**How to avoid:** Treat the one-time interactive trust step (via `/hooks` or the startup hooks-review prompt) as an explicit, documented operator action in the migration's Notes/`AGENTS.md`, not something the migration silently works around. This is consistent with `check-plan-review.sh`'s own existing philosophy of never silently authorizing itself around a human decision point.
**Warning signs:** A migration Apply block that writes to `${CODEX_HOME}/config.toml` (the OPERATOR's global file) rather than only to `<repo>/.codex/*` (the PROJECT's files) — this repo's migrations have never done the former, and HOOK-03 should not be the first.

### Pitfall 4: This repo's own project-trust entry is stale (family reorg)
**What goes wrong:** This exact repo, `codex-workflow`, is trusted on this machine under its OLD path (`/Users/donald/Sourcecode/codex-workflow`), not its CURRENT real path (`/Users/donald/Sourcecode/agenticapps/codex-workflow`, per the family-directory reorg documented in `~/Sourcecode/CLAUDE.md`). A live SC#2 session run from the current path may hit an untrusted-project prompt that has nothing to do with the phase's own work, and could be misdiagnosed as a hook-install failure.
**Why it happens:** `[projects.<path>]` is keyed by absolute path, verbatim; a directory move invalidates the entry with no automatic migration.
**How to avoid:** Before running the SC#2 live session, check `codex doctor` (which already reports the resolved "repo root" — VERIFIED it correctly reports `~/Sourcecode/agenticapps/codex-workflow` today) and confirm project trust status for THAT exact path, re-trusting if needed, as a pre-flight step separate from anything HOOK-03 installs.
**Warning signs:** An "untrusted project" prompt appearing during the live session that seems unrelated to the newly-installed hook.

## Spike Protocol (Success Criterion 1) — exact steps for the spike plan to execute

This researcher did not run this protocol (deliberately, per this phase's own task boundary — running `codex exec` against a live account has quota/cost implications the operator should consent to explicitly, and the interactive trust/review flow cannot be scripted around without defeating the point of observing it). The spike PLAN (a distinct plan from the wrapper/migration plan) should execute exactly this:

1. **Confirm current environment state first** (cheap, no live codex invocation): `cat ~/.codex/config.toml | grep -A2 'projects\."'$(pwd)'"'` — resolve Pitfall 4 before anything else.
2. **Author a known, trivial hook** in a SCRATCH git repo (not this repo, not `~/.codex/hooks.json` — do not touch the machine's real multi-vendor hooks file): `mkdir -p /tmp/spike-repo/.codex && git -C /tmp/spike-repo init` (if not already a git repo), then write `.codex/hooks.json` with one `PreToolUse` entry whose command is something observably harmless and logging (e.g. `echo "$(date) fired" >> /tmp/spike-repo/.codex/fired.log; cat`).
3. **Observe project-trust default:** run a trivial `codex` command inside `/tmp/spike-repo` BEFORE adding any explicit `[projects."/tmp/spike-repo"]` entry to `~/.codex/config.toml`. Record: was there an interactive trust prompt? Did the hook fire on the first run, or only after an explicit trust action? This resolves SPIKE-REQUIRED item 3 above.
4. **Trust the hook via the documented flow** (`/hooks` inside an interactive `codex` session, or observe the startup hooks-review prompt — `"1 hook is new or changed... Trust all and continue"`). Immediately after, `diff` a saved pre-trust copy of `~/.codex/config.toml` against the post-trust version — this reveals BOTH the exact `[hooks.state.<key>]` entry format for THIS specific hook (confirming or refuting the 4-segment key format already observed for `nyx`'s entries) AND whether a SEPARATE `[projects."/tmp/spike-repo"]` entry was also written at the same time (resolving whether Gate A and Gate B get set together by one interactive action, or require two distinct actions) — this directly resolves SPIKE-REQUIRED item 2 (one gate or two, from the install-flow perspective, complementing the doc-level "two gates exist" finding above with "how many operator actions does installing one project-scoped hook actually require").
5. **Compute the hash offline and compare.** With the trusted entry's exact hook JSON object in hand from `/tmp/spike-repo/.codex/hooks.json`, try `sha256sum` over (a) just the `command` string, (b) the whole hook object as compact JSON, (c) the whole hook object as normalized TOML (per the binary string "normalized hook identity should serialize to TOML"). Whichever matches `trusted_hash` resolves SPIKE-REQUIRED item 1 definitively.
6. **Test the untrusted-project case**: in a SECOND scratch repo `/tmp/spike-repo-2` with the SAME hooks.json content but no trust action taken, confirm the hook does NOT fire, and note whether codex reports WHY (untrusted project vs. untrusted hook — the error/status text, if any, should distinguish Gate A from Gate B failures).
7. **Test `apply_patch` coverage directly** (resolves Pitfall 2 / SPIKE-REQUIRED item 4): with the trusted hook now capturing full stdin to a log file (`cat >> /tmp/spike-repo/.codex/payload.log`), run a `codex` session (interactive, human-observed, satisfying part of SC#2 at the same time) that performs one file-creating edit via whatever tool codex naturally chooses, and inspect the captured payload for `tool_name` and the exact `tool_input` shape — this is also where the exit-code/stderr-surfacing question (does the human SEE the block reason) gets its first real observation, by then changing the hook to actually deny and re-running.
8. **Freeze findings** into a short spike-note (not a full RESEARCH.md rewrite) before the wrapper/migration plan starts, per ROADMAP's own instruction ("findings recorded before the wrapper/migration design is finalized").

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Project-scoped `[features] hooks = true` in `<repo>/.codex/config.toml` is settable (inferred from absence-of-prohibition in config-advanced's explicit deny-list, not an affirmative statement) | Project-Scoped Config Layering | If wrong, HOOK-03 must instead document a one-time operator action to set the flag globally, weakening "installs... and enables the hooks feature flag" to "installs... and instructs the operator to enable" |
| A2 | `permissionDecision` also accepts `"allow"` as an explicit value (inferred from the enum name pattern, not directly quoted from any source) | Exit-Code and JSON Contract | Low risk — the wrapper's allow path is designed as a silent `exit 0`, which is independently confirmed sufficient; this assumption is not load-bearing for the current design |
| A3 | The wrapper's fallback exit-2 path (empty `check-plan-review.sh` stdout+stderr) is realistically unreachable given `check-plan-review.sh`'s own `_cpr_block()` discipline, but is still worth defending with its own stderr write | Wrapper Script Design | If check-plan-review.sh's contract ever regresses to a silent exit 2 (no `_cpr_block()` call on some new path), the wrapper's fallback is the only remaining fail-safe — worth the mutation test regardless of how "unreachable" it looks today |
| A4 | The `--dangerously-bypass-hook-trust` flag bypasses ONLY Gate B (per-hook trust), not also Gate A (project trust) | Hook Trust Ledger | Unconfirmed either way in any source fetched; affects how the spike's non-interactive testing (step 3/6 above) should be scripted — flagged inline in the Spike Protocol as something to observe, not assume |

**If this table were empty:** it is not — four claims above need confirmation, none of them block the DOC-RESOLVED sections from being usable for planning, but A1 in particular should be confirmed early in the spike since it changes HOOK-03's Apply-block shape.

## Open Questions (RESOLVED — see 13-01 spike / 13-02 wrapper design)

1. **Does the wrapper need a `Bash`-command-parsing fallback, or is `apply_patch` matcher coverage sufficient?** *(RESOLVED — routed to the 13-01 spike's Matcher decision, which 13-02/13-03 read before finalizing matcher/parse logic.)*
   - What we know: official docs say `apply_patch`/`Edit`/`Write` are valid matcher values and `tool_name: "apply_patch"` is reported for patch-based edits; one third-party source disputes this entirely.
   - What's unclear: which is true for codex-cli 0.144.4 specifically, and whether `Edit`/`Write` are actual distinct `tool_name` values or just alternate `matcher` spellings for the same `apply_patch` tool.
   - Recommendation: resolve in spike step 7; do not write the Bash-parsing fallback branch until the spike confirms it's needed (avoid speculative complexity in the wrapper).

2. **What exactly does `check-plan-review.sh` need for a `--file` value derived from an `apply_patch` payload, given the script's own existing `--file` bypass logic (basename allowlist: `*PLAN.md`, `*REVIEW[S].md`, etc.)?** *(RESOLVED — `--file` is a nice-to-have, not required: the wrapper's "else, call without --file" branch (implemented in 13-02) blocks correctly via the core resolver regardless.)*
   - What we know: the existing bypass logic is designed around a plan/review-shaped filename; an arbitrary file edit (the kind HOOK-01 needs to demonstrably BLOCK) will almost never match that allowlist, meaning most real edits will fall through the bypass and hit the resolver/grandfather/REVIEWS.md-evidence path — which is exactly the intended behavior for a BLOCKING demo (SC#2 needs a disallowed edit to be blocked, and a disallowed edit is, by definition, not a plan/review file).
   - What's unclear: whether `--file` is even necessary for SC#2's demo to work, since `check-plan-review.sh` already resolves and blocks based on phase state with or without `--file` (the flag only affects the bypass-list fast path, not the core resolver).
   - Recommendation: the wrapper should call `check-plan-review.sh` correctly whether or not it could derive a `--file` value (already reflected in the wrapper design above, which has an explicit "else, call without --file" branch) — `--file` is a nice-to-have for bypass-list precision, not a hard requirement for the gate to function.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| codex-cli | HOOK-01/02/03 entire phase | ✓ | 0.144.4 (0.144.5 available) | — |
| `hooks` feature flag | HOOK-01/03 | ✓ (globally, this machine) | `stable`, `true` | Project-scoped `[features] hooks = true` per A1, if the global default cannot be relied on for every operator |
| `jq` | HOOK-02 wrapper, HOOK-03 migration | ✓ (already a hard pre-flight dependency of migration 0008) | — | None needed — already a proven repo dependency |
| `git` | migration pre-flight, spike scratch repos | ✓ | 2.50.1 | — |
| An interactive `codex` session for the human-observed block (SC#2) and the trust-approval step | HOOK-01, spike step 4/7 | Requires operator presence; cannot be scripted/automated away | — | None — this is inherent to the milestone's own SC#2 wording ("live human-observed session") |

**Missing dependencies with no fallback:** none identified — every technical dependency this phase needs is already present and proven on the development machine.

**Missing dependencies with fallback:** none beyond the project-scoped-vs-global `hooks` feature flag question (A1), which has a documented fallback (operator sets it globally once) if project-scoping turns out unsupported.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | Bash fixture/assertion harness, `migrations/run-tests.sh` (5417 lines, `test_migration_NNNN` / `test_check_plan_review_*` naming convention) |
| Config file | none — the harness is the single hand-written script; no external test framework config |
| Quick run command | `bash migrations/run-tests.sh` (full suite; the harness does not currently expose a `--filter`-by-name flag in evidence gathered — confirm at plan time whether one exists before assuming a "quick" subset run is possible) |
| Full suite command | `bash migrations/run-tests.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| HOOK-02 (SC#3) | Wrapper's exit-2 fallback always writes non-empty stderr; mutation empties it → RED, restore → GREEN | unit (shell, stubbed `check-plan-review.sh`) | new `test_hook_wrapper_stderr_contract` in `migrations/run-tests.sh` | ❌ Wave 0 — new test, wrapper script does not exist yet |
| HOOK-03 | Migration 0011 installs merge-don't-clobber into a fixture `.codex/hooks.json` carrying a pre-existing unrelated vendor's entries, idempotent re-apply is a no-op | unit (extract_step_block + jq assertions, following 0008's own test pattern) | new `test_migration_0011` in `migrations/run-tests.sh` | ❌ Wave 0 |
| HOOK-01 (SC#2) | Real, live-CLI, human-observed block | manual-only (justified: no automated harness can drive an actual interactive codex session's approval/edit UI) | N/A — human runs `codex` in the target repo, attempts a disallowed edit, observes denial | N/A |
| HOOK-03 (SC#4, positive half) | Binding fires in target repo | manual-only or scripted via `codex exec --dangerously-bypass-hook-trust` if the spike confirms that flag is safe for this purpose | recommend folding into the SC#2 live session rather than a second automation path (see Migration 0011 Design) | N/A |
| HOOK-03 (SC#4, negative half) | Binding does NOT fire in an unrelated second repo | trivial, automatable | a second scratch repo with no `.codex/hooks.json` — assert absence | ❌ Wave 0, but trivial to add |
| DOC-03 | ADR-0009 Correction section present, dated, references the correct decisions | contract-style grep assertion, following Phase 12's own pattern for its Reversed markers | grep-based assertion in a new or existing ADR-content test | ❌ Wave 0 if this repo doesn't already grep-assert ADR content (check at plan time — Phase 12 may have added a precedent) |

### Sampling Rate
- **Per task commit:** `bash migrations/run-tests.sh` (the harness has no documented fast/filtered mode found in this research — confirm before assuming a cheaper per-commit loop is available; if none exists, the "quick run" and "full suite" commands are identical, which is itself worth flagging to the planner as a possible Wave 0 gap: a `--filter` flag would materially speed up TDD cycles for this phase's new tests).
- **Per wave merge:** full suite green.
- **Phase gate:** full suite green before `/gsd-verify-work`, plus the one irreducibly manual SC#2/SC#4-positive live session.

### Wave 0 Gaps
- [ ] `test_hook_wrapper_stderr_contract` — covers HOOK-02/SC#3, needs the wrapper script to exist first (natural TDD ordering: write the RED test against a not-yet-existing wrapper, or against a stub, then implement)
- [ ] `test_migration_0011` — covers HOOK-03, follows 0008/0009/0010's own established fixture pattern (seed sandbox, extract Apply blocks via `extract_step_block`, assert idempotent re-run)
- [ ] Negative-repo fixture for SC#4 — trivial addition, no new infrastructure needed
- [ ] Confirm whether `migrations/run-tests.sh` supports filtering a single test by name (checked but not conclusively found in this research pass — worth a 30-second check at plan time before assuming a slow full-suite-only TDD loop)

*(No framework install needed — the harness and its conventions are already fully established across four prior migrations' tests.)*

## Security Domain

`security_enforcement` config key not found in `.planning/config.json` — absent means enabled per the governing instruction; this section is included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | No | This phase concerns tool-call authorization within an already-authenticated CLI session, not user auth |
| V3 Session Management | No | Not applicable |
| V4 Access Control | Yes | The entire phase IS an access-control mechanism (blocking a disallowed tool call); the "control" here is codex-cli's own native trust ledger + this repo's existing `check-plan-review.sh` resolver — HOOK-02 must not weaken either by, e.g., swallowing a non-zero `check-plan-review.sh` exit code as an allow |
| V5 Input Validation | Yes | The wrapper parses untrusted-shaped stdin JSON (a tool call's own arguments, potentially attacker-influenced if a prompt-injection scenario ever crafts a malicious `apply_patch`/`Bash` payload) — use `jq` for all field extraction, never naive string-splitting, and treat a malformed/unexpected JSON shape as "no derivable `--file`," never as a crash that could produce an unhandled exit code outside the `{0, 2}` contract |
| V6 Cryptography | No | The sha256 trust-hash mechanism is entirely codex-cli's own internal concern; this phase never computes, verifies, or stores a hash itself (per Pitfall 3's recommendation against pre-seeding) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Wrapper crashes/exits with an undocumented code on malformed stdin, and codex-cli's own runner treats an unrecognized exit code as allow (unconfirmed, but the milestone's own "nemesis" framing suggests this class of failure is the exact one to guard against) | Tampering / Repudiation of the gate's own guarantee | `set -uo pipefail` + explicit `{0, 2}`-only exit contract, mirroring `check-plan-review.sh`'s own existing header-comment discipline; never let an unguarded `jq` failure (missing field, malformed JSON) propagate as a non-{0,2} exit code |
| A malicious or malformed `apply_patch` payload crafted specifically to produce a `--file` value that re-triggers `check-plan-review.sh`'s own already-closed WR-03 symlink-escape hole via a NEW path (the wrapper introduces a second call site for a value that flows into `--file`) | Tampering | The wrapper does not need to re-implement any path-safety logic — `check-plan-review.sh --file <path>` already runs its own WR-03-hardened canonicalize-and-contain guard on whatever is passed; the wrapper's ONLY job is deriving the value, not validating it — do not add a second, redundant (and possibly weaker) path check in the wrapper itself |
| Interactive trust-approval fatigue (a human clicking "Trust all and continue" reflexively without reading, because a legitimate hook update requires re-approval too often) — a known, named upstream concern (openai/codex#21615) | Elevation of Privilege (a human trained to always-approve becomes a bypass) | Keep the wrapper's own command string maximally stable (it execs an external script rather than embedding logic inline, specifically so future gate-logic changes in `check-plan-review.sh` never touch the wrapper's own trusted_hash) — already reflected in the wrapper design above |

## Sources

### Primary (HIGH confidence)
- Live inspection, this machine: `~/.codex/config.toml`, `~/.codex/hooks.json`, `codex --version`, `codex doctor`, `codex features list`, `codex exec --help` — VERIFIED, ground truth, not documentation
- `strings /opt/homebrew/bin/codex` (binary strings of the installed codex-cli 0.144.4) — VERIFIED, surfaced the embedded Codex-self-knowledge doc-routing prompt, the `startup_hooks_review.rs` trust-review flow strings, `HookOutputEntry`/`Managed`/`Untrusted`/`Trusted` enum strings, and the `TrustLevel` `trusted`/`untrusted` enum
- developers.openai.com/codex/hooks (redirects to learn.chatgpt.com/docs/hooks) — official Codex hooks documentation, fetched via WebFetch
- developers.openai.com/codex/config-advanced (redirects to learn.chatgpt.com/docs/config-file/config-advanced) — official advanced config documentation
- learn.chatgpt.com/docs/config-file/config-reference — official config reference (project trust_level, layering precedence)
- This repo's own `docs/decisions/0009-plan-review-gate.md`, `docs/briefs/plan-review-gate.md`, `migrations/0000-baseline.md`, `migrations/0008-plan-review-gate.md`, `skills/agentic-apps-workflow/scripts/check-plan-review.sh`, `skills/setup-codex-agenticapps-workflow/templates/config-hooks.json`, `install.sh`, `docs/decisions/README.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`

### Secondary (MEDIUM confidence)
- github.com/openai/codex/issues/21615 ("Provide a supported way for local IDE/wrapper installers to request trust for installed hooks") — open, unresolved, confirms the pre-seeding workaround exists and is unsupported
- github.com/openai/codex/issues/27133 ("Project-level .codex/hooks.json is silently ignored when Codex runs inside a git worktree") — open, unresolved; relevant if this repo or its operators ever use git worktrees with this hook
- github.com/openai/codex source references via search snippets: `codex-rs/config/src/hook_config.rs` (`HookStateToml` struct), `codex-rs/hooks/src/engine/mod.rs` (`ConfiguredHandler::run_id()`, `bypass_hook_trust` check) — partial, not full file content, corroborates but does not fully resolve the exact hash algorithm
- agenticcontrolplane.com/blog/codex-cli-hooks-reference — third-party guide; useful for the discovery-order merge behavior and the JSON-stdin worked example, but CONTRADICTS official docs on `apply_patch` coverage — treat its `apply_patch` claim as unresolved, not authoritative
- deepwiki.com/openai/codex/3.11-hooks-system — AI-generated source-code summary, useful for locating the right files, not a primary source itself

### Tertiary (LOW confidence)
- None retained as load-bearing — every claim above is either VERIFIED live, CITED to an official doc, or explicitly marked SPIKE-REQUIRED/ASSUMED in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack / hooks schema: HIGH — official docs plus live-machine ground truth agree
- Trust ledger shape (two gates, per-hook granularity): HIGH — live observation + partial upstream source code agree independently
- Trust ledger exact values (hash algorithm, default trust_level): LOW/SPIKE-REQUIRED — genuinely undocumented, no source resolved it
- `apply_patch` PreToolUse coverage: MEDIUM, CONTRADICTED — official docs say yes, one third-party source says no; flagged as the single highest-priority spike question
- Wrapper/migration design: HIGH — grounded entirely in this repo's own existing, proven conventions (check-plan-review.sh, migration 0008, 0000-baseline Step 6)
- Architecture/install precedent: HIGH — merge-don't-clobber pattern already proven three times in this repo (0000 Step 6, 0007, 0008)

**Research date:** 2026-07-17
**Valid until:** 7 days (codex-cli is fast-moving — 0.144.5 was already available during this research session; any version bump could change hash algorithm details, feature-flag defaults, or the apply_patch coverage question)
