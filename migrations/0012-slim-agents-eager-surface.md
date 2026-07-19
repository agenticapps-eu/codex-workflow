---
id: 0012
slug: slim-agents-eager-surface
title: Slim the eager AGENTS.md to §11 + pointers, reconcile the spec citation — spec 0.10.0 §12 (v0.8.0 -> 0.9.0)
from_version: 0.8.0
to_version: 0.9.0
applies_to:
  - AGENTS.md                                                            # drop relocated sections, install pointers
  - skills/agentic-apps-workflow/SKILL.md                                # absorb session-handoff; §12 + spec-deltas; version + claim
  - docs/ENFORCEMENT-PLAN.md                                             # claim 0.4.0 -> 0.10.0; declare §14
  - .codex/workflow-version.txt                                          # record new project version
requires: []
optional_for: []
---

# Migration 0012 — Slim the eager AGENTS.md, reconcile the citation (v0.8.0 → 0.9.0)

Two changes that belong together: this host adopts core spec **0.10.0**'s §12
instruction-surface economy convention, and in doing so advances a conformance
citation that had been stale by six spec versions.

## Part 1 — the §12 convention

Core spec 0.10.0 added an "Instruction-surface economy (eager vs lazy)"
convention to §12 (core ADR-0020), extending §12 from *where in* the eager file
prose sits to **what belongs in it at all**:

> A host implementation **SHOULD** keep the always-loaded file to the minimum
> that must be resident on *every* turn: the §11 canonical block, verbatim and
> near the top, and a short pointer to the trigger skill that carries the rest.

`AGENTS.md` is injected on every turn — including turns that never touch code —
so its whole content is re-billed per turn. This host was carrying ~150 lines of
procedure there, and **all five** relocated blocks already existed in the trigger
skill or move there in step 1:

| Block | Was in `AGENTS.md` | Status |
|---|---|---|
| Workflow Enforcement Hooks (gate table) | 110–140 | already in `SKILL.md` Step 3 (the normative copy) |
| Skill routing (task size) | 141–154 | already in `SKILL.md` Step 1 |
| Knowledge Capture ritual tail (§15) | 171–230 | already in `SKILL.md`, and §15 *requires* it to live there |
| Pre-execution Gate — Plan Review (§02) | 232–267 | already in `SKILL.md`, **byte-identical** |
| Session handoff | 155–169 | **not** in `SKILL.md` — step 1 moves it |

Four of the five were pure duplication. Only the session-handoff protocol
genuinely moves, and step 1 places it in the skill before step 2 removes it from
`AGENTS.md`, so the contract is never absent from both files at once.

### Enforcement does not move — only prose

§12 is explicit that a host "whose runtime enforces a gate programmatically keeps
the *hook wiring* where the runtime needs it; only the explanatory prose moves."
The plan-review gate is the case in point: its **procedure prose** moves to the
trigger skill, while its enforcement — `.codex/hooks.json`'s `PreToolUse` entry
on `apply_patch`, `hook-wrapper-plan-review.sh`, and `check-plan-review.sh`
(exit 0 = ALLOW, exit 2 = BLOCK) — is **untouched by this migration**. So is
`.planning/config.codex.json`. Removing the prose weakens no gate; the hook is
what blocks, and it still does.

## Part 2 — the citation, reconciled

`implements_spec` read **0.4.0** while the repo already satisfied everything
through 0.9.1. Audited 2026-07-19:

| Spec | Verdict | Evidence |
|---|---|---|
| 0.5.0 — §02 `plan-review` gate | satisfied | `check-plan-review.sh` implements §02's four-step resolution order and the grandfather rule; wired natively by `0011` |
| 0.6.0 — §14 prompt-injection | **was the one real gap** | trivially conformant (no LLM prompt-building surface) but never *declared*; §09 requires the host to say so. Closed by step 4 |
| 0.7.0 — §15 knowledge capture | satisfied | all four requirements; migrations `0007` / `0010` |
| 0.8.0 — §04 red-flag composition | satisfied | canonical 13, zero host additions — the case 0.8.0 names as needing no action |
| 0.9.0 — §08 setup end-state | satisfied | this host installs by **replay**, §08's first-listed strategy; the drift-guard obligation binds snapshot installers only |
| 0.9.1 — §08 prose fix | vacuous | clarification only |

So the citation moves `0.4.0 → 0.10.0` in one step, but only after step 4 closes
the §14 declaration gap. **Do not reorder those steps**: advancing the claim
first would assert conformance the repo did not yet have.

Only `skills/agentic-apps-workflow/SKILL.md` moves. The gate, GSD-entry and
lifecycle skills keep `implements_spec: 0.4.0` — they cite the *gate contract*
they implement, not the host claim, and those contracts are unchanged since
0.4.0. spec/09 makes the trigger skill's frontmatter the normative carrier.

## States handled

| Condition | Behaviour |
|---|---|
| Marker pair absent in `AGENTS.md` | ABORT (exit 1) — run setup, not this migration |
| §11 provenance absent | ABORT (exit 1) — file is outside `0001`/`0009` management; refuse to edit |
| Already slimmed (pointer present) | No-op (idempotency guard) |
| Full v0.8.0 block present | Slim it |
| Some sections already hand-removed | Slim what remains; absent sections simply do not match |

## Pre-flight

```bash
grep -qE '^version: 0\.(8\.0|9\.0)$' skills/agentic-apps-workflow/SKILL.md \
  || { echo "ABORT: expected scaffolder version 0.8.0 (or 0.9.0 if re-running); replay through 0011 first"; exit 1; }
grep -q '^<!-- BEGIN: agentic-apps-workflow sections' AGENTS.md \
  || { echo "ABORT: AGENTS.md has no managed marker block"; exit 1; }
grep -qE '^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$' AGENTS.md \
  || { echo "ABORT: no §11 provenance anchor — file is outside 0001/0009 management"; exit 1; }
```

## Steps

### Step 1: Absorb the session-handoff protocol into the trigger skill

Done **before** step 2 removes it from `AGENTS.md`.

**Idempotency check:** `grep -q '^## Session handoff$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `skills/agentic-apps-workflow/SKILL.md` exists.
**Apply:** insert a `## Session handoff` section immediately above
`## Knowledge Capture — Ritual Tail (spec §15)`, carrying the protocol
`AGENTS.md` used to hold — read `.codex/session-handoff.md` at session start when
under 7 days old; **only** the codex handoff, never a bare root
`session-handoff.md` or another host's; write it before ending a session, in the
accomplished / decisions / files-modified / next-session / open-questions shape,
under 150 lines — and close with the ordering constraint that the §15 ritual tail
runs *after* the handoff is written.
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md`

### Step 2: Slim the eager AGENTS.md

**The installer template is deliberately NOT slimmed.** This host installs by
**replay** (§08's first-listed strategy): setup walks `0000`→latest, so
`templates/agents-md-additions.md` is an *input to the chain*, not the end
state. A fresh install applies the heavy template early, then this migration
slims it at the end of the same replay — landing slim either way.

Slimming the template as well was tried first and is wrong. Migrations `0007`,
`0008` and `0010` read their sections **out of that template** (the §15 ritual
tail, the plan-review row, the bindings table). Removing them from it breaks
those immutable migrations' replay — `0010` in particular would silently insert
nothing, regressing the very D-06 defect it exists to heal, and any project that
stopped at `0010` without applying `0012` would end up with §15 in neither file.
The suite catches this: `D-06: AGENTS.md carries the Knowledge Capture — Ritual
Tail section after Steps 1-3`.

**Idempotency check:** `grep -q 'Full protocol in the trigger skill' AGENTS.md`
**Pre-condition:** pre-flight (markers + provenance present).
**Apply:**
```bash
# step2:begin
# Drop the four relocated sections and rewrite the two that survive as pointers.
# Scoped strictly to the managed marker block. The §11 span (provenance ->
# terminator) is never matched: '## Coding Discipline (NON-NEGOTIABLE)' falls
# through to mode="pass" and its subheads are '### '.
slim_agents_block() {
  awk '
BEGIN { inblk=0; mode="pass"; infence=0 }

/^<!-- BEGIN: agentic-apps-workflow sections/ { inblk=1; print; next }
/^<!-- END: agentic-apps-workflow sections -->/ { inblk=0; mode="pass"; print; next }

!inblk { print; next }
# Code fences must be tracked (octal escape so this can live inside a doc
# fence). A fenced example inside a section can contain
# lines beginning with "## " (e.g. a session-handoff template). Treating those
# as headings ends the section early and leaks the rest of the fence through.
substr($0,1,3) == "\140\140\140" { infence = !infence; if (mode=="pass") print; next }
infence { if (mode=="pass") print; next }


/^## / {
  if ($0 == "## Workflow Enforcement Hooks (MANDATORY)" || \
      $0 == "## Skill routing" || \
      $0 ~ /^## Knowledge Capture — Ritual Tail \(spec §15\)$/ || \
      $0 ~ /^## Pre-execution Gate — Plan Review \(spec §02\)$/) {
    mode="drop"; next
  }
  if ($0 == "## Development Workflow") {
    mode="drop"
    print "## Development Workflow"
    print ""
    print "This repo uses the AgenticApps spec-first workflow on the OpenAI Codex"
    print "CLI host. On any code-touching task the `agentic-apps-workflow` trigger"
    print "skill activates, emits the canonical commitment ritual before any tool"
    print "call, and carries the gate bindings, task-size routing, the plan-review"
    print "procedure, and the knowledge-capture ritual — read them there, not here."
    print "Project-specific bindings live in `.planning/config.codex.json`; gates"
    print "that do not fire on this project are documented in"
    print "`docs/ENFORCEMENT-PLAN.md`. Do not bypass a gate — accept-via-ADR is the"
    print "override path. The plan-review gate is additionally enforced"
    print "programmatically by a `PreToolUse` hook (`.codex/hooks.json`), which is"
    print "unaffected by where the prose lives. Spec:"
    print "[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)."
    print "Version stamp: `.codex/workflow-version.txt`."
    print ""
    next
  }
  if ($0 == "## Session handoff") {
    mode="drop"
    print "## Session handoff"
    print ""
    print "Read `.codex/session-handoff.md` at session start if newer than 7 days;"
    print "write it before ending a session. Only the codex handoff — never another"
    print "host'\''s. Full protocol in the trigger skill."
    print ""
    next
  }
  mode="pass"
}

mode=="pass" { print }
' "$1" > "$1.0012.tmp" && mv "$1.0012.tmp" "$1"
}

slim_agents_block AGENTS.md
# NOTE: templates/agents-md-additions.md is intentionally left heavy — it is the
# chain's input, and migrations 0007/0008/0010 read their sections from it.
# step2:end
```
**Rollback:** `git checkout -- AGENTS.md`

### Step 3: Record the §12 adoption in the trigger skill

**Idempotency check:** `grep -q '^## Instruction surface — eager vs lazy (spec §12)$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** none — prose.
**Apply:** add an `## Instruction surface — eager vs lazy (spec §12)` section
stating what `AGENTS.md` now carries, what moved to the skill, and why (per-turn
re-billing; keeping §11 out of mid-context) — and stating explicitly that the
plan-review **hook** did not move. Rewrite the §15 cross-reference that claimed
the tail "mirrors the same section in the project `AGENTS.md`": after step 2 that
is false, it is now the only copy. Repoint the Step 3 `plan-review` row, which
referred the reader to an `AGENTS.md` section that no longer exists.
**Rollback:** `git checkout -- skills/agentic-apps-workflow/SKILL.md`

### Step 4: Declare §14 (closes the 0.6.0 gap)

**This step must precede step 5.** Until it lands, the repo cannot honestly cite
any spec version at or above 0.6.0.

**Idempotency check:** `grep -q '§14' docs/ENFORCEMENT-PLAN.md`
**Pre-condition:** none — declaration.
**Apply:** add a `## Spec deltas (spec 0.10.0)` section to the trigger skill and
a numbered §14 item to `docs/ENFORCEMENT-PLAN.md`'s conformance claim, both
stating that this scaffolder builds no LLM prompts from non-self-authored values,
so §14's trigger cannot occur, and that §09 requires only that the host say so.
Note downstream delegation to `injection-guard`, and that the `security` gate
still carries §02's obligation to record §14 evidence where the trigger *can*
occur. While here, advance the ENFORCEMENT-PLAN claim to v0.10.0 and add the
§15, §08-by-replay and §12 items.
**Rollback:** `git checkout -- docs/ENFORCEMENT-PLAN.md skills/agentic-apps-workflow/SKILL.md`

### Step 5: Advance the conformance claim to 0.10.0

**Idempotency check:** `grep -q '^implements_spec: 0.10.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^implements_spec: 0.4.0$' skills/agentic-apps-workflow/SKILL.md` **and** step 4 applied (`grep -q '§14' docs/ENFORCEMENT-PLAN.md`)
**Apply:**
```bash
grep -q '§14' docs/ENFORCEMENT-PLAN.md || { echo "ABORT: step 4 must land first — cannot claim >=0.6.0 without declaring §14"; exit 1; }
sed -i.0012.bak -E 's/^implements_spec: 0\.4\.0$/implements_spec: 0.10.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0012.bak
```
(Only the trigger skill. The gate / GSD-entry / lifecycle skills keep `0.4.0`:
they cite a gate contract, not the host claim.)
**Rollback:** `sed -i.bak -E 's/^implements_spec: 0\.10\.0$/implements_spec: 0.4.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 6: Bump the scaffolder version

**Idempotency check:** `grep -q '^version: 0.9.0$' skills/agentic-apps-workflow/SKILL.md`
**Pre-condition:** `grep -q '^version: 0.8.0$' skills/agentic-apps-workflow/SKILL.md`
**Apply:**
```bash
sed -i.0012.bak -E 's/^version: 0\.8\.0$/version: 0.9.0/' skills/agentic-apps-workflow/SKILL.md
rm -f skills/agentic-apps-workflow/SKILL.md.0012.bak
```
**Rollback:** `sed -i.bak -E 's/^version: 0\.9\.0$/version: 0.8.0/' skills/agentic-apps-workflow/SKILL.md && rm -f skills/agentic-apps-workflow/SKILL.md.bak`

### Step 7: Record the new project version

**Idempotency check:** `grep -q '^0.9.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:** `echo "0.9.0" > .codex/workflow-version.txt`
**Rollback:** `echo "0.8.0" > .codex/workflow-version.txt`

## Post-checks

```bash
# 1. §11 survives byte-identical to the mirror (the load-bearing assertion).
awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' AGENTS.md \
  | diff -q - skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md

# 2. Exactly one provenance anchor.
[ "$(grep -c 'spec-source: agenticapps-workflow-core' AGENTS.md)" -eq 1 ]

# 3. The relocated blocks are gone from the eager file...
! grep -q '^## Workflow Enforcement Hooks (MANDATORY)$' AGENTS.md
! grep -q '^## Skill routing$' AGENTS.md
! grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' AGENTS.md
! grep -q '^## Pre-execution Gate — Plan Review (spec §02)$' AGENTS.md

# 4. ...and the pointers are present.
grep -q 'Full protocol in the trigger skill' AGENTS.md
grep -q 'agentic-apps-workflow` trigger skill' AGENTS.md

# 5. The §11 block is still followed by a '## ' line (0001's bound).
awk '/session-level discipline the model brings to every diff\.$/{getline; getline; print; exit}' AGENTS.md | grep -q '^## '

# 6. The relocated procedures exist in the trigger skill.
grep -q '^## Session handoff$' skills/agentic-apps-workflow/SKILL.md
grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' skills/agentic-apps-workflow/SKILL.md
grep -q '^## Pre-execution Gate — Plan Review (spec §02)$' skills/agentic-apps-workflow/SKILL.md
grep -q '^## Step 3 — Gate-to-skill bindings' skills/agentic-apps-workflow/SKILL.md

# 7. §14 declared, and the claim advanced.
grep -q '§14' docs/ENFORCEMENT-PLAN.md
grep -q '^implements_spec: 0.10.0$' skills/agentic-apps-workflow/SKILL.md

# 8. Enforcement untouched: the plan-review hook still wired.
grep -q 'hook-wrapper-plan-review.sh' .codex/hooks.json
test -x skills/agentic-apps-workflow/scripts/check-plan-review.sh

# 9. The installer template is UNCHANGED — it is the chain's input, and
# migrations 0007/0008/0010 read their sections from it.
grep -q '^## Workflow Enforcement Hooks (MANDATORY)$' skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md
grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md
```

### REQUIRED operator check

Read the resulting `AGENTS.md` end to end and confirm a session that loads
**only** that file still knows: (a) the four §11 rules, (b) that a trigger skill
exists and carries the gates, (c) where the handoff lives, and (d) that
plan-review is hook-enforced regardless. If any is not obvious from the file
alone, the slimming went too far.

## Skip cases

- **`.codex/workflow-version.txt` already reads `0.9.0`** — fully applied; skip.
- **`AGENTS.md` contains `Full protocol in the trigger skill`** — step 2 already
  applied; the remaining steps are individually idempotent.
- **No marker pair in `AGENTS.md`** — never set up by this scaffolder. Pre-flight
  aborts; run setup instead.
- **A project that deliberately keeps the gate table eager.** §12's convention is
  **SHOULD**, not MUST: a heavy eager file is below the bar but not
  non-conformant. Such a project may skip step 2 and still claim 0.10.0, provided
  it records the choice — steps 1 and 3–7 still apply.

## Compatibility

- **Codex CLI runtime:** unaffected. Skill discovery is by frontmatter
  `description`, unchanged; only the skill body grew. The `PreToolUse` hook
  contract is untouched.
- **Downgrade:** every step has a `git checkout`-shaped rollback. Reverting step
  2 alone restores the heavy file without touching the claim.
- **Consuming projects on 0.8.0** pick this up via
  `/update-codex-agenticapps-workflow`. Projects that hand-edited the managed
  block keep any section this migration does not name.

## Notes

- The transform is **fence-aware**. A fenced example inside a dropped section can
  contain lines beginning with `## ` — this host's installer template carries
  exactly that, a session-handoff markdown example full of `## Accomplished` /
  `## Decisions` lines. Treating those as headings ends the drop early and leaks
  the fence's contents plus an orphaned fence marker into the slimmed file. The
  fence matcher uses an octal escape (`\140\140\140`) rather than a literal
  backtick run so this awk can live inside the migration doc's own fenced block.
- Four of the five relocated blocks were already duplicated in the trigger skill;
  the plan-review section was **byte-identical** between the two files. The §15
  tail had been obliged to live in `SKILL.md` by core §15 since `0007`.
- `CHANGELOG.md` has no `## [0.8.0]` entry — the version shipped without one.
  Out of scope here; noted so it is not mistaken for this migration's omission.

## References

- Core spec §12, "Instruction-surface economy (eager vs lazy)" (v0.10.0).
- Core [ADR-0020](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/adrs/0020-instruction-surface-economy.md).
- Core spec §14 (v0.6.0) — conditional; §09's "say so" requirement.
- Core spec §08 as amended at v0.9.0 — replay is the first-listed strategy.
- Migration [`0011`](0011-native-plan-review-hook.md) — the plan-review hook whose prose (not wiring) moves here.
