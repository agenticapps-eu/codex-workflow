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
