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
#                                    # (do not bind OpenSpec / Superpowers)
#   bash install.sh --install-prereqs # authorise installing a missing
#                                    # prerequisite without being asked
#                                    # (env: AGENTICAPPS_INSTALL_PREREQS=1)
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
# spec §21 — the opt-in that authorises a consent-requiring install unattended.
# Both spellings are fixed by the section rather than chosen here: the
# non-interactive report has to name the flag that authorises the install, and
# four hosts inventing four spellings is the divergence §21 exists to remove.
INSTALL_PREREQS=0
case "${AGENTICAPPS_INSTALL_PREREQS:-0}" in 1|true|yes) INSTALL_PREREQS=1 ;; esac
# Set when a step the operator asked for did not happen. §21: an installer that
# silently omits a step exits 0 having done less than the operator believes,
# and a zero exit is what an automated caller reads.
SKIPPED=0

for arg in "$@"; do
  case "$arg" in
    --copy)          MODE="copy"  ;;
    --symlink)       MODE="symlink" ;;
    --dry-run)       DRY_RUN=1     ;;
    --skip-upstream) SKIP_UPSTREAM=1 ;;
    --install-prereqs) INSTALL_PREREQS=1 ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0
      ;;
    *)
      echo "${RED}error:${RESET} unknown argument: $arg"
      exit 2
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Consent (spec §21)
# ─────────────────────────────────────────────────────────────────────────────
# A write that can change software this workflow did not install is offered,
# never performed unasked. Installing a package into npm's global namespace is
# that kind of write: it can upgrade or replace something every other project
# on the machine resolves. Provisioning this repo, and writing into
# ~/.agenticapps/, are not — the operator asked for those by running this.
#
# Returns 0 if the operator accepted, 1 otherwise. Only an explicit y/yes
# counts. Empty input, anything unrecognised, and end-of-input all decline,
# because a declined install is recoverable by re-running and an unwanted
# global install is not.
prereq_consent() { # $1 = prerequisite name, $2 = the command that installs it
  local reply
  if [ "$INSTALL_PREREQS" -eq 1 ]; then
    echo "${YELLOW}note:${RESET} installing $1 — authorised by --install-prereqs"
    echo "      $2"
    return 0
  fi
  if [ ! -t 0 ]; then
    echo "${YELLOW}warn:${RESET} $1 is missing, and there is no terminal to ask on."
    echo "      it would be installed with: $2"
    echo "      to authorise that unattended, re-run with --install-prereqs"
    echo "      or set AGENTICAPPS_INSTALL_PREREQS=1."
    return 1
  fi
  echo "${YELLOW}note:${RESET} $1 is not installed. This installer can install it with:"
  echo "      $2"
  echo "      That changes a global package other projects on this machine resolve."
  printf '      install it now? [y/N] '
  IFS= read -r reply || reply=""
  case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) echo "      declined." ; return 1 ;;
  esac
}

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

# git is a declared prerequisite. §21 requires reporting a missing one BY NAME,
# with what will not work without it — and git is a system runtime, so it is
# reported and never offered: installing one is platform-dependent in ways a
# shell script handles badly. Without this check the failure surfaces further
# down as git's own "command not found", which names the symptom.
if ! command -v git >/dev/null 2>&1; then
  echo "${YELLOW}warn:${RESET} 'git' not found on PATH."
  echo "      the vendor/agenticapps-shared submodule refresh and this repo's own"
  echo "      pre-commit wiring will be skipped. Skill installation still works."
  echo "      git is a system runtime — install it with your OS package manager."
  SKIPPED=1
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
# Install the §18 OpenSpec change-gate (the real enforcement surface)
# ─────────────────────────────────────────────────────────────────────────────
# ONE host-agnostic shell script, installed globally and shared by every
# AgenticApps host; each host's hook is thin wiring that pipes a tool-call
# payload to it. The git pre-commit hook and the CI check are the
# agent-agnostic FLOOR — a PreToolUse hook is loaded at session start and
# cannot gate the session that installed it (core spec §18).
AA_BIN="$HOME/.agenticapps/bin"
AA_GIT_HOOKS="$HOME/.agenticapps/git-hooks"

echo ""
echo "${YELLOW}Installing the OpenSpec change-gate (spec §18)${RESET}"
echo "  ${GREEN}GATE${RESET}   $AA_BIN/openspec-change-gate.sh   (host-agnostic enforcement surface)"
echo "  ${GREEN}REVIEW${RESET} $AA_BIN/reviewer-cli.sh           (</dev/null + timeout wrapper)"
echo "  ${GREEN}HOOK${RESET}   .codex/hooks.json PreToolUse -> hook-wrapper-openspec-gate.sh"
echo "  ${GREEN}HOOK${RESET}   .git/hooks/pre-commit             (agent-agnostic floor)"
echo "  ${GREEN}CI${RESET}     .github/workflows/openspec-gate.yml"

# ── where the bytes come from (ADR-0047, ported from claude-workflow) ────────
# This repo does NOT vendor the gate or the wrapper. tools/core-vendor.manifest
# records WHICH core revision it trusts and WHAT each file must hash to;
# materialise-core-artifacts.sh turns that into verified bytes at bin/, and
# install-gate.sh then arbitrates and publishes them as before.
#
# bin/ is a CACHE, not source: the two files are gitignored and regenerated
# from the pin, so they cannot drift. Vendoring is what this replaced — the
# runtime never read the committed copies (the project hook resolves
# ~/.agenticapps/bin first), so they existed only to feed this script, and on
# 2026-07-31 they were gate 1.3.1 against core's 2.0.0 and wrapper 1.1.0
# against 1.2.0. Arbitration meant that was never destructive, only silently
# useless — but a fresh machine installed from this host alone got the
# ENFORCING gate.
#
# It stays at bin/ rather than a temp dir because several things depend on that
# path: the setup skill's templates/*.sh are symlinks into bin/, and migration
# 0013 installs a target repo's copies from that stable installed path.
#
# Fails CLOSED. An installer that cannot verify what it is about to publish
# into a directory shared by every agent on this machine must stop.
if ! "$SCAFFOLDER_ROOT/bin/materialise-core-artifacts.sh"; then
  echo "  ${RED}FAIL${RESET}   could not materialise core's artifacts from the pin."
  echo "           Nothing was published. Fix the pin or the source, then re-run."
  echo "           Offline with no core checkout? Clone core beside this repo, or"
  echo "           set CORE_CHECKOUT=/path/to/agenticapps-workflow-core."
  exit 1
fi

# The gate is installed through bin/install-gate.sh, which ARBITRATES BY
# VERSION rather than blindly overwriting. All four AgenticApps hosts write
# $AA_BIN/openspec-change-gate.sh, so a plain `install` here is last-writer-wins:
# running an older host's installer afterwards silently republishes its copy and
# reverts the fix for every agent on the machine. That is the hazard issue #26
# was filed about, and core's gate README makes honouring `# gate-version:` a
# MUST for every host. It runs even under --dry-run, where it reports the
# decision it would take and writes nothing.
"$SCAFFOLDER_ROOT/bin/install-gate.sh" \
  $([ "$DRY_RUN" -eq 1 ] && echo --dry-run) \
  "$SCAFFOLDER_ROOT/bin/openspec-change-gate.sh" \
  "$AA_BIN/openspec-change-gate.sh"
gate_rc=$?
case "$gate_rc" in
  0) : ;;   # installed, or deliberately declined a downgrade — both fine
  2) echo "  ${YELLOW}WARN${RESET}   another installer holds the gate lock; shared gate left as-is."
     echo "           Re-run install.sh in a moment. This is contention, not breakage." ;;
  *) # A real failure. Say so loudly: the shared gate is the copy the pre-commit
     # and PreToolUse surfaces prefer, so leaving it un-upgraded silently means
     # every repo on this machine keeps enforcing with whatever was there before,
     # while the rest of the install reports success.
     echo "  ${RED}FAIL${RESET}   the shared change-gate was NOT installed (exit $gate_rc)."
     echo "           $AA_BIN/openspec-change-gate.sh still holds its previous contents."
     echo "           Every repo on this machine keeps enforcing with that copy. Fix the"
     echo "           cause above and re-run, or install deliberately:"
     echo "             install -m 0755 '$SCAFFOLDER_ROOT/bin/openspec-change-gate.sh' '$AA_BIN/openspec-change-gate.sh'" ;;
esac

# The review PRODUCER's wrapper is the SAME shared-path hazard as the gate, and
# it is not hypothetical. On 2026-07-25 a sibling host's installer delivered the
# correctly-arbitrated 1.2.2 gate and, in the SAME run, blind-installed its
# 3-arm reviewer-cli over this repo's 4-arm one. The `opencode` arm vanished and
# the next review that asked for it got `unknown vendor` mid-run — recorded as
# "reviewer unavailable" and waved through with one fewer opinion. The gate
# survived that same run only because it carries a marker every host compares.
# Same rule, same script, on `# reviewer-cli-version:` (core#41 / core#42).
"$SCAFFOLDER_ROOT/bin/install-gate.sh" \
  $([ "$DRY_RUN" -eq 1 ] && echo --dry-run) \
  --marker reviewer-cli-version \
  "$SCAFFOLDER_ROOT/bin/reviewer-cli.sh" \
  "$AA_BIN/reviewer-cli.sh"
cli_rc=$?
case "$cli_rc" in
  0) : ;;   # installed, or deliberately declined a downgrade — both fine
  2) echo "  ${YELLOW}WARN${RESET}   another installer holds the reviewer-cli lock; shared wrapper left as-is."
     echo "           Re-run install.sh in a moment. This is contention, not breakage." ;;
  *) # Not fatal to the gate, but say it plainly: reviews are the evidence the
     # gate consumes, and a degraded producer reports clean while supplying less
     # of it. A missing vendor arm surfaces mid-review as `unknown vendor`.
     echo "  ${RED}FAIL${RESET}   the shared reviewer-cli was NOT installed (exit $cli_rc)."
     echo "           $AA_BIN/reviewer-cli.sh still holds its previous contents. If that copy"
     echo "           predates core#42 it may be missing a vendor arm, and the review that"
     echo "           needs it will record 'reviewer unavailable' rather than fail loudly." ;;
esac

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$AA_BIN" "$AA_GIT_HOOKS"
  # Stage the pre-commit at a stable global path so the per-project setup skill
  # can install it into any repo without needing this scaffolder checked out.
  install -m 0755 "$SCAFFOLDER_ROOT/bin/git-hooks/pre-commit"    "$AA_GIT_HOOKS/pre-commit"
  # ...and wire this repo's own, since it dogfoods its workflow.
  if hookdir="$(git -C "$SCAFFOLDER_ROOT" rev-parse --git-path hooks 2>/dev/null)"; then
    ( cd "$SCAFFOLDER_ROOT" && mkdir -p "$hookdir" \
        && install -m 0755 bin/git-hooks/pre-commit "$hookdir/pre-commit" ) \
      && echo "  ${GREEN}OK${RESET}     pre-commit installed into $hookdir/"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Bind upstream — OpenSpec (planning front end) + Superpowers (execution)
# ─────────────────────────────────────────────────────────────────────────────
# codex-workflow ships only the AgenticApps layer. OpenSpec and Superpowers are
# the maintained upstream distributions — see docs/BINDING.md, docs/WORKFLOW.md,
# and docs/decisions/0011-openspec-superpowers-adoption.md. OpenSpec replaces
# the GSD phase engine as the planning driver at v1.0.0 (core spec §16); the
# bind-upstream RULE from ADR-0007 is unchanged, only its subject moved.
# Pass --skip-upstream to install only the AgenticApps skills.
if [ "$SKIP_UPSTREAM" -eq 0 ]; then
  echo ""
  echo "${YELLOW}Binding OpenSpec — openspec init --tools codex --profile core${RESET}"
  echo "  (generates the openspec/ spec slot + the six \$openspec-* skills under .codex/skills/)"

  if [ "$DRY_RUN" -eq 0 ]; then
    # The openspec CLI is this front end's core dependency, and it used to be
    # installed automatically on that reasoning. Being a dependency is not the
    # question §21 asks: `npm i -g` mutates a namespace shared with software
    # this workflow did not install, so it is offered and never performed
    # unasked. Instructing without installing would also be conformant; asking
    # is the option the operator most likely wants.
    if ! command -v openspec >/dev/null 2>&1; then
      OPENSPEC_INSTALL="npm i -g @fission-ai/openspec"
      if ! command -v npm >/dev/null 2>&1; then
        echo "${YELLOW}warn:${RESET} openspec CLI and npm are both absent."
        echo "      npm is a system runtime — this installer will not install it."
        echo "      Install Node.js, then: $OPENSPEC_INSTALL"
        SKIPPED=1
      elif prereq_consent "openspec" "$OPENSPEC_INSTALL"; then
        if npm i -g @fission-ai/openspec; then
          echo "  ${GREEN}OK${RESET}     installed openspec (@fission-ai/openspec, global)"
        else
          rc=$?
          echo "${RED}error:${RESET} $OPENSPEC_INSTALL failed (exit $rc)." >&2
          echo "      openspec is still absent — this is not being treated as installed." >&2
          SKIPPED=1
        fi
      else
        SKIPPED=1
        echo "      skipped: the openspec/ slot will not be generated. Complete it later with:"
        echo "        $OPENSPEC_INSTALL"
        echo "        openspec init --tools codex --profile core"
      fi
    fi

    if command -v openspec >/dev/null 2>&1; then
      if [ ! -d "$SCAFFOLDER_ROOT/openspec" ]; then
        ( cd "$SCAFFOLDER_ROOT" && openspec init --tools codex --profile core --force ) \
          && echo "  ${GREEN}OK${RESET}     openspec slot + \$openspec-* skills generated" \
          || echo "${YELLOW}warn:${RESET} openspec init failed — run it manually in this repo."
      else
        echo "  ${GREEN}OK${RESET}     openspec/ already present (skipping init)"
      fi
      echo "  CLI: $(openspec --version 2>/dev/null || echo unknown)"
    else
      echo "${YELLOW}warn:${RESET} openspec still unavailable — the change-gate BLOCKS edits under an"
      echo "      active change while it cannot assert validate-green. That is deliberate:"
      echo "      an unvalidatable change must not pass the gate (spec §18)."
    fi
  fi

  echo ""
  echo "${YELLOW}Superpowers${RESET} (TDD, brainstorming, verification, code-review,"
  echo "  finishing-branch, systematic-debugging) is the second upstream — the official"
  echo "  Codex plugin. Install it so the \`superpowers:*\` gate bindings resolve:"
  if [ "$DRY_RUN" -eq 0 ] && command -v codex >/dev/null 2>&1; then
    codex plugin add superpowers 2>/dev/null \
      || echo "  ${YELLOW}note:${RESET} run 'codex plugin add superpowers' (from the openai-curated marketplace)."
  else
    echo "    codex plugin add superpowers        # from the openai-curated marketplace"
  fi
  echo "  Verify: codex plugin list | grep superpowers"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Operator action the installer cannot do for you
# ─────────────────────────────────────────────────────────────────────────────
# codex-cli requires the operator to TRUST a project hook before it runs. An
# untrusted entry shows as `Installed N / Active N-1 / Review 1` and enforces
# NOTHING while looking installed. This is a real failure mode, observed in
# phase 13 — not a theoretical one.
echo ""
echo "${YELLOW}ACTION REQUIRED${RESET} — trust the PreToolUse hook, or it enforces nothing:"
echo "  1. Start a fresh Codex session in the target repo"
echo "  2. Run ${GREEN}/hooks${RESET} and confirm the openspec-gate entry is ${GREEN}Active${RESET}, not 'Review'"
echo "  An installed-but-untrusted hook is indistinguishable from an enforcing one"
echo "  in every output except this check. The git pre-commit + CI floor covers"
echo "  the gap in the meantime."

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo "${YELLOW}dry-run only${RESET} — no changes written."
elif [ "$SKIPPED" -eq 1 ]; then
  # §21 — completed work and skipped work are reported as different things, and
  # the exit status says which happened. Reporting alone is not sufficient: a
  # zero exit is what an automated caller reads.
  echo "${YELLOW}done, with skipped steps.${RESET} The skills are installed; the steps"
  echo "named above did not run. Re-run this installer once their prerequisites"
  echo "are present."
  exit 1
else
  echo "${GREEN}done.${RESET} Restart Codex (or open a fresh session) to pick up everything."
  echo ""
  echo "Next:"
  echo "  - In a fresh project:               \$setup-codex-agenticapps-workflow"
  echo "  - In an existing installed project: \$update-codex-agenticapps-workflow"
  echo "  - How the workflow runs:            docs/WORKFLOW.md"
  echo "  - Architecture + caveats:           docs/BINDING.md"
fi
