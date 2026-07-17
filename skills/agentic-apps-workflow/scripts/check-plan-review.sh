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

# ─────────────────────────────────────────────────────────────────────────────
# Escape hatch 1 (D-11): GSD_SKIP_REVIEWS=1. Checked before ANY filesystem
# work -- before even repo-root self-location -- per <ordering> step 1
# (plan 08-02). Only the literal "1" disarms the gate: "0" and empty are NOT
# hatches (T-08-07 -- a silent bypass on a stray falsy value would defeat the
# whole gate). This hatch announces itself on stderr, unlike the reference
# (its line 46), which exits 0 silently -- a silent authorization bypass is
# exactly the threat T-08-07 names.
# ─────────────────────────────────────────────────────────────────────────────
if [ "${GSD_SKIP_REVIEWS:-}" = "1" ]; then
  echo "plan-review gate: SKIPPED via GSD_SKIP_REVIEWS=1 (emergency override)" >&2
  exit 0
fi

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
#
# WR-03 (D-04): hoisted above the --file bypass block below (which used to
# run first, before $REPO_ROOT existed). The GSD_SKIP_REVIEWS hatch above
# stays the first executable gate; only the --file bypass moved below this,
# so it can canonicalize-and-contain against $REPO_ROOT/.planning.
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
# --file bypass list (T-08-08, T-08-37; <ordering> step 2) -- fires ONLY when
# --file was supplied. WR-03 (D-04): this block now runs AFTER repo-root
# self-location above, so $REPO_ROOT is available for the parent-dir
# containment gate added below.
#
# Traversal rejected FIRST, before the prefix test (bypass 2 in <ordering>;
# T-08-37): '.planning/../docs/IMPLEMENTATION-PLAN.md' satisfies BOTH the
# '.planning/' prefix and the 'PLAN.md' basename textually, and resolves to
# the exact file the FLAG-A fix below exists to exclude. Reject on the '..'
# component itself -- do NOT normalize-then-test: _canon_dir cd's and
# therefore requires the path to exist, and --file may name a file about to
# be created. A rejected --file is NOT a block by itself; the bypass simply
# does not fire and the gate falls through to normal resolution -- the
# phase's real state then decides. This lexical '..' check stays as a
# defensive floor (D-01) even with the WR-03 containment gate below: it
# still fires when the parent dir does not exist, where _canon_dir returns
# empty and cannot help.
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "$CPR_FILE" ]; then
  _cpr_has_dotdot=0
  IFS='/' read -ra _cpr_file_parts <<< "$CPR_FILE"
  for _cpr_file_part in "${_cpr_file_parts[@]}"; do
    if [ "$_cpr_file_part" = ".." ]; then
      _cpr_has_dotdot=1
      break
    fi
  done

  if [ "$_cpr_has_dotdot" -eq 0 ]; then
    # Ported from the reference's FLAG-A fix (its lines 51-60): gate on the
    # path PREFIX (.planning/*, */.planning/*) AND the basename, never the
    # basename alone. A basename-only check matched docs/IMPLEMENTATION-PLAN.md
    # and any repo file ending in a canonical basename, defeating the gate by
    # filename trivially (T-08-08).
    case "$CPR_FILE" in
      .planning/*|*/.planning/*)
        # NOTE: *REVIEW[S].md (not *REVIEWS.md) is deliberate, not a typo --
        # the bracket expression matches identically to *REVIEWS.md but
        # avoids spelling the contiguous substring "REVIEWS.md" this early
        # in the file. This plan's own acceptance criteria assert a source-
        # order regression guard (multi-ai-review-skipped must precede the
        # REVIEWS.md evidence-check block later in this file); an early,
        # unrelated "REVIEWS.md" occurrence here would falsely satisfy that
        # grep-based check. Do not "simplify" this back to *REVIEWS.md.
        case "$(basename "$CPR_FILE")" in
          *PLAN.md|*PLAN-*.md|*REVIEW[S].md|ROADMAP.md|PROJECT.md|REQUIREMENTS.md|*CONTEXT.md|*RESEARCH.md)
            # WR-03 (D-02/D-03/D-05): canonicalize the --file value's
            # PARENT directory (not the leaf -- _canon_dir cd's and
            # requires the path to exist, and --file may legitimately name
            # a file about to be created) and require it resolve INSIDE
            # $REPO_ROOT/.planning -- this repo's tree only. Reuses the
            # same _canon_dir/_is_contained helpers the current-phase
            # resolver below already uses (SC#1: reuse, not reinvent).
            #
            # Resolve-then-contain (D-03), not reject-any-symlink: a
            # symlinked parent that resolves INSIDE the tree is accepted;
            # only one that escapes is rejected. Do not copy the
            # REVIEWS.md evidence guard's reject-any-symlink rule below --
            # that asymmetry is deliberate for evidence artifacts, wrong
            # for a --file edit target, which may legitimately sit behind
            # a symlinked parent (e.g. a worktree symlink).
            #
            # D-05 tightens the old lexical '*/.planning/*' arm:
            # containment is against THIS repo's $REPO_ROOT/.planning
            # only, so a vendored 'vendor/foo/.planning/X-PLAN.md' that
            # used to satisfy the lexical prefix test alone no longer
            # bypasses -- disclosed behavior change, not a silent
            # regression (see phase SUMMARY / ADR-0009 decision 12).
            #
            # D-02: when _canon_dir returns empty (parent does not exist /
            # cannot be canonicalized), this gate simply does not pass --
            # the bypass FALLS THROUGH to normal resolution below, exactly
            # like the '..' check above. Never exit 2 here, never
            # bypass-approve on an unresolvable parent -- failing open is
            # the milestone's nemesis (T-12-02).
            _cpr_file_parent="$(dirname "$CPR_FILE")"
            _cpr_canon_parent="$(_canon_dir "$_cpr_file_parent")"
            _cpr_canon_planning_root="$(_canon_dir "$REPO_ROOT/.planning")"
            if [ -n "$_cpr_canon_parent" ] && _is_contained "$_cpr_canon_parent" "$_cpr_canon_planning_root"; then
              exit 0
            fi
            ;;
        esac
        ;;
    esac
  fi
fi

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

CURRENT_PHASE=$(
  resolve_phase
)
if [ -n "${CURRENT_PHASE:-}" ] && [ -d "$CURRENT_PHASE" ]; then
  _debug "resolved-phase: $CURRENT_PHASE"
else
  # No active phase resolved -- allow (workflow not in active phase
  # execution, or resolution was terminally ambiguous).
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Escape hatch 2 (D-11): multi-ai-review-skipped marker, checked ONLY at the
# resolved phase dir -- the path plan 08-01's containment check already
# validated (<ordering> step 4; T-08-29).
#
# Deliberately does NOT also check the raw '.planning/current-phase/...'
# path, unlike the reference (its line 130): that raw path follows the very
# symlink containment rejects, so an attacker-controlled pointer escaping
# .planning/phases/ could carry a marker that authorizes the edit even
# though the pointer itself was rejected. When the pointer IS legitimate,
# '.planning/current-phase/multi-ai-review-skipped' and
# '<resolved>/multi-ai-review-skipped' are the same file, so no legitimate
# hatch is lost by dropping the raw check. Do not "restore" it when porting
# from the reference.
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "$CURRENT_PHASE/multi-ai-review-skipped" ]; then
  echo "plan-review gate: SKIPPED via $CURRENT_PHASE/multi-ai-review-skipped (emergency override)" >&2
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
# REVIEWS.md evidence check (D-10, D-12, D-13) — plan 08-02.
#
# Block message shape (D-10; 08-CONTEXT.md "Specific Ideas"): state what is
# missing, give the exact remedy, then name both overrides as emergency-only.
# Never auto-invoke a reviewer from this script (D-10): doing so would ship
# plan content to third-party vendors without consent. The verifier detects
# and reports; the operator decides.
# ─────────────────────────────────────────────────────────────────────────────

_cpr_block() {
  local reason="${1:-}"
  {
    echo "❌ plan-review gate: BLOCKED (exit 2)"
    echo ""
    echo "   Phase:     $CURRENT_PHASE"
    [ -n "$CPR_FILE" ] && echo "   File:      $CPR_FILE"
    echo "   Missing:   $CURRENT_PHASE/<NN>-REVIEWS.md"
    echo ""
    echo "   Reason: $reason"
    echo ""
    echo "   Remedy: invoke the codex-plan-review skill to produce a"
    echo "   multi-AI plan review artifact, then continue."
    echo ""
    echo "   Overrides (emergency only):"
    echo "     GSD_SKIP_REVIEWS=1"
    echo "     touch $CURRENT_PHASE/multi-ai-review-skipped"
  } >&2
  exit 2
}

# Collect *-REVIEWS.md at -maxdepth 2 under the resolved phase into a
# counted list -- do NOT `head -1` (<ordering> step 6; T-08-30): a nested or
# stale artifact must not silently win over the canonical one by directory-
# walk order.
_cpr_reviews_list=()
while IFS= read -r -d '' _cpr_r; do
  _cpr_reviews_list+=("$_cpr_r")
done < <(find "$CURRENT_PHASE" -maxdepth 2 -name '*-REVIEWS.md' -print0 2>/dev/null)
_cpr_reviews_count="${#_cpr_reviews_list[@]}"

if [ "$_cpr_reviews_count" -eq 0 ]; then
  _cpr_block "the phase has *-PLAN.md files but no multi-AI plan review (*-REVIEWS.md not found)"
fi

if [ "$_cpr_reviews_count" -gt 1 ]; then
  {
    echo "❌ plan-review gate: BLOCKED (exit 2) — ambiguous review evidence"
    echo ""
    echo "   Phase: $CURRENT_PHASE"
    echo "   Found ${_cpr_reviews_count} *-REVIEWS.md files (expected exactly 1):"
    printf '     %s\n' "${_cpr_reviews_list[@]}"
    echo ""
    echo "   Remedy: invoke the codex-plan-review skill to produce a single"
    echo "   canonical review artifact; remove or consolidate the extras."
    echo ""
    echo "   Overrides (emergency only): GSD_SKIP_REVIEWS=1 or touch"
    echo "   $CURRENT_PHASE/multi-ai-review-skipped"
  } >&2
  exit 2
fi

REVIEWS="${_cpr_reviews_list[0]}"

# Symlink guard FIRST (<ordering> step 7a; T-08-36) -- [ -L ] is the only
# test that does NOT dereference. [ -f ] is a dereferencing test: false for
# a FIFO, socket, directory, and dangling symlink, but TRUE for a LIVE
# symlink pointing at any regular file anywhere. Testing -f first would
# therefore admit a live `08-REVIEWS.md -> /etc/hosts` as a frontmatter-less
# regular file that clears the >=5-line fallback below -- a trivial bypass
# with a file the operator never wrote. Reject symlinks outright rather than
# canonicalizing-and-containing: an evidence artifact has no legitimate
# reason to indirect (deliberate asymmetry with plan 08-01's current-phase
# pointer, which IS legitimately a symlink and IS canonicalized-and-
# contained -- a pointer is MEANT to indirect; an evidence artifact is not).
if [ -L "$REVIEWS" ]; then
  _cpr_block "the review artifact $REVIEWS is a symlink -- symlinked evidence is treated as missing, never canonicalized-and-contained"
fi

# Regular-file guard (round 1, T-08-09) -- false for the remaining
# non-regular cases (FIFO, socket, directory) after the symlink guard above.
# The reference exits 0 here (its line 162, a trivial gate bypass per
# review); this port fails closed: a non-regular artifact is not evidence of
# a review, it is an accident or an attack, so treat it as missing rather
# than risk `wc -l` hanging on a FIFO.
if [ ! -f "$REVIEWS" ]; then
  _cpr_block "the review artifact $REVIEWS is not a regular file -- treated as missing"
fi

# ─────────────────────────────────────────────────────────────────────────────
# _cpr_fm_list <frontmatter-block-text> <key> — extract a YAML key's values,
# accepting BOTH styles: a one-line flow sequence (`key: [a, b]`) and an
# indented block sequence (`key:` followed by `  - a` lines until the next
# unindented key). Takes no YAML dependency (D-13's own requirement). Bounded
# to the frontmatter block text passed in -- a `key:` mention in the body
# must never be read as a list (parse is bounded to the block between the
# first two '---' lines, never the whole file).
# ─────────────────────────────────────────────────────────────────────────────
_cpr_fm_list() {
  local text="$1" key="$2"
  printf '%s\n' "$text" | awk -v key="$key" '
    {
      line = $0
      if (match(line, "^" key ":[[:space:]]*\\[")) {
        s = line
        sub("^" key ":[[:space:]]*\\[", "", s)
        sub("\\].*$", "", s)
        n = split(s, arr, ",")
        for (i = 1; i <= n; i++) {
          v = arr[i]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
          if (v != "") print v
        }
        in_key = 0
        next
      }
      if (match(line, "^" key ":[[:space:]]*$")) {
        in_key = 1
        next
      }
      if (in_key == 1) {
        if (match(line, "^[[:space:]]*-[[:space:]]*")) {
          v = line
          sub("^[[:space:]]*-[[:space:]]*", "", v)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
          if (v != "") print v
          next
        } else {
          in_key = 0
        }
      }
    }
  '
}

# ─────────────────────────────────────────────────────────────────────────────
# Frontmatter detection and malformed handling (D-13). Look for an opening
# '---' on line 1. If present but there is no closing '---', the artifact is
# MALFORMED -- exit 2 distinctly, do NOT fall through to the >=5-line path
# (an unterminated block is a broken artifact, not a hand-written one;
# conflating them lets a truncated file take the looser path).
# ─────────────────────────────────────────────────────────────────────────────
_cpr_fm_first_line="$(head -n 1 "$REVIEWS" 2>/dev/null | tr -d '\r' | sed -e 's/[[:space:]]*$//' || true)"

if [ "${_cpr_fm_first_line:-}" = "---" ]; then
  # CR-01 fix: mirror the SAME normalization (strip CR + trailing whitespace)
  # onto the closing-delimiter search that was just applied to the opening
  # one above. Without this, a well-formed frontmatter whose opening '---'
  # is now tolerantly matched could still miss its own closing '---' on a
  # CRLF file and be misreported MALFORMED instead of parsed strictly --
  # "open and close agree" is the whole point of the tolerance.
  _cpr_fm_close_line="$(awk '
    NR > 1 {
      line = $0
      gsub(/\r/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      if (line == "---") { print NR; exit }
    }
  ' "$REVIEWS")"
  if [ -z "${_cpr_fm_close_line:-}" ]; then
    _cpr_block "the review artifact has an opening frontmatter '---' with no closing '---' -- MALFORMED frontmatter, distinct from a missing review (D-13)"
  fi

  # tr -d '\r' makes downstream parsing encoding-independent rather than
  # relying on awk's [[:space:]] class including CR (verified true on BSD
  # awk 20200816 during planning, but this must not depend on that).
  _cpr_fm_block="$(awk -v endline="$_cpr_fm_close_line" 'NR > 1 && NR < endline' "$REVIEWS" | tr -d '\r')"

  # Count DISTINCT reviewers. Normalize each entry (strip surrounding
  # whitespace and quotes, lowercase) before counting unique values --
  # [gemini, gemini] is one reviewer, not two (08-REVIEWS.md, Codex, MEDIUM).
  _cpr_reviewers_norm="$(
    _cpr_fm_list "$_cpr_fm_block" "reviewers" \
      | sed -e "s/^['\"]//" -e "s/['\"]\$//" \
      | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print tolower($0)}' \
      | sed '/^$/d' \
      | sort -u
  )"

  # WR-01 / D-15 fix: exclude codex-derived identities (codex, codex-self,
  # codex_foo, "codex bar", ...) from the count BEFORE the -lt 2 test --
  # codex is the implementing host and self-review does not count. This is
  # an EXCLUSION, not a strict vendor allowlist: a hard-coded allowlist
  # (only claude/gemini/opencode count) would silently false-block a
  # legitimate future vendor, or a cross-host REVIEWS.md naming a reviewer
  # this host has not heard of (ADR-0007 point 5) -- exactly what D-13
  # already warns against for the fallback. It also buys nothing against a
  # determined spoofer: anyone willing to write `reviewers: [alice, bob]`
  # to defeat the gate could instead `touch multi-ai-review-skipped`, which
  # ADR-0009 decisions 10/11 already accept as openly available. Identity
  # validation therefore only protects against the HONEST mistake, and the
  # honest mistake D-15 actually names is counting codex, the implementing
  # host, as an external reviewer -- exclusion closes exactly that and
  # nothing more, which is the correct scope.
  _cpr_reviewers_excluded="$(printf '%s\n' "$_cpr_reviewers_norm" | grep -E '^codex([-_ ].*)?$' || true)"
  _cpr_reviewers_external="$(printf '%s\n' "$_cpr_reviewers_norm" | grep -vE '^codex([-_ ].*)?$' || true)"

  _cpr_reviewers_distinct="$(printf '%s\n' "$_cpr_reviewers_external" | sed '/^$/d' | wc -l | tr -d ' ')"
  _cpr_reviewers_excluded_count="$(printf '%s\n' "$_cpr_reviewers_excluded" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [ "$_cpr_reviewers_distinct" -lt 2 ]; then
    if [ "$_cpr_reviewers_excluded_count" -gt 0 ]; then
      _cpr_block "found ${_cpr_reviewers_distinct} distinct EXTERNAL reviewer(s) in frontmatter 'reviewers:' (need >= 2); ${_cpr_reviewers_excluded_count} entry(ies) naming codex were excluded because codex is the implementing host and self-review does not count (D-15) -- add vendor-diverse reviewers such as claude, gemini, or opencode"
    else
      _cpr_block "found ${_cpr_reviewers_distinct} distinct reviewer(s) in frontmatter 'reviewers:' (need >= 2, counted after case/whitespace normalization)"
    fi
  fi

  # plans_reviewed coverage -- the cheap half of freshness (D-12). Require
  # every current *-PLAN.md basename under the resolved phase to appear in
  # it. A gap -> exit 2 naming the plans that were not reviewed. A superset
  # (a listed plan that no longer exists) is fine. Do NOT add a content
  # digest or any hashing scheme here -- that is the expensive half of
  # freshness and is explicitly deferred (08-CONTEXT.md "Deferred Ideas").
  #
  # NOTE on this check's real reach (08-REVIEWS.md round 2, OpenCode,
  # MEDIUM): the grandfather guard above fires on ANY *-SUMMARY.md, and this
  # fleet writes one SUMMARY per plan -- so the moment a phase's first plan
  # ships, the verifier exits 0 at the grandfather guard and never reaches
  # this check at all. This check is therefore the cheap half of freshness
  # for UN-shipped phases only; it is structurally unenforceable once any
  # SUMMARY exists. That is not a defect to fix here (D-08's grandfather
  # behavior is carried faithfully from the reference); it is reported
  # upstream (ADR-0009 decision 8b), not diverged on unilaterally.
  _cpr_plans_reviewed_raw="$(_cpr_fm_list "$_cpr_fm_block" "plans_reviewed")"
  if [ -z "$_cpr_plans_reviewed_raw" ]; then
    _cpr_block "frontmatter is missing the required 'plans_reviewed:' key (D-12 schema)"
  fi

  _cpr_missing_plans=""
  while IFS= read -r -d '' _cpr_plan_file; do
    _cpr_plan_base="$(basename "$_cpr_plan_file")"
    if ! printf '%s\n' "$_cpr_plans_reviewed_raw" | grep -qxF "$_cpr_plan_base"; then
      _cpr_missing_plans="${_cpr_missing_plans}${_cpr_plan_base} "
    fi
  done < <(find "$CURRENT_PHASE" -maxdepth 2 -name '*-PLAN.md' -print0 2>/dev/null)

  if [ -n "$_cpr_missing_plans" ]; then
    _cpr_block "plans_reviewed does not cover: ${_cpr_missing_plans}-- the review predates these plans"
  fi

  # Frontmatter present and every check passed -- allow.
  exit 0
else
  # ───────────────────────────────────────────────────────────────────────────
  # Fallback (D-13, ONLY when frontmatter is absent entirely): the >=5-line
  # non-emptiness check. This is the single deliberate behavioral divergence
  # from the reference, which warns and exits 0 here (its lines 166-172):
  # D-13 requires exit 2 below the threshold. This path is a known, locked
  # weakening -- review called it easy to spoof (08-REVIEWS.md, Codex,
  # MEDIUM), D-13 keeps it for hand-written-file compatibility, and
  # ADR-0009 records the accepted limitation. When frontmatter IS present it
  # is authoritative and this fallback never runs -- body length must not
  # rescue a short reviewer list (D-14).
  # ───────────────────────────────────────────────────────────────────────────
  _cpr_line_count="$(wc -l < "$REVIEWS" 2>/dev/null | tr -d ' ')"
  _cpr_line_count="${_cpr_line_count:-0}"
  if [ "$_cpr_line_count" -lt 5 ]; then
    _cpr_block "the review artifact has no frontmatter and fewer than 5 lines (D-13 fallback; the reference warns and allows here, this host blocks)"
  fi
  exit 0
fi
