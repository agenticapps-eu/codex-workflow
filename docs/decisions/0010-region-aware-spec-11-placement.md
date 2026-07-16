# ADR-0010: Anchor the §11 block above a leading GitNexus region

**Status**: Accepted  **Date**: 2026-07-15
**Core contract**: `agenticapps-workflow-core/spec/12-authoring-conventions.md` §"Placement of behavior-critical prose (advisory)" (lines 93-113)
**Sibling host**: claude-workflow — design doc `docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` / migration-0029, re-pinned at `f9354cc` (upstream HEAD, PR #89 squash-merge; see the Correction section for why the original `8520f90d235e0c50b0484b170d595ab6f2cd1173` pin — a PR-branch commit that never landed on main — is superseded, not deleted)

## Correction (2026-07-15, Phase 9.1)

Phase 9.1 audited this ADR against `migrations/0009-spec-11-region-aware-placement.md`
**as shipped**, not as planned, and found one falsified decision claim and one dead
upstream citation. Both are corrected here, in place, rather than silently
rewritten — this section records what was believed, what is now known, and what
changed it. It also records three items that were never wrong in the ADR but
belong here per DOC-01: the runaway's reachability argument, V-01's root cause,
and the Q1 refuse-gate ruling with its rejected alternative.

### (1) The runaway (CR-01)

The strip's entry was decoupled from its exit: a drifted
`## Coding Discipline (NON-NEGOTIABLE)` heading latches `in_block = 1`, and
because the exit rule is gated behind `swallowed_own_h2` (only ever set by the
*exact* heading), `in_block { next }` never un-latches and eats every line to
EOF. Reproduced (`.planning/phases/09-region-aware-11-placement/09-CR-01-REPRO.md`):
16 lines → 4, destroying `## Critical Project Rules` and `## Deployment`. All
three post-strip guards passed — the third, `grep -q '^## Coding Discipline
(NON-NEGOTIABLE)$' AGENTS.md.0009.tmp`, is satisfied by the **insert pass that
runs after it**, re-adding the exact heading the guard checks for. A guard meant
to detect a bad strip is satisfied by the pass that follows the bad one.

**The reachability argument** — this is the part that makes "drifted heading"
non-exotic. The Step 1 Apply's existing conflict/abort branch fires on
`grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md && ! grep -qE
"$PROV_RE" AGENTS.md` — i.e. **heading present AND provenance absent**. CR-01
needs the **inverse**: provenance present, heading absent/drifted. That state
falls straight through the existing `else` into the strip, reachable via a
hand-edited/drifted heading, old-version provenance from an earlier migration,
or the orphaned-provenance state the migration document itself acknowledges it
can produce (`:282`).

### (2) The D-26 correction

Decision 3, as originally written, claimed: *"the boundary is bounded by construction,
so a drifted block cannot cause a runaway."* **This claim is
FALSE**, and it was load-bearing — reproduced above. D-26's underlying
*principle* survives: the strip stays blind to the block's **prose**, because
content fidelity is 0004's job, not the strip's. The reconciliation is that
heading drift and prose drift are different failure classes, and the canonical
mirror proves the distinction is real — it carries exactly one `## ` line, on
line 1, and that line is the heading (now asserted in `test_migration_0004`).
The heading is a structural boundary marker, not content. So: **prose drift →
stay blind and repair** (D-26's principle, intact); **heading drift → the
boundary is gone, refuse** (D-26's original claim, corrected). The corrected
claim: **bounded only when the heading matches — enforced by the refuse gate
and the END fail-closed guard** (both closed in 09.1-05, see item 4 below).
This is D-25's rejected content-sentinel bug class resurfacing *inside* the
structural boundary chosen to prevent it.

### (3) V-01 — a porting error, not an inherited defect

09.1's own pre-flight regression (V-01) is a **porting error**, not an
inherited upstream defect: it greped the project-relative
`skills/agentic-apps-workflow/SKILL.md`, which no target project has, so it
exited 3 on every real install and Step 1 never ran — while the suite stayed
green, because `314 PASS / 0 FAIL` was **fully consistent with a migration that
never ran.** This is a regression against an established, documented
precedent: `migrations/0008-plan-review-gate.md:470-487` (**T-08-38**) names
this *exact* defect class in migration `0007` and calls it "a defect this
migration does not replicate," because no target project carries a local
`skills/` tree — the project-side surface is `AGENTS.md`, `.planning/`,
`.codex/`, and `docs/decisions/` only, and the durable per-project version
record is `.codex/workflow-version.txt`.

**Upstream is not at fault.** Upstream `claude-workflow` greps
`.claude/skills/agenticapps-workflow/SKILL.md` — a path *its own* setup skill
creates (`f9354cc:setup/SKILL.md:146`), so the grep is correct for that host.
**This host's port dropped the `.claude/` prefix** and pointed at
`skills/agentic-apps-workflow/`, which on Codex is this scaffolder repo's own
source tree, not anything a target project carries — which is exactly why it
looked right to its author and why the test suite manufactured a synthetic
`SKILL.md` fixture to keep itself green around it. Root cause: MIGR-08 and
MIGR-09 were conflated, which `0008` (T-08-38) had kept deliberately apart.

### (4) The Q1 ruling, with its rejected alternative

**Decision:** provenance present + exact H2 absent ⇒ **refuse**, `exit 3`, file
byte-identical. One rule covers both reproduced runaway shapes because both are
exactly that condition. It closes CR-01 by construction — a strip that refuses
to run cannot run away — and is consistent with 0009's existing
never-overwrite-a-hand-paste branch. Implemented in 09.1-05 as a pre-surgery
`elif` that is the literal inverse of the existing hand-paste-conflict `elif`,
plus the strip awk's `unresolved`/**`END { exit 4 }`** fail-closed guard (a
POSIX construct, **fail-closed** by design) for the one mixed-provenance shape
the file-global refuse gate cannot see: a healthy provenance+heading pair
earlier in the file satisfies the gate's whole-file predicate while a drifted
pair later in the file still runs away — confirmed empirically, not assumed
(`09.1-05-SUMMARY.md`'s "Division of labour" section reproduces fixtures
13/14/15 in isolation and shows the refuse gate's diagnostic firing for 13/14
and the **END guard**'s distinct diagnostic firing for 15).

**Rejected: heal-and-duplicate** (the reviewer's fix (a) in `09-REVIEW.md`,
`:122-134` — un-latch at the structural boundary and insert anyway, rather than
refuse). This avoids data loss but silently leaves two similar `## Coding
Discipline` headings in the file, which a future migration's own conflict grep
would trip on. RESEARCH (`09.1-RESEARCH.md` § "Pitfall 1") further found that
un-latching alone still runs away to EOF on the orphaned-provenance shape (8
lines → 4) — the un-latch rule does not even fully close CR-01 by itself. The
refuse gate was chosen instead; the un-latch rule was **not adopted** anywhere
in 0009 (confirmed by the alternation copy count staying at exactly 2
throughout 09.1-05/06). The refuse gate is the primary mechanism; the END
guard (`END { if (unresolved || (in_block && !swallowed_own_h2)) exit 4 }`) is
its backstop for the shape the gate cannot see. Fixture
`15-mixed-provenance-unresolved` is the END guard's falsifiability proof —
09.1-05 mutated the guard away, observed the fixture still refuse (caught by a
*different*, independently-reachable layer: the h2-count strip-integrity
guard, `grep -c 'h2_out' migrations/0009-spec-11-region-aware-placement.md` →
`3`), and restored it before shipping.

### (5) D-48's re-pin

Recorded per RESEARCH Q5 — citing a dead PR-branch commit as "the upstream
reference" would send the next reader to a ref they cannot find. Both refs are
recorded, neither is erased:

- Phase 9 pinned the port at `8520f90` — a **PR-branch commit that never landed
  on main** (`git merge-base --is-ancestor 8520f90 HEAD` → NO, re-verified this
  phase);
- PR #89 squash-merged as **`f9354cc`**, upstream HEAD (`28b393b8`'s 0029 is
  byte-identical to `f9354cc`'s);
- upstream **already fixed CR-02** there — `PROV_RE` anchored at all three of
  its own sites, plus a new `11-prose-mention-provenance` fixture; **9.1 ported
  that fix rather than re-inventing it** (09.1-05, Task 1);
- 9.1 **diverges** from upstream on CR-01, which remains live at
  `f9354cc:0029:222-241` — Task 3 of this plan files that finding upstream.

`:5`, decision 4 (`:189-191`), and decision 6 (`:214-236`) are updated in place
to cite `f9354cc`, with every `8520f90` occurrence marked "as pinned during
Phase 9 (PR branch, never merged)" rather than deleted.

### Also recorded, from 09.1-05/06's SUMMARYs

- **Criterion-4 KEEP/REMOVE**: the h2-count strip-integrity guard
  (`h2_out == h2_in - h2_own`, else abort `exit 3`) was kept, not removed, based
  on a *verified mutation*, not an assumption — deleting only the strip awk's
  `END { ... exit 4 }` clause left fixture 15 still refusing (`rc=3`,
  byte-identical), caught by the h2-count guard's own distinct diagnostic
  ("the strip removed structural headings it does not own") rather than the
  END guard's. This is the opposite of RESEARCH's tentative expectation that
  the guard might be "dead by construction" once the refuse gate + END guard
  existed — the empirical mutation, not the prior reasoning, is what settled
  it.
- **WR-01's mirror single-`## ` coupling** the refuse gate rests on is now
  asserted directly in `test_migration_0004` (the canonical mirror has exactly
  one `## ` line, on line 1).
- **Awk portability (A2)** is a known limitation, recorded rather than
  verified: `END { exit 4 }` is POSIX and was verified on BSD awk 20200816;
  `gawk`/`mawk` are not installed in this environment, so portability is
  argued, not tested. This is the same exposure the pre-existing awk in this
  migration already carried — the phase does not widen it.

## Context

Migration `0001` injects the canonical §11 Coding Discipline block immediately
before the first `## ` heading in `AGENTS.md` (`0001:91`); `0004` re-injects it
the same way (`0004:77`). That anchor is only safe when the first `## ` heading
belongs to *project* content. In an `AGENTS.md` that **leads** with a
GitNexus-managed region, the first `## ` is the region's own heading — `## Always
Do` — which sits inside `<!-- gitnexus:start -->…<!-- gitnexus:end -->`. The
block lands in the region, and the next `gitnexus analyze` regenerates that
region and destroys the block with no diagnostic.

Nothing recovers from that on its own. The update engine marks a migration
pending iff `installed >= from_version && installed < to_version`; `0001`'s
`to_version` is `0.2.0`, so for any 0.6.x project it is permanently not-pending.
`0001` and `0004` are immutable and already applied, so this is fixed **forward**
by a new migration rather than by editing them:
[`migrations/0009-spec-11-region-aware-placement.md`](../../migrations/0009-spec-11-region-aware-placement.md)
(`0.6.0` → `0.7.0`) implements every decision recorded below.

**On this host the defect is LATENT, not live.** This repo's own `AGENTS.md`
carries §11 at L18 and its GitNexus region at L271-313 — the region does not lead
the file, so the naive anchor happens to land correctly here. There is no broken
repo in this project to repair. Migration `0009` exists because every project this
host scaffolds inherits the naive anchor, and any one of them whose `AGENTS.md`
is region-led is one `gitnexus analyze` away from silently losing §11.

The rule looks obvious and is not. The obvious reading of "put it above the
region" is one of the two alternatives rejected below, and the structural
invariant that everyone — including this repo's own first draft — assumed was
preserved is in fact widened. Both mistakes are recorded here because both were
made before they were caught.

## Options considered

### A. Anchor before `gitnexus:start` if a region exists, else the first `## `

**Rejected (D-22.1).** The reference design names this one exactly right: it is
*"the obvious reading of 'put it above the region', and wrong."* A region is not
always at the top. When the region starts late in the file, this rule drops the
§11 block hundreds of lines down, below whatever project prose precedes the
region. The region is only the anchor **when it comes first**.

What that violates, stated precisely: §12's placement rule is an **advisory**.
`spec/12:95-97` says so in its own words — *"This requirement is advisory,
lower-case 'should.' It is not RFC 2119 and not a conformance gate, but host
implementations are encouraged to honor it."* Option A therefore fails an
advisory this host chooses to honor, not a normative gate. Both the source prompt
and the reference design phrase this loosely; this ADR does not, and does not
upgrade the advisory to a conformance obligation in order to make the rejection
sound stronger than it is.

### B. Always insert immediately after the H1

**Rejected (D-22.2).** This was the reference design's own earlier option, and it
is the alternative the source prompt omitted entirely — recorded here because an
omitted alternative is the one most likely to be re-proposed by the next author.
Placing the block immediately after the H1 unconditionally moves it in **every**
healthy repo, for no benefit: it churns files that were never broken (this repo's
own `AGENTS.md` among them), and it breaks the followed-by-`## ` invariant that
`0001`/`0004`'s strip logic depends on, since the block would then be followed by
whatever arbitrary prose the H1 introduces.

### C. Anchor on the first `## ` heading **or** an anchored `<!-- gitnexus:start -->` marker — whichever comes first — chosen

Insert immediately before the first line that is **either** a `## ` heading **or**
a line that is *exactly* `<!-- gitnexus:start -->`; EOF if neither. This keeps the
block near the top when the region starts late (option A's failure), leaves
healthy files byte-identical (option B's failure), and moves the block above the
region exactly when the region leads the file.

## Decision

1. **The anchor rule (D-21).** Insert immediately before the first line matching
   `(/^## / || /^<!-- gitnexus:start -->$/)`, with an EOF fallback in awk's `END`
   block. "Whichever comes first" is the whole rule — the region is the anchor
   only when it precedes all project headings.

   **The marker regex MUST be anchored** (`/^<!-- gitnexus:start -->$/`), never a
   substring match. This matters in exactly one case, which is why it is easy to
   get wrong and never notice: a file whose *prose* mentions the marker — as a
   scaffolded project's own `AGENTS.md` guidance comment does, in backticks — is
   not a region-led file. An unanchored match judges such a file in-region and
   proposes to "heal" a perfectly healthy file by moving §11 above a region that
   does not exist. A substring match passes every other fixture and fails only
   this one; fixture `07-prose-mention-not-a-region` exists to be the single
   detector of it, and was observed failing under a deliberately substring-mutated
   predicate while all other cases still passed (09-VALIDATION-EVIDENCE.md §13).

2. **The structural invariant is WIDENED, not preserved. This is the single most
   important item in this ADR.**

   The invariant that holds after migration 0009 is:

   > The block is always followed by a `## ` line, an anchored
   > `<!-- gitnexus:start -->` marker, or EOF.

   An earlier draft of this repo's own decision record claimed instead that the
   change was *"a one-alternation delta, so the structural invariant survives: the
   block is still always followed by a `## ` or EOF."* **That claim was false, and
   it was load-bearing.** It is false by construction: once the anchor can be a
   marker line, a healed region-led file — the exact case the migration exists to
   produce — has the block followed by `<!-- gitnexus:start -->`, which is neither
   a `## ` line nor EOF. The old invariant is not left intact by the delta; it is
   replaced by it.

   The consequence is the reason this paragraph exists: **every terminator that
   bounds the managed section must carry the same alternation as the anchor**,
   because the anchor rule and the terminator rule are one decision, not two. A
   `/^## /`-only terminator runs straight past the marker on an already-healed
   file and consumes the **entire GitNexus region** plus everything up to the next
   `## ` or EOF — leaving an orphaned, unpaired `<!-- gitnexus:end -->` — and it
   does so on an ordinary idempotent re-run, not on some exotic input. This is
   precisely the runaway-strip hazard that decision 3's structural boundary was
   chosen to avoid, resurfacing *inside* that boundary. The structural boundary is
   only safe once its terminator set equals the anchor's terminator set.

   Recorded rather than quietly corrected, because the false rationale is more
   dangerous than an absent one: a future author who trusts it will narrow a
   terminator, see the suite stay green (see Verification — no fixture catches
   this), and ship a file-destroying bug. The error was caught and corrected the
   same day, independently, in both this repo and the sibling host — claude-workflow's
   design doc carries its own correction under §"The invariant this breaks
   (corrected 2026-07-15 after Task 2 review)", reporting the identical failure and
   noting it was *"Verified empirically."* Two hosts made the same mistake from the
   same reasoning and caught it the same way, which is the strongest available
   evidence that the mistake is a natural one rather than a lapse.

3. **The strip boundary is structural, and blind to the block's content (D-24,
   D-25, D-26).** The managed block spans: provenance comment → its own
   `## Coding Discipline (NON-NEGOTIABLE)` heading → everything up to the next
   line matching `(/^## / || /^<!-- gitnexus:start -->$/)`, or EOF. The block's
   own heading is swallowed explicitly (`swallowed_own_h2`) before the terminator
   search begins, or the strip terminates on the block's own heading and leaves
   the body behind; that flag is **reset at the terminator**, so a second
   provenance line re-enters cleanly rather than inheriting a stale swallow state
   (fixture `09-two-provenance-heal`).

   **Rejected: 0004's content sentinel (D-25)** — terminating the strip on §11's
   last prose line (`/session-level discipline the model brings to every diff\.$/`).
   It couples the strip boundary to the block's *prose*, and prose drift in that
   exact block is *why migration 0004 had to exist in the first place*. Worse, its
   shape is `inblk {next}` until the sentinel matches, so if that line ever changes
   the strip never terminates and **deletes the entire rest of the file**. 0004
   escaped this only by luck: its drift (75→79 lines) added blank lines *inside*
   the block and left the closing line intact. That is not a boundary; it is a
   boundary that has not failed yet.

   **The strip asserts nothing about the block's content (D-26).** *(Corrected
   2026-07-15, Phase 9.1 — the original claim in this decision was reproduced
   false; see the Correction section below for the full account.)* The surviving
   principle: 0009 must not refuse to *place* a block merely because its prose
   drifted — content fidelity is 0004's job. A `diff` against the mirror gating
   the strip with `exit 3` was explicitly considered and declined.

4. **Re-injection re-vendors from the mirror (D-27), guarded twice (D-28.1).**
   After stripping, the block is re-injected fresh from
   `skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md`,
   streamed via `getline` and never transcribed into the migration document —
   exactly what 0001 and 0004 already do. This unifies **States B and C into one
   code path**: the insert always reads the mirror, and "move" simply strips first.
   There is no separate inject branch to drift from the move branch.

   Because D-27 makes the mirror the **sole** re-injection source, the pre-flight
   guards it in two layers, both refusing with `exit 3`:
   - `test -s` — a zero-byte mirror. **`test -f` is insufficient**, and was proven
     so upstream: an interrupted `git pull` in the scaffolder clone leaves a
     zero-byte mirror that `test -f` happily passes, after which the strip removes
     the project's real §11 and the insert adds nothing — silently committing a
     maimed `AGENTS.md` on every heal.
   - `grep -q '^### 4\. Goal-Driven Execution$'` — a truncated mirror. Non-empty is
     not the same as un-truncated: the block's own heading is on **line 1**, so a
     mirror truncated at the tail passes both `test -s` and the insert pass's own
     shape assertion, which greps for that same line-1 heading. Both are
     single-point guards on a continuum. A real truncation loses the tail long
     before it loses the head, so the last structural `### ` heading is the cheap
     guard that closes the gap between "has a heading" and "is the whole block".

   **This is not decision 3's rejected content sentinel wearing a disguise.** D-25
   rejects coupling a **strip terminator** to §11's last *prose* line, where drift
   makes the strip run away and eat a file. This is a read-only integrity check on
   a **different file**, anchored to a **structural heading**; it bounds nothing,
   strips nothing, and cannot run away. Different mechanism, different failure
   mode, different file. This gap is the one claude-workflow closed in its own
   third review — the PR-branch commit `8520f90` (as pinned during Phase 9; it
   never merged to main as such — see decision 6's correction) is literally
   *"close truncated-mirror gap, add its missing test"*; that fix is present,
   squash-merged, at upstream HEAD `f9354cc`.

5. **Rollback is `git checkout AGENTS.md` (D-47) — a deliberate tradeoff,
   recorded.** The alternative was porting 0029's bespoke Rollback awk, a third
   removal pass that would have to carry the same terminator alternation as Apply.
   That construct is exactly what required upstream to add a post-review fixture to
   catch a file-destroying bug: a narrow-terminator removal run over a healed
   region-led file eats the start marker and the region's real content.
   `git checkout` is **structurally immune** — there is no terminator to get wrong,
   so decision 2's entire bug class is unreachable in this host's rollback rather
   than merely tested-for. Migration rollbacks in this repo already run inside a
   `test -d .git`-guarded context (pre-flight guard 1), and this follows `0004:87`'s
   precedent.

   The cost, stated: this host's rollback depends on git state rather than being
   self-contained, and it restores the *whole file* rather than only this
   migration's change — an uncommitted unrelated edit to `AGENTS.md` is discarded
   along with the heal. That is accepted. Fixture `08-rollback-region-led` is kept
   anyway, even though D-47 downgrades it from a live bug hunt to a cheap
   regression guard: it is the only case exercising Rollback at all, and it is what
   stops a future author from "improving" `git checkout` into the awk that eats the
   region.

6. **The upstream reference is pinned at `f9354cc` (D-48, re-pinned 2026-07-15
   Phase 9.1 — see the Correction section), not chased.** claude-workflow's
   0029 changed **four times during this phase's planning session alone** (13:52
   ship → 14:08 fixture 09 → 14:27 fixture 10 → 14:34 third-review mirror fix), and
   three of those landed after this phase's context was finalized. Recording the
   SHA is what makes the phase's scope knowable after the fact: everything Phase 9's
   port read came from
   `git -C ../claude-workflow show 8520f90:migrations/0029-region-aware-spec-11-placement.md`
   — **as pinned during Phase 9 (PR branch, never merged)** — and any upstream
   change after that pin is a deliberate follow-up diff rather than an invisible
   mid-execution scope change. Phase 9.1 re-pins the *citation* (not the port) to
   `f9354cc`, the commit `8520f90` squash-merged into as PR #89, because
   `8520f90` is unreachable from upstream's own `main`
   (`git merge-base --is-ancestor 8520f90 HEAD` → NO) and citing a dead commit as
   "the upstream reference" would send the next reader to a ref they cannot find.

   The pin justified itself during execution. Upstream HEAD was observed at
   `496acfc9` when validation started and at `28b393b8` roughly ten minutes later
   when its evidence was recorded — 0029 moved *again, mid-execution*, a fifth time
   (09-VALIDATION-EVIDENCE.md §3). Chasing it would have been unbounded; pinning
   cost nothing. `28b393b8`'s 0029 is byte-identical to `f9354cc`'s.

   **The two hosts converged rather than diverged.** Both shipped the same anchor
   rule and the same terminator alternation, from the same design, within hours of
   each other, and both independently made and corrected decision 2's false-invariant
   error the same day. The pinned document's alternation appears at three sites
   (`:202` strip, `:228` insert, `:302` rollback); the two load-bearing sites are
   ported here and `:302` is deliberately not, per decision 5.

   Upstream **already fixed CR-02** at `f9354cc` (`PROV_RE` anchored at all three
   of its own sites, plus a new `11-prose-mention-provenance` fixture) — 9.1
   **ported that fix rather than re-inventing it** (see the Correction section,
   item 5). 9.1 **diverges** from upstream on CR-01, which remains live at
   `f9354cc:0029:222-241` — see item 1 below and Task 3's filed report.

## Consequences

The §11 block moves above a leading GitNexus region on any project this host
scaffolds; on a file whose region does not lead, nothing moves. This repo's own
`AGENTS.md` is unchanged — the defect here was latent, and migration 0009 is
byte-identical-in, byte-identical-out against it.

A State-B move **silently repairs a drifted block** as a side effect (D-28.2).
This is a stated consequence, not an accident: the re-injection re-vendors from
the mirror, so a block that drifted from canonical §11 comes back canonical after
being moved. A drifted block that is *not* in a region is not moved and stays
drifted — that remains 0004's job, not 0009's.

Rollback now depends on git state (decision 5). The migration refuses rather than
overwrites when it finds a `## Coding Discipline (NON-NEGOTIABLE)` heading with no
provenance, inheriting 0001's never-overwrite-a-hand-paste rule. A project with no
`AGENTS.md` takes an informational skip and still records `0.7.0`, because an abort
there would strand it below `to_version` permanently.

Every future terminator over this managed section inherits decision 2's
obligation: it must carry the anchor's full alternation, or it eats the region.

## Setup parity (SETUP-01)

The natural worry about an anchor change is that the *setup* path carries its own
copy of the placement logic, so healing the migration chain leaves fresh installs
still broken. **On this host it does not.** Verified, each claim with its evidence:

- **Setup has no independent §11 placement logic.** `migrations/0000-baseline.md:102`
  is a plain `cat …/templates/agents-md-additions.md >> AGENTS.md` append — an
  unconditional concatenation with no anchor, no heading search, and no awk. The
  template it appends carries **no §11 at all**: it runs `## Development Workflow`
  → … → `## Pre-execution Gate — Plan Review (spec §02)`, and contains zero
  occurrences of `Coding Discipline` or `spec-source` (re-verified for this ADR
  rather than inherited).
- **Setup applies `0000-baseline` only, and lands the project at `0.1.0`.** Stage C
  walks that one migration step by step; Stage D's post-check asserts
  `.codex/workflow-version.txt` reads `0.1.0` (`skills/setup-codex-agenticapps-workflow/SKILL.md:109`).
- **§11 therefore arrives via migration `0001`** in the subsequent update chain, and
  migration `0009` heals its placement.

So the anchor rule has exactly **one source — the migration chain**. A future
change to the anchor has exactly one place to look, and that is the whole point of
recording this: there is no second implementation to keep in sync, and none should
be added.

**Why no parity guard is needed (D-44).** `spec/08-migration-format.md:27-33` makes
the **end state** normative rather than the mechanism, and names two conformant
strategies: *"**replay** (setup applies every migration from `0000-baseline`
forward) and **snapshot** (setup installs a prebuilt artifact assembled from those
same sources, with a drift guard in CI proving artifact and sources agree)."* This
host is **replay**; claude-workflow is **snapshot**, which is exactly why it ships
`migrations/check-snapshot-parity.sh` and an anchor-parity guard, and why this host
ships neither. §08 conformance is satisfied here **by construction** — there is no
second anchor to guard, because there is no second artifact. SETUP-01 is a
record-the-fact requirement, not a build-a-guard one; adding a guard here would be
guarding the absence of a thing.

**The limitation that bounds this claim (D-45), stated without hedging.** The
update skill has a **multi-hop chain-selection defect**: it selects pending
migrations *once* from the project's initial version and never recomputes the
version after each hop. A freshly scaffolded project sits at `0.1.0`, so it selects
only `0001`, applies it, lands at `0.2.0`, and then fails the final target-version
check. **"Setup end-state ≡ full replay" therefore does NOT complete in one
invocation today.** This ADR does not assert an end-state conformance this host
cannot currently demonstrate — what is demonstrated is the single-source property
above, not that a single `/update-codex-agenticapps-workflow` invocation walks a
fresh project to `0.7.0`.

The defect is deferred to its own phase (see Open follow-ups) and does **not** block
migration 0009, whose supported floor is `0.6.0 → 0.7.0` — a single hop, and where
every live project already sits after `0008`.

## Verification

The anchor rule was validated empirically **before** migration 0009 was written
(ROADMAP hard ordering 1). The evidence is recorded verbatim in
`.planning/phases/09-region-aware-11-placement/09-VALIDATION-EVIDENCE.md` and is
reproducible via `bash migrations/validate-0009-anchor.sh` (committed, exit 0,
five labels):

- **Zero churn on the real `AGENTS.md`** (§6 Claim 1) — and non-vacuous: the strip
  genuinely removes 81 lines (313 → 232), so a no-op strip would double-insert and
  fail the diff.
- **Above-region on a gitnexus-led file** (§6 Claim 2).
- **The naive anchor observed failing live** (§6 Claim 3) — provenance at line 10,
  inside the region opening at line 5.
- **The narrow terminator observed eating the region** (§6 Claim 4) — `start=0
  end=1`, an orphaned unpaired region; the widened terminator preserves it and
  still strips cleanly. Its liveness is shown by mutation (§5), not assumed.

The ten-case fixture suite is `migrations/run-tests.sh::test_migration_0009`
(cases 01-10). It was observed **RED before the migration existed** — `PASS: 0 /
FAIL: 25`, every case reporting FAILED rather than SKIPPED (§10) — and its
assertions were observed failing against the naive anchor specifically (§12), with
the six non-discriminating assertions named and explained rather than glossed. The
suite turned GREEN by shipping the document, with no assertion edited.

**Known coverage gaps, recorded rather than implied:**

- **No idempotent-re-run fixture.** `run-tests.sh` never re-applies Step 1 to an
  already-healed file, so **narrowing the strip terminator does not fail the
  suite.** Decision 2's hazard — the highest-severity mechanic in this migration —
  is demonstrated live only by `validate-0009-anchor.sh`'s counter-case B, not by
  the fixture suite. A future author who narrows the terminator will see green.
  The recommended follow-up fixture is `11-idempotent-rerun`.
- **Step 3's version is untested.** Mutating the version Step 3 records fails
  nothing in the suite.
- **A latent `want`-flag leak** exists in the fence-scoped extractor for
  *fenceless* labels; it does not affect the cases in use and is unfixed.

## Open follow-ups

Recorded, not implemented in this phase.

- **Delimit §11 with paired start/end markers — the durable retirement of this
  whole defect class.** §11 today has an *opening* marker (the `spec-source`
  provenance line) and no closing one, so the strip must infer where the block
  ends by scanning for the next `## ` heading. That single fact is the common
  root of every defect this phase fought: drift the heading and the inference
  misfires (CR-01's runaway); remove the heading entirely and it runs to EOF
  (orphan provenance); place the block at a managed region's tail and the
  inference runs past `<!-- gitnexus:end -->` and eats it (below). GitNexus
  solves this correctly *in the same file* — paired markers, extent as data, not
  inference. With paired markers the strip becomes "delete between markers": no
  terminator, no alternation to remember, no heading coupling, and each of the
  above stops being expressible rather than needing its own guard. The migration
  already re-vendors the block, so it can emit the closing marker during the
  re-vendor it performs anyway. This is the recommended successor to 0009's
  guard-stacking, not an enhancement to it.
- **§11 at the tail of a managed region — reproduced, disclosed, undefended**
  (`0009`'s "NOT refused" limitation). The strip terminator carries the region's
  START marker but not its END marker, so a §11 block sitting after a region's own
  `## ` headings makes the strip consume `<!-- gitnexus:end -->`; Step 1 exits 0
  reporting success and leaves an unterminated region. Reproduced in phase 9.1's
  UAT by A/B on §11's position alone (HEAD → `start=1 end=1`; TAIL →
  `start=1 end=0`). Not reachable via `0001:91`/`0004:77`, which inject before the
  *first* `## ` and therefore always land at the region HEAD — it needs a hand-edit
  or third-party placement, which is why it is disclosed rather than given a fifth
  guard. Subsumed by the paired-markers item above. This is the prophecy in
  decision 2 landing: *"Every future terminator over this managed section inherits
  decision 2's obligation: it must carry the anchor's full alternation, or it eats
  the region."*
- **`11-idempotent-rerun` fixture** (see Verification): re-apply Step 1 to an
  already-healed region-led file and assert the region survives paired. This is the
  fixture that would make decision 2's hazard fail the suite rather than only the
  standalone validation script.
- **0008's inlined Step-3 insert-awk copy** (`migrations/run-tests.sh` ~:985) — a
  real instance of the same drift class this phase's TEST-04 closed at `:119`, but
  reaching into another migration's tests widens a placement fix into harness
  refactoring across a 300+-assertion suite. D-37 scoped it out; tracked here so it
  is not silently unrecorded.
- **Migrations 0002 and 0003 declare `from_version == to_version`** (`0.2.0` →
  `0.2.0`) — under the engine's `installed >= from && installed < to` rule they can
  **never** be pending: dead migrations. Pre-existing, unrelated to §11 placement,
  and unsafe to "fix" without understanding why they were authored that way.
- **The update skill's multi-hop chain-selection defect** — it selects pending
  migrations once from the project's initial version and never recomputes. See the
  Setup parity section: this is what bounds SETUP-01's claim. Its own phase.
- **`implements_spec` 0.4.0 → 0.5.0+** — appears in 13+ files with no single
  authoritative one. D-17 (Phase 8) decided the field tracks a full conformance
  audit, not one gate; this migration does not make that claim.
- **Real CI (CI-01)** — `.github/workflows/ci.yml` is still the Phase 0 placeholder
  (`echo` + `exit 0`), so `run-tests.sh` runs only locally and this phase merges on
  a local green, as v0.6.0 did.
- **Note back to claude-workflow** recording the same-day convergence (decision 6):
  both hosts shipped the same rule and the same correction independently, from the
  same design. Worth reporting so the two hosts' fixture sets can be reconciled —
  upstream has an idempotent-re-run gap of its own to compare against.
- **Upstream CR-01 defect report — FILED 2026-07-15:**
  https://github.com/agenticapps-eu/claude-workflow/issues/90 — **criterion 10
  satisfied.** CR-01 (the Correction section's item 1) was **live at upstream HEAD**
  `f9354cc:0029:222-241`, and upstream's own "Known limitations" section
  (`f9354cc:0029:411-420`) listed CRLF and fenced-code-block markers but **not** the
  runaway — so upstream was unaware, not accepting. Both facts were re-verified live
  immediately before filing, and the repro was re-run against upstream's own
  unmodified strip awk (retargeted `AGENTS.md` → `CLAUDE.md`): **18 lines → 4**,
  destroying two real headings. The report body is committed at
  [`.planning/phases/09.1-11-strip-runaway-inserted/09.1-UPSTREAM-CR-01.md`](../../.planning/phases/09.1-11-strip-runaway-inserted/09.1-UPSTREAM-CR-01.md),
  scoped to **CR-01 only** (CR-02 is already fixed upstream by PR #89; V-01 is
  this host's own porting error — see Correction item 3).

  Recorded for the next reader: a first filing attempt was **denied by the
  permission system** because the approval reaching the executor was agent-relayed
  rather than the user's own. The executor refused to route around the denial —
  notably declining the available GitHub MCP tool, since the objection was to
  authorization, not tooling — and did not fabricate a URL. The block was resolved by
  obtaining the user's approval **directly**, after which the orchestrator filed from
  the main checkout. The refusal was correct behaviour and is kept here on purpose:
  the lesson is that an agent relay is not consent, not that the gate was noise.
