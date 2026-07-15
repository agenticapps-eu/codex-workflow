---
phase: 09-region-aware-11-placement
reviewed: 2026-07-15T17:05:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - docs/decisions/0010-region-aware-spec-11-placement.md
  - docs/decisions/README.md
  - migrations/0009-spec-11-region-aware-placement.md
  - migrations/run-tests.sh
  - migrations/validate-0009-anchor.sh
  - skills/agentic-apps-workflow/SKILL.md
  - skills/setup-codex-agenticapps-workflow/SKILL.md
findings:
  critical: 3
  warning: 5
  info: 4
  total: 12
status: issues_found
---

# Phase 9: Code Review Report

**Reviewed:** 2026-07-15T17:05:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

The anchor rule (D-21) and the terminator alternation (D-24) are correct, and I
could not break them. Counter-case A and counter-case B in
`validate-0009-anchor.sh` are genuinely non-vacuous — I re-ran both and confirmed
they discriminate. Fixture 07 really is the sole detector of an unanchored marker
regex. The `09-two-provenance-heal` reset guard works. Case 03's byte-identity
assertion is non-vacuous as claimed (the strip removes 81 lines from a 313-line
file and the insert re-adds them). The reviewed-for mechanics hold up.

The defects are elsewhere, and they are in the mechanic **adjacent** to the one
this phase hardened.

The strip's **entry** condition (an *unanchored substring* match on the
provenance comment) is decoupled from its **swallow** condition (an *exact*
match on `## Coding Discipline (NON-NEGOTIABLE)`). D-26 claims the structural
boundary makes the strip "bounded by construction, so a drifted block cannot
cause a runaway." **That claim is false and I reproduced the runaway.** When the
provenance matches but the heading does not, `in_block` latches at 1 and
`in_block { next }` deletes every remaining line to EOF. All three guards
(`[ -s ]` on the strip, `[ -s ]` on the tmp, `grep -q` for the §11 heading on the
tmp) **pass**, because the insert pass re-adds the heading the guard looks for.
`mv` then commits the truncated file. This is the same bug class D-25 rejected
the content sentinel for — resurfacing inside the boundary that was chosen to
prevent it, exactly as decision 2 warns happens with terminators.

Separately, the ADR spends its single most emphatic decision (D-21) insisting the
`gitnexus:start` regex MUST be anchored because prose mentions exist, and builds
fixture 07 solely to detect it. **The provenance regex — which is the strip's
entry condition, a strictly more dangerous position — is unanchored, and has no
equivalent fixture.**

And one dead assertion, which this repo classifies as high-severity by policy: I
deleted the `test -s` pre-flight guard and the suite stayed green. Both the
document-contract assertion and the behavioral case 10(a) pass without it.

The three known gaps recorded in the SUMMARYs/ADR (`11-idempotent-rerun`, MIGR-08,
the `want`-flag leak) are excluded below. Everything reported is distinct from
them and was reproduced, not inferred.

Note on provenance: **CR-01 and CR-02 are faithful ports.** I diffed the strip
awk against `claude-workflow @ 8520f90:migrations/0029-*.md:192-210` — upstream is
byte-identical modulo `CLAUDE.md`→`AGENTS.md`. These are inherited upstream
defects, not porting errors. That does not make them non-defects, and the ADR
already has an "Open follow-up" to report back to claude-workflow; these belong in
that note.

## Critical Issues

### CR-01: Strip awk deletes to EOF when the block's heading drifts — all three guards pass and `mv` commits the loss

**File:** `migrations/0009-spec-11-region-aware-placement.md:255-273` (strip awk);
same rule mirrored at `migrations/validate-0009-anchor.sh:66-86`
**Also contradicts:** `docs/decisions/0010-region-aware-spec-11-placement.md:154-158` (D-26)

**Issue:** The strip enters `in_block=1` on the provenance line, but only ever
leaves via a terminator gated on `swallowed_own_h2`. `swallowed_own_h2` is set
only by an **exact** match on `/^## Coding Discipline \(NON-NEGOTIABLE\)$/`. If
provenance matches and that heading does not, no rule can ever reset `in_block`,
so `in_block { next }` silently deletes the entire remainder of the file.

Reproduced. Input: provenance `@0.3.0` + a heading with one trailing space:

```
# AGENTS.md / Intro. / <PROV@0.3.0> / ## Coding Discipline (NON-NEGOTIABLE)<SP>
/ body / ## Critical Project Rules / DO NOT DELETE ME. / ## Deployment / ...
```

- Input 14 lines → strip output **4 lines**. `## Critical Project Rules`,
  `DO NOT DELETE ME.` and `## Deployment` are gone.
- `[ -s AGENTS.md.0009.strip ]` → **PASSES** (the file head survives).
- Insert runs, re-adds §11 from the mirror.
- `[ -s AGENTS.md.0009.tmp ]` → **PASSES**.
- `grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md.0009.tmp` →
  **PASSES** — because the *insert* just put that heading there. The guard
  intended to detect a bad result is satisfied by the pass that follows the bad
  one.
- `mv` commits. No diagnostic. Rollback is `git checkout`, so an operator who
  does not notice loses the content at the next commit.

**Reachability is not exotic.** The Apply's conflict branch is
`grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' && ! grep -qE "$PROV_RE"`.
A drifted heading makes the *first* grep false, so the conflict branch does **not**
fire and control falls straight into the `else` that runs the strip. Any of these
reach it:
- provenance at an older `@x.y.z` (idempotency's `@0\.4\.0` grep fails →
  not-applied → Apply) with any heading drift;
- provenance present **in-region** (idempotency correctly returns not-applied)
  with the heading damaged;
- an **orphaned provenance line with no block at all** — a state the migration
  document itself acknowledges is producible (`:282`: *"the rest of the file, plus
  an orphaned provenance line"*) — sitting inside a region.

**Fix:** Make the strip fail closed rather than run away. The entry condition must
be able to un-latch. Either (a) require the heading on the *very next* non-blank
line and otherwise treat the provenance as unmanaged prose:

```awk
# reset an unswallowed block at ANY structural boundary, not only a swallowed one
in_block && !swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/) {
  # provenance was not followed by the managed heading — do not consume the file
  in_block = 0
  print
  next
}
```

or (b) add a post-strip guard that the strip removed only what it was allowed to,
e.g. assert the strip output still contains every `^## ` heading the input had
except `## Coding Discipline (NON-NEGOTIABLE)`:

```bash
# after the strip, before the insert
if [ "$(grep -c '^## ' AGENTS.md | tr -d ' ')" -ne \
     "$(( $(grep -c '^## ' AGENTS.md.0009.strip | tr -d ' ') + \
          $(grep -c '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md | tr -d ' ') ))" ]; then
  rm -f AGENTS.md.0009.strip
  echo "ABORT: the strip removed structural headings it does not own."
  echo "       AGENTS.md left untouched."
  exit 3
fi
```

Option (a) is preferable — it removes the bug rather than detecting it. Either
way, D-26's "bounded by construction" claim in ADR-0010 must be corrected: the
boundary is bounded only when the heading matches.

---

### CR-02: The provenance regex is unanchored — a prose mention of it makes the strip delete real content

**File:** `migrations/0009-spec-11-region-aware-placement.md:165, 204, 257`;
`migrations/validate-0009-anchor.sh:69`
**Also:** `docs/decisions/0010-region-aware-spec-11-placement.md:84-93` (D-21)

**Issue:** D-21 is unambiguous that a marker regex must be anchored, and states the
reason exactly: *"a file whose prose mentions the marker … is not a region-led
file. An unanchored match judges such a file in-region."* Fixture
`07-prose-mention-not-a-region` exists solely to detect this for `gitnexus:start`.

The **provenance** regex is
`/<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/` — unanchored
on **both** sides. The version wildcard requires no anchor to be dropped;
`/^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/` would match
every real provenance line just as well. There is no fixture 07 twin.

This is the more dangerous position of the two: the marker regex only picks an
*anchor*, whereas the provenance regex arms a **destructive strip**.

Reproduced. An `AGENTS.md` documenting its own managed sections:

```markdown
## Managed Sections
The line `<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->` marks the managed block.
Do not remove it.

## Critical Project Rules
DO NOT DELETE ME.

<PROV>
## Coding Discipline (NON-NEGOTIABLE)
...
```

19-line input → strip output loses `## Critical Project Rules` and
`DO NOT DELETE ME.` entirely: the backticked mention latches `in_block=1`, and
everything from it down to the real block's heading is consumed. Non-empty output,
heading guard passes, `mv` commits.

Note the plausibility is *raised by this migration itself*: its own abort message
(`:224-227`) instructs the operator to paste that exact line into `AGENTS.md` to
adopt a section as managed. An operator who documents that instruction in
`AGENTS.md` arms the bug. (This repo's own `AGENTS.md` has provenance only at
`:17` and no prose mention — so, like the defect this phase fixes, it is latent
here and live in whatever the host scaffolds.)

**Fix:** Anchor the provenance regex everywhere it appears, matching D-21's
treatment of the marker:

```awk
/^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/
```

and in the shell:

```bash
PROV_RE='^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$'
```

Then add the fixture 07 twin — `11-prose-mention-of-provenance` — asserting a
backticked mention of the provenance comment is not treated as a block. Without
the fixture the anchoring will be "simplified" back out, exactly as D-21 predicts
for the marker.

---

### CR-03: Dead assertion — D-28.1 layer 1 (`test -s`) passes with the guard deleted, in both the document check and the behavioral check

**File:** `migrations/run-tests.sh:3467-3470` (document contract),
`migrations/run-tests.sh:3901-3908` (case 10(a))
**Guard under test:** `migrations/0009-spec-11-region-aware-placement.md:111-116`

**Issue:** Mutation-tested. I deleted the real `test -s "$MIRROR" || { …; exit 3; }`
guard (`:111-116`) and left the surrounding comments intact:

```
PASS 0009 Pre-flight carries D-28.1 layer 1 (test -s — zero-byte mirror guard)
PASS 10-corrupt-mirror-refused (a) zero-byte mirror: pre-flight refuses with exit 3 — got exit=3
```

**Both assertions stayed green with the guard gone.** Two independent causes:

1. **The document-contract check matches prose, not code.** `case "$pf_block" in
   *'test -s'*` matches the pre-flight's own *comments* — `:108`
   (``"`test -s` catches that"``) and `:114` (``"`test -s` above"``) both contain
   the literal string. The assertion cannot distinguish a guard from a comment
   about a guard.
2. **Case 10(a) cannot discriminate the layer it names.** On a zero-byte mirror,
   guard 4's `grep -q '^### 4\. Goal-Driven Execution$'` also fails (verified:
   exit 1 on a zero-byte file) and refuses with the same `exit 3`. Case 10(a)
   passes **for the wrong reason** — the tail sentinel refuses, not `test -s`.

Cause 2 is the same failure the harness explicitly guards against 12 lines earlier
(`:3893-3896`: *"THE MIRROR IS THE ONLY VARIABLE — otherwise a refusal could come
from the version gate instead and the assertion would pass for the wrong reason"*).
The version gate was controlled for; the *other guard in the same pre-flight,
firing on the same input*, was not.

Control run confirms layer 2 is genuinely live — removing the tail sentinel turns
both of its assertions RED (`layer 2` FAIL; `10(b)` FAIL, got exit=0) while 10(a)
and 10(c) stay green. So the suite discriminates layer 2 and not layer 1.

Consequence: `test -s` is currently **untested in both directions** and any future
author may delete it on a green suite. This is precisely the defect class the phase
header at `:3311-3314` says the suite exists to close.

**Fix:** Anchor the document check on the executable line, not a substring that
prose satisfies — and make the behavioral case discriminate:

```bash
# document contract: match the guard's executable shape, not any mention of it
case "$pf_block" in
  *'test -s "$MIRROR"'*) _m0009_ok 0 "0009 Pre-flight carries D-28.1 layer 1 (test -s)" ;;
  *)                     _m0009_ok 1 "0009 Pre-flight carries D-28.1 layer 1 (test -s)" ;;
esac
```

For case 10(a), assert the *diagnostic* so the layer that refused names itself:

```bash
case "$out" in
  *'missing or empty'*) _m0009_ok 0 "10(a) zero-byte mirror refused BY THE test -s layer" ;;
  *)                    _m0009_ok 1 "10(a) zero-byte mirror refused, but not by test -s (wrong layer)" ;;
esac
```

See also WR-04: layer 1 is redundant with layer 2 for *correctness*, which is why
no behavioral assertion can isolate it. If `test -s` is kept for its better
diagnostic (a defensible choice), then the diagnostic is the only thing worth
asserting — and the ADR's "two layers" framing should say so.

## Warnings

### WR-01: The strip silently assumes the mirror contains exactly one `## ` line

**File:** `migrations/0009-spec-11-region-aware-placement.md:261-270`
**Issue:** `swallowed_own_h2` swallows exactly one heading. Any *second* `^## ` line
inside the mirror body terminates the strip early: the block's tail is left behind,
and the insert then adds a full fresh block — **duplicated content**, not a
runaway. Verified the mirror currently has exactly one `## ` (line 1), so this is
latent. But this is an undocumented coupling to a file this repo does not own:
core's §11 has already drifted once (75→79 lines — the entire reason migration 0004
exists), and D-26 explicitly promises the strip is "BLIND to the block's content".
It is not blind to the block's heading count.
**Fix:** Record the coupling in ADR-0010 decision 3 and add a cheap guard to
`test_migration_0004`, next to the existing line-count assertion:

```bash
local h2; h2=$(grep -c '^## ' "$mirror" | tr -d ' ')
if [ "$h2" -eq 1 ]; then
  echo "  ${GREEN}PASS${RESET} mirror has exactly one '## ' heading (0009's strip depends on this)"
  PASS=$((PASS+1))
else
  echo "  ${RED}FAIL${RESET} mirror has $h2 '## ' headings — 0009's strip will terminate early and duplicate the block"
  FAIL=$((FAIL+1))
fi
```

---

### WR-02: The new setup-SKILL note cites the wrong step and the wrong append

**File:** `skills/setup-codex-agenticapps-workflow/SKILL.md:123-125`
**Issue:** The note says *"`0000-baseline.md`'s **Step 6** is a plain append of
`templates/agents-md-additions.md`"*. Both halves are wrong:
- `agents-md-additions.md` is appended by **Step 3** (`0000-baseline.md:91`,
  `cat … agents-md-additions.md >> AGENTS.md` at `:102`).
- **Step 6** (`0000-baseline.md:139`) appends a *different* template
  (`global-agents-additions.md`) to a *different* file (`${CODEX_HOME}/AGENTS.md`),
  and is skipped entirely on an Option B install.

ADR-0010:265 cites `migrations/0000-baseline.md:102` correctly, so this note
contradicts the ADR it links to. This matters more than a typo: the note's stated
job is to redirect a future author to the right file, and it points them at the
wrong step of it. (The ADR's other citation, `SKILL.md:109`, is correct — verified.)
**Fix:** `Step 6` → `Step 3`.

---

### WR-03: Pre-flight version-gate diagnostic contradicts the gate it reports on

**File:** `migrations/0009-spec-11-region-aware-placement.md:96-98`
**Issue:** The gate accepts `0.6.0` **or** `0.7.0` — deliberately, and the comment
at `:92-94` explains why. The abort message says `(need 0.6.0)`. An operator whose
project is at `0.7.1` is told to get to 0.6.0, which is both wrong and
unachievable. Also `INSTALLED=$(grep -E '^version:' …)` has no `-m1`, so a file
with two `^version:` lines yields a multi-line interpolation in the message.
**Fix:**

```bash
INSTALLED=$(grep -m1 -E '^version:' "$SKILL_FILE" 2>/dev/null | sed 's/version: //')
echo "ABORT: workflow scaffolder version is ${INSTALLED:-unknown} (need 0.6.0 or 0.7.0)."
```

---

### WR-04: ADR-0010's D-28.1 "two layers" framing overstates layer 1's independence

**File:** `docs/decisions/0010-region-aware-spec-11-placement.md:169-181`
**Issue:** The ADR presents `test -s` and the tail sentinel as two guards *"both
refusing with `exit 3`"*, implying independent coverage. They are not independent:
the tail sentinel `grep -q '^### 4\. Goal-Driven Execution$'` **subsumes** `test -s`
entirely — it fails on a zero-byte mirror (verified, exit 1) *and* on a missing
mirror *and* on a truncated one. `test -s` cannot refuse anything guard 4 would
accept. That is the structural reason CR-03's behavioral assertion cannot isolate
it, so the doc claim and the dead assertion are the same fact seen twice.

This is not an argument to delete `test -s` — a precise "missing or empty" message
beats grep's "No such file or directory". But the ADR should say layer 1 is a
**diagnostic** layer, not a second correctness layer, or the next author will trust
a redundancy that is not there.
**Fix:** Reword D-28.1 to state that guard 4 is the correctness guard for all three
mirror-corruption modes, and `test -s` exists for the operator-facing diagnostic on
the most common one.

---

### WR-05: `validate-0009-anchor.sh`'s "deterministic banner" claim is contradicted by its own output

**File:** `migrations/validate-0009-anchor.sh:231-241`
**Issue:** The comment states the banner is *"deliberately DETERMINISTIC — no repo
SHA, no absolute path. The recorded evidence file … must stay byte-consistent with
a fresh run so a verifier can re-run and diff (T-09-04)."* But `:241` prints
`$(wc -l < "$MIRROR")` — `(79 lines)` — and CASE 2's PASS line prints
`gitnexus:start at line 86`, a number derived from the mirror's length. A mirror
re-vendor (which has happened once already: 75→79) silently invalidates the
recorded evidence in exactly the way the comment says it is designed to prevent.
The rationale is right; the implementation does not honor it.
**Fix:** Either drop the mirror line count from the banner and the derived line
numbers from the PASS text, or narrow the comment's claim to "stable for a given
mirror revision" and say the evidence file must be re-recorded when the mirror is
re-vendored.

## Info

### IN-01: `extract_step_block` prefix-matches `### Step 1` against `### Step 10`

**File:** `migrations/run-tests.sh:110`
**Issue:** `index($0, stepp) == 1` with `stepp="### Step 1"` also matches
`### Step 10`…`### Step 19`, so a document with 10+ steps would set `in_step=1`
inside the wrong step. Harmless today (0009 has 3 steps) and the literal-prefix
choice is well-justified at `:80-91` — but the "matches the same lines upstream's
anchored regexes do" claim does not hold at the 10-step boundary.
**Fix:** Match on the delimiter too, e.g. compare against both `### Step N:` and
`### Step N ` prefixes, which preserves the no-escaping property.

### IN-02: `validate-0009-anchor.sh` CASE 1 never asserts the line drop the ADR cites as its non-vacuity evidence

**File:** `migrations/validate-0009-anchor.sh:249-264`;
`docs/decisions/0010-region-aware-spec-11-placement.md:318-320`
**Issue:** The ADR grounds CASE 1's non-vacuity on a specific number — *"the strip
genuinely removes 81 lines (313 → 232)"* (accurate: `AGENTS.md` is 313 lines). The
script asserts only the round-trip diff and never checks that number, so the
evidence for the claim lives outside the thing that reproduces it. In practice a
no-op strip would still fail the diff (the insert would add a second block), so
CASE 1 is not vacuous — but the recorded justification is unverified by the harness.
**Fix:** Add a cheap assertion between strip and insert:
`[ "$(wc -l < "$tmp/case1.strip")" -lt "$(wc -l < "$tmp/case1-input.md")" ]`.

### IN-03: ADR/migration numbering collision — ADR-0010 documents migration 0009, while ADR-0009 is a different subject

**File:** `docs/decisions/README.md:26-27`
**Issue:** `ADR-0009` = plan-review gate; `migration 0009` = region-aware placement;
`ADR-0010` = the ADR *for* migration 0009. The two series are numbered
independently and are now off by one at adjacent numbers, so `0009` is ambiguous in
prose. `run-tests.sh:1828` greps `docs/decisions/0009-plan-review-gate.md` while
`test_migration_0009` tests the placement migration — correct, and confusing.
**Fix:** No code change. Consider an explicit "ADR-NNNN numbering is independent of
migration-NNNN" line in `docs/decisions/README.md`.

### IN-04: Strip/insert temp files are predictable names in the project CWD and follow symlinks

**File:** `migrations/0009-spec-11-region-aware-placement.md:273, 306`
**Issue:** `> AGENTS.md.0009.strip` / `> AGENTS.md.0009.tmp` are fixed names written
into the project root, and `>` follows an existing symlink. Low real-world risk
(the CWD is the operator's own repo, and cleanup is correct on all four exit paths
— verified). Noted for completeness; consistent with `0006`/`0007`'s `.bak` idiom.
**Fix:** None required. If hardened later, `mktemp` in the project dir would keep
the `mv`-is-same-filesystem property that makes the current approach atomic.

---

_Reviewed: 2026-07-15T17:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
