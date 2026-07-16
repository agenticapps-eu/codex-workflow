# Phase 9 — Empirical Replay Evidence (ANCHOR-03 / ANCHOR-04)

This file is the **recorded evidence** Success Criterion 1 demands. The criterion says
the anchor rule *"has been validated empirically … **before** migration 0009 is written."*
That is a recorded-evidence requirement, not a claim to assert — so what follows is the
verbatim output of a committed replay script, not a summary of it.

Nothing here is an argument. Every claim in the final section cites a line of recorded
output that a verifier can reproduce by re-running the command below.

---

## 1. The run

| | |
|---|---|
| **Command** | `bash migrations/validate-0009-anchor.sh` |
| **Date (UTC)** | 2026-07-15 13:32:34Z |
| **Exit status** | `0` |
| **Script** | [`migrations/validate-0009-anchor.sh`](../../../migrations/validate-0009-anchor.sh) (committed, not a throwaway) |

## 2. This repo's SHA

```
47c67fdef82794662590397b8c329b219df80e0f
```

Captured with `git rev-parse HEAD` at the moment of the recorded run — the commit that
added the counter-replays (`47c67fd`), i.e. the script in its final form.

The script's stdout deliberately contains **no** SHA and **no** absolute path. Echoing
`git rev-parse HEAD` into the output would invalidate this record on the very next commit
— including the commit that records it — and `$REPO_ROOT` would diverge between a git
worktree and the main checkout. Either would make the "re-run and diff stdout" check in
§5 unsatisfiable by construction (T-09-04). The volatile facts live here, in the header;
the fenced block below is deterministic across runs and checkouts.

## 3. Pinned upstream reference (D-48)

| | |
|---|---|
| **Pin (the reference actually used)** | `8520f90d235e0c50b0484b170d595ab6f2cd1173` |
| **Observed `git -C ../claude-workflow rev-parse HEAD`** | `28b393b87885f3cfe3671c90fb112490c8c7e7e0` |
| **Observed upstream branch** | `fix/0029-spec-11-region-aware-placement` |
| **Is the pin an ancestor of upstream HEAD?** | yes (`git merge-base --is-ancestor` → 0) |

**Upstream HEAD differs from the pin. Stated plainly as a recorded fact: the pinned
content was used regardless.** The awk in `candidate_strip` / `candidate_insert` was read
via `git -C ../claude-workflow show 8520f90:migrations/0029-region-aware-spec-11-placement.md`
and ported from lines 192-210 (strip) and 226-246 (insert), with `CLAUDE.md` retargeted to
an input path. No content at upstream HEAD was read into this phase. Upstream drift is a
follow-up note, never a licence to absorb changes mid-phase.

**D-48 confirmed live during this plan's own execution.** Upstream HEAD was observed at
`496acfc9622bd285f383f3957a3861362f9f9091` when this plan started and at
`28b393b87885f3cfe3671c90fb112490c8c7e7e0` ~7 minutes later, when this evidence was
recorded. 0029 moved *again, mid-execution* — exactly the churn D-48 anticipated when it
recorded four changes during the planning session alone. Chasing it would have been
unbounded; pinning cost nothing.

**Port fidelity.** The pinned document carries the terminator alternation
`(/^## / || /^<!-- gitnexus:start -->$/)` at exactly three sites — verified against the pin:

| Pinned site (`0029-region-aware-spec-11-placement.md`) | Line | Ported here? |
|---|---|---|
| Step 1 Apply — strip pass terminator | `:202` | yes → `candidate_strip` |
| Step 1 Apply — insert pass anchor condition | `:228` | yes → `candidate_insert` |
| Step 1 Rollback — removal pass terminator | `:302` | **no** — 0009's Rollback is `git checkout AGENTS.md` (D-47) |

The two load-bearing sites are both carried, matching 09-PATTERNS.md's enumerated
checklist. This is the corrected D-24 requirement: every terminator carries the same
alternation as the anchor.

## 4. Verbatim replay output

Recorded verbatim from the run described in §1 — not summarized, paraphrased, or re-typed.

```
=== validate-0009-anchor — empirical replay of the D-21 anchor + D-24 terminator ===
Pinned upstream: claude-workflow @ 8520f90d235e0c50b0484b170d595ab6f2cd1173 (D-48)
Mirror:          skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md (79 lines)

--- CASE 1 (ANCHOR-03): replay strip+insert over the real AGENTS.md
  PASS CASE 1 ZERO CHURN — candidate rule re-derives §11's current position byte-identically

--- CASE 2 (ANCHOR-04): replay insert over a synthesized gitnexus-led AGENTS.md
  PASS CASE 2 ABOVE REGION — provenance at line 5 is above gitnexus:start at line 86; region intact and paired (start=1 end=1), body at line 93

--- COUNTER-CASE A (D-36): replay the NAIVE anchor (0001:91) over the same gitnexus-led file
  PASS COUNTER-CASE A (counter) NAIVE ANCHOR INSERTS INSIDE REGION — naive rule put provenance at line 10, INSIDE the region that opens at line 5 (the latent defect, observed live)

--- COUNTER-CASE B (D-24): replay NARROW vs WIDENED strip terminators over the already-healed file
  PASS COUNTER-CASE B (counter) NARROW TERMINATOR EATS REGION — start marker DESTROYED (start=0) while gitnexus:end survives (end=1): an orphaned, unpaired region; region body content gone
  PASS WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=1 end=1), body at line 8, and the §11 block was still cleanly stripped (no provenance left)

=== RESULT: all cases PASSED ===
```

*(The script emits one leading blank line before the banner; it is elided from the fence
above only because a leading blank line inside a fenced block is not reproducible by eye.
Diff against `bash migrations/validate-0009-anchor.sh | sed '1{/^$/d;}'` if checking
byte-for-byte.)*

## 5. Mutation demonstration — counter-case B is live

A counter-case never observed failing is not a counter-case. Per Task 2's acceptance
criteria, `narrow_strip`'s terminator was temporarily widened with
`|| /^<!-- gitnexus:start -->$/` — making the "narrow" rule no longer narrow — and the
script re-run. It must then report that the narrow terminator FAILED to destroy the region,
and exit non-zero.

**Mutated run — `narrow_strip` line 176 changed to
`in_block && swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/) {`:**

```
--- COUNTER-CASE B (D-24): replay NARROW vs WIDENED strip terminators over the already-healed file
  FAIL COUNTER-CASE B NARROW TERMINATOR EATS REGION — narrow terminator did NOT destroy the region (start=1 end=1, body line 8). The narrow rule behaved correctly, so D-24's alternation is not shown to be load-bearing and the WIDENED assertion below is dead-by-construction.
  PASS WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=1 end=1), body at line 8, and the §11 block was still cleanly stripped (no provenance left)

=== RESULT: 1 case(s) FAILED ===
MUTATED_EXIT=1
```

**Reverted run — mutation undone, script byte-identical to the committed version:**

```
--- COUNTER-CASE B (D-24): replay NARROW vs WIDENED strip terminators over the already-healed file
  PASS COUNTER-CASE B (counter) NARROW TERMINATOR EATS REGION — start marker DESTROYED (start=0) while gitnexus:end survives (end=1): an orphaned, unpaired region; region body content gone
  PASS WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=1 end=1), body at line 8, and the §11 block was still cleanly stripped (no provenance left)

=== RESULT: all cases PASSED ===
REVERTED_EXIT=0
```

The assertion tracks the rule rather than the weather: it fails when the rule it guards is
wrong, and passes when it is right. This is the direct antidote to the Phase 8 defect class
where assertions that could never match silently passed and read as coverage (D-36:
*"non-empty is not the same as correct"*).

---

## 6. Claims and their evidence

Four claims. Each cites the recorded output line that supports it, so a verifier can
confirm the replay happened rather than take the claim on faith.

### Claim 1 (ANCHOR-03) — the candidate rule causes zero churn on the real AGENTS.md

> Replaying `candidate_strip` then `candidate_insert` over this repo's real `AGENTS.md`
> re-derives §11's current position **byte-identically**.

**Evidence — §4, CASE 1 line:**
`PASS CASE 1 ZERO CHURN — candidate rule re-derives §11's current position byte-identically`

The assertion is `diff` of the replay output against the untouched original; PASS iff
byte-identical, with the full diff printed on failure. **Not vacuous:** `AGENTS.md:18`
(`## Coding Discipline (NON-NEGOTIABLE)`) is the first `## ` line in the file, the strip
genuinely removes 81 lines (provenance + 79 mirror lines + the single trailing blank 0001
injects — 313 → 232), and the insert genuinely re-adds them. A strip that silently did
nothing would cause the insert to add a *second* block and fail this diff.

### Claim 2 (ANCHOR-04) — the candidate rule anchors above a leading region

> On a gitnexus-led file, the block lands **above** `<!-- gitnexus:start -->`, and the
> region survives intact with its markers paired.

**Evidence — §4, CASE 2 line:**
`PASS CASE 2 ABOVE REGION — provenance at line 5 is above gitnexus:start at line 86; region intact and paired (start=1 end=1), body at line 93`

5 < 86. The synthesized fixture places a `## Some Section` heading **after** the region
deliberately: that ordering is what discriminates D-21's rule ("first `## ` **or** an
anchored marker, whichever comes first") from D-22.1's rejected "the region is always the
anchor" alternative. Marker counts `start=1 end=1` confirm the insert did not orphan or
duplicate a marker.

### Claim 3 (D-36) — the naive anchor genuinely fails ANCHOR-04

> The incumbent `/^## / && !done` rule (`migrations/0001-inject-spec-11-coding-discipline.md:91`)
> inserts §11 **inside** the GitNexus region — the latent defect this phase exists to close.

**Evidence — §4, COUNTER-CASE A line:**
`PASS COUNTER-CASE A (counter) NAIVE ANCHOR INSERTS INSIDE REGION — naive rule put provenance at line 10, INSIDE the region that opens at line 5 (the latent defect, observed live)`

10 > 5 — the naive rule anchored on `## Always Do`, the region's own heading, because that
is the first `## ` in a gitnexus-led file. The defect is **observed**, not argued. This also
proves Claim 2 is discriminating: the two rules demonstrably disagree on the same input
(candidate → line 5, naive → line 10), so CASE 2's PASS reflects the rule under test rather
than a property any rule would satisfy.

### Claim 4 (D-24) — the terminator alternation is load-bearing, not cosmetic

> A narrow `/^## /`-only strip terminator **destroys** the GitNexus region on an
> already-healed file; the widened terminator does not.

**Evidence — §4, COUNTER-CASE B lines:**
`PASS COUNTER-CASE B (counter) NARROW TERMINATOR EATS REGION — start marker DESTROYED (start=0) while gitnexus:end survives (end=1): an orphaned, unpaired region; region body content gone`
`PASS WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=1 end=1), body at line 8, and the §11 block was still cleanly stripped (no provenance left)`

`start=0 end=1` is precisely the orphaned, unpaired region the source design reports: the
narrow strip runs past `<!-- gitnexus:start -->` hunting a `## `, eats the marker and the
region's real content, and halts only at the region's own `## Always Do`. The widened rule
on the same input yields `start=1 end=1` with the body intact **and** still strips the §11
block cleanly (no leftover provenance) — so the alternation buys region safety without
costing strip correctness. This is the assertion the pre-correction CONTEXT.md would not
have caught; without it the phase could ship green and still eat a GitNexus region.
Its liveness is demonstrated in §5, not assumed.

---

## 7. Gate

**This evidence exists and shows PASS (exit 0, all five labels), therefore plan 09-04 is
unblocked to author migration 0009's Step 1 Apply block (ROADMAP hard ordering 1:
"validate before you write").**

The rule 09-04 is cleared to author is the one replayed above, at both load-bearing sites:

- **Anchor (D-21/ANCHOR-01/ANCHOR-02):** `!inserted && (/^## / || /^<!-- gitnexus:start -->$/)`, with an EOF fallback in `END`.
- **Strip terminator (D-24):** `in_block && swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/)`, with `swallowed_own_h2` gating so the block's own `## Coding Discipline (NON-NEGOTIABLE)` heading cannot terminate its own strip.

Both marker regexes are anchored (`^...$`) so a prose mention of the marker in backticks
can never be mistaken for a real region.

*Recorded 2026-07-15 by plan 09-01. Reproduce with `bash migrations/validate-0009-anchor.sh`.*

---
---

# RED OBSERVED (TEST-02) — recorded by plan 09-03

ROADMAP hard ordering 2 says the fixture suite must FAIL before migration 0009 exists,
then turn GREEN once it ships. *"A suite that was never observed RED is not evidence"*
(09-VALIDATION.md, Dimension 8 item 2). This section is that observation — the auditable
half of RED-before-GREEN. It is a **recorded-evidence** requirement, not a claim to assert,
so what follows is verbatim harness output.

## 8. The RED run

| | |
|---|---|
| **Command** | `migrations/run-tests.sh 0009` |
| **Date (UTC)** | 2026-07-15 13:53:32Z |
| **Exit status** | `1` — **RED, and required** |
| **Result** | `PASS: 0` / `FAIL: 25` |
| **This repo's SHA at the recorded run** | `23153932373e6728f0f938cb3d5c2bd7cde1f527` |

The SHA is the commit that added cases 01-06 (`2315393`, plan 09-03 Task 2) — i.e. HEAD at
the moment of the run. Per 09-01's finding, volatile facts live in this header rather than
in harness stdout, so the fenced block below stays diffable against a fresh run.

## 9. Proof the 0009 document does not exist

```
$ test -f migrations/0009-spec-11-region-aware-placement.md && echo PRESENT || echo ABSENT
ABSENT
```

**This is why the suite is RED, and it is deliberate.** Plan 09-03 writes the fixtures;
plan 09-04 writes the document. The suite was NOT stubbed, weakened, or given a
"skip if the document is missing" guard — a conditional skip is precisely how a suite that
never fails ships as coverage, which is the Phase 8 defect class this phase exists to close.

## 10. Verbatim RED output

Recorded verbatim from the run described in §8 — not summarized or re-typed.

```
=== Migration 0009 — Region-aware §11 placement ===
  FAIL 0009 Pre-flight: extraction is EMPTY — heading/fence shape drift
  FAIL 0009 Pre-flight: extraction does not contain 'spec-mirrors/11-coding-discipline-0.4.0.md' (extraction was empty)
  FAIL 0009 Pre-flight carries D-28.1 layer 1 (test -s — zero-byte mirror guard)
  FAIL 0009 Pre-flight carries D-28.1 layer 2 (tail sentinel — truncated mirror guard)
  FAIL 0009 Step 1 Idempotency check: extraction is EMPTY — heading/fence shape drift
  FAIL 0009 Step 1 Idempotency check: extraction does not contain 'spec-source: agenticapps-workflow-core' (extraction was empty)
  FAIL 0009 Step 1 Apply: extraction is EMPTY — heading/fence shape drift
  FAIL 0009 Step 1 Apply: extraction does not contain 'gitnexus:start' (extraction was empty)
  FAIL state A: anchored + current provenance + region later → skip (D-31/MIGR-07) — NOT ASSERTED: 0009's Step 1 Idempotency check could not be extracted
  FAIL state B: provenance present BUT block in region → heal, not skip (D-38 — the whole point) — NOT ASSERTED: extraction failed
  FAIL state C: no provenance at all → inject — NOT ASSERTED: extraction failed
  FAIL state B (D-32 variant): unterminated gitnexus:start → fails closed — NOT ASSERTED: extraction failed
  FAIL 01-gitnexus-led-inject — NOT ASSERTED: 0009's Step 1 Apply could not be extracted (the 0009 document does not exist yet)
  FAIL 02-inside-region-move — NOT ASSERTED: Step 1 Apply extraction failed
  FAIL 03-healthy-noop — NOT ASSERTED: Step 1 Apply extraction failed
  FAIL 04-no-agentsmd — NOT ASSERTED: Step 1 Apply extraction failed
  FAIL 05-unmanaged-conflict — NOT ASSERTED: Step 1 Apply extraction failed
  FAIL 06-no-heading-eof — NOT ASSERTED: Step 1 Apply extraction failed
  FAIL 09-two-provenance-heal — NOT ASSERTED: Step 1 Apply extraction failed
  FAIL 07-prose-mention-not-a-region — NOT ASSERTED: Step 1 Idempotency check extraction failed
  FAIL 08-rollback-region-led: Step 1 Rollback is 'git checkout AGENTS.md' (D-47 — structurally immune, no terminator to get wrong)
  FAIL 08-rollback-region-led: Step 1 Rollback carries NO fenced awk block — the region-eating bug class stays unreachable
  FAIL 10-corrupt-mirror-refused (a) zero-byte mirror — NOT ASSERTED: Pre-flight extraction failed
  FAIL 10-corrupt-mirror-refused (b) truncated mirror — NOT ASSERTED: Pre-flight extraction failed
  FAIL 10-corrupt-mirror-refused (c) healthy mirror — NOT ASSERTED: Pre-flight extraction failed

=== Summary ===
  PASS: 0
  FAIL: 25
```

*(The harness emits one leading blank line before the banner; elided above for the same
reason 09-01 elided it — a leading blank line inside a fence is not reproducible by eye.)*

**Every case reports FAILED, none reports SKIPPED.** That distinction is the point: a case
that silently vanishes when its input is missing is the dead-assertion defect wearing a
different hat, and the suite would exit 0 and read as coverage.

## 11. TEST-02 is evidenced in two complementary halves

TEST-02 requires the suite to *"fail against the current naive anchor"*. That phrase has a
suite-level reading and a rule-level reading, and **both are now backed by recorded output**
rather than by a claim:

| Half | What it shows | Where recorded |
|---|---|---|
| **Rule-level** — 09-01 Task 2, counter-case A | The naive rule `/^## / && !done` inserts §11 **inside** the region, on a gitnexus-led file, replayed directly | §4 / §6 Claim 3 of this file |
| **Suite-level** — 09-03 Task 2, naive-anchor override | `test_migration_0009`'s own fixtures **observed failing** when pointed at the naive anchor | §12 below |

Neither alone is sufficient. The rule-level replay proves the *rule* is wrong but says
nothing about whether the fixtures would catch it. The suite-level override proves the
*fixtures* catch it. Together they close the loop.

## 12. Naive-anchor override demonstration (the suite-level half)

These fixtures cannot pass yet, so their liveness cannot be shown by making them go green.
It is shown instead by pointing them at a real, eval-able, **known-wrong** implementation —
migration 0001's Step 1 Apply, which carries the naive `/^## / && !done` anchor this phase
exists to heal — and observing them fail.

Run against a **scratch copy** of the harness (`sed` override into `/tmp`); the tracked
`migrations/run-tests.sh` was never mutated, and `git status --porcelain` confirmed clean
before and after.

### Run 1 — `MIGRATION_0009` → 0001's document, Apply shape guard INTACT

```
  PASS 0009 Step 1 Apply: extraction from the real document is non-empty
  FAIL 0009 Step 1 Apply: extraction does NOT contain 'gitnexus:start' — the
  FAIL 01-gitnexus-led-inject — NOT ASSERTED: 0009's Step 1 Apply could not be extracted
  FAIL 02-inside-region-move — NOT ASSERTED: Step 1 Apply extraction failed
  ...
  PASS: 6
  FAIL: 12
```

**This is D-36's thesis observed live: the extraction is NON-EMPTY (PASS) and still WRONG
(FAIL).** 0001's Apply block extracts perfectly cleanly — it simply is not a region-aware
apply, because it carries no marker alternation. A non-empty check alone would have trusted
it and eval'd it. The shape guard refuses, and correctly gates all six cases.

### Run 2 — same override, Apply shape guard BYPASSED so the naive anchor actually runs

Guard bypassed by requiring `getline line < mirror` (a substring 0001's Apply *does*
contain) instead of `gitnexus:start`, so `apply_ok` stays 1 and the cases execute.

```
  FAIL 01-gitnexus-led-inject: provenance (line 10) is ABOVE gitnexus:start (line 5)
  PASS 01-gitnexus-led-inject: region markers still paired exactly once (start=1 end=1)
  PASS 01-gitnexus-led-inject: the region's own body content survived
  FAIL 02-inside-region-move: exactly ONE provenance line remains (found 2) — moved, not duplicated
  FAIL 02-inside-region-move: provenance (line 8) moved ABOVE gitnexus:start (line 5)
  PASS 02-inside-region-move: region survived intact and paired (start=1 end=1) — the D-24 terminator assertion
  FAIL 03-healthy-noop: AGENTS.md is BYTE-IDENTICAL after Apply (zero churn — catches an over-eager anchor)
  FAIL 04-no-agentsmd: Apply exits ZERO (informational skip, so Step 2's version bump still runs) — got exit=2
  FAIL 04-no-agentsmd: skip message names THIS host's skill (update-codex-agenticapps-workflow), not claude-workflow's slug
  PASS 04-no-agentsmd: Apply created no AGENTS.md out of thin air
  FAIL 05-unmanaged-conflict: Apply exits exactly 3 on an unmanaged §11 heading (State D) — got exit=0
  FAIL 05-unmanaged-conflict: hand-written §11 is BYTE-IDENTICAL after the refusal (refused AND untouched)
  PASS 06-no-heading-eof: provenance is present after Apply (END fallback fired, block not dropped)
  PASS 06-no-heading-eof: block was APPENDED at EOF (provenance at line 5, below the 3 lines of pre-existing prose)
```

**8 of 14 case assertions FAIL against the naive anchor.** What each failure means:

- **Case 01 — `provenance (line 10) ... gitnexus:start (line 5)`.** The naive rule anchored
  on `## Always Do`, the region's own heading, and injected §11 **inside** the region. These
  are **the exact line numbers 09-01's counter-case A recorded** (*"naive rule put provenance
  at line 10, INSIDE the region that opens at line 5"*). The fixture-level twin and the
  rule-level replay independently reproduce the same defect at the same coordinates.
- **Case 02 — `found 2` provenance lines.** The naive anchor has no strip pass, so it
  *duplicates* the block instead of moving it. MIGR-03 is a real behavior 0009 must add.
- **Case 03 — byte-identity BROKEN.** The over-eager anchor moved the block on a healthy
  file. **This is precisely the failure 09-CONTEXT.md says case 03 exists to catch**
  (*"it is the fixture that would catch an over-eager anchor"*), now observed catching it.
  The assertion is live, not vacuous.
- **Case 04 — `exit=2`.** 0001's Apply has no missing-AGENTS.md branch at all; awk simply
  errors on the absent file. D-33's informational skip is behavior 0009 must add.
- **Case 05 — `exit=0`, file mangled.** 0001's conflict check lives in its *pre-flight*, not
  its Apply, so the extracted Apply happily clobbers a hand-written §11. Per D-30 and the
  pinned 0029 (`:155-172`), 0009's three-branch dispatcher belongs **inside Step 1's Apply**.

**Honest accounting of the 6 assertions that PASS under the wrong rule** — recorded rather
than glossed, because a demonstration that hides its non-discriminators is a sales pitch:

- **Case 06 (both assertions) genuinely PASSES**, and should. 0001's Apply already carries a
  correct `END { if (!done) ... }` EOF fallback (verified by reading `0001`'s Step 1 Apply).
  ANCHOR-02's END path is a property 0001 already has right; the naive anchor's bug is
  *where* it inserts when a region leads, not the EOF path. Case 06 is not a
  naive-anchor detector and does not claim to be.
- **Cases 01/02's marker-pairing and region-survival assertions PASS** because the naive rule
  only ever *inserts* and never *strips* — it cannot unpair a marker. Those assertions guard
  the **strip terminator** (D-24), whose counter-case is 09-01's counter-case B (narrow
  terminator, `start=0 end=1`), not the anchor.
- **Case 04's "created no AGENTS.md" PASSES** because awk aborted outright.

So each assertion discriminates against the wrong rule it was written for, and the cases
that do not discriminate against *this particular* wrong rule are named, with the reason.

## 13. Case-07 substring mutation demonstration (Dimension 8 item 4)

09-VALIDATION.md: *"`07-prose-mention-not-a-region` is a dead-assertion detector by design.
A substring marker match passes every other fixture and fails only this one. If it passes
with a substring match, the fixture is wrong."*

Since 0009 does not exist there is no extracted check to mutate, so the candidate predicate
0009 will carry (PATTERNS.md's quoted `0029:119-130` region check, retargeted to `AGENTS.md`)
was built in a scratch script and run against case 07's fixture plus states A/B/C, with only
the marker regex varied.

**Control — anchored `/^<!-- gitnexus:start -->$/`:**

```
  ✓ 07-prose-mention-not-a-region (expect applied) (expected applied, exit=0)
  ✓ state A (expect applied) (expected applied, exit=0)
  ✓ state B (expect not-applied) (expected not-applied, exit=1)
  ✓ state C (expect not-applied) (expected not-applied, exit=1)
  -> PASS=4 FAIL=0
```

**Mutated — substring `/gitnexus:start/`:**

```
  ✗ 07-prose-mention-not-a-region (expect applied) (expected applied, got exit=1)
  ✓ state A (expect applied) (expected applied, exit=0)
  ✓ state B (expect not-applied) (expected not-applied, exit=1)
  ✓ state C (expect not-applied) (expected not-applied, exit=1)
  -> PASS=3 FAIL=1
```

**Case 07 is the ONLY failure under the mutation; every other case still passes.** That is
the specified behavior exactly. The substring match sees the marker mentioned in backticks
inside a prose comment, judges a region-less file to be region-led, and proposes to "heal" a
perfectly healthy file by moving §11 above a region that does not exist. The fixture is a
live detector, and D-21's anchoring requirement is load-bearing rather than stylistic.

The **control passing 4/4 is itself forward evidence for 09-04**: the four-state
double-sided table (including State B returning non-zero *despite provenance being present*)
is satisfiable by the D-21/D-32 predicate as specified. 09-04 is not being asked to satisfy
a contradictory contract.

## 14. Gate

**The suite was OBSERVED RED (exit 1, `PASS: 0` / `FAIL: 25`) while
`migrations/0009-spec-11-region-aware-placement.md` does not exist, and its assertions were
OBSERVED FAILING against the naive anchor specifically. ROADMAP hard ordering 2 is
discharged: plan 09-04 may now ship migration 0009 and turn this suite GREEN.**

09-04 turns it green by *shipping the document*, never by editing these fixtures. If a
fixture must change to make 0009 pass, that is a design disagreement to surface explicitly —
not a test to adjust.

*Recorded 2026-07-15 by plan 09-03. Reproduce with `migrations/run-tests.sh 0009`.*
