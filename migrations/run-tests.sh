#!/usr/bin/env bash
# Migration test harness — verifies idempotency checks behave correctly
# against known before / after reference states extracted from git.
#
# Usage:
#   migrations/run-tests.sh                # run all testable migrations
#   migrations/run-tests.sh 0001           # run only migration 0001
#   migrations/run-tests.sh -- 0000        # run only migration 0000 (which
#                                          # currently produces a SKIP)
#
# At v0.1.0 the only migration is 0000-baseline, which requires
# interactive input (user-question responses for placeholder
# substitution) and therefore cannot be tested non-interactively.
# The harness reports SKIP for 0000 and exits 0 if no other migrations
# are testable. Once incremental migrations land (v0.2.0+), each ships
# with fixtures and the dispatcher gains a `test_migration_NNNN`
# function.
#
# See migrations/test-fixtures/README.md for the fixture contract.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ]; then
  echo "error: run-tests.sh must be invoked from inside a git repo" >&2
  exit 1
fi
cd "$REPO_ROOT"

# Shared harness primitives — agenticapps-shared submodule (SPLIT-01, per
# claude-workflow ADR-0035). Provides colors (RED/GREEN/YELLOW/RESET), counters
# (PASS/FAIL/SKIP), run_check, assert_check, extract_to, run_drift_test. The
# drift POLICY (version coupling is a hard fail) stays in this consumer.
SHARED_LIB="$REPO_ROOT/vendor/agenticapps-shared/migrations/lib"
if [ ! -f "$SHARED_LIB/helpers.sh" ]; then
  echo "error: agenticapps-shared submodule not initialized." >&2
  echo "       Run: git submodule update --init --recursive   (or: bash install.sh)" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$SHARED_LIB/helpers.sh"
. "$SHARED_LIB/fixture-runner.sh"
. "$SHARED_LIB/drift-test.sh"

# Filter (optional first non-`--` arg)
FILTER=""
for arg in "$@"; do
  case "$arg" in
    --) continue ;;
    *) FILTER="$arg"; break ;;
  esac
done

# Helpers (extract_to, run_check, assert_check) are now provided by the shared
# lib sourced above (agenticapps-shared migrations/lib/helpers.sh +
# fixture-runner.sh) — no local duplication.

# ─────────────────────────────────────────────────────────────────────────────
# Fence-scoped extraction helpers (TEST-01, D-35/D-36)
#
# WHY THESE EXIST: TEST-01 requires a fixture to execute the migration's shell
# EXTRACTED FROM THE MIGRATION DOCUMENT ITSELF, never a transcribed copy. A
# transcribed copy is a second source of truth that drifts silently from the
# document it claims to test — `run-tests.sh:119` was exactly that (an inlined
# copy of 0001's injection awk), and retiring it is TEST-04.
#
# WHY NOT `extract_to()`: the shared lib's `extract_to()` (agenticapps-shared
# migrations/lib/fixture-runner.sh) is a GIT-SHOW extractor — it pulls a whole
# FILE at a git ref. It deliberately does NOT solve this problem, which is
# pulling a named FENCED BLOCK out of a markdown document. Do not mistake one
# for the other.
#
# PORTED FROM (pinned, D-48): claude-workflow @ 8520f90d235e0c50b0484b170d595ab6f2cd1173
#   migrations/test-fixtures/0029/common-verify.sh
# Diff against that path at that SHA to see what was adapted and why. Upstream
# HEAD has already moved past this pin; any later upstream change is a
# deliberate follow-up diff, not an invisible mid-execution scope change.
#
# TWO DELIBERATE ADAPTATIONS from upstream:
#   1. Scope/label matching is by LITERAL PREFIX (`index($0, p) == 1`), not by
#      an interpolated regex. Upstream hardcodes `/^### Step 1/` and
#      `/^\*\*Apply:\*\*/` because its step and label are fixed; these helpers
#      take both as parameters, so interpolating them raw into an awk regex
#      would let a metacharacter in a label change the match. A literal prefix
#      compare has nothing to escape and cannot be injected. It matches the
#      same lines upstream's anchored regexes do:
#        - `^### Step N` prefix matches BOTH this repo's `### Step 1: <title>`
#          (colon) and upstream's `### Step 1 — <title>` (dash).
#        - `**Apply:**` prefix matches BOTH `0001:83` (marker alone on its line)
#          and `0004:64` (`**Apply:** <prose>` on the same line).
#   2. On failure these report through the harness PASS/FAIL counters rather
#      than `exit 1` — upstream is a per-fixture subshell that may die; this is
#      a 278-assertion in-process suite that must not.
#
# LOAD-BEARING: `want=0` on fence open is preserved verbatim from upstream. It
# is why a ```bash → ```sh change cannot make the scan skip past the Apply
# fence and latch onto the Rollback fence below it. Do not "simplify" it away.
# ─────────────────────────────────────────────────────────────────────────────

# extract_step_block <doc_path> <step_number> <label>
# Prints the FIRST fenced block following a `**<label>:**` line within
# `### Step <step_number>`, scoped to end at `### Step <step_number+1>`.
# <label> is e.g. `Apply` or `Idempotency check`.
#
# INLINE-CODE-SPAN FALLBACK (added in 11-02, MIGR-08): 0007/0008's single-line
# steps (e.g. 0008's Step 4 version record) write the whole command as an
# INLINE code span on the SAME line as the label --
# `**Apply:** \`echo "0.6.0" > .codex/workflow-version.txt\`` -- never as a
# following fenced block. The original fenced-only scan sets `want=1` and then
# never finds a fence before the label's step ends, so it silently returns
# EMPTY on this real, immutable document shape -- 11-01-SUMMARY.md flagged
# this exact gap ("their own version-record steps (Step 4) are inline code
# spans that no fixture currently extracts via extract_step_block ... flagged
# for awareness if a future fixture ever tries to extract those steps"). This
# is that fixture (11-02). When the label line itself carries a single inline
# `` `...` `` span (nothing else but optional trailing whitespace), that span
# IS the block -- print it and exit immediately, never falling through to scan
# for a fence (which could otherwise latch onto an unrelated later fenced
# block, e.g. `## Post-checks`, since 0008 has no `### Step 5` to bound the
# scan). When the label line carries nothing inline (0009/0010's style: the
# label alone on its own line, followed by a fence), behavior is UNCHANGED --
# falls through to the original want=1 fenced-block scan.
#
# DELIMITER GUARD (REV-02, 09-REVIEW.md IN-01): `index($0, stepp) == 1` is a
# bare PREFIX test -- for step=1, stepp="### Step 1" also prefix-matches
# "### Step 10" through "### Step 19" (and 100+), because "1" followed by
# more digits is still a prefix match. A document with 10+ steps can
# therefore latch `in_step=1` on the WRONG step's heading if that heading is
# scanned before the real one. D-12's fix: require the character immediately
# AFTER the matched prefix to be a valid delimiter -- ':' (this repo's
# `### Step 1:` form), ' ' (space, covering trailing space and upstream's
# `### Step 1 -- <title>` dash form), or EOL (empty string, end of line) --
# via `delim_ok()`, a `substr`/literal character comparison. This is NOT a
# compiled regex built from interpolated input (`stepp`/`nextp` are still
# passed in as literal strings via `-v` and matched with `index()`, never
# spliced into a `/.../ ` regex) -- the file header's "literal prefix, never
# an interpolated regex, nothing to escape" no-escaping property (:80-91)
# is unchanged. The same guard is applied to `nextp` so the end-of-block
# boundary is equally precise.
extract_step_block() {
  local doc="$1" step="$2" label="$3"
  local next_step=$((step + 1))
  awk -v stepp="### Step ${step}" \
      -v nextp="### Step ${next_step}" \
      -v lblp="**${label}:**" '
    function delim_ok(line, plen,    d) {
      d = substr(line, plen + 1, 1)
      return (d == "" || d == ":" || d == " ")
    }
    index($0, stepp) == 1 && delim_ok($0, length(stepp)) { in_step=1; next }
    index($0, nextp) == 1 && delim_ok($0, length(nextp)) { in_step=0 }
    in_step && index($0, lblp) == 1 {
      rest = substr($0, length(lblp) + 1)
      sub(/^[ \t]+/, "", rest)
      if (rest ~ /^`[^`]+`[ \t]*$/) {
        sub(/^`/, "", rest)
        sub(/`[ \t]*$/, "", rest)
        print rest
        exit
      }
      want=1; next
    }
    want && /^```/ { inb=1; want=0; next }
    inb && /^```$/ { exit }
    inb { print }
  ' "$doc"
}

# extract_preflight_block <doc_path>
# Prints the first fenced block under this repo's `## Pre-flight` heading
# (`0001:44`, `0004:38`), scoped to end at the next `## ` heading. Unlike a
# step block there is no `**Label:**` marker — the heading is followed directly
# by the fence.
extract_preflight_block() {
  local doc="$1"
  awk '
    index($0, "## Pre-flight") == 1 { want=1; next }
    want && /^## / { exit }
    want && /^```/ { inb=1; want=0; next }
    inb && /^```$/ { exit }
    inb { print }
  ' "$doc"
}

# assert_extracted_shape <label> <text> <required_substring>
# D-36's antidote, ported from upstream's `case` shape guards: NON-EMPTY IS NOT
# THE SAME AS CORRECT. An extractor that drifted onto the wrong fence returns
# plenty of text. Asserts both that <text> is non-empty AND that it contains
# <required_substring>, reporting each through the harness counters (always two
# assertions per call). Prints the extracted text indented on failure.
# Returns 0 if both hold, 1 otherwise — callers MUST gate execution on this.
assert_extracted_shape() {
  local label="$1" text="$2" want="$3"

  if [ -n "$text" ]; then
    echo "  ${GREEN}PASS${RESET} $label: extraction from the real document is non-empty"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $label: extraction is EMPTY — heading/fence shape drift"
    FAIL=$((FAIL+1))
    # An empty extraction cannot contain the required substring either. Report
    # both so the assertion count stays stable whichever way the guard trips.
    echo "  ${RED}FAIL${RESET} $label: extraction does not contain '$want' (extraction was empty)"
    FAIL=$((FAIL+1))
    return 1
  fi

  case "$text" in
    *"$want"*)
      echo "  ${GREEN}PASS${RESET} $label: extraction contains '$want'"
      PASS=$((PASS+1))
      ;;
    *)
      echo "  ${RED}FAIL${RESET} $label: extraction does NOT contain '$want' — the"
      echo "         document's shape moved and the extractor followed it somewhere"
      echo "         wrong. Fix the extractor rather than trusting this block."
      echo "         Extracted:"
      printf '%s\n' "$text" | sed 's/^/       /'
      FAIL=$((FAIL+1))
      return 1
      ;;
  esac
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# extract_step_block delimiter guard (REV-02, 09-REVIEW.md IN-01)
#
# `index($0, stepp) == 1` with `stepp="### Step 1"` prefix-matches BOTH the
# real `### Step 1:` heading AND `### Step 10:` .. `### Step 19:` (a bare
# numeric continuation is not excluded by a prefix test). This is only
# reachable when the wrong heading is scanned FIRST -- in a naturally
# ascending document (1, 2, ..., 10) Step 1's own fenced block always closes
# and `exit`s before the scan ever reaches Step 10, which is exactly why this
# repo's real migration documents (currently <=4 steps) have never tripped it.
# To reproduce it honestly this fixture places `### Step 10` BEFORE
# `### Step 1` in the document text (D-34: printf-into-$tmp, no static
# fixture file) -- under the PRE-FIX extractor, scanning hits "### Step 10:"
# first, `index($0, stepp) == 1` matches it (bare-prefix collision), and
# `in_step` latches there, so `extract_step_block(doc, 1, Apply)` returns
# STEP 10's Apply body instead of Step 1's. Under the DELIMITER-GUARDED fix,
# `delim_ok` sees "0" (not ":", " ", or EOL) immediately after the matched
# "### Step 1" prefix on the "### Step 10:" line and correctly rejects it,
# so the scan continues to the real "### Step 1:" heading further down.
#
# Mutation-proven (verifier re-runs this cycle, does not trust the claim):
# stash the `delim_ok` guard (revert to the bare `index($0, stepp) == 1`
# test) and this fixture goes RED (extraction contains Step 10's body, not
# Step 1's); restore the guard and it returns GREEN. Observed by hand during
# 12-02's execution (see 12-02-SUMMARY.md).
# ─────────────────────────────────────────────────────────────────────────────

test_extract_step_block_delimiter() {
  echo ""
  echo "${YELLOW}=== extract_step_block — delimiter guard (REV-02, IN-01) ===${RESET}"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  local doc="$tmp/synthetic-10-step.md"
  # Deliberately Step 10 BEFORE Step 1 — see comment block above for why a
  # naturally-ascending document cannot reproduce the collision.
  {
    printf '### Step 10: Synthetic step ten\n'
    printf '\n'
    printf '**Apply:**\n'
    printf '```bash\n'
    printf 'echo "this is step 10 body"\n'
    printf '```\n'
    printf '\n'
    printf '### Step 1: Synthetic step one\n'
    printf '\n'
    printf '**Apply:**\n'
    printf '```bash\n'
    printf 'echo "this is step 1 body"\n'
    printf '```\n'
    printf '\n'
    printf '### Step 2: Synthetic step two\n'
    printf '\n'
    printf '**Apply:**\n'
    printf '```bash\n'
    printf 'echo "this is step 2 body"\n'
    printf '```\n'
  } > "$doc"

  local step1_apply
  step1_apply="$(extract_step_block "$doc" 1 Apply 2>/dev/null)"

  if [ -z "$step1_apply" ]; then
    echo "  ${RED}FAIL${RESET} extract_step_block(doc,1,Apply): extraction is EMPTY"
    FAIL=$((FAIL+1))
    echo "  ${RED}FAIL${RESET} extract_step_block(doc,1,Apply): extraction does not contain Step 1's body (extraction was empty)"
    FAIL=$((FAIL+1))
  else
    echo "  ${GREEN}PASS${RESET} extract_step_block(doc,1,Apply): extraction is non-empty"
    PASS=$((PASS+1))

    case "$step1_apply" in
      *'this is step 1 body'*)
        echo "  ${GREEN}PASS${RESET} extract_step_block(doc,1,Apply): extraction contains Step 1's own body"
        PASS=$((PASS+1))
        ;;
      *)
        echo "  ${RED}FAIL${RESET} extract_step_block(doc,1,Apply): extraction does NOT contain Step 1's own body"
        FAIL=$((FAIL+1))
        ;;
    esac

    case "$step1_apply" in
      *'this is step 10 body'*)
        echo "  ${RED}FAIL${RESET} extract_step_block(doc,1,Apply): extraction WRONGLY contains Step 10's body — '### Step 1' bare-prefix-matched '### Step 10'"
        FAIL=$((FAIL+1))
        ;;
      *)
        echo "  ${GREEN}PASS${RESET} extract_step_block(doc,1,Apply): extraction does NOT contain Step 10's body (delimiter guard holds)"
        PASS=$((PASS+1))
        ;;
    esac
  fi

  # Sanity: the fix must not break extraction of the step whose heading
  # caused the false match — Step 10's own Apply must still extract cleanly.
  local step10_apply
  step10_apply="$(extract_step_block "$doc" 10 Apply 2>/dev/null)"
  case "$step10_apply" in
    *'this is step 10 body'*)
      echo "  ${GREEN}PASS${RESET} extract_step_block(doc,10,Apply): Step 10's own extraction is unaffected by the guard"
      PASS=$((PASS+1))
      ;;
    *)
      echo "  ${RED}FAIL${RESET} extract_step_block(doc,10,Apply): Step 10's own extraction is BROKEN by the guard"
      FAIL=$((FAIL+1))
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0000 — Baseline
# Interactive only — placeholder substitution requires user input.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0000() {
  echo ""
  echo "${YELLOW}=== Migration 0000 — Baseline ===${RESET}"
  echo "  ${YELLOW}SKIP${RESET}: 0000-baseline.md is interactive-only"
  echo "  Validation path: run \$setup-codex-agenticapps-workflow against a"
  echo "  real fresh project and confirm the post-checks listed in"
  echo "  migrations/0000-baseline.md."
  SKIP=$((SKIP+1))
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0001 — Inject spec §11 Coding Discipline
# Testable non-interactively: idempotency check, conflict pre-flight, and
# byte-identity of the injection are validated against synthetic fixtures.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0001() {
  echo ""
  echo "${YELLOW}=== Migration 0001 — Inject spec §11 Coding Discipline ===${RESET}"

  local mirror="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
  if [ ! -f "$mirror" ]; then
    echo "  ${RED}FAIL${RESET} mirror missing: skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
    FAIL=$((FAIL+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  local PROV='<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->'

  # Fixture A: AGENTS.md with a heading but no §11 → not yet applied.
  printf '# Title\n\n## Some Section\n\nbody\n' > "$tmp/a-AGENTS.md"
  ( cd "$tmp" && grep -qE "$PROV" a-AGENTS.md )
  assert_check "idempotency: fresh AGENTS.md needs apply" \
    "grep -qE '$PROV' a-AGENTS.md" "$tmp" "not-applied"

  # Fixture B: AGENTS.md already carrying the provenance anchor → applied (skip).
  printf '# Title\n\n<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->\n## Coding Discipline (NON-NEGOTIABLE)\n\n## Some Section\n' > "$tmp/b-AGENTS.md"
  assert_check "idempotency: provenance present → skip" \
    "grep -qE '$PROV' b-AGENTS.md" "$tmp" "applied"

  # Fixture C: unmanaged §11 heading (no provenance) → conflict must be detected.
  printf '# Title\n\n## Coding Discipline (NON-NEGOTIABLE)\n\nhand-written\n' > "$tmp/c-AGENTS.md"
  if ( cd "$tmp" && grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' c-AGENTS.md \
        && ! grep -qE "$PROV" c-AGENTS.md ); then
    echo "  ${GREEN}PASS${RESET} conflict pre-flight detects unmanaged §11 prose"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} conflict pre-flight did NOT detect unmanaged §11 prose"
    FAIL=$((FAIL+1))
  fi

  # Injection byte-identity: executing 0001's OWN Step 1 Apply block against
  # fixture A must produce a §11 block byte-identical to the mirror.
  #
  # This closes TEST-04 / Success Criterion 5. Until now this assertion ran an
  # INLINED COPY of 0001's injection awk transcribed into this harness — a
  # second source of truth that could drift from the document it claimed to
  # test. It is now extracted from 0001's document itself (TEST-01).
  #
  # 0001 IS IMMUTABLE (fix-forward). Its anchor is the naive `/^## / && !done`,
  # which is exactly the defect migration 0009 exists to heal. Asserting it here
  # FAITHFULLY is deliberate: this test documents what 0001 actually does, not
  # what we wish it did. That is a fidelity improvement, not a behavior change,
  # and it does not conflict with 0009's fixtures going RED.
  #
  # KNOWN, DEFERRED (D-37): 0008's Step-3 insert-awk copy near :985 is a real
  # instance of this same drift class. It is scoped OUT of this phase — reaching
  # into another migration's tests widens a placement fix into harness
  # refactoring across a 278-assertion suite. It was not missed; it is tracked.
  local step1_apply
  step1_apply="$(extract_step_block \
    "$REPO_ROOT/migrations/0001-inject-spec-11-coding-discipline.md" 1 Apply)"

  # Extraction from the REAL document must be non-empty AND identifiably the
  # mirror-streaming injection block BEFORE the injection is asserted — a
  # heading-regex drift must report as "extraction empty/wrong" rather than as a
  # confusing downstream injection failure (T-08-23 precedent at :967-977, here
  # generalized from template content to the migration's own shell).
  if assert_extracted_shape "0001 Step 1 Apply" "$step1_apply" 'getline line < mirror'; then
    # Scratch project root + fake Codex home. 0001's Apply block is
    # self-contained: it re-declares MIRROR from ${CODEX_HOME:-$HOME/.codex} and
    # operates on AGENTS.md in the current directory — which is what makes it
    # eval-able here without modification.
    local proj="$tmp/proj0001"
    local fakehome="$tmp/codexhome"
    local fakemirrors="$fakehome/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors"
    mkdir -p "$proj" "$fakemirrors"
    cp "$mirror" "$fakemirrors/11-coding-discipline-0.4.0.md"
    printf '# Title\n\n## Some Section\n\nbody\n' > "$proj/AGENTS.md"

    # SUBSHELL IS MANDATORY: an extracted block that takes an `exit` path would
    # otherwise terminate the whole suite mid-run, hiding every later assertion.
    ( cd "$proj" && export CODEX_HOME="$fakehome" && eval "$step1_apply" ) \
      >/dev/null 2>&1

    awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' \
      "$proj/AGENTS.md" > "$tmp/a-block.md"
    if diff -q "$tmp/a-block.md" "$mirror" >/dev/null 2>&1; then
      echo "  ${GREEN}PASS${RESET} injected §11 block is byte-identical to the mirror"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} injected §11 block differs from the mirror"
      FAIL=$((FAIL+1))
    fi
  else
    echo "  ${RED}FAIL${RESET} injected §11 block byte-identity NOT asserted — 0001's"
    echo "         Step 1 Apply block could not be extracted from its document."
    FAIL=$((FAIL+1))
  fi

  # Mirror byte-identity vs core spec (only when the core spec repo is present).
  # Extract the canonical block FENCE-RELATIVE (content between the two four-backtick
  # fences) rather than by hardcoded line numbers — robust to spec edits that shift
  # line numbers (e.g. core 10f2c96 added blank lines around the anti-pattern lists).
  local core="$REPO_ROOT/../agenticapps-workflow-core/spec/11-coding-discipline.md"
  if [ -f "$core" ]; then
    if diff -q <(awk '/^````$/{f++; next} f==1{print}' "$core") "$mirror" >/dev/null 2>&1; then
      echo "  ${GREEN}PASS${RESET} mirror == core spec §11 canonical block (verbatim, fence-relative)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} mirror has drifted from core spec §11"
      FAIL=$((FAIL+1))
    fi
  else
    echo "  ${YELLOW}SKIP${RESET} core spec repo not adjacent — mirror/core diff not checked"
    SKIP=$((SKIP+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0002 — Add codex-ts-declare-first skill (spec §13)
# Testable non-interactively: idempotency check + jq apply/rollback on a
# synthetic .planning/config.json fixture.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0002() {
  echo ""
  echo "${YELLOW}=== Migration 0002 — Add codex-ts-declare-first skill ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-edit test not run"
    SKIP=$((SKIP+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Synthetic config without the §13 binding.
  cat > "$tmp/config.json" <<'JSON'
{ "hooks": { "per_task": { "tdd": { "skill": "codex-tdd", "fires_when": "tdd=true", "commit_pair": ["test(RED):","feat(GREEN):"] } } } }
JSON

  assert_check "idempotency: fresh config needs the §13 binding" \
    "jq -e '.hooks.per_task.tdd.strengthened_by.skill == \"codex-ts-declare-first\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # Apply Step 1's jq.
  ( cd "$tmp" && jq '.hooks.per_task.tdd.strengthened_by = {
      "skill": "codex-ts-declare-first",
      "implements_spec": "0.4.0",
      "fires_when": "task introduces a new TypeScript module public API surface in a TS-primary project",
      "commit_sequence": ["declare(ts):", "test(ts):", "feat(ts):"]
    }' config.json > config.tmp && mv config.tmp config.json )

  assert_check "after apply: §13 binding present" \
    "jq -e '.hooks.per_task.tdd.strengthened_by.skill == \"codex-ts-declare-first\"' config.json >/dev/null" \
    "$tmp" "applied"

  # Base tdd binding must be intact (not clobbered).
  if ( cd "$tmp" && jq -e '.hooks.per_task.tdd.skill == "codex-tdd"' config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} base tdd binding intact after strengthening"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} base tdd binding lost"
    FAIL=$((FAIL+1))
  fi

  # Rollback removes the binding.
  ( cd "$tmp" && jq 'del(.hooks.per_task.tdd.strengthened_by)' config.json > config.tmp && mv config.tmp config.json )
  assert_check "after rollback: binding removed" \
    "jq -e '.hooks.per_task.tdd.strengthened_by.skill == \"codex-ts-declare-first\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # The shipped skill has three SEPARATE template files (structural three-commit shape).
  local sk="$REPO_ROOT/skills/codex-ts-declare-first"
  if [ -f "$sk/templates/example.declare.ts" ] && [ -f "$sk/templates/example.test.ts" ] && [ -f "$sk/templates/example.impl.ts" ]; then
    echo "  ${GREEN}PASS${RESET} three separate phase templates ship with the skill"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} ts-declare-first templates missing or incomplete"
    FAIL=$((FAIL+1))
  fi

  # The declare template must be declare-only (no implementation bodies).
  if grep -qE '(^|[^.])\bexport declare\b' "$sk/templates/example.declare.ts" 2>/dev/null \
     && ! grep -qE '^\s*(return|this\.[a-zA-Z]+ =)' "$sk/templates/example.declare.ts" 2>/dev/null; then
    echo "  ${GREEN}PASS${RESET} declare template is declare-only (no impl bodies)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} declare template contains implementation bodies"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0003 — Delegate §10 observability to agenticapps-observability
# Testable non-interactively: idempotency + jq apply/rollback on a synthetic
# config; conditional AGENTS.md repoint on a synthetic fixture.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0003() {
  echo ""
  echo "${YELLOW}=== Migration 0003 — Delegate §10 observability ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-edit test not run"
    SKIP=$((SKIP+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Synthetic config without the delegation.
  cat > "$tmp/config.json" <<'JSON'
{ "hooks": { "per_task": { "tdd": { "skill": "codex-tdd" } } } }
JSON

  assert_check "idempotency: fresh config needs the §10 delegation" \
    "jq -e '.hooks.observability.delegated_to == \"observability\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # Apply Step 1's jq.
  ( cd "$tmp" && jq '.hooks.observability = {
      "delegated_to": "observability",
      "implements_spec": "0.4.0",
      "host": "codex",
      "invoke": "$observability",
      "spec_section": "10"
    }' config.json > config.tmp && mv config.tmp config.json )

  assert_check "after apply: §10 delegation present" \
    "jq -e '.hooks.observability.delegated_to == \"observability\"' config.json >/dev/null" \
    "$tmp" "applied"

  # Base hooks must be intact.
  if ( cd "$tmp" && jq -e '.hooks.per_task.tdd.skill == "codex-tdd"' config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} base hooks intact after delegation record"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} base hooks lost"
    FAIL=$((FAIL+1))
  fi

  # Rollback removes the delegation.
  ( cd "$tmp" && jq 'del(.hooks.observability)' config.json > config.tmp && mv config.tmp config.json )
  assert_check "after rollback: delegation removed" \
    "jq -e '.hooks.observability.delegated_to == \"observability\"' config.json >/dev/null" \
    "$tmp" "not-applied"

  # Step 2 §10.8 relocate: an anchored observability block in CLAUDE.md (init's
  # output) is moved to AGENTS.md, preserving its real content, and removed from
  # CLAUDE.md.
  printf '# Project\n\n<!-- agenticapps:observability:start -->\nobservability:\n  spec_version: 0.3.2\n  skill: add-observability\n  policy: lib/observability/policy.md\n<!-- agenticapps:observability:end -->\n' > "$tmp/CLAUDE.md"
  printf '# AGENTS\n\nbody\n' > "$tmp/AGENTS.md"
  ( cd "$tmp" \
    && awk '/<!-- agenticapps:observability:start -->/,/<!-- agenticapps:observability:end -->/' CLAUDE.md >> AGENTS.md \
    && awk 'BEGIN{d=0} /<!-- agenticapps:observability:start -->/{d=1} d==0{print} /<!-- agenticapps:observability:end -->/{d=0}' CLAUDE.md > CLAUDE.md.t && mv CLAUDE.md.t CLAUDE.md )
  if ( cd "$tmp" \
       && grep -q '^observability:' AGENTS.md \
       && grep -q 'policy: lib/observability/policy.md' AGENTS.md \
       && ! grep -q '<!-- agenticapps:observability:start -->' CLAUDE.md ); then
    echo "  ${GREEN}PASS${RESET} Step 2 relocates the §10.8 block CLAUDE.md→AGENTS.md (content preserved)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Step 2 relocate did not move the §10.8 block correctly"
    FAIL=$((FAIL+1))
  fi

  # Step 3 conditional repoint: a stale 'skill: add-observability' becomes 'skill: observability'
  # (anchored to a line-leading skill: key).
  ( cd "$tmp" && sed -i.bak -E 's/^([[:space:]]*skill:[[:space:]]*)add-observability/\1observability/' AGENTS.md && rm -f AGENTS.md.bak )
  if ( cd "$tmp" && grep -q 'skill: observability' AGENTS.md && ! grep -qE '^[[:space:]]*skill:[[:space:]]*add-observability' AGENTS.md ); then
    echo "  ${GREEN}PASS${RESET} Step 3 repoints a stale add-observability skill ref (anchored sed)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Step 3 repoint did not rewrite the stale skill ref"
    FAIL=$((FAIL+1))
  fi

  # The delegation/binding doc + ADR ship.
  if [ -f "$REPO_ROOT/docs/observability-delegation.md" ] && [ -f "$REPO_ROOT/docs/decisions/0005-adopt-observability-architecture.md" ]; then
    echo "  ${GREEN}PASS${RESET} delegation doc + ADR-0005 ship"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} delegation doc or ADR-0005 missing"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0004 — Re-vendor §11 mirror (blank-line drift fix)
# The live AGENTS.md §11 block MUST match the (corrected) mirror, and the mirror
# MUST match current core §11 (checked fence-relative in test_migration_0001).
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0004() {
  echo ""
  echo "${YELLOW}=== Migration 0004 — Re-vendor §11 mirror ===${RESET}"
  local mirror="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"

  # The scaffolder's own AGENTS.md §11 block must be byte-identical to the
  # corrected mirror (this is the post-0004 invariant + the idempotency check).
  if awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' "$REPO_ROOT/AGENTS.md" \
       | diff -q - "$mirror" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} AGENTS.md §11 block == corrected mirror (re-vendor applied)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} AGENTS.md §11 block differs from the corrected mirror"
    FAIL=$((FAIL+1))
  fi

  # The mirror must be the 79-line (post-10f2c96) shape, not the stale 75-line one.
  local n; n=$(wc -l < "$mirror" | tr -d ' ')
  if [ "$n" -ge 79 ]; then
    echo "  ${GREEN}PASS${RESET} mirror is the current ($n-line) core §11 shape"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} mirror is the stale shape ($n lines; expected ≥79)"
    FAIL=$((FAIL+1))
  fi

  # WR-01/Q2 — the mirror's single-`## ` invariant. 0009 Step 1's strip pass
  # explicitly swallows the block's OWN `## ` heading first, then terminates
  # at the NEXT `## ` line. That is only correct because the canonical mirror
  # carries exactly ONE `## ` line, on line 1 — 09.1-05's refuse gate rests on
  # the same invariant. It was unasserted, and it lives in a file this repo
  # vendors rather than authors: if the mirror ever gains a second `## `, the
  # strip terminates early and leaves body behind. Asserted at `== 1`, not
  # `>= 1` — a count of 1 today and 2 tomorrow must fail.
  local n_h2 first_h2
  n_h2=$(grep -c '^## ' "$mirror" | tr -d ' ')
  first_h2=$(grep -n '^## ' "$mirror" | head -1 | cut -d: -f1)
  if [ "$n_h2" = "1" ] && [ "$first_h2" = "1" ]; then
    echo "  ${GREEN}PASS${RESET} mirror carries exactly ONE '## ' line, on line 1 (the strip's single-heading swallow invariant, WR-01/Q2)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} mirror carries $n_h2 '## ' line(s), first at line ${first_h2:-ABSENT} (expected exactly 1, on line 1 — the strip's single-heading swallow would terminate early and leave body behind)"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0005 — Bind upstream GSD + Superpowers; namespace the hook config
# Testable non-interactively: config rename (config.json → config.codex.json) +
# jq rebind/rollback of the six Superpowers-duplicate gates on a synthetic config,
# plus a kept-gate-intact assertion.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0005() {
  echo ""
  echo "${YELLOW}=== Migration 0005 — Bind upstream GSD + Superpowers ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-edit test not run"
    SKIP=$((SKIP+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/.planning"

  # Synthetic pre-0.3.0 config: old name, codex-* dupe bindings, a kept gstack
  # gate (design_shotgun), and the §13 strengthener from migration 0002.
  cat > "$tmp/.planning/config.json" <<'JSON'
{ "hooks": {
    "pre_phase": {
      "brainstorm_ui": { "skill": "codex-brainstorming", "mode": "ui" },
      "brainstorm_architecture": { "skill": "codex-brainstorming", "mode": "architecture" },
      "design_shotgun": { "skill": "codex-design-shotgun" }
    },
    "per_task": {
      "tdd": { "skill": "codex-tdd", "strengthened_by": { "skill": "codex-ts-declare-first" } },
      "verification": { "skill": "codex-verification" }
    },
    "post_phase": { "code_review": { "skill": "codex-code-review", "stage": 2 } },
    "finishing": { "branch_close": { "skill": "codex-finishing-branch" } }
} }
JSON

  # Step 1 idempotency: not yet renamed → needs apply.
  assert_check "idempotency: config.json still present → needs namespacing" \
    "test -f .planning/config.codex.json && ! test -f .planning/config.json" \
    "$tmp" "not-applied"

  # Apply Step 1 (rename).
  ( cd "$tmp" && mv .planning/config.json .planning/config.codex.json )
  assert_check "after Step 1: config namespaced to config.codex.json" \
    "test -f .planning/config.codex.json && ! test -f .planning/config.json" \
    "$tmp" "applied"

  # Step 2 idempotency: dupe gate still codex-* → needs rebind.
  assert_check "idempotency: dupe gate still codex-* → needs rebind" \
    "jq -e '.hooks.pre_phase.brainstorm_ui.skill == \"superpowers:brainstorming\"' .planning/config.codex.json >/dev/null" \
    "$tmp" "not-applied"

  # Apply Step 2 (rebind).
  ( cd "$tmp" && jq '
        .hooks.pre_phase.brainstorm_ui.skill           = "superpowers:brainstorming"
      | .hooks.pre_phase.brainstorm_architecture.skill = "superpowers:brainstorming"
      | .hooks.per_task.tdd.skill                      = "superpowers:test-driven-development"
      | .hooks.per_task.verification.skill             = "superpowers:verification-before-completion"
      | .hooks.post_phase.code_review.skill            = "superpowers:requesting-code-review"
      | .hooks.finishing.branch_close.skill            = "superpowers:finishing-a-development-branch"
    ' .planning/config.codex.json > .planning/config.tmp && mv .planning/config.tmp .planning/config.codex.json )

  assert_check "after Step 2: tdd rebound to superpowers" \
    "jq -e '.hooks.per_task.tdd.skill == \"superpowers:test-driven-development\"' .planning/config.codex.json >/dev/null" \
    "$tmp" "applied"
  assert_check "after Step 2: code_review rebound to superpowers" \
    "jq -e '.hooks.post_phase.code_review.skill == \"superpowers:requesting-code-review\"' .planning/config.codex.json >/dev/null" \
    "$tmp" "applied"

  # Kept gstack gate must be intact (not clobbered).
  if ( cd "$tmp" && jq -e '.hooks.pre_phase.design_shotgun.skill == "codex-design-shotgun"' .planning/config.codex.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} kept gstack gate (design-shotgun) intact after rebind"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} kept gstack gate clobbered by rebind"
    FAIL=$((FAIL+1))
  fi

  # The §13 strengthener from 0002 must survive the rebind.
  if ( cd "$tmp" && jq -e '.hooks.per_task.tdd.strengthened_by.skill == "codex-ts-declare-first"' .planning/config.codex.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} §13 strengthener (codex-ts-declare-first) preserved"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} §13 strengthener lost during rebind"
    FAIL=$((FAIL+1))
  fi

  # Rollback Step 2 restores codex-* bindings.
  ( cd "$tmp" && jq '
        .hooks.pre_phase.brainstorm_ui.skill           = "codex-brainstorming"
      | .hooks.pre_phase.brainstorm_architecture.skill = "codex-brainstorming"
      | .hooks.per_task.tdd.skill                      = "codex-tdd"
      | .hooks.per_task.verification.skill             = "codex-verification"
      | .hooks.post_phase.code_review.skill            = "codex-code-review"
      | .hooks.finishing.branch_close.skill            = "codex-finishing-branch"
    ' .planning/config.codex.json > .planning/config.tmp && mv .planning/config.tmp .planning/config.codex.json )
  assert_check "after Step 2 rollback: bindings back to codex-*" \
    "jq -e '.hooks.per_task.tdd.skill == \"superpowers:test-driven-development\"' .planning/config.codex.json >/dev/null" \
    "$tmp" "not-applied"

  # The binding ADR + BINDING doc ship.
  if [ -f "$REPO_ROOT/docs/BINDING.md" ] && [ -f "$REPO_ROOT/docs/decisions/0007-bind-upstream-gsd.md" ]; then
    echo "  ${GREEN}PASS${RESET} docs/BINDING.md + ADR-0007 ship"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} docs/BINDING.md or ADR-0007 missing"
    FAIL=$((FAIL+1))
  fi

  # The re-ported skills must be gone from the scaffolder.
  local leaked=""
  for s in gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-debug gsd-quick \
           codex-brainstorming codex-tdd codex-verification codex-finishing-branch \
           codex-code-review codex-systematic-debugging; do
    [ -e "$REPO_ROOT/skills/$s" ] && leaked="$leaked $s"
  done
  if [ -z "$leaked" ]; then
    echo "  ${GREEN}PASS${RESET} re-ported gsd-*/superpowers-dupe skills removed from scaffolder"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} re-ported skills still present:$leaked"
    FAIL=$((FAIL+1))
  fi
}

test_migration_0006() {
  echo ""
  echo "${YELLOW}=== Migration 0006 — Commit phase artifacts (strip whole-tree ignore) ===${RESET}"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Synthetic project .gitignore: a whole-tree phases ignore (to strip), a
  # narrow under-tree scratch ignore (to preserve), and legitimate transient
  # ignores (to preserve).
  cat > "$tmp/.gitignore" <<'IGN'
node_modules/
.planning/cache/
.planning/state/
.planning/phases/
.planning/phases/*/.codex-review.md
IGN

  # Step 1 idempotency: whole-tree ignore present → needs apply.
  assert_check "idempotency: whole-tree .planning/phases/ ignore present → needs strip" \
    "[ ! -f .gitignore ] || ! grep -qE '^[[:space:]]*/?\.planning/phases/?[[:space:]]*\$' .gitignore" \
    "$tmp" "not-applied"

  # Apply Step 1 (strip whole-tree ignore; preserve narrow + transient).
  ( cd "$tmp" && sed -i.0006.bak -E \
      -e '/^[[:space:]]*\/?\.planning\/phases\/?[[:space:]]*$/d' \
      -e '/^[[:space:]]*\/?\.planning\/?[[:space:]]*$/d' \
      -e '/^[[:space:]]*\/?\.planning\/\*[[:space:]]*$/d' \
      .gitignore && rm -f .gitignore.0006.bak )

  assert_check "after Step 1: no whole-tree .planning/phases/ ignore remains" \
    "[ ! -f .gitignore ] || ! grep -qE '^[[:space:]]*/?\.planning/phases/?[[:space:]]*\$' .gitignore" \
    "$tmp" "applied"

  # Narrow under-tree scratch ignore preserved.
  if grep -qF '.planning/phases/*/.codex-review.md' "$tmp/.gitignore"; then
    echo "  ${GREEN}PASS${RESET} narrow under-tree scratch ignore preserved"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} narrow under-tree scratch ignore was clobbered"
    FAIL=$((FAIL+1))
  fi

  # Transient .planning/cache/ + .planning/state/ preserved.
  if grep -qF '.planning/cache/' "$tmp/.gitignore" && grep -qF '.planning/state/' "$tmp/.gitignore"; then
    echo "  ${GREEN}PASS${RESET} transient .planning/cache/ + .planning/state/ preserved"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} transient cache/state ignore lost"
    FAIL=$((FAIL+1))
  fi

  # Version-bump round-trip (Step 2) on a synthetic SKILL.md copy.
  printf 'version: 0.3.0\nimplements_spec: 0.4.0\n' > "$tmp/SKILL.md"
  ( cd "$tmp" && sed -i.0006.bak -E 's/^version: 0\.3\.0$/version: 0.4.0/' SKILL.md && rm -f SKILL.md.0006.bak )
  assert_check "after Step 2: version bumped to 0.4.0" \
    "grep -q '^version: 0.4.0\$' SKILL.md" "$tmp" "applied"
  # implements_spec must NOT be touched by the version bump.
  if grep -q '^implements_spec: 0.4.0$' "$tmp/SKILL.md"; then
    echo "  ${GREEN}PASS${RESET} implements_spec untouched by version bump"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} implements_spec was altered"
    FAIL=$((FAIL+1))
  fi
  # Rollback restores 0.3.0.
  ( cd "$tmp" && sed -i.bak -E 's/^version: 0\.4\.0$/version: 0.3.0/' SKILL.md && rm -f SKILL.md.bak )
  assert_check "after Step 2 rollback: version back to 0.3.0" \
    "grep -q '^version: 0.4.0\$' SKILL.md" "$tmp" "not-applied"

  # An already-clean .gitignore is a no-op (idempotent re-apply).
  printf 'node_modules/\n.planning/cache/\n' > "$tmp/clean.gitignore"
  if ! grep -qE '^[[:space:]]*/?\.planning/phases/?[[:space:]]*$' "$tmp/clean.gitignore"; then
    echo "  ${GREEN}PASS${RESET} already-clean .gitignore needs no change (idempotent)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} false-positive on a clean .gitignore"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0007 — Knowledge capture (spec §15) into the Obsidian vault.
# Testable non-interactively: the config merge (resolve <repo-name>, preserve a
# pre-existing key, codex-only create) + the AGENTS.md section insert/idempotency
# + the version-bump round-trip. Uses the real shipped templates as source.
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0007() {
  echo ""
  echo "${YELLOW}=== Migration 0007 — Knowledge capture (spec §15) ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-merge test not run"
    SKIP=$((SKIP+1)); return
  fi

  local kc_tpl agents_tpl
  kc_tpl="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/config-knowledge-capture.json"
  agents_tpl="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md"

  # Templates must ship (single source of truth for both fresh + migrated).
  if [ -f "$kc_tpl" ] && [ -f "$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/obsidian-learnings-note.md" ]; then
    echo "  ${GREEN}PASS${RESET} knowledge-capture templates ship (config block + note skeleton)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} knowledge-capture template(s) missing"
    FAIL=$((FAIL+1))
  fi

  # The shipped block is host-neutral (no host-specific keys) and enabled.
  if jq -e '.knowledge_capture | has("enabled") and has("note") and (keys | length == 2)' "$kc_tpl" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} config block is host-neutral (only enabled + note)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} config block carries unexpected/host-specific keys"
    FAIL=$((FAIL+1))
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/.planning"

  local REPO_NAME="codex-workflow"
  local KC
  KC="$(jq -c --arg name "$REPO_NAME" \
          '.knowledge_capture.note |= gsub("<repo-name>"; $name) | .knowledge_capture' \
          "$kc_tpl")"

  # --- Merge path: pre-existing config.json with a claude-written key survives.
  cat > "$tmp/.planning/config.json" <<'JSON'
{ "host": "claude", "hooks": { "post_phase": { "code_review": { "stage": 2 } } } }
JSON

  # Step 1 idempotency (pre): no knowledge_capture yet → needs apply.
  assert_check "idempotency: config.json has no knowledge_capture → needs seed" \
    "test -f .planning/config.json && jq -e '.knowledge_capture' .planning/config.json >/dev/null" \
    "$tmp" "not-applied"

  ( cd "$tmp" && jq --argjson kc "$KC" '. + {knowledge_capture: $kc}' \
      .planning/config.json > .planning/config.json.tmp \
      && mv .planning/config.json.tmp .planning/config.json )

  assert_check "after merge: knowledge_capture present" \
    "jq -e '.knowledge_capture.enabled == true' .planning/config.json >/dev/null" \
    "$tmp" "applied"

  # <repo-name> placeholder resolved to the real repo directory name.
  if ( cd "$tmp" && jq -e '.knowledge_capture.note | endswith("/codex-workflow.md")' .planning/config.json >/dev/null ) \
     && ! grep -qF '<repo-name>' "$tmp/.planning/config.json"; then
    echo "  ${GREEN}PASS${RESET} <repo-name> resolved in note path; no placeholder left"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} <repo-name> not resolved (or placeholder remains)"
    FAIL=$((FAIL+1))
  fi

  # Pre-existing claude key preserved by the merge (host-neutral coexistence).
  if ( cd "$tmp" && jq -e '.hooks.post_phase.code_review.stage == 2 and .host == "claude"' .planning/config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} pre-existing (claude) config keys preserved by merge"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} merge clobbered pre-existing config keys"
    FAIL=$((FAIL+1))
  fi

  # --- Create path: codex-only repo (no config.json) gets a block-only file.
  rm -f "$tmp/.planning/config.json"
  ( cd "$tmp" && jq -n --argjson kc "$KC" '{knowledge_capture: $kc}' > .planning/config.json )
  if ( cd "$tmp" && jq -e '(keys == ["knowledge_capture"])' .planning/config.json >/dev/null ); then
    echo "  ${GREEN}PASS${RESET} codex-only create yields a block-only shared config.json"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} codex-only create produced unexpected keys"
    FAIL=$((FAIL+1))
  fi

  # --- AGENTS.md section insert from the real template.
  cat > "$tmp/AGENTS.md" <<'MD'
# AGENTS.md — fixture

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Session handoff

Existing content.

<!-- END: agentic-apps-workflow sections -->
MD

  # Step 2 idempotency (pre): section absent → needs insert.
  assert_check "idempotency: AGENTS.md lacks Knowledge Capture section → needs insert" \
    "grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md" \
    "$tmp" "not-applied"

  local secfile; secfile="$tmp/section.txt"
  awk '
    /^## Knowledge Capture — Ritual Tail \(spec §15\)/ {f=1}
    /^<!-- END: agentic-apps-workflow sections -->/    {f=0}
    f
  ' "$agents_tpl" > "$secfile"

  ( cd "$tmp" && awk -v secfile="$secfile" '
      /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
        while ((getline line < secfile) > 0) print line
        ins=1
      }
      { print }
    ' AGENTS.md > AGENTS.md.0007.tmp && mv AGENTS.md.0007.tmp AGENTS.md )

  assert_check "after insert: Knowledge Capture section present in AGENTS.md" \
    "grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' AGENTS.md" \
    "$tmp" "applied"

  # Section landed INSIDE the marker block (before the END marker).
  if awk '/^## Knowledge Capture — Ritual Tail/{k=NR} /^<!-- END: agentic-apps-workflow sections -->/{e=NR} END{exit !(k>0 && e>0 && k<e)}' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} section sits inside the agentic-apps-workflow marker block"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} section landed outside the marker block"
    FAIL=$((FAIL+1))
  fi

  # Config-routed, not hardcoded: the section names the shared .planning/config.json
  # and explicitly steers away from the host-specific config.codex.json.
  if grep -qF '.planning/config.json' "$tmp/AGENTS.md" \
     && grep -qF 'config.codex.json' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} section routes destination via shared .planning/config.json"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} section does not disambiguate the config source"
    FAIL=$((FAIL+1))
  fi

  # Host tag is codex in the Log-heading shape.
  if grep -qF '(codex)' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} Log-entry heading carries the (codex) host tag"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} (codex) host tag missing from the section"
    FAIL=$((FAIL+1))
  fi

  # --- Version-bump round-trip on a synthetic SKILL.md copy.
  printf 'version: 0.4.0\nimplements_spec: 0.4.0\n' > "$tmp/SKILL.md"
  ( cd "$tmp" && sed -i.0007.bak -E 's/^version: 0\.4\.0$/version: 0.5.0/' SKILL.md && rm -f SKILL.md.0007.bak )
  assert_check "after Step 3: version bumped to 0.5.0" \
    "grep -q '^version: 0.5.0\$' SKILL.md" "$tmp" "applied"
  if grep -q '^implements_spec: 0.4.0$' "$tmp/SKILL.md"; then
    echo "  ${GREEN}PASS${RESET} implements_spec untouched by version bump"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} implements_spec was altered"
    FAIL=$((FAIL+1))
  fi

  # The ADR ships.
  if [ -f "$REPO_ROOT/docs/decisions/0008-knowledge-capture.md" ]; then
    echo "  ${GREEN}PASS${RESET} ADR-0008 (knowledge capture) ships"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} ADR-0008 missing"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0008 — Plan-review gate (spec §02, v0.5.0 -> 0.6.0)
#
# Four steps (no target-project SKILL.md step — 08-05-PLAN.md
# <target_project_surface>): (1) leaf-level config merge into
# .planning/config.codex.json, (2) AGENTS.md ritual-section insert extracted
# from the real template, (3) AGENTS.md bindings-table corrections (D-20 —
# brainstorm split + tdd collapse + plan-review add, plan 08-06), (4)
# .codex/workflow-version.txt version record. This repo's own scaffolder bump
# is a direct edit in plan 08-05's commit, never a migration step — no 0008
# sandbox here manufactures a synthetic SKILL.md.
# ─────────────────────────────────────────────────────────────────────────────

# Extract a Markdown bindings-table's DATA rows only (no header, no
# separator) — shared by test_migration_0008's Step 3 (bindings-table
# corrections, D-20) assertions. Stops at the first non-"|" line after the
# table starts, so it never bleeds into unrelated content below the table.
_table_data_rows() {
  awk '
    /^\| Gate \|/ { in_table=1; next }
    in_table && /^\|---/ { next }
    in_table && /^\|/ { print; next }
    in_table { exit }
  ' "$1"
}

test_migration_0008() {
  echo ""
  echo "${YELLOW}=== Migration 0008 — Plan-review gate (spec §02) ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-merge test not run"
    SKIP=$((SKIP+1)); return
  fi

  local hooks_tpl agents_tpl
  hooks_tpl="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/config-hooks.json"
  agents_tpl="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md"

  # Templates must ship (single source of truth for both fresh + migrated).
  if [ -f "$hooks_tpl" ] && [ -f "$agents_tpl" ]; then
    echo "  ${GREEN}PASS${RESET} plan-review templates ship (config-hooks.json + agents-md-additions.md)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} plan-review template(s) missing"
    FAIL=$((FAIL+1))
  fi

  # $PE is the pre_execution object's CONTENTS (i.e. {"plan_review": {...}}),
  # sourced from the installed template via --argjson — never a heredoc'd
  # literal (single-source-of-truth, D-19).
  local PE
  PE="$(jq -c '.hooks.pre_execution' "$hooks_tpl")"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/.planning" "$tmp/.codex"

  # ── Step 1 — leaf-level config merge into .planning/config.codex.json ────
  # Fixture carries all THREE kinds of neighbour so every preservation
  # assertion is real, not vacuous: a sibling gate under
  # .hooks.pre_execution.other_gate (findings 2/3/4 — the one the original
  # fixture lacked and the only one that can catch a replaced pre_execution
  # object), a gate under a different group (.hooks.post_phase.spec_review),
  # and a foreign top-level key (mirrors 0007's "host": "claude" trick).
  # NOTE: kept as a single JSON line deliberately — a multi-line pretty-print
  # would place a bare "}" at column 0, which this repo's own
  # acceptance-check idiom (`awk '/^test_migration_0008\(\)/{f=1} f&&/^}/{exit} f'`)
  # uses as the function-body end marker; a stray "}" mid-fixture would
  # truncate that extraction early and silently hide everything after it.
  cat > "$tmp/.planning/config.codex.json" <<'JSON'
{ "custom_operator_key": "unchanged", "hooks": { "pre_execution": { "other_gate": { "skill": "some-other-gate" } }, "post_phase": { "spec_review": { "skill": "codex-spec-review", "stage": 1 } } } }
JSON

  # Idempotency check on the LEAF, not the group (finding 1). This fixture's
  # pre_execution GROUP already exists (holding only other_gate) — a
  # group-level check (`jq -e '.hooks.pre_execution'`) would read "applied"
  # here and silently skip the migration, leaving an install with a sibling
  # gate but no plan_review while reporting success. The leaf check must read
  # "not-applied", i.e. the migration must still run.
  assert_check "idempotency (leaf): pre_execution exists (sibling other_gate only), plan_review absent -> needs merge" \
    "jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null" \
    "$tmp" "not-applied"

  # Apply — leaf-level deep merge (finding 2). NEVER `.hooks += {pre_execution: $pe}`,
  # which preserves other hook GROUPS but replaces the whole pre_execution
  # object, deleting other_gate. `// {}` handles the first-run case where
  # pre_execution does not exist at all.
  ( cd "$tmp" && jq --argjson pe "$PE" \
      '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
      .planning/config.codex.json > .planning/config.codex.json.tmp \
      && mv .planning/config.codex.json.tmp .planning/config.codex.json )

  assert_check "after merge: plan_review present at the leaf (min_reviewers == 2)" \
    "jq -e '.hooks.pre_execution.plan_review.min_reviewers == 2' .planning/config.codex.json >/dev/null" \
    "$tmp" "applied"

  # Merge preserves the SIBLING pre-execution gate (findings 2 + 4) — the
  # assertion the original (group-only) fixture could not make.
  if ( cd "$tmp" && jq -e '.hooks.pre_execution.other_gate.skill == "some-other-gate" and (.hooks.pre_execution.plan_review.skill == "codex-plan-review")' .planning/config.codex.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} merge preserves sibling pre_execution gate (other_gate) alongside plan_review"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} merge clobbered the sibling pre_execution gate (other_gate)"
    FAIL=$((FAIL+1))
  fi

  # Merge preserves other top-level hook groups and foreign top-level keys.
  if ( cd "$tmp" && jq -e '.hooks.post_phase.spec_review.stage == 1 and .custom_operator_key == "unchanged"' .planning/config.codex.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} merge preserves other hook groups + foreign top-level key"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} merge clobbered other hook groups or a foreign top-level key"
    FAIL=$((FAIL+1))
  fi

  # The merged block equals the template's block exactly.
  if ( cd "$tmp" && jq -e --argjson pe "$PE" '.hooks.pre_execution.plan_review == $pe.plan_review' .planning/config.codex.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} merged plan_review block equals the template's block"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} merged block diverges from the template"
    FAIL=$((FAIL+1))
  fi

  # Second run is a no-op — byte-identical file (cksum), no duplicate/nested
  # pre_execution. cksum, not sha256sum/md5sum: POSIX, identical on macOS and
  # Linux.
  local cksum_applied cksum_reapplied
  cksum_applied="$(cksum < "$tmp/.planning/config.codex.json")"
  ( cd "$tmp" && jq --argjson pe "$PE" \
      '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
      .planning/config.codex.json > .planning/config.codex.json.tmp \
      && mv .planning/config.codex.json.tmp .planning/config.codex.json )
  cksum_reapplied="$(cksum < "$tmp/.planning/config.codex.json")"

  if [ "$cksum_applied" = "$cksum_reapplied" ]; then
    echo "  ${GREEN}PASS${RESET} second merge run is a no-op (cksum unchanged)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} second merge run changed the file — not idempotent"
    FAIL=$((FAIL+1))
  fi

  if ( cd "$tmp" && jq -e '(.hooks.pre_execution | keys | length) == 2' .planning/config.codex.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} re-apply did not duplicate or nest pre_execution keys (other_gate + plan_review only)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} re-apply duplicated or nested pre_execution keys"
    FAIL=$((FAIL+1))
  fi

  # Rollback removes only OUR leaf (finding 3), asserted against the sibling
  # fixture: from the merged state with other_gate present, plan_review must
  # be gone AND other_gate must survive. del(.hooks.pre_execution) alone would
  # be destructive to the sibling for the same reason the shallow merge was.
  ( cd "$tmp" && jq \
      'del(.hooks.pre_execution.plan_review)
       | if (.hooks.pre_execution // {}) == {} then del(.hooks.pre_execution) else . end' \
      .planning/config.codex.json > .planning/config.codex.json.tmp \
      && mv .planning/config.codex.json.tmp .planning/config.codex.json )

  if ( cd "$tmp" && jq -e '(.hooks.pre_execution.plan_review == null) and (.hooks.pre_execution.other_gate.skill == "some-other-gate")' .planning/config.codex.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} rollback removes only plan_review; sibling other_gate survives"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} rollback was destructive to the sibling gate, or left plan_review behind"
    FAIL=$((FAIL+1))
  fi

  # Rollback drops the now-empty parent when there is NO sibling — a separate
  # fixture, since the one above always has other_gate.
  cat > "$tmp/.planning/config.codex.no-sibling.json" <<'JSON'
{ "hooks": { "post_phase": { "spec_review": { "skill": "codex-spec-review" } } } }
JSON
  ( cd "$tmp" && jq --argjson pe "$PE" \
      '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
      .planning/config.codex.no-sibling.json > .planning/config.codex.no-sibling.json.tmp \
      && mv .planning/config.codex.no-sibling.json.tmp .planning/config.codex.no-sibling.json )
  ( cd "$tmp" && jq \
      'del(.hooks.pre_execution.plan_review)
       | if (.hooks.pre_execution // {}) == {} then del(.hooks.pre_execution) else . end' \
      .planning/config.codex.no-sibling.json > .planning/config.codex.no-sibling.json.tmp \
      && mv .planning/config.codex.no-sibling.json.tmp .planning/config.codex.no-sibling.json )

  if ! ( cd "$tmp" && jq -e '.hooks | has("pre_execution")' .planning/config.codex.no-sibling.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} rollback drops the now-empty pre_execution parent entirely (no sibling case)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} rollback left an empty pre_execution object instead of dropping it"
    FAIL=$((FAIL+1))
  fi

  # ── Step 2 — AGENTS.md ritual section insert ──────────────────────────────
  cat > "$tmp/AGENTS.md" <<'MD'
# AGENTS.md — fixture

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Session handoff

Existing content.

<!-- END: agentic-apps-workflow sections -->
MD

  assert_check "idempotency: AGENTS.md lacks Pre-execution Gate section -> needs insert" \
    "grep -q '^## Pre-execution Gate — Plan Review (spec §02)' AGENTS.md" \
    "$tmp" "not-applied"

  local secfile; secfile="$tmp/section-0008.txt"
  awk '
    /^## Pre-execution Gate — Plan Review \(spec §02\)/ {f=1}
    /^<!-- END: agentic-apps-workflow sections -->/      {f=0}
    f
  ' "$agents_tpl" > "$secfile"

  # Extraction from the REAL template must be non-empty BEFORE the insert is
  # asserted — a heading-regex mismatch would otherwise report as a confusing
  # downstream insert failure instead of "extraction empty" (T-08-23).
  if [ -s "$secfile" ]; then
    echo "  ${GREEN}PASS${RESET} section extraction from the real template is non-empty"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} section extraction from the real template is EMPTY — heading regex drift"
    FAIL=$((FAIL+1))
  fi

  ( cd "$tmp" && awk -v secfile="$secfile" '
      /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
        while ((getline line < secfile) > 0) print line
        ins=1
      }
      { print }
    ' AGENTS.md > AGENTS.md.0008.tmp && mv AGENTS.md.0008.tmp AGENTS.md )

  assert_check "after insert: Pre-execution Gate section present in AGENTS.md" \
    "grep -q '^## Pre-execution Gate — Plan Review (spec §02)' AGENTS.md" \
    "$tmp" "applied"

  # Section landed INSIDE the marker block (heading line number < END marker).
  if awk '/^## Pre-execution Gate — Plan Review \(spec §02\)/{k=NR} /^<!-- END: agentic-apps-workflow sections -->/{e=NR} END{exit !(k>0 && e>0 && k<e)}' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} section sits inside the agentic-apps-workflow marker block"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} section landed outside the marker block"
    FAIL=$((FAIL+1))
  fi

  # Second run is a no-op — cksum-based, not merely a predicate re-check (a
  # predicate re-check would pass even if the second run appended a
  # duplicate section). Guard the re-run by the same idempotency check the
  # real step uses, so this proves the STEP is idempotent, not just the awk.
  local cksum_agents_first cksum_agents_second
  cksum_agents_first="$(cksum < "$tmp/AGENTS.md")"
  if ! grep -q '^## Pre-execution Gate — Plan Review (spec §02)' "$tmp/AGENTS.md"; then
    ( cd "$tmp" && awk -v secfile="$secfile" '
        /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
          while ((getline line < secfile) > 0) print line
          ins=1
        }
        { print }
      ' AGENTS.md > AGENTS.md.0008.tmp && mv AGENTS.md.0008.tmp AGENTS.md )
  fi
  cksum_agents_second="$(cksum < "$tmp/AGENTS.md")"

  if [ "$cksum_agents_first" = "$cksum_agents_second" ]; then
    echo "  ${GREEN}PASS${RESET} second run of Step 2 is a no-op (cksum unchanged)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} second run of Step 2 changed AGENTS.md — not idempotent"
    FAIL=$((FAIL+1))
  fi

  if [ "$(grep -c '^## Pre-execution Gate — Plan Review (spec §02)' "$tmp/AGENTS.md")" = "1" ]; then
    echo "  ${GREEN}PASS${RESET} section appears exactly once after re-run (no duplicate)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} section duplicated after re-run"
    FAIL=$((FAIL+1))
  fi

  # The inserted text is byte-identical to the template's section.
  local extracted_from_agents; extracted_from_agents="$tmp/agents-section-extracted.txt"
  awk '
    /^## Pre-execution Gate — Plan Review \(spec §02\)/ {f=1}
    /^<!-- END: agentic-apps-workflow sections -->/      {f=0}
    f
  ' "$tmp/AGENTS.md" > "$extracted_from_agents"

  if diff -q "$secfile" "$extracted_from_agents" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} inserted text is byte-identical to the template's section"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} inserted text diverges from the template's section"
    FAIL=$((FAIL+1))
  fi

  # ── Step 3 — AGENTS.md bindings-table corrections (D-20, <table_migration>) ──
  # Round 2's top consensus concern (08-REVIEWS.md, Codex + OpenCode, HIGH):
  # an earlier revision applied only the tdd collapse + plan-review add,
  # leaving the template's combined brainstorm row untouched — a migrated
  # install would land at 15 rows / 16 distinct gates while a fresh install
  # is 16/16. Step 3 now applies ALL THREE corrections (split brainstorm,
  # collapse tdd, add plan-review), every row sourced from the same template.

  # Template-shipped invariants that make all three corrections possible:
  # exactly one plan-review row, exactly one tdd row, exactly two brainstorm
  # rows (post-08-04, the template itself is already 16/16 — the source of
  # truth every correction below reads from).
  if [ "$(grep -c '^| plan-review' "$agents_tpl")" = "1" ] \
     && [ "$(grep -c '^| tdd |' "$agents_tpl")" = "1" ] \
     && [ "$(grep -ci '^| brainstorm-' "$agents_tpl")" = "2" ]; then
    echo "  ${GREEN}PASS${RESET} template ships exactly 1 plan-review row, 1 tdd row, 2 brainstorm rows"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} template's table rows are not in the expected 1/1/2 shape"
    FAIL=$((FAIL+1))
  fi

  # The template's table header line must be extractable and non-empty BEFORE
  # asserting anything downstream — a header the migration cannot find makes
  # Step 3 decline on every real target, same discipline as Step 2's
  # extraction-non-empty guard (T-08-23).
  local tpl_header
  tpl_header="$(grep -m1 '^| Gate |' "$agents_tpl")"
  if [ -n "$tpl_header" ]; then
    echo "  ${GREEN}PASS${RESET} template's bindings-table header is extractable and non-empty"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} template's bindings-table header extraction is EMPTY — header regex drift"
    FAIL=$((FAIL+1))
  fi

  # Rows Step 3 needs, extracted from the REAL template — never a heredoc'd
  # literal (D-19). All four corrected rows (2 brainstorm, tdd, plan-review)
  # are sourced from here, never authored inline.
  local row_plan_review row_brainstorm_ui row_brainstorm_arch row_tdd
  row_plan_review="$(grep -m1 '^| plan-review |' "$agents_tpl")"
  row_brainstorm_ui="$(grep -m1 '^| brainstorm-ui |' "$agents_tpl")"
  row_brainstorm_arch="$(grep -m1 '^| brainstorm-architecture |' "$agents_tpl")"
  row_tdd="$(grep -m1 '^| tdd |' "$agents_tpl")"

  # The idempotency-pre fixture is PINNED to the realistic pre-0008 shape a
  # real v0.5.0 install actually has (08-REVIEWS.md round 2, OpenCode,
  # MEDIUM): the Scope-shaped header, 15 data rows, brainstorm COMBINED into
  # one row, TWO tdd rows, no plan-review row. This is a HISTORICAL shape —
  # a heredoc literal is correct here (D-19 governs what the MIGRATION
  # sources, not what a test pins as a past state).
  cat > "$tmp/AGENTS.md.scope-shaped" <<'MD'
| Gate | Bound skill | Scope |
|---|---|---|
| brainstorm-ui / brainstorm-architecture | `superpowers:brainstorming` | pre-phase |
| design-shotgun | `codex-design-shotgun` | pre-phase |
| design-critique | `codex-design-critique` | pre-phase |
| tdd | `superpowers:test-driven-development` | per-task |
| tdd (new TS module) | `codex-ts-declare-first` | per-task |
| ui-preview | `codex-qa` (preview mode) | per-task |
| verification | `superpowers:verification-before-completion` | per-task |
| spec-review | `codex-spec-review` | post-phase |
| code-review | `superpowers:requesting-code-review` | post-phase |
| security | `codex-cso` | post-phase |
| database-security | `codex-database-sentinel-audit` | post-phase |
| qa | `codex-qa` | post-phase |
| impeccable-audit | `codex-impeccable-audit` | post-phase |
| db-pre-launch-audit | `codex-database-sentinel-audit` | finishing |
| branch-close | `superpowers:finishing-a-development-branch` | finishing |
MD

  # Assert the fixture's OWN shape before using it (round 2's consensus
  # concern 3) — 15 data rows, brainstorm combined into exactly one row — so
  # a future edit that quietly "modernises" the fixture into an
  # already-split shape fails HERE, loudly, rather than making the
  # post-condition pass for the wrong reason. A fixture that already matches
  # the new template proves nothing; this guard is what stops one being built.
  local fixture_row_count fixture_brainstorm_count
  fixture_row_count="$(_table_data_rows "$tmp/AGENTS.md.scope-shaped" | grep -c '^|')"
  fixture_brainstorm_count="$(grep -c '^| brainstorm' "$tmp/AGENTS.md.scope-shaped")"
  if [ "$fixture_row_count" = "15" ] && [ "$fixture_brainstorm_count" = "1" ]; then
    echo "  ${GREEN}PASS${RESET} idempotency-pre fixture pinned to the realistic pre-0008 shape (15 rows, brainstorm combined)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} idempotency-pre fixture has rotted away from the realistic pre-0008 shape (rows=$fixture_row_count, brainstorm=$fixture_brainstorm_count)"
    FAIL=$((FAIL+1))
  fi

  assert_check "idempotency: Scope-shaped fixture lacks plan-review row -> needs table corrections" \
    "grep -q '^| plan-review' AGENTS.md.scope-shaped" \
    "$tmp" "not-applied"

  # Apply — all THREE corrections in one pass, every row template-sourced
  # (never a heredoc'd literal for the rows themselves).
  ( cd "$tmp" && awk \
      -v pr="$row_plan_review" \
      -v bui="$row_brainstorm_ui" \
      -v barch="$row_brainstorm_arch" \
      -v tdd="$row_tdd" '
    /^\| Gate \|/ { seen_hdr=1 }
    /^\|---/ && seen_hdr && !ins_pr { print; print pr; ins_pr=1; next }
    /^\| brainstorm-ui \/ brainstorm-architecture \|/ { print bui; print barch; next }
    /^\| tdd \(new TS module\)/ { next }
    /^\| tdd \|/ { print tdd; next }
    { print }
  ' AGENTS.md.scope-shaped > AGENTS.md.scope-shaped.tmp && mv AGENTS.md.scope-shaped.tmp AGENTS.md.scope-shaped )

  # Post-condition: BOTH row count AND distinct-gate count == 16 (OpenCode
  # suggestion 6 — asserting both makes the test self-documenting rather than
  # silently depending on the brainstorm question). Distinct-gate count
  # splits each data row's gate-slug column on "/" — this is what catches a
  # surviving combined row (1 row naming 2 gates: rows < distinct).
  local post_row_count post_gate_count
  post_row_count="$(_table_data_rows "$tmp/AGENTS.md.scope-shaped" | grep -c '^|')"
  post_gate_count="$(_table_data_rows "$tmp/AGENTS.md.scope-shaped" \
    | awk -F'|' '{print $2}' | tr '/' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | sort -u | grep -c .)"

  if [ "$post_row_count" -eq 16 ]; then
    echo "  ${GREEN}PASS${RESET} after Step 3: row count == 16, matching the template's row count"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} after Step 3: row count is $post_row_count, expected 16"
    FAIL=$((FAIL+1))
  fi

  if [ "$post_gate_count" -eq 16 ]; then
    echo "  ${GREEN}PASS${RESET} after Step 3: distinct-gate count == 16 — row count == distinct-gate count"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} after Step 3: distinct-gate count is $post_gate_count, expected 16"
    FAIL=$((FAIL+1))
  fi

  # Exactly one plan-review row, one tdd row, two brainstorm rows survive.
  if [ "$(grep -c '^| plan-review' "$tmp/AGENTS.md.scope-shaped")" = "1" ] \
     && [ "$(grep -c '^| tdd |' "$tmp/AGENTS.md.scope-shaped")" = "1" ] \
     && [ "$(grep -ci '^| brainstorm-' "$tmp/AGENTS.md.scope-shaped")" = "2" ]; then
    echo "  ${GREEN}PASS${RESET} exactly one plan-review row, one tdd row, two brainstorm rows after Step 3"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} row counts after Step 3 are wrong (expected 1 plan-review, 1 tdd, 2 brainstorm)"
    FAIL=$((FAIL+1))
  fi

  # No combined row survives — zero rows match brainstorm.*/.*brainstorm.
  if [ "$(grep -cE 'brainstorm.*/.*brainstorm' "$tmp/AGENTS.md.scope-shaped")" = "0" ]; then
    echo "  ${GREEN}PASS${RESET} no combined brainstorm row survives"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} a combined brainstorm row survived the correction"
    FAIL=$((FAIL+1))
  fi

  # The split brainstorm rows, the inserted plan-review row, and the
  # collapsed tdd row are byte-identical to the template's (D-19) — exact
  # substring match, not a fuzzy check.
  if grep -qF "$row_plan_review" "$tmp/AGENTS.md.scope-shaped" \
     && grep -qF "$row_brainstorm_ui" "$tmp/AGENTS.md.scope-shaped" \
     && grep -qF "$row_brainstorm_arch" "$tmp/AGENTS.md.scope-shaped" \
     && grep -qF "$row_tdd" "$tmp/AGENTS.md.scope-shaped"; then
    echo "  ${GREEN}PASS${RESET} all four corrected rows are byte-identical to the template's"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} a corrected row diverges from the template's byte-for-byte text"
    FAIL=$((FAIL+1))
  fi

  # A migrated fixture and the template's table are row-for-row identical —
  # the assertion that makes must_haves' "same bound state as a fresh
  # install" a test rather than a claim.
  _table_data_rows "$tmp/AGENTS.md.scope-shaped" > "$tmp/scope-shaped-rows.txt"
  _table_data_rows "$agents_tpl" > "$tmp/template-rows.txt"
  if diff -q "$tmp/scope-shaped-rows.txt" "$tmp/template-rows.txt" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} migrated fixture's data rows diff clean against the template's (fresh == migrated)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} migrated fixture's data rows diverge from the template's"
    FAIL=$((FAIL+1))
  fi

  # Unrelated rows survive untouched (the migration does not touch a gate it
  # was not told to).
  if grep -q '^| spec-review ' "$tmp/AGENTS.md.scope-shaped"; then
    echo "  ${GREEN}PASS${RESET} unrelated row (spec-review) survives the table corrections untouched"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} unrelated row (spec-review) was lost or altered"
    FAIL=$((FAIL+1))
  fi

  # Second run is a no-op (cksum) — including the brainstorm split: a second
  # run must not re-split an already-split row, and must not re-add
  # plan-review. A row-count check alone would not distinguish 16-correct
  # from 16-mangled; cksum does.
  local cksum_table_first cksum_table_second
  cksum_table_first="$(cksum < "$tmp/AGENTS.md.scope-shaped")"
  if ! grep -q '^| plan-review' "$tmp/AGENTS.md.scope-shaped"; then
    ( cd "$tmp" && awk \
        -v pr="$row_plan_review" \
        -v bui="$row_brainstorm_ui" \
        -v barch="$row_brainstorm_arch" \
        -v tdd="$row_tdd" '
      /^\| Gate \|/ { seen_hdr=1 }
      /^\|---/ && seen_hdr && !ins_pr { print; print pr; ins_pr=1; next }
      /^\| brainstorm-ui \/ brainstorm-architecture \|/ { print bui; print barch; next }
      /^\| tdd \(new TS module\)/ { next }
      /^\| tdd \|/ { print tdd; next }
      { print }
    ' AGENTS.md.scope-shaped > AGENTS.md.scope-shaped.tmp && mv AGENTS.md.scope-shaped.tmp AGENTS.md.scope-shaped )
  fi
  cksum_table_second="$(cksum < "$tmp/AGENTS.md.scope-shaped")"
  if [ "$cksum_table_first" = "$cksum_table_second" ]; then
    echo "  ${GREEN}PASS${RESET} second run of Step 3 is a no-op (cksum unchanged) — no re-split, no re-add"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} second run of Step 3 changed the file — not idempotent"
    FAIL=$((FAIL+1))
  fi

  # ── The decoy-table fixture (WR-02, 08-REVIEW.md) — proves Step 3's
  # insertion is correlated with the validated '| Gate |' bindings-table
  # header, not with the first '|---' line anywhere in the file. Takes the
  # SAME realistic pre-0008 bindings table the scope-shaped fixture uses and
  # PREPENDS an unrelated Markdown table (its own header + separator) ahead
  # of it, so the file's first '|---' line belongs to the unrelated table.
  cat > "$tmp/AGENTS.md.decoy-table" <<'MD'
# AGENTS.md — decoy-table fixture (WR-02 regression)

## Unrelated Tooling Reference

| Tool | Purpose |
|---|---|
| foo-cli | does foo things |
| bar-cli | does bar things |

## Gate bindings

| Gate | Bound skill | Scope |
|---|---|---|
| brainstorm-ui / brainstorm-architecture | `superpowers:brainstorming` | pre-phase |
| design-shotgun | `codex-design-shotgun` | pre-phase |
| design-critique | `codex-design-critique` | pre-phase |
| tdd | `superpowers:test-driven-development` | per-task |
| tdd (new TS module) | `codex-ts-declare-first` | per-task |
| ui-preview | `codex-qa` (preview mode) | per-task |
| verification | `superpowers:verification-before-completion` | per-task |
| spec-review | `codex-spec-review` | post-phase |
| code-review | `superpowers:requesting-code-review` | post-phase |
| security | `codex-cso` | post-phase |
| database-security | `codex-database-sentinel-audit` | post-phase |
| qa | `codex-qa` | post-phase |
| impeccable-audit | `codex-impeccable-audit` | post-phase |
| db-pre-launch-audit | `codex-database-sentinel-audit` | finishing |
| branch-close | `superpowers:finishing-a-development-branch` | finishing |
MD

  # Self-guard (round 2's consensus rationale, reused): assert the fixture's
  # OWN shape BEFORE trusting the assertions below — the file's first
  # '|---' line must precede the '| Gate |' header, i.e. the decoy really is
  # in front. If a future edit reorders the fixture this guard fails loudly
  # instead of letting the WR-02 assertions pass for the wrong reason.
  local decoy_first_sep_line decoy_gate_hdr_line_pre
  decoy_first_sep_line="$(grep -n '^|---' "$tmp/AGENTS.md.decoy-table" | head -1 | cut -d: -f1)"
  decoy_gate_hdr_line_pre="$(grep -n '^| Gate |' "$tmp/AGENTS.md.decoy-table" | head -1 | cut -d: -f1)"
  if [ -n "$decoy_first_sep_line" ] && [ -n "$decoy_gate_hdr_line_pre" ] \
     && [ "$decoy_first_sep_line" -lt "$decoy_gate_hdr_line_pre" ]; then
    echo "  ${GREEN}PASS${RESET} decoy-table fixture self-guard: first '|---' line ($decoy_first_sep_line) precedes '| Gate |' header ($decoy_gate_hdr_line_pre) — decoy really is in front"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} decoy-table fixture self-guard failed — first '|---' line ($decoy_first_sep_line) does not precede '| Gate |' header ($decoy_gate_hdr_line_pre); fixture has rotted"
    FAIL=$((FAIL+1))
  fi

  # Apply the SAME Step 3 pass (production logic, template-sourced rows) to
  # the decoy-table fixture.
  ( cd "$tmp" && awk \
      -v pr="$row_plan_review" \
      -v bui="$row_brainstorm_ui" \
      -v barch="$row_brainstorm_arch" \
      -v tdd="$row_tdd" '
    /^\| Gate \|/ { seen_hdr=1 }
    /^\|---/ && seen_hdr && !ins_pr { print; print pr; ins_pr=1; next }
    /^\| brainstorm-ui \/ brainstorm-architecture \|/ { print bui; print barch; next }
    /^\| tdd \(new TS module\)/ { next }
    /^\| tdd \|/ { print tdd; next }
    { print }
  ' AGENTS.md.decoy-table > AGENTS.md.decoy-table.tmp && mv AGENTS.md.decoy-table.tmp AGENTS.md.decoy-table )

  # The plan-review row lands in the BINDINGS table, not the decoy: its line
  # number must be GREATER than the '| Gate |' header's. A plain integer
  # comparison, not an awk range one-liner — trivially verifiable by eye.
  local decoy_pr_line decoy_gate_hdr_line_post
  decoy_pr_line="$(grep -n '^| plan-review' "$tmp/AGENTS.md.decoy-table" | head -1 | cut -d: -f1)"
  decoy_gate_hdr_line_post="$(grep -n '^| Gate |' "$tmp/AGENTS.md.decoy-table" | head -1 | cut -d: -f1)"
  if [ -n "$decoy_pr_line" ] && [ -n "$decoy_gate_hdr_line_post" ] \
     && [ "$decoy_pr_line" -gt "$decoy_gate_hdr_line_post" ]; then
    echo "  ${GREEN}PASS${RESET} decoy-table fixture: plan-review row (line $decoy_pr_line) lands AFTER the '| Gate |' header (line $decoy_gate_hdr_line_post) — the bindings table, not the decoy"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} decoy-table fixture: plan-review row (line $decoy_pr_line) did NOT land after the '| Gate |' header (line $decoy_gate_hdr_line_post) — WR-02 (row misinserted into the decoy table)"
    FAIL=$((FAIL+1))
  fi

  # The unrelated table is untouched: zero plan-review lines appear BEFORE
  # the '| Gate |' header.
  local decoy_pr_before_hdr
  decoy_pr_before_hdr="$(sed -n "1,${decoy_gate_hdr_line_post}p" "$tmp/AGENTS.md.decoy-table" 2>/dev/null | grep -c '^| plan-review')"
  if [ "$decoy_pr_before_hdr" = "0" ]; then
    echo "  ${GREEN}PASS${RESET} decoy-table fixture: unrelated table has zero plan-review lines before the '| Gate |' header"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} decoy-table fixture: $decoy_pr_before_hdr plan-review line(s) found before the '| Gate |' header — row landed in the unrelated table"
    FAIL=$((FAIL+1))
  fi

  # The bindings table still reaches 16 rows / 16 distinct gates —
  # _table_data_rows is already scoped to start at the first '| Gate |'
  # line, so it correctly skips the decoy table regardless of where the
  # pass actually inserted the row.
  local decoy_post_row_count decoy_post_gate_count
  decoy_post_row_count="$(_table_data_rows "$tmp/AGENTS.md.decoy-table" | grep -c '^|')"
  decoy_post_gate_count="$(_table_data_rows "$tmp/AGENTS.md.decoy-table" \
    | awk -F'|' '{print $2}' | tr '/' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | sort -u | grep -c .)"
  if [ "$decoy_post_row_count" -eq 16 ] && [ "$decoy_post_gate_count" -eq 16 ]; then
    echo "  ${GREEN}PASS${RESET} decoy-table fixture: bindings table still reaches 16 rows / 16 distinct gates"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} decoy-table fixture: bindings table row/gate count wrong (rows=$decoy_post_row_count, gates=$decoy_post_gate_count, expected 16/16)"
    FAIL=$((FAIL+1))
  fi

  # ── The wrong-shape decline case (T-08-40) — proves the migration DECLINES
  # rather than guesses when it does not recognise the target's table shape.
  # This repo's OWN hand-maintained header (`Applies to scaffolder?`) is
  # exactly the wrong-shape target a downstream install should never have.
  cat > "$tmp/AGENTS.md.wrong-shape" <<'MD'
| Gate | Bound skill | Applies to scaffolder? |
|---|---|---|
| brainstorm-ui / brainstorm-architecture | `superpowers:brainstorming` | No (no UI) |
| tdd | `superpowers:test-driven-development` | Yes (always) |
MD

  local cksum_wrong_before cksum_wrong_after target_header table_step_rc
  cksum_wrong_before="$(cksum < "$tmp/AGENTS.md.wrong-shape")"
  target_header="$(grep -m1 '^| Gate |' "$tmp/AGENTS.md.wrong-shape")"

  table_step_rc=0
  if [ "$target_header" != "$tpl_header" ]; then
    echo "  ${YELLOW}⚠${RESET}  bindings-table header mismatch — declining rather than guessing (would-be precondition failure)"
    table_step_rc=6
  else
    ( cd "$tmp" && awk \
        -v pr="$row_plan_review" \
        -v bui="$row_brainstorm_ui" \
        -v barch="$row_brainstorm_arch" \
        -v tdd="$row_tdd" '
      /^\| Gate \|/ { seen_hdr=1 }
      /^\|---/ && seen_hdr && !ins_pr { print; print pr; ins_pr=1; next }
      /^\| brainstorm-ui \/ brainstorm-architecture \|/ { print bui; print barch; next }
      /^\| tdd \(new TS module\)/ { next }
      /^\| tdd \|/ { print tdd; next }
      { print }
    ' AGENTS.md.wrong-shape > AGENTS.md.wrong-shape.tmp && mv AGENTS.md.wrong-shape.tmp AGENTS.md.wrong-shape )
  fi
  cksum_wrong_after="$(cksum < "$tmp/AGENTS.md.wrong-shape")"

  if [ "$table_step_rc" != "0" ]; then
    echo "  ${GREEN}PASS${RESET} wrong-shape target (Applies to scaffolder? header) declines with a distinct non-zero precondition code"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} wrong-shape target was NOT declined — the migration guessed instead"
    FAIL=$((FAIL+1))
  fi

  if [ "$cksum_wrong_before" = "$cksum_wrong_after" ]; then
    echo "  ${GREEN}PASS${RESET} wrong-shape target left byte-identical (cksum unchanged) — declines rather than mangles"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} wrong-shape target was modified despite the header mismatch"
    FAIL=$((FAIL+1))
  fi

  # The migration DOCUMENT itself must teach Step 3 (bindings-table
  # corrections) and renumber the version-record step to Step 4 — this is
  # the ship-guard assertion that makes this task genuinely RED until Task 2
  # writes it (the assertions above re-implement the same logic inline, per
  # this file's existing Step 1/Step 2 convention, and would pass on their
  # own regardless of the migration document's own content).
  if grep -qE '^### Step 3: .*[Bb]indings.table' "$REPO_ROOT/migrations/0008-plan-review-gate.md" \
     && grep -qE '^### Step 4: Record .0\.6\.0. in .\.codex/workflow-version\.txt.' "$REPO_ROOT/migrations/0008-plan-review-gate.md"; then
    echo "  ${GREEN}PASS${RESET} migrations/0008-plan-review-gate.md documents Step 3 (bindings table) and renumbers the version step to Step 4"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} migrations/0008-plan-review-gate.md does not yet document Step 3 (bindings-table corrections) with Step 4 renumbered"
    FAIL=$((FAIL+1))
  fi

  # ── Step 4 — .codex/workflow-version.txt records 0.6.0 ────────────────────
  printf '0.5.0\n' > "$tmp/.codex/workflow-version.txt"

  assert_check "idempotency: workflow-version.txt reads 0.5.0 -> needs bump" \
    "grep -q '^0.6.0$' .codex/workflow-version.txt" \
    "$tmp" "not-applied"

  ( cd "$tmp" && echo "0.6.0" > .codex/workflow-version.txt )

  assert_check "after Step 4: workflow-version.txt reads 0.6.0" \
    "grep -q '^0.6.0$' .codex/workflow-version.txt" \
    "$tmp" "applied"

  local cksum_ver_first cksum_ver_second
  cksum_ver_first="$(cksum < "$tmp/.codex/workflow-version.txt")"
  if ! grep -q '^0.6.0$' "$tmp/.codex/workflow-version.txt"; then
    ( cd "$tmp" && echo "0.6.0" > .codex/workflow-version.txt )
  fi
  cksum_ver_second="$(cksum < "$tmp/.codex/workflow-version.txt")"
  if [ "$cksum_ver_first" = "$cksum_ver_second" ]; then
    echo "  ${GREEN}PASS${RESET} second run of Step 4 is a no-op (cksum unchanged)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} second run of Step 4 changed the file"
    FAIL=$((FAIL+1))
  fi

  # ── No-scaffolder-tree fixture — the regression guard for round 2's HIGH ──
  # (T-08-38). Shaped like a REAL target project per the setup skill's own
  # post-checks: AGENTS.md marker pair, .planning/config.codex.json,
  # .codex/workflow-version.txt, docs/decisions/. Deliberately NO skills/
  # directory at all — the setup skill never creates a local skills/ tree in
  # a target project, and no step here may stat a path under it.
  local tmp2; tmp2="$(mktemp -d)"
  mkdir -p "$tmp2/.planning" "$tmp2/.codex" "$tmp2/docs/decisions"
  cat > "$tmp2/.planning/config.codex.json" <<'JSON'
{ "hooks": { "post_phase": { "spec_review": { "skill": "codex-spec-review" } } } }
JSON
  cat > "$tmp2/AGENTS.md" <<'MD'
# AGENTS.md — no-scaffolder-tree fixture

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Session handoff

Existing content.

<!-- END: agentic-apps-workflow sections -->
MD
  printf '0.5.0\n' > "$tmp2/.codex/workflow-version.txt"

  if test ! -e "$tmp2/skills"; then
    echo "  ${GREEN}PASS${RESET} no-scaffolder-tree fixture has no local skills/ directory"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} no-scaffolder-tree fixture unexpectedly has a skills/ directory"
    FAIL=$((FAIL+1))
  fi

  # Pre-flight version floor reads the project's OWN record — no skills/ tree
  # needed at all (the divergence from 0007's scaffolder-file floor grep).
  if ( cd "$tmp2" && grep -qE '^0\.(5|6)\.0$' .codex/workflow-version.txt ); then
    echo "  ${GREEN}PASS${RESET} pre-flight version floor passes reading .codex/workflow-version.txt (no skills/ tree needed)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} pre-flight version floor failed"
    FAIL=$((FAIL+1))
  fi

  # Every step's idempotency check runs without error in this sandbox.
  if ( cd "$tmp2" && jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null 2>&1; [ $? -le 1 ] ) \
     && ( cd "$tmp2" && grep -q '^## Pre-execution Gate — Plan Review (spec §02)' AGENTS.md >/dev/null 2>&1; [ $? -le 1 ] ) \
     && ( cd "$tmp2" && grep -q '^0.6.0$' .codex/workflow-version.txt >/dev/null 2>&1; [ $? -le 1 ] ); then
    echo "  ${GREEN}PASS${RESET} every step's idempotency check runs cleanly with no skills/ tree present"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} an idempotency check errored (unexpected exit status) in the no-skills/ sandbox"
    FAIL=$((FAIL+1))
  fi

  # All three steps apply and the migration completes end to end.
  ( cd "$tmp2" && jq --argjson pe "$PE" \
      '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
      .planning/config.codex.json > .planning/config.codex.json.tmp \
      && mv .planning/config.codex.json.tmp .planning/config.codex.json )
  ( cd "$tmp2" && awk -v secfile="$secfile" '
      /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
        while ((getline line < secfile) > 0) print line
        ins=1
      }
      { print }
    ' AGENTS.md > AGENTS.md.0008.tmp && mv AGENTS.md.0008.tmp AGENTS.md )
  ( cd "$tmp2" && echo "0.6.0" > .codex/workflow-version.txt )

  if ( cd "$tmp2" && jq -e '.hooks.pre_execution.plan_review.min_reviewers == 2' .planning/config.codex.json >/dev/null 2>&1 ) \
     && grep -q '^## Pre-execution Gate — Plan Review (spec §02)' "$tmp2/AGENTS.md" \
     && grep -q '^0.6.0$' "$tmp2/.codex/workflow-version.txt"; then
    echo "  ${GREEN}PASS${RESET} no-scaffolder-tree fixture migrates end-to-end (Steps 1, 2, 4 apply; Step 3's table is exercised separately above)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} no-scaffolder-tree fixture failed to complete migration"
    FAIL=$((FAIL+1))
  fi
  rm -rf "$tmp2"

  # ── Partial-application fixture — step-local idempotency (finding 6) ──────
  # Step 1 already applied (plan_review present) but Step 2 is NOT (no ritual
  # heading) -> Steps 2 and 4 must still run (Step 3's table-step recovery is
  # exercised separately above). This is the atomicity contract's documented
  # recovery path (migrations/README.md:103-113); a migration-wide skip keyed
  # on Step 1's artifact would strand the install half-migrated while
  # reporting success. There is no migration-level skip predicate.
  local tmp3; tmp3="$(mktemp -d)"
  mkdir -p "$tmp3/.planning" "$tmp3/.codex"
  jq -n --argjson pe "$PE" '{hooks: {pre_execution: $pe}}' > "$tmp3/.planning/config.codex.json"
  cat > "$tmp3/AGENTS.md" <<'MD'
# AGENTS.md — partial-application fixture

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Session handoff

Existing content.

<!-- END: agentic-apps-workflow sections -->
MD
  printf '0.5.0\n' > "$tmp3/.codex/workflow-version.txt"

  if ( cd "$tmp3" && jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} partial fixture set up correctly: Step 1 already applied"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} partial fixture setup wrong: Step 1 not pre-applied"
    FAIL=$((FAIL+1))
  fi
  if ! ( cd "$tmp3" && grep -q '^## Pre-execution Gate — Plan Review (spec §02)' AGENTS.md 2>/dev/null ); then
    echo "  ${GREEN}PASS${RESET} partial fixture set up correctly: Step 2 NOT yet applied"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} partial fixture setup wrong: Step 2 already applied"
    FAIL=$((FAIL+1))
  fi

  # Re-run the migration's step set — each step checks its OWN idempotency,
  # none gates on another. Steps 2 and 4 must still complete.
  if ! ( cd "$tmp3" && jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null 2>&1 ); then
    ( cd "$tmp3" && jq --argjson pe "$PE" \
        '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
        .planning/config.codex.json > .planning/config.codex.json.tmp \
        && mv .planning/config.codex.json.tmp .planning/config.codex.json )
  fi
  if ! ( cd "$tmp3" && grep -q '^## Pre-execution Gate — Plan Review (spec §02)' AGENTS.md 2>/dev/null ); then
    ( cd "$tmp3" && awk -v secfile="$secfile" '
        /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
          while ((getline line < secfile) > 0) print line
          ins=1
        }
        { print }
      ' AGENTS.md > AGENTS.md.0008.tmp && mv AGENTS.md.0008.tmp AGENTS.md )
  fi
  if ! ( cd "$tmp3" && grep -q '^0.6.0$' .codex/workflow-version.txt 2>/dev/null ); then
    ( cd "$tmp3" && echo "0.6.0" > .codex/workflow-version.txt )
  fi

  if grep -q '^## Pre-execution Gate — Plan Review (spec §02)' "$tmp3/AGENTS.md" \
     && grep -q '^0.6.0$' "$tmp3/.codex/workflow-version.txt"; then
    echo "  ${GREEN}PASS${RESET} partial-application recovery: Steps 2 and 4 still ran to completion (already applied not gating them)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} partial-application recovery failed — a step was skipped by a whole-migration predicate"
    FAIL=$((FAIL+1))
  fi
  rm -rf "$tmp3"

  # Inverse: Step 2 applied (heading present), Step 1 NOT -> Step 1 still runs.
  local tmp4; tmp4="$(mktemp -d)"
  mkdir -p "$tmp4/.planning" "$tmp4/.codex"
  echo '{"hooks":{"post_phase":{"spec_review":{"skill":"codex-spec-review"}}}}' > "$tmp4/.planning/config.codex.json"
  cat > "$tmp4/AGENTS.md" <<'MD'
# AGENTS.md — inverse partial fixture

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Session handoff

Existing content.

<!-- END: agentic-apps-workflow sections -->
MD
  ( cd "$tmp4" && awk -v secfile="$secfile" '
      /^<!-- END: agentic-apps-workflow sections -->/ && !ins {
        while ((getline line < secfile) > 0) print line
        ins=1
      }
      { print }
    ' AGENTS.md > AGENTS.md.0008.tmp && mv AGENTS.md.0008.tmp AGENTS.md )
  printf '0.5.0\n' > "$tmp4/.codex/workflow-version.txt"

  if ! ( cd "$tmp4" && jq -e '.hooks.pre_execution.plan_review' .planning/config.codex.json >/dev/null 2>&1 ); then
    ( cd "$tmp4" && jq --argjson pe "$PE" \
        '.hooks.pre_execution = ((.hooks.pre_execution // {}) + $pe)' \
        .planning/config.codex.json > .planning/config.codex.json.tmp \
        && mv .planning/config.codex.json.tmp .planning/config.codex.json )
  fi

  if ( cd "$tmp4" && jq -e '.hooks.pre_execution.plan_review.min_reviewers == 2' .planning/config.codex.json >/dev/null 2>&1 ); then
    echo "  ${GREEN}PASS${RESET} inverse partial-application: Step 1 still ran when only Step 2 was pre-applied"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} inverse partial-application: Step 1 was skipped"
    FAIL=$((FAIL+1))
  fi
  rm -rf "$tmp4"

  # Ship guards.
  if [ -f "$REPO_ROOT/migrations/0008-plan-review-gate.md" ]; then
    echo "  ${GREEN}PASS${RESET} migrations/0008-plan-review-gate.md ships"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} migrations/0008-plan-review-gate.md MISSING"
    FAIL=$((FAIL+1))
  fi

  if [ -f "$REPO_ROOT/docs/decisions/0009-plan-review-gate.md" ]; then
    echo "  ${GREEN}PASS${RESET} ADR-0009 (plan-review gate) ships"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} ADR-0009 missing"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# MIGR-08 — mutation-proven execution coverage for 0008 Step 4's version write
# (v0.8.0 Enforcement, Not Intention; 11-CONTEXT.md D-05).
#
# test_migration_0008 above builds its own `.codex/workflow-version.txt =
# 0.6.0` sandboxes by hand-writing `echo "0.6.0" > ...` directly into the test
# (e.g. ~line 1631) -- an assertion that CANNOT fail, exactly the "can't-fail-
# assertion" class Phase 9.1 existed to close, and 09-VERIFICATION.md flagged
# this specific gap as the one residual instance still open.
#
# This fixture instead:
#   1. Extracts 0008's REAL Step 4 Apply block via extract_step_block (never a
#      hand-copied transcription) -- gated by assert_extracted_shape (D-36):
#      a silently-empty extraction FAILs loudly rather than vacuously passing.
#   2. Executes the extracted block, cd-isolated, against a sandbox whose
#      .codex/workflow-version.txt is seeded at 0.5.0 -- the pre-migration
#      value (D-05) -- with no local skills/ tree (matches a real target
#      project's shape, not this repo's own scaffolder shape).
#   3. Asserts EXACT post-execution content equality against `0.6.0` via cmp,
#      never grep -q -- a substring match would spuriously pass on any file
#      merely containing "0.6.0" (e.g. "10.6.0" or trailing garbage).
#
# Mutation-proven (D-05): 0008's `echo "0.6.0" > .codex/workflow-version.txt`
# write line was temporarily commented out, this fixture re-run and observed
# RED (the cmp equality assertion fails -- the file stays at the seeded
# 0.5.0), then the line was restored and re-run to observe GREEN. See
# 11-02-SUMMARY.md for the verbatim transcript. 0008 itself is immutable and
# ships unmodified -- only extract_step_block (above) was extended to also
# recognize 0008's inline-code-span Apply shape.
# ─────────────────────────────────────────────────────────────────────────────
test_migration_0008_step4_write() {
  echo ""
  echo "${YELLOW}=== MIGR-08 — 0008 Step 4 write, extracted + executed + exact-asserted ===${RESET}"

  local MIGRATION_0008="$REPO_ROOT/migrations/0008-plan-review-gate.md"

  local step4_apply
  step4_apply="$(extract_step_block "$MIGRATION_0008" 4 Apply 2>/dev/null)"

  if ! assert_extracted_shape "0008 Step 4 Apply" "$step4_apply" '.codex/workflow-version.txt'; then
    echo "  ${RED}FAIL${RESET} 0008 Step 4 Apply executes cleanly against the 0.5.0-seeded sandbox — NOT ASSERTED: extraction failed"
    FAIL=$((FAIL+1))
    echo "  ${RED}FAIL${RESET} 0008 Step 4: .codex/workflow-version.txt reads exactly 0.6.0 after Apply (cmp) — NOT ASSERTED: extraction failed"
    FAIL=$((FAIL+1))
    return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # No-scaffolder-tree shape (D-07 discipline applied here too): a real
  # target project has no local skills/ tree.
  mkdir -p "$tmp/.codex"
  printf '0.5.0\n' > "$tmp/.codex/workflow-version.txt"

  if test ! -e "$tmp/skills"; then
    echo "  ${GREEN}PASS${RESET} 0008 Step 4 sandbox has no local skills/ directory"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 0008 Step 4 sandbox unexpectedly has a skills/ directory"
    FAIL=$((FAIL+1))
  fi

  # Pre-state: the Step 4 idempotency check must be not-applied against the
  # seeded 0.5.0 value -- proves this is genuinely a pre-migration sandbox,
  # not one that manufactured the postcondition under test.
  assert_check "0008 Step 4 idempotency check is not-applied against the 0.5.0-seeded pre-state" \
    "grep -q '^0.6.0\$' .codex/workflow-version.txt" \
    "$tmp" "not-applied"

  # Execute the EXTRACTED block -- not a transcription -- cd-isolated inside
  # the sandbox.
  ( cd "$tmp" && eval "$step4_apply" ) >/dev/null 2>&1

  # Post-state: EXACT content equality against `0.6.0` via cmp, never grep -q
  # (D-05).
  local ref; ref="$(mktemp)"
  printf '0.6.0\n' > "$ref"
  if cmp -s "$tmp/.codex/workflow-version.txt" "$ref" 2>/dev/null; then
    echo "  ${GREEN}PASS${RESET} 0008 Step 4: .codex/workflow-version.txt reads EXACTLY 0.6.0 after the extracted Apply (cmp, not grep -q)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} 0008 Step 4: .codex/workflow-version.txt does NOT read exactly 0.6.0 after the extracted Apply"
    echo "         got: $(cat "$tmp/.codex/workflow-version.txt" 2>/dev/null || echo '<missing>')"
    FAIL=$((FAIL+1))
  fi
  rm -f "$ref"
}

# ─────────────────────────────────────────────────────────────────────────────
# check-plan-review.sh — resolver + grandfather test suite (phase 08, plan 01)
#
# Verifier CLI contract: skills/agentic-apps-workflow/scripts/check-plan-review.sh
#   Exit 0 = ALLOW, exit 2 = BLOCK (08-02 owns the block path; this plan only
#   exercises allow paths). GSD_PLAN_REVIEW_DEBUG=1 makes it print
#   `repo-root: <dir>` and `resolved-phase: <dir>` to stderr without changing
#   the exit code — the assertion surface for resolution order and for the
#   ambiguity contract's load-bearing "no resolution happened" proof.
#
# `_cpr_case` is the ONE pinned invocation helper (08-01-PLAN.md <action>):
# captures the verifier's exit status on the line immediately after invoking
# it, no intervening `local`/color/`set` toggle. Its stderr-exposure shape is
# an out-path argument (`--err-out <path>`) defaulting to a per-call mktemp
# that is cleaned up automatically. Plan 08-02 reuses this same helper.
# ─────────────────────────────────────────────────────────────────────────────

_cpr_case() {
  local label sandbox expected rc err own_err
  label="${1:-}"; sandbox="${2:-}"; expected="${3:-}"; shift 3
  err=""
  own_err=0
  if [ "${1:-}" = "--err-out" ]; then
    err="${2:-}"; shift 2
  fi
  [ "${1:-}" = "--" ] && shift
  if [ -z "$err" ]; then
    err="$(mktemp)"
    own_err=1
  fi
  ( cd "$sandbox" && bash "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" "$@" ) >/dev/null 2>"$err"
  rc=$?
  if [ "$rc" = "$expected" ]; then
    echo "  ${GREEN}PASS${RESET} $label (exit=$rc)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $label (expected exit=$expected, got exit=$rc)"
    FAIL=$((FAIL+1))
  fi
  if [ "$own_err" = "1" ]; then
    rm -f "$err"
  fi
}

# Assert an already-captured stderr file's `resolved-phase:` line matches a
# substring. Read-only on the capture — never re-invokes the verifier.
_cpr_check_resolved() {
  local label errfile expected_substr
  label="${1:-}"; errfile="${2:-}"; expected_substr="${3:-}"
  if grep -q "resolved-phase:.*${expected_substr}" "$errfile" 2>/dev/null; then
    echo "  ${GREEN}PASS${RESET} $label"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $label"
    FAIL=$((FAIL+1))
  fi
}

# Assert an already-captured stderr file contains a literal needle.
_cpr_check_contains() {
  local label errfile needle
  label="${1:-}"; errfile="${2:-}"; needle="${3:-}"
  if grep -qF -- "$needle" "$errfile" 2>/dev/null; then
    echo "  ${GREEN}PASS${RESET} $label"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $label"
    FAIL=$((FAIL+1))
  fi
}

# Compound assertion for the tri-state ambiguity contract and the path-safety
# escape cases: exit code must equal expected AND a literal needle must be
# ABSENT from stderr (captured with debug on). Folding both checks into one
# PASS/FAIL avoids a false PASS during RED — an absence-only check would
# spuriously pass when the verifier doesn't exist yet and prints nothing at
# all (08-REVIEWS.md round 2, Codex, HIGH: the ambiguity contract's absence
# assertion must be load-bearing, not just "nothing was printed").
_cpr_case_and_absent() {
  local label sandbox expected needle err rc
  label="${1:-}"; sandbox="${2:-}"; expected="${3:-}"; needle="${4:-}"
  err="$(mktemp)"
  ( cd "$sandbox" && GSD_PLAN_REVIEW_DEBUG=1 bash "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" ) >/dev/null 2>"$err"
  rc=$?
  if [ "$rc" = "$expected" ] && ! grep -qF -- "$needle" "$err"; then
    echo "  ${GREEN}PASS${RESET} $label"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $label (rc=$rc)"
    FAIL=$((FAIL+1))
  fi
  rm -f "$err"
}

test_check_plan_review_resolver() {
  echo ""
  echo "${YELLOW}=== check-plan-review.sh — resolver + grandfather (phase 08-01) ===${RESET}"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp" "${tmp}-escape"' RETURN
  mkdir -p "$tmp/.planning"

  local errdir; errdir="$tmp/err"
  mkdir -p "$errdir"

  local s e r1 r2 r3 e1 e2 e3 escdir

  # ── Repo-root location (<root_location>; T-08-28) ──────────────────────────

  if command -v git >/dev/null 2>&1; then
    s="$tmp/rootloc-git"
    mkdir -p "$s/.planning/phases/08-rootcase"
    touch "$s/.planning/phases/08-rootcase/08-01-PLAN.md"
    # *-SUMMARY.md (08-01's own grandfather guard) keeps this resolution-only
    # fixture allowed once 08-02's REVIEWS.md enforcement lands -- this case
    # tests root-location, not the REVIEWS check.
    touch "$s/.planning/phases/08-rootcase/08-01-SUMMARY.md"
    cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (Root location test) - DOING
EOF
    ( cd "$s" && git init -q )
    mkdir -p "$s/src"

    e1="$errdir/rootloc-root.err"
    GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "root-location: git repo, invoked from sandbox root" "$s" 0 --err-out "$e1"
    e2="$errdir/rootloc-nested.err"
    GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "root-location: git repo, invoked from a nested subdirectory (src/)" "$s/src" 0 --err-out "$e2"

    r1="$(grep 'resolved-phase:' "$e1")"; r2="$(grep 'resolved-phase:' "$e2")"
    if [ -n "$r1" ] && [ "$r1" = "$r2" ]; then
      echo "  ${GREEN}PASS${RESET} root-location: nested subdirectory resolves the SAME phase as root (T-08-28 regression guard)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} root-location: nested subdirectory diverged from root resolution"
      FAIL=$((FAIL+1))
    fi
  else
    echo "  ${YELLOW}SKIP${RESET} git not available — root-location git-repo cases not run"
    SKIP=$((SKIP+1))
  fi

  # Non-git ancestor walk: same-phase resolution from root and from a nested
  # subdirectory when the sandbox is NOT a git tree at all.
  s="$tmp/rootloc-nogit"
  mkdir -p "$s/.planning/phases/08-rootcase2" "$s/src"
  touch "$s/.planning/phases/08-rootcase2/08-01-PLAN.md"
  touch "$s/.planning/phases/08-rootcase2/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (Root location test, non-git) - DOING
EOF
  e1="$errdir/rootloc-nogit-root.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "root-location: non-git tree, invoked from sandbox root" "$s" 0 --err-out "$e1"
  e2="$errdir/rootloc-nogit-nested.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "root-location: non-git tree, invoked from a nested subdirectory (src/)" "$s/src" 0 --err-out "$e2"
  r1="$(grep 'resolved-phase:' "$e1")"; r2="$(grep 'resolved-phase:' "$e2")"
  if [ -n "$r1" ] && [ "$r1" = "$r2" ]; then
    echo "  ${GREEN}PASS${RESET} root-location: non-git ancestor .planning walk resolves the same phase from a nested dir"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} root-location: non-git ancestor walk diverged"
    FAIL=$((FAIL+1))
  fi

  # No .planning/ in any ancestor and not a git tree -> fail open.
  s="$tmp/rootloc-none"
  mkdir -p "$s"
  _cpr_case "root-location: no .planning/ anywhere, not a git tree -> fail open" "$s" 0

  # ── Resolution order (D-05) ─────────────────────────────────────────────────

  # Step 1a: explicit pointer, absolute path.
  s="$tmp/step1a"
  mkdir -p "$s/.planning/phases/08-pointer-abs"
  touch "$s/.planning/phases/08-pointer-abs/08-01-PLAN.md"
  touch "$s/.planning/phases/08-pointer-abs/08-01-SUMMARY.md"
  ln -s "$s/.planning/phases/08-pointer-abs" "$s/.planning/current-phase"
  e="$errdir/step1a.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 1a — absolute pointer wins" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 1a resolves 08-pointer-abs" "$e" "08-pointer-abs"

  # Step 1b: explicit pointer, .planning/-relative value.
  s="$tmp/step1b"
  mkdir -p "$s/.planning/phases/08-pointer-rel"
  touch "$s/.planning/phases/08-pointer-rel/08-01-PLAN.md"
  touch "$s/.planning/phases/08-pointer-rel/08-01-SUMMARY.md"
  ( cd "$s/.planning" && ln -s "phases/08-pointer-rel" current-phase )
  e="$errdir/step1b.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 1b — .planning-relative pointer wins" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 1b resolves 08-pointer-rel" "$e" "08-pointer-rel"

  # Step 2: STATE.md, canonical '## Current Position' heading.
  s="$tmp/step2a"
  mkdir -p "$s/.planning/phases/08-state-basic"
  touch "$s/.planning/phases/08-state-basic/08-01-PLAN.md"
  touch "$s/.planning/phases/08-state-basic/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (State basic) - DOING
EOF
  e="$errdir/step2a.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 2 — '## Current Position' + 'Phase: 08'" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 2 resolves 08-state-basic" "$e" "08-state-basic"

  # Step 2, D-06 tolerated fallback heading '## Current Phase'.
  s="$tmp/step2b"
  mkdir -p "$s/.planning/phases/08-heading-fallback"
  touch "$s/.planning/phases/08-heading-fallback/08-01-PLAN.md"
  touch "$s/.planning/phases/08-heading-fallback/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Phase

Phase: 08 (Heading fallback) - DOING
EOF
  e="$errdir/step2b.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 2 — D-06 '## Current Phase' heading fallback" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 2 heading fallback resolves 08-heading-fallback" "$e" "08-heading-fallback"

  # Step 2, zero-pad a single-digit integer phase.
  s="$tmp/step2c"
  mkdir -p "$s/.planning/phases/08-zeropad"
  touch "$s/.planning/phases/08-zeropad/08-01-PLAN.md"
  touch "$s/.planning/phases/08-zeropad/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 8 (Zero pad) - DOING
EOF
  e="$errdir/step2c.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 2 — 'Phase: 8' zero-pads to 08-*" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 2 zero-pad resolves 08-zeropad" "$e" "08-zeropad"

  # Step 2, third resolver defect regression: canonical 'Phase:' line wins over
  # a later prose decoy naming a different phase, in the SAME section.
  s="$tmp/step2d"
  mkdir -p "$s/.planning/phases/08-prose-decoy"
  touch "$s/.planning/phases/08-prose-decoy/08-01-PLAN.md"
  touch "$s/.planning/phases/08-prose-decoy/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (Prose decoy) - DOING
Last activity: phase 03 shipped last week; unrelated prose mention.
EOF
  e="$errdir/step2d.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 2 — canonical 'Phase:' line wins over a prose decoy" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: prose-decoy case resolves 08, not the decoy's 03" "$e" "08-prose-decoy"

  # Step 3: newest *-PLAN.md by mtime, no pointer, no STATE.md.
  s="$tmp/step3"
  mkdir -p "$s/.planning/phases/08-older" "$s/.planning/phases/09-newer"
  touch -t 202501010000 "$s/.planning/phases/08-older/08-01-PLAN.md"
  touch -t 202601010000 "$s/.planning/phases/09-newer/09-01-PLAN.md"
  touch "$s/.planning/phases/09-newer/09-01-SUMMARY.md"
  e="$errdir/step3.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 3 — newest *-PLAN.md by mtime wins" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 3 resolves the newer dir (09-newer)" "$e" "09-newer"

  # Step 4: fail-open, .planning/ exists but is empty.
  s="$tmp/step4-empty"
  mkdir -p "$s/.planning/phases"
  _cpr_case "resolution: step 4 — .planning/ exists but empty -> fail open" "$s" 0

  # Step 4: fail-open, no .planning/ at all (D-05's own explicit case).
  s="$tmp/step4-none"
  mkdir -p "$s"
  _cpr_case "resolution: step 4 — no .planning/ at all -> fail open" "$s" 0

  # Precedence: pointer -> A, STATE.md -> B, newest plan -> C, all present and
  # each holding an unreviewed *-PLAN.md -> the pointer's A wins.
  s="$tmp/precedence"
  mkdir -p "$s/.planning/phases/08-pointer-wins" "$s/.planning/phases/08-state-loser" "$s/.planning/phases/09-newest-loser"
  touch "$s/.planning/phases/08-pointer-wins/08-01-PLAN.md"
  touch "$s/.planning/phases/08-pointer-wins/08-01-SUMMARY.md"
  touch "$s/.planning/phases/08-state-loser/08-01-PLAN.md"
  touch -t 202601010000 "$s/.planning/phases/09-newest-loser/09-01-PLAN.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (State loser) - DOING
EOF
  ln -s "$s/.planning/phases/08-pointer-wins" "$s/.planning/current-phase"
  e="$errdir/precedence.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: precedence — pointer wins over STATE.md and newest-plan" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: precedence resolves via pointer (08-pointer-wins)" "$e" "08-pointer-wins"

  # ── Decimal phases (<resolver_defects> item 5) ──────────────────────────────

  s="$tmp/dec1"
  mkdir -p "$s/.planning/phases/08.1-inserted"
  touch "$s/.planning/phases/08.1-inserted/08.1-01-PLAN.md"
  touch "$s/.planning/phases/08.1-inserted/08.1-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 8.1 (Inserted) - DOING
EOF
  e="$errdir/dec1.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: decimal — 'Phase: 8.1' zero-pads integer part to 08.1-*" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: decimal 8.1 resolves 08.1-inserted" "$e" "08.1-inserted"

  s="$tmp/dec2"
  mkdir -p "$s/.planning/phases/08.1-inserted"
  touch "$s/.planning/phases/08.1-inserted/08.1-01-PLAN.md"
  touch "$s/.planning/phases/08.1-inserted/08.1-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08.1 (Inserted, already padded) - DOING
EOF
  e="$errdir/dec2.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: decimal — 'Phase: 08.1' (already padded) resolves directly" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: decimal 08.1 resolves 08.1-inserted" "$e" "08.1-inserted"

  s="$tmp/dec3"
  mkdir -p "$s/.planning/phases/12.3-x"
  touch "$s/.planning/phases/12.3-x/12.3-01-PLAN.md"
  touch "$s/.planning/phases/12.3-x/12.3-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 12.3 (No pad needed) - DOING
EOF
  e="$errdir/dec3.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: decimal — 'Phase: 12.3' needs no padding (integer part already 2 digits)" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: decimal 12.3 resolves 12.3-x" "$e" "12.3-x"

  s="$tmp/dec4"
  mkdir -p "$s/.planning/phases"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 8.1 (No matching dir) - DOING
EOF
  _cpr_case_and_absent "resolution: decimal — 'Phase: 8.1' with no matching dir falls through to fail-open, never matches 08-*" "$s" 0 "resolved-phase:"

  # ── STATE.md section bounding (<resolver_defects> item 4) ───────────────────

  s="$tmp/sec1"
  mkdir -p "$s/.planning/phases/08-bound-good"
  touch "$s/.planning/phases/08-bound-good/08-01-PLAN.md"
  touch "$s/.planning/phases/08-bound-good/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (Bounded) - DOING

## Notes

Phase: 03 (unrelated prose in a later section, must not win)
EOF
  e="$errdir/sec1.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: STATE.md section bounding — later '## Notes' Phase: does not override Current Position" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: section-bounded parse resolves 08-bound-good, not 03" "$e" "08-bound-good"

  s="$tmp/sec2"
  mkdir -p "$s/.planning/phases/03-decoy" "$s/.planning/phases/08-step3-winner"
  touch -t 202501010000 "$s/.planning/phases/03-decoy/03-PLAN.md"
  touch -t 202601010000 "$s/.planning/phases/08-step3-winner/08-01-PLAN.md"
  touch "$s/.planning/phases/08-step3-winner/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Status: Ready to execute (no Phase: line in this section)

## Notes

Phase: 03 (must not be picked up from a later section)
EOF
  e="$errdir/sec2.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: STATE.md section bounding — no Phase: in Current Position falls through past Notes to step 3" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: falls through to step 3, resolves 08-step3-winner not 03-decoy" "$e" "08-step3-winner"

  # ── Ambiguity — TERMINAL fail-open (<resolver_defects> item 6; T-08-01) ────

  s="$tmp/ambiguous"
  mkdir -p "$s/.planning/phases/08-old" "$s/.planning/phases/08-plan-review-gate"
  touch "$s/.planning/phases/08-old/08-01-PLAN.md"
  touch "$s/.planning/phases/08-plan-review-gate/08-01-PLAN.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (Ambiguous) - DOING
EOF
  e="$errdir/amb-nodebug.err"
  _cpr_case "ambiguity: two 08-* dirs -> allow (fail-open), no GSD_PLAN_REVIEW_DEBUG set" "$s" 0 --err-out "$e"
  _cpr_check_contains "ambiguity: diagnostic unconditionally names 08-old" "$e" "08-old"
  _cpr_check_contains "ambiguity: diagnostic unconditionally names 08-plan-review-gate" "$e" "08-plan-review-gate"

  # Load-bearing: WITH debug set, NO resolved-phase: line at all — proves
  # resolution was terminal, not merely that the outcome happened to allow.
  _cpr_case_and_absent "ambiguity: WITH GSD_PLAN_REVIEW_DEBUG=1, resolution is terminal (no resolved-phase: line)" "$s" 0 "resolved-phase:"

  # Ambiguity must not fall through to step 3 even when a third, unambiguous,
  # newer-by-mtime phase dir exists.
  s="$tmp/ambiguous-fallthrough"
  mkdir -p "$s/.planning/phases/08-old" "$s/.planning/phases/08-plan-review-gate" "$s/.planning/phases/09-later"
  touch "$s/.planning/phases/08-old/08-01-PLAN.md"
  touch "$s/.planning/phases/08-plan-review-gate/08-01-PLAN.md"
  touch -t 202601010000 "$s/.planning/phases/09-later/09-01-PLAN.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (Ambiguous with fallthrough temptation) - DOING
EOF
  _cpr_case_and_absent "ambiguity: does not fall through to step 3 despite a newer unambiguous 09-later dir" "$s" 0 "resolved-phase:"

  # Absent (status 1) vs ambiguous (status 2) are distinct: an unmatched
  # phase number is ABSENT, not ambiguous, so resolution continues to step 3.
  s="$tmp/absent-vs-amb"
  mkdir -p "$s/.planning/phases/08-x"
  touch "$s/.planning/phases/08-x/08-01-PLAN.md"
  touch "$s/.planning/phases/08-x/08-01-SUMMARY.md"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 42 (No matching directory exists) - DOING
EOF
  e="$errdir/absent-vs-amb.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: absent (status 1) is distinct from ambiguous (status 2) — Phase: 42 has no dir, continues to step 3" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 2 absent falls through, step 3 resolves 08-x" "$e" "08-x"

  # ── Newest-plan determinism (<resolver_defects> item 7) ─────────────────────

  s="$tmp/mtime-eq"
  mkdir -p "$s/.planning/phases/08-eq-a" "$s/.planning/phases/08-eq-b"
  touch -t 202601010000 "$s/.planning/phases/08-eq-a/08-01-PLAN.md" "$s/.planning/phases/08-eq-b/08-01-PLAN.md"
  touch "$s/.planning/phases/08-eq-a/08-01-SUMMARY.md" "$s/.planning/phases/08-eq-b/08-01-SUMMARY.md"
  e1="$errdir/mtime-eq-1.err"; e2="$errdir/mtime-eq-2.err"; e3="$errdir/mtime-eq-3.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: mtime tie-break — invocation 1 of 3" "$s" 0 --err-out "$e1"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: mtime tie-break — invocation 2 of 3" "$s" 0 --err-out "$e2"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: mtime tie-break — invocation 3 of 3" "$s" 0 --err-out "$e3"
  r1="$(grep 'resolved-phase:' "$e1")"; r2="$(grep 'resolved-phase:' "$e2")"; r3="$(grep 'resolved-phase:' "$e3")"
  if [ -n "$r1" ] && [ "$r1" = "$r2" ] && [ "$r2" = "$r3" ]; then
    echo "  ${GREEN}PASS${RESET} resolution: equal-mtime tie-break is deterministic across 3 consecutive invocations"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} resolution: equal-mtime tie-break was NOT stable across invocations"
    FAIL=$((FAIL+1))
  fi

  # Empty input: directories exist but zero *-PLAN.md anywhere.
  s="$tmp/mtime-empty"
  mkdir -p "$s/.planning/phases/08-nofiles/sub"
  _cpr_case_and_absent "resolution: step 3 — zero *-PLAN.md anywhere -> fail open, no 'operand' error leaked" "$s" 0 "operand"

  # ── Grandfather guards (D-08/D-09) ──────────────────────────────────────────

  s="$tmp/legacy"
  mkdir -p "$s/.planning/phases/03"
  cat > "$s/.planning/phases/03/PLAN.md" <<'EOF'
# Legacy bare-number phase plan (pre-GSD)
EOF
  ln -s "$s/.planning/phases/03" "$s/.planning/current-phase"
  _cpr_case "grandfather: legacy bare-number layout (phases/03/PLAN.md) resolved via pointer -> allow" "$s" 0

  s="$tmp/summary-present"
  mkdir -p "$s/.planning/phases/08-shipped"
  touch "$s/.planning/phases/08-shipped/08-01-PLAN.md"
  touch "$s/.planning/phases/08-shipped/08-01-SUMMARY.md"
  ln -s "$s/.planning/phases/08-shipped" "$s/.planning/current-phase"
  _cpr_case "grandfather: *-SUMMARY.md present alongside *-PLAN.md -> allow (already shipped)" "$s" 0

  s="$tmp/no-plan"
  mkdir -p "$s/.planning/phases/08-unplanned"
  ln -s "$s/.planning/phases/08-unplanned" "$s/.planning/current-phase"
  _cpr_case "grandfather: no *-PLAN.md at all in resolved phase -> allow" "$s" 0

  # ── Path safety (threat T-08-01) ─────────────────────────────────────────────

  s="$tmp/escape-sibling"
  mkdir -p "$s/.planning/phases" "$s/scratch-outside"
  touch "$s/scratch-outside/PLAN.md"
  ln -s "$s/scratch-outside" "$s/.planning/current-phase"
  _cpr_case_and_absent "path-safety: pointer to a sibling dir OUTSIDE .planning/phases is rejected, falls through" "$s" 0 "scratch-outside"

  escdir="${tmp}-escape"
  mkdir -p "$escdir"
  touch "$escdir/PLAN.md"
  s="$tmp/escape-tmp"
  mkdir -p "$s/.planning/phases"
  ln -s "$escdir" "$s/.planning/current-phase"
  _cpr_case_and_absent "path-safety: pointer to a /tmp-rooted escape target (derived from sandbox mktemp) is rejected" "$s" 0 "$escdir"

  s="$tmp/escape-traversal"
  mkdir -p "$s/.planning/phases"
  ( cd "$s/.planning" && ln -s "phases/../../../tmp" current-phase )
  _cpr_case "path-safety: '..'-traversal pointer value is rejected, falls through to fail-open" "$s" 0
}

# ─────────────────────────────────────────────────────────────────────────────
# check-plan-review.sh — enforcement + block path suite (phase 08, plan 02)
#
# Builds on the resolver suite above and reuses its pinned `_cpr_case` /
# `_cpr_check_contains` helpers exactly (08-01's <action>: do not write a
# second sandbox+exit-code helper). Every case builds a sandbox whose
# resolved phase holds an unreviewed *-PLAN.md (the block candidate) unless
# the case says otherwise.
# ─────────────────────────────────────────────────────────────────────────────

# _cpr_enf_phase <sandbox-root> <phase-dir-name> [plan-basename ...]
# Creates .planning/phases/<name>/ with one *-PLAN.md per basename argument
# (default: a single 08-01-PLAN.md), points .planning/current-phase at it via
# a .planning/-relative symlink (mirrors the resolver suite's own idiom), and
# echoes the phase dir path.
_cpr_enf_phase() {
  local root="$1" name="$2" phasedir p
  shift 2
  phasedir="$root/.planning/phases/$name"
  mkdir -p "$phasedir"
  if [ "$#" -eq 0 ]; then
    touch "$phasedir/08-01-PLAN.md"
  else
    for p in "$@"; do
      touch "$phasedir/$p"
    done
  fi
  ( cd "$root/.planning" && ln -sf "phases/$name" current-phase )
  echo "$phasedir"
}

test_check_plan_review_enforcement() {
  echo ""
  echo "${YELLOW}=== check-plan-review.sh — enforcement + block path (phase 08-02) ===${RESET}"

  local tmp; tmp="$(mktemp -d)"
  local escoutside="${tmp}-escmarker"
  trap 'rm -rf "$tmp" "$escoutside"' RETURN
  mkdir -p "$tmp/.planning/phases" "$tmp/err"
  local errdir="$tmp/err"
  local s e phasedir

  # ── Block path (D-10) ───────────────────────────────────────────────────────

  s="$tmp/block-basic"
  phasedir="$(_cpr_enf_phase "$s" "08-block-basic")"
  e="$errdir/block-basic.err"
  _cpr_case "block: plans present, no *-REVIEWS.md -> exit 2" "$s" 2 --err-out "$e"
  # The verifier cd's into the sandbox root, so it reports phase paths
  # relative to that root (e.g. .planning/phases/08-block-basic), not the
  # sandbox's own absolute $phasedir.
  _cpr_check_contains "block: stderr names the resolved phase dir" "$e" ".planning/phases/08-block-basic"
  _cpr_check_contains "block: stderr names codex-plan-review remedy" "$e" "codex-plan-review"
  _cpr_check_contains "block: stderr names GSD_SKIP_REVIEWS hatch" "$e" "GSD_SKIP_REVIEWS"
  _cpr_check_contains "block: stderr names multi-ai-review-skipped hatch" "$e" "multi-ai-review-skipped"

  # ── REVIEWS strictness (D-13) — frontmatter present and well-formed ────────

  s="$tmp/rev-flow2"; phasedir="$(_cpr_enf_phase "$s" "08-rev-flow2")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8

Body text.
MD
  _cpr_case "strictness: reviewers: [gemini, opencode] (flow, 2 distinct) -> exit 0" "$s" 0

  s="$tmp/rev-flow3"; phasedir="$(_cpr_enf_phase "$s" "08-rev-flow3")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [claude, gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  claude: LOW
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8

Body text.
MD
  _cpr_case "strictness: reviewers: [claude, gemini, opencode] (flow, 3 distinct) -> exit 0" "$s" 0

  s="$tmp/rev-block2"; phasedir="$(_cpr_enf_phase "$s" "08-rev-block2")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers:
  - gemini
  - opencode
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed:
  - 08-01-PLAN.md
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8

Body text.
MD
  _cpr_case "strictness: reviewers: as a 2-entry BLOCK sequence -> exit 0 (style independence)" "$s" 0

  s="$tmp/rev-block1"; phasedir="$(_cpr_enf_phase "$s" "08-rev-block1")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers:
  - gemini
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed:
  - 08-01-PLAN.md
overall_verdict:
  gemini: LOW
recommendation: rework
---

# Cross-AI Plan Review — Phase 8

Body text.
MD
  _cpr_case "strictness: reviewers: as a 1-entry BLOCK sequence -> exit 2" "$s" 2

  s="$tmp/rev-one"; phasedir="$(_cpr_enf_phase "$s" "08-rev-one")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
recommendation: rework
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "strictness: reviewers: [gemini] (1 reviewer) -> exit 2" "$s" 2

  s="$tmp/rev-zero"; phasedir="$(_cpr_enf_phase "$s" "08-rev-zero")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: []
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict: {}
recommendation: rework
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "strictness: reviewers: [] (0 reviewers) -> exit 2" "$s" 2

  s="$tmp/rev-dup"; phasedir="$(_cpr_enf_phase "$s" "08-rev-dup")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, gemini]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
recommendation: rework
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "strictness: reviewers: [gemini, gemini] — DISTINCT count is 1, not 2 -> exit 2" "$s" 2

  s="$tmp/rev-norm"; phasedir="$(_cpr_enf_phase "$s" "08-rev-norm")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, GEMINI, ' gemini ']
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
recommendation: rework
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "strictness: reviewers: [gemini, GEMINI, ' gemini '] normalizes to 1 distinct -> exit 2" "$s" 2

  s="$tmp/rev-longbody-ok"; phasedir="$(_cpr_enf_phase "$s" "08-rev-longbody-ok")"
  {
    cat <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8

MD
    for _i in $(seq 1 200); do echo "Body line $_i of a long, otherwise irrelevant review."; done
  } > "$phasedir/08-REVIEWS.md"
  _cpr_case "strictness: reviewers: [gemini, opencode] + 200-line body -> exit 0 (frontmatter authoritative)" "$s" 0

  s="$tmp/rev-longbody-block"; phasedir="$(_cpr_enf_phase "$s" "08-rev-longbody-block")"
  {
    cat <<'MD'
---
phase: 8
reviewers: [gemini]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
recommendation: rework
---

# Cross-AI Plan Review — Phase 8

MD
    for _i in $(seq 1 200); do echo "Body line $_i of a long, otherwise irrelevant review."; done
  } > "$phasedir/08-REVIEWS.md"
  _cpr_case "strictness: reviewers: [gemini] + 200-line body MUST NOT be rescued -> exit 2 (D-14)" "$s" 2

  s="$tmp/rev-body-only"; phasedir="$(_cpr_enf_phase "$s" "08-rev-body-only")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
plans_reviewed: [08-01-PLAN.md]
overall_verdict: {}
recommendation: rework
---

# Cross-AI Plan Review — Phase 8

reviewers: [gemini, opencode]

A `reviewers:` mention in the BODY, not the frontmatter, must not count.
MD
  _cpr_case "strictness: 'reviewers:' in BODY only (not frontmatter) -> exit 2 (parse bounded to frontmatter)" "$s" 2

  # ── plans_reviewed coverage (D-12) ──────────────────────────────────────────

  s="$tmp/cov-full"; phasedir="$(_cpr_enf_phase "$s" "08-cov-full" "08-01-PLAN.md" "08-02-PLAN.md")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md, 08-02-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "coverage: plans_reviewed covers both current plans -> exit 0" "$s" 0

  s="$tmp/cov-gap"; phasedir="$(_cpr_enf_phase "$s" "08-cov-gap" "08-01-PLAN.md" "08-02-PLAN.md")"
  e="$errdir/cov-gap.err"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "coverage: plans_reviewed omits 08-02-PLAN.md -> exit 2" "$s" 2 --err-out "$e"
  _cpr_check_contains "coverage: stderr names the unreviewed plan 08-02-PLAN.md" "$e" "08-02-PLAN.md"

  s="$tmp/cov-block-style"; phasedir="$(_cpr_enf_phase "$s" "08-cov-block-style" "08-01-PLAN.md" "08-02-PLAN.md")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed:
  - 08-01-PLAN.md
  - 08-02-PLAN.md
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "coverage: plans_reviewed as a BLOCK sequence covering both plans -> exit 0" "$s" 0

  s="$tmp/cov-block-gap"; phasedir="$(_cpr_enf_phase "$s" "08-cov-block-gap" "08-01-PLAN.md" "08-02-PLAN.md")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed:
  - 08-01-PLAN.md
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "coverage: plans_reviewed as a BLOCK sequence with a gap -> exit 2 (style independence)" "$s" 2

  s="$tmp/cov-no-key"; phasedir="$(_cpr_enf_phase "$s" "08-cov-no-key")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "coverage: frontmatter with reviewers: but NO plans_reviewed: key -> exit 2 (D-12 schema)" "$s" 2

  s="$tmp/cov-superset"; phasedir="$(_cpr_enf_phase "$s" "08-cov-superset" "08-01-PLAN.md")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md, 08-02-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "coverage: plans_reviewed lists a plan that no longer exists (superset) -> exit 0" "$s" 0

  # ── Malformed vs absent frontmatter (D-13) ──────────────────────────────────

  s="$tmp/fm-malformed"; phasedir="$(_cpr_enf_phase "$s" "08-fm-malformed")"
  e="$errdir/fm-malformed.err"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]

# Cross-AI Plan Review — Phase 8

An opening '---' with no closing '---' below it -- malformed, not absent.
MD
  _cpr_case "frontmatter: opening '---' with NO closing '---' -> exit 2 (malformed)" "$s" 2 --err-out "$e"
  _cpr_check_contains "frontmatter: stderr distinguishes 'malformed' from missing-REVIEWS wording" "$e" "malformed"

  s="$tmp/fm-absent-ok"; phasedir="$(_cpr_enf_phase "$s" "08-fm-absent-ok")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
Line 1 of a hand-written, frontmatter-less review note.
Line 2.
Line 3.
Line 4.
Line 5.
Line 6.
Line 7.
Line 8.
Line 9.
Line 10.
Line 11.
Line 12.
MD
  _cpr_case "frontmatter: absent, 12-line body -> exit 0 (D-13 fallback)" "$s" 0

  s="$tmp/fm-absent-short"; phasedir="$(_cpr_enf_phase "$s" "08-fm-absent-short")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
Line 1.
Line 2.
Line 3.
MD
  _cpr_case "frontmatter: absent, 3-line body -> exit 2 (D-13 diverges from the reference's warn+allow)" "$s" 2

  s="$tmp/fm-absent-empty"; phasedir="$(_cpr_enf_phase "$s" "08-fm-absent-empty")"
  : > "$phasedir/08-REVIEWS.md"
  _cpr_case "frontmatter: absent, empty file -> exit 2" "$s" 2

  # ── Delimiter tolerance (CR-01 regression) ──────────────────────────────────
  # 08-VERIFICATION.md derived truth #8 / 08-REVIEW.md CR-01: a trailing space
  # or CRLF on the opening '---' silently downgrades a well-formed frontmatter
  # to the reviewer-check-free D-13 fallback. These four fixtures pin the fix
  # both directions: the two "currently exits 0" repros must become exit 2,
  # and the two over-correction guards must stay exit 0.

  s="$tmp/cr01-trailing-space"; phasedir="$(_cpr_enf_phase "$s" "08-cr01-trailing-space")"
  printf -- '--- \nphase: 8\nreviewers: [gemini]\nplans_reviewed: [08-01-PLAN.md]\n---\nBody text.\n' > "$phasedir/08-REVIEWS.md"
  e="$errdir/cr01-trailing-space.err"
  _cpr_case "CR-01: opening '--- ' (trailing space) + 1 reviewer -> exit 2 (strict path reached, not D-13 fallback)" "$s" 2 --err-out "$e"
  _cpr_check_contains "CR-01: trailing-space stderr reports reviewer count (not coverage/missing-plan)" "$e" "distinct reviewer"

  s="$tmp/cr01-crlf-one-reviewer"; phasedir="$(_cpr_enf_phase "$s" "08-cr01-crlf-one-reviewer")"
  printf -- '---\r\nphase: 8\r\nreviewers: [gemini]\r\nplans_reviewed: [08-01-PLAN.md]\r\n---\r\nBody line.\r\n' > "$phasedir/08-REVIEWS.md"
  e="$errdir/cr01-crlf-one-reviewer.err"
  _cpr_case "CR-01: CRLF line endings + 1 reviewer -> exit 2 (strict path reached despite CRLF)" "$s" 2 --err-out "$e"
  _cpr_check_contains "CR-01: CRLF 1-reviewer stderr reports reviewer count (not coverage/missing-plan)" "$e" "distinct reviewer"

  s="$tmp/cr01-crlf-two-reviewers-ok"; phasedir="$(_cpr_enf_phase "$s" "08-cr01-crlf-two-reviewers-ok")"
  printf -- '---\r\nphase: 8\r\nreviewers: [gemini, opencode]\r\nplans_reviewed: [08-01-PLAN.md]\r\n---\r\nBody line.\r\n' > "$phasedir/08-REVIEWS.md"
  e="$errdir/cr01-crlf-two-reviewers-ok.err"
  _cpr_case "CR-01 guard: CRLF + 2 valid reviewers -> exit 0 (must not over-correct into false block or MALFORMED)" "$s" 0 --err-out "$e"

  s="$tmp/cr01-trailing-space-two-reviewers-ok"; phasedir="$(_cpr_enf_phase "$s" "08-cr01-trailing-space-two-reviewers-ok")"
  printf -- '--- \nphase: 8\nreviewers: [gemini, opencode]\nplans_reviewed: [08-01-PLAN.md]\n---\nBody text.\n' > "$phasedir/08-REVIEWS.md"
  _cpr_case "CR-01 guard: trailing-space opening delimiter + 2 valid reviewers -> exit 0" "$s" 0

  # ── Reviewer identity / D-15 codex exclusion (WR-01) ────────────────────────
  # 08-VERIFICATION.md derived truth #8 / 08-REVIEW.md WR-01: the strict path
  # counts distinct strings, never identity, so codex (the implementing host)
  # can supply the >=2 floor via self-review. D-15 excludes codex-derived
  # entries from the count before the -lt 2 test.

  s="$tmp/wr01-codex-self"; phasedir="$(_cpr_enf_phase "$s" "08-wr01-codex-self")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [codex, codex-self]
plans_reviewed: [08-01-PLAN.md]
overall_verdict: {}
recommendation: rework
---

# Cross-AI Plan Review — Phase 8
MD
  e="$errdir/wr01-codex-self.err"
  _cpr_case "WR-01: reviewers: [codex, codex-self] -> exit 2 (both codex-derived, D-15 excludes both)" "$s" 2 --err-out "$e"
  _cpr_check_contains "WR-01: [codex, codex-self] block message names codex" "$e" "codex"
  _cpr_check_contains "WR-01: [codex, codex-self] block message cites D-15" "$e" "D-15"

  s="$tmp/wr01-codex-gemini"; phasedir="$(_cpr_enf_phase "$s" "08-wr01-codex-gemini")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [codex, gemini]
plans_reviewed: [08-01-PLAN.md]
overall_verdict: {}
recommendation: rework
---

# Cross-AI Plan Review — Phase 8
MD
  e="$errdir/wr01-codex-gemini.err"
  _cpr_case "WR-01: reviewers: [codex, gemini] -> exit 2 (1 external reviewer remains after codex exclusion)" "$s" 2 --err-out "$e"
  _cpr_check_contains "WR-01: [codex, gemini] block message cites D-15" "$e" "D-15"

  s="$tmp/wr01-zero-margin"; phasedir="$(_cpr_enf_phase "$s" "08-wr01-zero-margin")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, codex, opencode]
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
  codex: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "WR-01 zero-margin: reviewers: [gemini, codex, opencode] -> exit 0 (2 external after exclusion; pins the real 08-REVIEWS.md shape)" "$s" 0

  s="$tmp/wr01-case-insensitive"; phasedir="$(_cpr_enf_phase "$s" "08-wr01-case-insensitive")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [CODEX, Codex]
plans_reviewed: [08-01-PLAN.md]
overall_verdict: {}
recommendation: rework
---

# Cross-AI Plan Review — Phase 8
MD
  _cpr_case "WR-01: reviewers: [CODEX, Codex] -> exit 2 (case-insensitive exclusion, both normalize to codex)" "$s" 2

  # ── D-13 fallback is RETAINED (over-correction guard) ───────────────────────
  # ADR-0009 decision 11 deliberately keeps the >=5-line, frontmatter-less
  # fallback for hand-written cross-host compatibility (ADR-0007 point 5). A
  # fix that blocks this has over-corrected.

  s="$tmp/d13-fallback-retained"; phasedir="$(_cpr_enf_phase "$s" "08-d13-fallback-retained")"
  printf 'Line 1 of a hand-written, frontmatter-less review note.\nLine 2.\nLine 3.\nLine 4.\nLine 5.\nLine 6.\n' > "$phasedir/08-REVIEWS.md"
  _cpr_case "D-13 guard: frontmatter-less 6-line body -> exit 0 (fallback deliberately retained, ADR-0009 decision 11)" "$s" 0

  # ── Escape hatches (D-11) ────────────────────────────────────────────────────

  s="$tmp/hatch-env"; phasedir="$(_cpr_enf_phase "$s" "08-hatch-env")"
  e="$errdir/hatch-env.err"
  GSD_SKIP_REVIEWS=1 _cpr_case "hatch: GSD_SKIP_REVIEWS=1 -> exit 0" "$s" 0 --err-out "$e"
  _cpr_check_contains "hatch: stderr names GSD_SKIP_REVIEWS as the fired hatch" "$e" "GSD_SKIP_REVIEWS"

  s="$tmp/hatch-marker"; phasedir="$(_cpr_enf_phase "$s" "08-hatch-marker")"
  touch "$phasedir/multi-ai-review-skipped"
  e="$errdir/hatch-marker.err"
  _cpr_case "hatch: multi-ai-review-skipped marker at resolved phase dir -> exit 0" "$s" 0 --err-out "$e"
  _cpr_check_contains "hatch: stderr names the marker path" "$e" "multi-ai-review-skipped"

  mkdir -p "$tmp/.planning/phases/08-real"
  touch "$tmp/.planning/phases/08-real/08-01-PLAN.md" 2>/dev/null || true
  s="$tmp/hatch-escaped-marker"
  mkdir -p "$s/.planning/phases/08-real"
  touch "$s/.planning/phases/08-real/08-01-PLAN.md"
  mkdir -p "$escoutside"
  touch "$escoutside/multi-ai-review-skipped"
  ln -s "$escoutside" "$s/.planning/current-phase"
  cat > "$s/.planning/STATE.md" <<'EOF'
## Current Position

Phase: 08 (escaped marker regression) - DOING
EOF
  _cpr_case "hatch: marker reachable ONLY via an escaped current-phase pointer is NOT honored -> exit 2 (T-08-29)" "$s" 2

  s="$tmp/hatch-zero"; phasedir="$(_cpr_enf_phase "$s" "08-hatch-zero")"
  GSD_SKIP_REVIEWS=0 _cpr_case "hatch: GSD_SKIP_REVIEWS=0 is NOT a hatch -> exit 2" "$s" 2

  s="$tmp/hatch-blank"; phasedir="$(_cpr_enf_phase "$s" "08-hatch-blank")"
  GSD_SKIP_REVIEWS="" _cpr_case "hatch: GSD_SKIP_REVIEWS='' is NOT a hatch -> exit 2" "$s" 2

  # ── --file bypass list (T-08-08, T-08-37) ───────────────────────────────────

  s="$tmp/bypass-plan"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-plan")"
  _cpr_case "bypass: --file .planning/.../08-01-PLAN.md -> exit 0 (canonical GSD artifact)" "$s" 0 --file ".planning/phases/08-bypass-plan/08-01-PLAN.md"

  s="$tmp/bypass-nonplanning"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-nonplanning")"
  _cpr_case "bypass: --file docs/IMPLEMENTATION-PLAN.md -> exit 2 (basename matches but NOT .planning/-rooted)" "$s" 2 --file "docs/IMPLEMENTATION-PLAN.md"

  s="$tmp/bypass-traversal1"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-traversal1")"
  _cpr_case "bypass: --file .planning/../docs/IMPLEMENTATION-PLAN.md -> exit 2 (traversal regression guard)" "$s" 2 --file ".planning/../docs/IMPLEMENTATION-PLAN.md"

  s="$tmp/bypass-traversal2"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-traversal2")"
  _cpr_case "bypass: --file .planning/../../etc/passwd -> exit 2 (traversal, basename wouldn't have matched anyway)" "$s" 2 --file ".planning/../../etc/passwd"

  s="$tmp/bypass-traversal3"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-traversal3")"
  _cpr_case "bypass: --file .planning/phases/08-x/../08-x/08-01-PLAN.md -> exit 2 (traversal is a SHAPE check, not a resolution check)" "$s" 2 --file ".planning/phases/08-x/../08-x/08-01-PLAN.md"

  # ── WR-03: symlink-resolution + sibling-prefix containment (Phase 12) ──────
  #
  # Reuses _cpr_case/_cpr_enf_phase verbatim (no second sandbox/exit-code
  # helper, per this suite's own header rule). Each fixture below is
  # mutation-proven RED-before-GREEN: observed exit=0 (fail-open) against
  # the pre-Phase-12 lexical-'..'-only guard, exit=2 against the
  # parent-dir canonicalize-and-contain fix (Task 1), except (b) which
  # proves the accept side of resolve-then-contain (D-03) and is exit=0
  # under both the old and new guard (not a regression case).

  # (a) SYMLINKED-PARENT-ESCAPE: the --file value's parent directory is a
  # symlink resolving OUTSIDE $REPO_ROOT/.planning. Mirrors ADR-0009
  # decision 12's own live repro
  # (`ln -s /tmp/outside .planning/phases/09-test-phase/evil-link`).
  # Old lexical-'..'-only guard: no '..' component in the literal string,
  # '.planning/' prefix matches, basename matches *PLAN.md -> exit 0
  # (fail-open, the WR-03 hole). New guard: canonicalizes the parent,
  # 'evil-link' resolves outside .planning -> containment fails -> bypass
  # falls through (D-02) -> normal resolution finds the phase's real
  # unreviewed PLAN.md -> exit 2 via the REVIEWS.md gate.
  s="$tmp/wr03-symlink-escape"; phasedir="$(_cpr_enf_phase "$s" "12-wr03-escape")"
  wr03_escdir="${tmp}-wr03-escape"
  mkdir -p "$wr03_escdir"
  ln -s "$wr03_escdir" "$phasedir/evil-link"
  _cpr_case "WR-03 bypass: --file .../evil-link/some-PLAN.md -> exit 2 (symlinked parent resolves OUTSIDE .planning; old lexical-only guard returned exit 0 here -- fail-open closed)" "$s" 2 --file ".planning/phases/12-wr03-escape/evil-link/some-PLAN.md"

  # (b) SYMLINKED-PARENT-INSIDE: the --file value's parent directory is a
  # symlink resolving to a real directory INSIDE .planning/phases/.
  # Resolve-then-contain (D-03) accepts this -- WR-03 does NOT adopt
  # REVIEWS.md's reject-any-symlink asymmetry, which would false-block a
  # legitimate worktree symlink under a --file edit target.
  s="$tmp/wr03-symlink-inside"; phasedir="$(_cpr_enf_phase "$s" "12-wr03-inside")"
  wr03_insidedir="$s/.planning/phases/12-wr03-inside-target"
  mkdir -p "$wr03_insidedir"
  ln -s "$wr03_insidedir" "$phasedir/inside-link"
  _cpr_case "WR-03 bypass: --file .../inside-link/some-PLAN.md -> exit 0 (symlinked parent resolves INSIDE .planning -- resolve-then-contain accepts it, D-03)" "$s" 0 --file ".planning/phases/12-wr03-inside/inside-link/some-PLAN.md"

  # (c) SIBLING-PREFIX-COLLISION: a 'vendor/foo/.planning/X-PLAN.md'-shaped
  # path that satisfied the OLD lexical '*/.planning/*' arm textually.
  # 'vendor/foo/.planning/' is created as a REAL directory here (not left
  # absent) so _canon_dir on the parent succeeds and returns a non-empty
  # path -- the exit=2 below is produced by _is_contained genuinely
  # evaluating containment-false against $REPO_ROOT/.planning (SC#1), NOT
  # by the D-02 fall-through that fires when a parent does not exist. Old
  # guard: '*/.planning/*' + 'X-PLAN.md' basename match -> exit 0. New
  # guard (D-05, disclosed tightening): containment is against THIS repo's
  # $REPO_ROOT/.planning only -> a vendored sub-project's .planning/ no
  # longer bypasses -> falls through -> exit 2 via the REVIEWS.md gate.
  s="$tmp/wr03-sibling-prefix"; phasedir="$(_cpr_enf_phase "$s" "12-wr03-sibling")"
  mkdir -p "$s/vendor/foo/.planning"
  _cpr_case "WR-03 bypass: --file vendor/foo/.planning/X-PLAN.md -> exit 2 (sibling-prefix collision; old */.planning/* lexical arm returned exit 0 here -- D-05 tightens containment to \$REPO_ROOT/.planning only)" "$s" 2 --file "vendor/foo/.planning/X-PLAN.md"

  # (d) NOT-YET-CREATED-DIR WITH UNRELATED ACTIVE PHASE (12-04 gap-closure;
  # 12-VERIFICATION.md Priority Concern / WR-01; 12-01-PLAN.md truth #4).
  #
  # Reproduces the verifier's exact independently-constructed repro: an
  # UNRELATED active phase (13-active-phase) is mid-review -- it has a
  # *-PLAN.md but no *-REVIEWS.md, and .planning/current-phase points at
  # it -- while the --file value names a DIFFERENT, not-yet-created plan
  # artifact (14-new-nonexistent/14-01-PLAN.md). Expected: exit 0
  # (fail-safe accept), matching the pre-Phase-12 script's behavior for
  # the identical input.
  #
  # CRITICAL, unlike every other _cpr_enf_phase fixture in this file
  # (which pre-creates the phase dir it operates on): this fixture
  # deliberately does NOT create .planning/phases/14-new-nonexistent/.
  # The entire point is that the --file value's parent dir does not
  # exist, so _canon_dir returns empty and the resolve-then-contain
  # branch (fixtures a/b/c above) never fires -- only the new lexical
  # $REPO_ROOT/.planning-rooted fallback (check-plan-review.sh, the
  # elif [ -z "$_cpr_canon_parent" ] branch) can produce the exit-0
  # verdict here.
  #
  # RED-before-GREEN evidence (executor-observed, this gap-closure):
  #   RED  (fallback commented out): FAIL WR-03 bypass: --file
  #        .planning/phases/14-new-nonexistent/14-01-PLAN.md -> exit 0
  #        (not-yet-created dir + unrelated active PLAN.md-no-REVIEWS.md
  #        phase must fall through to fail-safe accept, matching
  #        pre-Phase-12 behavior) (expected exit=0, got exit=2)
  #   GREEN (fallback restored):   PASS WR-03 bypass: --file
  #        .planning/phases/14-new-nonexistent/14-01-PLAN.md -> exit 0
  #        (not-yet-created dir + unrelated active PLAN.md-no-REVIEWS.md
  #        phase must fall through to fail-safe accept, matching
  #        pre-Phase-12 behavior) (exit=0)
  # See 12-04-SUMMARY.md for the verbatim transcript.
  #
  # Fixture (a) above (symlinked-parent-escape, :3191) is the paired
  # hole-not-reopened invariant: its parent EXISTS as a symlink, so
  # _canon_dir is non-empty there and the fallback added here never
  # fires for it -- it must keep asserting exit 2 after this change.
  s="$tmp/wr04-not-yet-created-unrelated-active"
  phasedir="$(_cpr_enf_phase "$s" "13-active-phase" "13-01-PLAN.md")"
  _cpr_case "WR-03 bypass: --file .planning/phases/14-new-nonexistent/14-01-PLAN.md -> exit 0 (not-yet-created dir + unrelated active PLAN.md-no-REVIEWS.md phase must fall through to fail-safe accept, matching pre-Phase-12 behavior)" "$s" 0 --file ".planning/phases/14-new-nonexistent/14-01-PLAN.md"

  s="$tmp/bypass-codefile"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-codefile")"
  _cpr_case "bypass: --file src/app.ts -> exit 2 (ordinary code file, the gate's whole point)" "$s" 2 --file "src/app.ts"

  s="$tmp/bypass-none"; phasedir="$(_cpr_enf_phase "$s" "08-bypass-none")"
  _cpr_case "bypass: no --file at all -> exit 2 (bypass never fires when the flag is absent)" "$s" 2

  # ── Non-regular artifact, fail-closed (T-08-09) ─────────────────────────────

  if command -v mkfifo >/dev/null 2>&1; then
    _cpr_timeout_cmd=""
    if command -v timeout >/dev/null 2>&1; then
      _cpr_timeout_cmd="timeout"
    elif command -v gtimeout >/dev/null 2>&1; then
      _cpr_timeout_cmd="gtimeout"
    fi
    if [ -n "$_cpr_timeout_cmd" ]; then
      s="$tmp/nonreg-fifo"; phasedir="$(_cpr_enf_phase "$s" "08-nonreg-fifo")"
      rm -f "$phasedir/08-REVIEWS.md"
      mkfifo "$phasedir/08-REVIEWS.md"
      _cpr_fifo_rc=$( ( cd "$s" && "$_cpr_timeout_cmd" 5 bash "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" ) >/dev/null 2>&1; echo $? )
      if [ "$_cpr_fifo_rc" = "2" ]; then
        echo "  ${GREEN}PASS${RESET} non-regular: FIFO *-REVIEWS.md -> exit 2 under timeout (not a hang, not exit 0)"
        PASS=$((PASS+1))
      else
        echo "  ${RED}FAIL${RESET} non-regular: FIFO case (expected exit=2, got exit=$_cpr_fifo_rc)"
        FAIL=$((FAIL+1))
      fi
    else
      echo "  ${YELLOW}SKIP${RESET} no timeout/gtimeout available — FIFO fail-closed case not run"
      SKIP=$((SKIP+1))
    fi
  else
    echo "  ${YELLOW}SKIP${RESET} mkfifo not available — FIFO fail-closed case not run"
    SKIP=$((SKIP+1))
  fi

  s="$tmp/nonreg-dir"; phasedir="$(_cpr_enf_phase "$s" "08-nonreg-dir")"
  rm -f "$phasedir/08-REVIEWS.md" 2>/dev/null || true
  mkdir -p "$phasedir/08-REVIEWS.md"
  _cpr_case "non-regular: *-REVIEWS.md is a directory -> exit 2" "$s" 2

  s="$tmp/nonreg-dangling"; phasedir="$(_cpr_enf_phase "$s" "08-nonreg-dangling")"
  ln -s "$phasedir/does-not-exist" "$phasedir/08-REVIEWS.md"
  _cpr_case "non-regular: *-REVIEWS.md is a dangling symlink -> exit 2" "$s" 2

  # ── Symlinked artifact, fail-closed (T-08-36; bypass 1) ─────────────────────

  s="$tmp/symlink-outside"; phasedir="$(_cpr_enf_phase "$s" "08-symlink-outside")"
  printf 'a\nb\nc\nd\ne\nf\n' > "$s/decoy.txt"
  ln -s "$s/decoy.txt" "$phasedir/08-REVIEWS.md"
  e="$errdir/symlink-outside.err"
  _cpr_case "symlink: LIVE symlink to a 12-line frontmatter-less file OUTSIDE the phase dir -> exit 2 (the bypass)" "$s" 2 --err-out "$e"
  # Relative to the sandbox root the verifier cd's into (see the block-path
  # case above for the same relative-vs-absolute-path rationale).
  _cpr_check_contains "symlink: stderr names the symlink path" "$e" ".planning/phases/08-symlink-outside/08-REVIEWS.md"

  s="$tmp/symlink-valid-elsewhere"; phasedir="$(_cpr_enf_phase "$s" "08-symlink-valid-elsewhere")"
  cat > "$s/valid-reviews.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  ln -s "$s/valid-reviews.md" "$phasedir/08-REVIEWS.md"
  _cpr_case "symlink: LIVE symlink to a VALID 2-reviewer REVIEWS.md elsewhere -> exit 2 (rejected on shape, not content)" "$s" 2

  s="$tmp/symlink-insidedir"; phasedir="$(_cpr_enf_phase "$s" "08-symlink-insidedir")"
  cat > "$phasedir/valid-reviews.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  ln -s "$phasedir/valid-reviews.md" "$phasedir/08-REVIEWS.md"
  _cpr_case "symlink: LIVE symlink to a file INSIDE the same phase dir -> exit 2 (containment is not the test)" "$s" 2

  # ── Ambiguous artifact ───────────────────────────────────────────────────────

  s="$tmp/ambiguous-reviews"; phasedir="$(_cpr_enf_phase "$s" "08-ambiguous-reviews")"
  cat > "$phasedir/08-REVIEWS.md" <<'MD'
---
phase: 8
reviewers: [gemini, opencode]
reviewed_at: 2026-07-15T00:00:00Z
plans_reviewed: [08-01-PLAN.md]
overall_verdict:
  gemini: LOW
  opencode: LOW
recommendation: proceed
---

# Cross-AI Plan Review — Phase 8
MD
  cp "$phasedir/08-REVIEWS.md" "$phasedir/old-REVIEWS.md"
  e="$errdir/ambiguous-reviews.err"
  _cpr_case "ambiguous: two *-REVIEWS.md in the resolved phase -> exit 2" "$s" 2 --err-out "$e"
  _cpr_check_contains "ambiguous: stderr names 08-REVIEWS.md" "$e" "08-REVIEWS.md"
  _cpr_check_contains "ambiguous: stderr names old-REVIEWS.md" "$e" "old-REVIEWS.md"
}

# ─────────────────────────────────────────────────────────────────────────────
# check-plan-review.sh — producer <-> verifier contract suite (phase 08, plan 02)
#
# Reads the REAL repo-root artifacts (this repo's own 08-REVIEWS.md and the
# codex-plan-review skill's reviews-skeleton) rather than inline fixtures --
# deliberately, per this plan's <action>: an inline copy of the schema only
# proves the verifier parses the test author's idea of the schema. If either
# real artifact is absent, these cases FAIL (never SKIP) -- their absence is
# the regression.
# ─────────────────────────────────────────────────────────────────────────────

test_check_plan_review_contract() {
  echo ""
  echo "${YELLOW}=== check-plan-review.sh — producer<->verifier contract (phase 08-02) ===${RESET}"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/.planning/phases"

  local real_reviews="$REPO_ROOT/.planning/phases/08-plan-review-gate/08-REVIEWS.md"
  local skill_md="$REPO_ROOT/skills/codex-plan-review/SKILL.md"

  # ── Real-artifact round trip ─────────────────────────────────────────────────

  if [ -f "$real_reviews" ]; then
    local s phasedir plans_line plan_name
    s="$tmp/real-artifact"
    phasedir="$s/.planning/phases/08-plan-review-gate"
    mkdir -p "$phasedir"
    cp "$real_reviews" "$phasedir/08-REVIEWS.md"
    ( cd "$s/.planning" && ln -sf "phases/08-plan-review-gate" current-phase )

    plans_line="$(awk -F': ' '/^plans_reviewed:/{print $2; exit}' "$real_reviews")"
    plans_line="${plans_line#\[}"; plans_line="${plans_line%\]}"
    local -a real_plans
    IFS=',' read -ra real_plans <<< "$plans_line"
    for plan_name in "${real_plans[@]}"; do
      plan_name="$(printf '%s' "$plan_name" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')"
      [ -n "$plan_name" ] && touch "$phasedir/$plan_name"
    done

    if [ "${#real_plans[@]}" -ge 1 ]; then
      echo "  ${GREEN}PASS${RESET} contract: real 08-REVIEWS.md's plans_reviewed parsed (${#real_plans[@]} entries)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} contract: real 08-REVIEWS.md's plans_reviewed did not parse -- 0 entries"
      FAIL=$((FAIL+1))
    fi

    _cpr_case "contract: this repo's real 08-REVIEWS.md, with one *-PLAN.md per plans_reviewed entry -> exit 0" "$s" 0
  else
    echo "  ${RED}FAIL${RESET} contract: real artifact missing at .planning/phases/08-plan-review-gate/08-REVIEWS.md (always a FAIL, never skipped)"
    FAIL=$((FAIL+1))
  fi

  # ── Producer-skeleton round trip + full D-12 schema assertion ───────────────

  if [ -f "$skill_md" ]; then
    local skel_raw skel
    skel_raw="$(awk '
      /<!-- BEGIN: reviews-skeleton/ { f=1; next }
      /<!-- END: reviews-skeleton/   { f=0 }
      f
    ' "$skill_md")"
    skel="$(printf '%s\n' "$skel_raw" | awk '$0 == "```" || $0 == "```markdown" { next } { print }')"

    if [ -n "$(printf '%s' "$skel" | tr -d '[:space:]')" ]; then
      echo "  ${GREEN}PASS${RESET} contract: reviews-skeleton extraction is non-empty"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} contract: reviews-skeleton extraction is EMPTY -- marker rename regression"
      FAIL=$((FAIL+1))
    fi

    # Full D-12 schema assertion -- the six required frontmatter keys.
    local key
    for key in phase reviewers reviewed_at plans_reviewed overall_verdict recommendation; do
      if printf '%s\n' "$skel" | grep -q "^${key}:"; then
        echo "  ${GREEN}PASS${RESET} contract: skeleton frontmatter carries '${key}:' (D-12 schema)"
        PASS=$((PASS+1))
      else
        echo "  ${RED}FAIL${RESET} contract: skeleton frontmatter MISSING '${key}:' (D-12 schema)"
        FAIL=$((FAIL+1))
      fi
    done

    # Body: H1 + one "## <Reviewer> Review" H2 per reviewers entry + consensus.
    if printf '%s\n' "$skel" | grep -qE '^# Cross-AI Plan Review — Phase [0-9]+'; then
      echo "  ${GREEN}PASS${RESET} contract: skeleton body carries the required H1 (D-12)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} contract: skeleton body MISSING the required H1 (D-12)"
      FAIL=$((FAIL+1))
    fi

    if printf '%s\n' "$skel" | grep -qiE '^## +Consensus'; then
      echo "  ${GREEN}PASS${RESET} contract: skeleton body carries a Consensus section (D-12)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} contract: skeleton body MISSING a Consensus section (D-12)"
      FAIL=$((FAIL+1))
    fi

    local skel_reviewers_line skel_reviewers_line2 skel_reviewer_count skel_section_count
    skel_reviewers_line="$(printf '%s\n' "$skel" | awk -F': ' '/^reviewers:/{print $2; exit}')"
    skel_reviewers_line2="${skel_reviewers_line#\[}"; skel_reviewers_line2="${skel_reviewers_line2%\]}"
    local -a skel_reviewers
    IFS=',' read -ra skel_reviewers <<< "$skel_reviewers_line2"
    skel_reviewer_count="${#skel_reviewers[@]}"
    skel_section_count="$(printf '%s\n' "$skel" | grep -cE '^## .+ Review$')"
    if [ "$skel_reviewer_count" -eq "$skel_section_count" ] && [ "$skel_reviewer_count" -ge 2 ]; then
      echo "  ${GREEN}PASS${RESET} contract: per-reviewer section count ($skel_section_count) equals reviewers: entry count ($skel_reviewer_count)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} contract: per-reviewer section count ($skel_section_count) != reviewers: entry count ($skel_reviewer_count)"
      FAIL=$((FAIL+1))
    fi

    # Round trip: derive *-PLAN.md names FROM the skeleton's own
    # plans_reviewed rather than hardcoding a count.
    local plans_line plan_name
    plans_line="$(printf '%s\n' "$skel" | awk -F': ' '/^plans_reviewed:/{print $2; exit}')"
    plans_line="${plans_line#\[}"; plans_line="${plans_line%\]}"
    local -a skel_plans
    IFS=',' read -ra skel_plans <<< "$plans_line"

    local s phasedir
    s="$tmp/skeleton-roundtrip"
    phasedir="$s/.planning/phases/08-skeleton"
    mkdir -p "$phasedir"
    printf '%s\n' "$skel" > "$phasedir/08-REVIEWS.md"
    for plan_name in "${skel_plans[@]}"; do
      plan_name="$(printf '%s' "$plan_name" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')"
      [ -n "$plan_name" ] && touch "$phasedir/$plan_name"
    done
    ( cd "$s/.planning" && ln -sf "phases/08-skeleton" current-phase )
    _cpr_case "contract: producer's reviews-skeleton, with one *-PLAN.md per plans_reviewed entry -> exit 0" "$s" 0

    # ── Producer dropped a failed reviewer (D-14/T-08-13) ──────────────────────
    local s2 phasedir2
    s2="$tmp/skeleton-onereviewer"
    phasedir2="$s2/.planning/phases/08-skeleton"
    mkdir -p "$phasedir2"
    printf '%s\n' "$skel" | sed -E 's/^reviewers:.*$/reviewers: [gemini]/' > "$phasedir2/08-REVIEWS.md"
    for plan_name in "${skel_plans[@]}"; do
      plan_name="$(printf '%s' "$plan_name" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')"
      [ -n "$plan_name" ] && touch "$phasedir2/$plan_name"
    done
    ( cd "$s2/.planning" && ln -sf "phases/08-skeleton" current-phase )
    _cpr_case "contract: skeleton with reviewers: reduced to one entry -> exit 2 (verifier independently enforces the minimum)" "$s2" 2

    # ── Vendor-diversity spoof ─────────────────────────────────────────────────
    local s3 phasedir3
    s3="$tmp/skeleton-spoof"
    phasedir3="$s3/.planning/phases/08-skeleton"
    mkdir -p "$phasedir3"
    printf '%s\n' "$skel" | sed -E 's/^reviewers:.*$/reviewers: [gemini, gemini]/' > "$phasedir3/08-REVIEWS.md"
    for plan_name in "${skel_plans[@]}"; do
      plan_name="$(printf '%s' "$plan_name" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')"
      [ -n "$plan_name" ] && touch "$phasedir3/$plan_name"
    done
    ( cd "$s3/.planning" && ln -sf "phases/08-skeleton" current-phase )
    _cpr_case "contract: skeleton with reviewers: [gemini, gemini] -> exit 2 (vendor-diversity spoof)" "$s3" 2
  else
    echo "  ${RED}FAIL${RESET} contract: skills/codex-plan-review/SKILL.md missing (always a FAIL, never skipped)"
    FAIL=$((FAIL+1))
  fi

  # ── Producer refusal (D-14) ──────────────────────────────────────────────────
  local s4 phasedir4
  s4="$tmp/producer-refusal"
  phasedir4="$(_cpr_enf_phase "$s4" "08-producer-refusal")"
  _cpr_case "contract: producer refused (no REVIEWS.md written) -> exit 2 (refusing leaves the gate closed)" "$s4" 2
}

# ─────────────────────────────────────────────────────────────────────────────
# Drift test — the scaffolder's SKILL.md version MUST equal the latest
# migration's to_version (version is migration-coupled).
# ─────────────────────────────────────────────────────────────────────────────

test_migration_0012() {
  echo ""
  echo "${YELLOW}=== Migration 0012 — slim the eager AGENTS.md + reconcile the citation ===${RESET}"

  local doc="$REPO_ROOT/migrations/0012-slim-agents-eager-surface.md"
  local mirror="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
  local skill="$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md"

  if [ ! -f "$doc" ]; then
    echo "  ${RED}FAIL${RESET} 0012 doc missing"; FAIL=$((FAIL+1)); return
  fi

  # The transform is extracted from the DOCUMENT and executed, so the doc stays
  # the single source of truth. Shape-guarded per D-36: non-empty != correct.
  local apply2; apply2="$(extract_step_block "$doc" 2 Apply)"
  assert_extracted_shape "0012 step 2" "$apply2" "slim_agents_block" || return

  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/skills/setup-codex-agenticapps-workflow/templates"
  printf '%s\n' "$apply2" > "$tmp/apply2.sh"

  # Fixture: a v0.8.0-shaped AGENTS.md with all five relocated sections, plus a
  # fenced session-handoff example whose lines start with '## '. That fence is
  # the real-world shape this host's installer template carries; a transform
  # that is not fence-aware reads those lines as headings, ends the drop early,
  # and leaks the fence body into the slimmed file.
  {
    printf '# AGENTS\n\nproject preamble\n\n'
    printf '<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->\n\n'
    printf '<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->\n'
    cat "$mirror"
    printf '\n## Development Workflow\n\nold workflow prose\n\n'
    printf '## Workflow Enforcement Hooks (MANDATORY)\n\n| Gate | Bound skill |\n|---|---|\n| tdd | x |\n\n'
    printf '## Skill routing\n\n- Tiny -> verification\n\n'
    printf '## Session handoff\n\nprose\n\n```markdown\n# Handoff\n\n## Accomplished\n- x\n\n## Decisions\n- y\n```\n\ntrailing handoff prose\n\n'
    printf '## Knowledge Capture — Ritual Tail (spec §15)\n\nlong ritual prose\n\n'
    printf '## Pre-execution Gate — Plan Review (spec §02)\n\nplan review ritual prose\n\n'
    printf '<!-- END: agentic-apps-workflow sections -->\n\n'
    printf '## Project Section\n\nproject-owned content below the marker\n'
  } > "$tmp/AGENTS.md"

  if ! ( cd "$tmp" && bash apply2.sh >/dev/null ); then
    echo "  ${RED}FAIL${RESET} 0012 step 2 shell errored on the fixture"; FAIL=$((FAIL+1)); rm -rf "$tmp"; return
  fi

  # 1. §11 survives byte-identical.
  if awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' "$tmp/AGENTS.md" \
       | diff -q - "$mirror" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} §11 block survives the slim byte-identical"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} §11 block altered by the slim"; FAIL=$((FAIL+1))
  fi

  # 2. All four dropped sections are gone.
  if ! grep -q '^## Workflow Enforcement Hooks (MANDATORY)$' "$tmp/AGENTS.md" \
     && ! grep -q '^## Skill routing$' "$tmp/AGENTS.md" \
     && ! grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' "$tmp/AGENTS.md" \
     && ! grep -q '^## Pre-execution Gate — Plan Review (spec §02)$' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} gate table, routing, §15 tail and plan-review prose removed"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} a relocated section survived in AGENTS.md"; FAIL=$((FAIL+1))
  fi

  # 3. Fence leak — the regression this transform's octal-escape matcher prevents.
  if ! grep -q '^## Accomplished$' "$tmp/AGENTS.md" \
     && ! grep -q '^## Decisions$' "$tmp/AGENTS.md" \
     && ! grep -q '^trailing handoff prose$' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} fenced '## ' lines inside a dropped section do not leak"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} fence leak — a '## ' line inside a code fence ended the drop early"; FAIL=$((FAIL+1))
  fi

  # 4. Both pointers installed.
  if grep -q 'Full protocol in the trigger skill' "$tmp/AGENTS.md" \
     && grep -q 'agentic-apps-workflow` trigger' "$tmp/AGENTS.md" \
     && grep -q 'PreToolUse` hook' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} trigger-skill and session-handoff pointers installed"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} pointers missing after slim"; FAIL=$((FAIL+1))
  fi

  # 5. Content outside the marker block untouched.
  if grep -q '^project-owned content below the marker$' "$tmp/AGENTS.md" \
     && grep -q '^project preamble$' "$tmp/AGENTS.md" \
     && grep -q '^## Project Section$' "$tmp/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} content outside the marker block untouched"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} slim escaped the marker block"; FAIL=$((FAIL+1))
  fi

  # 6. §11 still followed by a '## ' line (0001's replace/rollback bound).
  if awk '/session-level discipline the model brings to every diff\.$/{getline; getline; print; exit}' "$tmp/AGENTS.md" | grep -q '^## '; then
    echo "  ${GREEN}PASS${RESET} §11 block still bounded by a following '## ' heading"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} §11 lost its trailing '## ' bound (breaks 0001/0009)"; FAIL=$((FAIL+1))
  fi

  # 7. The installer template is left ALONE. This host installs by replay, so the
  # template is an input to the chain, not the end state — and migrations
  # 0007/0008/0010 read their sections out of it. Slimming it breaks their replay
  # (0010 would insert nothing, regressing D-06). A fresh install applies the
  # heavy template early and this migration slims the result at the end of the
  # same replay, so it lands slim either way.
  if grep -q '^## Workflow Enforcement Hooks (MANDATORY)$' "$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md" \
     && grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' "$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md"; then
    echo "  ${GREEN}PASS${RESET} installer template left intact as the chain's input (0007/0008/0010 read it)"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} installer template was slimmed — breaks 0007/0008/0010 replay (D-06)"; FAIL=$((FAIL+1))
  fi

  # 8. Idempotent.
  cp "$tmp/AGENTS.md" "$tmp/AGENTS.once"
  ( cd "$tmp" && bash apply2.sh >/dev/null )
  if diff -q "$tmp/AGENTS.once" "$tmp/AGENTS.md" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} second apply is a no-op"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} slim is not idempotent"; FAIL=$((FAIL+1))
  fi

  rm -rf "$tmp"

  # 9. Live repo is at the end state (dogfooding).
  if ! grep -q '^## Workflow Enforcement Hooks (MANDATORY)$' "$REPO_ROOT/AGENTS.md" \
     && grep -q 'Full protocol in the trigger skill' "$REPO_ROOT/AGENTS.md"; then
    echo "  ${GREEN}PASS${RESET} live AGENTS.md is at the 0012 end state"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} live AGENTS.md not slimmed (repo must dogfood its own migration)"; FAIL=$((FAIL+1))
  fi

  # 10. Relocated procedures present in the trigger skill.
  if grep -q '^## Session handoff$' "$skill" \
     && grep -q '^## Knowledge Capture — Ritual Tail (spec §15)$' "$skill" \
     && grep -q '^## Pre-execution Gate — Plan Review (spec §02)$' "$skill" \
     && grep -q '^## Instruction surface — eager vs lazy (spec §12)$' "$skill"; then
    echo "  ${GREEN}PASS${RESET} handoff, §15 tail, plan-review and §12 rationale in trigger skill"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} a relocated procedure is missing from the trigger skill"; FAIL=$((FAIL+1))
  fi

  # 11. §14 declared — the 0.6.0 gap that gated the whole citation advance.
  if grep -q '§14' "$REPO_ROOT/docs/ENFORCEMENT-PLAN.md" && grep -q '§14' "$skill"; then
    echo "  ${GREEN}PASS${RESET} §14 declared in ENFORCEMENT-PLAN and trigger skill"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} §14 undeclared — cannot honestly claim >= 0.6.0"; FAIL=$((FAIL+1))
  fi

  # 12. Claim advanced, and ONLY on the normative carrier.
  if grep -q '^implements_spec: 0.10.0$' "$skill" \
     && grep -q '^implements_spec: 0.4.0$' "$REPO_ROOT/skills/codex-cso/SKILL.md"; then
    echo "  ${GREEN}PASS${RESET} claim 0.10.0 on the trigger skill; gate skills still cite their contract"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} claim not advanced, or a gate skill's contract citation was collaterally bumped"; FAIL=$((FAIL+1))
  fi

  # 13. Enforcement untouched — the point of the whole scope note.
  if grep -q 'hook-wrapper-plan-review.sh' "$REPO_ROOT/.codex/hooks.json" \
     && [ -f "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" ]; then
    echo "  ${GREEN}PASS${RESET} plan-review hook wiring untouched by the prose relocation"; PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} plan-review enforcement disturbed — prose moved but so did the hook"; FAIL=$((FAIL+1))
  fi
}

test_drift() {
  echo ""
  echo "${YELLOW}=== Drift — SKILL.md version == latest migration to_version ===${RESET}"

  # ── Leg 1: drift-target selection by semver-max to_version, NOT filename
  # sort (Phase 11, MIGR-10). The shared run_drift_test() MECHANISM (vendor/
  # agenticapps-shared/migrations/lib/drift-test.sh, pinned per ADR-0035)
  # selects the "latest" migration via `ls ... | sort | tail -1` — a FILENAME
  # sort. Migration 0010 is a version-BACKPORT into the 0.4.0->0.5.0 slot
  # migration 0007 occupies: 0010's filename sorts last (numerically highest
  # ID), but its to_version (0.5.0) is BELOW the real drift target (0.7.0,
  # from 0009's to_version). Feeding run_drift_test the migrations dir
  # directly would compare SKILL.md's 0.7.0 against 0010's 0.5.0 and report a
  # false mismatch. The drift target is therefore selected HERE, by this
  # consumer, as the semver-max `to_version` across every `migrations/*.md`
  # file — never by filename sort. This is consumer-owned POLICY (ADR-0035);
  # the pinned MECHANISM in vendor/agenticapps-shared is not edited to
  # implement it. Portable numeric-field sort — the GNU-only version-sort
  # flag is deliberately avoided (BSD sort on the macOS leg of the CI matrix
  # does not support it).
  local skill_md="$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md"
  local mig_dir="$REPO_ROOT/migrations"
  local drift_target skill_v_leg1
  drift_target="$(
    for f in "$mig_dir"/[0-9][0-9][0-9][0-9]-*.md; do
      grep -m1 '^to_version:' "$f" 2>/dev/null | awk '{print $2}'
    done | sort -t. -k1,1n -k2,2n -k3,3n | tail -1
  )"
  skill_v_leg1="$(grep -m1 '^version:' "$skill_md" 2>/dev/null | awk '{print $2}')"

  if [ -n "$drift_target" ] && [ "$skill_v_leg1" = "$drift_target" ]; then
    echo "  ${GREEN}PASS${RESET} SKILL.md version ($skill_v_leg1) matches the semver-max migration to_version ($drift_target)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} drift mismatch: SKILL.md version=$skill_v_leg1, semver-max migration to_version=$drift_target"
    FAIL=$((FAIL+1))
  fi

  # ── Consumer-side third leg (V-03) ──────────────────────────────────────────
  # The MECHANISM (run_drift_test above) is a pinned submodule and is NOT edited
  # here. The POLICY below is consumer-owned per ADR-0035: this repo self-applies
  # its own workflow, so its own version record (.codex/workflow-version.txt)
  # must agree with the scaffolder it ships (SKILL.md's `version:`). V-03 slipped
  # through precisely because nothing compared these two files — the leg above
  # only checks SKILL.md against the latest migration's to_version, never against
  # this repo's own record. 0008's `98c06f5` bumped both in one commit; this leg
  # is what makes that precedent enforceable going forward.
  local skill_v proj_v
  skill_v=$(grep -m1 '^version:' "$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md" | awk '{print $2}')
  proj_v=$(cat "$REPO_ROOT/.codex/workflow-version.txt" 2>/dev/null)
  if [ "$skill_v" = "$proj_v" ]; then
    echo "  ${GREEN}PASS${RESET} this repo's .codex/workflow-version.txt ($proj_v) agrees with its scaffolder SKILL.md"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} version split: SKILL.md=$skill_v but .codex/workflow-version.txt=$proj_v (V-03)"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Repo layout sanity checks
# These do not require fixtures; they verify the scaffolder itself
# ships the artifacts the migrations and skills reference.
# ─────────────────────────────────────────────────────────────────────────────

test_repo_layout() {
  echo ""
  echo "${YELLOW}=== Repo layout sanity ===${RESET}"

  for f in \
    skills/agentic-apps-workflow/SKILL.md \
    skills/setup-codex-agenticapps-workflow/SKILL.md \
    skills/update-codex-agenticapps-workflow/SKILL.md \
    skills/setup-codex-agenticapps-workflow/templates/workflow-config.md \
    skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md \
    skills/setup-codex-agenticapps-workflow/templates/config-hooks.json \
    skills/setup-codex-agenticapps-workflow/templates/config-knowledge-capture.json \
    skills/setup-codex-agenticapps-workflow/templates/obsidian-learnings-note.md \
    skills/setup-codex-agenticapps-workflow/templates/adr-db-security-acceptance.md \
    skills/setup-codex-agenticapps-workflow/templates/global-agents-additions.md \
    migrations/README.md \
    migrations/0000-baseline.md \
    migrations/0001-inject-spec-11-coding-discipline.md \
    migrations/0002-add-ts-declare-first-skill.md \
    migrations/0003-delegate-observability.md \
    migrations/0004-revendor-spec-11.md \
    migrations/0005-bind-upstream-gsd.md \
    migrations/0006-commit-planning-phases.md \
    migrations/0007-knowledge-capture.md \
    migrations/test-fixtures/README.md \
    docs/decisions/0008-knowledge-capture.md \
    docs/BINDING.md \
    docs/decisions/0007-bind-upstream-gsd.md \
    vendor/agenticapps-shared/migrations/lib/helpers.sh \
    vendor/agenticapps-shared/migrations/lib/drift-test.sh \
    docs/observability-delegation.md \
    docs/decisions/0005-adopt-observability-architecture.md \
    skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md \
    skills/codex-ts-declare-first/SKILL.md \
    skills/codex-ts-declare-first/templates/example.declare.ts \
    skills/codex-ts-declare-first/templates/example.test.ts \
    skills/codex-ts-declare-first/templates/example.impl.ts \
    skills/agentic-apps-workflow/scripts/check-plan-review.sh \
    skills/codex-plan-review/SKILL.md \
    migrations/0008-plan-review-gate.md \
    docs/decisions/0009-plan-review-gate.md \
    skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh \
    migrations/0011-native-plan-review-hook.md \
    install.sh ; do
    if [ -f "$f" ]; then
      echo "  ${GREEN}PASS${RESET} $f exists"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} $f MISSING"
      FAIL=$((FAIL+1))
    fi
  done

  # Update-path migration discovery: the update skill reads migrations at
  # ${CODEX_HOME}/skills/update-codex-agenticapps-workflow/migrations/. Because
  # the whole skill dir is symlinked into ~/.codex, a committed
  # `migrations -> ../../migrations` symlink exposes the canonical repo-root
  # migrations there. Without it, `$update-codex-agenticapps-workflow` discovers
  # zero migrations in target repos (regression guard).
  if [ -L skills/update-codex-agenticapps-workflow/migrations ] \
     && [ -f skills/update-codex-agenticapps-workflow/migrations/0006-commit-planning-phases.md ]; then
    echo "  ${GREEN}PASS${RESET} update skill migrations symlink resolves to repo-root migrations/"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} update skill migrations symlink missing/broken — \$update discovers no migrations"
    FAIL=$((FAIL+1))
  fi

  # Setup-path migration discovery: the setup skill walks 0000-baseline.md at
  # ${CODEX_HOME}/skills/setup-codex-agenticapps-workflow/migrations/. Same
  # committed-symlink mechanism as the update skill — without it, setup can't
  # find the baseline migration when run in a target repo (regression guard).
  if [ -L skills/setup-codex-agenticapps-workflow/migrations ] \
     && [ -f skills/setup-codex-agenticapps-workflow/migrations/0000-baseline.md ]; then
    echo "  ${GREEN}PASS${RESET} setup skill migrations symlink resolves to repo-root migrations/"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} setup skill migrations symlink missing/broken — setup can't find 0000-baseline"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0009 — Region-aware §11 placement  (TEST-02 / TEST-03)
#
# ⚠⚠ THIS SUITE IS **EXPECTED TO BE RED** UNTIL PLAN 09-04 SHIPS
#     migrations/0009-spec-11-region-aware-placement.md. THAT IS THE POINT.
#
# ROADMAP hard ordering 2 ("RED before GREEN"). Every assertion below is written
# against a migration document that does not exist yet, so the three extraction
# gates report empty-extraction failures and every case reports "not asserted".
#
#   DO NOT create or stub 0009 to make this pass — that is 09-04's job.
#   DO NOT weaken these assertions.
#   DO NOT add a "skip if the document is missing" guard. A conditional skip is
#   PRECISELY how a suite that never fails ships as coverage — the Phase 8
#   defect class this phase exists to close (D-36: "non-empty is not the same
#   as correct"; 08-05 shipped two assertions that could never match and read
#   as coverage). When 0009 lands, this function turns GREEN on its own.
#
# FIXTURE IDIOM IS LOCKED (D-34): ten case labels inside ONE function, each
# synthesized at test time via `printf` into `$tmp`. This is this repo's native
# idiom (`test_migration_0001`) and the documented fallback in
# migrations/test-fixtures/README.md § "Limits" (fixtures cannot capture state
# outside the repo, e.g. ~/.codex/skills/). Do NOT port claude-workflow's
# per-fixture directory layout (test-fixtures/0029/01-.../{setup,verify}.sh) —
# README.md § "Why no static fixture files" rejects exactly that, and porting it
# would introduce a second, competing fixture idiom.
#
# UPSTREAM REFERENCE IS PINNED (D-48): claude-workflow @
#   8520f90d235e0c50b0484b170d595ab6f2cd1173
# Fixture INTENT and content-generation logic are adopted from
# migrations/test-fixtures/0029/{common-setup.sh,common-verify.sh,NN-*/setup.sh}
# at that SHA; the layout is rejected. Read with `git -C ../claude-workflow show
# 8520f90:<path>`. Upstream HEAD has already moved past this pin (it moved twice
# during phase 9's planning alone); any later upstream change is a deliberate
# follow-up diff, not an invisible mid-execution scope change.
#
# SUBSHELL WRAPPING IS MANDATORY (T-09-07): two extracted paths deliberately
# `exit 3` (State D conflict; corrupt mirror). An un-subshelled eval would
# terminate the whole harness mid-suite and hide every later assertion.
# CODEX_HOME + cwd are always redirected into $tmp (T-09-10 / T-09-11): the
# fixtures perform real file surgery and deliberately build corrupt mirrors, so
# pointing them at the real repo or the real ~/.codex would rewrite the
# developer's own AGENTS.md / corrupt their installed scaffolder.
# ─────────────────────────────────────────────────────────────────────────────

# Helpers for test_migration_0009. File-scope with a `_m0009_` prefix, following
# this harness's established convention for per-test helpers (`_cpr_case`,
# `_cpr_check_resolved`, `_table_data_rows`, …) — shell has no function-local
# functions, and the prefix keeps them out of the shared namespace.

# _m0009_mk_fake_home <tmp> <name> <mirror_src>
# Builds a fake ${CODEX_HOME} carrying the spec mirror at the installed path, so
# an extracted block's `${CODEX_HOME:-$HOME/.codex}`-derived MIRROR/SPEC_BLOCK
# resolves to a controlled file under $tmp instead of the developer's real
# ~/.codex (T-09-10). Prints the fake home's path.
_m0009_mk_fake_home() {
  local h="$1/$2/codexhome"
  local m="$h/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors"
  mkdir -p "$m"
  cp "$3" "$m/11-coding-discipline-0.4.0.md"
  printf '%s\n' "$h"
}

# _m0009_mk_project <tmp> <name>
# Builds a scratch project root shaped like a REAL target project: a `.git`
# directory (`test -d .git`) plus `.codex/workflow-version.txt` at `0.6.0`
# (the durable per-project version record the update skill itself reads) —
# and DELIBERATELY NO local scaffolder-skill tree of any kind, because no
# target project this host scaffolds has one (`run-tests.sh:917-918`: "no
# 0008 sandbox here manufactures a synthetic SKILL.md" — the same rule
# applied here). See 0008's T-08-38 note (`0008:470-487`): the setup skill's
# project-side surface is `AGENTS.md`, `.planning/`, `.codex/`, and
# `docs/decisions/` only; a locally installed scaffolder SKILL.md never
# exists on a real install. Prints the project root's path.
_m0009_mk_project() {
  local p="$1/$2/proj"
  mkdir -p "$p/.git" "$p/.codex"
  printf '0.6.0\n' > "$p/.codex/workflow-version.txt"
  printf '%s\n' "$p"
}

# _m0009_apply <proj> <fake_home> <apply_text>
# Runs an extracted block against a scratch project. Prints its combined
# output; returns its exit status.
#
# THE SUBSHELL IS MANDATORY, NOT STYLE (T-09-07): cases 05 and 10 exercise
# blocks that deliberately `exit 3`. Un-subshelled, that would terminate the
# whole harness mid-suite and silently hide every later assertion — the suite
# would report a truncated PASS count and exit 0.
# CODEX_HOME and cwd are BOTH redirected under $tmp (T-09-10 / T-09-11): these
# blocks perform real file surgery and resolve their mirror from
# ${CODEX_HOME:-$HOME/.codex}. Run at the real repo root against the real Codex
# home, they would rewrite the developer's own AGENTS.md.
_m0009_apply() {
  ( cd "$1" && export CODEX_HOME="$2" && eval "$3" ) 2>&1
}

# _m0009_ok <rc> <label> — PASS iff rc is 0.
_m0009_ok() {
  if [ "$1" -eq 0 ]; then
    echo "  ${GREEN}PASS${RESET} $2"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $2"
    FAIL=$((FAIL+1))
  fi
}

# _m0009_fail <label> — unconditional FAIL. Used when an extraction gate is down
# so a case reports FAILED rather than silently vanishing. A case that quietly
# disappears when its input is missing is the dead-assertion defect itself.
_m0009_fail() {
  echo "  ${RED}FAIL${RESET} $1"
  FAIL=$((FAIL+1))
}

test_migration_0009() {
  echo ""
  echo "${YELLOW}=== Migration 0009 — Region-aware §11 placement ===${RESET}"

  local mirror="$REPO_ROOT/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
  if [ ! -f "$mirror" ]; then
    echo "  ${RED}FAIL${RESET} mirror missing: skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
    FAIL=$((FAIL+1)); return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  local MIGRATION_0009="$REPO_ROOT/migrations/0009-spec-11-region-aware-placement.md"
  local PROV_LIT='<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->'

  # ───────────────────────────────────────────────────────────────────────────
  # Extract 0009's own shell from 0009's own document (TEST-01), and gate every
  # consumer on a shape assertion first (D-36). Ported from the pin's
  # common-verify.sh, which sequences all three extractions + guards BEFORE any
  # fixture runs, so a document-shape drift reports as "extraction wrong" rather
  # than as a confusing downstream surgery failure.
  # ───────────────────────────────────────────────────────────────────────────
  local pf_block idem_block apply_block
  pf_block="$(extract_preflight_block "$MIGRATION_0009" 2>/dev/null)"
  idem_block="$(extract_step_block "$MIGRATION_0009" 1 "Idempotency check" 2>/dev/null)"
  apply_block="$(extract_step_block "$MIGRATION_0009" 1 Apply 2>/dev/null)"

  local pf_ok=1 idem_ok=1 apply_ok=1

  # Pre-flight shape guard.
  #
  # ANCHORED ON THE MIRROR PATH, deliberately — NOT on `test -s`, and NOT on a
  # variable name. Two reasons, both load-bearing:
  #
  #  1. The pin's common-verify.sh states the rule explicitly: anchor the shape
  #     check on what identifies the block STRUCTURALLY, "NOT on the specific
  #     guard operators (`test -s`, the tail-sentinel grep) that fixture 10
  #     exists to mutation-test. Coupling this shape check to the guard text
  #     itself would make reverting a guard trip the loader for EVERY fixture
  #     that sources this file, not just fixture 10 — masking the real signal
  #     behind a loader error instead." Case 10 below mutation-tests exactly
  #     those two operators, so gating the loader on one of them would hide the
  #     signal case 10 exists to produce.
  #  2. Upstream names this variable SPEC_BLOCK; this repo's 0004 precedent
  #     names it MIRROR, and 09-04 may legitimately pick either. The mirror
  #     PATH is invariant under that choice; a variable name is not.
  #
  # `test -s` and the tail-sentinel are still asserted — as explicit D-28.1
  # document-contract assertions immediately below, where a missing guard names
  # itself instead of masquerading as an extractor failure.
  assert_extracted_shape "0009 Pre-flight" "$pf_block" \
    'spec-mirrors/11-coding-discipline-0.4.0.md' || pf_ok=0

  # CR-03 fix: derive a COMMENT-STRIPPED view of the pre-flight before matching
  # either D-28.1 `case` below. A bare substring `case "$pf_block" in *'test -s'*`
  # matches the pre-flight's OWN COMMENTS at 0009:108/:120 ("`test -s` catches
  # that...") just as readily as the executable guard at :111 — so the guard can
  # be deleted entirely and this check stays green, satisfied by prose describing
  # a guard that no longer exists. A header that documents a guard is not the
  # guard. Match against $pf_code, never $pf_block, below.
  local pf_code
  pf_code="$(printf '%s\n' "$pf_block" | grep -v '^[[:space:]]*#')"

  # D-28.1 contract, layer 1 (zero-byte): `test -f` alone passes a zero-byte
  # mirror, and D-27 makes the mirror the SOLE re-injection source — so a
  # zero-byte mirror would strip §11 and inject nothing, silently committing a
  # maimed AGENTS.md on every heal. Asserted behaviorally by case 10(a).
  # Pattern tightened from the bare `*'test -s'*` to the executable shape
  # `*'test -s "$MIRROR"'*` — a check that only works by accident of comment
  # wording is one prose edit from being dead.
  case "$pf_code" in
    *'test -s "$MIRROR"'*) _m0009_ok 0 "0009 Pre-flight carries D-28.1 layer 1 (test -s — zero-byte mirror guard)" ;;
    *)                     _m0009_ok 1 "0009 Pre-flight carries D-28.1 layer 1 (test -s — zero-byte mirror guard)" ;;
  esac

  # D-28.1 contract, layer 2 (truncation): the mirror's heading is on L1, so a
  # tail-truncated mirror satisfies `test -s` AND Apply's pre-`mv` heading grep.
  # Only a tail sentinel closes that gap. Verified present at
  # 11-coding-discipline-0.4.0.md:57 (last of four `### ` sections, 79 lines).
  # This is NOT D-25's rejected content sentinel: that coupled a STRIP
  # TERMINATOR to §11's last prose line (runaway-strip hazard). This is a
  # read-only integrity check on a different file, anchored to a structural
  # heading; it bounds nothing and cannot run away. Asserted by case 10(b).
  # Also matched against $pf_code (CR-03): it does not collide with a comment
  # today, but a check that only works by accident of comment wording is one
  # prose edit from being dead, same as layer 1 above.
  case "$pf_code" in
    *'Goal-Driven Execution'*) _m0009_ok 0 "0009 Pre-flight carries D-28.1 layer 2 (tail sentinel — truncated mirror guard)" ;;
    *)                         _m0009_ok 1 "0009 Pre-flight carries D-28.1 layer 2 (tail sentinel — truncated mirror guard)" ;;
  esac

  # Idempotency-check shape guard: it must be identifiably the provenance-aware
  # region check.
  assert_extracted_shape "0009 Step 1 Idempotency check" "$idem_block" \
    'spec-source: agenticapps-workflow-core' || idem_ok=0

  # Apply shape guard: `gitnexus:start` is D-36's exact antidote here. A block
  # that carries no marker alternation is NOT Step 1's region-aware apply,
  # whatever else it is — 0001's and 0004's naive `/^## / && !done` apply blocks
  # both extract cleanly and both fail this guard, which is the point.
  assert_extracted_shape "0009 Step 1 Apply" "$apply_block" \
    'gitnexus:start' || apply_ok=0

  # ───────────────────────────────────────────────────────────────────────────
  # The four-state DOUBLE-SIDED idempotency table (D-38 / 09-VALIDATION.md).
  #
  # A check asserted in only one direction catches nothing: a too-permissive
  # check skips unapplied work, a too-strict one re-applies applied work. Each
  # state gets its own directory because the extracted check hardcodes
  # `AGENTS.md`, and assert_check cd's into the fixture dir.
  # ───────────────────────────────────────────────────────────────────────────

  # State A — genuinely OFF-ANCHOR but healthy: correct provenance, placed
  # BELOW a real project heading (not at the anchor this migration would
  # pick), and NO region anywhere in the file — position is the ONLY
  # variable. (V-02: the PRIOR version of this fixture put the block BEFORE
  # the first heading — i.e. exactly ON the anchor — while ALSO carrying a
  # trailing region, so it varied two things at once and its "off-anchor"
  # label read as coverage it did not provide. This rewrite isolates position
  # as the sole variable, per RESEARCH's off-anchor shape.)
  local sa="$tmp/state-a"; mkdir -p "$sa"
  {
    printf '# Title\n\nGuidance.\n\n'
    printf '## Project Overview\nStuff.\n\n'
    printf '%s\n' "$PROV_LIT"
    cat "$mirror"
    printf '\n## Deployment\nMore stuff.\n'
  } > "$sa/AGENTS.md"
  # Belt-and-braces self-guard, immune to the comment-matching hazard entirely
  # (CR-03's class): the GENERATED file has no comments to collide with, so
  # asserting on it directly cannot mistake a rewritten source comment for a
  # region. Checked unconditionally, not gated on idem_ok — a structural
  # property of the fixture itself, not a consumer of the extraction.
  [ "$(grep -c 'gitnexus' "$sa/AGENTS.md" 2>/dev/null)" = "0" ]
  _m0009_ok $? "state A self-guard: generated AGENTS.md carries no 'gitnexus' string anywhere (no region — position is the only variable)"

  # State B — provenance present BUT the block sits INSIDE the region.
  local sb="$tmp/state-b"; mkdir -p "$sb"
  {
    printf '# Title\n\nGuidance.\n\n'
    printf '<!-- gitnexus:start -->\n# GitNexus — Code Intelligence\n\n'
    printf '%s\n' "$PROV_LIT"
    cat "$mirror"
    printf '\n## Always Do\n- MUST run impact analysis.\n<!-- gitnexus:end -->\n\n'
    printf '## Workflow\nProject stuff.\n'
  } > "$sb/AGENTS.md"

  # State C — no provenance at all.
  local sc="$tmp/state-c"; mkdir -p "$sc"
  printf '# Title\n\n## Some Section\n\nbody\n' > "$sc/AGENTS.md"

  # D-32 variant — UNTERMINATED `<!-- gitnexus:start -->` (no matching end) with
  # provenance after it. No separate branch and no extra predicate: it rides on
  # State B's region predicate, which is exactly why D-32 chose the fail-closed
  # shape. Rejected alternatives: fail-open (leaves the block inside something
  # gitnexus may still regenerate — the very defect this closes) and exit 3
  # (adds a fifth state and blocks the version bump on a possibly benign shape).
  local sbu="$tmp/state-b-unterminated"; mkdir -p "$sbu"
  {
    printf '# Title\n\nGuidance.\n\n'
    printf '<!-- gitnexus:start -->\n# GitNexus — Code Intelligence\n\n'
    printf '%s\n' "$PROV_LIT"
    cat "$mirror"
    printf '\n## Always Do\n- MUST run impact analysis.\n'
  } > "$sbu/AGENTS.md"

  if [ "$idem_ok" = "1" ]; then
    # State A ⇒ applied (exit 0 → skip). This is ALSO MIGR-07's guard: a
    # healthy-but-off-anchor block must be left alone, and per D-31 that falls
    # out of THIS predicate rather than a special case — do not add code to
    # detect "off-anchor but healthy", and do not move it.
    assert_check "state A: anchored + current provenance + region later → skip (D-31/MIGR-07)" \
      "$idem_block" "$sa" "applied"

    # State B ⇒ not-applied (exit NON-ZERO **despite provenance being present**).
    #
    # ⚠ THIS ROW IS THE WHOLE POINT (D-38). The design calls this conjunction
    # exactly that: provenance alone must NOT short-circuit the heal. The check
    # must be `provenance present AND NOT in-region`, not `provenance present`.
    # A check that returns `applied` here IS THE DEFECT — it would skip a block
    # sitting inside a region that `gitnexus analyze` will later regenerate and
    # destroy. Expected argument is `not-applied`; if a future edit "fixes" this
    # to `applied` to make something pass, it has reintroduced the bug.
    assert_check "state B: provenance present BUT block in region → heal, not skip (D-38 — the whole point)" \
      "$idem_block" "$sb" "not-applied"

    # State C ⇒ not-applied. Plain absent case.
    assert_check "state C: no provenance at all → inject" \
      "$idem_block" "$sc" "not-applied"

    # D-32 fail-closed ⇒ not-applied, via State B's predicate.
    assert_check "state B (D-32 variant): unterminated gitnexus:start → fails closed, treated as in-region" \
      "$idem_block" "$sbu" "not-applied"
  else
    _m0009_fail "state A: anchored + current provenance + region later → skip (D-31/MIGR-07) — NOT ASSERTED: 0009's Step 1 Idempotency check could not be extracted"
    _m0009_fail "state B: provenance present BUT block in region → heal, not skip (D-38 — the whole point) — NOT ASSERTED: extraction failed"
    _m0009_fail "state C: no provenance at all → inject — NOT ASSERTED: extraction failed"
    _m0009_fail "state B (D-32 variant): unterminated gitnexus:start → fails closed — NOT ASSERTED: extraction failed"
  fi

  # State D — a `## Coding Discipline (NON-NEGOTIABLE)` heading with NO
  # provenance — is deliberately NOT asserted here. Per D-30 branch 1 and
  # 09-VALIDATION.md's table it is gated by the APPLY's conflict branch
  # (`exit 3`, file untouched), not by the idempotency check. It is asserted by
  # case `05-unmanaged-conflict` below. The four-state table is therefore
  # complete across this function: A/B/C (+ D-32) here, D at case 05.

  # ───────────────────────────────────────────────────────────────────────────
  # TEST-03's ten cases. Each synthesizes its BEFORE state with `printf` into
  # $tmp (D-34), runs the extracted Step 1 Apply against that scratch root, and
  # asserts the AFTER state. Case labels are carried in the assertion text so a
  # failure names itself.
  # ───────────────────────────────────────────────────────────────────────────
  local p h out rc prov_line start_line nstart nend nprov

  if [ "$apply_ok" = "1" ]; then

    # ── 01-gitnexus-led-inject (MIGR-04 — inject at the region-led anchor) ──
    # BEFORE: a gitnexus-LED file with no §11 anywhere (State C).
    # The first `## ` in this file is `## Always Do`, which is INSIDE the region
    # — that is what makes this case discriminating. The naive `/^## / && !done`
    # anchor (0001:91, 0004:77) lands on it and injects §11 inside a region that
    # `gitnexus analyze` later regenerates, destroying the block. D-21's rule
    # anchors on whichever comes FIRST — here the marker — so it lands above.
    # `## Some Section` sits AFTER the region deliberately: that ordering is what
    # discriminates D-21 from D-22.1's rejected "the region is always the anchor"
    # (which would drop §11 hundreds of lines down when the region comes late).
    p="$(_m0009_mk_project "$tmp" 01)"; h="$(_m0009_mk_fake_home "$tmp" 01 "$mirror")"
    {
      printf '# AGENTS.md\n\nThis file provides guidance to Codex.\n\n'
      printf '<!-- gitnexus:start -->\n# GitNexus — Code Intelligence\n\n'
      printf 'This project is indexed by GitNexus as **demo** (100 symbols).\n\n'
      printf '## Always Do\n- MUST run impact analysis before editing any symbol.\n\n'
      printf '## Never Do\n- NEVER rename symbols with find-and-replace.\n<!-- gitnexus:end -->\n\n'
      printf '## Some Section\nProject-specific stuff here.\n'
    } > "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    prov_line="$(grep -n -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null | head -1 | cut -d: -f1)"
    start_line="$(grep -n -x -- '<!-- gitnexus:start -->' "$p/AGENTS.md" 2>/dev/null | head -1 | cut -d: -f1)"
    [ -n "$prov_line" ] && [ -n "$start_line" ] && [ "$prov_line" -lt "$start_line" ]
    _m0009_ok $? "01-gitnexus-led-inject: provenance (line ${prov_line:-ABSENT}) is ABOVE gitnexus:start (line ${start_line:-ABSENT})"

    nstart="$(grep -c -x -- '<!-- gitnexus:start -->' "$p/AGENTS.md" 2>/dev/null)"
    nend="$(grep -c -x -- '<!-- gitnexus:end -->' "$p/AGENTS.md" 2>/dev/null)"
    [ "$nstart" = "1" ] && [ "$nend" = "1" ]
    _m0009_ok $? "01-gitnexus-led-inject: region markers still paired exactly once (start=$nstart end=$nend)"

    grep -q 'MUST run impact analysis before editing any symbol' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "01-gitnexus-led-inject: the region's own body content survived"

    # ── 02-inside-region-move (MIGR-03 — State B strip+reinject) ──
    # BEFORE: provenance + full mirror already sit INSIDE the region. This is
    # what the naive anchor produces on a gitnexus-led file. Not yet eaten; 0009
    # must move it out before the next `gitnexus analyze` does.
    #
    # THIS IS THE CASE THAT PROVES THE STRIP TERMINATOR'S ALTERNATION (D-24).
    # 09-01's counter-case B observed the narrow `/^## /`-only terminator EATING
    # the region here: it runs past `<!-- gitnexus:start -->` hunting a `## `,
    # consuming the marker and the region's real content, halting only at the
    # region's own `## Always Do` — leaving start=0/end=1, an orphaned unpaired
    # region. The marker-count assertion below is what catches that.
    p="$(_m0009_mk_project "$tmp" 02)"; h="$(_m0009_mk_fake_home "$tmp" 02 "$mirror")"
    {
      printf '# AGENTS.md\n\nGuidance.\n\n'
      printf '<!-- gitnexus:start -->\n# GitNexus — Code Intelligence\n\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n## Always Do\n- MUST run impact analysis.\n<!-- gitnexus:end -->\n\n'
      printf '## Workflow\nProject stuff.\n'
    } > "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    nprov="$(grep -c -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null)"
    [ "$nprov" = "1" ]
    _m0009_ok $? "02-inside-region-move: exactly ONE provenance line remains (found $nprov) — moved, not duplicated"

    prov_line="$(grep -n -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null | head -1 | cut -d: -f1)"
    start_line="$(grep -n -x -- '<!-- gitnexus:start -->' "$p/AGENTS.md" 2>/dev/null | head -1 | cut -d: -f1)"
    [ -n "$prov_line" ] && [ -n "$start_line" ] && [ "$prov_line" -lt "$start_line" ]
    _m0009_ok $? "02-inside-region-move: provenance (line ${prov_line:-ABSENT}) moved ABOVE gitnexus:start (line ${start_line:-ABSENT})"

    nstart="$(grep -c -x -- '<!-- gitnexus:start -->' "$p/AGENTS.md" 2>/dev/null)"
    nend="$(grep -c -x -- '<!-- gitnexus:end -->' "$p/AGENTS.md" 2>/dev/null)"
    [ "$nstart" = "1" ] && [ "$nend" = "1" ] && grep -q 'MUST run impact analysis' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "02-inside-region-move: region survived intact and paired (start=$nstart end=$nend) — the D-24 terminator assertion"

    # ── 03-healthy-noop (MIGR-02, MIGR-07 — zero churn) ──
    # BEFORE: this repo's own real AGENTS.md shape — §11 correctly anchored at
    # the first `## `, region LATER in the file (State A).
    #
    # WHY APPLY IS RUN HERE EVEN THOUGH THE RUNTIME WOULD SKIP IT: in real
    # operation State A's idempotency check returns `applied`, so the runtime
    # skips Step 1 entirely — that skip is already asserted by the State A row
    # above. If this case ALSO merely skipped Apply, `cmp -s` would compare a
    # file nothing had touched and pass unconditionally: a dead assertion, and
    # exactly the defect class this phase exists to close. The plan's stated
    # purpose for this case is to "catch an over-eager anchor", and an over-eager
    # anchor can only manifest if Apply RUNS. So Apply is run deliberately, and
    # byte-identity is asserted against a pristine copy — the fixture-level twin
    # of 09-01's CASE 1 (ANCHOR-03), which observed strip+insert re-deriving
    # §11's position byte-identically on the real AGENTS.md.
    #
    # NOT VACUOUS: the strip genuinely removes 81 lines (provenance + 79 mirror
    # lines + the trailing blank) and the insert genuinely re-adds them; a strip
    # that silently did nothing would make the insert add a SECOND block and fail
    # this cmp. `grep`-based "block still present" would pass for an over-eager
    # anchor that MOVED the block — byte-identity is the assertion that does not.
    p="$(_m0009_mk_project "$tmp" 03)"; h="$(_m0009_mk_fake_home "$tmp" 03 "$mirror")"
    {
      printf '# AGENTS.md\n\nGuidance.\n\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n## Project Overview\nStuff.\n\n'
      printf '<!-- gitnexus:start -->\n# GitNexus\n\n## Always Do\n- x\n<!-- gitnexus:end -->\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$tmp/03-pristine.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    cmp -s "$p/AGENTS.md" "$tmp/03-pristine.md"
    _m0009_ok $? "03-healthy-noop: AGENTS.md is BYTE-IDENTICAL after Apply (zero churn — catches an over-eager anchor)"

    # ── 04-no-agentsmd (D-33 — informational skip, NOT an abort) ──
    # BEFORE: a project with no AGENTS.md at all.
    #
    # WHY A SKIP AND NOT 0004's PRE-FLIGHT ABORT (0004:44): the update engine
    # marks a migration pending iff `installed >= from && installed < to`. An
    # abort here leaves the project at 0.6.0 forever — Step 2 never records
    # 0.7.0, so 0009 stays pending AND 0010+ never become pending either. The
    # project is stranded below to_version PERMANENTLY. A skip costs nothing;
    # an abort is unrecoverable without manual intervention.
    p="$(_m0009_mk_project "$tmp" 04)"; h="$(_m0009_mk_fake_home "$tmp" 04 "$mirror")"
    rm -f "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 0 ]
    _m0009_ok $? "04-no-agentsmd: Apply exits ZERO (informational skip, so Step 2's version bump still runs) — got exit=$rc"

    case "$out" in
      *update-codex-agenticapps-workflow*) _m0009_ok 0 "04-no-agentsmd: skip message names THIS host's skill (update-codex-agenticapps-workflow), not claude-workflow's slug" ;;
      *)                                   _m0009_ok 1 "04-no-agentsmd: skip message names THIS host's skill (update-codex-agenticapps-workflow), not claude-workflow's slug" ;;
    esac

    [ ! -f "$p/AGENTS.md" ]
    _m0009_ok $? "04-no-agentsmd: Apply created no AGENTS.md out of thin air"

    # ── 16-zero-byte-agentsmd (09.1-REVIEW.md WR-01 — the "nothing to heal"
    #    twin of 04-no-agentsmd) ──
    # BEFORE: AGENTS.md is PRESENT but zero bytes (e.g. `touch AGENTS.md`, an
    # interrupted write, or a prior tool crash). `test -f` PASSES on an empty
    # file — that is precisely the gap: the pre-fix Apply routes this past the
    # `[ ! -f AGENTS.md ]` skip branch, into the strip, which runs on zero
    # input, produces zero-byte output, and hard-ABORTS (exit 3) at the
    # strip-output guard with a diagnostic that says "possibly-truncated
    # result" — misleading, since nothing was truncated; the input was already
    # empty. Per WR-01's fix and the user's binding ruling: a zero-byte
    # AGENTS.md is materially identical to a missing one — "nothing to heal" —
    # and must route through the SAME informational-skip branch as
    # 04-no-agentsmd, not an abort. An abort here is UNRECOVERABLE by this
    # migration's own stated design principle (Step 2 never records 0.7.0, so
    # 0009 stays pending forever and 0010+ never become pending either).
    p="$(_m0009_mk_project "$tmp" 16)"; h="$(_m0009_mk_fake_home "$tmp" 16 "$mirror")"
    : > "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 0 ]
    _m0009_ok $? "16-zero-byte-agentsmd: Apply exits ZERO on a zero-byte AGENTS.md (informational skip, not the unrecoverable abort) — got exit=$rc"

    case "$out" in
      *'possibly-truncated'*) _m0009_ok 1 "16-zero-byte-agentsmd: diagnostic is NOT the misleading 'possibly-truncated result' message (input was already empty, nothing was truncated)" ;;
      *)                      _m0009_ok 0 "16-zero-byte-agentsmd: diagnostic is NOT the misleading 'possibly-truncated result' message (input was already empty, nothing was truncated)" ;;
    esac

    case "$out" in
      *update-codex-agenticapps-workflow*) _m0009_ok 0 "16-zero-byte-agentsmd: skip message names THIS host's skill (update-codex-agenticapps-workflow), matching 04's skip path" ;;
      *)                                   _m0009_ok 1 "16-zero-byte-agentsmd: skip message names THIS host's skill (update-codex-agenticapps-workflow), matching 04's skip path" ;;
    esac

    [ -f "$p/AGENTS.md" ] && [ ! -s "$p/AGENTS.md" ]
    _m0009_ok $? "16-zero-byte-agentsmd: AGENTS.md still exists and is still zero bytes after the skip (untouched, not deleted or rewritten)"

    # ── 05-unmanaged-conflict (MIGR-05, State D — D-30 branch 1) ──
    # BEFORE: a §11 heading with hand-written prose and NO provenance. The
    # operator pasted it outside this migration's management. 0009 must refuse
    # rather than clobber it (inherits 0001's conflict rule).
    #
    # BOTH HALVES ARE REQUIRED: an `exit 3` that already mangled the file is
    # still a destroyed hand-authored §11. Asserting only the exit code would
    # pass for a block that rewrote AGENTS.md and then errored.
    p="$(_m0009_mk_project "$tmp" 05)"; h="$(_m0009_mk_fake_home "$tmp" 05 "$mirror")"
    {
      printf '# AGENTS.md\n\n## Coding Discipline (NON-NEGOTIABLE)\n\n'
      printf 'Hand-pasted content the operator wrote themselves. Must not be clobbered.\n\n'
      printf '## Workflow\nStuff.\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$tmp/05-pristine.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 3 ]
    _m0009_ok $? "05-unmanaged-conflict: Apply exits exactly 3 on an unmanaged §11 heading (State D) — got exit=$rc"

    cmp -s "$p/AGENTS.md" "$tmp/05-pristine.md"
    _m0009_ok $? "05-unmanaged-conflict: hand-written §11 is BYTE-IDENTICAL after the refusal (refused AND untouched)"

    # ── 06-no-heading-eof (ANCHOR-02 — the END fallback) ──
    # BEFORE: no `## ` heading and no marker anywhere. The anchor scan finds
    # nothing, so awk's END branch must APPEND rather than silently drop the
    # block. Without the END branch the insert is a no-op and §11 vanishes.
    p="$(_m0009_mk_project "$tmp" 06)"; h="$(_m0009_mk_fake_home "$tmp" 06 "$mirror")"
    printf '# AGENTS.md\n\nJust prose. No level-2 headings anywhere in this file.\n' > "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    grep -q -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "06-no-heading-eof: provenance is present after Apply (END fallback fired, block not dropped)"

    prov_line="$(grep -n -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null | head -1 | cut -d: -f1)"
    [ -n "$prov_line" ] && [ "$prov_line" -gt 3 ]
    _m0009_ok $? "06-no-heading-eof: block was APPENDED at EOF (provenance at line ${prov_line:-ABSENT}, below the 3 lines of pre-existing prose)"

    # ── 09-two-provenance-heal (D-46.3 — the `swallowed_own_h2` stale-state guard) ──
    # BEFORE: TWO provenance+block pairs, each properly terminated by a real
    # project `## ` heading (not back-to-back). Must heal down to exactly one.
    #
    # THE MECHANISM THIS GUARDS, PRECISELY: the strip pass must swallow each
    # block's OWN `## Coding Discipline (NON-NEGOTIABLE)` heading before it starts
    # hunting for that block's terminator — otherwise the block's own heading
    # terminates its own strip immediately. That is what `swallowed_own_h2` is for.
    # But it MUST RESET at the terminator. If it is stale-true when the SECOND
    # provenance line arrives, the second block's own `## Coding Discipline`
    # heading is mistaken for ITS terminator, so the strip stops there and the
    # second block's body is left orphaned in the output — two blocks in, two
    # blocks out, healed nothing. Upstream hit this and fixed it; without this
    # fixture we would not catch the regression.
    #
    # The surviving-headings assertion is the other half: a terminator that
    # over-runs would eat `## Workflow` / `## Deployment` along with the block.
    p="$(_m0009_mk_project "$tmp" 09)"; h="$(_m0009_mk_fake_home "$tmp" 09 "$mirror")"
    {
      printf '# AGENTS.md\n\nThis file provides guidance to Codex.\n\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n'
      printf '## Workflow\nFirst project section.\n\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n'
      printf '## Deployment\nSecond project section.\n'
    } > "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    nprov="$(grep -c -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null)"
    [ "$nprov" = "1" ]
    _m0009_ok $? "09-two-provenance-heal: healed down to exactly ONE provenance line (found $nprov) — swallowed_own_h2 reset at the terminator"

    grep -q -x -- '## Workflow' "$p/AGENTS.md" 2>/dev/null \
      && grep -q -x -- '## Deployment' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "09-two-provenance-heal: both terminating '## ' headings survived (## Workflow, ## Deployment) — the strip did not over-run"

    # ── 12-idempotent-rerun (ANCHOR-05 / MIGR-06 — the highest-value gap this
    #    phase produced, per 09-REVIEW.md) ──
    # BEFORE state is NOT hand-written: it is case 01-gitnexus-led-inject's
    # BEFORE fixture (a region-LED file, no §11 anywhere), run through Apply
    # ONCE to produce a genuinely healed region-led AGENTS.md, then Apply is
    # run a SECOND time against that same output. Building the BEFORE this way
    # means the fixture cannot drift from what 0009 actually emits — a
    # hand-authored "healed" file would silently stop testing the re-run path
    # the moment the insert's exact output shape changed.
    #
    # WHY THIS SHAPE SPECIFICALLY: 0009's own prose (Step 1 Apply, near the
    # strip terminator) calls a `/^## /`-only terminator "the highest-severity
    # mechanic in this migration" because it "skips straight past
    # `<!-- gitnexus:start -->` on a file this migration has already healed."
    # A re-run against an OFF-ANCHOR-BUT-HEALTHY file (state A) never reaches
    # the strip's terminator at all — the idempotency check short-circuits
    # Apply entirely — so state A cannot exercise this. Only a REGION-LED
    # healed file (healed block immediately followed by
    # `<!-- gitnexus:start -->`, not by a `## `) puts the terminator's
    # alternation on the critical path of an ordinary second run. This is
    # ANCHOR-05's ONLY live suite coverage: the anchor and the terminator are
    # one decision, not two, and this fixture is what proves they still move
    # together.
    p="$(_m0009_mk_project "$tmp" 12)"; h="$(_m0009_mk_fake_home "$tmp" 12 "$mirror")"
    {
      printf '# AGENTS.md\n\nThis file provides guidance to Codex.\n\n'
      printf '<!-- gitnexus:start -->\n# GitNexus — Code Intelligence\n\n'
      printf 'This project is indexed by GitNexus as **demo** (100 symbols).\n\n'
      printf '## Always Do\n- MUST run impact analysis before editing any symbol.\n\n'
      printf '## Never Do\n- NEVER rename symbols with find-and-replace.\n<!-- gitnexus:end -->\n\n'
      printf '## Some Section\nProject-specific stuff here.\n'
    } > "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?
    cp "$p/AGENTS.md" "$tmp/12-first-run.md"

    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 0 ]
    _m0009_ok $? "12-idempotent-rerun: second Apply against an already-healed region-led file exits 0 — got exit=$rc"

    cmp -s "$p/AGENTS.md" "$tmp/12-first-run.md"
    _m0009_ok $? "12-idempotent-rerun: second run leaves AGENTS.md BYTE-IDENTICAL to the first run's output (true idempotency, MIGR-06)"

    nstart="$(grep -c -x -- '<!-- gitnexus:start -->' "$p/AGENTS.md" 2>/dev/null)"
    nend="$(grep -c -x -- '<!-- gitnexus:end -->' "$p/AGENTS.md" 2>/dev/null)"
    [ "$nstart" = "1" ] && [ "$nend" = "1" ]
    _m0009_ok $? "12-idempotent-rerun: region markers still paired exactly once each (start=$nstart end=$nend) — ANCHOR-05's only live suite coverage"

    grep -q 'MUST run impact analysis before editing any symbol' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "12-idempotent-rerun: the region's own body content survived the second run"

    nprov="$(grep -c -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null)"
    [ "$nprov" = "1" ]
    _m0009_ok $? "12-idempotent-rerun: exactly ONE provenance line remains after the second run (found $nprov)"

    # ── 17-crlf-region-led (09.1-REVIEW.md CR-01 — D-38 double-sided) ──
    # Same region-led BEFORE shape as 01-gitnexus-led-inject (no §11 yet, the
    # first `## ` is INSIDE the region), built twice: (a) with CRLF line
    # endings, (b) with ordinary LF line endings. This is the ONLY structural
    # variable between the two sub-cases.
    #
    # WHY (a) MUST REFUSE: every `$`-anchored regex this migration depends on
    # (the strip terminator's `/^<!-- gitnexus:start -->$/` alternative, the
    # insert anchor's twin) does NOT match a `\r`-terminated line — the `\r`
    # sits between the matched text and the record's true end, in standard
    # POSIX awk (gawk/mawk/BWK awk all agree). The unanchored `/^## /`
    # alternative is unaffected. On THIS fixture that asymmetry lands the §11
    # block INSIDE `<!-- gitnexus:start -->` while Apply reports success —
    # reproducing the exact defect this migration exists to fix, silently.
    # Per the user's binding ruling: fail closed. Refuse, do not normalize.
    #
    # WHY (b) MUST ACCEPT (D-38's other half — a guard never observed
    # accepting is a brick wall, not a guard): an ordinary LF file with the
    # identical byte content must heal exactly as 01-gitnexus-led-inject does.
    # If the CRLF guard fired on (b) too, it would be a brick wall, not a
    # guard — this is what actually proves the guard is CRLF-specific.
    local s17
    {
      printf '# AGENTS.md\n\nThis file provides guidance to Codex.\n\n'
      printf '<!-- gitnexus:start -->\n# GitNexus — Code Intelligence\n\n'
      printf 'This project is indexed by GitNexus as **demo** (100 symbols).\n\n'
      printf '## Always Do\n- MUST run impact analysis before editing any symbol.\n\n'
      printf '## Never Do\n- NEVER rename symbols with find-and-replace.\n<!-- gitnexus:end -->\n\n'
      printf '## Some Section\nProject-specific stuff here.\n'
    } > "$tmp/17-source.md"

    # (a) CRLF variant.
    p="$(_m0009_mk_project "$tmp" 17a)"; h="$(_m0009_mk_fake_home "$tmp" 17a "$mirror")"
    awk '{ printf "%s\r\n", $0 }' "$tmp/17-source.md" > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$tmp/17a-pristine.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 3 ]
    _m0009_ok $? "17-crlf-region-led (a) CRLF: Apply refuses with exit 3 rather than mis-anchor inside the region — got exit=$rc"

    cmp -s "$p/AGENTS.md" "$tmp/17a-pristine.md"
    _m0009_ok $? "17-crlf-region-led (a) CRLF: AGENTS.md is BYTE-IDENTICAL after the refusal (fail-closed, not normalized/rewritten)"

    case "$out" in
      *'CRLF'*) _m0009_ok 0 "17-crlf-region-led (a) CRLF: diagnostic names CRLF as the cause" ;;
      *)        _m0009_ok 1 "17-crlf-region-led (a) CRLF: diagnostic names CRLF as the cause" ;;
    esac

    case "$out" in
      *'perl -pi -e'*) _m0009_ok 0 "17-crlf-region-led (a) CRLF: diagnostic states a concrete, actionable remedy command (the user's binding ruling — a refusal without a stated remedy is not acceptable)" ;;
      *)               _m0009_ok 1 "17-crlf-region-led (a) CRLF: diagnostic states a concrete, actionable remedy command" ;;
    esac

    case "$out" in
      *update-codex-agenticapps-workflow*) _m0009_ok 0 "17-crlf-region-led (a) CRLF: diagnostic names the re-run command after the remedy" ;;
      *)                                   _m0009_ok 1 "17-crlf-region-led (a) CRLF: diagnostic names the re-run command after the remedy" ;;
    esac

    # (b) LF variant — the D-38 accept direction. Same content, ordinary line
    # endings; must heal exactly like 01-gitnexus-led-inject.
    p="$(_m0009_mk_project "$tmp" 17b)"; h="$(_m0009_mk_fake_home "$tmp" 17b "$mirror")"
    cp "$tmp/17-source.md" "$p/AGENTS.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 0 ]
    _m0009_ok $? "17-crlf-region-led (b) LF (accept direction): Apply exits 0 on an ordinary LF file — the CRLF guard must NOT fire here — got exit=$rc"

    prov_line="$(grep -n -F -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null | head -1 | cut -d: -f1)"
    start_line="$(grep -n -x -- '<!-- gitnexus:start -->' "$p/AGENTS.md" 2>/dev/null | head -1 | cut -d: -f1)"
    [ -n "$prov_line" ] && [ -n "$start_line" ] && [ "$prov_line" -lt "$start_line" ]
    _m0009_ok $? "17-crlf-region-led (b) LF (accept direction): provenance (line ${prov_line:-ABSENT}) lands ABOVE gitnexus:start (line ${start_line:-ABSENT}), same as 01-gitnexus-led-inject"

    case "$out" in
      *'CRLF'*) _m0009_ok 1 "17-crlf-region-led (b) LF (accept direction): diagnostic does NOT mention CRLF (guard is CRLF-specific, not a brick wall)" ;;
      *)        _m0009_ok 0 "17-crlf-region-led (b) LF (accept direction): diagnostic does NOT mention CRLF (guard is CRLF-specific, not a brick wall)" ;;
    esac

  else
    # The Apply extraction gate is DOWN. Report every case as FAILED rather than
    # skipping it. A case that silently vanishes when its input is missing is the
    # dead-assertion defect wearing a different hat: the suite would exit 0 and
    # read as coverage.
    _m0009_fail "01-gitnexus-led-inject — NOT ASSERTED: 0009's Step 1 Apply could not be extracted (the 0009 document does not exist yet)"
    _m0009_fail "02-inside-region-move — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "03-healthy-noop — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "04-no-agentsmd — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "16-zero-byte-agentsmd: Apply exits ZERO on a zero-byte AGENTS.md — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "16-zero-byte-agentsmd: diagnostic is NOT the misleading 'possibly-truncated result' message — NOT ASSERTED: extraction failed"
    _m0009_fail "16-zero-byte-agentsmd: skip message names THIS host's skill — NOT ASSERTED: extraction failed"
    _m0009_fail "16-zero-byte-agentsmd: AGENTS.md still exists and is still zero bytes after the skip — NOT ASSERTED: extraction failed"
    _m0009_fail "05-unmanaged-conflict — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "06-no-heading-eof — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "09-two-provenance-heal — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "12-idempotent-rerun — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "17-crlf-region-led (a) CRLF: Apply refuses with exit 3 — NOT ASSERTED: extraction failed"
    _m0009_fail "17-crlf-region-led (a) CRLF: AGENTS.md is BYTE-IDENTICAL after the refusal — NOT ASSERTED: extraction failed"
    _m0009_fail "17-crlf-region-led (a) CRLF: diagnostic names CRLF as the cause — NOT ASSERTED: extraction failed"
    _m0009_fail "17-crlf-region-led (a) CRLF: diagnostic states a concrete, actionable remedy command — NOT ASSERTED: extraction failed"
    _m0009_fail "17-crlf-region-led (a) CRLF: diagnostic names the re-run command after the remedy — NOT ASSERTED: extraction failed"
    _m0009_fail "17-crlf-region-led (b) LF (accept direction): Apply exits 0 — NOT ASSERTED: extraction failed"
    _m0009_fail "17-crlf-region-led (b) LF (accept direction): provenance lands ABOVE gitnexus:start — NOT ASSERTED: extraction failed"
    _m0009_fail "17-crlf-region-led (b) LF (accept direction): diagnostic does NOT mention CRLF — NOT ASSERTED: extraction failed"
  fi

  # ── 07-prose-mention-not-a-region (D-46.1 — forces D-21's ANCHORED regex) ──
  # BEFORE: an HTML comment near the top MENTIONS the marker inside backticks, so
  # the line is NOT exactly `<!-- gitnexus:start -->`; the §11 block is correctly
  # anchored right after that comment; there is NO real region anywhere.
  #
  # THIS CASE IS A DEAD-ASSERTION DETECTOR BY DESIGN (09-VALIDATION.md Dimension 8
  # item 4). A SUBSTRING marker match passes every OTHER fixture in this suite and
  # fails ONLY here: it would see the prose mention, judge the file in-region, and
  # return `not-applied` — proposing to "heal" a perfectly healthy file by moving
  # §11 above a region that does not exist. The anchored `/^...$/` regex returns
  # `applied` (skip). If this case ever passes with a substring match, the fixture
  # is wrong and must be rewritten, not the assertion relaxed.
  if [ "$idem_ok" = "1" ]; then
    local s07="$tmp/state-07"; mkdir -p "$s07"
    {
      printf '<!--\n'
      printf '  This block MUST stay ABOVE the `<!-- gitnexus:start -->` region below.\n'
      printf '  This is prose ONLY — this fixture file has no real region.\n'
      printf -- '-->\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n## Project Overview\nStuff. No GitNexus region anywhere in this file.\n'
    } > "$s07/AGENTS.md"
    assert_check "07-prose-mention-not-a-region: a prose mention of the marker is NOT a region → skip (D-21 anchored regex)" \
      "$idem_block" "$s07" "applied"
  else
    _m0009_fail "07-prose-mention-not-a-region — NOT ASSERTED: Step 1 Idempotency check extraction failed"
  fi

  # ── 11-prose-mention-provenance (CR-02 — 07's PROVENANCE twin) ──
  # PORTED, not re-derived, from `claude-workflow f9354cc`
  # (migrations/test-fixtures/0029/11-prose-mention-provenance/{setup,verify}.sh,
  # PR #89), which fixed CR-02 upstream before we did. Verified before reading:
  # `git -C ../claude-workflow fetch && git log --oneline -1 origin/main` is
  # STILL `f9354cc` as of this port. Re-deriving would risk prose divergence
  # from the exact fixture this repo's 0009 is a port of; validated across six
  # repos upstream.
  #
  # 07 above proves the REGION marker (`gitnexus:start`) is anchored (`^...$`);
  # this is the PROVENANCE marker's twin — it proves `PROV_RE` must be too.
  # BEFORE: a guard comment near the top MENTIONS the provenance marker in
  # prose (indented inside an HTML comment, not a whole-line match), followed
  # by real project content ("IMPORTANT PROJECT RULE...") an unanchored
  # PROV_RE would destroy, THEN the real, correctly-placed §11 block with NO
  # GitNexus region anywhere in the file. Translated: upstream's CLAUDE.md →
  # this repo's AGENTS.md; upstream's per-directory setup.sh/verify.sh harness
  # → this repo's inline _m0009_mk_project + _m0009_mk_fake_home + _m0009_apply
  # idiom.
  #
  # THIS IS ALSO A DEAD-ASSERTION DETECTOR, mirroring 07's design (09-VALIDATION.md
  # Dimension 8 item 4): the real block is already healthy and un-regioned, so
  # this MUST be a legitimate heal/no-op — rc 0, NOT a refusal. An unanchored
  # PROV_RE substring-matches the prose line, enters `in_block` there instead
  # of at the real marker, and (per fixture 13/14's mechanism above) destroys
  # everything between the prose mention and the block's own heading — upstream
  # measured this turning their 91-line fixture into 85 lines.
  if [ "$apply_ok" = "1" ]; then
    p="$(_m0009_mk_project "$tmp" 11)"; h="$(_m0009_mk_fake_home "$tmp" 11 "$mirror")"
    {
      printf '<!--\n'
      printf '  The §11 block is anchored behind\n'
      printf '  %s below.\n' "$PROV_LIT"
      printf '  This is prose ONLY — the real marker is further down.\n'
      printf -- '-->\n'
      printf '\n'
      printf 'IMPORTANT PROJECT RULE: never deploy on Friday.\n'
      printf '\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n## Project Overview\nStuff. No GitNexus region anywhere in this file.\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$p/AGENTS.md.before"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 0 ]
    _m0009_ok $? "11-prose-mention-provenance: rc is 0 — a legitimate heal/no-op, NOT a refusal (the anchored regex must not turn a prose mention into a refuse-gate trigger either) — got exit=$rc, before=$(wc -l < "$p/AGENTS.md.before" | tr -d ' ') after=$(wc -l < "$p/AGENTS.md" | tr -d ' ') lines"

    grep -q 'IMPORTANT PROJECT RULE' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "11-prose-mention-provenance: content between the prose mention and the next heading survives ('IMPORTANT PROJECT RULE') — the content-survival assertion (CR-02's independent second reproduction)"

    nprov="$(grep -c -x -- "$PROV_LIT" "$p/AGENTS.md" 2>/dev/null)"
    [ "$nprov" = "1" ]
    _m0009_ok $? "11-prose-mention-provenance: exactly ONE real (whole-line) provenance line remains after Apply (found $nprov)"

    grep -q -F -- '  The §11 block is anchored behind' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "11-prose-mention-provenance: the prose-mention guard-comment line survives verbatim in the after-state"
  else
    _m0009_fail "11-prose-mention-provenance: rc is 0 — a legitimate heal/no-op — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "11-prose-mention-provenance: content between the prose mention and the next heading survives — NOT ASSERTED: extraction failed"
    _m0009_fail "11-prose-mention-provenance: exactly ONE real provenance line remains after Apply — NOT ASSERTED: extraction failed"
    _m0009_fail "11-prose-mention-provenance: the prose-mention guard-comment line survives verbatim — NOT ASSERTED: extraction failed"
  fi

  # ── 08-rollback-region-led (D-46.2, kept even under D-47) ──
  # 0009's Rollback is `git checkout AGENTS.md` (D-47), so the region-eating-
  # rollback bug class is STRUCTURALLY UNREACHABLE here — there is no terminator
  # to get wrong. This case is therefore a REGRESSION GUARD ON THAT CHOICE, and it
  # is asserted against the migration DOCUMENT rather than by executing awk.
  #
  # Its purpose is to fail loudly if a future author "improves" Rollback into the
  # custom awk that upstream's fixture 08 exists to catch a file-destroying bug in
  # (running that awk on a healed region-led file eats the start marker and the
  # region's real content, leaving an orphaned, unpaired `<!-- gitnexus:end -->` —
  # verified empirically upstream, and replayed as 09-01's counter-case B).
  #
  # Scoped from Step 1's `**Rollback:**` line to `### Step 2` deliberately, rather
  # than via extract_step_block: with no fence inside Step 1's Rollback, that
  # helper's `want` flag would stay armed past `### Step 2` and latch onto Step 2's
  # Apply fence, so a "no awk here" assertion would pass by inspecting the WRONG
  # block. (Harmless for 0009's real consumers — Apply and Idempotency check both
  # have fences inside their own step — and assert_extracted_shape would catch it
  # regardless. Noted, not fixed: 09-02's helper is out of this plan's scope.)
  local rb_scope
  rb_scope="$(awk '
    index($0, "### Step 1") == 1 { in1=1; next }
    index($0, "### Step 2") == 1 { exit }
    in1 && index($0, "**Rollback:**") == 1 { r=1 }
    r { print }
  ' "$MIGRATION_0009" 2>/dev/null)"

  case "$rb_scope" in
    *'git checkout AGENTS.md'*) _m0009_ok 0 "08-rollback-region-led: Step 1 Rollback is 'git checkout AGENTS.md' (D-47 — structurally immune, no terminator to get wrong)" ;;
    *)                          _m0009_ok 1 "08-rollback-region-led: Step 1 Rollback is 'git checkout AGENTS.md' (D-47 — structurally immune, no terminator to get wrong)" ;;
  esac

  # Both halves required: the literal alone would still pass if someone ADDED an
  # awk block alongside it.
  if [ -n "$rb_scope" ] && ! printf '%s' "$rb_scope" | grep -q 'awk'; then
    _m0009_ok 0 "08-rollback-region-led: Step 1 Rollback carries NO fenced awk block — the region-eating bug class stays unreachable"
  else
    _m0009_ok 1 "08-rollback-region-led: Step 1 Rollback carries NO fenced awk block — the region-eating bug class stays unreachable"
  fi

  # ── 10-corrupt-mirror-refused (D-46.4 — binds BOTH D-28.1 guard layers) ──
  # Exercises the PRE-FLIGHT, not Step 1, because the mirror guards live there.
  # D-27 makes the mirror the SOLE re-injection source, so a mirror that exists
  # but is corrupt makes 0009 strip §11 and inject garbage — destroying §11 on
  # every heal. Each mode gets its OWN fake home so the modes are independent and
  # cannot depend on execution order. mk_project supplies `.git` +
  # `.codex/workflow-version.txt` at 0.6.0 (no local `skills/` tree — see
  # `_m0009_mk_project`'s own header comment, 09.1-01), so the pre-flight's
  # other guards pass and THE MIRROR IS THE ONLY VARIABLE — otherwise a
  # refusal could come from the version gate instead and the assertion would
  # pass for the wrong reason.
  if [ "$pf_ok" = "1" ]; then
    local h10a h10b h10c p10
    p10="$(_m0009_mk_project "$tmp" 10)"

    # (a) ZERO-BYTE mirror → the `test -s` layer. `test -f` alone PASSES here —
    #     that is the exact gap upstream closed (an interrupted `git pull` in the
    #     scaffolder clone leaves precisely this).
    h10a="$(_m0009_mk_fake_home "$tmp" 10a "$mirror")"
    : > "$h10a/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
    out="$(_m0009_apply "$p10" "$h10a" "$pf_block")"; rc=$?
    [ "$rc" -eq 3 ]
    _m0009_ok $? "10-corrupt-mirror-refused (a) zero-byte mirror: pre-flight refuses with exit 3 (D-28.1 layer 1, test -s) — got exit=$rc"

    # WR-04: `rc -eq 3` above CANNOT discriminate layer 1 (test -s) from layer 2
    # (the tail sentinel) — guard 4 also fails a zero-byte mirror with the same
    # exit 3 BY CONSTRUCTION (a zero-byte file has no `### 4. Goal-Driven
    # Execution` line either), so guard 4 subsumes guard 3 on this exact
    # fixture. The diagnostic TEXT is the only thing that differs: guard 3's is
    # "missing or empty" (0009:115), guard 4's is "missing its final section...
    # truncated or corrupt" (0009:140) and does NOT contain "missing or empty"
    # (re-confirmed by A4 in this plan's acceptance criteria). This mirrors how
    # the harness already isolates the version gate from the mirror guards 12
    # lines earlier by construction (mk_project supplies a passing version).
    case "$out" in
      *'missing or empty'*) _m0009_ok 0 "10-corrupt-mirror-refused (a) zero-byte mirror refused BY THE test -s layer" ;;
      *)                    _m0009_ok 1 "10-corrupt-mirror-refused (a) zero-byte mirror refused, but not by test -s (wrong layer)" ;;
    esac

    # (b) TRUNCATED mirror (head -20: keeps the L1 `## ` heading, drops
    #     `### 4. Goal-Driven Execution` at L57) → the tail-sentinel layer.
    #     WHY TRUNCATION DEFEATS BOTH `test -s` AND Apply's pre-`mv` shape
    #     assertion: the mirror's heading is on LINE 1, and both of those guards
    #     only look at the HEAD of a file that is truncated at the TAIL. A
    #     head-preserving truncation is non-empty and still produces the §11
    #     heading in the insert, so both pass it. Only a tail sentinel closes the
    #     gap between "has a heading" and "is the whole block".
    h10b="$(_m0009_mk_fake_home "$tmp" 10b "$mirror")"
    head -20 "$mirror" > "$h10b/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
    out="$(_m0009_apply "$p10" "$h10b" "$pf_block")"; rc=$?
    [ "$rc" -eq 3 ]
    _m0009_ok $? "10-corrupt-mirror-refused (b) truncated mirror: pre-flight refuses with exit 3 (D-28.1 layer 2, tail sentinel) — got exit=$rc"

    # (c) HEALTHY mirror → MUST pass. WITHOUT THIS DIRECTION A PRE-FLIGHT THAT
    #     REFUSED EVERYTHING WOULD PASS (a) AND (b) AND READ AS A WORKING GUARD.
    #     This is D-38's double-sided contract applied to the mirror guards: a
    #     guard never observed ACCEPTING is not a guard, it is a brick wall.
    h10c="$(_m0009_mk_fake_home "$tmp" 10c "$mirror")"
    out="$(_m0009_apply "$p10" "$h10c" "$pf_block")"; rc=$?
    [ "$rc" -eq 0 ]
    _m0009_ok $? "10-corrupt-mirror-refused (c) healthy mirror: pre-flight PASSES with exit 0 (the direction that proves it is not refusing everything) — got exit=$rc"
  else
    _m0009_fail "10-corrupt-mirror-refused (a) zero-byte mirror — NOT ASSERTED: Pre-flight extraction failed"
    _m0009_fail "10-corrupt-mirror-refused (b) truncated mirror — NOT ASSERTED: Pre-flight extraction failed"
    _m0009_fail "10-corrupt-mirror-refused (c) healthy mirror — NOT ASSERTED: Pre-flight extraction failed"
  fi

  # ═════════════════════════════════════════════════════════════════════════
  # 09.1-04 Task 1 — the three reproduced runaway-strip fixtures (CR-01/ANCHOR-05).
  #
  # Each is a fixture that has NOT YET been observed RED against the current,
  # unfixed 0009 the moment it is written is an assertion, not evidence. All
  # three MUST fail against this plan's unmodified `migrations/0009-*.md`:
  # the strip's exit condition (`in_block && swallowed_own_h2 && (...)`) is
  # gated behind `swallowed_own_h2`, which ONLY the EXACT
  # `## Coding Discipline (NON-NEGOTIABLE)` heading ever sets. When that exact
  # heading never appears after a provenance line, the exit rule can never
  # fire, `in_block` latches at 1 forever, and `in_block { next }` consumes
  # every remaining line to EOF — silently, with exit 0. Fixed by 09.1-05.
  #
  # All three assert the SAME four-part contract (Q1 ruling — REFUSE, not
  # heal): exit 3, AGENTS.md byte-identical, a diagnostic naming the offending
  # provenance line, and NOT the misleading "produced no output" message that
  # `0009:332` would emit for an unrelated failure class (disk full / awk
  # error) — that message is false for this failure and would misdirect an
  # operator. Gated on `[ "$apply_ok" = "1" ]`, mirroring every case above: a
  # down extraction gate reports FAILED via `_m0009_fail`, never silence.
  # ═════════════════════════════════════════════════════════════════════════
  if [ "$apply_ok" = "1" ]; then

    # ── 13-runaway-drifted-h2 (CR-01 — the exact 09-CR-01-REPRO.md shape) ──
    # BEFORE: provenance present, H2 drifted to
    # "## Coding Discipline (RENAMED — drifted)", followed by two real project
    # headings ("## Critical Project Rules", "## Deployment"). 16 lines in.
    # Reproduces 09-CR-01-REPRO.md verbatim, not an approximation: that repro
    # recorded 16 → 4 lines, with everything from the provenance line to EOF
    # destroyed while all three of 0009's own post-strip guards report success.
    p="$(_m0009_mk_project "$tmp" 13)"; h="$(_m0009_mk_fake_home "$tmp" 13 "$mirror")"
    {
      printf '# My Project\n\nIntro prose.\n\n'
      printf '%s\n' "$PROV_LIT"
      printf '## Coding Discipline (RENAMED — drifted)\n'
      printf 'Some body text describing the drifted heading.\n\n'
      printf '## Critical Project Rules\n'
      printf 'Critical rules body text that must not be destroyed.\n\n'
      printf '## Deployment\n'
      printf 'Deployment body text line 1.\n'
      printf 'Deployment body text line 2.\n'
      printf 'Deployment body text line 3.\n\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$p/AGENTS.md.before"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 3 ]
    _m0009_ok $? "13-runaway-drifted-h2: Apply refuses with exit 3 on a drifted H2 (CR-01) — before=$(wc -l < "$p/AGENTS.md.before" | tr -d ' ') after=$(wc -l < "$p/AGENTS.md" | tr -d ' ') lines, got exit=$rc"

    cmp -s "$p/AGENTS.md" "$p/AGENTS.md.before"
    _m0009_ok $? "13-runaway-drifted-h2: AGENTS.md is BYTE-IDENTICAL after refusal — the assertion that actually catches CR-01 (current 0009 truncates the file)"

    case "$out" in
      *"$PROV_LIT"*) _m0009_ok 0 "13-runaway-drifted-h2: diagnostic names the offending provenance line" ;;
      *)              _m0009_ok 1 "13-runaway-drifted-h2: diagnostic names the offending provenance line" ;;
    esac

    case "$out" in
      *'produced no output'*) _m0009_ok 1 "13-runaway-drifted-h2: diagnostic is NOT the misleading 'produced no output' message (0009:332 is the wrong branch for this failure class)" ;;
      *)                       _m0009_ok 0 "13-runaway-drifted-h2: diagnostic is NOT the misleading 'produced no output' message (0009:332 is the wrong branch for this failure class)" ;;
    esac

    grep -q -x -- '## Critical Project Rules' "$p/AGENTS.md" 2>/dev/null && grep -q -x -- '## Deployment' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "13-runaway-drifted-h2: surviving-content check — '## Critical Project Rules' and '## Deployment' both present (names the harm as data loss, redundant with cmp but reads as content destruction)"

    # ── 14-runaway-orphan-provenance (0009:282's own acknowledged state) ──
    # BEFORE: provenance present, NO §11 heading at all, and NO following
    # `## ` anywhere — the tail runs straight to EOF. 0009's own insert-pass
    # comment (`:282-285`) documents that the migration itself can PRODUCE
    # this exact state ("the rest of the file, plus an orphaned provenance
    # line") when the mirror is empty; 09-REVIEW.md lists it as reachable.
    # RESEARCH reproduced 8 lines in → 4 lines out.
    p="$(_m0009_mk_project "$tmp" 14)"; h="$(_m0009_mk_fake_home "$tmp" 14 "$mirror")"
    {
      printf '# My Project\n\nIntro prose.\n\n'
      printf '%s\n' "$PROV_LIT"
      printf 'Some content that follows the orphaned provenance line.\n'
      printf 'More content that would be silently destroyed.\n'
      printf 'Final line of content — no heading anywhere below this point.\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$p/AGENTS.md.before"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 3 ]
    _m0009_ok $? "14-runaway-orphan-provenance: Apply refuses with exit 3 on an orphaned provenance line — before=$(wc -l < "$p/AGENTS.md.before" | tr -d ' ') after=$(wc -l < "$p/AGENTS.md" | tr -d ' ') lines, got exit=$rc"

    cmp -s "$p/AGENTS.md" "$p/AGENTS.md.before"
    _m0009_ok $? "14-runaway-orphan-provenance: AGENTS.md is BYTE-IDENTICAL after refusal"

    case "$out" in
      *"$PROV_LIT"*) _m0009_ok 0 "14-runaway-orphan-provenance: diagnostic names the offending provenance line" ;;
      *)              _m0009_ok 1 "14-runaway-orphan-provenance: diagnostic names the offending provenance line" ;;
    esac

    case "$out" in
      *'produced no output'*) _m0009_ok 1 "14-runaway-orphan-provenance: diagnostic is NOT the misleading 'produced no output' message" ;;
      *)                       _m0009_ok 0 "14-runaway-orphan-provenance: diagnostic is NOT the misleading 'produced no output' message" ;;
    esac

    # ── 15-mixed-provenance-unresolved (the END guard's ONLY falsifiability proof) ──
    # BEFORE: provenance #1 + a HEALTHY block (exact H2 + full mirror body) +
    # a real terminating heading (`## Workflow`) + provenance #2 + a DRIFTED
    # H2 ("## Coding Discipline (RENAMED — drifted)") + body + `## Deployment`
    # + EOF.
    #
    # WHY THIS FIXTURE EXISTS: the file-global refuse gate at the top of
    # Apply (`grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md &&
    # ! grep -qE "$PROV_RE" AGENTS.md`) checks the WHOLE FILE, not per-block.
    # In this shape the exact H2 IS present — block 1 has it — so
    # `! grep -qE "$PROV_RE"` is false and the conjunction never fires. The
    # refuse gate is BLIND to this shape. It falls through to the strip,
    # which heals block 1 correctly but then latches on block 2's drifted H2
    # exactly as in fixture 13, this time consuming `## Deployment` and
    # everything after it. Only the END guard
    # (`END { if (unresolved || (in_block && !swallowed_own_h2)) exit 4 }`,
    # 09.1-05's fix) can catch this shape — without this fixture that guard
    # is defense-in-depth theater, never observed catching anything.
    p="$(_m0009_mk_project "$tmp" 15)"; h="$(_m0009_mk_fake_home "$tmp" 15 "$mirror")"
    {
      printf '# AGENTS.md\n\nGuidance.\n\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n## Workflow\nFirst project section — must survive.\n\n'
      printf '%s\n' "$PROV_LIT"
      printf '## Coding Discipline (RENAMED — drifted)\n'
      printf 'Body content under the drifted heading in the second block.\n\n'
      printf '## Deployment\n'
      printf 'Deployment body text — the harm the END guard exists to prevent.\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$p/AGENTS.md.before"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 3 ]
    _m0009_ok $? "15-mixed-provenance-unresolved: Apply refuses with exit 3 on a shape the file-global refuse gate cannot see — before=$(wc -l < "$p/AGENTS.md.before" | tr -d ' ') after=$(wc -l < "$p/AGENTS.md" | tr -d ' ') lines, got exit=$rc"

    cmp -s "$p/AGENTS.md" "$p/AGENTS.md.before"
    _m0009_ok $? "15-mixed-provenance-unresolved: AGENTS.md is BYTE-IDENTICAL after refusal"

    case "$out" in
      *"$PROV_LIT"*) _m0009_ok 0 "15-mixed-provenance-unresolved: diagnostic names the offending provenance line" ;;
      *)              _m0009_ok 1 "15-mixed-provenance-unresolved: diagnostic names the offending provenance line" ;;
    esac

    case "$out" in
      *'produced no output'*) _m0009_ok 1 "15-mixed-provenance-unresolved: diagnostic is NOT the misleading 'produced no output' message" ;;
      *)                       _m0009_ok 0 "15-mixed-provenance-unresolved: diagnostic is NOT the misleading 'produced no output' message" ;;
    esac

    grep -q -x -- '## Deployment' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "15-mixed-provenance-unresolved: '## Deployment' survives — its absence is the harm the END guard (09.1-05) exists to prevent"

    # ── 18-fenced-quoted-marker (09.1-REVIEW.md CR-02 — D-38 double-sided) ──
    # An exact, whole-line quotation of the provenance marker AND the §11
    # heading — together, adjacent, inside a markdown code fence documenting
    # "what a healthy block looks like" — is not a "mention" in the CR-01/
    # 07/11 sense (those are unanchored SUBSTRING mentions). It is a real
    # ANCHORED match on both regexes simultaneously. The strip latches
    # `in_block` at the fenced provenance line, swallows the fenced example's
    # own heading (exactly like a real block), and then — because neither
    # refuse-gate `elif` is file-global-blind here too (heading present +
    # provenance present, both true in aggregate) — keeps consuming
    # everything that is not itself a `## ` line or a region marker: the
    # closing code fence, an unrelated prose sentence, and a blank line —
    # real, unrelated user content — until it reaches the next real `## `
    # heading. Per the user's binding ruling: do not attempt fence-parsing in
    # the strip to make it "smart" about skipping fenced content and
    # continuing to heal (upstream calls that not-fixable-by-design). Instead
    # detect the ambiguity — a bare \`\`\`/~~~ fence-delimiter line appearing
    # inside the span the strip is about to silently discard is ALWAYS
    # suspicious, since the real vendored mirror carries zero such lines in
    # its own body — and refuse rather than guess.
    #
    # (a) REFUSE: the review's own concrete repro, verbatim.
    p="$(_m0009_mk_project "$tmp" 18a)"; h="$(_m0009_mk_fake_home "$tmp" 18a "$mirror")"
    {
      printf '# My Project\n\n'
      printf '## Troubleshooting\n\n'
      printf 'If your AGENTS.md ever needs the §11 marker restored by hand, it looks\n'
      printf 'exactly like this:\n\n'
      printf '```\n'
      printf '%s\n' "$PROV_LIT"
      printf '## Coding Discipline (NON-NEGOTIABLE)\n'
      printf '```\n\n'
      printf 'Do not delete this troubleshooting note.\n\n'
      printf '## Deployment\n'
      printf 'Real deployment content that must survive.\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$p/AGENTS.md.before"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 3 ]
    _m0009_ok $? "18-fenced-quoted-marker (a) REFUSE: Apply refuses with exit 3 on a fenced whole-line quotation of provenance+heading — got exit=$rc"

    cmp -s "$p/AGENTS.md" "$p/AGENTS.md.before"
    _m0009_ok $? "18-fenced-quoted-marker (a) REFUSE: AGENTS.md is BYTE-IDENTICAL after refusal — the assertion that actually catches CR-02 (unfixed 0009 silently deletes the troubleshooting note)"

    case "$out" in
      *'fence'*|*'Fence'*) _m0009_ok 0 "18-fenced-quoted-marker (a) REFUSE: diagnostic names the fence/ambiguity as the cause" ;;
      *)                   _m0009_ok 1 "18-fenced-quoted-marker (a) REFUSE: diagnostic names the fence/ambiguity as the cause" ;;
    esac

    grep -q -F -- 'Do not delete this troubleshooting note.' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "18-fenced-quoted-marker (a) REFUSE: the troubleshooting prose survives (the exact content CR-02 found silently deleted)"

    grep -q -x -- '## Deployment' "$p/AGENTS.md" 2>/dev/null
    _m0009_ok $? "18-fenced-quoted-marker (a) REFUSE: '## Deployment' survives"

    # (b) ACCEPT (D-38's other half) — a REAL, un-fenced, correctly-placed §11
    # block that genuinely gets stripped-and-reinserted (so the strip's
    # in_block span is actually exercised, not skipped like 03's zero-churn
    # case would leave untested), PLUS a totally unrelated fenced code
    # example living OUTSIDE that span (after the real terminator). The
    # guard must NOT fire just because a fence exists SOMEWHERE in the file —
    # only when one falls inside content the strip is about to discard.
    p="$(_m0009_mk_project "$tmp" 18b)"; h="$(_m0009_mk_fake_home "$tmp" 18b "$mirror")"
    {
      printf '# AGENTS.md\n\nGuidance.\n\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n## Examples\nHere is an example:\n\n'
      printf '```\necho hello\n```\n\n'
      printf '## Deployment\nMore stuff.\n'
    } > "$p/AGENTS.md"
    cp "$p/AGENTS.md" "$tmp/18b-pristine.md"
    out="$(_m0009_apply "$p" "$h" "$apply_block")"; rc=$?

    [ "$rc" -eq 0 ]
    _m0009_ok $? "18-fenced-quoted-marker (b) ACCEPT: Apply exits 0 when the fence is OUTSIDE the strip's span — the guard must not be a brick wall — got exit=$rc"

    cmp -s "$p/AGENTS.md" "$tmp/18b-pristine.md"
    _m0009_ok $? "18-fenced-quoted-marker (b) ACCEPT: AGENTS.md is BYTE-IDENTICAL (zero-churn heal, unrelated fence content untouched)"

  else
    _m0009_fail "13-runaway-drifted-h2: Apply refuses with exit 3 on a drifted H2 (CR-01) — NOT ASSERTED: Step 1 Apply extraction failed"
    _m0009_fail "13-runaway-drifted-h2: AGENTS.md is BYTE-IDENTICAL after refusal — NOT ASSERTED: extraction failed"
    _m0009_fail "13-runaway-drifted-h2: diagnostic names the offending provenance line — NOT ASSERTED: extraction failed"
    _m0009_fail "13-runaway-drifted-h2: diagnostic is NOT the misleading 'produced no output' message — NOT ASSERTED: extraction failed"
    _m0009_fail "13-runaway-drifted-h2: surviving-content check — NOT ASSERTED: extraction failed"
    _m0009_fail "14-runaway-orphan-provenance: Apply refuses with exit 3 on an orphaned provenance line — NOT ASSERTED: extraction failed"
    _m0009_fail "14-runaway-orphan-provenance: AGENTS.md is BYTE-IDENTICAL after refusal — NOT ASSERTED: extraction failed"
    _m0009_fail "14-runaway-orphan-provenance: diagnostic names the offending provenance line — NOT ASSERTED: extraction failed"
    _m0009_fail "14-runaway-orphan-provenance: diagnostic is NOT the misleading 'produced no output' message — NOT ASSERTED: extraction failed"
    _m0009_fail "15-mixed-provenance-unresolved: Apply refuses with exit 3 on a shape the file-global refuse gate cannot see — NOT ASSERTED: extraction failed"
    _m0009_fail "15-mixed-provenance-unresolved: AGENTS.md is BYTE-IDENTICAL after refusal — NOT ASSERTED: extraction failed"
    _m0009_fail "15-mixed-provenance-unresolved: diagnostic names the offending provenance line — NOT ASSERTED: extraction failed"
    _m0009_fail "15-mixed-provenance-unresolved: diagnostic is NOT the misleading 'produced no output' message — NOT ASSERTED: extraction failed"
    _m0009_fail "15-mixed-provenance-unresolved: '## Deployment' survives — NOT ASSERTED: extraction failed"
    _m0009_fail "18-fenced-quoted-marker (a) REFUSE: Apply refuses with exit 3 — NOT ASSERTED: extraction failed"
    _m0009_fail "18-fenced-quoted-marker (a) REFUSE: AGENTS.md is BYTE-IDENTICAL after refusal — NOT ASSERTED: extraction failed"
    _m0009_fail "18-fenced-quoted-marker (a) REFUSE: diagnostic names the fence/ambiguity as the cause — NOT ASSERTED: extraction failed"
    _m0009_fail "18-fenced-quoted-marker (a) REFUSE: the troubleshooting prose survives — NOT ASSERTED: extraction failed"
    _m0009_fail "18-fenced-quoted-marker (a) REFUSE: '## Deployment' survives — NOT ASSERTED: extraction failed"
    _m0009_fail "18-fenced-quoted-marker (b) ACCEPT: Apply exits 0 — NOT ASSERTED: extraction failed"
    _m0009_fail "18-fenced-quoted-marker (b) ACCEPT: AGENTS.md is BYTE-IDENTICAL — NOT ASSERTED: extraction failed"
  fi

  # ── no-scaffolder-tree (T-08-38 port — the criterion-0 regression guard) ──
  # Ports 0008's OWN `no-scaffolder-tree` fixture (`run-tests.sh:1638-1707`,
  # named without a number to match 0008's own naming — numbered fixtures
  # 11-15 are reserved, per Q4) to 0009. V-01 shipped 314 PASS / 0 FAIL
  # because the OLD `_m0009_mk_project` manufactured a synthetic
  # `skills/agentic-apps-workflow/SKILL.md` in every 0009 sandbox — the exact
  # practice 0008's own sandbox refuses (`run-tests.sh:917-918`). Task 1 of
  # this plan already made `_m0009_mk_project` realistic (no `skills/` tree
  # at all); this fixture is the falsifiable proof that removal sticks, and
  # — until 09.1-02 lands — the RECORDED RED that criterion 0 requires.
  #
  # Sandbox: `_m0009_mk_project` (now realistic) + `_m0009_mk_fake_home` with
  # the healthy `$mirror`, plus an AGENTS.md carrying a healthy ON-anchor §11
  # block ($PROV_LIT + the mirror's own bytes + a following `## Deployment`
  # heading) — the same shape `03-healthy-noop` above uses for its pristine
  # fixture. Gated on `[ "$pf_ok" = "1" ]`, mirroring every other case above:
  # a down extraction gate reports FAILED via `_m0009_fail`, not silence.
  if [ "$pf_ok" = "1" ]; then
    local pns hns applies_to_block step2_apply_block sep_bad
    pns="$(_m0009_mk_project "$tmp" nst)"
    hns="$(_m0009_mk_fake_home "$tmp" nst "$mirror")"
    {
      printf '# AGENTS.md\n\nGuidance.\n\n'
      printf '%s\n' "$PROV_LIT"
      cat "$mirror"
      printf '\n## Deployment\nStuff.\n'
    } > "$pns/AGENTS.md"

    # 1. The fixture guards itself — it really has no local `skills/` tree.
    #    Without this, the fixture can silently stop testing its own premise,
    #    which is exactly how V-01 shipped green.
    if test ! -e "$pns/skills"; then
      _m0009_ok 0 "no-scaffolder-tree: fixture has no local skills/ directory (self-guard — proves Task 1 landed)"
    else
      _m0009_ok 1 "no-scaffolder-tree: fixture has no local skills/ directory (self-guard — proves Task 1 landed)"
    fi

    # 2. Pre-flight passes with no skills/ tree present. THE CRITERION-0
    #    ASSERTION. Run the EXTRACTED pre-flight through _m0009_apply, not an
    #    inline copy — TEST-01's rule, so a document edit is what this
    #    observes, not a hand-maintained duplicate.
    out="$(_m0009_apply "$pns" "$hns" "$pf_block")"; rc=$?
    _m0009_ok "$rc" "no-scaffolder-tree: pre-flight PASSES with no skills/ tree present (criterion 0) — got exit=$rc"

    # 3. Step 1's idempotency check runs cleanly (exit <= 1, i.e. no *errors*,
    #    per 0008's own assertion 3) in this sandbox.
    out="$(_m0009_apply "$pns" "$hns" "$idem_block")"; rc=$?
    [ "$rc" -le 1 ]
    _m0009_ok $? "no-scaffolder-tree: Step 1's idempotency check runs cleanly (exit <= 1) with no skills/ tree — got exit=$rc"

    # 4. The MIGR-08 / MIGR-09 separation holds as a DOCUMENT CONTRACT: no
    #    EXECUTABLE surface of 0009 names skills/agentic-apps-workflow/SKILL.md.
    #    Checked on three surfaces, not the raw file — 0009's own PROSE
    #    legitimately discusses the path when it records the divergence
    #    (0008:470-487), so a bare whole-document grep would self-invalidate
    #    the moment 09.1-02 writes that prose.
    applies_to_block="$(awk '/^applies_to:/{f=1;next} f && /^[^ ]/{exit} f{print}' "$MIGRATION_0009")"
    step2_apply_block="$(extract_step_block "$MIGRATION_0009" 2 Apply 2>/dev/null)"
    sep_bad=0
    printf '%s' "$applies_to_block" | grep -q 'skills/' && sep_bad=1
    printf '%s' "$pf_block" | grep -q 'skills/agentic-apps-workflow' && sep_bad=1
    printf '%s' "$apply_block" | grep -q 'skills/agentic-apps-workflow' && sep_bad=1
    printf '%s' "$step2_apply_block" | grep -q 'skills/agentic-apps-workflow' && sep_bad=1
    _m0009_ok "$sep_bad" "no-scaffolder-tree: MIGR-08/MIGR-09 separation — no executable surface (applies_to frontmatter, pre-flight, every Step Apply) names skills/agentic-apps-workflow/SKILL.md"
  else
    _m0009_fail "no-scaffolder-tree: fixture has no local skills/ directory (self-guard) — NOT ASSERTED: Pre-flight extraction failed"
    _m0009_fail "no-scaffolder-tree: pre-flight PASSES with no skills/ tree present (criterion 0) — NOT ASSERTED: Pre-flight extraction failed"
    _m0009_fail "no-scaffolder-tree: Step 1's idempotency check runs cleanly (exit <= 1) with no skills/ tree — NOT ASSERTED: Pre-flight extraction failed"
    _m0009_fail "no-scaffolder-tree: MIGR-08/MIGR-09 separation — NOT ASSERTED: Pre-flight extraction failed"
  fi

  # ── Known-limitations document contract (09.1-REVIEW.md WR-02) ──
  # Asserted against the RAW DOCUMENT, not execution — mirrors
  # 08-rollback-region-led's own style just above, for the same reason: this
  # is a document-shape/disclosure contract, not behavior. Checks that 0009
  # carries its own "Known limitations" section naming both hazards CR-01/
  # CR-02 closed (rather than leaving the reader to assume the anchoring note
  # at :640 means the whole marker-matching hazard class is resolved), states
  # the concrete CRLF remedy command, and records the deliberate divergence
  # from upstream's own still-accepting 0029.
  local known_lim
  known_lim="$(awk '/^## Known limitations/{f=1} f{print} /^## Notes/{exit}' "$MIGRATION_0009")"

  case "$known_lim" in
    *'## Known limitations'*) _m0009_ok 0 "WR-02: 0009 carries its own '## Known limitations' section" ;;
    *)                        _m0009_ok 1 "WR-02: 0009 carries its own '## Known limitations' section" ;;
  esac

  case "$known_lim" in
    *'CRLF'*) _m0009_ok 0 "WR-02: Known limitations names CRLF as a refused (not silently mis-healed) hazard" ;;
    *)        _m0009_ok 1 "WR-02: Known limitations names CRLF as a refused (not silently mis-healed) hazard" ;;
  esac

  case "$known_lim" in
    *'code fence'*) _m0009_ok 0 "WR-02: Known limitations names the fenced/quoted-marker hazard" ;;
    *)              _m0009_ok 1 "WR-02: Known limitations names the fenced/quoted-marker hazard" ;;
  esac

  case "$known_lim" in
    *'perl -pi -e'*) _m0009_ok 0 "WR-02: Known limitations states the concrete CRLF remedy command" ;;
    *)               _m0009_ok 1 "WR-02: Known limitations states the concrete CRLF remedy command" ;;
  esac

  case "$known_lim" in
    *'0029'*) _m0009_ok 0 "WR-02: Known limitations records the deliberate divergence from upstream's 0029" ;;
    *)        _m0009_ok 1 "WR-02: Known limitations records the deliberate divergence from upstream's 0029" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# validate-0009-anchor.sh stdout determinism (REV-01, 09-REVIEW.md WR-05)
#
# WR-05's finding: the script's own banner comment claims its stdout is
# "deliberately DETERMINISTIC ... so a verifier can re-run and diff", but (pre
# -fix) it printed `$(wc -l < "$MIRROR")` in the banner and mirror-length-
# derived line numbers in CASE 2's PASS text — a mirror re-vendor (this repo's
# has already happened once, 75->79 lines) would silently invalidate recorded
# evidence the comment says it is designed to protect. D-11's fix-option (a):
# REMOVE the mirror-derived values from stdout entirely (not reword the
# claim). This is the full-script grep proving that removal, run against the
# REAL validator (not a copy) so a future re-introduction of a `wc -l`-style
# value is caught here rather than only in code review.
#
# Mutation-proven (verifier re-runs this cycle, does not trust the claim): a
# `$(wc -l < "$MIRROR" ...)`-style value temporarily reintroduced into the
# banner flips this test RED; removing it restores GREEN. Observed by hand
# during 12-02's execution (see 12-02-SUMMARY.md) and re-verifiable at any
# time by reintroducing the clause and re-running `bash migrations/run-tests.sh
# determinism`.
# ─────────────────────────────────────────────────────────────────────────────

test_validate_0009_anchor_determinism() {
  echo ""
  echo "${YELLOW}=== validate-0009-anchor.sh — stdout determinism (REV-01, WR-05) ===${RESET}"

  local validator="$REPO_ROOT/migrations/validate-0009-anchor.sh"
  if [ ! -f "$validator" ]; then
    echo "  ${RED}FAIL${RESET} validator script missing: migrations/validate-0009-anchor.sh"
    FAIL=$((FAIL+1)); return
  fi

  local out
  out="$(bash "$validator" 2>/dev/null)"

  if [ -z "$out" ]; then
    echo "  ${RED}FAIL${RESET} validate-0009-anchor.sh determinism: validator produced no stdout"
    FAIL=$((FAIL+1))
    return
  fi

  # Full-script grep for the two mirror-derived shapes WR-05 named: a
  # "(N lines)" banner count, and an "at line N" reference in any PASS/FAIL
  # text. Absence of BOTH across the ENTIRE run (not just CASE 2) is what
  # "genuinely deterministic" means here.
  if printf '%s\n' "$out" | grep -Eq '\([0-9]+ lines\)|at line [0-9]+'; then
    echo "  ${RED}FAIL${RESET} validate-0009-anchor.sh determinism: stdout carries a mirror-derived value (a '(N lines)' banner count or an 'at line N' reference) — a mirror re-vendor would silently invalidate recorded evidence"
    FAIL=$((FAIL+1))
  else
    echo "  ${GREEN}PASS${RESET} validate-0009-anchor.sh determinism: stdout carries zero mirror-derived values (no line count, no derived line number)"
    PASS=$((PASS+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Migration 0010 — Heal 0007's knowledge-capture chain break (v0.4.0 -> 0.5.0)
#
# MIGR-10. 0007's pre-flight greps a scaffolder-relative path
# (`skills/agentic-apps-workflow/SKILL.md`) no real target project has, so it
# hard-aborts (exit 3) before writing anything — 0008/0009's own floor checks
# then never reach a version the fleet ever recorded. 0010 re-delivers 0007's
# Steps 1/2/4 payload (config.json seed, AGENTS.md ritual-tail, version
# record — renumbered here to Steps 1/2/3, 0007's Step 3 scaffolder bump
# dropped per D-03/MIGR-09) behind a corrected pre-flight that reads
# `.codex/workflow-version.txt` exclusively, verbatim-reusing 0008's proven
# floor-check pattern (D-01).
#
# RED-BEFORE / GREEN-AFTER (success criterion #1): this fixture is authored
# BEFORE migrations/0010-heal-0007-knowledge-capture.md exists. Every
# extraction below is gated by assert_extracted_shape (D-36) — with no
# document to extract from, each gate reports an empty-extraction FAIL and
# every downstream D-06/D-07 assertion reports via _m0010_fail rather than
# silently vanishing. `bash migrations/run-tests.sh 0010` is expected to exit
# NON-ZERO until Task 2 authors the migration. DO NOT stub 0010 to turn this
# green early — that is Task 2's job (D-36: "non-empty is not the same as
# correct").
# ─────────────────────────────────────────────────────────────────────────────

# _m0010_ok <rc> <label> — PASS iff rc is 0. Mirrors _m0009_ok's convention
# (file-scope, `_m0010_` prefix — shell has no function-local functions).
_m0010_ok() {
  if [ "$1" -eq 0 ]; then
    echo "  ${GREEN}PASS${RESET} $2"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $2"
    FAIL=$((FAIL+1))
  fi
}

# _m0010_fail <label> — unconditional FAIL, used when an extraction gate is
# down so a case reports FAILED rather than silently disappearing.
_m0010_fail() {
  echo "  ${RED}FAIL${RESET} $1"
  FAIL=$((FAIL+1))
}

# _m0010_apply <sandbox_dir> <codex_home> <block_text>
# Runs an extracted Apply block against the sandbox with CODEX_HOME resolved
# to the real repo root (0010's Apply blocks resolve
# $CODEX_HOME/skills/setup-codex-agenticapps-workflow/templates/... and
# `git rev-parse --show-toplevel`, so the sandbox is `git init`-ed and
# CODEX_HOME points at this trusted repo, never at the developer's real
# ~/.codex). Subshell-wrapped so a block that exits non-zero cannot terminate
# the whole harness mid-suite (same discipline as _m0009_apply).
_m0010_apply() {
  ( cd "$1" && export CODEX_HOME="$2" && eval "$3" ) 2>&1
}

# _m0010_mk_version_sandbox <tmp> <name> <version>
# WR-02: builds a scratch project root shaped like a REAL target project — a
# `.git` directory (the pre-flight's `test -d .git` guard) plus
# `.codex/workflow-version.txt` set to <version> — and DELIBERATELY NO local
# `skills/` tree of any kind (D-07, mirrors `_m0009_mk_project`'s
# no-scaffolder-tree shape, `run-tests.sh:3543-3559`). The version file is the
# ONLY variable across the four sandboxes the floor-execution cases below
# build, so a floor accept/reject can only be explained by the version-floor
# regex itself. Prints the project root's path.
_m0010_mk_version_sandbox() {
  local p="$1/$2/proj"
  mkdir -p "$p/.codex"
  ( cd "$p" && git init -q )
  printf '%s\n' "$3" > "$p/.codex/workflow-version.txt"
  printf '%s\n' "$p"
}

test_migration_0010() {
  echo ""
  echo "${YELLOW}=== Migration 0010 — Heal 0007 knowledge-capture chain break ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — config-merge test not run"
    SKIP=$((SKIP+1)); return
  fi

  local MIGRATION_0010="$REPO_ROOT/migrations/0010-heal-0007-knowledge-capture.md"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # ── Extraction (TEST-01): 0010's own shell, pulled from 0010's own document,
  # never hand-transcribed. Every extraction is gated by assert_extracted_shape
  # (D-36) before it is executed or asserted-on.
  local pf_block applies_to_block step1_apply step2_apply step3_apply
  pf_block="$(extract_preflight_block "$MIGRATION_0010" 2>/dev/null)"
  applies_to_block="$(awk '/^applies_to:/{f=1;next} f && /^[^ ]/{exit} f{print}' "$MIGRATION_0010")"
  step1_apply="$(extract_step_block "$MIGRATION_0010" 1 Apply 2>/dev/null)"
  step2_apply="$(extract_step_block "$MIGRATION_0010" 2 Apply 2>/dev/null)"
  step3_apply="$(extract_step_block "$MIGRATION_0010" 3 Apply 2>/dev/null)"

  local pf_ok=1 applies_ok=1 s1_ok=1 s2_ok=1 s3_ok=1
  assert_extracted_shape "0010 Pre-flight" "$pf_block" '.codex/workflow-version.txt' || pf_ok=0
  assert_extracted_shape "0010 applies_to" "$applies_to_block" '.planning/config.json' || applies_ok=0
  assert_extracted_shape "0010 Step 1 Apply" "$step1_apply" '.planning/config.json' || s1_ok=0
  assert_extracted_shape "0010 Step 2 Apply" "$step2_apply" 'AGENTS.md' || s2_ok=0
  assert_extracted_shape "0010 Step 3 Apply" "$step3_apply" '.codex/workflow-version.txt' || s3_ok=0

  local all_ok=1
  [ "$pf_ok" = "1" ] && [ "$applies_ok" = "1" ] && [ "$s1_ok" = "1" ] \
    && [ "$s2_ok" = "1" ] && [ "$s3_ok" = "1" ] || all_ok=0

  # ── D-07 document contract: no executable surface of 0010 (pre-flight,
  # applies_to, every Step Apply) names skills/agentic-apps-workflow — proves
  # the original V-01-class bug is not re-introduced by copy-paste. Matched
  # against the exact D-07 substring, NOT `skills/` broadly, which would
  # false-positive on the legitimate
  # skills/setup-codex-agenticapps-workflow/templates/... references 0010
  # correctly retains from 0007's Steps 1/2.
  local surface_bad=0
  [ "$pf_ok" = "1" ] && { printf '%s' "$pf_block" | grep -q 'skills/agentic-apps-workflow' && surface_bad=1; }
  [ "$applies_ok" = "1" ] && { printf '%s' "$applies_to_block" | grep -q 'skills/agentic-apps-workflow' && surface_bad=1; }
  [ "$s1_ok" = "1" ] && { printf '%s' "$step1_apply" | grep -q 'skills/agentic-apps-workflow' && surface_bad=1; }
  [ "$s2_ok" = "1" ] && { printf '%s' "$step2_apply" | grep -q 'skills/agentic-apps-workflow' && surface_bad=1; }
  [ "$s3_ok" = "1" ] && { printf '%s' "$step3_apply" | grep -q 'skills/agentic-apps-workflow' && surface_bad=1; }
  if [ "$all_ok" = "1" ]; then
    _m0010_ok "$surface_bad" "D-07: no executable surface (pre-flight, applies_to, every Step Apply) names skills/agentic-apps-workflow"
  else
    _m0010_fail "D-07: no executable surface names skills/agentic-apps-workflow — NOT ASSERTED: one or more extractions failed"
  fi

  # ── WR-02: EXECUTE the extracted pre-flight (pf_block) against four
  # seeded-version sandboxes, proving 0010's version-floor regex correct BY
  # EXECUTION — not merely present as text (closes the gap flagged in
  # 11-VERIFICATION.md: "a mutation to 0010's version-floor regex ... would
  # survive the test suite undetected"). Mirrors test_migration_0009's
  # _m0009_apply-against-seeded-sandbox pattern for its own pre-flight
  # (`run-tests.sh:4358-4412`). CODEX_HOME is pinned to REPO_ROOT (trusted,
  # same as the Step 1/2/3 executions below) so both required templates
  # resolve and are held CONSTANT across all four sandboxes — the version
  # file is the SOLE variable, isolating the floor regex exactly as 0009's
  # fixture isolates its mirror-guard cases from its own version gate.
  if [ "$pf_ok" = "1" ]; then
    local v03 v04 v05 v06 out rc
    v03="$(_m0010_mk_version_sandbox "$tmp" floor03 "0.3.0")"
    v04="$(_m0010_mk_version_sandbox "$tmp" floor04 "0.4.0")"
    v05="$(_m0010_mk_version_sandbox "$tmp" floor05 "0.5.0")"
    v06="$(_m0010_mk_version_sandbox "$tmp" floor06 "0.6.0")"

    out="$(_m0010_apply "$v03" "$REPO_ROOT" "$pf_block")"; rc=$?
    [ "$rc" -ne 0 ]
    _m0010_ok $? "WR-02 floor (execution): 0.3.0 (below 0.4.0 floor) REJECTED by the extracted pre-flight — got exit=$rc"

    out="$(_m0010_apply "$v04" "$REPO_ROOT" "$pf_block")"; rc=$?
    [ "$rc" -eq 0 ]
    _m0010_ok $? "WR-02 floor (execution): 0.4.0 (fresh install) ACCEPTED by the extracted pre-flight — got exit=$rc"

    out="$(_m0010_apply "$v05" "$REPO_ROOT" "$pf_block")"; rc=$?
    [ "$rc" -eq 0 ]
    _m0010_ok $? "WR-02 floor (execution): 0.5.0 (idempotent re-apply) ACCEPTED by the extracted pre-flight — got exit=$rc"

    out="$(_m0010_apply "$v06" "$REPO_ROOT" "$pf_block")"; rc=$?
    [ "$rc" -ne 0 ]
    _m0010_ok $? "WR-02 floor (execution): 0.6.0 (above 0010's slot) REJECTED by the extracted pre-flight — got exit=$rc"
  else
    _m0010_fail "WR-02 floor (execution): 0.3.0 REJECTED by the extracted pre-flight — NOT ASSERTED: pre-flight extraction failed"
    _m0010_fail "WR-02 floor (execution): 0.4.0 ACCEPTED by the extracted pre-flight — NOT ASSERTED: pre-flight extraction failed"
    _m0010_fail "WR-02 floor (execution): 0.5.0 ACCEPTED by the extracted pre-flight — NOT ASSERTED: pre-flight extraction failed"
    _m0010_fail "WR-02 floor (execution): 0.6.0 REJECTED by the extracted pre-flight — NOT ASSERTED: pre-flight extraction failed"
  fi

  # ── D-06 delivery fixture: a 0.4.0 sandbox carrying NONE of 0007's
  # artifacts, shaped like a real target project (D-07's no-local-skills/-tree
  # shape — mirrors 0008's own no-scaffolder-tree fixture,
  # `migrations/run-tests.sh:1651-1727`).
  if [ "$all_ok" = "1" ]; then
    local sbx="$tmp/sandbox"
    mkdir -p "$sbx/.planning" "$sbx/.codex"
    ( cd "$sbx" && git init -q )
    printf '0.4.0\n' > "$sbx/.codex/workflow-version.txt"
    cat > "$sbx/AGENTS.md" <<'MD'
# AGENTS.md — 0010 sandbox fixture

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## Session handoff

Existing content.

<!-- END: agentic-apps-workflow sections -->
MD

    # Self-guard 1 (D-07 shape): the sandbox really has no local skills/ tree.
    if test ! -e "$sbx/skills"; then
      _m0010_ok 0 "D-07 sandbox self-guard: no local skills/ directory (no-scaffolder-tree shape)"
    else
      _m0010_ok 1 "D-07 sandbox self-guard: no local skills/ directory (no-scaffolder-tree shape)"
    fi

    # Self-guard 2 (D-06 shape): none of 0007's artifacts are present yet —
    # the clean pre-migration 0.4.0 state.
    if ! grep -q '^## Knowledge Capture' "$sbx/AGENTS.md" \
       && [ ! -f "$sbx/.planning/config.json" ]; then
      _m0010_ok 0 "D-06 sandbox self-guard: carries none of 0007's artifacts before apply (clean 0.4.0 state)"
    else
      _m0010_ok 1 "D-06 sandbox self-guard: carries none of 0007's artifacts before apply (clean 0.4.0 state)"
    fi

    # Execute the extracted Step 1/2/3 Apply blocks, in order, against the
    # sandbox. CODEX_HOME points at the real repo root (trusted, T-11-02) so
    # the blocks' $CODEX_HOME/skills/setup-codex-agenticapps-workflow/templates/...
    # reads resolve to the real templates.
    local out rc
    out="$(_m0010_apply "$sbx" "$REPO_ROOT" "$step1_apply")"; rc=$?
    _m0010_ok "$rc" "Step 1 Apply executes cleanly against the 0.4.0 sandbox — got exit=$rc"
    [ "$rc" -ne 0 ] && printf '%s\n' "$out" | sed 's/^/    /'

    out="$(_m0010_apply "$sbx" "$REPO_ROOT" "$step2_apply")"; rc=$?
    _m0010_ok "$rc" "Step 2 Apply executes cleanly against the 0.4.0 sandbox — got exit=$rc"
    [ "$rc" -ne 0 ] && printf '%s\n' "$out" | sed 's/^/    /'

    out="$(_m0010_apply "$sbx" "$REPO_ROOT" "$step3_apply")"; rc=$?
    _m0010_ok "$rc" "Step 3 Apply executes cleanly against the 0.4.0 sandbox — got exit=$rc"
    [ "$rc" -ne 0 ] && printf '%s\n' "$out" | sed 's/^/    /'

    # D-06 assertions: payload delivered + version healed.
    if ( cd "$sbx" && jq -e '.knowledge_capture.enabled == true' .planning/config.json >/dev/null 2>&1 ); then
      _m0010_ok 0 "D-06: knowledge_capture.enabled is true in .planning/config.json after Steps 1-3"
    else
      _m0010_ok 1 "D-06: knowledge_capture.enabled is true in .planning/config.json after Steps 1-3"
    fi

    # WR-03: <repo-name> placeholder resolved in knowledge_capture.note — 0010's
    # own Post-checks (migrations/0010-heal-0007-knowledge-capture.md:207-212)
    # calls this "ALWAYS true on success"; mirrors test_migration_0007's
    # identical assertion (run-tests.sh:838-845), adapted to this sandbox's
    # real repo directory name ("sandbox", from `$tmp/sandbox`). Both halves
    # required, same discipline as 0007's check: the resolved note path must
    # END with "/sandbox.md" (not merely NOT contain the placeholder — a
    # broken resolution that clobbers the whole note would still pass a
    # placeholder-absence-only check).
    if ( cd "$sbx" && jq -e '.knowledge_capture.note | endswith("/sandbox.md")' .planning/config.json >/dev/null 2>&1 ) \
       && ! grep -qF '<repo-name>' "$sbx/.planning/config.json"; then
      _m0010_ok 0 "D-06/WR-03: <repo-name> resolved in knowledge_capture.note (ends with /sandbox.md); no placeholder left"
    else
      _m0010_ok 1 "D-06/WR-03: <repo-name> resolved in knowledge_capture.note (ends with /sandbox.md); no placeholder left"
    fi

    if grep -q '^## Knowledge Capture — Ritual Tail (spec §15)' "$sbx/AGENTS.md"; then
      _m0010_ok 0 "D-06: AGENTS.md carries the Knowledge Capture — Ritual Tail section after Steps 1-3"
    else
      _m0010_ok 1 "D-06: AGENTS.md carries the Knowledge Capture — Ritual Tail section after Steps 1-3"
    fi

    if [ "$(cat "$sbx/.codex/workflow-version.txt" 2>/dev/null)" = "0.5.0" ]; then
      _m0010_ok 0 "D-06: .codex/workflow-version.txt reads exactly 0.5.0 after Steps 1-3"
    else
      _m0010_ok 1 "D-06: .codex/workflow-version.txt reads exactly 0.5.0 after Steps 1-3"
    fi
  else
    _m0010_fail "D-07 sandbox self-guard: no local skills/ directory — NOT ASSERTED: one or more extractions failed"
    _m0010_fail "D-06 sandbox self-guard: carries none of 0007's artifacts before apply — NOT ASSERTED: extraction failed"
    _m0010_fail "Step 1 Apply executes cleanly against the 0.4.0 sandbox — NOT ASSERTED: extraction failed"
    _m0010_fail "Step 2 Apply executes cleanly against the 0.4.0 sandbox — NOT ASSERTED: extraction failed"
    _m0010_fail "Step 3 Apply executes cleanly against the 0.4.0 sandbox — NOT ASSERTED: extraction failed"
    _m0010_fail "D-06: knowledge_capture.enabled is true in .planning/config.json after Steps 1-3 — NOT ASSERTED: extraction failed"
    _m0010_fail "D-06/WR-03: <repo-name> resolved in knowledge_capture.note (ends with /sandbox.md); no placeholder left — NOT ASSERTED: extraction failed"
    _m0010_fail "D-06: AGENTS.md carries the Knowledge Capture — Ritual Tail section after Steps 1-3 — NOT ASSERTED: extraction failed"
    _m0010_fail "D-06: .codex/workflow-version.txt reads exactly 0.5.0 after Steps 1-3 — NOT ASSERTED: extraction failed"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# test_migration_0011 (HOOK-03, phase 13-native-enforcement-plan-review-hook)
#
# Proves migration 0011's Step 1/2 Apply blocks — EXTRACTED FROM THE
# DOCUMENT ITSELF, never hand-transcribed (TEST-01, 11-02's own lesson) —
# actually merge-don't-clobber against fixtures carrying a PRE-EXISTING
# unrelated vendor's content, are idempotent on re-apply, and that SC#4's
# negative half (a second, untouched repo carries no plan-review entry) is
# automated. Mirrors test_migration_0010's structural template:
# extract_step_block + assert_extracted_shape gating, mktemp -d sandboxes
# with `trap ... RETURN`, CODEX_HOME pinned to the real repo root (trusted,
# same discipline as _m0010_apply/_m0009_apply) so the wrapper path in
# Step 1's jq --arg resolves.
# ─────────────────────────────────────────────────────────────────────────────

# _m0011_ok <rc> <label> — PASS iff rc is 0. Mirrors _m0010_ok's convention.
_m0011_ok() {
  if [ "$1" -eq 0 ]; then
    echo "  ${GREEN}PASS${RESET} $2"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $2"
    FAIL=$((FAIL+1))
  fi
}

# _m0011_fail <label> — unconditional FAIL, used when an extraction gate is
# down so a case reports FAILED rather than silently disappearing.
_m0011_fail() {
  echo "  ${RED}FAIL${RESET} $1"
  FAIL=$((FAIL+1))
}

# _m0011_apply <sandbox_dir> <codex_home> <block_text>
# Runs an extracted Apply block against the sandbox with CODEX_HOME resolved
# to the real repo root (0011's Step 1 Apply resolves
# $CODEX_HOME/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh,
# so CODEX_HOME must point at this trusted repo, never the developer's real
# ~/.codex). Subshell-wrapped so a block that exits non-zero cannot terminate
# the whole harness mid-suite (same discipline as _m0010_apply/_m0009_apply).
_m0011_apply() {
  ( cd "$1" && export CODEX_HOME="$2" && eval "$3" ) 2>&1
}

test_migration_0011() {
  echo ""
  echo "${YELLOW}=== Migration 0011 — Native PreToolUse plan-review hook (HOOK-03) ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — migration 0011 test not run"
    SKIP=$((SKIP+1)); return
  fi

  local MIGRATION_0011="$REPO_ROOT/migrations/0011-native-plan-review-hook.md"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # ── Extraction (TEST-01): 0011's own shell, pulled from 0011's own
  # document, never hand-transcribed. Every extraction is gated by
  # assert_extracted_shape (D-36) before it is executed or asserted-on.
  # Idempotency-check blocks are extracted too (not just Apply): the
  # "idempotent re-apply" case below re-runs each step's OWN idempotency
  # check before deciding whether to re-invoke Apply — the SAME discipline
  # test_migration_0008's partial-application fixture uses
  # (`run-tests.sh:1928`, "each step checks its OWN idempotency"), mirroring
  # how the real update flow gates re-invocation. 0011's Step 1 Apply is an
  # unconditional array-append by design (leaf-merge discipline, T-13-04) —
  # it is the EXTERNAL idempotency check that makes re-application safe, not
  # an append-if-absent Apply body.
  local pf_block applies_to_block step1_apply step2_apply step1_idem step2_idem
  pf_block="$(extract_preflight_block "$MIGRATION_0011" 2>/dev/null)"
  applies_to_block="$(awk '/^applies_to:/{f=1;next} f && /^[^ ]/{exit} f{print}' "$MIGRATION_0011")"
  step1_apply="$(extract_step_block "$MIGRATION_0011" 1 Apply 2>/dev/null)"
  step2_apply="$(extract_step_block "$MIGRATION_0011" 2 Apply 2>/dev/null)"
  step1_idem="$(extract_step_block "$MIGRATION_0011" 1 "Idempotency check" 2>/dev/null)"
  step2_idem="$(extract_step_block "$MIGRATION_0011" 2 "Idempotency check" 2>/dev/null)"

  local pf_ok=1 applies_ok=1 s1_ok=1 s2_ok=1 s1i_ok=1 s2i_ok=1
  assert_extracted_shape "0011 Pre-flight" "$pf_block" 'hook-wrapper-plan-review.sh' || pf_ok=0
  assert_extracted_shape "0011 applies_to" "$applies_to_block" '.codex/hooks.json' || applies_ok=0
  assert_extracted_shape "0011 Step 1 Apply" "$step1_apply" 'PreToolUse' || s1_ok=0
  assert_extracted_shape "0011 Step 2 Apply" "$step2_apply" 'features' || s2_ok=0
  assert_extracted_shape "0011 Step 1 Idempotency check" "$step1_idem" 'PreToolUse' || s1i_ok=0
  assert_extracted_shape "0011 Step 2 Idempotency check" "$step2_idem" 'hooks' || s2i_ok=0

  local all_ok=1
  [ "$pf_ok" = "1" ] && [ "$applies_ok" = "1" ] && [ "$s1_ok" = "1" ] && [ "$s2_ok" = "1" ] \
    && [ "$s1i_ok" = "1" ] && [ "$s2i_ok" = "1" ] || all_ok=0

  if [ "$all_ok" != "1" ]; then
    _m0011_fail "Step 1 Apply: merge-don't-clobber (decoy vendor entry survives) — NOT ASSERTED: extraction failed"
    _m0011_fail "Step 1 Apply: wrapper PreToolUse entry present after apply — NOT ASSERTED: extraction failed"
    _m0011_fail "Step 1 Apply: idempotent re-apply adds no duplicate entry — NOT ASSERTED: extraction failed"
    _m0011_fail "Step 2 Apply: config-flag merge (decoy [some_other] table survives) — NOT ASSERTED: extraction failed"
    _m0011_fail "Step 2 Apply: [features] hooks = true present after apply — NOT ASSERTED: extraction failed"
    _m0011_fail "Step 2 Apply: idempotent re-apply adds no duplicate flag — NOT ASSERTED: extraction failed"
    _m0011_fail "SC#4-negative: second repo with no .codex/hooks.json has no PreToolUse plan-review entry — NOT ASSERTED: extraction failed"
    return
  fi

  local CODEX_HOME_FOR_TEST="$REPO_ROOT"
  local WRAPPER_PATH="$REPO_ROOT/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"

  # ── Sandbox 1: hooks.json merge-don't-clobber + config.toml flag merge ──
  local sbx="$tmp/sandbox"
  mkdir -p "$sbx/.codex"
  ( cd "$sbx" && git init -q )

  # Decoy vendor hooks.json — a PRE-EXISTING unrelated vendor's PreToolUse
  # entry that must survive the merge (T-13-04). Uses the NESTED matcher-group
  # schema ({"hooks":[{"type","command"}]}), which is what codex-cli actually
  # loads and what this machine's live ~/.codex/hooks.json carries; the flat
  # form is silently dropped (migration 0011 ## Correction, 2026-07-19).
  cat > "$sbx/.codex/hooks.json" <<'JSON'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/opt/vendor/some-other-hook.sh"}]}]}}
JSON

  # Decoy config.toml — an unrelated [some_other] table that must survive
  # the [features] merge (T-13-05).
  cat > "$sbx/.codex/config.toml" <<'TOML'
[some_other]
foo = "bar"
TOML

  local out rc
  out="$(_m0011_apply "$sbx" "$CODEX_HOME_FOR_TEST" "$step1_apply")"; rc=$?
  _m0011_ok "$rc" "Step 1 Apply executes cleanly against the seeded sandbox — got exit=$rc"
  [ "$rc" -ne 0 ] && printf '%s\n' "$out" | sed 's/^/    /'

  if ( cd "$sbx" && jq -e '.hooks.PreToolUse | length == 2' .codex/hooks.json >/dev/null 2>&1 ); then
    _m0011_ok 0 "Step 1: .hooks.PreToolUse has exactly 2 entries after apply (decoy + wrapper)"
  else
    _m0011_ok 1 "Step 1: .hooks.PreToolUse has exactly 2 entries after apply (decoy + wrapper)"
  fi

  if ( cd "$sbx" && jq -e '.hooks.PreToolUse[] | (.hooks // [])[] | select(.command == "/opt/vendor/some-other-hook.sh")' .codex/hooks.json >/dev/null 2>&1 ); then
    _m0011_ok 0 "Step 1: pre-existing decoy vendor PreToolUse entry survives the merge (T-13-04)"
  else
    _m0011_ok 1 "Step 1: pre-existing decoy vendor PreToolUse entry survives the merge (T-13-04)"
  fi

  if ( cd "$sbx" && jq -e --arg cmd "$WRAPPER_PATH" \
       '.hooks.PreToolUse[] | select(.matcher == "apply_patch") | (.hooks // [])[] | select(.command == $cmd and .type == "command")' .codex/hooks.json >/dev/null 2>&1 ); then
    _m0011_ok 0 "Step 1: wrapper PreToolUse entry (matcher=apply_patch) present after apply"
  else
    _m0011_ok 1 "Step 1: wrapper PreToolUse entry (matcher=apply_patch) present after apply"
  fi

  # SCHEMA REGRESSION GUARD (migration 0011 ## Correction, 2026-07-19).
  # The original migration wrote the entry FLAT — {"matcher","type","command"}
  # with no nested `hooks` array. codex-cli drops such an entry silently: no
  # error, no warning, and `/hooks` does not count it, so the gate ships inert
  # while every filesystem-level post-check still passes. The assertion above
  # would go RED on that regression, but only implicitly; this one names the
  # defect directly so a future reader sees WHY the shape matters.
  if ( cd "$sbx" && jq -e --arg cmd "$WRAPPER_PATH" \
       '[.hooks.PreToolUse[] | select(.command == $cmd)] | length == 0' .codex/hooks.json >/dev/null 2>&1 ); then
    _m0011_ok 0 "Step 1: wrapper entry is NOT in the silently-dropped flat schema (no group-level .command)"
  else
    _m0011_ok 1 "Step 1: wrapper entry is NOT in the silently-dropped flat schema (no group-level .command)"
  fi

  # The matcher group must carry its command in a nested `hooks` ARRAY — the
  # exact shape codex-cli loads. Asserted structurally, not just by lookup.
  if ( cd "$sbx" && jq -e --arg cmd "$WRAPPER_PATH" \
       '.hooks.PreToolUse[] | select(.matcher == "apply_patch") | (.hooks | type == "array") and ((.hooks | length) >= 1)' .codex/hooks.json >/dev/null 2>&1 ); then
    _m0011_ok 0 "Step 1: apply_patch matcher group carries a nested hooks[] array (codex-cli load shape)"
  else
    _m0011_ok 1 "Step 1: apply_patch matcher group carries a nested hooks[] array (codex-cli load shape)"
  fi

  # Idempotent re-apply — no duplicate entry. Mirrors test_migration_0008's
  # partial-application fixture discipline (run-tests.sh:1928, "each step
  # checks its OWN idempotency"): 0011's Step 1 Apply is an unconditional
  # leaf-level array-append BY DESIGN (T-13-04 — never an append-if-absent
  # body, which is what 0008's OBJECT merge achieves for free but an ARRAY
  # append cannot without re-checking membership); it is the EXTRACTED
  # Idempotency check that must gate re-invocation, exactly as the real
  # update flow would. The regression this proves: if the idempotency
  # check's own `select` match ever stopped tracking the wrapper's command
  # string, this assertion (not the Apply body) is what would catch a
  # silent double-fire on every re-run.
  if ( cd "$sbx" && export CODEX_HOME="$CODEX_HOME_FOR_TEST" && eval "$step1_idem" >/dev/null 2>&1 ); then
    out=""; rc=0
  else
    out="$(_m0011_apply "$sbx" "$CODEX_HOME_FOR_TEST" "$step1_apply")"; rc=$?
  fi
  _m0011_ok "$rc" "Step 1 Apply re-executes cleanly (idempotent re-apply, gated by its own Idempotency check) — got exit=$rc"

  if ( cd "$sbx" && jq -e '.hooks.PreToolUse | length == 2' .codex/hooks.json >/dev/null 2>&1 ); then
    _m0011_ok 0 "Step 1: idempotent re-apply adds NO duplicate entry (still exactly 2)"
  else
    _m0011_ok 1 "Step 1: idempotent re-apply adds NO duplicate entry (still exactly 2)"
  fi

  # Step 2 — config.toml [features] hooks = true merge.
  out="$(_m0011_apply "$sbx" "$CODEX_HOME_FOR_TEST" "$step2_apply")"; rc=$?
  _m0011_ok "$rc" "Step 2 Apply executes cleanly against the seeded sandbox — got exit=$rc"
  [ "$rc" -ne 0 ] && printf '%s\n' "$out" | sed 's/^/    /'

  if grep -q '^foo = "bar"' "$sbx/.codex/config.toml" && grep -q '^\[some_other\]' "$sbx/.codex/config.toml"; then
    _m0011_ok 0 "Step 2: pre-existing decoy [some_other] table survives the [features] merge (T-13-05)"
  else
    _m0011_ok 1 "Step 2: pre-existing decoy [some_other] table survives the [features] merge (T-13-05)"
  fi

  if grep -q '^hooks = true$' "$sbx/.codex/config.toml"; then
    _m0011_ok 0 "Step 2: [features] hooks = true present after apply"
  else
    _m0011_ok 1 "Step 2: [features] hooks = true present after apply"
  fi

  # Idempotent re-apply — no duplicate flag. Step 2's Apply is idempotent by
  # construction (the awk pass replaces an existing `hooks =` line rather
  # than appending a second one), but re-invocation is still gated by the
  # extracted Idempotency check first, matching Step 1's discipline and the
  # real update flow (each step checks its OWN idempotency, run-tests.sh:1928).
  if ( cd "$sbx" && export CODEX_HOME="$CODEX_HOME_FOR_TEST" && eval "$step2_idem" >/dev/null 2>&1 ); then
    out=""; rc=0
  else
    out="$(_m0011_apply "$sbx" "$CODEX_HOME_FOR_TEST" "$step2_apply")"; rc=$?
  fi
  _m0011_ok "$rc" "Step 2 Apply re-executes cleanly (idempotent re-apply, gated by its own Idempotency check) — got exit=$rc"

  local hooks_count
  hooks_count="$(grep -c '^hooks = true$' "$sbx/.codex/config.toml" 2>/dev/null || true)"
  if [ "$hooks_count" = "1" ]; then
    _m0011_ok 0 "Step 2: idempotent re-apply adds NO duplicate hooks=true line (still exactly 1)"
  else
    _m0011_ok 1 "Step 2: idempotent re-apply adds NO duplicate hooks=true line (still exactly 1, got $hooks_count)"
  fi

  # ── SC#4-negative: a second repo with no .codex/hooks.json has no
  # PreToolUse plan-review entry — asserted by absence, never by running
  # Step 1 against it (the point is an UNTOUCHED second repo).
  local sbx2="$tmp/sandbox2"
  mkdir -p "$sbx2/.codex"
  ( cd "$sbx2" && git init -q )

  if [ ! -f "$sbx2/.codex/hooks.json" ]; then
    _m0011_ok 0 "SC#4-negative: second repo has no .codex/hooks.json before any apply (clean state)"
  else
    _m0011_ok 1 "SC#4-negative: second repo has no .codex/hooks.json before any apply (clean state)"
  fi

  # Searches BOTH schemas — group-level `.command` (the dropped flat form) and
  # the nested `hooks[].command` (the real load shape). An absence assertion
  # that checks only one shape can pass while an entry in the other shape is
  # sitting right there, which would make this negative half vacuously true.
  if [ ! -f "$sbx2/.codex/hooks.json" ] || ! jq -e --arg cmd "$WRAPPER_PATH" \
       '[.hooks.PreToolUse[]? | (.command // empty), ((.hooks // [])[]? | .command)] | index($cmd)' \
       "$sbx2/.codex/hooks.json" >/dev/null 2>&1; then
    _m0011_ok 0 "SC#4-negative: second, unrelated repo carries NO plan-review PreToolUse entry (asserted by absence, both schemas)"
  else
    _m0011_ok 1 "SC#4-negative: second, unrelated repo carries NO plan-review PreToolUse entry (asserted by absence, both schemas)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# test_hook_wrapper_stderr_contract (HOOK-02, SC#3) — mutation-proves that
# hook-wrapper-plan-review.sh's exit-2 fallback branch ALWAYS writes a
# non-empty reason to its own stderr before exiting. A silent exit-2 block
# with no reason is the fail-open nemesis 13-02-PLAN.md names: codex-cli
# treats invalid/partial hook stdout as a hook FAILURE and runs the tool
# anyway (13-01-SPIKE-FINDINGS.md STEP 3), so a caller relying on this
# fallback path needs a guarantee it never goes silent, not just that it
# "currently" writes something.
#
# Both directions are asserted, not just the fix:
#   GREEN — the real (unmutated) wrapper, forced down the fallback branch by
#           a stub check-plan-review.sh that exits 2 with EMPTY stdout+
#           stderr, exits 2 AND writes non-empty stderr of its OWN.
#   RED   — a MUTATED copy of the same wrapper, with the fallback's `>&2`
#           write neutralized (redirected to /dev/null via a grep-located
#           marker, never a hardcoded line number, so this stays valid as
#           the wrapper grows), exits 2 with EMPTY stderr against the exact
#           same fixture. The test PASSES by confirming this RED state is
#           detectable — i.e. that the GREEN wrapper's stderr write is what
#           stands between "silent block" and "attributable block", and a
#           regression that drops it is caught, not silently accepted.
#
# Pinned portable idioms only (ubuntu + macOS CI matrix, RESEARCH.md
# Environment Availability): no GNU-only sed flags, no `sed -i` (BSD/GNU
# disagree on `-i` syntax) — the mutated copy is produced by piping sed's
# transformed output to a new file, never in-place.
# ─────────────────────────────────────────────────────────────────────────────
test_hook_wrapper_stderr_contract() {
  echo ""
  echo "${YELLOW}=== hook-wrapper-plan-review.sh — fail-CLOSED stderr contract (HOOK-02, SC#3) ===${RESET}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — hook-wrapper stderr contract test not run"
    SKIP=$((SKIP+1)); return
  fi

  local WRAPPER="$REPO_ROOT/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
  if [ ! -f "$WRAPPER" ]; then
    echo "  ${RED}FAIL${RESET} contract: $WRAPPER not found"
    FAIL=$((FAIL+1))
    return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # Stub check-plan-review.sh that exits 2 with EMPTY stdout AND EMPTY
  # stderr — the fixture that forces the wrapper's own fallback branch
  # (check-plan-review.sh's real _cpr_block() always writes a reason, so
  # this stub simulates the "should be unreachable" case the fallback
  # exists to defend against, per RESEARCH.md Assumption A3).
  mkdir -p "$tmp/skills/agentic-apps-workflow/scripts"
  cat > "$tmp/skills/agentic-apps-workflow/scripts/check-plan-review.sh" <<'STUB'
#!/usr/bin/env bash
exit 2
STUB
  chmod +x "$tmp/skills/agentic-apps-workflow/scripts/check-plan-review.sh"

  local payload='{"tool_name":"apply_patch","tool_input":{}}'

  # ── GREEN: the real wrapper, unmutated ──────────────────────────────────
  local green_stdout green_stderr green_rc
  green_stdout="$(printf '%s' "$payload" | CODEX_HOME="$tmp" bash "$WRAPPER" 2>"$tmp/green.stderr")"
  green_rc=$?
  green_stderr="$(cat "$tmp/green.stderr")"

  if [ "$green_rc" -eq 2 ] && [ -n "$green_stderr" ]; then
    echo "  ${GREEN}PASS${RESET} contract: real wrapper's fallback exits 2 with non-empty stderr (GREEN) — rc=$green_rc"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} contract: real wrapper's fallback did NOT exit 2 with non-empty stderr — rc=$green_rc, stderr='$green_stderr'"
    FAIL=$((FAIL+1))
  fi

  # ── RED: a mutated copy with the fallback's stderr write neutralized ────
  # Locate the marker by grep, never a hardcoded line number (13-02-PLAN.md
  # Task 2 action) — the echo line immediately follows the marker line.
  local marker_line echo_line mutated_wrapper
  marker_line="$(grep -n 'FALLBACK-STDERR-MARKER' "$WRAPPER" | head -1 | cut -d: -f1)"

  if [ -z "$marker_line" ]; then
    echo "  ${RED}FAIL${RESET} contract: FALLBACK-STDERR-MARKER not found in $WRAPPER — mutation target lost"
    FAIL=$((FAIL+1))
  else
    echo_line=$((marker_line + 1))
    mutated_wrapper="$tmp/mutated-wrapper.sh"
    # Redirect the fallback echo's stderr write to /dev/null instead of
    # /dev/stderr — portable sed (no GNU-only flags, no -i), piped to a new
    # file rather than edited in place.
    sed "${echo_line}s#>&2#>/dev/null#" "$WRAPPER" > "$mutated_wrapper"
    chmod +x "$mutated_wrapper"

    local red_stdout red_stderr red_rc
    red_stdout="$(printf '%s' "$payload" | CODEX_HOME="$tmp" bash "$mutated_wrapper" 2>"$tmp/red.stderr")"
    red_rc=$?
    red_stderr="$(cat "$tmp/red.stderr")"

    if [ "$red_rc" -eq 2 ] && [ -z "$red_stderr" ]; then
      echo "  ${GREEN}PASS${RESET} contract: mutated wrapper (fallback stderr silenced) exits 2 with EMPTY stderr (RED is detectable) — rc=$red_rc"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} contract: mutation did not reproduce the RED (fail-open) state — rc=$red_rc, stderr='$red_stderr' (expected rc=2, empty stderr)"
      FAIL=$((FAIL+1))
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Native-hook vs agent-bash Source tag (debug session codex-hook-not-firing,
# 2026-07-19). Root cause of that session: a block observed in a live codex
# transcript was textually indistinguishable between "the model's own
# AGENTS.md-mandated bash self-check ran check-plan-review.sh and blocked"
# (prompt-based, NOT enforcement — hypothesis 5) and "codex-cli's native
# PreToolUse dispatch denied an apply_patch call independent of model
# compliance" (real enforcement — HOOK-03's whole purpose). This suite pins
# the fix: check-plan-review.sh's _cpr_block() now always emits a `Source:`
# line, defaulting to "agent-bash" and switching to "native-hook" only when
# GSD_PLAN_REVIEW_SOURCE=native-hook is set — which only
# hook-wrapper-plan-review.sh sets, and only when it execs the gate. It also
# regression-guards the sed portability fix found while building this suite:
# CPR_FILE derivation used a GNU-only `\|` BRE alternation that silently
# never matched on BSD/macOS sed, so `--file` was never threaded through on
# this operator's own machine — `sed -E` fixes it for both dialects.
# ─────────────────────────────────────────────────────────────────────────────

test_hook_native_source_evidence() {
  echo ""
  echo "${YELLOW}=== check-plan-review.sh / hook-wrapper — native-hook vs agent-bash Source tag (codex-hook-not-firing) ===${RESET}"

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/.planning/phases" "$tmp/err"
  local errdir="$tmp/err"
  local s phasedir e

  # ── Direct invocation (mirrors the agent's own AGENTS.md bash ritual) ──────
  # No GSD_PLAN_REVIEW_SOURCE set — must default to "agent-bash", never omit
  # the tag, never silently say "native-hook" for a plain direct call.

  s="$tmp/direct"
  phasedir="$(_cpr_enf_phase "$s" "08-direct-source")"
  e="$errdir/direct.err"
  _cpr_case "direct call: no *-REVIEWS.md -> exit 2" "$s" 2 --err-out "$e"
  _cpr_check_contains "direct call: Source tag defaults to agent-bash" "$e" "Source:    agent-bash"
  if grep -qF -- "Source:    native-hook" "$e"; then
    echo "  ${RED}FAIL${RESET} direct call: Source tag must NOT read native-hook (env unset)"
    FAIL=$((FAIL+1))
  else
    echo "  ${GREEN}PASS${RESET} direct call: Source tag does not falsely claim native-hook"
    PASS=$((PASS+1))
  fi

  # ── GSD_PLAN_REVIEW_SOURCE=native-hook set directly on check-plan-review.sh ─
  # (isolates the _cpr_block() half of the contract from the wrapper).

  s="$tmp/tagged"
  phasedir="$(_cpr_enf_phase "$s" "08-tagged-source")"
  e="$errdir/tagged.err"
  ( cd "$s" && GSD_PLAN_REVIEW_SOURCE=native-hook bash "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" ) >/dev/null 2>"$e"
  local tagged_rc=$?
  if [ "$tagged_rc" = "2" ]; then
    echo "  ${GREEN}PASS${RESET} GSD_PLAN_REVIEW_SOURCE=native-hook: still blocks (exit=2)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} GSD_PLAN_REVIEW_SOURCE=native-hook: expected exit=2, got exit=$tagged_rc"
    FAIL=$((FAIL+1))
  fi
  _cpr_check_contains "GSD_PLAN_REVIEW_SOURCE=native-hook: Source tag reads native-hook" "$e" "Source:    native-hook"

  # ── End-to-end through hook-wrapper-plan-review.sh ──────────────────────────
  # A realistic apply_patch PreToolUse payload (same shape 13-05-LIVE-SESSION.md
  # section 3 captured), run with a scratch CODEX_HOME carrying only the real
  # check-plan-review.sh so the wrapper's $GATE resolves. Never touches the
  # operator's real ~/.codex/hook-wrapper-plan-review.log (CODEX_HOME is
  # this test's own tmp dir).

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ${YELLOW}SKIP${RESET} jq not available — wrapper end-to-end Source/log test not run"
    SKIP=$((SKIP+1))
  else
    s="$tmp/wrapper-e2e"
    phasedir="$(_cpr_enf_phase "$s" "08-wrapper-e2e")"
    local codexhome="$tmp/codexhome"
    mkdir -p "$codexhome/skills/agentic-apps-workflow/scripts"
    cp "$REPO_ROOT/skills/agentic-apps-workflow/scripts/check-plan-review.sh" \
       "$codexhome/skills/agentic-apps-workflow/scripts/check-plan-review.sh"

    local payload wrapper_out wrapper_rc logfile
    payload='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: NOTES-scratch.md\n+hello\n*** End Patch"}}'
    wrapper_out="$(cd "$s" && printf '%s' "$payload" | CODEX_HOME="$codexhome" bash "$REPO_ROOT/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh")"
    wrapper_rc=$?
    logfile="$codexhome/hook-wrapper-plan-review.log"

    if [ "$wrapper_rc" = "0" ]; then
      echo "  ${GREEN}PASS${RESET} wrapper e2e: deny-via-JSON path exits 0 (load-bearing contract)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} wrapper e2e: expected exit=0 (deny expressed via JSON), got exit=$wrapper_rc"
      FAIL=$((FAIL+1))
    fi

    if printf '%s' "$wrapper_out" | grep -qF 'Source:    native-hook'; then
      echo "  ${GREEN}PASS${RESET} wrapper e2e: deny JSON reason carries Source: native-hook"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} wrapper e2e: deny JSON reason missing Source: native-hook — got: $wrapper_out"
      FAIL=$((FAIL+1))
    fi

    if printf '%s' "$wrapper_out" | grep -qF 'File:      NOTES-scratch.md'; then
      echo "  ${GREEN}PASS${RESET} wrapper e2e: --file derivation survives portable sed fix (BSD/GNU)"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} wrapper e2e: --file was not derived (sed portability regression) — got: $wrapper_out"
      FAIL=$((FAIL+1))
    fi

    if [ -f "$logfile" ] && grep -q 'tool_name=apply_patch' "$logfile"; then
      echo "  ${GREEN}PASS${RESET} wrapper e2e: self-evidencing invocation log records tool_name=apply_patch"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} wrapper e2e: invocation log missing or missing tool_name=apply_patch — $(cat "$logfile" 2>/dev/null || echo '<no log file>')"
      FAIL=$((FAIL+1))
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# DOC-03 — ADR-0009's dated Correction section (Phase 13, HOOK-01/DOC-03;
# 13-04-PLAN.md). Grep-assertion, not a fixture/mutation harness: pins the
# Correction section's CONTENT so a silent removal of any one recorded item
# — d.9 superseded, d.12 reversed (by reference), or the global-vs-
# project-scoped factual correction — goes RED. Each check is scoped to the
# section's own line span (heading to EOF, its document position), not the
# whole file, so it cannot pass by matching decision 12's pre-existing
# Phase-12 inline markers instead of the new section.
# ─────────────────────────────────────────────────────────────────────────────

test_adr_0009_correction() {
  echo ""
  echo "${YELLOW}=== ADR-0009 Correction section (DOC-03) ===${RESET}"

  local adr="$REPO_ROOT/docs/decisions/0009-plan-review-gate.md"

  if [ ! -f "$adr" ]; then
    echo "  ${RED}FAIL${RESET} $adr MISSING"
    FAIL=$((FAIL+1))
    return
  fi

  # (a) exactly one '## Correction' heading — a missing OR a duplicated
  # heading both flip this RED.
  local heading_count
  heading_count="$(grep -c '^## Correction' "$adr")"
  if [ "$heading_count" -eq 1 ]; then
    echo "  ${GREEN}PASS${RESET} exactly one '## Correction' heading ($heading_count)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} expected exactly one '## Correction' heading, found $heading_count"
    FAIL=$((FAIL+1))
  fi

  # Portable (BSD/macOS awk + gawk both honor '/pat/,0' as "to EOF", per
  # migrations/run-tests.sh:609's existing awk-range precedent).
  local section
  section="$(awk '/^## Correction/,0' "$adr")"

  # (b) decision 9 recorded superseded.
  if printf '%s\n' "$section" | grep -iq 'decision 9' \
     && printf '%s\n' "$section" | grep -iq 'supersed'; then
    echo "  ${GREEN}PASS${RESET} Correction section records decision 9 superseded"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Correction section missing decision 9 superseded language"
    FAIL=$((FAIL+1))
  fi

  # (c) decision 12 recorded reversed, BY REFERENCE.
  if printf '%s\n' "$section" | grep -iq 'decision 12' \
     && printf '%s\n' "$section" | grep -iq 'revers'; then
    echo "  ${GREEN}PASS${RESET} Correction section references decision 12 reversed"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Correction section missing decision 12 reversed reference"
    FAIL=$((FAIL+1))
  fi

  # (c2) ...and it is genuinely a reference, not a duplicate of decision 12's
  # own guard-mechanics walkthrough (Phase 12's inline markers are the only
  # place `_canon_dir`/`_is_contained` should appear).
  if printf '%s\n' "$section" | grep -q '_canon_dir\|_is_contained'; then
    echo "  ${RED}FAIL${RESET} Correction section re-explains decision 12's guard mechanics (duplicate, not reference)"
    FAIL=$((FAIL+1))
  else
    echo "  ${GREEN}PASS${RESET} Correction section does not duplicate decision 12's guard mechanics"
    PASS=$((PASS+1))
  fi

  # (d) the "global, not per-project" factual correction.
  if printf '%s\n' "$section" | grep -iq 'project-scoped' \
     && printf '%s\n' "$section" | grep -iqE 'global rather than per-project|not global'; then
    echo "  ${GREEN}PASS${RESET} Correction section corrects the global-vs-project-scoped claim"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Correction section missing the global-vs-project-scoped factual correction"
    FAIL=$((FAIL+1))
  fi

  # (e) dated.
  if printf '%s\n' "$section" | grep -qE '2026-07-(1[7-9]|2[0-9])'; then
    echo "  ${GREEN}PASS${RESET} Correction section is dated"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} Correction section is not dated"
    FAIL=$((FAIL+1))
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatcher
# ─────────────────────────────────────────────────────────────────────────────

if [ -z "$FILTER" ] || [ "$FILTER" = "extract-step-block" ]; then
  test_extract_step_block_delimiter
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0000" ]; then
  test_migration_0000
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0001" ]; then
  test_migration_0001
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0002" ]; then
  test_migration_0002
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0003" ]; then
  test_migration_0003
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0004" ]; then
  test_migration_0004
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0005" ]; then
  test_migration_0005
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0006" ]; then
  test_migration_0006
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0007" ]; then
  test_migration_0007
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0008" ]; then
  test_migration_0008
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0008-step4" ]; then
  test_migration_0008_step4_write
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0009" ]; then
  test_migration_0009
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "determinism" ]; then
  test_validate_0009_anchor_determinism
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0010" ]; then
  test_migration_0010
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0011" ]; then
  test_migration_0011
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "check-plan-review" ]; then
  test_check_plan_review_resolver
  test_check_plan_review_enforcement
  test_check_plan_review_contract
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "hook-wrapper-plan-review" ]; then
  test_hook_wrapper_stderr_contract
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "hook-native-source" ]; then
  test_hook_native_source_evidence
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "adr-0009-correction" ]; then
  test_adr_0009_correction
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "0012" ]; then
  test_migration_0012
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "drift" ]; then
  test_drift
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "layout" ]; then
  test_repo_layout
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "${YELLOW}=== Summary ===${RESET}"
echo "  ${GREEN}PASS${RESET}: $PASS"
[ $FAIL -gt 0 ] && echo "  ${RED}FAIL${RESET}: $FAIL"
[ $SKIP -gt 0 ] && echo "  ${YELLOW}SKIP${RESET}: $SKIP"

if [ $FAIL -gt 0 ]; then
  exit 1
elif [ $PASS -eq 0 ] && [ $SKIP -eq 0 ]; then
  echo "  ${RED}NO TESTS RAN${RESET}"
  exit 1
else
  exit 0
fi
