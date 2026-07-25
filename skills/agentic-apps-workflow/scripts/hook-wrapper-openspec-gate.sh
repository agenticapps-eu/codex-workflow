#!/usr/bin/env bash
# hook-wrapper-openspec-gate.sh — codex-cli native PreToolUse adapter for the
# host-agnostic OpenSpec change-gate (core spec §18).
#
# This is the codex sibling of hook-wrapper-plan-review.sh, retargeted from the
# 0.x phase/PLAN.md gate to the 1.0.0 OpenSpec change-gate. It is a THIN
# ADAPTER: all verdict logic lives in openspec-change-gate.sh (validate-green
# AND REVIEWS.md >= 2 reviewers) and must never be re-implemented here.
#
# ─────────────────────────────────────────────────────────────────────────────
# Why an adapter is REQUIRED on codex (do not "simplify" this away)
# ─────────────────────────────────────────────────────────────────────────────
# Two codex-cli facts make a direct `.codex/hooks.json` -> gate wiring unsafe:
#
# 1. PAYLOAD SHAPE. The gate extracts the edited path from `tool_input.file_path`
#    / `.path` / `.file`. codex's `apply_patch` carries NO such field — the
#    target path lives inside the patch blob at `tool_input.command`, as
#    `*** Add File: <path>` / `*** Update File: <path>` header lines
#    (13-01-SPIKE-FINDINGS.md STEP 7, verbatim from a live payload). Handed the
#    raw codex payload, the gate parses no path and FAILS OPEN by design (§18
#    fail-open-on-parse-error) — i.e. it would allow every edit, silently. This
#    wrapper translates the codex shape into the shape the gate parses.
#
# 2. STDOUT CONTRACT. A codex-cli PreToolUse hook emitting invalid/partial
#    stdout FAILS OPEN — codex reports "PreToolUse hook (failed)" and RUNS THE
#    TOOL ANYWAY (13-01-SPIKE-FINDINGS.md STEP 3 side-finding). So a block is
#    expressed as strictly valid `permissionDecision: deny` JSON built with jq
#    (never hand-escaped), exit 0; the bare `exit 2` path is the reason-less
#    fallback only. Every terminal path below is an explicit `exit 0` or
#    `exit 2` — no path may emit partial/malformed stdout or a third exit code.
#
# `set -uo pipefail`, never bare `set -e`: a mid-parse death here would be a
# silent bypass.
set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Read stdin ONCE. All field extraction goes through jq — never naive
# string-splitting. Malformed/unexpected JSON becomes "no derivable path",
# never a crash.
# ─────────────────────────────────────────────────────────────────────────────
PAYLOAD="$(cat)"
TOOL_NAME="$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)"

# ─────────────────────────────────────────────────────────────────────────────
# Self-evidencing invocation log (debug session codex-hook-not-firing,
# 2026-07-19). Written BEFORE any decision logic, on EVERY invocation, so
# "the native hook fired" is directly observable evidence rather than an
# inference from block text alone — the discriminator that exposed a false
# positive in phase 13, where a prompt-based self-check produced a block that
# looked identical to a native one. Best-effort: a log-write failure must never
# flip this load-bearing script's exit contract.
# ─────────────────────────────────────────────────────────────────────────────
HW_LOG="${CODEX_HOME:-$HOME/.codex}/hook-wrapper-openspec-gate.log"
printf '%s pid=%s tool_name=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$$" "${TOOL_NAME:-<empty>}" \
  >>"$HW_LOG" 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# Derive the edited path from whichever codex tool shape arrived, then hand the
# gate a payload it can parse. `sed -E` (portable ERE), NOT basic-regex
# `\(...\|...\)`: BSD/macOS sed treats `\|` in a BRE as a LITERAL pipe, so the
# GNU-only form silently matches nothing on this operator's machine (debug
# session codex-hook-not-firing, 2026-07-19).
# ─────────────────────────────────────────────────────────────────────────────
EDITED_PATH=""
case "$TOOL_NAME" in
  apply_patch)
    EDITED_PATH="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null \
                   | sed -n -E 's/^\*\*\* (Add|Update|Delete) File: //p' | head -1)"
    ;;
  *)
    # Any other file-mutating tool codex may route here already uses a plain
    # path field; let the gate's own extractor see the untouched payload.
    EDITED_PATH="$(printf '%s' "$PAYLOAD" \
                   | jq -r '(.tool_input.file_path // .tool_input.path // empty)' 2>/dev/null | head -1)"
    ;;
esac

# No derivable path => hand the payload through untouched and let the gate make
# its own §18 fail-open decision. We do not invent a verdict here.
if [ -n "$EDITED_PATH" ]; then
  GATE_STDIN="$(jq -n --arg p "$EDITED_PATH" --arg t "${TOOL_NAME:-apply_patch}" \
                  '{tool:$t, tool_input:{file_path:$p}}')"
else
  GATE_STDIN="$PAYLOAD"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Exec the unchanged gate, capturing its stderr (the reason text) and exit
# code. RC is {0,2} by the §18 truth table; no other value is meaningful.
# Resolution order matches the pre-commit floor: env override, the global
# install, then a repo-local checkout.
# ─────────────────────────────────────────────────────────────────────────────
# This host's identity, so codex's own reviews do not satisfy the >= 2
# independent reviewer threshold. Set here rather than inherited — a gate that
# counts self-review disagrees with the §02 evidence verifier, and a verifier
# and a gate that disagree is the ADR-0018 drift pattern reappearing inside the
# tooling.
export OPENSPEC_GATE_SELF="${OPENSPEC_GATE_SELF:-codex}"

# The shared gate is trusted only if it carries a well-formed `# gate-version:`
# marker — exactly three dot-separated integers, the shape install.sh
# arbitrates on. All four host installers write that one path and only this host
# arbitrates so far, so a sibling can blind-write its unmarked pre-canonical
# copy over ours; without this check, shared-first resolution would run this
# hook against the very gate the workflow replaced. It does NOT distinguish
# newer from older — a marked-but-older sibling copy is still trusted — but it
# closes the case that exists today. Same rule as bin/git-hooks/pre-commit; the
# two must not drift apart.
has_valid_marker() {
  local v dots
  v="$(grep -m1 '^# gate-version:' "$1" 2>/dev/null | sed 's/^# gate-version:[[:space:]]*//' | tr -d '[:space:]')"
  case "$v" in
    ''|*[!0-9.]*) return 1 ;;
  esac
  dots="$(printf '%s' "$v" | tr -cd '.' | wc -c | tr -d ' ')"
  [ "$dots" = "2" ] || return 1
  case "$v" in .*|*.|*..*) return 1 ;; esac
  return 0
}

GATE=""
if [ -n "${OPENSPEC_CHANGE_GATE:-}" ] && [ -x "${OPENSPEC_CHANGE_GATE:-}" ]; then
  # An explicit override is the operator's deliberate choice, used as-is.
  GATE="$OPENSPEC_CHANGE_GATE"
fi
if [ -z "$GATE" ]; then
  _shared="$HOME/.agenticapps/bin/openspec-change-gate.sh"
  if [ -x "$_shared" ] && has_valid_marker "$_shared"; then
    GATE="$_shared"
  elif [ -x "$_shared" ]; then
    printf '%s shared-gate-unmarked ignored=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$_shared" >>"$HW_LOG" 2>/dev/null || true
  fi
fi
if [ -z "$GATE" ]; then
  _local="$(git rev-parse --show-toplevel 2>/dev/null)/bin/openspec-change-gate.sh"
  [ -x "$_local" ] && GATE="$_local"
fi

if [ -z "$GATE" ]; then
  # The gate is not installed. ALLOW rather than bricking every edit on a
  # machine that never installed the workflow — the git pre-commit + CI floor is
  # the enforcement guarantee; this hook is faster feedback on top.
  #
  # The log line is MANDATORY, not best-effort housekeeping: a surface that
  # silently stops enforcing looks exactly like one that is enforcing and
  # finding nothing wrong. That ambiguity is how the fleet drift went unnoticed,
  # so the paths searched are recorded even on the allow path.
  printf '%s gate-not-installed allow searched=[$OPENSPEC_CHANGE_GATE,%s,repo-local]\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" \
    "$HOME/.agenticapps/bin/openspec-change-gate.sh" >>"$HW_LOG" 2>/dev/null || true
  exit 0
fi

OUT="$(printf '%s' "$GATE_STDIN" | OPENSPEC_GATE_SOURCE=native-hook "$GATE" 2>&1 1>/dev/null)"
RC=$?

if [ "$RC" -eq 0 ]; then
  # ALLOW — silent exit 0, no stdout (codex treats empty stdout as a no-op
  # success).
  exit 0
fi

if [ -n "$OUT" ]; then
  # BLOCK — primary path: strictly valid deny JSON on stdout, built with jq so
  # a reason containing quotes/newlines cannot produce malformed JSON and flip
  # the gate open. The block is expressed via the JSON body, not the exit code,
  # so this path always exits 0.
  jq -n --arg reason "Source:    native-hook
$OUT" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

# FALLBACK — reachable only if the gate exited non-zero with EMPTY stderr,
# which its own logging discipline is designed to make unreachable. A silent
# exit-2 block with no reason is indistinguishable from a hang or a crash, so
# this branch always writes a reason first and blocks CLOSED, not open.
# FALLBACK-STDERR-MARKER: the line below must never be silenced or removed.
echo "openspec-gate hook wrapper: BLOCKED (exit 2) — openspec-change-gate.sh exited $RC with no captured reason; blocking CLOSED, not open" >&2
exit 2
