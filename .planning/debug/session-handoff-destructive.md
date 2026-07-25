---
status: researched
created: 2026-07-19
---

# Debug: session-handoff mechanism is destructive-by-default

## Symptoms

Live codex session, 2026-07-19, in `/Users/donald/Sourcecode/agenticapps/codex-workflow`.
Operator asked only: *"add a line saying 'hello' to
`NOTES-13-05-live-session-scratch.md`"* — a trivial scratch-file edit, no session
history worth recording.

Following the workflow's handoff rule, the model checked `.codex/session-handoff.md`,
found it dated 2026-07-03 (>7 days old, past the staleness window used for the
*read* check), and moved to **delete** it — shown in the diff as
`Deleted .codex/session-handoff.md (+0 -65)` — in order to write a fresh handoff
describing the throwaway edit.

`.codex/session-handoff.md` is untracked by git:

```
$ git ls-files --error-unmatch .codex/session-handoff.md
error: pathspec '.codex/session-handoff.md' did not match any file(s) known to git
```

The deletion would have been **unrecoverable**. The file (verified present,
65 lines, dated 2026-07-03) contains real session history: two merged PR
references (#11, #12, #13), file inventories, decisions, and open questions
— see `/Users/donald/Sourcecode/agenticapps/codex-workflow/.codex/session-handoff.md`
(left untouched by this investigation, per constraints). The operator was watching
and stopped it. This is already logged as a "SIDE FINDING (unrelated defect,
needs its own fix)" at `.planning/debug/codex-hook-not-firing.md:322-328`, in the
middle of an unrelated hook-enforcement investigation — this document is the
dedicated root-cause writeup that side finding called for.

The model was not malfunctioning — it was following the rule as written. That is
what makes this a defect in the rule/mechanism, not in the model.

## Where the rule lives (every copy found)

The rule exists in **two layers** — a host-neutral "personal" copy (Claude's global
config) and per-repo copies shipped by four sibling scaffolder repos in this family
(codex-workflow, claude-workflow, opencode-workflow, pi-agentic-apps-workflow).
All are textually near-identical descendants of one template; claude-workflow is
documented as "the reference host" (ADR-0008). I stayed inside
`~/Sourcecode/agenticapps` per the family boundary.

### 1. `~/.claude/CLAUDE.md` (global, host-neutral — "Session startup" / "Session handoff")

Not a repo file (outside any git tree), but quoted verbatim in the system prompt
for this session:

> At the start of every session, check for a session-handoff.md in the current
> project directory. If it exists and was modified in the last 7 days, read it
> before doing anything else and confirm what you found.
>
> Before ending any session — when asked to exit, when the final task is done,
> or when context is getting full — write a session-handoff.md in the current
> project directory.
>
> [format block: `# Session Handoff — [date]` / Accomplished / Decisions / Files
> modified / Next session: start here / Open questions]
>
> Keep it under 150 lines. Write the file directly — do not print it to the
> terminal.

This is the **fullest** version of the rule: it has the write trigger, the format
template, and the 150-line cap.

### 2. `codex-workflow/AGENTS.md:155-169` (this repo's own root instructions — what actually governed the incident)

```
## Session handoff

At the start of every session, check for `.codex/session-handoff.md`.
If it exists and was modified in the last 7 days, read it before doing
anything else and confirm what was found. **Only read the codex
handoff** — do NOT read a bare root `session-handoff.md` or another
host's handoff (e.g. `.opencode/session-handoff.md`); handoffs are
host-scoped so multiple hosts can share one working tree without
cross-contaminating context.

Before ending any session — when asked to exit, when the final
task is done, or when context is getting full — write
`.codex/session-handoff.md`. The file is in `.gitignore`
because it is a working artifact for cross-session continuity, not
a shipped scaffolder artifact.
```

**This is the copy Codex actually reads for this repo** (AGENTS.md, root-down
concat, per ADR-0007's "thin binding" model). It is **missing the format
template and the "Keep it under 150 lines" cap** that every other copy has
(see divergence note below).

### 3. `codex-workflow/skills/agentic-apps-workflow/SKILL.md:377-388`

Same content as AGENTS.md's `## Session handoff` section (read/write triggers,
host-scoping caveat), **also missing** the format block and 150-line cap.
This is the trigger skill's own copy — used when Codex loads the skill on a
code-task turn rather than reading AGENTS.md's ritual-tail passively.

### 4. `codex-workflow/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md:59-95` (the template shipped to new projects)

```
## Session handoff

At the start of every session, check for `.codex/session-handoff.md`.
If it exists and was modified in the last 7 days, read it before doing
anything else and confirm what was found. **Only read the codex
handoff** — do NOT read a bare root `session-handoff.md` or another
host's handoff (e.g. `.opencode/session-handoff.md`); handoffs are
host-scoped so multiple hosts can share one working tree without
cross-contaminating context.

Before ending any session — when asked to exit, when the final
task is done, or when context is getting full — write
`.codex/session-handoff.md`. Format:

# Session Handoff — YYYY-MM-DD

## Accomplished
- ...

## Decisions
- decision — why

## Files modified
- path — what changed

## Next session: start here
One paragraph on exactly where to pick up and what the first
action should be.

## Open questions
- ...

Keep it under 150 lines. Write the file directly — do not print
it to the terminal. This file survives session boundaries and is
the primary continuity mechanism across sessions.
```

**This is the version every newly-scaffolded project gets** — full format +
150-line cap, matching the global CLAUDE.md. It does **not** mention
`.gitignore` at all in this excerpt (the gitignore line lives in a separate
`.gitignore`-additions template, not this prose block).

### Divergence found: this repo's own operative copies are the loosest ones that exist

`AGENTS.md` and `skills/agentic-apps-workflow/SKILL.md` — the two files that
actually govern a Codex session in *this* repo — both **omit** the format
template and the 150-line cap present in (a) the global CLAUDE.md and (b) this
repo's own downstream-facing template
(`skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md`).
Confirmed by grep — `Format:` / `150 lines` / `Session Handoff — YYYY-MM-DD`
appear in the template but zero times in AGENTS.md or SKILL.md:

```
$ grep -n "Format\|150 lines\|Session Handoff —" AGENTS.md
(no output)
$ grep -n "Format\|150 lines\|Session Handoff —" skills/agentic-apps-workflow/SKILL.md
(no output)
$ grep -n "Format\|150 lines\|Session Handoff —" skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md
71:`.codex/session-handoff.md`. Format:
74:# Session Handoff — YYYY-MM-DD
93:Keep it under 150 lines. Write the file directly — do not print
```

This is likely incidental drift (the ADR-0008 knowledge-capture wiring edited
both files' "Knowledge Capture" tail sections but the "Session handoff" section
above it was probably hand-trimmed at some point and never resynced against the
template) rather than a deliberate choice — nothing in ADR-0008 or the
migrations discusses removing the format block. It doesn't change the root
cause below (no copy, anywhere, licenses deletion), but it means the copy that
fired in the incident carries *less* guidance than the one shipped to every
other project, which is backwards for a repo whose own copy should be at least
as disciplined as what it hands out.

### Sibling repos confirm the same pattern fleet-wide (read-only check, stayed in-family)

- `claude-workflow/templates/global-claude-additions.md` and
  `claude-workflow/skill/SKILL.md:270-` — same wording, full format + 150-line
  cap (claude-workflow is the reference host).
- `opencode-workflow/AGENTS.md:158-169`,
  `opencode-workflow/skills/agentic-apps-workflow/SKILL.md`, and
  `opencode-workflow/skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md` —
  same wording, `.opencode/session-handoff.md`, same "the file is in `.gitignore`"
  line as codex-workflow's AGENTS.md.
- `pi-agentic-apps-workflow/templates/agents-md-additions.md` — same wording,
  full format + 150-line cap.

Every project scaffolded by any of these four repos inherits the identical
mechanism. This is a fleet-wide latent defect, not something specific to
codex-workflow.

## Root cause analysis

### The rule as written

No copy, anywhere in the fleet, uses the words "delete," "overwrite," "replace,"
or "discard." Every copy says only **"write"** — e.g. "write a session-handoff.md,"
"write `.codex/session-handoff.md`." The rule is completely silent on what to do
with an existing file's content: it neither says "preserve prior content" nor
"append" nor "you may destroy the old one." It gives a fixed single-session
template (`# Session Handoff — [date]` / Accomplished / Decisions / Files
modified / Next session / Open questions) with **no rotation, versioning, or
history mechanism**, and caps the whole artifact at 150 lines — which structurally
presupposes a full replace each time, since a growing append-only log would blow
through 150 lines within a handful of sessions.

Deletion is not *instructed* — it is the unavoidable **emergent consequence** of
"write a fixed-shape single-snapshot file at a fixed path" with zero guard around
the case where an existing file at that path holds content the current session
did not produce. "Write a session-handoff.md" and "destroy whatever the last
session wrote there" are, in this design, the same operation. That collapse is
the defect, not any single word in the prose.

### Why staleness triggered a rewrite at all

The **7-day staleness window only gates the *read* step** ("check... If it exists
and was modified in the last 7 days, read it"). It does not appear anywhere in
the *write* trigger, which fires unconditionally: "Before ending any session —
when asked to exit, when the final task is done, or when context is getting
full — write...". A trivial one-line scratch edit still satisfies "the final
task is done," so the write fires regardless of whether anything happened that
was worth recording.

What the incident shows is the model treating the *read*-side staleness signal
("this handoff is old, I won't read it in full") as license for the *write*
side ("...so it's safe to discard"). That linkage is nowhere in the rule text —
it is the model's own inference, made under a rule that gives it no reason not
to make it, because the rule never says what "write" should do when prior
content exists. Concretely: **the rule as written is not conditioned on task
significance** — it fires on trivial and substantial sessions alike — and
**the model's specific inference (staleness ⇒ discardable) is an
over-interpretation the rule does not forbid but also does not require.**
Both are true simultaneously; neither alone produces the incident. A rule that
fired unconditionally but preserved old content (e.g. via rotation) would have
been safe. A rule that made staleness license deletion, but only fired on
significant sessions, would also have limited the blast radius. It took both
gaps together — unconditional trigger + no preservation path — to make a
one-line scratch edit capable of destroying 65 lines of real history.

### Is the delete-then-recreate interpretation, or literal?

**Interpretation, not literal instruction.** No copy of the rule contains the
word "delete." The observed diff (`Deleted .codex/session-handoff.md (+0 -65)`)
is consistent with either an explicit `rm` before the write, or simply the
diff-renderer's representation of a full-content overwrite (old content
entirely replaced, new content entirely different, which most diff tools show
as delete-old-lines + add-new-lines when there's no line-level overlap). Either
mechanism produces the same *outcome* — total loss of the prior 65 lines — which
is why this is a defect in the rule/mechanism rather than in how literally the
model executed a single verb.

## Blast radius

- **Every project scaffolded from codex-workflow, claude-workflow,
  opencode-workflow, or pi-agentic-apps-workflow** inherits this exact
  mechanism verbatim (same wording, same unconditional trigger, same lack of
  rotation/backup, same gitignored/untracked status). Confirmed present in all
  four sibling repos in this family via direct grep (see above) — not inferred.
- **claude-workflow** is documented as the reference host (ADR-0008), meaning
  this defect most likely originated there and was mirrored outward — a fix
  upstream in claude-workflow (and the global `~/.claude/CLAUDE.md`) would need
  to propagate through each host's own migration chain to reach existing
  installs, mirroring how ADR-0008/migration 0007 propagated the knowledge-
  capture ritual.
- Any working tree where **two hosts share one repo** (e.g. claude + codex, per
  `docs/standards/gsd-binding-and-planning.md` §4) has two independent
  instances of this same destructive mechanism, one per host-scoped handoff
  file (`.codex/session-handoff.md`, `.claude/session-handoff.md`, etc.) — the
  defect is not reduced by host-scoping, only isolated per host.
- No user-facing warning, dry-run, or opt-out exists anywhere in the fleet for
  this specific operation — the operator's only defense today is watching the
  diff in real time, which is exactly what happened here.

## Is the file gitignored or merely untracked? Would tracking it be desirable?

**Gitignored, deliberately**, in this repo's `.gitignore:16-17`:

```
session-handoff.md
.codex/session-handoff.md
```

`git check-ignore -v .codex/session-handoff.md` confirms `.gitignore:17` is the
match. `AGENTS.md:167-169` documents the rationale: *"The file is in `.gitignore`
because it is a working artifact for cross-session continuity, not a shipped
scaffolder artifact."* — i.e., a fresh install of this scaffolder into a new
project should not ship codex-workflow's own dev-session history.

`docs/standards/gsd-binding-and-planning.md:77,89,95,124` treats this as a
deliberate, fleet-wide, documented design position: session-handoff files are
explicitly named (alongside `.planning/cache/` and `.planning/state/`) as the
**only** things a host scaffolder is allowed to gitignore — everything else
under `.planning/` (phase artifacts) is "committed evidence" per ADR-0037 and
must never be ignored. This is the *opposite* policy applied to two different
categories of file, on purpose: phase evidence is expensive, shared, and must
survive; session handoffs are treated as cheap, host-local, and disposable.

**Is disposability actually a safe assumption?** No — that is exactly what this
incident disproves. The design correctly distinguishes "should this ship to
downstream projects" (no) from "is this safe to destroy without a trace" (the
rule silently assumes yes, but the file in practice accumulates real,
hard-to-reconstruct decision history — PR numbers, rationale, open questions —
that nothing else in the repo captures at that granularity). Tracking the *live*
file in git would fix recoverability for free (git IS a rotation/backup
mechanism) but conflicts with two things the fleet has decided on purpose: (1)
it would make every session-end a commit-worthy mutation of a file whose whole
purpose is host-local scratch, and (2) in a two-host shared tree, the
`.codex/`-scoped and `.claude/`-scoped handoffs would both start accumulating
git history that's arguably local/noisy rather than shared project state. See
Option (c) below for the tradeoff this specific choice implies.

## Existing safeguards — none for session-handoff; what the repo's own idiom looks like elsewhere

No backup, archive-on-rotate, append-instead-of-replace, or confirmation gate
exists anywhere in the fleet for the handoff write. `scripts/` at the repo root
does not exist; `skills/agentic-apps-workflow/scripts/` contains only
`check-plan-review.sh` (a read-only *verifier*, not a file-mutating helper) —
there is no handoff helper script at all. The mechanism is pure prose in
AGENTS.md/SKILL.md with no programmatic backstop.

This repo *does* have well-established idioms for "about to mutate or destroy
something the operator may want back," used consistently elsewhere:

1. **Migration `.bak`-then-mutate, every single sed-based edit.** Every
   migration in `migrations/*.md` that edits an existing file wraps the edit in
   a transient backup that is only removed after the edit succeeds, e.g.
   `migrations/0007-knowledge-capture.md:159-160`:
   ```
   sed -i.0007.bak -E 's/^version: 0\.4\.0$/version: 0.5.0/' skills/agentic-apps-workflow/SKILL.md
   rm -f skills/agentic-apps-workflow/SKILL.md.0007.bak
   ```
   and every migration also documents an explicit, literal **Rollback:** command
   (e.g. `migrations/0007-knowledge-capture.md:164`,
   `migrations/0006-commit-planning-phases.md:114`,
   `migrations/0004-revendor-spec-11.md:99`). The idiom: never mutate a file
   in place without a recovery path that's checked in as documentation, not
   left to git alone.

2. **`check-plan-review.sh`'s escape hatches announce themselves loudly, never
   silently.** `GSD_SKIP_REVIEWS=1` and `touch <phase>/multi-ai-review-skipped`
   both print an explicit `"...SKIPPED via ... (emergency override)"` line to
   stderr before proceeding (lines 65-68, 441-444) — the design comment at
   lines 61-63 is explicit: *"this hatch announces itself on stderr, unlike the
   reference..., which exits 0 silently — a silent authorization bypass is
   exactly the threat T-08-07 names."* The block path (`_cpr_block`, lines
   486-520) is equally explicit about what's missing and what the remedies are.
   The idiom: an operation that bypasses a normal safety check must leave a
   visible trace, never fail silently in either direction.

3. **ADR-0037 / migration `0006-commit-planning-phases.md`'s "committed by
   default, surface don't silently skip" principle**
   (`docs/standards/gsd-binding-and-planning.md:99-112`): *"losing phase
   evidence to a stray ignore rule is a correctness failure, not a warning"* —
   evidence that's expensive to reconstruct must never be silently discarded;
   if a mechanism *could* discard it, that mechanism must surface the fact
   loudly and require a deliberate act to proceed.

**The session-handoff mechanism follows none of these three idioms.** It has
no `.bak`-then-mutate step, no rollback instruction, no announce-yourself
notice before replacing existing content, and treats content loss as the
unremarked default rather than something requiring a visible, deliberate act.
Given how consistently the rest of this repo applies "back up before you
mutate, announce before you bypass a safeguard, never silently discard
expensive-to-reconstruct evidence," the session-handoff rule reads as an
oversight relative to the repo's own established standards, not a deliberate
exception.

## Options, with tradeoffs

**(a) Archive-on-rotate to a dated file.** Before writing, if
`.codex/session-handoff.md` already exists, copy (never move-and-lose) it to
e.g. `.codex/session-handoff-archive/<its-original-date>.md`, creating the
archive dir if needed, then write the fresh handoff at the live path. Prune
archives beyond N (e.g. 10) if unbounded growth is a concern (these are tiny
text files; likely unnecessary).
- *Pros:* Directly mirrors this repo's own `.bak`-then-mutate idiom (§ above).
  Mechanical, cheap, fully automatable in prose (no new hook infrastructure
  needed — the rule already lives in prose). Makes every future overwrite
  recoverable regardless of how the model interprets "write." Does not require
  redesigning the handoff format or the 150-line cap.
- *Cons:* Archive directory needs its own gitignore/tracking decision (inherits
  the same disposability question as the live file, see Option (c)). Doesn't
  by itself stop a trivial session from *triggering* a write at all — it only
  makes each write non-destructive.

**(b) Append-only history with a current-section.** Replace the single-snapshot
file with a running log — new dated section prepended or appended each session,
old sections retained (possibly summarized) below.
- *Pros:* Single file, no archive-directory sprawl. Full history in one place
  is easy to skim.
- *Cons:* Directly conflicts with the existing, deliberately-chosen "under 150
  lines" cap (present in 3 of 4 rule copies) — the format is designed as a
  compact single-session snapshot, not a growing log; making it append-only
  requires redesigning the template *and* still needs a pruning/rotation policy
  once it would exceed 150 lines, at which point it has re-invented Option (a)
  with extra steps. Higher redesign cost for no clear win over (a).

**(c) Track the file in git.** Remove `.codex/session-handoff.md` (and the
`session-handoff.md` bare-root line) from `.gitignore`; let git's own history
serve as the recovery mechanism.
- *Pros:* Recoverability comes for free from a mechanism that already exists;
  zero new prose/tooling needed.
- *Cons:* Directly conflicts with the fleet's explicit, multi-repo, documented
  design position (`docs/standards/gsd-binding-and-planning.md` §4-5, `AGENTS.md`
  line 167-169) that host-scoped handoffs are the one deliberate exception to
  "commit everything under `.planning/`," precisely because they are host-local
  scratch, not shared project state. Would turn every session-end into a commit
  (or require squashing/rebasing discipline the workflow doesn't currently ask
  for anywhere else), and in a two-host shared-tree setup
  (`docs/standards/gsd-binding-and-planning.md` §4) would start accumulating
  git history for what's designed to be per-host noise. This is the most
  invasive option relative to existing, intentional design.

**(d) Condition the write on task significance.** Only rewrite the handoff if
the session did something worth recording (non-trivial diff, a decision made,
a plan/phase touched); otherwise skip the write and leave the existing file
untouched.
- *Pros:* Directly prevents the observed incident's trigger — a one-line
  scratch edit would never reach the write step at all. Reduces handoff churn
  generally (fewer near-empty handoffs).
- *Cons:* Requires an LLM judgment call embedded in prose ("is this worth
  recording?"), which is inherently inconsistent across models/sessions — a
  model could still misjudge a session as insignificant when it wasn't, and a
  model that *does* judge a session significant still has no protection against
  overwriting real prior content (this option does nothing for that case; it
  only reduces how often the destructive path is reached, not what happens
  when it is).

**(e) Require confirmation before replacing a handoff containing content the
current session did not author.** Diff old vs. intended-new content before
writing; if the old file contains material (headings, decisions, PR refs) that
don't trace to anything touched this session, stop and ask, or auto-archive
instead of proceeding silently.
- *Pros:* Matches the repo's own "announce yourself, never silently bypass a
  safeguard" idiom (`check-plan-review.sh`'s escape hatches). Closest to a true
  confirmation gate.
- *Cons:* This rule lives entirely in prose (AGENTS.md/SKILL.md), not a hook
  the way `check-plan-review.sh` is — a prose-only "ask before overwriting" is
  exactly the kind of instruction a model under context pressure can skip, which
  is a weaker guarantee than a mechanical step baked into the write procedure
  itself (Option (a) doesn't require the model to *notice* anything; it just
  changes what "write" mechanically does).

### Recommendation

**Adopt (a) archive-on-rotate as the primary fix, with (d) task-significance
gating as a cheap complementary tweak. Reject (b) and (c); treat (e) as
subsumed once (a) exists.**

(a) is the load-bearing fix: it makes content loss structurally impossible
regardless of how a model interprets "write a handoff" — the same category of
defense this repo already trusts for every migration-driven file edit
(`.bak`-then-mutate). It requires no redesign of the handoff format, no new
infrastructure, and can be expressed as a single mechanical pre-step in the
existing prose rule. (d) is worth adding alongside it because it reduces how
often the write (and thus any residual risk) fires at all — a one-line scratch
edit shouldn't produce a handoff rewrite in the first place — but (d) alone is
not sufficient, because a model can misjudge "significant" in either direction,
and even legitimately significant sessions deserve a backup before overwrite as
defense in depth, not a judgment call as the only defense.

(c) is rejected because it fights an explicit, considered, multi-repo design
decision (host-scoped handoffs are deliberately excluded from "commit
everything," precisely to avoid cross-host noise in a shared tree) rather than
fixing the actual gap, which is recoverability, not trackedness — (a) gives
recoverability without relitigating that design decision. (b) is rejected
because it breaks the deliberately compact, capped format for no benefit over
(a): it would need its own pruning/rotation logic anyway, at which point it has
just reinvented (a) with a redesigned template on top. (e) is treated as
subsumed: once overwrites are non-destructive by construction (a), a
confirmation gate becomes a nice-to-have UX improvement rather than the last
line of defense — and as a prose-only instruction it would carry the same
"can be skipped under pressure" risk that let the original incident happen at
all.

## Proposed fix sketch (NOT applied)

Add a mechanical pre-step to the "Session handoff" *write* instruction, in
every copy identified above (global `~/.claude/CLAUDE.md`; and per-repo, for
each of codex-workflow, claude-workflow, opencode-workflow,
pi-agentic-apps-workflow: the root instruction file, the trigger `SKILL.md`,
and the scaffolder template that ships to new projects — with claude-workflow
as the reference host getting the change first per ADR-0008's precedent, then
mirrored via each host's own migration chain to reach existing installs, the
same propagation pattern used for the ADR-0008/migration-0007 knowledge-capture
rollout):

1. **Archive, don't clobber.** Before writing `<host-marker>/session-handoff.md`,
   if it already exists: copy it to
   `<host-marker>/session-handoff-archive/<its own header date>.md` (creating
   the archive directory if needed) — never `rm` it outright, and never let a
   fresh write touch the live path until the archive copy has succeeded. This
   is a straight port of the migrations' `.bak`-then-mutate idiom
   (`sed -i.NNNN.bak ...; rm -f *.bak` only after success) to a plain-prose
   copy-then-write step.
2. **Skip on insignificant sessions.** Add an explicit significance gate to the
   write trigger: a session whose only activity was a trivial, single-file,
   no-decision edit (the rule can borrow this repo's own existing "Tiny"
   task-size bucket, already defined in the skill routing table just above the
   Session handoff section in every copy — `AGENTS.md`/SKILL.md already say
   "Tiny (typo, comment, README) → `superpowers:verification-before-completion`")
   does not trigger a handoff write at all; the existing handoff (if any) is
   left untouched.
3. **Decide, separately, whether archives are gitignored or tracked** (open
   question, not resolved by this document) — the live file's disposability
   rationale (host-local scratch, not shipped) doesn't automatically transfer
   to an archive directory whose only job is being a recovery net; tracking
   just the archives (not the noisy live file) may thread the needle between
   Option (a) and the recoverability benefit of Option (c) without inheriting
   (c)'s downsides. This choice should be made deliberately when the fix is
   implemented, not defaulted silently either way.
4. Fix the divergence noted above as a side item: resync
   `codex-workflow/AGENTS.md` and `skills/agentic-apps-workflow/SKILL.md`
   against the format template and 150-line cap already present in
   `skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md`
   — the copy that actually governs sessions in this repo should not be looser
   than what ships to every other project.

No files were modified to produce this document beyond the new file itself, per
the read-only constraint. `.codex/session-handoff.md` was read but not touched.
