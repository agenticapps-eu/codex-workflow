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
  ln -s "$s/.planning/phases/08-pointer-abs" "$s/.planning/current-phase"
  e="$errdir/step1a.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 1a — absolute pointer wins" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 1a resolves 08-pointer-abs" "$e" "08-pointer-abs"

  # Step 1b: explicit pointer, .planning/-relative value.
  s="$tmp/step1b"
  mkdir -p "$s/.planning/phases/08-pointer-rel"
  touch "$s/.planning/phases/08-pointer-rel/08-01-PLAN.md"
  ( cd "$s/.planning" && ln -s "phases/08-pointer-rel" current-phase )
  e="$errdir/step1b.err"
  GSD_PLAN_REVIEW_DEBUG=1 _cpr_case "resolution: step 1b — .planning-relative pointer wins" "$s" 0 --err-out "$e"
  _cpr_check_resolved "resolution: step 1b resolves 08-pointer-rel" "$e" "08-pointer-rel"

  # Step 2: STATE.md, canonical '## Current Position' heading.
  s="$tmp/step2a"
  mkdir -p "$s/.planning/phases/08-state-basic"
  touch "$s/.planning/phases/08-state-basic/08-01-PLAN.md"
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
  _cpr_check_contains "block: stderr names the resolved phase dir" "$e" "$phasedir"
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
  _cpr_check_contains "symlink: stderr names the symlink path" "$e" "$phasedir/08-REVIEWS.md"

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

if [ -z "$FILTER" ] || [ "$FILTER" = "0007" ]; then
  test_migration_0007
fi

if [ -z "$FILTER" ] || [ "$FILTER" = "check-plan-review" ]; then
  test_check_plan_review_resolver
  test_check_plan_review_enforcement
  test_check_plan_review_contract
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
