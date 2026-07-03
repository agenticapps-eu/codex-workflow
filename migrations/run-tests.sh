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

  # Injection byte-identity: applying Step 1's awk to fixture A must produce a
  # §11 block byte-identical to the mirror.
  awk -v mirror="$mirror" '
    /^## / && !done {
      print "<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->"
      while ((getline line < mirror) > 0) print line
      close(mirror); print ""; done=1
    }
    { print }
  ' "$tmp/a-AGENTS.md" > "$tmp/a-injected.md"
  awk '/^## Coding Discipline \(NON-NEGOTIABLE\)$/{f=1} f{print} /session-level discipline the model brings to every diff\.$/{exit}' \
    "$tmp/a-injected.md" > "$tmp/a-block.md"
  if diff -q "$tmp/a-block.md" "$mirror" >/dev/null 2>&1; then
    echo "  ${GREEN}PASS${RESET} injected §11 block is byte-identical to the mirror"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} injected §11 block differs from the mirror"
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
# Drift test — the scaffolder's SKILL.md version MUST equal the latest
# migration's to_version (version is migration-coupled).
# ─────────────────────────────────────────────────────────────────────────────

test_drift() {
  echo ""
  echo "${YELLOW}=== Drift — SKILL.md version == latest migration to_version ===${RESET}"
  # Mechanism from the shared lib (run_drift_test); the POLICY (a mismatch is a
  # hard fail) is this consumer's, per ADR-0035.
  if run_drift_test "$REPO_ROOT/skills/agentic-apps-workflow/SKILL.md" "$REPO_ROOT/migrations"; then
    echo "  ${GREEN}PASS${RESET} SKILL.md version matches latest migration to_version"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} drift mismatch (see message above)"
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
    migrations/test-fixtures/README.md \
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
# Dispatcher
# ─────────────────────────────────────────────────────────────────────────────

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
