#!/usr/bin/env bash
# openspec-change-gate.sh — host-agnostic OpenSpec change-gate (spec §18).
#
# The REAL enforcement surface for the retargeted change-gate. Every host's
# hook (Claude settings.json · Codex .codex/hooks.json · opencode plugin · pi)
# is thin wiring that pipes a tool-call payload to this script on stdin and
# acts on the exit code. It is also wired as a git pre-commit hook and a CI
# check — the agent-agnostic floor that catches edits from any agent or human
# and gates the session that installed the per-agent hook (a PreToolUse hook
# cannot gate its own installing session — §18).
#
# Contract (spec §18 exit-code truth table — normative):
#
#   Situation                                                    Decision  Exit
#   ---------------------------------------------------------    --------  ----
#   No active change (edit outside any open change)              allow      0
#   Edit targets an OpenSpec artifact (openspec/**)              allow*     0   (*exempt: author the change)
#   Active change, validate green, no REVIEWS.md (or <2)         block      2
#   Active change, validate FAILS                                block      2
#   Active change, validate green AND REVIEWS.md >=2 reviewers   allow      0
#   Escape hatch env var set (GSD_SKIP_REVIEWS=1)                allow      0   (documented override)
#   Malformed / unparseable stdin                                allow      0   (fail-open on PARSE error)
#
# Fail-open is deliberate on PARSE error only; failing open on POLICY
# (missing review) is non-conformant. Reviewers are counted as `## Reviewer:`
# headings in REVIEWS.md (pilot convention, PILOT-REPORT.md).
#
# Inputs:
#   stdin  — the host runtime's tool-call payload (JSON). This script extracts
#            the tool name and the target file path defensively across the
#            known host payload shapes (Claude PreToolUse, opencode
#            tool.execute.before, Codex apply_patch, and a plain
#            "TOOL\tPATH" test line).
#   env    — GSD_SKIP_REVIEWS=1 documented escape hatch.
#            OPENSPEC_GATE_MIN_REVIEWERS overrides the >=2 default (rarely).
#            OPENSPEC_BIN overrides the openspec CLI name/path (default: openspec).
#
# Exit: 0 = allow, 2 = block. Never exits non-zero for any other reason.

set -u

MIN_REVIEWERS="${OPENSPEC_GATE_MIN_REVIEWERS:-2}"
OPENSPEC_BIN="${OPENSPEC_BIN:-openspec}"
ALLOW=0
BLOCK=2

log() { printf 'openspec-change-gate: %s\n' "$*" >&2; }

# ── Documented escape hatch ──────────────────────────────────────────────────
if [ "${GSD_SKIP_REVIEWS:-}" = "1" ]; then
  log "ALLOW (GSD_SKIP_REVIEWS=1 override)"
  exit "$ALLOW"
fi

# ── Read + parse the payload (fail-open on parse error) ──────────────────────
payload="$(cat 2>/dev/null || true)"

# Extract the target file path from whichever host shape we got. Tolerant by
# design: any failure to parse => empty path => fail-open allow.
extract_path() {
  local p=""
  # Plain test line: "TOOL<TAB>PATH" or "TOOL PATH" (used by run-tests.sh).
  if printf '%s' "$payload" | grep -q '[[:space:]]'; then
    if ! printf '%s' "$payload" | grep -q '[{}]'; then
      p="$(printf '%s' "$payload" | awk '{ $1=""; sub(/^[[:space:]]+/,""); print; exit }')"
      [ -n "$p" ] && { printf '%s' "$p"; return; }
    fi
  fi
  # JSON shapes — try common keys with jq if available, else a grep fallback.
  if command -v jq >/dev/null 2>&1; then
    p="$(printf '%s' "$payload" | jq -r '
      (.tool_input.file_path // .tool_input.path //
       .args.filePath // .args.path // .args.file //
       .input.file_path // .input.path //
       .file_path // .path // empty)' 2>/dev/null | head -1)"
  fi
  if [ -z "$p" ] || [ "$p" = "null" ]; then
    # jq-free fallback: first "<key>": "<value>" for a path-ish key.
    p="$(printf '%s' "$payload" \
      | grep -oE '"(file_?[pP]ath|path|file)"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | head -1 | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/')"
  fi
  [ "$p" = "null" ] && p=""
  printf '%s' "$p"
}

target_path="$(extract_path)"

if [ -z "$target_path" ]; then
  # Could not identify a file path — fail-open (parse error, not policy).
  log "ALLOW (fail-open: no target path parsed from stdin)"
  exit "$ALLOW"
fi

# Normalise to a repo-relative-ish path for the openspec/** exemption test.
case "$target_path" in
  /*) rel="${target_path#"$PWD"/}" ;;
  *)  rel="$target_path" ;;
esac

# ── Exemption: writes to OpenSpec artifacts themselves ───────────────────────
# The agent must be able to author the change (proposal/design/delta/tasks) and
# its REVIEWS.md while the gate is engaged.
case "$rel" in
  openspec/*|*/openspec/*)
    log "ALLOW (exempt: OpenSpec artifact write — $rel)"
    exit "$ALLOW"
    ;;
esac

# ── Determine the active change ──────────────────────────────────────────────
# The single open change directory under openspec/changes/ (excluding archive/).
# No openspec/ or no open change => no active change => allow (out-of-change).
changes_dir="openspec/changes"
if [ ! -d "$changes_dir" ]; then
  log "ALLOW (no openspec/changes — nothing to gate)"
  exit "$ALLOW"
fi

active_change=""
for d in "$changes_dir"/*/; do
  [ -d "$d" ] || continue
  case "$d" in "$changes_dir"/archive/) continue ;; esac
  active_change="${d%/}"
  break   # first open change; hosts with parallel changes extend this (§09)
done

if [ -z "$active_change" ]; then
  log "ALLOW (no active change — out-of-change edit)"
  exit "$ALLOW"
fi

# ── Resolve validate-green AND REVIEWS.md >= MIN_REVIEWERS ───────────────────
# validate: if the openspec CLI is absent we cannot assert green -> block
# (policy, not parse): an unvalidatable change must not pass the gate.
if command -v "$OPENSPEC_BIN" >/dev/null 2>&1; then
  if "$OPENSPEC_BIN" validate --all >/dev/null 2>&1; then
    validate_ok=1
  else
    validate_ok=0
  fi
else
  log "BLOCK (openspec CLI '$OPENSPEC_BIN' not found — cannot assert validate-green)"
  exit "$BLOCK"
fi

reviews_file="$active_change/REVIEWS.md"
reviewer_count=0
if [ -f "$reviews_file" ]; then
  reviewer_count="$(grep -cE '^##[[:space:]]+Reviewer:' "$reviews_file" 2>/dev/null || echo 0)"
fi

if [ "$validate_ok" -ne 1 ]; then
  log "BLOCK (openspec validate --all failed for $(basename "$active_change"))"
  exit "$BLOCK"
fi

if [ "$reviewer_count" -lt "$MIN_REVIEWERS" ]; then
  log "BLOCK ($(basename "$active_change"): REVIEWS.md has $reviewer_count reviewer(s); need >= $MIN_REVIEWERS '## Reviewer:' headings)"
  exit "$BLOCK"
fi

log "ALLOW ($(basename "$active_change"): validate green, $reviewer_count reviewers)"
exit "$ALLOW"
