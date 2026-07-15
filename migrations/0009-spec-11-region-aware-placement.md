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
  && grep -q '^<!-- spec-source: agenticapps-workflow-core@0\.4\.0 §11 -->$' AGENTS.md \
  && ! awk '
       /^<!-- gitnexus:start -->$/ { r = 1; next }
       /^<!-- gitnexus:end -->$/   { r = 0; next }
       r && /^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/ { f = 1 }
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
PROV_RE='^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$'
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"

if [ ! -s AGENTS.md ]; then
  # Informational skip, NOT an abort. An abort would strand the project below
  # to_version forever (see the pre-flight note above). `test -s` (not
  # `test -f`) deliberately covers BOTH a missing AGENTS.md AND a
  # zero-byte one: `test -f` alone PASSES on an empty file (e.g. `touch
  # AGENTS.md`, an interrupted write, or a prior tool crash), which would
  # fall through to the strip below, run it on zero input, and hard-ABORT at
  # the strip-output guard (`:` "the strip pass produced no output") with a
  # misleading "possibly-truncated" diagnostic — nothing was truncated, the
  # input was already empty. A zero-byte file is materially identical to a
  # missing one: "nothing to heal." Routing it through this same skip avoids
  # stranding the project below `to_version` over a file with nothing in it
  # to lose (09.1-REVIEW.md WR-01).
  echo "INFO: migration 0009 Step 1 — no AGENTS.md in project (or it is empty);"
  echo "      §11 heal skipped."
  echo "      Scaffold one via /setup-codex-agenticapps-workflow, then re-run"
  echo "      /update-codex-agenticapps-workflow to pick up §11 on the next pass."
elif grep -q "$(printf '\r')" AGENTS.md; then
  # CR-01, closed per the user's binding fail-closed ruling: normalize
  # nothing, rewrite nothing, refuse. Every `$`-anchored regex this migration
  # depends on (the strip terminator's and the insert anchor's
  # `/^<!-- gitnexus:start -->$/` alternative) does NOT match a
  # `\r`-terminated line in standard POSIX awk — the `\r` sits between the
  # matched text and the record's true end. The unanchored `/^## /`
  # alternative is unaffected by this. On a REGION-LED CRLF file that
  # asymmetry lands the §11 block INSIDE `<!-- gitnexus:start -->` while this
  # migration reports success — reproducing the exact defect it exists to
  # fix, silently, and the block is then destroyed by the next
  # `gitnexus analyze` with no diagnostic from either tool. Refusing here,
  # before any surgery, is strictly safer than guessing at a line-ending
  # normalization this migration was never asked to own.
  #
  # THE REMEDY MUST BE STATED, NOT JUST THE REFUSAL (the user's binding
  # ruling's critical corollary): unlike a missing/empty AGENTS.md (WR-01,
  # which has a true "nothing to heal" skip) or an unmanaged heading (which
  # requires a human decision), CRLF has a real, mechanical escape hatch —
  # convert the line endings and re-run. A bare `exit 3` here with no stated
  # remedy would strand the project exactly as permanently as WR-01's
  # abort did, for a hazard that is trivially fixable. Name the concrete
  # command.
  echo "ABORT: migration 0009 Step 1 — AGENTS.md uses CRLF (\\r\\n) line endings,"
  echo "       which defeat the anchor/terminator matching this migration"
  echo "       depends on. Refusing rather than risk mis-anchoring the §11"
  echo "       block inside a managed region."
  echo ""
  echo "       To proceed: convert AGENTS.md to LF line endings and re-run, e.g."
  echo "         perl -pi -e 's/\r\n\$/\n/' AGENTS.md"
  echo "       Then: re-run /update-codex-agenticapps-workflow"
  exit 3
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
elif grep -qE "$PROV_RE" AGENTS.md \
     && ! grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md; then
  # The literal INVERSE of the guard immediately above. Provenance is present
  # but the exact heading is not — either drifted (CR-01a) or orphaned with no
  # heading at all (CR-01b). Both reproduced runaway-strip shapes collapse to
  # this ONE predicate: "provenance present, exact H2 absent". Q1's ruling
  # (see this document's <interfaces>, or 09.1-05's plan): REFUSE, not
  # heal-and-duplicate. This check runs BEFORE any file surgery, so the file
  # is byte-identical by construction — a strip that refuses to run cannot
  # run away. This gate is file-global: it cannot see a shape where a HEALTHY
  # provenance+heading pair exists elsewhere in the same file alongside a
  # drifted one (both satisfy "some provenance is present" / "some heading is
  # present" in aggregate). That shape is caught downstream by the strip
  # awk's own END guard instead.
  echo "ABORT: AGENTS.md contains a spec-11 provenance line whose"
  echo "       '## Coding Discipline (NON-NEGOTIABLE)' heading is drifted or"
  echo "       absent. The offending line(s):"
  grep -nE "$PROV_RE" AGENTS.md
  echo ""
  echo "       (a) restore the '## Coding Discipline (NON-NEGOTIABLE)' heading"
  echo "           immediately below the provenance line, or"
  echo "       (b) remove the provenance line."
  echo "       Refusing to strip. AGENTS.md left untouched."
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
  # D-26's PRINCIPLE survives: the strip stays deliberately BLIND to the
  # block's PROSE — content fidelity is 0004's job, not this migration's, and
  # moving a drifted block also silently re-vendors it from the mirror,
  # repairing the drift. D-26's CLAIM does not survive: the strip is bounded
  # ONLY when the exact heading is where it is expected — the heading is a
  # STRUCTURAL boundary marker, not content (the canonical mirror has exactly
  # one `## ` line, and it is the heading — asserted by
  # `test_migration_0004`'s single-`## ` invariant guard). So: prose drift ->
  # stay blind and repair; HEADING drift -> the boundary itself is gone, and
  # this migration must refuse rather than run away. The two `elif` refuse
  # branches above cover the file-global case; the `unresolved` flag and the
  # `END` guard immediately below cover the shape they cannot see.
  #
  # The strip's output is required non-empty before anything consumes it.
  # AGENTS.md must never be replaced by a result derived from a truncated or
  # failed strip (awk error, disk full) — on failure this aborts, leaves
  # AGENTS.md untouched, and cleans up the partial temp file.
  awk '
    BEGIN { in_block = 0; swallowed_own_h2 = 0; unresolved = 0; fenced = 0 }
    /^<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->$/ {
      # A second provenance line arriving while a previous one never found
      # its heading (in_block still latched, swallowed_own_h2 never set) is
      # itself an unresolved shape — record it before re-entering, and reset
      # swallowed_own_h2 so this new entry is judged on its own.
      if (in_block && !swallowed_own_h2) { unresolved = 1 }
      in_block = 1
      swallowed_own_h2 = 0
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
    # CR-02: an exact, whole-line quotation of the provenance marker and/or
    # the §11 heading inside a markdown code fence (a troubleshooting note
    # showing "what a healthy block looks like") is a REAL anchored match on
    # both regexes above — not a "mention" (07/11 already close that door via
    # anchoring) — so it latches `in_block` exactly like a genuine block and
    # this pass is about to silently swallow whatever sits between it and the
    # next real terminator. A bare \`\`\`/~~~ fence-delimiter line appearing
    # THAT WOULD BE SWALLOWED is the tripwire: the real vendored mirror
    # carries zero such lines in its own body (confirmed structurally, not
    # assumed), so seeing one here means this pass is about to eat content it
    # has no way to know is safe. Per the binding user ruling, this does
    # NOT attempt to parse fence state and skip past it to keep healing
    # (upstream calls full fence-awareness not-fixable-by-design) — it only
    # detects the ambiguity and refuses. `next` is deliberately omitted here
    # so the line still falls through to `in_block { next }` below and is
    # discarded from the (about to be refused) output exactly as before.
    in_block && /^(```|~~~)/ { fenced = 1 }
    in_block { next }
    !in_block { print }
    END {
      # Fail closed: a provenance entry that never finds its heading leaves
      # in_block latched true to EOF (or an earlier one was overwritten by a
      # second entry above, recorded as `unresolved`). Either shape means
      # "in_block { next }" was about to eat content it had no structural
      # right to eat. Exit 4 — NOT exit 1 — so the caller can distinguish
      # this refusal from a genuine awk error. A LEGITIMATE block that runs
      # to EOF (no trailing `## ` or region marker, e.g. fixture
      # 06-no-heading-eof) has swallowed_own_h2 == 1 at EOF and is
      # unaffected by this guard.
      if (unresolved || (in_block && !swallowed_own_h2)) exit 4
      # CR-02 exit code, checked SECOND, deliberately: `fenced` can only ever
      # be set while `in_block` is still open at the time the fence line was
      # seen, and if that same span ALSO never resolved its heading, that
      # takes exit 4 shape first (a different, more specific diagnostic
      # exists for that). Exit 5 is reserved for the shape where the block
      # bounded cleanly (a real terminator was found) but a fence line was
      # seen in what got swallowed along the way — precisely the
      # fenced-quotation hazard, not the drifted/orphaned-heading hazard
      # exit 4 already names.
      if (fenced) exit 5
    }
  ' AGENTS.md > AGENTS.md.0009.strip
  strip_rc=$?
  if [ "$strip_rc" -eq 5 ]; then
    # CR-02: the file-global refuse gates above cannot see this shape either
    # — a fenced quotation of BOTH the exact heading and the exact provenance
    # satisfies "heading present" AND "provenance present" simultaneously, so
    # neither `elif`'s conjunction fires. The strip's sequential scan is what
    # actually catches it, via the fence tripwire above.
    rm -f AGENTS.md.0009.strip
    echo "ABORT: migration 0009 Step 1 — a spec-11 provenance line and/or its"
    echo "       '## Coding Discipline (NON-NEGOTIABLE)' heading was found next"
    echo "       to a markdown code-fence delimiter (\`\`\` or ~~~) inside the"
    echo "       span this migration would otherwise strip and re-vendor. This"
    echo "       migration cannot reliably tell a REAL managed block apart from"
    echo "       an EXACT quotation of one inside a fenced troubleshooting note"
    echo "       or code example — refusing rather than risk silently deleting"
    echo "       real content between the quotation and the next heading."
    echo ""
    echo "       (a) move the quoted marker/heading text out of AGENTS.md (e.g."
    echo "           into a separate docs file), or"
    echo "       (b) break the exact match by editing the quoted text so it no"
    echo "           longer reproduces the marker/heading verbatim (e.g. add a"
    echo "           word or escape a character inside the fence)."
    echo "       Then re-run /update-codex-agenticapps-workflow."
    echo "       Refusing to strip. AGENTS.md left untouched."
    exit 3
  elif [ "$strip_rc" -eq 4 ]; then
    # The refuse-gate `elif`s above are file-global and cannot see a MIXED
    # shape: a healthy provenance+heading pair elsewhere in the file makes
    # both "provenance present" and "heading present" true in aggregate, so
    # neither gate fires. The strip awk sees the file sequentially instead,
    # so it is what actually catches this shape.
    rm -f AGENTS.md.0009.strip
    echo "ABORT: migration 0009 Step 1 — a spec-11 provenance line was never"
    echo "       followed by its '## Coding Discipline (NON-NEGOTIABLE)'"
    echo "       heading before the strip pass reached EOF or a second"
    echo "       provenance line. The offending line(s):"
    grep -nE "$PROV_RE" AGENTS.md
    echo ""
    echo "       (a) restore the '## Coding Discipline (NON-NEGOTIABLE)' heading"
    echo "           immediately below the provenance line, or"
    echo "       (b) remove the provenance line."
    echo "       Refusing to strip. AGENTS.md left untouched."
    exit 3
  elif [ "$strip_rc" -ne 0 ] || [ ! -s AGENTS.md.0009.strip ]; then
    rm -f AGENTS.md.0009.strip
    echo "ABORT: migration 0009 Step 1 — the strip pass produced no output;"
    echo "       refusing to replace AGENTS.md with a possibly-truncated result."
    exit 3
  else
    # Strip-integrity guard (criterion 4). The strip may remove ONLY the
    # '## ' heading(s) it owns; every OTHER '## ' heading in the input must
    # survive into the strip output. This is a backstop for the refuse gate
    # and the END guard above, not a replacement for either — by itself it
    # is defeated by the orphan-PROV-at-EOF shape (no '## ' headings are
    # lost when there is no trailing heading to lose in the first place).
    # Source: 09-REVIEW.md CR-01 fix (b), repositioned between the passes,
    # before the insert regenerates the evidence this guard checks.
    h2_in=$(grep -c '^## ' AGENTS.md | tr -d ' ')
    h2_own=$(grep -c '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md | tr -d ' ')
    h2_out=$(grep -c '^## ' AGENTS.md.0009.strip | tr -d ' ')
    if [ "$h2_out" -ne "$(( h2_in - h2_own ))" ]; then
      rm -f AGENTS.md.0009.strip
      echo "ABORT: migration 0009 Step 1 — the strip removed structural headings"
      echo "       it does not own (expected $(( h2_in - h2_own )) '## ' headings"
      echo "       to survive, found $h2_out). AGENTS.md left untouched."
      exit 3
    fi

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
    # to actually contain the block's own heading catches it. This guards
    # MIRROR integrity, not strip integrity — it cannot guard strip integrity,
    # because it looks for the very heading the insert pass itself just wrote;
    # strip integrity is guarded upstream by `strip_rc` instead. Pre-flight's
    # `test -s` guards the common mirror-missing case; this is the last line
    # of defense against a present-but-empty-or-corrupt mirror.
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
- **No `AGENTS.md`, or `AGENTS.md` is zero bytes** — Step 1 emits an
  informational message; Step 2 still runs. Both shapes are "nothing to
  heal" and route through the same `test -s` skip (WR-01).
- **Unmanaged `## Coding Discipline (NON-NEGOTIABLE)` heading** — Step 1 aborts
  with `exit 3` and leaves the file untouched; resolve per its message.

## Known limitations

This migration **refuses** (does not silently mis-heal) on two input shapes
that upstream `claude-workflow`'s own `0029-region-aware-spec-11-placement.md`
still accepts by design — its "Known limitations" section
(`f9354cc:0029:411-420`) names both as open, unaddressed hazards in the same
strip mechanism this migration ports. `09.1-REVIEW.md` (CR-01, CR-02)
reproduced both live against this repo's own, already-CR-02-anchored 0009 and
they are **closed here**, not inherited as open — this repo's 0009 now
diverges from upstream's 0029, which still silently accepts both shapes.

- **CRLF line endings** (`AGENTS.md` uses `\r\n`). Every `$`-anchored regex
  the strip/insert awk depends on does not match a `\r`-terminated line,
  while the unanchored `/^## /` alternative still does — on a region-led
  file that asymmetry would land the §11 block *inside* the GitNexus-managed
  region while Step 1 reports success. Step 1 detects any `\r` byte in
  `AGENTS.md` and aborts with `exit 3` **before any surgery**, leaving
  `AGENTS.md` byte-identical, and prints the concrete recovery command:
  convert the file to LF and re-run, e.g.
  `perl -pi -e 's/\r\n$/\n/' AGENTS.md`, then re-run
  `/update-codex-agenticapps-workflow`.
- **An exact, whole-line quotation of the provenance marker and/or the §11
  heading inside a markdown code fence** (e.g. a troubleshooting note
  showing "what a healthy block looks like"). The quotation is a real,
  anchored match — indistinguishable from a genuine block by the strip's own
  state machine — and would make the strip silently swallow real, unrelated
  content up to the next heading. Step 1 detects a fence-delimiter line
  (`` ``` `` or `~~~`) inside the span it is about to discard and aborts
  with `exit 3` **before any surgery**, leaving `AGENTS.md` byte-identical,
  and names both recovery options: move the quoted text out of `AGENTS.md`
  (e.g. into a separate docs file), or edit it so it no longer reproduces
  the marker/heading verbatim.

Neither refusal normalizes, rewrites, or auto-corrects `AGENTS.md` — both are
fail-closed by the user's binding ruling on this hazard class: when Step 1
cannot safely determine the file's real structure, it refuses rather than
guesses, and always states the concrete remedy rather than leaving the
project stranded with no path forward.

## Notes

- **`PROV_RE` anchoring, ported from upstream `f9354cc` (not re-derived).** All
  four sites where this migration matches the provenance marker as a regex
  (the idempotency check's provenance grep and its in-region awk trigger, the
  `PROV_RE` definition, and the strip pass's entry regex) are whole-line
  anchored (`^...$`). This closes CR-02: an unanchored substring match also
  fires on prose that merely *mentions* the marker — including a guard
  comment inside `AGENTS.md` itself quoting the marker — which would
  misjudge a healthy file as region-led or, worse, latch the strip's
  `in_block` state onto a prose line and eat everything up to the next
  terminator. Anchored per upstream `claude-workflow @ f9354cc`
  (`migrations/0029-region-aware-spec-11-placement.md:142,146,175,223`, PR
  #89), which fixed the identical defect there before this migration was
  written. Ported rather than re-derived: the fix is already validated across
  six repos, and re-deriving it here would risk prose divergence from the
  repo this migration is a port of. The `@[^[:space:]]+` any-version class is
  preserved at every site except the idempotency check's provenance grep
  (`:164`), which stays pinned to the current version `0.4.0` by design — that
  predicate is *idempotency* ("is the current version already applied"), a
  different question from the strip's *entry* condition ("is there a
  provenance line of any version to heal"), and narrowing it would leave a
  stale-version provenance line unstrippable.

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
