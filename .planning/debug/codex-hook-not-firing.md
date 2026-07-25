---
status: awaiting_human_verify
trigger: "Native PreToolUse plan-review hook does not fire in codex-cli 0.144.6. Migration 0011 installed .codex/hooks.json (PreToolUse, matcher \"apply_patch\", command ~/.codex/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh) and .codex/config.toml ([features] hooks = true). In a live session the expected one-time hook-trust prompt never appeared, and a disallowed edit was blocked only by the OLD prompt-based gate."
created: 2026-07-19
updated: 2026-07-19
phase: 13-native-enforcement-plan-review-hook
plan: 13-05
---

# Debug: codex native PreToolUse hook does not fire

## Symptoms

**Expected behavior**
In a live `codex` session in `/Users/donald/Sourcecode/agenticapps/codex-workflow`:
1. On first invocation after migration 0011, a one-time hook-trust prompt appears
   ("1 hook is new or changed... Trust all and continue").
2. When the model attempts a disallowed file edit, codex-cli's native `PreToolUse`
   dispatch intercepts the `apply_patch` tool call, runs
   `~/.codex/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh`,
   and the wrapper's `permissionDecision: "deny"` prevents the edit — independent of
   whether the model chose to comply.

**Actual behavior**
1. No hook-trust prompt appeared at session startup.
2. The edit WAS blocked, but by the OLD prompt-based mechanism: the model read
   `skills/agentic-apps-workflow/SKILL.md`, declared a "Workflow commitment", and
   voluntarily ran `check-plan-review.sh` itself as a compound **bash** call
   (`check-plan-review.sh` + `printf` + `tail -n 8` in one invocation).
3. `apply_patch` was never invoked at all, so the `apply_patch` matcher had nothing
   to match. The native hook cannot be shown to have run.

This is intention (model compliance), not enforcement — the exact distinction
milestone v0.8.0 exists to establish.

**Error messages**
No error. The observed block text was the gate script's own output, surfaced as the
agent's bash result:
```
plan-review gate: BLOCKED (exit 2)
```
followed by the model's narration: "The edit is blocked by the mandatory plan-review
gate. Phase .planning/phases/99-scratch-13-05-live-session needs a *-REVIEWS.md
artifact created through codex-plan-review before I may edit the file."
Note: this text is near-identical to the script-level simulation recorded in
13-05-LIVE-SESSION.md section 3, which is what makes the false positive dangerous.

**Timeline**
Never observed working. Migration 0011 was authored in plan 13-03 and applied to this
repo for the first time in plan 13-05 Task 1 (commit 3c6b85b). The 13-05 live session
(2026-07-18) is the first and only attempt to observe it firing end-to-end.
13-01-SPIKE-FINDINGS.md claims the mechanism works; those claims are now suspect and
must be treated as unverified rather than as ground truth.

**Reproduction**
```
cd /Users/donald/Sourcecode/agenticapps/codex-workflow
codex
# prompt: add a line saying 'hello' to NOTES-13-05-live-session-scratch.md
```
Staged condition (still in place, untracked): scratch phase
`.planning/phases/99-scratch-13-05-live-session/` containing a `*-PLAN.md` with no
`*-REVIEWS.md` and no `*-SUMMARY.md`, plus a `.planning/current-phase` pointer at it.
Both `check-plan-review.sh` and the wrapper have been verified in isolation to emit
valid `permissionDecision: "deny"` JSON when fed a simulated `apply_patch` payload —
so the failure is in hook LOADING or DISPATCH, not in the gate logic.

## Candidate Hypotheses (initial, unranked)

1. `[features] hooks = true` is not honored from a **project-level** `.codex/config.toml`
   and must live in the global `~/.codex/config.toml`.
2. The `apply_patch` matcher does not match the tool name codex-cli 0.144.6 actually
   emits for file edits (name drift, or a different edit tool entirely).
3. Project-scoped `.codex/hooks.json` is not read at all in this version; hooks may be
   global-only (`~/.codex/hooks.json`).
4. Hooks require a trust/enablement step that silently no-ops when absent, so the
   feature is off without any diagnostic.
5. The model never reached an edit tool call at all — the prompt-based gate short-circuited
   it first — meaning the hook may be correctly installed but was never exercised.
   (Distinguishing 5 from 1-4 is the highest-value first experiment.)

## Current Focus

reasoning_checkpoint:
  hypothesis: "Hypothesis 5 CONFIRMED as the primary cause of the observed
    non-firing: AGENTS.md's always-loaded '## Pre-execution Gate — Plan
    Review' section (installed by migration 0008, still present) instructs
    the model, on EVERY session, to invoke check-plan-review.sh itself via
    bash before any code-touching edit and HARD STOP on exit 2. A compliant
    model therefore always self-blocks (or self-allows) before it ever
    attempts apply_patch, so the apply_patch-matched native PreToolUse hook
    (migration 0011) structurally never receives a matching tool call to
    intercept. This is not a hook-loading/dispatch bug — it is an
    unresolved design conflict between the OLD prompt-based gate (ADR-0009)
    and the NEW native gate (HOOK-03) that migration 0011 never addressed:
    the old gate always wins the race for a compliant model, making the new
    gate's independent-of-compliance guarantee permanently unverifiable
    under normal operation. Separately, Gate B (per-hook trust) was never
    granted for this hook in the observed session (confirmed by direct grep
    -- zero `[hooks.state.*]` entries reference this repo's hooks.json) --
    so even a non-compliant model reaching apply_patch may not have been
    denied either, a second, stacked reason no denial was observed."
  confirming_evidence:
    - "Symptoms (pre-existing, operator-observed): apply_patch was never
      invoked in the live session; the model ran check-plan-review.sh
      itself as a bash call and narrated a HARD STOP. Direct proof the
      native hook's matcher never had an event to match."
    - "AGENTS.md:232 ('## Pre-execution Gate — Plan Review') is inside the
      unconditionally-loaded BEGIN/END agentic-apps-workflow block (line
      15-269), not a trigger-skill-only instruction -- confirmed by direct
      grep of AGENTS.md, not SKILL.md alone."
    - "grep of ~/.codex/config.toml: zero [hooks.state...] entries reference
      this repo's .codex/hooks.json at all -- Gate B (per-hook trust) was
      never granted for the plan-review hook, confirmed directly."
    - "External research (GitHub openai/codex, closed issue #16732 + PR
      #18391): apply_patch PreToolUse coverage is a real, shipped, fixed
      capability (tool_name: apply_patch, patch blob under
      tool_input.command) -- independently corroborates 13-01-SPIKE-
      FINDINGS.md STEP 7 rather than resting on that suspect document
      alone. Hypothesis 2 (matcher/tool-name drift) is ELIMINATED."
    - "External docs (developers.openai.com/codex/config-advanced,
      /codex/hooks): project-scoped .codex/config.toml and .codex/hooks.json
      ARE discovered and loaded, walking from repo root to cwd, but ONLY
      when the project is Gate-A trusted -- confirmed this repo's exact
      current path IS Gate-A trusted (13-05 Task 1 pre-flight, re-verified
      by direct grep of ~/.codex/config.toml this session). Hypotheses 1
      and 3 (project-scope not honored / hooks.json project-scope not read)
      are ELIMINATED by documented behavior + confirmed trust state."
    - "codex doctor --all: 'feature flags: 35 enabled . 0 overridden' with
      hooks already in the enabled-machine-wide-default list -- inconclusive
      noise, not evidence either way for 1/3 (hooks=true needs no override
      to already read true globally); not relied upon for the elimination
      above."
    - "Direct reproduction of the wrapper end-to-end (this session, sandbox
      fixture): confirms the wrapper->gate chain produces valid deny JSON,
      and that the new Source: tag and self-evidencing log line both work
      as designed (migrations/run-tests.sh test_hook_native_source_evidence,
      9/9 PASS)."
  falsification_test: "A live session where the prompt-based AGENTS.md
    ritual cannot fire (temporarily disabled) still shows NO new line in
    hook-wrapper-plan-review.log for an attempted disallowed edit -- that
    would disprove hypothesis 5 and point back to a real dispatch failure
    (hypotheses 1/3/4) despite the documentation/config evidence above."
  fix_rationale: "The fix does not (and structurally cannot, from this
    non-interactive session) change codex-cli's own dispatch behavior or
    complete the operator's one-time Gate B trust action. It instead closes
    the OBSERVABILITY gap that let this false positive happen at all:  (1) a
    Source: tag threaded from hook-wrapper-plan-review.sh through
    check-plan-review.sh's _cpr_block() so every future block is
    self-labeled native-hook vs agent-bash, and (2) a self-evidencing
    invocation log written before any decision logic on every wrapper
    invocation, so 'the native hook fired' becomes a directly observable
    fact (a new log line) instead of an inference from block text. A third,
    incidental fix (sed -E for the Add/Update File alternation, previously
    GNU-only \\| syntax that silently never matched on this operator's own
    BSD/macOS sed) was found and fixed while building regression coverage
    for the above -- it was silently breaking --file derivation on this
    exact machine, which is directly relevant to any future diagnosis on
    this host."
  blind_spots: "Cannot independently confirm from this non-interactive
    session whether: (a) the Gate-B hook-review prompt truly never appeared
    in the 13-05 live session (vs. appeared as an easy-to-miss warning line
    the operator/transcript didn't capture), (b) granting Gate B trust and
    forcing a real apply_patch attempt (prompt-based gate disabled) actually
    produces a native-hook-tagged deny in this codex-cli 0.144.6 build on
    this exact host, (c) whether other block sites in check-plan-review.sh
    (the ambiguous-REVIEWS.md path, ~line 521) also need the Source: tag --
    only _cpr_block() was tagged, matching this session's actual
    reproduction and keeping the change surgical."
next_action: return CHECKPOINT REACHED to the operator for the live
  discriminator session (Gate B trust + prompt-based-gate-disabled apply_patch
  attempt), since no further progress is possible without operator-driven
  interactive codex.

## Evidence

- timestamp: 2026-07-18 (live session, operator-observed)
  observation: Disallowed edit blocked; `NOTES-13-05-live-session-scratch.md` never
  created on disk. Block came from the model's own bash call to check-plan-review.sh,
  not from a harness interception. No hook-trust prompt at startup.
  source: 13-05-LIVE-SESSION.md, operator screenshot

- timestamp: 2026-07-18 (Task 1, plan 13-05)
  observation: `.codex/hooks.json` and `.codex/config.toml` confirmed present and
  well-formed in the repo. Wrapper fed a simulated apply_patch PreToolUse payload
  returns strictly valid `permissionDecision: "deny"`.
  source: 13-05-LIVE-SESSION.md section 3, commit 3c6b85b

- timestamp: 2026-07-19
  observation: codex-cli version confirmed 0.144.6. `.codex/hooks.json` matcher is
  `apply_patch`; command path is `~/.codex/skills/.../hook-wrapper-plan-review.sh`
  (global skills dir, not repo-relative). `.codex/config.toml` contains
  `[features] hooks = true`.
  source: direct inspection

- timestamp: 2026-07-19
  checked: AGENTS.md (this repo) for the source of the model's self-invoked
  check-plan-review.sh call.
  found: "## Pre-execution Gate — Plan Review" (line 232) is inside the
  unconditionally-loaded `<!-- BEGIN: agentic-apps-workflow sections -->`
  block (lines 15-269), reread every session per the file's own "Coding
  Discipline (NON-NEGOTIABLE)" framing -- not merely a trigger-skill
  instruction that only sometimes loads. It mandates: run the verifier
  before the FIRST code-touching edit, HARD STOP on exit 2, "Do not edit
  code."
  implication: A compliant model will always self-invoke check-plan-review.sh
  via bash BEFORE attempting apply_patch, on every session, unconditionally.
  This structurally prevents the apply_patch-matched native hook from ever
  receiving a matching tool call under normal (compliant-model) operation --
  confirms hypothesis 5 as an architectural certainty, not a one-off fluke.

- timestamp: 2026-07-19
  checked: `codex --help` / `codex features list` / `codex doctor --all` /
  `codex debug --help` for hook-related introspection surfaces.
  found: no dedicated hooks-introspection subcommand exists in this version
  (no `codex hooks`); `codex doctor` reports only `~/.codex/config.toml` as
  "config.toml" and never mentions .codex/hooks.json, project-scoped
  config.toml, or hook trust state anywhere in its output, even --all;
  `codex features list` shows `hooks    stable    true` as a machine-wide
  default (independent of this repo's project-scoped override).
  implication: codex-cli 0.144.6 has no CLI-level way to directly confirm
  hook load/dispatch state outside the interactive `/hooks` command --
  confirms the operator must drive `/hooks` interactively; no further
  non-interactive introspection is available.

- timestamp: 2026-07-19
  checked: web research (github.com/openai/codex issues #16732, #20204;
  developers.openai.com/codex/hooks, /codex/config-advanced).
  found: (1) apply_patch PreToolUse coverage is a real, shipped capability
  (PR #18391, closed issue #16732) -- tool_name: "apply_patch", patch blob
  under tool_input.command -- independently corroborating 13-01-SPIKE-
  FINDINGS.md STEP 7. (2) matcher is a regex string, not exact-match.
  (3) project-scoped .codex/config.toml and .codex/hooks.json ARE
  discovered (repo-root to cwd walk) but ONLY when the project is Gate-A
  trusted; untrusted projects have their ENTIRE .codex/ layer ignored.
  (4) Gate B (per-hook trust) review is lazy -- happens on first encounter
  of a new/changed hook, either as an interactive prompt or (per issue
  #24093 discussion) sometimes as a printed warning directing the user to
  `/hooks`, not necessarily a blocking modal every time.
  implication: hypothesis 2 (matcher/tool-name drift) ELIMINATED by external
  confirmation, independent of the suspect 13-01-SPIKE-FINDINGS.md.
  Hypotheses 1 and 3 (project-scope config/hooks.json not honored)
  ELIMINATED by documented behavior, cross-referenced against this repo's
  confirmed Gate-A-trusted state. Hypothesis 4 (silent no-op trust gate)
  narrows to: Gate B was genuinely never granted (confirmed by config.toml
  grep below), but whether the review signal is silently absent or was
  simply an easily-missed printed warning is still open -- needs a live
  `/hooks` check.

- timestamp: 2026-07-19
  checked: `grep -n 'hooks.state.*codex-workflow' ~/.codex/config.toml`
  found: zero matches. No `[hooks.state."<...>/codex-workflow/.codex/hooks.json:...">]`
  entry exists anywhere in the operator's trust ledger for this repo's
  plan-review hook.
  implication: Gate B (per-hook trust) was never granted for this hook in
  this repo, independent of hypothesis 5. Even if a future session forces
  an apply_patch attempt past the prompt-based gate, the native hook would
  still not fire (STEP 6 of 13-01-SPIKE-FINDINGS.md: Gate A alone does not
  fire a hook; Gate B is independently required) until the operator
  completes the interactive `/hooks` trust flow. This is a second, stacked,
  independently-confirmed reason no denial was observed live.

- timestamp: 2026-07-19
  checked: manual end-to-end reproduction of hook-wrapper-plan-review.sh
  fed a realistic apply_patch PreToolUse payload (same shape
  13-05-LIVE-SESSION.md section 3 captured), before any fix applied.
  found: the wrapper's own `--file` derivation (`sed -n 's/^\*\*\* \(Add\|Update\) File: //p'`)
  silently returned empty on this operator's own macOS/BSD sed -- `\|`
  inside a BRE is a GNU sed extension for alternation; BSD sed treats it as
  a literal pipe character, so the pattern never matches. `--file` was
  therefore never threaded through to check-plan-review.sh on this exact
  machine, on any invocation, native-hook or otherwise.
  implication: a real, independent, previously-undetected portability bug
  in the wrapper -- not the root cause of "hook does not fire" (the phase-
  only fallback still resolves and blocks correctly without --file, so this
  did not itself cause the observed non-firing), but directly relevant to
  future diagnosis on this host and fixed alongside the observability fix.

- timestamp: 2026-07-19
  checked: `migrations/run-tests.sh` full suite, before and after the fix.
  found: 442 PASS / 1 SKIP / 0 FAIL before (matches 13-05-LIVE-SESSION.md's
  recorded baseline); 451 PASS / 1 SKIP / 0 FAIL after adding
  `test_hook_native_source_evidence` (9 new assertions, all green) and
  applying the Source-tag + logging + sed-portability fixes. No regressions
  in any pre-existing suite (check-plan-review: 140 PASS unchanged in shape;
  hook-wrapper stderr contract: 2 PASS unchanged; migration 0011: 25 PASS
  unchanged).
  implication: the fix is additive and non-breaking; existing enforcement
  behavior (exit codes, JSON shape, bypass-list logic) is untouched.

## DECISIVE EXPERIMENT — 2026-07-19 (operator-observed)

Conditions: BOTH prompt-based gate copies stripped (AGENTS.md + SKILL.md), so the
model had no self-check instruction; `.codex/hooks.json` schema corrected to the
nested `hooks: [...]` shape matching the global file; scratch phase 99 fixture in
place; wrapper log baseline = 1 line (`tool_name=<empty>`, a self-test).

Prompt: "add a line saying 'hello' to NOTES-13-05-live-session-scratch.md"

RESULT — **FAIL**:
- `NOTES-13-05-live-session-scratch.md` WAS CREATED (6 bytes, 08:54). The edit
  reached the filesystem.
- Wrapper log UNCHANGED — still only the baseline entry. No `tool_name=apply_patch`
  line. The wrapper was never invoked.

CONCLUSION: with the prompt-based gate removed there is NO enforcement underneath.
The native PreToolUse hook has never fired — not before the schema fix, not after.
Yesterday's observed block was 100% the prompt-based gate. The native layer that
phase 13 is built on has never worked in this environment; the schema correction
was necessary-but-not-sufficient, or irrelevant.

Additional evidence from the same session, BEFORE the schema fix:
- `/hooks` reported `PreToolUse: Installed 2, Active 2`. The global
  `~/.codex/hooks.json` contains exactly 2 PreToolUse hooks (nyx tool-start,
  herdr agent-state). The project hook was therefore NOT loaded at that point.
- Zero `[hooks.state.*]` trust entries in `~/.codex/config.toml` reference the
  project `.codex/hooks.json`; all reference the global file.

OPEN: post-fix `/hooks` PreToolUse count (2 vs 3) — splits "parsed but not
dispatched / untrusted" from "project-scoped hooks.json never read at all".

## SIDE FINDING (unrelated defect, needs its own fix)

During the session the model moved to DELETE `.codex/session-handoff.md` (65 lines,
dated 2026-07-03) in order to write a fresh handoff about the throwaway test edit.
The file is UNTRACKED, so the deletion would have been unrecoverable. The handoff
rule treats ">7 days old" as "safe to overwrite", with no backup and no git
tracking — destructive-by-default on unrecoverable data. Operator caught it.

## Eliminated

- hypothesis: "schema mismatch (flat matcher/type/command instead of nested
  hooks:[...]) is the root cause"
  evidence: schema corrected to match the global file's shape; the very next live
  session still produced NO wrapper log line and the edit still reached disk.
  status: eliminated as SOLE root cause. The malformed entry was real and worth
  fixing, but fixing it did not restore enforcement.

- hypothesis: "5 — prompt-based gate short-circuit, as the ROOT CAUSE"
  evidence: both copies stripped; model went straight to the edit with no
  self-check; hook still never fired. The short-circuit is real and does mask the
  hook for a compliant model, but it explained the OBSERVATION, not the DEFECT.
  status: demoted from root cause to confounder.

- hypothesis: "2 — the apply_patch matcher does not match the tool name
  codex-cli 0.144.6 actually emits for file edits"
  evidence: External, independent confirmation (GitHub openai/codex closed
  issue #16732, merged PR #18391) that apply_patch PreToolUse coverage is a
  real shipped capability with tool_name "apply_patch" and the patch blob
  under tool_input.command -- corroborating 13-01-SPIKE-FINDINGS.md STEP 7
  without relying on that suspect document alone. Also directly confirmed
  by this session's own end-to-end wrapper test (payload with
  tool_name=apply_patch flows correctly through the wrapper).
  timestamp: 2026-07-19

- hypothesis: "1 — [features] hooks = true is not honored from a
  project-level .codex/config.toml"
  evidence: developers.openai.com/codex/config-advanced documents
  project-scoped .codex/config.toml discovery (repo-root to cwd walk,
  closest file wins) conditioned only on the project being Gate-A trusted.
  This repo's exact current path is confirmed Gate-A trusted (13-05 Task 1
  pre-flight; re-verified this session by direct grep). No evidence
  project-scope is ignored when trusted.
  timestamp: 2026-07-19

- hypothesis: "3 — project-scoped .codex/hooks.json is not read at all in
  this version; hooks may be global-only"
  evidence: Same source as hypothesis 1's elimination -- project-scoped
  .codex/hooks.json is documented as discovered under the identical
  trust-gated discovery walk. No evidence hooks.json is treated differently
  from config.toml in this regard.
  timestamp: 2026-07-19

## Resolution

root_cause: The native PreToolUse hook was never demonstrated to fire
  because it was never given the chance to: AGENTS.md's always-loaded
  "Pre-execution Gate — Plan Review" ritual (migration 0008, ADR-0009)
  instructs a compliant model to self-invoke check-plan-review.sh via bash
  BEFORE any code-touching edit, on every session, unconditionally, and
  HARD STOP on exit 2 without ever calling apply_patch. Migration 0011
  (HOOK-03) installed the native hook correctly (files present, wrapper
  contract sound, matcher correct) but never resolved the conflict with the
  pre-existing prompt-based gate -- the old gate wins the race for any
  compliant model, so the new gate's core promise (enforcement independent
  of model compliance) has never actually been exercised or proven live.
  Independently, Gate B (per-hook trust) was also never granted for this
  hook (confirmed by config.toml grep: zero matching hooks.state entries) --
  a second, stacked reason a denial was never observed, requiring the
  operator's own one-time interactive `/hooks` trust action regardless of
  the AGENTS.md-ritual conflict above.
fix: (1) check-plan-review.sh's _cpr_block() now emits a `Source:` line,
  defaulting to "agent-bash (direct invocation, not the native hook)" and
  reading "native-hook" only when GSD_PLAN_REVIEW_SOURCE=native-hook is set.
  (2) hook-wrapper-plan-review.sh sets GSD_PLAN_REVIEW_SOURCE=native-hook
  when it execs the gate, so every block the native hook produces is now
  self-labeled and textually distinguishable from a model's own compliant
  self-check. (3) hook-wrapper-plan-review.sh now writes a self-evidencing
  timestamped invocation log line (tool_name + pid) to
  ${CODEX_HOME}/hook-wrapper-plan-review.log BEFORE any decision logic, on
  every invocation (allow, deny, or fallback) -- "the native hook fired"
  becomes directly observable evidence, not an inference from block text.
  (4) incidental fix: hook-wrapper-plan-review.sh's --file derivation now
  uses `sed -n -E 's/^\*\*\* (Add|Update) File: //p'` (portable ERE)
  instead of a GNU-only `\(Add\|Update\)` BRE alternation that silently
  never matched on this operator's own BSD/macOS sed -- --file was never
  threaded through to the gate on this host before this fix.
  This fix does NOT resolve the underlying AGENTS.md-vs-native-hook race
  (that is a design decision for phase 13 planning to make, out of this
  debug session's scope) and does NOT complete the operator's own Gate B
  trust action (cannot be done non-interactively) -- both remain open,
  the first flagged for phase 13 follow-up, the second requiring the
  live checkpoint below.
verification: Self-verified non-interactively: migrations/run-tests.sh full
  suite 451 PASS / 1 SKIP / 0 FAIL (up from 442 PASS / 1 SKIP baseline, 9
  new assertions in test_hook_native_source_evidence, zero regressions).
  Manual end-to-end reproduction of the wrapper confirms Source: native-hook
  and the invocation log both work as designed. NOT YET independently
  verified in a live interactive codex session (requires operator action --
  see CHECKPOINT REACHED).
files_changed:
  - skills/agentic-apps-workflow/scripts/check-plan-review.sh (Source: tag
    in _cpr_block())
  - skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh
    (GSD_PLAN_REVIEW_SOURCE=native-hook on gate exec; self-evidencing
    invocation log; portable sed -E fix for --file derivation)
  - migrations/run-tests.sh (new test_hook_native_source_evidence suite,
    9 assertions, registered under filter "hook-native-source")
