# 13-05 Live Session — HOOK-01 end-to-end block (SC#2 + SC#4-positive)

**Phase:** 13 — native-enforcement-plan-review-hook
**Plan:** 05 — live human-observed session
**Task 1 (pre-flight, automated):** recorded below, 2026-07-18
**Task 2 (live human-observed session):** NOT YET RUN — see placeholders at the
bottom of this document. Task 1 does **not** drive the interactive codex
session; that is the operator's own action.

**Live target (operator preference, recorded per this plan's
`<operator_decision>`):** THIS REPO'S OWN `.codex/` —
`/Users/donald/Sourcecode/agenticapps/codex-workflow` — not a fresh clone.

---

## 1. Pitfall-4 pre-step — stale project-trust path

**Check performed:**
```
$ codex --version
codex-cli 0.144.6
$ codex doctor   # relevant excerpt
  repo root                ~/Sourcecode/agenticapps/codex-workflow
  branch                   feat/phase-12-path-safety-review-debt
```
`codex doctor` resolves the repo root correctly to the CURRENT path. Grepped
`~/.codex/config.toml` for a `[projects."<current-abs-path>"]` entry:

```
$ grep -n -A1 '\[projects\."/Users/donald/Sourcecode/agenticapps/codex-workflow"\]' ~/.codex/config.toml
(no match — 0 occurrences, before the fix below)
$ grep -n 'projects\..*codex-workflow' ~/.codex/config.toml
15:[projects."/Users/donald/Sourcecode/codex-workflow"]
```

**Result: Pitfall 4 CONFIRMED, exactly as recorded in
`13-01-SPIKE-FINDINGS.md`.** The only `codex-workflow` trust entry is keyed to
the STALE pre-family-reorg path `/Users/donald/Sourcecode/codex-workflow`.
The CURRENT path `/Users/donald/Sourcecode/agenticapps/codex-workflow` has
**zero** Gate A (project-trust) entries.

**Re-trust action taken (Gate A ONLY — never Gate B):**

- Backed up `~/.codex/config.toml` first:
  `~/.codex/config.toml.pre-13-05-backup-20260718T190308Z`
  (sha256 identical to the live file before editing — confirmed via
  `shasum -a 256` on both, matching hashes).
- Added exactly one new stanza, immediately after the stale entry, changing
  nothing else in the file:
  ```toml
  [projects."/Users/donald/Sourcecode/agenticapps/codex-workflow"]
  trust_level = "trusted"
  ```
- Full `diff` against the pre-edit backup confirms this is the **only**
  change:
  ```
  17a18,20
  > [projects."/Users/donald/Sourcecode/agenticapps/codex-workflow"]
  > trust_level = "trusted"
  >
  ```
- `codex doctor` afterward reports `config.toml parse ok` — the file is still
  valid.
- **The stale entry (line 15, old path) was left untouched.** Removing it was
  out of scope for this pre-step; only the current path needed a trust entry.
- **No `[hooks.state.*]` (Gate B) entry was written anywhere.** This is
  deliberate and required by this plan's `<critical_constraints>` and by
  `13-01-SPIKE-FINDINGS.md` STEP 6: Gate A (project trust) and Gate B
  (per-hook trust) are independent — trusting the project alone does **not**
  make a hook fire. Gate B trust is Task 2's own one-time interactive action
  (the `/hooks` or startup hooks-review "Trust all and continue" prompt),
  which the operator must complete live. Pre-seeding it here would defeat
  T-13-07's mitigation and invalidate the proof.

**Consequence for Task 2:** with Gate A already trusted, the operator should
see **only** the hook-review prompt at first invocation (Gate B), not also an
"untrusted project" prompt (Gate A). If an untrusted-project prompt *does*
still appear in Task 2, that is a genuine anomaly to investigate — it is not
expected given this fix — and must not be rubber-stamped through.

**Disclosed version drift:** the spike (13-01) ran on codex-cli `0.144.4`;
this pre-flight ran on `0.144.6` (two patch versions later, still within
RESEARCH.md's "valid until 7 days" window but a real drift). `codex doctor`
still resolves the repo root and `[projects.*]`/`[hooks.state.*]` shapes
identically to the spike's observations, and `config.toml parse ok`
confirms the TOML layer is unaffected. No behavior change observed at the
pre-flight level; Task 2 is the first live proof against the newer patch.

---

## 2. Migration 0011 applied to this repo's own `.codex/`

**Pre-existing suite state confirmed first** (per the prior session-handoff's
open question — "Wave 3 post-merge test gate not independently verified"):

```
$ bash migrations/run-tests.sh
=== Summary ===
  PASS: 442
  SKIP: 1
$ echo $?
0
```
442 PASS / 0 FAIL / 1 SKIP, exit 0 — the merged tree (through 13-04) is
independently confirmed green. That open question is now resolved.

**Migration 0011 applied via its OWN extracted document blocks** (Pre-flight,
then Step 1/2/3 Apply — extracted from `migrations/0011-native-plan-review-hook.md`
itself using `extract_step_block`/`extract_preflight_block`, the same functions
`migrations/run-tests.sh` uses, never hand-transcribed), run against this
repo's real working tree (`.codex/` was empty beforehand — no
`.codex/hooks.json` or `.codex/config.toml` existed in this repo prior to
this plan):

```
=== Pre-flight === exit=0
=== Step 1 (hooks.json merge) === exit=0
=== Step 2 (config.toml [features] merge) === exit=0
=== Step 3 (workflow-version.txt seal) === exit=0
```

**Post-checks, run verbatim from the migration document's own `## Post-checks`
section:**

```
$ CODEX="${CODEX_HOME:-$HOME/.codex}"
$ WRAPPER="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
$ jq -e --arg cmd "$WRAPPER" \
   '(.hooks.PreToolUse // [])[] | select(.command == $cmd and .matcher == "apply_patch")' \
   .codex/hooks.json
{
  "matcher": "apply_patch",
  "type": "command",
  "command": "/Users/donald/.codex/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
}
exit=0

$ awk '/^\[features\]/{f=1;next} /^\[/{f=0} f && /^hooks[ \t]*=[ \t]*true[ \t]*$/{found=1} END{exit !found}' .codex/config.toml
exit=0

$ grep -q '^0.8.0$' .codex/workflow-version.txt
exit=0
```

**Acceptance-criterion grep confirmations (verbatim requested form):**

```
$ grep -n "hook-wrapper-plan-review.sh" .codex/hooks.json
7:        "command": "/Users/donald/.codex/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"

$ grep -n "hooks = true" .codex/config.toml
2:hooks = true
```

`<repo>/.codex/hooks.json` carries the plan-review PreToolUse entry pointing
at the installed wrapper, and `<repo>/.codex/config.toml` has
`[features] hooks = true`. **Both confirmed.**

**No write to `~/.codex/hooks.json` at all** — verified: this migration run
never touches the operator's global hooks file; only `<repo>/.codex/*` was
written (`.codex/hooks.json`, `.codex/config.toml`, `.codex/workflow-version.txt`
— the last was already `0.8.0` from plan 13-03's earlier commit, so Step 3
was a no-op re-confirmation, not a new write).

**Resulting file contents (this repo's `.codex/`):**

`.codex/hooks.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "apply_patch",
        "type": "command",
        "command": "/Users/donald/.codex/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
      }
    ]
  }
}
```

`.codex/config.toml`:
```toml
[features]
hooks = true
```

**Sanity check — wrapper + gate script identity between `~/.codex/` and this
repo's tree:** `diff` of both `hook-wrapper-plan-review.sh` and
`check-plan-review.sh` between `~/.codex/skills/agentic-apps-workflow/scripts/`
and this repo's `skills/agentic-apps-workflow/scripts/` returned no
differences (byte-identical) — the wrapper `.codex/hooks.json` now points at
is the same file this repo's own tests exercise.

---

## 3. Staged disallowed-edit condition

**Why staging was necessary (not optional):** `check-plan-review.sh`'s
grandfather guard exits 0 (ALLOW) the moment **any** `*-REVIEWS.md` OR any
`*-SUMMARY.md` exists under the resolved phase directory (enforcement is
go-forward-only, by design — ADR-0025). Phase 13's own real directory
(`.planning/phases/13-native-enforcement-plan-review-hook/`) already carries
`13-01-SUMMARY.md` through `13-04-SUMMARY.md` from the plans this phase has
already shipped. A live disallowed edit attempted *right now, against phase
13's real resolved state*, would **not** block — it would hit the grandfather
guard and silently allow, which would look like a hook failure but is
actually documented, intentional behavior. Checked and confirmed by
inspection: **every** phase directory in this repo that has any `*-PLAN.md`
also already has a `*-SUMMARY.md`, so there is no "for free" un-shipped phase
currently sitting in the tree.

**Staged fix — an explicit-pointer scratch phase, never touching phase 13's
real state or STATE.md:**

1. Created `.planning/phases/99-scratch-13-05-live-session/99-01-PLAN.md` — a
   scratch phase directory carrying a `*-PLAN.md` and (deliberately)
   **no** `*-REVIEWS.md` and **no** `*-SUMMARY.md`.
2. Pointed `.planning/current-phase` (a symlink) at
   `phases/99-scratch-13-05-live-session` — this is `resolve_phase`'s **step
   1** (explicit pointer), the highest-precedence resolution path, checked
   *before* STATE.md's `Phase: 13` line (step 2). While this symlink exists,
   the resolver returns the scratch phase, not phase 13, regardless of
   STATE.md's content — STATE.md itself was never touched.
3. **Both the scratch phase directory and the `.planning/current-phase`
   symlink are deliberately UNTRACKED** — confirmed via `git status --short`
   (both show as `??`, untracked) and **will not be included in Task 1's
   commit**. They exist only in the working tree for the duration of Task 2's
   live session.

**Disallowed-edit target file:** `NOTES-13-05-live-session-scratch.md` at the
repo root. This does **not** exist yet — the operator's live session should
ask codex to create/edit this file. It is deliberately **not** under
`.planning/` and does not match any bypass-list basename
(`*PLAN.md|*PLAN-*.md|*REVIEW[S].md|ROADMAP.md|PROJECT.md|REQUIREMENTS.md|*CONTEXT.md|*RESEARCH.md`),
so `check-plan-review.sh`'s `--file` bypass block never even enters its
`case` arm for it — control falls straight through to `resolve_phase`, which
(via the pointer) resolves to the scratch phase, finds its `*-PLAN.md`, finds
**zero** `*-REVIEWS.md`, and blocks.

**Verified against the REAL scripts (not simulated logic) before handing off
to Task 2:**

a) Direct gate script, both with and without `--file`:
```
$ GSD_PLAN_REVIEW_DEBUG=1 bash skills/agentic-apps-workflow/scripts/check-plan-review.sh
resolved-phase: .planning/phases/99-scratch-13-05-live-session
❌ plan-review gate: BLOCKED (exit 2)
   Reason: the phase has *-PLAN.md files but no multi-AI plan review (*-REVIEWS.md not found)
exit=2

$ GSD_PLAN_REVIEW_DEBUG=1 bash skills/agentic-apps-workflow/scripts/check-plan-review.sh --file NOTES-13-05-live-session-scratch.md
resolved-phase: .planning/phases/99-scratch-13-05-live-session
❌ plan-review gate: BLOCKED (exit 2)
   File:      NOTES-13-05-live-session-scratch.md
   Reason: the phase has *-PLAN.md files but no multi-AI plan review (*-REVIEWS.md not found)
exit=2
```

b) The INSTALLED wrapper, fed a simulated but realistic `apply_patch`
PreToolUse stdin payload (same JSON shape STEP 7 of the spike captured
live — `tool_name: "apply_patch"`, patch blob under `tool_input.command`
with a `*** Add File: <path>` header):
```
$ echo "$PAYLOAD" | /Users/donald/.codex/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "❌ plan-review gate: BLOCKED (exit 2)\n\n   Phase:     .planning/phases/99-scratch-13-05-live-session\n   Missing:   .planning/phases/99-scratch-13-05-live-session/<NN>-REVIEWS.md\n\n   Reason: the phase has *-PLAN.md files but no multi-AI plan review (*-REVIEWS.md not found)\n\n   Remedy: invoke the codex-plan-review skill to produce a\n   multi-AI plan review artifact, then continue.\n\n   Overrides (emergency only):\n     GSD_SKIP_REVIEWS=1\n     touch .planning/phases/99-scratch-13-05-live-session/multi-ai-review-skipped"
  }
}
wrapper exit=0
```
Strictly valid JSON, `permissionDecision: "deny"`, the wrapper's own exit
code is 0 (per the load-bearing contract: the block is expressed via JSON
body, never partial stdout). The `--file` value the wrapper derived from the
patch blob's `*** Add File:` header matches the staged target exactly.

**This end-to-end script-level chain (gate script -> wrapper -> deny JSON) is
proven.** What Task 2 proves that this pre-flight structurally CANNOT is that
codex-cli's own runtime — after the operator completes the one-time
interactive Gate-B hook-trust action — actually invokes this exact wrapper
via its real `PreToolUse` interception point on a real `apply_patch` tool
call, and that the operator observes the denial through the real CLI UI, not
a simulated payload.

---

## 4. Task 2 — Live human-observed session (OPERATOR ACTION — NOT YET RUN)

> Everything below this line is an empty placeholder. Task 1 does not drive
> the interactive codex session. Fill in each section during the live
> session per the plan's Task 2 `<manual_verification>` steps.

### Step 1 — one-time hook-trust (Gate B)

_(operator fills in: did the "1 hook is new or changed... Trust all and
continue" prompt appear on first `codex` invocation in this repo? Was it
completed? Did an UNEXPECTED untrusted-project prompt also appear — if so,
STOP and treat as an anomaly, not a hook failure, since Gate A was
pre-trusted in Task 1.)_

/ not yet recorded /

### Step 2 — SC#2: observed denial of the disallowed edit

_(operator fills in: the exact prompt given to codex, the tool call codex
chose, and the denial observed verbatim — an edit that reaches the
filesystem is a FAIL.)_

/ not yet recorded /

### Step 3 — SC#4-positive: binding fires in target repo

_(operator fills in: cross-reference to Step 2's observation — same evidence
proves both.)_

/ not yet recorded /

### Step 4 — CONTROL: plan-review gate block vs. untrusted-project refusal

_(operator fills in: confirm the observed denial reason names the
plan-review gate / missing REVIEWS.md specifically — e.g. contains
"plan-review gate" or "REVIEWS.md" — and is NOT a generic untrusted-project
refusal.)_

/ not yet recorded /

### Outcome

/ not yet recorded — BLOCKED / FAIL /

---

## 5. Cleanup (after Task 2 completes, either outcome)

Run from the repo root once Task 2's observation is recorded above:
```bash
rm .planning/current-phase
rm -rf .planning/phases/99-scratch-13-05-live-session
rm -f NOTES-13-05-live-session-scratch.md   # only if codex's edit reached disk (FAIL case)
```
None of these three paths were ever staged into git; removing them returns
the working tree to a clean state with no `git rm` needed.
