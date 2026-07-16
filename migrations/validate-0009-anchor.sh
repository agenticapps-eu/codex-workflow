#!/usr/bin/env bash
# Empirical replay of migration 0009's candidate anchor rule (D-21) and widened
# strip terminator (D-24) — run and recorded BEFORE 0009's apply-block is
# authored (ROADMAP hard ordering 1, Success Criterion 1).
#
# This is a VALIDATION HARNESS, not a migration. It MUST NOT modify any tracked
# file. Every working file lives under a `mktemp -d` scratch dir; the repo's real
# AGENTS.md is only ever read (copied out), never written.
#
# The awk carried below is ported from the PINNED upstream reference (D-48):
#   claude-workflow @ 8520f90d235e0c50b0484b170d595ab6f2cd1173
#   migrations/0029-region-aware-spec-11-placement.md
#     lines 192-210 — strip pass    -> candidate_strip()
#     lines 226-246 — insert pass   -> candidate_insert()
# with `CLAUDE.md` retargeted to an input path passed as $1. Upstream HEAD has
# moved past the pin; changes after it are a deliberate follow-up diff, never
# absorbed here.
#
# The naive anchor replayed as a counter-case is this repo's own incumbent:
#   migrations/0001-inject-spec-11-coding-discipline.md:91 — `/^## / && !done`
#
# Usage: bash migrations/validate-0009-anchor.sh   (exit 0 = every case passed)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ]; then
  echo "error: validate-0009-anchor.sh must be invoked from inside a git repo" >&2
  exit 1
fi
cd "$REPO_ROOT" || exit 1

# The mirror is the source of §11's prose. It is STREAMED into the insert via
# `getline line < block_file` — never transcribed into this script. `test -s`
# (not `test -f`): an interrupted `git pull` leaves a zero-byte mirror that
# `test -f` still passes, and a zero-byte mirror makes every replay vacuous.
MIRROR="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
if [ ! -s "$MIRROR" ]; then
  echo "ABORT: spec §11 mirror missing or empty at:" >&2
  echo "       $MIRROR" >&2
  exit 1
fi

# D-29: @0.4.0 is the BLOCK'S CONTENT version and stays hardcoded. It is not the
# workflow version and must not be bumped to 0.7.0 with the milestone.
PROV='<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

FAILURES=0
pass() { printf '  PASS %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

# ─────────────────────────────────────────────────────────────────────────────
# The rules under test
# ─────────────────────────────────────────────────────────────────────────────

# CANDIDATE STRIP (D-24). Removes the managed §11 block wherever it currently
# sits. The `swallowed_own_h2` flag exists because the block's own
# `## Coding Discipline (NON-NEGOTIABLE)` heading matches the terminator regex:
# without swallowing it explicitly, the strip terminates on the block's own
# heading and leaves the body behind. The terminator is the ALTERNATION
# (/^## / || /^<!-- gitnexus:start -->$/) — this is D-24, and counter-case B
# below proves it is load-bearing rather than cosmetic.
candidate_strip() {
  awk '
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
  ' "$1"
}

# CANDIDATE INSERT (D-21). Anchors at the first `## ` heading OR an anchored
# `<!-- gitnexus:start -->` marker, WHICHEVER COMES FIRST, with an EOF fallback
# in END. The marker regex is anchored (`^...$`) so a prose mention of the
# marker in backticks can never be mistaken for a real region.
# Shape reproduced exactly from 0001:84-108 — provenance line, mirror content
# streamed via getline, ONE trailing blank line — or case 1's zero-churn replay
# would fail for a spurious formatting reason rather than an anchor reason.
candidate_insert() {
  awk -v prov="$PROV" -v block_file="$MIRROR" '
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
  ' "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# The WRONG rules — replayed as counter-cases (D-36 / Dimension 8)
#
# A counter-replay asserts that a WRONG rule FAILS. If a wrong rule passes, the
# corresponding positive assertion above is dead-by-construction: it would pass
# for any rule, discriminate nothing, and read as coverage while covering
# nothing. That is the exact Phase 8 defect class (08-05 shipped two awk
# patterns that could never match and silently passed). When a counter-case's
# wrong rule behaves CORRECTLY, this script fails loudly and exits non-zero.
# ─────────────────────────────────────────────────────────────────────────────

# NAIVE INSERT — the incumbent, verbatim from this repo's shipped
# migrations/0001-inject-spec-11-coding-discipline.md:91: `/^## / && !done`,
# with NO marker alternation. On a gitnexus-led file the first `## ` sits INSIDE
# the region, so this rule injects §11 into managed territory and the next
# `gitnexus analyze` silently destroys the block. That is the latent defect this
# whole phase exists to close — counter-case A observes it happening.
naive_insert() {
  awk -v prov="$PROV" -v mirror="$MIRROR" '
    /^## / && !done {
      print prov
      while ((getline line < mirror) > 0) print line
      close(mirror)
      print ""
      done=1
    }
    { print }
    END {
      if (!done) {
        print ""
        print prov
        while ((getline line < mirror) > 0) print line
        close(mirror)
      }
    }
  ' "$1"
}

# NARROW STRIP — candidate_strip with the marker alternation REMOVED from the
# terminator (`/^## /` only). This is the highest-severity mechanic in the phase
# (D-24). On an already-healed region-led file the strip runs past
# `<!-- gitnexus:start -->` looking for a `## `, eating the start marker and the
# region's real content, and stops only at the region's own `## Always Do` —
# leaving an orphaned `<!-- gitnexus:end -->`, an unpaired region. Counter-case
# B reproduces that destruction deliberately, in a scratch dir, to prove the
# alternation is load-bearing rather than cosmetic (T-09-01).
narrow_strip() {
  awk '
    BEGIN { in_block = 0; swallowed_own_h2 = 0 }
    /<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ {
      in_block = 1
      next
    }
    in_block && !swallowed_own_h2 && /^## Coding Discipline \(NON-NEGOTIABLE\)$/ {
      swallowed_own_h2 = 1
      next
    }
    in_block && swallowed_own_h2 && (/^## /) {
      in_block = 0
      swallowed_own_h2 = 0
      print
      next
    }
    in_block { next }
    !in_block { print }
  ' "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Fixture synthesis (printf into $tmp — this repo's run-tests.sh idiom, D-34)
# ─────────────────────────────────────────────────────────────────────────────

# A gitnexus-LED AGENTS.md: H1 + prose, then the region, and only THEN a `## `
# heading AFTER the region. The ordering is the whole point — the region's own
# `## Always Do` is the first `## ` in the file, so it is what a naive anchor
# selects. A `## ` heading after the region is what discriminates D-21's rule
# from D-22.1's rejected "the region is always the anchor" alternative.
synth_region_led() {
  {
    printf '# Project Title\n'
    printf '\n'
    printf 'Intro prose that appears before any heading in this file.\n'
    printf '\n'
    printf '<!-- gitnexus:start -->\n'
    printf '# GitNexus — Code Intelligence\n'
    printf '\n'
    printf 'This project is indexed by GitNexus as example-repo.\n'
    printf '\n'
    printf '## Always Do\n'
    printf '\n'
    printf -- '- Region body line one (regenerated by `gitnexus analyze`).\n'
    printf -- '- Region body line two.\n'
    printf '\n'
    printf '<!-- gitnexus:end -->\n'
    printf '\n'
    printf '## Some Section\n'
    printf '\n'
    printf 'body\n'
  } > "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Assertion helpers
# ─────────────────────────────────────────────────────────────────────────────

# First line number of a fixed whole-line match; empty when absent.
line_of_exact() { grep -n -x -F -m1 -e "$2" "$1" 2>/dev/null | cut -d: -f1; }
# First line number of a fixed substring match; empty when absent.
line_of_sub() { grep -n -F -m1 -e "$2" "$1" 2>/dev/null | cut -d: -f1; }
# Count of whole-line fixed matches.
count_exact() { grep -c -x -F -e "$2" "$1" 2>/dev/null || true; }

# This banner is deliberately DETERMINISTIC — no repo SHA, no absolute path.
# The recorded evidence file (09-VALIDATION-EVIDENCE.md) must stay byte-
# consistent with a fresh run so a verifier can re-run and diff (T-09-04).
# Echoing `git rev-parse HEAD` here would invalidate the record on the very next
# commit — including the commit that records it — and echoing $REPO_ROOT would
# diverge between a worktree and the main checkout. The SHA and repo path belong
# in the evidence file's own header, captured alongside the run, not in stdout.
echo ""
echo "=== validate-0009-anchor — empirical replay of the D-21 anchor + D-24 terminator ==="
echo "Pinned upstream: claude-workflow @ 8520f90d235e0c50b0484b170d595ab6f2cd1173 (D-48)"
echo "Mirror:          skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md ($(wc -l < "$MIRROR" | tr -d ' ') lines)"

# ─────────────────────────────────────────────────────────────────────────────
# CASE 1 (ANCHOR-03) — zero churn against this repo's REAL AGENTS.md
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- CASE 1 (ANCHOR-03): replay strip+insert over the real AGENTS.md"

if [ ! -s "$REPO_ROOT/AGENTS.md" ]; then
  fail "CASE 1 ZERO CHURN — AGENTS.md missing or empty; replay input unavailable"
else
  cp "$REPO_ROOT/AGENTS.md" "$tmp/case1-input.md"
  candidate_strip "$tmp/case1-input.md" > "$tmp/case1.strip"
  candidate_insert "$tmp/case1.strip" > "$tmp/case1.out"

  if [ ! -s "$tmp/case1.strip" ] || [ ! -s "$tmp/case1.out" ]; then
    fail "CASE 1 ZERO CHURN — replay produced empty output (strip or insert failed)"
  elif diff -u "$tmp/case1-input.md" "$tmp/case1.out" > "$tmp/case1.diff" 2>&1; then
    pass "CASE 1 ZERO CHURN — candidate rule re-derives §11's current position byte-identically"
  else
    fail "CASE 1 ZERO CHURN — replay churned the real AGENTS.md; diff follows"
    sed 's/^/      /' "$tmp/case1.diff"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# CASE 2 (ANCHOR-04) — above-region anchoring on a gitnexus-led file
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- CASE 2 (ANCHOR-04): replay insert over a synthesized gitnexus-led AGENTS.md"

synth_region_led "$tmp/case2-input.md"
candidate_insert "$tmp/case2-input.md" > "$tmp/case2-healed.md"

c2_prov="$(line_of_sub "$tmp/case2-healed.md" "$PROV")"
c2_start="$(line_of_exact "$tmp/case2-healed.md" '<!-- gitnexus:start -->')"
c2_start_n="$(count_exact "$tmp/case2-healed.md" '<!-- gitnexus:start -->')"
c2_end_n="$(count_exact "$tmp/case2-healed.md" '<!-- gitnexus:end -->')"
c2_body="$(line_of_sub "$tmp/case2-healed.md" 'Region body line one')"

if [ ! -s "$tmp/case2-healed.md" ]; then
  fail "CASE 2 ABOVE REGION — insert produced empty output"
elif [ -z "$c2_prov" ] || [ -z "$c2_start" ]; then
  fail "CASE 2 ABOVE REGION — provenance (line '${c2_prov:-none}') or start marker (line '${c2_start:-none}') absent from output"
elif [ "$c2_prov" -ge "$c2_start" ]; then
  fail "CASE 2 ABOVE REGION — provenance at line $c2_prov is NOT above gitnexus:start at line $c2_start"
elif [ "$c2_start_n" != "1" ] || [ "$c2_end_n" != "1" ]; then
  fail "CASE 2 ABOVE REGION — region markers unpaired (start=$c2_start_n end=$c2_end_n, expected 1/1)"
elif [ -z "$c2_body" ]; then
  fail "CASE 2 ABOVE REGION — region body was destroyed by the insert"
else
  pass "CASE 2 ABOVE REGION — provenance at line $c2_prov is above gitnexus:start at line $c2_start; region intact and paired (start=$c2_start_n end=$c2_end_n), body at line $c2_body"
fi

# ─────────────────────────────────────────────────────────────────────────────
# COUNTER-CASE A — the NAIVE anchor must FAIL ANCHOR-04
#
# Replayed over the SAME synthesized gitnexus-led file as case 2. If the naive
# rule somehow landed the block above the region, case 2 could not discriminate
# between the two rules and would prove nothing — that is a FAIL here.
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- COUNTER-CASE A (D-36): replay the NAIVE anchor (0001:91) over the same gitnexus-led file"

naive_insert "$tmp/case2-input.md" > "$tmp/counterA-naive.md"

cA_prov="$(line_of_sub "$tmp/counterA-naive.md" "$PROV")"
cA_start="$(line_of_exact "$tmp/counterA-naive.md" '<!-- gitnexus:start -->')"

if [ ! -s "$tmp/counterA-naive.md" ]; then
  fail "COUNTER-CASE A NAIVE ANCHOR INSERTS INSIDE REGION — naive insert produced empty output"
elif [ -z "$cA_prov" ] || [ -z "$cA_start" ]; then
  fail "COUNTER-CASE A NAIVE ANCHOR INSERTS INSIDE REGION — provenance (line '${cA_prov:-none}') or start marker (line '${cA_start:-none}') absent"
elif [ "$cA_prov" -gt "$cA_start" ]; then
  pass "COUNTER-CASE A (counter) NAIVE ANCHOR INSERTS INSIDE REGION — naive rule put provenance at line $cA_prov, INSIDE the region that opens at line $cA_start (the latent defect, observed live)"
else
  fail "COUNTER-CASE A NAIVE ANCHOR INSERTS INSIDE REGION — naive rule anchored at line $cA_prov, above gitnexus:start at line $cA_start. The naive rule did NOT misbehave, so CASE 2 discriminates nothing and its PASS is dead-by-construction."
fi

# ─────────────────────────────────────────────────────────────────────────────
# COUNTER-CASE B — a NARROW strip terminator must DESTROY the region (D-24)
#
# State B, already-healed: case 2's candidate output, in which the block sits
# correctly anchored immediately above <!-- gitnexus:start -->. This is the
# assertion the pre-correction CONTEXT.md would not have caught: without it the
# phase can ship green and still eat a GitNexus region.
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "--- COUNTER-CASE B (D-24): replay NARROW vs WIDENED strip terminators over the already-healed file"

if [ ! -s "$tmp/case2-healed.md" ]; then
  fail "COUNTER-CASE B NARROW TERMINATOR EATS REGION — no healed State-B file to strip (case 2 produced nothing)"
  fail "WIDENED TERMINATOR PRESERVES REGION — no healed State-B file to strip"
else
  # B.1 — the narrow terminator must eat the region.
  narrow_strip "$tmp/case2-healed.md" > "$tmp/counterB-narrow.md"
  nb_start_n="$(count_exact "$tmp/counterB-narrow.md" '<!-- gitnexus:start -->')"
  nb_end_n="$(count_exact "$tmp/counterB-narrow.md" '<!-- gitnexus:end -->')"
  nb_body="$(line_of_sub "$tmp/counterB-narrow.md" 'This project is indexed by GitNexus')"

  if [ ! -s "$tmp/counterB-narrow.md" ]; then
    fail "COUNTER-CASE B NARROW TERMINATOR EATS REGION — narrow strip produced empty output"
  elif [ "$nb_start_n" = "0" ] && [ "$nb_end_n" = "1" ] && [ -z "$nb_body" ]; then
    pass "COUNTER-CASE B (counter) NARROW TERMINATOR EATS REGION — start marker DESTROYED (start=$nb_start_n) while gitnexus:end survives (end=$nb_end_n): an orphaned, unpaired region; region body content gone"
  else
    fail "COUNTER-CASE B NARROW TERMINATOR EATS REGION — narrow terminator did NOT destroy the region (start=$nb_start_n end=$nb_end_n, body line ${nb_body:-absent}). The narrow rule behaved correctly, so D-24's alternation is not shown to be load-bearing and the WIDENED assertion below is dead-by-construction."
  fi

  # B.2 — the widened terminator (the candidate) must preserve it.
  candidate_strip "$tmp/case2-healed.md" > "$tmp/counterB-widened.md"
  wb_start_n="$(count_exact "$tmp/counterB-widened.md" '<!-- gitnexus:start -->')"
  wb_end_n="$(count_exact "$tmp/counterB-widened.md" '<!-- gitnexus:end -->')"
  wb_body="$(line_of_sub "$tmp/counterB-widened.md" 'This project is indexed by GitNexus')"
  wb_prov="$(line_of_sub "$tmp/counterB-widened.md" "$PROV")"

  if [ ! -s "$tmp/counterB-widened.md" ]; then
    fail "WIDENED TERMINATOR PRESERVES REGION — candidate strip produced empty output"
  elif [ "$wb_start_n" = "1" ] && [ "$wb_end_n" = "1" ] && [ -n "$wb_body" ] && [ -z "$wb_prov" ]; then
    pass "WIDENED TERMINATOR PRESERVES REGION — region intact and paired (start=$wb_start_n end=$wb_end_n), body at line $wb_body, and the §11 block was still cleanly stripped (no provenance left)"
  else
    fail "WIDENED TERMINATOR PRESERVES REGION — start=$wb_start_n end=$wb_end_n body=${wb_body:-absent} leftover-provenance=${wb_prov:-none} (expected start=1 end=1, body present, no provenance)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "=== RESULT: all cases PASSED ==="
  exit 0
fi
echo "=== RESULT: $FAILURES case(s) FAILED ==="
exit 1
