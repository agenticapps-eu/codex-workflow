#!/usr/bin/env bash
# check-plan-review.sh — programmatic verifier for the plan-review
# pre-execution gate (spec/02:81-109; D-01 hybrid enforcement: the
# declarative binding in .planning/config.codex.json stays the source of
# truth, this script supplies the programmatic half spec/02:92-93 calls for).
#
# SCOPE OF THIS PLAN (08-01): only the allow paths. Repo-root self-location,
# the D-05 four-step resolver (with the D-06/D-07 corrections and the
# resolver_defects hardening from cross-AI review), and the D-08/D-09
# grandfather guards. The REVIEWS.md enforcement (exit 2), the escape
# hatches (GSD_SKIP_REVIEWS, multi-ai-review-skipped), and the block
# message are plan 08-02's scope — see the marker comment near the end of
# this file where 08-02 inserts them. This plan never exits 2.
#
# CLI contract:
#   check-plan-review.sh [--file <path>]
#   Reads no stdin (deliberate divergence from the reference PreToolUse
#   hook, which consumes tool-call JSON on stdin — this is a plain script
#   invoked from ritual text, and reading stdin would hang under
#   `codex exec`). --file is optional; when supplied it names the file
#   about to be edited (consumed by plan 08-02's bypass list; ignored here).
#   Exit 0 = ALLOW. Exit 2 = BLOCK (08-02 only). No other exit code is
#   meaningful — every terminal path is a deliberate exit 0 or exit 2.
#
# Debug surface: GSD_PLAN_REVIEW_DEBUG=1 prints `repo-root: <dir>` and
# `resolved-phase: <dir>` to stderr and never changes the exit code.
#
# Reference (read-only, OUTSIDE this repo, ported with named corrections,
# never verbatim):
#   ../claude-workflow/templates/.claude/hooks/multi-ai-review-gate.sh
#   D-06: its step 2 greps a heading ('## Current Phase') no real STATE.md
#         uses; this port matches '## Current Position' and tolerates
#         '## Current Phase' as a fallback.
#   D-07: its gsd-tools.cjs node step has no Codex analogue; omitted, so
#         this resolver is 4 steps, not 5.
#   Third defect: its line regex cannot match the canonical 'Phase: NN'
#         line (the colon blocks `[[:space:]]+`); this port anchors on the
#         canonical line and tolerates an optional colon.
#
# set -uo pipefail (not the reference's bare set -e): a gate verifier that
# dies mid-resolution on an unguarded read is a silent bypass (T-08-05),
# neither a clean allow nor a block. Every terminal path below is an
# explicit exit 0 or exit 2, and every environment/positional read uses the
# ${VAR:-} default-expansion discipline.
set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing — never abort on an unrecognized or missing argument.
# ─────────────────────────────────────────────────────────────────────────────

CPR_FILE=""
if [ "${1:-}" = "--file" ]; then
  CPR_FILE="${2:-}"
fi
# CPR_FILE is unused in this plan; plan 08-02 consumes it for the bypass list.

_debug() {
  [ "${GSD_PLAN_REVIEW_DEBUG:-}" = "1" ] && echo "$1" >&2
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Portable helpers — pinned idioms (do not improvise these).
# ─────────────────────────────────────────────────────────────────────────────

# Portable directory canonicalization. `realpath -m` is absent on stock
# macOS; `readlink -f` differs between BSD and GNU. This subshell cd + pwd -P
# idiom resolves symlinks and `..` traversal and prints nothing on a
# non-existent or unreadable path, everywhere.
_canon_dir() { ( cd "${1:-}" 2>/dev/null && pwd -P ); }

# Separator-aware containment test: cand must equal root, or be root plus a
# path separator plus more — so ".planning/phases-evil" cannot pass as a
# child of ".planning/phases" (T-08-01).
_is_contained() {
  local cand="${1:-}" root="${2:-}"
  [ -n "$cand" ] && [ -n "$root" ] || return 1
  [ "$cand" = "$root" ] && return 0
  case "${cand}/" in
    "${root}/"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Portable mtime: GNU `stat -c %Y`, BSD/macOS `stat -f %m` — neither flag
# exists on the other. Prints an integer epoch or nothing; callers MUST
# treat empty as "unknown" and skip the candidate rather than comparing an
# empty string numerically.
_mtime() {
  stat -c %Y "${1:-}" 2>/dev/null || stat -f %m "${1:-}" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Repo-root self-location (<root_location>; T-08-28).
#
# The verifier locates its own repo root rather than assuming the caller's
# cwd is the root — an agent invoking this from a nested subdirectory (e.g.
# `src/`) must reach the same verdict as an invocation from the root. An
# earlier draft assumed cwd == root, which cross-AI review (Codex, HIGH)
# identified as a silent fail-open: the gate would authorize exactly the
# edit it exists to block.
# ─────────────────────────────────────────────────────────────────────────────

REPO_ROOT=""
_cpr_git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "${_cpr_git_root:-}" ]; then
  REPO_ROOT="$_cpr_git_root"
else
  _cpr_walk="$(pwd -P 2>/dev/null || true)"
  while [ -n "${_cpr_walk:-}" ]; do
    if [ -d "${_cpr_walk}/.planning" ]; then
      REPO_ROOT="$_cpr_walk"
      break
    fi
    [ "$_cpr_walk" = "/" ] && break
    _cpr_walk="$(dirname "$_cpr_walk")"
  done
fi

if [ -z "${REPO_ROOT:-}" ]; then
  _debug "repo-root: <unresolved> (not a git tree, no .planning ancestor)"
  # No planning tree to enforce against — fail open.
  exit 0
fi

cd "$REPO_ROOT" 2>/dev/null || exit 0
_debug "repo-root: $REPO_ROOT"

# ─────────────────────────────────────────────────────────────────────────────
# _match_phase_dir <num> — tri-state status contract (resolver_defects item 6).
#
#   0 = unique    -> echoes the dir, caller uses it
#   1 = absent    -> echoes nothing, caller CONTINUES to the next step
#   2 = ambiguous -> echoes nothing, caller STOPS (terminal fail-open)
#
# The status is the contract; callers must branch on it, never on whether
# stdout was empty (absent and ambiguous both echo nothing).
# ─────────────────────────────────────────────────────────────────────────────

_match_phase_dir() {
  local num="${1:-}" d dirs count int_part padded

  # Constrain to [0-9]+(\.[0-9]+)? — never eval, never interpolate an
  # unvalidated value into a glob or command string (T-08-02).
  if ! [[ "$num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    return 1
  fi

  dirs=()
  while IFS= read -r -d '' d; do
    dirs+=("$d")
  done < <(find .planning/phases -maxdepth 1 -type d -name "${num}-*" -print0 2>/dev/null)

  if [ "${#dirs[@]}" -eq 0 ]; then
    # Zero-pad the integer part only, not the whole string (resolver_defects
    # item 5): "8.1" -> "08.1", "8" -> "08", "12.3" untouched (already 2
    # digits), "08.1" untouched (already padded).
    int_part="${num%%.*}"
    if [ "${#int_part}" -eq 1 ]; then
      padded="0${num}"
      while IFS= read -r -d '' d; do
        dirs+=("$d")
      done < <(find .planning/phases -maxdepth 1 -type d -name "${padded}-*" -print0 2>/dev/null)
    fi
  fi

  count="${#dirs[@]}"
  if [ "$count" -eq 0 ]; then
    return 1
  elif [ "$count" -eq 1 ]; then
    echo "${dirs[0]}"
    return 0
  else
    # Ambiguous — print unconditionally (not gated on GSD_PLAN_REVIEW_DEBUG),
    # since a fail-open the operator cannot see is the ADR-0018 drift
    # pattern this diagnostic exists to avoid (T-08-01).
    {
      echo "check-plan-review: ambiguous phase '${num}' matches ${count} directories (fail-open, resolution stops):"
      printf '  %s\n' "${dirs[@]}"
    } >&2
    return 2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# resolve_phase — the D-05 four-step order (explicit pointer -> workflow
# state -> newest plan -> fail-open). D-07: no gsd-tools.cjs step; there is
# no bin/ under ~/.codex/get-shit-done/.
# ─────────────────────────────────────────────────────────────────────────────

resolve_phase() {
  local p pdir canon_p canon_root cp d status
  local best best_mtime cand cand_mtime

  # 1. Explicit pointer, absolute or .planning/-relative, containment-checked
  #    against .planning/phases (T-08-01). Reject and fall through on any
  #    escape rather than exiting non-zero.
  p="$(readlink .planning/current-phase 2>/dev/null || true)"
  if [ -n "${p:-}" ]; then
    pdir=""
    if [ -d "$p" ]; then
      pdir="$p"
    elif [ -d ".planning/$p" ]; then
      pdir=".planning/$p"
    fi
    if [ -n "$pdir" ]; then
      canon_p="$(_canon_dir "$pdir")"
      canon_root="$(_canon_dir ".planning/phases")"
      if _is_contained "$canon_p" "$canon_root"; then
        echo "$pdir"
        return 0
      fi
    fi
  fi

  # 2. Workflow state (.planning/STATE.md). Section-bounded (resolver_defects
  #    item 4): the flag clears on the next '##' heading so a later section's
  #    'Phase:' line cannot win. Anchored on the canonical 'Phase:' line, not
  #    free prose (third resolver defect / regression guard). Tolerates
  #    '## Current Phase' as a fallback heading (D-06).
  if [ -f .planning/STATE.md ]; then
    cp="$(awk '
      /^##[[:space:]]+Current Position/ { in_section=1; next }
      /^##[[:space:]]+Current Phase/    { in_section=1; next }
      /^##/                              { in_section=0 }
      in_section && match($0, /^[Pp]hase:?[[:space:]]*[0-9]+(\.[0-9]+)?/) {
        s = substr($0, RSTART, RLENGTH)
        match(s, /[0-9]+(\.[0-9]+)?/)
        print substr(s, RSTART, RLENGTH)
        exit
      }
    ' .planning/STATE.md 2>/dev/null || true)"
    if [ -n "${cp:-}" ]; then
      d="$(_match_phase_dir "$cp")"; status=$?
      case "$status" in
        0) echo "$d"; return 0 ;;
        2) return 1 ;;  # ambiguous -- TERMINAL. No later step runs (item 6).
        *) : ;;         # absent (status 1) -- continue to step 3.
      esac
    fi
  fi

  # 3. Newest *-PLAN.md by mtime — portable, NUL-safe, deterministic
  #    (resolver_defects item 7). NOT the reference's
  #    `find -print0 | xargs -0 ls -t | head -1` (ls -t discards NUL-safety,
  #    BSD/GNU xargs disagree on empty input, ls -t tie order is
  #    unspecified). The loop runs via process substitution, not a pipe, so
  #    it stays in the current shell and `best` survives the loop.
  best=""; best_mtime=""
  while IFS= read -r -d '' cand; do
    cand_mtime="$(_mtime "$cand")"
    [ -z "${cand_mtime:-}" ] && continue
    if [ -z "$best" ]; then
      best="$cand"; best_mtime="$cand_mtime"
    elif [ "$cand_mtime" -gt "$best_mtime" ]; then
      best="$cand"; best_mtime="$cand_mtime"
    elif [ "$cand_mtime" -eq "$best_mtime" ] && [[ "$cand" < "$best" ]]; then
      best="$cand"; best_mtime="$cand_mtime"
    fi
  done < <(find .planning/phases -maxdepth 2 -name '*-PLAN.md' -print0 2>/dev/null)

  if [ -n "$best" ]; then
    dirname "$best"
    return 0
  fi

  # 4. Nothing resolved.
  return 1
}

CURRENT_PHASE="$(resolve_phase)"
if [ -n "${CURRENT_PHASE:-}" ] && [ -d "$CURRENT_PHASE" ]; then
  _debug "resolved-phase: $CURRENT_PHASE"
else
  # No active phase resolved -- allow (workflow not in active phase
  # execution, or resolution was terminally ambiguous).
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Grandfather guards (D-08/D-09) — each a named, commented rule, not an
# emergent glob property.
# ─────────────────────────────────────────────────────────────────────────────

# Legacy bare-number layout (D-08): phases/<NN>/PLAN.md. Not redundant with
# step 3 above — the *-PLAN.md glob cannot match a bare PLAN.md, so a legacy
# phase never resolves THROUGH step 3, but steps 1-2 can resolve one via the
# pointer or STATE.md. This explicit check makes legacy grandfathering a
# stated rule rather than an accident of a glob (D-09).
if [ -f "$CURRENT_PHASE/PLAN.md" ]; then
  _cpr_dated_plan="$(find "$CURRENT_PHASE" -maxdepth 2 -name '*-PLAN.md' 2>/dev/null | head -1)"
  if [ -z "$_cpr_dated_plan" ]; then
    exit 0
  fi
fi

# No *-PLAN.md at all -- planning has not happened yet -- allow.
PLANS="$(find "$CURRENT_PHASE" -maxdepth 2 -name '*-PLAN.md' 2>/dev/null | head -1)"
if [ -z "$PLANS" ]; then
  exit 0
fi

# *-SUMMARY.md present -- phase already executed. Enforcement is go-forward
# only; blocking it would retroactively brick shipped repos (core ADR-0025).
SUMMARY="$(find "$CURRENT_PHASE" -maxdepth 2 -name '*-SUMMARY.md' 2>/dev/null | head -1)"
if [ -n "$SUMMARY" ]; then
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# END OF PLAN 08-01's SCOPE.
#
# Plan 08-02 inserts here: the *-REVIEWS.md check (frontmatter reviewers:
# count, or the >=5-line fallback), the GSD_SKIP_REVIEWS=1 and
# multi-ai-review-skipped escape hatches, and the exit-2 block message.
# This plan has no cases for any of that and never exits 2.
# ─────────────────────────────────────────────────────────────────────────────

exit 0
