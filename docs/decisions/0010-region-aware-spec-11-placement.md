# ADR-0010: Anchor the §11 block above a leading GitNexus region

**Status**: Accepted  **Date**: 2026-07-15
**Core contract**: `agenticapps-workflow-core/spec/12-authoring-conventions.md` §"Placement of behavior-critical prose (advisory)" (lines 93-113)
**Sibling host**: claude-workflow — design doc `docs/superpowers/specs/2026-07-15-spec-11-region-aware-placement-design.md` / migration-0029, pinned at `8520f90d235e0c50b0484b170d595ab6f2cd1173`

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

   **The strip asserts nothing about the block's content (D-26).** Because the
   boundary is structural it is bounded by construction, so a drifted block cannot
   cause a runaway, and 0009 must not refuse to *place* a block merely because its
   prose drifted — content fidelity is 0004's job. A `diff` against the mirror
   gating the strip with `exit 3` was explicitly considered and declined.

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
   third review — the pinned commit `8520f90` is literally *"close truncated-mirror
   gap, add its missing test"*.

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

6. **The upstream reference is pinned at
   `8520f90d235e0c50b0484b170d595ab6f2cd1173` (D-48), not chased.** claude-workflow's
   0029 changed **four times during this phase's planning session alone** (13:52
   ship → 14:08 fixture 09 → 14:27 fixture 10 → 14:34 third-review mirror fix), and
   three of those landed after this phase's context was finalized. Recording the
   SHA is what makes the phase's scope knowable after the fact: everything this
   port read came from
   `git -C ../claude-workflow show 8520f90:migrations/0029-region-aware-spec-11-placement.md`,
   and any upstream change after the pin is a deliberate follow-up diff rather than
   an invisible mid-execution scope change.

   The pin justified itself during execution. Upstream HEAD was observed at
   `496acfc9` when validation started and at `28b393b8` roughly ten minutes later
   when its evidence was recorded — 0029 moved *again, mid-execution*, a fifth time
   (09-VALIDATION-EVIDENCE.md §3). Chasing it would have been unbounded; pinning
   cost nothing.

   **The two hosts converged rather than diverged.** Both shipped the same anchor
   rule and the same terminator alternation, from the same design, within hours of
   each other, and both independently made and corrected decision 2's false-invariant
   error the same day. The pinned document's alternation appears at three sites
   (`:202` strip, `:228` insert, `:302` rollback); the two load-bearing sites are
   ported here and `:302` is deliberately not, per decision 5.

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

*(Recorded by task 2 — see below.)*

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
