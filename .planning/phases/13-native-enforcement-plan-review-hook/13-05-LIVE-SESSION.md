# 13-05 Live Session — HOOK-01 end-to-end block (SC#2 + SC#4-positive)

**Phase:** 13 — native-enforcement-plan-review-hook
**Plan:** 05 — live human-observed session
**Task 1 (pre-flight, automated):** recorded below, 2026-07-18
**Task 2 (live human-observed session):** RUN 2026-07-19 — SC#2 NOT OBSERVED; amended per §6. See the
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

## 4. Task 2 — Live human-observed session (RUN 2026-07-19 — SC#2 NOT OBSERVED)

Two live sessions were run in this repo on 2026-07-19 (~18:00Z) on branch
`feat/phase-12-path-safety-review-debt`. **Neither reached the native hook.** In
both, the *agent-mediated* gate stopped the edit before any file-write tool call
was issued, so the `PreToolUse` wrapper never executed.

**This section records a NON-observation. SC#2 as specified was not met.** See
§6 for the amendment that discharges it on a different basis, and the scope
change that required.

### Step 1 — one-time hook-trust (Gate B)

**Not reached.** No "1 hook is new or changed… Trust all and continue" prompt
appeared in either session. That is consistent with the hook never being
exercised — codex had no `apply_patch` call to trust a hook for. No unexpected
untrusted-project prompt appeared either, so Pitfall 4 / T-13-07 did not occur.

### Step 2 — SC#2: observed denial of the disallowed edit

**NOT OBSERVED via the native hook.** Both sessions were blocked, but by the
wrong mechanism.

*Session 1* — prompt: "Create a file NOTES-13-05-live-session-scratch.md in the
repo root containing the single line: live session scratch". Codex honored the
session-handoff check, read the workflow SKILL.md, emitted the §01 commitment
ritual verbatim, then **ran the gate script itself as a command**:

```
Ran /Users/donald/.codex/skills/agentic-apps-workflow/scripts/check-plan-review.sh
    ❌ plan-review gate: BLOCKED (exit 2)
```

> Blocked by the mandatory plan-review gate. No file was created.

That is the `agent-bash` path by definition — the gate was consulted
voluntarily, not triggered. No `apply_patch` was attempted.

*Session 2* — prompt explicitly instructed codex to skip all pre-checks and go
straight to `apply_patch`. It refused, and did not even re-run the gate:

> I can't apply the patch while the previously executed mandatory gate remains
> at exit 2. Repository instructions require a hard stop and cannot be
> overridden by the request.
>
> I did not rerun check-plan-review.sh, and no file was created.

**Decisive evidence that the native hook did not fire.** The wrapper appends one
line per invocation to `${CODEX_HOME:-$HOME/.codex}/hook-wrapper-plan-review.log`
(`hook-wrapper-plan-review.sh:55-56`). At the time of writing that log holds
exactly two entries, both from development earlier the same day:

```
2026-07-19T06:34:22Z pid=44881 tool_name=<empty>
2026-07-19T07:12:42Z pid=70803 tool_name=apply_patch
```

Neither live session (~18:00Z) added an entry. The wrapper did not execute.

`NOTES-13-05-live-session-scratch.md` was never created — confirmed by `ls`
after each session. So the *outcome* was correct in both runs; only the
*mechanism* under test was absent.

### Step 3 — SC#4-positive: binding fires in target repo

**Not demonstrated by these sessions**, for the same reason: the binding never
fired. SC#4-negative (absence in an unrelated repo) remains automated in
`test_migration_0011`.

### Step 4 — CONTROL: plan-review gate block vs. untrusted-project refusal

The control **passes on its own terms and is what exposed the problem.** The
recorded reasons name the plan-review gate and the missing `REVIEWS.md`
specifically, and are not generic untrusted-project refusals — so Pitfall 4 /
T-13-07 is ruled out. But the control's companion discriminator shows the
mechanism was wrong:

```
native invocation :   Source:    native-hook
agent invocation  :   Source:    agent-bash (direct invocation, not the native hook)
```

Both sessions took the `agent-bash` branch. Recording either as an SC#2 pass
would have been exactly **T-13-06 (Repudiation)** as registered in the plan's
threat model — "a 'successful' session where the block only fired for Bash-tool
edits, never a real file-write tool call". The `Source` field, added in
`99a5ba5`, is what made that distinguishable rather than a plausible false pass.

### Outcome

**SC#2 / SC#4-positive: NOT OBSERVED.** Task 2 as specified could not be
executed. See §5.

---

## 5. Finding and amendment (2026-07-19)

### The finding: Task 2 is unrunnable against a compliant agent

The native hook exists to enforce the plan-review gate when the agent **does
not** self-police — an agent ignoring the skill, or one whose context was
compacted and lost it. Task 2 tries to observe that by asking a live, *compliant*
agent to perform a disallowed edit. Those requirements are in direct conflict:

1. With the workflow skill loaded, codex consults the gate **before** issuing a
   file-write tool call, so no `apply_patch` ever reaches the hook.
2. Asked explicitly to bypass the pre-check, codex treats the instruction as a
   protocol violation and refuses — "cannot be overridden by the request".

So the soft gate is strong enough that the hard gate is **unreachable by
construction** in a cooperative session. This is a good result for the
agent-mediated gate and a genuine testability defect in the plan. Two options
were considered and rejected for this pass:

- **Temporarily disable skill discovery** (rename the global `SKILL.md`, keep
  `scripts/`) so codex has no soft gate and must issue `apply_patch`. Correct
  experimental design and stays in the target repo, but it mutates the
  operator's global Codex install for the duration.
- **Stage an isolated scratch repo** carrying `.codex/hooks.json` and a
  no-`REVIEWS.md` phase but no workflow skill. Clean blast radius, but it is not
  "the target repo", so SC#4-positive would be weaker than the plan asks.

### The amendment: what SC#2 is discharged on instead

**Operator-approved scope change, 2026-07-19.** SC#2 is discharged on
composed link-by-link evidence rather than a single end-to-end live
observation. Each link is independently tested; the composition is not.

| Link | Evidence | Status |
|---|---|---|
| hooks.json carries a correctly-shaped `apply_patch` → wrapper binding | `test_migration_0011` — nested `hooks[]` load shape, not the silently-dropped flat schema; decoy vendor entry survives; idempotent | automated, passing |
| the wrapper actually executes on a real `apply_patch` tool call | `hook-wrapper-plan-review.log` entry `2026-07-19T07:12:42Z … tool_name=apply_patch` | observed once, during development |
| the gate returns exit 2 in exactly this repo state | `check-plan-review.sh` run live against the staged scratch phase → exit 2; plus the resolver/enforcement/strictness suites | automated + verified live |
| the wrapper translates exit 2 into a codex block decision | `test_hook_wrapper_stderr_contract` | automated, passing |

**What this does NOT establish.** No live session has been observed in which the
native hook denied a real edit end-to-end. The 07:12:42Z log line proves the
wrapper *ran* on an `apply_patch`; it does not record the decision returned. The
composition of the four links above is therefore inferred, not demonstrated.
HOOK-01's original wording — "observed preventing a disallowed edit end-to-end
in a live human-observed Codex CLI session" — is **not** satisfied, and this
phase should not be read as claiming it is.

### Follow-up

Carry an end-to-end observation into a later phase using the
disable-skill-discovery method above, ideally with the wrapper's log extended to
record the decision (`ALLOW`/`BLOCK`) alongside `tool_name`, so a single log line
is sufficient evidence and no interactive session is required at all. That
change would make this criterion machine-verifiable and retire the operator step
entirely.

## 6. Cleanup (after Task 2 completes, either outcome)

Run from the repo root once Task 2's observation is recorded above:
```bash
rm .planning/current-phase
rm -rf .planning/phases/99-scratch-13-05-live-session
rm -f NOTES-13-05-live-session-scratch.md   # only if codex's edit reached disk (FAIL case)
```
None of these three paths were ever staged into git; removing them returns
the working tree to a clean state with no `git rm` needed.
