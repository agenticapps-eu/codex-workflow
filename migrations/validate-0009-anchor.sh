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

echo ""
echo "=== validate-0009-anchor — empirical replay of the D-21 anchor + D-24 terminator ==="
echo "Repo:            $REPO_ROOT"
echo "Repo SHA:        $(git rev-parse HEAD)"
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
echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "=== RESULT: all cases PASSED ==="
  exit 0
fi
echo "=== RESULT: $FAILURES case(s) FAILED ==="
exit 1
