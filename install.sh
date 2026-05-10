#!/usr/bin/env bash
# install.sh — install the codex-workflow skills into the user's
# Codex skills directory ($CODEX_HOME/skills, default ~/.codex/skills).
#
# Usage:
#   bash install.sh                  # symlink each skill (recommended)
#   bash install.sh --copy           # copy instead of symlinking (cuts
#                                    # the link to git pull updates)
#   bash install.sh --dry-run        # show what would happen
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

for arg in "$@"; do
  case "$arg" in
    --copy)    MODE="copy"  ;;
    --symlink) MODE="symlink" ;;
    --dry-run) DRY_RUN=1     ;;
    -h|--help)
      sed -n '2,12p' "$0"
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

  if [ -e "$dst" ]; then
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
    else
      echo "  ${RED}BLOCKED${RESET} $name (destination exists and is not a symlink — refusing to clobber)"
      FAILED=$((FAILED+1))
      return
    fi
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
# Templates symlink — so migrations can `cp` from a stable scaffolder path
# ─────────────────────────────────────────────────────────────────────────────
# The setup skill's migrations expect templates at
# $CODEX_HOME/skills/setup-codex-agenticapps-workflow/templates/.
# We make that path a symlink to the scaffolder's top-level templates/.

SETUP_DIR="$CODEX_SKILLS_DIR/setup-codex-agenticapps-workflow"
SETUP_TEMPLATES="$SETUP_DIR/templates"
SCAFFOLDER_TEMPLATES="$SCAFFOLDER_ROOT/templates"

if [ -d "$SETUP_DIR" ] || [ -L "$SETUP_DIR" ]; then
  if [ -e "$SETUP_TEMPLATES" ] && [ ! -L "$SETUP_TEMPLATES" ]; then
    echo "  ${RED}BLOCKED${RESET} setup skill's templates/ link (destination exists and is not a symlink)"
    FAILED=$((FAILED+1))
  else
    if [ -L "$SETUP_TEMPLATES" ] && [ "$(readlink "$SETUP_TEMPLATES")" = "$SCAFFOLDER_TEMPLATES" ]; then
      echo "  ${GREEN}OK${RESET}     setup-skill templates/ link (already linked)"
      SKIPPED=$((SKIPPED+1))
    else
      [ -L "$SETUP_TEMPLATES" ] && rm "$SETUP_TEMPLATES"
      if [ "$DRY_RUN" -eq 0 ]; then
        ln -s "$SCAFFOLDER_TEMPLATES" "$SETUP_TEMPLATES"
      fi
      echo "  ${GREEN}LINK${RESET}   setup-skill templates/ -> $SCAFFOLDER_TEMPLATES"
      INSTALLED=$((INSTALLED+1))
    fi
  fi
else
  echo "  ${YELLOW}skip${RESET}   setup skill not present at $SETUP_DIR"
fi

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

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "${YELLOW}dry-run only${RESET} — no changes written."
else
  echo "${GREEN}done.${RESET} Restart Codex (or open a fresh session) to pick up the new skills."
  echo ""
  echo "Next:"
  echo "  - In a fresh project: \$setup-codex-agenticapps-workflow"
  echo "  - In an existing installed project: \$update-codex-agenticapps-workflow"
fi
