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

# Colors for output (skip if not a tty)
if [ -t 1 ]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RESET=$'\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  RESET=""
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ]; then
  echo "${RED}error:${RESET} run-tests.sh must be invoked from inside a git repo"
  exit 1
fi
cd "$REPO_ROOT"

PASS=0
FAIL=0
SKIP=0

# Filter (optional first non-`--` arg)
FILTER=""
for arg in "$@"; do
  case "$arg" in
    --) continue ;;
    *) FILTER="$arg"; break ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Helpers (kept for incremental migrations to use)
# ─────────────────────────────────────────────────────────────────────────────

# Extract a file from a git ref into a temp path.
# Usage: extract_to <ref> <path-in-repo> <output-path>
extract_to() {
  local ref="$1" path="$2" out="$3"
  mkdir -p "$(dirname "$out")"
  git show "$ref:$path" >"$out" 2>/dev/null
}

# Run an idempotency check shell snippet inside a fixture dir.
# Returns the exit code of the check.
run_check() {
  local fixture="$1" check="$2"
  ( cd "$fixture" && eval "$check" >/dev/null 2>&1 )
  return $?
}

# Assert helper.
# Usage: assert_check "<label>" "<check>" "<fixture>" "<expected: applied|not-applied>"
# Semantic: "applied" means the idempotency check returned 0 (skip — already done).
#          "not-applied" means it returned ANY non-zero (please apply).
assert_check() {
  local label="$1" check="$2" fixture="$3" expected="$4"
  run_check "$fixture" "$check"
  local actual=$?
  local pass=0
  case "$expected" in
    applied)     [ "$actual" = "0" ] && pass=1 ;;
    not-applied) [ "$actual" != "0" ] && pass=1 ;;
    *) echo "  ${RED}!${RESET} bad expected value: $expected"; FAIL=$((FAIL+1)); return ;;
  esac
  if [ "$pass" = "1" ]; then
    echo "  ${GREEN}PASS${RESET} $label (expected $expected, exit=$actual)"
    PASS=$((PASS+1))
  else
    echo "  ${RED}FAIL${RESET} $label (expected $expected, got exit=$actual)"
    echo "      check: $check"
    echo "      fixture: $fixture"
    FAIL=$((FAIL+1))
  fi
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
    templates/workflow-config.md \
    templates/agents-md-additions.md \
    templates/config-hooks.json \
    templates/adr-db-security-acceptance.md \
    templates/global-agents-additions.md \
    migrations/README.md \
    migrations/0000-baseline.md \
    migrations/test-fixtures/README.md \
    install.sh ; do
    if [ -f "$f" ]; then
      echo "  ${GREEN}PASS${RESET} $f exists"
      PASS=$((PASS+1))
    else
      echo "  ${RED}FAIL${RESET} $f MISSING"
      FAIL=$((FAIL+1))
    fi
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatcher
# ─────────────────────────────────────────────────────────────────────────────

if [ -z "$FILTER" ] || [ "$FILTER" = "0000" ]; then
  test_migration_0000
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
