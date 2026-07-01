#!/usr/bin/env bash
# install.sh — install the codex-workflow skills into the user's
# Codex skills directory ($CODEX_HOME/skills, default ~/.codex/skills).
#
# Usage:
#   bash install.sh                  # symlink each skill (recommended)
#   bash install.sh --copy           # copy instead of symlinking (cuts
#                                    # the link to git pull updates)
#   bash install.sh --dry-run        # show what would happen
#   bash install.sh --skip-upstream  # install only the AgenticApps skills
#                                    # (do not bind GSD / Superpowers)
#
# Idempotent — re-running with no changes produces "already linked"
# log lines and exits 0. Refuses to clobber non-symlink directories
# at the destination.
#
# This script is invoked once after cloning codex-workflow. After it
# runs, Codex auto-discovers the skills on its next session start.

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

# ─────────────────────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────────────────────

MODE="symlink"
DRY_RUN=0
SKIP_UPSTREAM=0

for arg in "$@"; do
  case "$arg" in
    --copy)          MODE="copy"  ;;
    --symlink)       MODE="symlink" ;;
    --dry-run)       DRY_RUN=1     ;;
    --skip-upstream) SKIP_UPSTREAM=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *)
      echo "${RED}error:${RESET} unknown argument: $arg"
      exit 2
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Resolve paths
# ─────────────────────────────────────────────────────────────────────────────

# Scaffolder root: directory containing this script.
SCAFFOLDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Codex skills directory (per Phase 0 ADR-0001 D1; verified against codex-cli 0.130.0).
CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"

# Sanity: the scaffolder must contain the expected skills.
if [ ! -d "$SCAFFOLDER_ROOT/skills/agentic-apps-workflow" ]; then
  echo "${RED}error:${RESET} install.sh must be run from the codex-workflow root."
  echo "       expected: $SCAFFOLDER_ROOT/skills/agentic-apps-workflow/"
  exit 1
fi

# Codex installed?
if ! command -v codex >/dev/null 2>&1; then
  echo "${YELLOW}warn:${RESET} 'codex' CLI not found on PATH."
  echo "      Continuing with skill install, but you'll need to install Codex"
  echo "      before the skills are usable. See https://developers.openai.com/codex/"
fi

# Refresh the agenticapps-shared submodule (provides the migration test harness
# primitives). Idempotent and non-fatal: a missing/transient submodule must not
# block skill linking. Guard on a real .git so copied/tarball trees (which carry
# .gitmodules but no git dir) don't fatal under the refresh.
if [ "$DRY_RUN" -eq 0 ] && [ -f "$SCAFFOLDER_ROOT/.gitmodules" ] \
   && { [ -d "$SCAFFOLDER_ROOT/.git" ] || [ -f "$SCAFFOLDER_ROOT/.git" ]; }; then
  echo "${YELLOW}note:${RESET} syncing git submodule(s) vendor/agenticapps-shared..."
  if ! { git -C "$SCAFFOLDER_ROOT" submodule sync --recursive \
      && git -C "$SCAFFOLDER_ROOT" submodule update --init --recursive; }; then
    echo "${YELLOW}warn:${RESET} submodule refresh failed — continuing with skill linking." >&2
    echo "      Fix later: git -C \"$SCAFFOLDER_ROOT\" submodule update --init --recursive" >&2
  fi
fi

# Ensure destination exists.
if [ ! -d "$CODEX_SKILLS_DIR" ]; then
  echo "${YELLOW}note:${RESET} creating $CODEX_SKILLS_DIR"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$CODEX_SKILLS_DIR"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Install each skill directory
# ─────────────────────────────────────────────────────────────────────────────

INSTALLED=0
SKIPPED=0
FAILED=0

install_one() {
  local src="$1"
  local name
  name="$(basename "$src")"
  local dst="$CODEX_SKILLS_DIR/$name"

  # NB: test -L before -e. A dangling symlink (target moved/deleted — e.g. the
  # repo was relocated) makes `-e` false because it follows the link, which
  # would skip replacement and leave `ln -s` to fail "File exists". Catch the
  # symlink first so stale/dangling links are always repointed.
  if [ -L "$dst" ]; then
    local target
    target="$(readlink "$dst")"
    if [ "$target" = "$src" ]; then
      echo "  ${GREEN}OK${RESET}     $name (already linked)"
      SKIPPED=$((SKIPPED+1))
      return
    else
      echo "  ${YELLOW}REPLACE${RESET} $name (was linked to $target)"
      if [ "$DRY_RUN" -eq 0 ]; then
        rm "$dst"
      fi
    fi
  elif [ -e "$dst" ]; then
    echo "  ${RED}BLOCKED${RESET} $name (destination exists and is not a symlink — refusing to clobber)"
    FAILED=$((FAILED+1))
    return
  fi

  case "$MODE" in
    symlink)
      if [ "$DRY_RUN" -eq 0 ]; then
        ln -s "$src" "$dst"
      fi
      echo "  ${GREEN}LINK${RESET}   $name -> $src"
      ;;
    copy)
      if [ "$DRY_RUN" -eq 0 ]; then
        cp -R "$src" "$dst"
      fi
      echo "  ${GREEN}COPY${RESET}   $name <- $src"
      ;;
  esac
  INSTALLED=$((INSTALLED+1))
}

echo ""
echo "${YELLOW}Installing codex-workflow skills (mode: $MODE; dry-run: $DRY_RUN)${RESET}"
echo "  scaffolder: $SCAFFOLDER_ROOT"
echo "  destination: $CODEX_SKILLS_DIR"
echo ""

for d in "$SCAFFOLDER_ROOT"/skills/*/; do
  d="${d%/}"
  install_one "$d"
done

# ─────────────────────────────────────────────────────────────────────────────
# Templates: no secondary symlink needed (v0.2.0 fix)
# ─────────────────────────────────────────────────────────────────────────────
# Templates now ship INSIDE the setup skill at
# skills/setup-codex-agenticapps-workflow/templates/ and are committed there.
# Because the whole setup-skill directory is symlinked above, migrations resolve
# them at the stable path
# $CODEX_HOME/skills/setup-codex-agenticapps-workflow/templates/ with NO
# install-time write inside the source tree. (Pre-v0.2.0, install.sh wrote a
# secondary symlink there which resolved back into the repo — that step is gone.)

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "${YELLOW}Summary${RESET}"
echo "  ${GREEN}installed/linked${RESET}: $INSTALLED"
echo "  ${YELLOW}skipped (already done)${RESET}: $SKIPPED"
[ $FAILED -gt 0 ] && echo "  ${RED}failed${RESET}: $FAILED"

if [ $FAILED -gt 0 ]; then
  echo ""
  echo "${RED}install incomplete${RESET} — see blocked entries above."
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Bind upstream — GSD + Superpowers (this repo no longer re-ports them)
# ─────────────────────────────────────────────────────────────────────────────
# codex-workflow ships only the AgenticApps layer. GSD and Superpowers are the
# maintained upstream distributions for Codex — see docs/BINDING.md and
# docs/decisions/0007-bind-upstream-gsd.md. Pass --skip-upstream to install only
# the AgenticApps skills.
if [ "$DRY_RUN" -eq 0 ] && [ "$SKIP_UPSTREAM" -eq 0 ]; then
  CODEX_PROMPTS_DIR="${CODEX_HOME:-$HOME/.codex}/prompts"
  echo ""
  echo "${YELLOW}Binding GSD (get-shit-done-codex, TÂCHES lineage) — /prompts:gsd-* + resources...${RESET}"
  echo "  (installs /prompts:gsd-* under $CODEX_PROMPTS_DIR; verify with /prompts:gsd-help)"
  if command -v npx >/dev/null 2>&1; then
    # Non-interactive global install: the installer bin is get-shit-done-cc; --global
    # skips its Global/Local prompt and writes to ~/.codex/{prompts,get-shit-done}.
    npx -y -p get-shit-done-codex get-shit-done-cc --global \
      || echo "${YELLOW}warn:${RESET} GSD install failed — run 'npx get-shit-done-codex' manually (pick Global)."
  else
    echo "${YELLOW}warn:${RESET} npx not found — install Node, then: npx get-shit-done-codex"
  fi
  echo ""
  echo "${YELLOW}Superpowers${RESET} (TDD, brainstorming, verification, code-review,"
  echo "  finishing-branch, systematic-debugging) is the second upstream. Install the"
  echo "  Superpowers distribution for Codex so the \`superpowers:*\` gate bindings resolve."
  echo "  Verify: ask Codex \"tell me about your superpowers\"."
fi

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "${YELLOW}dry-run only${RESET} — no changes written."
else
  echo "${GREEN}done.${RESET} Restart Codex (or open a fresh session) to pick up everything."
  echo ""
  echo "Next:"
  echo "  - In a fresh project:               \$setup-codex-agenticapps-workflow"
  echo "  - In an existing installed project: \$update-codex-agenticapps-workflow"
  echo "  - Architecture + caveats:           docs/BINDING.md"
fi
