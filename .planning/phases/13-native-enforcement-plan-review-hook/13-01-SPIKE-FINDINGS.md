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

> **STATUS: COMPLETE — 2026-07-18.** Every block below carries a real, dated observation
> from human-observed live `codex` sessions (STEP 3/4/6/7) plus the A1 layer test.

### STEP 3 — default trust_level for an unlisted project (recorded 2026-07-18)
_Ran interactive `codex` inside `spike-repo` (no `[projects."…spike-repo"]` entry yet)
and asked it to run `echo hello-from-spike`._

- **Observation:** Default for an unlisted/untrusted project is **PROMPT — not
  silent-trusted, not silent-untrusted.** On startup codex surfaced **BOTH** a
  project-trust prompt (Gate A) **and** a "1 hook is new or changed… Trust all and
  continue" hooks-review prompt (Gate B). The hook did **not** fire until the operator
  approved trust. After approval the `echo` tool call ran and the hook fired
  (`fired.log`: `Sat Jul 18 10:45:15 CEST 2026 fired in spike-repo`).
- **PreToolUse fires on shell/Bash tool calls** — confirmed by the hook firing on a
  plain `echo` (relevant to the Matcher decision; apply_patch coverage still tested in
  STEP 7).
- **⚠ Decisive side-finding — an invalid-output hook FAILS OPEN.** The fixture command
  ended in `; cat`, which echoed the raw stdin JSON to stdout. codex reported
  **"PreToolUse hook (failed) — error: hook returned invalid pre-tool-use JSON output"**
  and **still ran the command** (`Ran echo hello-from-spike → hello-from-spike`). So a
  malformed/garbage-stdout hook does NOT block — the tool proceeds. This makes HOOK-02's
  contract load-bearing: the allow path must emit **empty stdout / silent `exit 0`**, and
  the deny path must emit **strictly valid `permissionDecision` JSON OR a clean
  `exit 2`** — never partial/invalid stdout, or the gate silently fails open.

### STEP 4 — trust flow + ledger diff (recorded 2026-07-18)
_Approved the startup trust flow, then diffed the saved pre-trust `config.toml` copy
against the post-trust file._

- **Path canonicalization:** codex writes both keys under the **real** path
  (`/private/tmp/…`, macOS resolving `/tmp` → `/private/tmp`), not the literal `/tmp/…`.
  Gate A/B keys use the canonicalized absolute path.
- **Exact Gate B `[hooks.state.<key>]` entry written for this hook:**
  ```toml
  [hooks.state."/private/tmp/gsd-phase13-spike/spike-repo/.codex/hooks.json:pre_tool_use:0:0"]
  trusted_hash = "sha256:79880528f4285b85140ef44266db365535de02d35879c8829db6e3d0d47cbdbc"
  ```
  Confirms the 4-segment key format `<hooks.json-abs-path>:<event_snake>:<group>:<hook>`.
- **Gate A written at the SAME time:**
  ```toml
  [projects."/private/tmp/gsd-phase13-spike/spike-repo"]
  trust_level = "trusted"
  ```
- **One operator action or two?** Two *prompts* appeared at startup (project-trust +
  hook-review), but a **single approval flow wrote BOTH gates** in one shot. From the
  install perspective: **one interactive first-session trust flow sets Gate A and Gate B
  together** — the operator does not have to perform two separate deliberate actions on
  two separate occasions. (This is exactly the one-time operator action 13-05 documents.)

### STEP 6 — Gate A vs Gate B isolation (recorded 2026-07-18)
_Ran `codex` in `spike-repo-2` and this time approved project trust but did NOT complete
hook trust._

- **Result — the cleanest possible gate separation:**
  - Gate A present: `[projects."/private/tmp/…/spike-repo-2"] trust_level = "trusted"`.
  - Gate B ABSENT: no `[hooks.state."…spike-repo-2…"]` entry exists.
  - **The hook did NOT fire** — `spike-repo-2/.codex/fired.log` is absent — while the
    `echo hello-from-spike-2` tool call **still ran normally** (no error, no
    "PreToolUse hook (failed)" line).
- **Conclusion:** **Gate A (project trust) alone is NOT sufficient to fire a hook —
  Gate B (per-hook `trusted_hash`) is independently required.** A newly-installed hook
  in an already-trusted project stays silent until the operator separately trusts the
  hook. Hook trust does **not** gate tool execution (the tool runs either way); it only
  gates whether the hook runs. Consequence for HOOK-03/13-05: the one-time operator
  trust action must explicitly include trusting the **hook** (Gate B), not merely the
  project — trusting the repo is not enough to make the plan-review gate fire.

### STEP 7 — apply_patch coverage (THE decisive observation)
_Point the hook command at `cat >> <repo>/.codex/payload.log`, then in a human-observed
`codex` session perform ONE file-creating edit via whatever tool codex naturally chooses.
Inspect the captured payload._

- **`tool_name` reported for the file edit: `apply_patch`** (CONFIRMED — recorded
  2026-07-18). Captured invocation sequence for a one-file creation task:
  `['Bash','Bash','Bash','apply_patch','Bash']` (the Bash calls are codex's own
  workflow-skill/verify steps; the file edit itself is `apply_patch`).
  **PreToolUse DOES fire for apply_patch file edits on codex-cli 0.144.4** — the official
  docs are correct and the third-party "apply_patch not covered" claim is FALSIFIED.
- **Exact `tool_input` shape:** the patch text is under **`tool_input.command`** (the
  SAME field name Bash uses, different content — a shell string for Bash, a patch blob
  for apply_patch), NOT `.input` and NOT `.patch`:
  ```json
  { "command": "*** Begin Patch\n*** Add File: hello.txt\n+spike apply_patch test\n*** End Patch" }
  ```
  It carries clean, parseable `*** Add File: <path>` / `*** Update File: <path>` header
  lines — so a `--file` value IS derivable with a small `sed`/`grep` over
  `tool_input.command`.
- **Full PreToolUse stdin top-level keys (verbatim):** `session_id, turn_id,
  transcript_path, cwd, hook_event_name, model, permission_mode, tool_name, tool_input,
  tool_use_id`.
- **Deny visibility:** _(tested separately in STEP 7b below — primary-path JSON deny.)_

### A1 — project-scoped `[features] hooks = true` honored?
_In a trusted scratch repo, set ONLY a project-scoped `[features] hooks = true` in its
`.codex/config.toml` while forcing the machine-wide default OFF for the check (e.g.
`codex -c features.hooks=false features list` from inside the repo). Record whether
`hooks` reports ENABLED via the PROJECT layer specifically._

- **Observation — A1 CONFIRMED (recorded 2026-07-18).** The project-scoped
  `<repo>/.codex/config.toml` `[features]` table **is** read and **does** override the
  machine-wide default.

  _Method note — the first attempt was confounded and discarded._ Running
  `codex -c features.hooks=false features list` from inside the repo reported
  `hooks … false`, but `-c` is a CLI override that outranks **every** config layer, so
  that result proves nothing about project-vs-global precedence. The clean isolation
  below uses no `-c` at all and instead flips the project layer against a global default
  of `true`:

  | Where run | Project `[features] hooks` | `codex features list` reports |
  |---|---|---|
  | outside any project | _(absent)_ | `hooks  stable  true`  ← global default |
  | inside `spike-repo` | `false` | `hooks  stable  false` ← **project layer won** |
  | inside `spike-repo` | `true` | `hooks  stable  true` |

  The middle row is decisive: the global default is `true`, so `false` can only have come
  from the project layer.

- **Independent corroboration + a strictness caveat 13-03 must honor.** Injecting a
  non-boolean key into the project `[features]` table makes codex fail at startup with an
  error naming the file's exact path:
  ```
  Error: /private/tmp/gsd-phase13-spike/spike-repo/.codex/config.toml:3:9:
    invalid type: string "spike-canary-model-xyz", expected a boolean
    in `features`
  ```
  This both proves the file is genuinely parsed (not silently ignored) and shows
  `[features]` is **strictly typed and fail-closed**: any non-boolean value is a hard
  startup error, not a warning. **Consequence for HOOK-03 / migration 0011:** the
  `[features]` block it writes must contain `hooks = true` and nothing else — a stray or
  non-boolean key bricks `codex` startup for that repo.

- **Consequence for HOOK-03 Step 2:** writing `[features] hooks = true` into
  `<repo>/.codex/config.toml` is **effective**, not an ignored file. The migration does
  NOT need to fall back to instructing the operator to enable hooks globally.

---

## Resolved Answers (Task 3 — frozen; consumed by 13-02 / 13-03)

> **STATUS: FROZEN — 2026-07-18.** All four SPIKE-REQUIRED items answered by direct
> observation on codex-cli 0.144.4. 13-02 and 13-03 read this section.

- **SPIKE item 1 — exact `trusted_hash` input: NOT REPRODUCIBLE BLACK-BOX (negative
  result, and it is decisive rather than blocking).** Against a fixture whose exact bytes
  were controlled (`hooks.json` sha256 `7465d8df…`, single no-`matcher` PreToolUse group,
  command `cat >> /private/tmp/gsd-phase13-spike/spike-repo/.codex/payload.log`) and the
  freshly-written ledger value
  `sha256:002c38e7e76d694a5d27ae2ff751e90e4d121488cdb9ef1c18532ac0971fd470`, **65
  candidate inputs failed to reproduce the hash**: (a) command string ±newline; (b) the
  hook object as compact/spaced/sorted-key JSON in both key orders, with and without
  `timeout`/`matcher` defaults; (c) normalized TOML in both key orders; plus group-level
  objects, key/path/event-salted concatenations, and nine whole-file normalizations
  (raw bytes, compact, sorted, pretty). **None matched.** The input is an internal
  codex-cli serialization that is not derivable from the public file format.
- **SPIKE item 2 — pre-seeding viability + one-gate-or-two: PRE-SEEDING IS NOT VIABLE;
  two gates, but one approval flow.**
  - _Viability:_ pre-seeding was **already forbidden** by Pitfall 3 (the migration must
    never write the operator's global `~/.codex/config.toml`). Item 1's negative result
    makes it additionally **impossible** to do correctly even if it were permitted. The
    question is therefore closed from both directions, and **nothing downstream depends
    on knowing the hash input** — 13-03's migration writes only project-scoped files, and
    13-05 documents the one-time interactive trust as an operator action. This is why the
    unresolved hash input does **not** block the phase.
  - _One gate or two:_ **two independent gates.** Gate A (`[projects.<path>] trust_level`)
    and Gate B (`[hooks.state.<key>] trusted_hash`) are separately required — STEP 6
    proved Gate A alone does **not** fire a hook. But a **single first-session approval
    flow writes both together**, so it is one operator action, not two occasions.
  - _Caveat on stability:_ the same ledger key produced three different hashes across the
    spike (`79880528…`, `1e6949b0…`, `002c38e7…`). Content changes explain at least the
    first transition; whether the value is purely content-derived or additionally salted
    was **not** established, since the earlier fixtures were reaped from `/tmp` before
    their exact bytes could be re-hashed. Treat `trusted_hash` as opaque and
    non-reconstructible.
- **SPIKE item 3 — default trust_level for an unlisted project: PROMPT.** Not
  silent-trusted, not silent-untrusted — codex surfaces an interactive trust prompt (and,
  for a new hook, a separate hook-review prompt) and the hook does not fire until
  approved. HOOK-03's "verified firing in target repo" criterion must therefore state
  that firing follows an explicit operator trust action.
- **SPIKE item 4 — apply_patch coverage + `tool_input` field name: COVERED; the field is
  `tool_input.command`.** PreToolUse **does** fire for `apply_patch` file edits on
  codex-cli 0.144.4 — the official docs are correct and the third-party "apply_patch is
  not covered" claim is **FALSIFIED**. The patch blob arrives under
  **`tool_input.command`** (same field name Bash uses, different content), carrying
  parseable `*** Add File: <path>` / `*** Update File: <path>` header lines, so a
  `--file` value is derivable with a small `sed`/`grep`.
- **sha256 hash-input determination:** **UNRESOLVED — none of (a) command string,
  (b) compact-JSON hook object, or (c) normalized-TOML hook object matched**, nor did 56
  further variants. Recorded as a negative result; see item 1 for why it is non-blocking.
- **A1 (project-scoped feature flag honored): CONFIRMED.** `<repo>/.codex/config.toml`
  `[features] hooks` overrides the machine-wide default (project `false` beat global
  `true`). The table is strictly typed and fail-closed — a non-boolean value is a hard
  startup error — so migration 0011 must write `hooks = true` and nothing else.
- **No `trusted_hash` was written into `~/.codex/config.toml` (Pitfall 3 honored):**
  **AFFIRMED.** No automated task in this plan wrote to the global config. The only
  mutations to it were codex's own writes in response to the operator's interactive trust
  approvals, confined to the two `/private/tmp/gsd-phase13-spike/*` scratch keys.
- **⚠ Baseline drift disclosure (Task 1 acceptance criterion).** Task 1 asserted
  `~/.codex/hooks.json` byte-identity at `07112ce1…6d778`; it now hashes `eb7adec8…`.
  Content inspection shows **zero** `gsd-phase13-spike` entries — the file holds only
  live vendor hooks (nyx, cmux/termloop, superset, herdr), and its mtime post-dates the
  spike sessions. **Cause is unrelated vendor churn, not spike contamination**, but the
  criterion as literally written no longer holds and is recorded here rather than passed
  over silently.

**Matcher decision:** 13-03's `hooks.json` PreToolUse entry MUST carry
**`"matcher": "apply_patch"`**, and 13-02's wrapper does **NOT** need a
`Bash`-command-parsing branch — STEP 7 proved `apply_patch` covers file edits, and per
RESEARCH.md Open Question 1 the Bash branch is recommended only if apply_patch had proven
uncovered; it did not. The wrapper parses the patch blob from `tool_input.command`,
extracting the target path from its `*** Add File:` / `*** Update File:` headers.

> **Load-bearing corollary for HOOK-02 (from STEP 3's side-finding).** A hook emitting
> invalid stdout **fails OPEN** — codex reports `PreToolUse hook (failed)` and runs the
> tool anyway. The wrapper's allow path must therefore emit **empty stdout / silent
> `exit 0`**, and its deny path **strictly valid `permissionDecision` JSON or a clean
> `exit 2`**. Any partial or malformed stdout silently disables the gate.
