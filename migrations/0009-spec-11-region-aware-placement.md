---
id: 0009
slug: spec-11-region-aware-placement
title: Anchor the §11 block above any GitNexus-managed region (v0.6.0 -> 0.7.0)
from_version: 0.6.0
to_version: 0.7.0
applies_to:
  - AGENTS.md                              # §11 block placement healed (Step 1)
  - .codex/workflow-version.txt            # project version recorded (Step 2)
requires: []
optional_for: []
---

# Migration 0009 — Region-aware §11 placement (v0.6.0 -> 0.7.0)

Migration `0001` injects the canonical §11 block immediately before the first
`## ` heading in `AGENTS.md` (`0001:91`), and `0004` re-injects it the same way
(`0004:77`). That is only a safe boundary when the first `## ` heading belongs
to *project* content. In an `AGENTS.md` that leads with the GitNexus block, the
first `## ` is `## Always Do` — which sits **inside**
`<!-- gitnexus:start -->…<!-- gitnexus:end -->`. The block lands in the region,
and the next `gitnexus analyze` regenerates that region and destroys the block
with no diagnostic.

Nothing recovers from that. The update engine marks a migration pending iff
`installed >= from_version && installed < to_version`; `0001`'s `to_version` is
`0.2.0`, so for any 0.6.x project it is permanently not-pending. `0001` and
`0004` are immutable and already applied, so this migration fixes **forward**
rather than editing them.

**On this host the defect is LATENT, not active.** This repo's own `AGENTS.md`
carries §11 at the top and its GitNexus region at L271 — the region does not
lead the file, so the naive anchor happens to land correctly here. There is no
broken repo in this project to repair. This migration exists because every
project this host scaffolds inherits the naive anchor, and any one of them whose
`AGENTS.md` is region-led is one `gitnexus analyze` away from silently losing
§11.

**The anchor rule.** Insert immediately before the first line that is **either**
a `## ` heading **or** a line that is *exactly* `<!-- gitnexus:start -->` —
whichever comes first; EOF if neither. Both marker regexes MUST be anchored
(`/^<!-- gitnexus:start -->$/`, `/^<!-- gitnexus:end -->$/`). An unanchored
substring match also fires on prose that merely *mentions* the marker — which is
exactly what a scaffolded project's own `AGENTS.md` guidance comment does — and
would misjudge a perfectly healthy file as region-led.

The rule anchors on the region **only when the region comes first**. Anchoring
before `gitnexus:start` whenever a region exists anywhere would be wrong: in a
project whose region starts late, the block would land hundreds of lines down,
violating §12's placement advisory. This rule was validated empirically against
this host's real `AGENTS.md` and a synthesized region-led file *before* this
document was written — it re-derives the block's current position byte-identically
on the healthy file (zero churn) and anchors above the region on a region-led one.

**The structural invariant is WIDENED, not preserved.** `0001`/`0004` could
assume the managed block is always followed by a `## ` line or EOF, because their
anchor could only ever *be* a `## ` heading. Once the anchor can also be a
`<!-- gitnexus:start -->` marker, a healed region-led file has the block followed
by that marker, not by a `## ` line. The invariant that actually holds after this
migration is: **the block is always followed by a `## ` line, an anchored
`<!-- gitnexus:start -->` marker, or EOF.** This is not a delta that leaves the
old invariant intact — it replaces it. Every terminator that bounds the managed
section carries the same alternation as the anchor, because the anchor rule and
the terminator rule are **one decision, not two**, and must move together. A
terminator that recognizes only `## ` runs straight past the marker on an
already-healed file and consumes the entire region — see Step 1.

## Why a 0.x minor bump

`0.6.0 -> 0.7.0`. This changes where a managed section is placed in a file the
project owns, and rewrites `AGENTS.md` in place. That is behavioural, not a
patch to vendored bytes (which is what `0004`'s `0.2.0 -> 0.2.1` was), so it
takes a minor bump. `implements_spec` stays **0.4.0** — core's spec version is
unchanged; this migration corrects a *host placement defect*, not a spec version.

## Supported upgrade floor

This migration upgrades **0.6.0 -> 0.7.0 in a single hop**. It does not accept a
lower floor. Every live project already sits at 0.6.0 after `0008`, so a wider
floor would buy nothing real while papering over a known multi-hop
chain-selection defect in the update skill. That defect is deferred and tracked
separately; it does not block this migration.

## Pre-flight

```bash
# 1. Step 1 rewrites AGENTS.md in place and its rollback is `git checkout
#    AGENTS.md`, which requires a git repo to restore from.
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# 2. The project must be at 0.6.0 — or already at 0.7.0, for a re-apply or a
#    partial state. Accepting BOTH is deliberate: an idempotent re-run on an
#    already-migrated project must not abort. The floor is read from the
#    project's OWN durable version record, `.codex/workflow-version.txt` —
#    what the update skill itself reads (its Stage A step 1) — per 0008's
#    precedent (`0008:73-79`), not from a project-relative `skills/` path
#    (see the porting-error note under `## Notes`).
grep -qE '^0\.(6|7)\.0$' .codex/workflow-version.txt || {
  INSTALLED=$(cat .codex/workflow-version.txt 2>/dev/null)
  echo "ABORT: workflow project version is ${INSTALLED:-unknown} (need 0.6.0)."
  echo "       Apply prior migrations first via \$update-codex-agenticapps-workflow."
  echo "       Supported upgrade floor: 0.6.0 -> 0.7.0."
  exit 3
}

# 3. The vendored §11 mirror must be present AND non-empty. `test -f` alone is
#    insufficient: it passes on a zero-byte file, which is exactly what an
#    interrupted `git pull` in the scaffolder clone produces. Because Step 1
#    re-vendors §11 from this mirror as its SOLE source, a zero-byte mirror
#    would strip the project's existing §11 block and inject nothing in its
#    place — silently committing a maimed AGENTS.md. `test -s` catches that
#    before any file surgery runs.
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
test -s "$MIRROR" || {
  echo "ABORT: vendored §11 canonical block missing or empty at:"
  echo "       $MIRROR"
  echo "       Re-install: re-run codex-workflow's install.sh"
  exit 3
}

# 4. Non-empty is not the same as un-truncated. The block's own heading sits on
#    LINE 1 of the mirror, so a mirror truncated at the tail still satisfies
#    `test -s` above AND still satisfies Step 1's pre-`mv` shape assertion
#    (which greps for that same line-1 heading) — both are single-point guards
#    on a continuum, not guards against truncation. So assert the block's LAST
#    section is present too: a real truncation or a corrupt mirror loses the
#    tail long before it loses the head.
#
#    This is NOT the rejected content-sentinel pattern. That anti-pattern
#    coupled a STRIP TERMINATOR to §11's last PROSE line, so prose drift made
#    the strip run away and eat the rest of the file. This is a read-only
#    integrity check on a DIFFERENT file, anchored to a structural `### `
#    heading; it bounds nothing and cannot run away. It is not a byte-identity
#    or checksum check either — vendored-file integrity is git's job and
#    `0004`'s — it is the cheapest guard that closes the gap between "has a
#    heading" and "is the whole block".
grep -q '^### 4\. Goal-Driven Execution$' "$MIRROR" || {
  echo "ABORT: vendored §11 canonical block at:"
  echo "       $MIRROR"
  echo "       is missing its final section — it looks truncated or corrupt."
  echo "       Re-install: re-run codex-workflow's install.sh"
  exit 3
}
```

Pre-flight is deliberately **permissive on the missing-`AGENTS.md` path**: Step 1
emits an informational message and Step 2 still runs. This diverges **on
purpose** from `0004:44`, which hard-aborts when the project has no `AGENTS.md`,
and the divergence is load-bearing. The update engine marks a migration pending iff
`installed >= from_version && installed < to_version`. An abort here would mean
Step 2 never records `0.7.0`, so 0009 stays pending forever *and* every future
migration `0010+` never becomes pending either — the project is stranded at
0.6.0 permanently, unrecoverable without manual intervention. A skip costs
nothing. An abort is unrecoverable.

## Steps

### Step 1: Heal the §11 block's placement

**Idempotency check:**

```bash
[ -f AGENTS.md ] \
  && grep -q '<!-- spec-source: agenticapps-workflow-core@0\.4\.0 §11 -->' AGENTS.md \
  && ! awk '
       /^<!-- gitnexus:start -->$/ { r = 1; next }
       /^<!-- gitnexus:end -->$/   { r = 0; next }
       r && /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ { f = 1 }
       END { exit(f ? 0 : 1) }
     ' AGENTS.md
```

Returns 0 (**already applied — nothing to do**) only when the current-version
provenance is present **and** the block is not inside a managed region. That
conjunction is the whole point: a block sitting inside a region carries perfectly
correct provenance but is **not safe**, so provenance alone must never
short-circuit the heal.

Returns non-zero when `AGENTS.md` is absent (routes to the informational-skip
branch), when the block is missing entirely, and when the block is inside a
region.

Both marker regexes are anchored (`^...$`). A bare substring match also fires on
prose that merely *mentions* the marker — a scaffolded project's own `AGENTS.md`
guidance comment does exactly that — which would misjudge a healthy file as
"inside a region" and propose to move §11 above a region that does not exist.

The scan is single-pass and **fails closed** without any line-number arithmetic:
if `<!-- gitnexus:end -->` never appears, `r` stays 1 to EOF, so provenance
sitting after an unterminated `<!-- gitnexus:start -->` is correctly judged
in-region and the block gets moved above the marker to safety. That is the same
outcome as the well-formed case, reached with no extra branch.

A **healthy-but-off-anchor** block — correct provenance, not in a region, but not
at the anchor this migration would pick — has provenance and is not in a region,
so this predicate returns 0 and it is **left exactly where it is**. That falls
out of the predicate rather than a special case; there is deliberately no code
that detects "off-anchor but healthy", and this migration does not move it.

**Pre-condition:** pre-flight passed — the vendored mirror exists, is non-empty,
and is not truncated (its final section is present).

**Apply:**

```bash
PROV='<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->'
PROV_RE='<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->'
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"

if [ ! -f AGENTS.md ]; then
  # Informational skip, NOT an abort. An abort would strand the project below
  # to_version forever (see the pre-flight note above).
  echo "INFO: migration 0009 Step 1 — no AGENTS.md in project; §11 heal skipped."
  echo "      Scaffold one via /setup-codex-agenticapps-workflow, then re-run"
  echo "      /update-codex-agenticapps-workflow to pick up §11 on the next pass."
elif grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md \
     && ! grep -qE "$PROV_RE" AGENTS.md; then
  # A §11 heading with no provenance was hand-pasted outside this migration's
  # management. Refuse, and leave the file byte-identical — this check runs
  # before any surgery. Inherits 0001's never-overwrite-a-hand-paste rule.
  echo "ABORT: AGENTS.md contains a '## Coding Discipline (NON-NEGOTIABLE)'"
  echo "       heading but no provenance comment — it was hand-pasted outside"
  echo "       this migration's management. Refusing to overwrite."
  echo ""
  echo "       (a) Remove that section and re-run /update-codex-agenticapps-workflow, or"
  echo "       (b) add the line"
  echo ""
  echo "             $PROV"
  echo ""
  echo "           immediately above the heading to adopt it as managed."
  exit 3
else
  # Two passes: strip the managed block wherever it currently sits, then
  # re-insert it at the region-aware anchor. The strip is a no-op when the block
  # is absent, so "inject" (no block yet) and "move" (block in the wrong place)
  # are ONE code path — the insert always re-vendors from the mirror.
  #
  # The strip terminator recognizes the SAME anchor as the insert pass below
  # (`## ` OR an anchored `<!-- gitnexus:start -->`) — see "The anchor rule"
  # above for why the two must move together. The block contains exactly one
  # `## ` line (its own heading), so that is swallowed explicitly first;
  # naively stopping at the first `## ` would terminate on the block's own
  # heading and leave the body behind. `swallowed_own_h2` is RESET at the
  # terminator so a SECOND provenance line re-enters cleanly instead of
  # inheriting a stale swallow state and leaking its own heading.
  #
  # The strip is deliberately BLIND to the block's content: it is bounded
  # structurally, so a drifted block cannot cause a runaway, and no verbatim
  # assertion gates it. This migration must not refuse to PLACE a block just
  # because its prose drifted — content fidelity is 0004's job. A consequence,
  # stated rather than accidental: moving a drifted block also silently
  # re-vendors it from the mirror, repairing the drift.
  #
  # The strip's output is required non-empty before anything consumes it.
  # AGENTS.md must never be replaced by a result derived from a truncated or
  # failed strip (awk error, disk full) — on failure this aborts, leaves
  # AGENTS.md untouched, and cleans up the partial temp file.
  if awk '
    BEGIN { in_block = 0; swallowed_own_h2 = 0 }
    /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ {
      in_block = 1
      next
    }
    in_block && !swallowed_own_h2 && /^## Coding Discipline \(NON-NEGOTIABLE\)$/ {
      swallowed_own_h2 = 1
      next
    }
    in_block && swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/) {
      in_block = 0
      swallowed_own_h2 = 0
      print
      next
    }
    in_block { next }
    !in_block { print }
  ' AGENTS.md > AGENTS.md.0009.strip && [ -s AGENTS.md.0009.strip ]; then
    # Re-insert at the region-aware anchor. The alternation IS the fix: 0001 and
    # 0004 had only /^## /, which selects a heading INSIDE the region on a
    # region-led file. "Whichever comes first" is what keeps the block near the
    # top when the region starts late. The marker regex is anchored (`^...$`) so
    # a prose mention of it can never be mistaken for a real region.
    #
    # Non-empty is not the same as correct: a zero-byte mirror makes the
    # `while ((getline ...))` loop read nothing, yet awk still exits 0 with
    # non-empty output (the rest of the file, plus an orphaned provenance line).
    # `[ -s ]` alone would pass and commit that data loss. Requiring the result
    # to actually contain the block's own heading catches it. Pre-flight's
    # `test -s` guards the common case; this is the last line of defense.
    if awk -v prov="$PROV" -v block_file="$MIRROR" '
      BEGIN { inserted = 0 }
      !inserted && (/^## / || /^<!-- gitnexus:start -->$/) {
        print prov
        while ((getline line < block_file) > 0) print line
        close(block_file)
        print ""
        inserted = 1
        print
        next
      }
      { print }
      END {
        if (!inserted) {
          print ""
          print prov
          while ((getline line < block_file) > 0) print line
          close(block_file)
        }
      }
    ' AGENTS.md.0009.strip > AGENTS.md.0009.tmp && [ -s AGENTS.md.0009.tmp ] \
      && grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md.0009.tmp; then
      if mv AGENTS.md.0009.tmp AGENTS.md; then
        rm -f AGENTS.md.0009.strip AGENTS.md.0009.tmp
        echo "INFO: migration 0009 Step 1 — §11 block anchored above any managed region."
      else
        rm -f AGENTS.md.0009.strip AGENTS.md.0009.tmp
        echo "ABORT: migration 0009 Step 1 — mv failed; refusing to report"
        echo "       success. AGENTS.md left as-is (mv is atomic on failure);"
        echo "       check disk space / permissions."
        exit 3
      fi
    else
      rm -f AGENTS.md.0009.strip AGENTS.md.0009.tmp
      echo "ABORT: migration 0009 Step 1 — the insert pass produced no output,"
      echo "       or its result is missing the §11 heading. The vendored"
      echo "       spec-mirror block is likely empty or corrupt:"
      echo "       $MIRROR"
      echo "       Refusing to replace AGENTS.md. Left untouched."
      exit 3
    fi
  else
    rm -f AGENTS.md.0009.strip
    echo "ABORT: migration 0009 Step 1 — the strip pass produced no output;"
    echo "       refusing to replace AGENTS.md with a possibly-truncated result."
    exit 3
  fi
fi
```

**The terminator alternation is the highest-severity mechanic in this
migration.** A `/^## /`-only strip terminator skips straight past
`<!-- gitnexus:start -->` on a file this migration has already healed, and
consumes the ENTIRE GitNexus region plus everything up to the next `## ` or EOF —
on an ordinary idempotent re-run. It leaves an orphaned, unpaired
`<!-- gitnexus:end -->` and destroys the region's content. This is exactly the
runaway-strip hazard that the structural boundary was chosen to avoid,
resurfacing *inside* that boundary. The structural boundary is only safe once its
terminator set equals the anchor's terminator set. This was demonstrated
empirically against real files before this document was written; it is not a
theoretical concern.

The payload is always **streamed from the mirror** (`getline line < block_file`),
never `cat`'d inline and never transcribed into this document. The mirror is the
single source of §11's prose.

Rollback deliberately does **not** get a bespoke removal pass. Such a pass would
need to carry the same terminator alternation as Apply, and it is precisely the
construct upstream's own fixture had to be added to catch a file-destroying bug
in — running a narrow-terminator removal over a healed region-led file eats the
start marker and the region's real content. `git checkout` is *structurally
immune*: there is no terminator to get wrong. Migration rollbacks in this repo
already run inside a `test -d .git`-guarded context (pre-flight guard 1), and
this is `0004:87`'s precedent.

**Rollback:** `git checkout AGENTS.md`.

### Step 2: Record the new project version

**Idempotency check:** `grep -q '^0.7.0$' .codex/workflow-version.txt 2>/dev/null`
**Pre-condition:** `.codex/` exists
**Apply:** `echo "0.7.0" > .codex/workflow-version.txt`
**Rollback:** `echo "0.6.0" > .codex/workflow-version.txt`

**Step 2 runs unconditionally — including when Step 1 took its
informational-skip path because the project has no `AGENTS.md`.** Do not
"helpfully" gate the version bump on Step 1 having actually moved a block. The
update engine marks a migration pending iff
`installed >= from_version && installed < to_version`, so a project whose Step 1
legitimately had nothing to do would never record `0.7.0`, would keep 0009
pending forever, and would never see `0010+` become pending either — stranded
below `to_version` permanently. Step 1's job is the heal; Step 2's job is
the version, and they are independent by design.

**There is no step in this migration that bumps this repo's own scaffolder
trigger skill's SKILL.md, and none should be added.** No target project has a
local `skills/` tree to bump — see the MIGR-08/MIGR-09 separation note under
`## Notes`.

## Verification

After applying, a human can check:

- `.codex/workflow-version.txt` reads `0.7.0`.
- If `AGENTS.md` exists: the `<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->`
  provenance line sits **above** any leading `<!-- gitnexus:start -->` marker, and
  the region's markers are still paired exactly once each.
- No `AGENTS.md.0009.strip` / `AGENTS.md.0009.tmp` temp files were left behind.

## Skip cases

- **Already healed** (Step 1 idempotency returns 0) — Step 1 no-ops; Step 2
  still records the version.
- **Healthy but off-anchor** — provenance present, not in a region: left exactly
  where it is, by the same predicate. Not a special case.
- **No `AGENTS.md`** — Step 1 emits an informational message; Step 2 still runs.
- **Unmanaged `## Coding Discipline (NON-NEGOTIABLE)` heading** — Step 1 aborts
  with `exit 3` and leaves the file untouched; resolve per its message.

## Notes

- **The pre-flight version-floor porting error (fixed here, not inherited).**
  0009 v1's pre-flight guard 2 greped the project-relative path
  `skills/agentic-apps-workflow/SKILL.md` for its version floor — a path **no
  target project has** — so it aborted with `exit 3` on every real install and
  the entire §11 heal (Step 1) never ran. **This was a codex-side porting
  error, not an inherited upstream defect.** Upstream greps
  `.claude/skills/agentic-apps-workflow/SKILL.md`, a path its own setup skill
  creates (`f9354cc:setup/SKILL.md:146`); this host's port dropped the
  `.claude/` prefix. On this host, skills install **globally** at
  `${CODEX_HOME}/skills/…`, not under a project-relative `skills/` tree, and
  the project's version lives in `.codex/workflow-version.txt`. Fixed here per
  0008's precedent (`0008:73-79`), which named this exact class of defect in
  migration 0007 (T-08-38, `0008:470-487`) and called it "a defect this
  migration does not replicate" — 0009 now keeps that same discipline.
- **MIGR-08 / MIGR-09 separation.** This migration (MIGR-08) records the new
  version **in the target project** — Step 2, `.codex/workflow-version.txt`.
  **This repo's own** scaffolder trigger skill's SKILL.md version bump
  (MIGR-09) is a **direct edit in the phase's own commit**, never a migration
  step shipped to other people's repos — per the rule `0008:337-350` states
  verbatim: "There is no step that bumps a target project's local scaffolder
  trigger skill's SKILL.md, and none should be added." MIGR-09 is satisfied by
  plan 09.1-03's direct edit to this repo's own `skills/` tree, not by
  anything in this document.
