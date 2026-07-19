#!/usr/bin/env bash
# hook-wrapper-plan-review.sh — codex-cli native PreToolUse adapter for
# check-plan-review.sh (HOOK-02, phase 13-native-enforcement-plan-review-hook).
#
# Purpose: codex-cli's hooks.json `command` is a static string with no
# per-invocation templating (13-RESEARCH.md, "Command templating"), so the
# `--file` value check-plan-review.sh's bypass list wants arrives on stdin
# JSON, not as a shell argument. This wrapper is a THIN ADAPTER: it derives
# the value, execs the unchanged gate, and translates the gate's {0,2} exit
# contract into codex-cli's PreToolUse `permissionDecision` shape. All gate
# verdict logic (resolve phase, REVIEWS.md evidence, WR-03 path containment)
# stays in check-plan-review.sh — this file must never re-implement it.
#
# Matcher decision (13-01-SPIKE-FINDINGS.md, FROZEN): hooks.json's
# PreToolUse entry carries `"matcher": "apply_patch"`. STEP 7 of the spike
# proved apply_patch IS covered by PreToolUse on codex-cli 0.144.4 and the
# patch blob arrives under `tool_input.command` (same field name Bash uses,
# different content) — so this wrapper has NO Bash-command-parsing branch
# (RESEARCH.md Open Question 1: only add it if apply_patch proved
# uncovered; it did not — no speculative dead code).
#
# ⚠ LOAD-BEARING CONTRACT (13-01-SPIKE-FINDINGS.md STEP 3 side-finding): a
# PreToolUse hook emitting invalid/partial stdout FAILS OPEN — codex reports
# "PreToolUse hook (failed)" and RUNS THE TOOL ANYWAY. Every terminal path
# below is therefore an explicit `exit 0` (silent allow, or deny expressed
# as strictly valid JSON on stdout) or `exit 2` (fallback only, stderr-only,
# no stdout). No path may emit partial/malformed stdout or a third exit
# code. `set -uo pipefail`, never bare `set -e` — matching
# check-plan-review.sh's own discipline: a mid-parse death here would be a
# silent bypass (an uncaught crash exits non-zero with no captured OUT,
# which is exactly the fallback branch's job to catch, not a script abort).
set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Read stdin ONCE. All field extraction goes through jq — never naive
# string-splitting (13-RESEARCH.md Security Domain, V5 input validation).
# Malformed/unexpected JSON must become "no derivable --file", never a crash.
# ─────────────────────────────────────────────────────────────────────────────
PAYLOAD="$(cat)"
TOOL_NAME="$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null)"

# ─────────────────────────────────────────────────────────────────────────────
# Self-evidencing invocation log (debug session codex-hook-not-firing,
# 2026-07-19). Written BEFORE any decision logic, on EVERY invocation —
# allow, deny, or fallback — so "the native hook fired" is directly
# observable evidence (a new log line) rather than an inference from block
# text alone. A live session that produces zero new lines here proves the
# native PreToolUse dispatch never reached this wrapper at all, regardless
# of what the transcript shows (e.g. an agent's own compliant self-check).
# Best-effort only: a log-write failure (unwritable CODEX_HOME, read-only
# fs) must never flip this load-bearing script's exit contract, so errors
# are swallowed and the write is never allowed to abort the script (no
# `set -e` reliance; `|| true` on the exact line that can fail).
# ─────────────────────────────────────────────────────────────────────────────
HW_LOG="${CODEX_HOME:-$HOME/.codex}/hook-wrapper-plan-review.log"
printf '%s pid=%s tool_name=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" "$$" "${TOOL_NAME:-<empty>}" >>"$HW_LOG" 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# Best-effort --file derivation. Absence of a derivable path is NOT an
# error — the gate is called without --file and falls through to its own
# phase/REVIEWS.md resolver, which is where a real disallowed edit is
# expected to block (RESEARCH.md Open Question 2: --file is a nice-to-have
# bypass-list precision aid, not required for the gate to function).
#
# Do NOT re-implement any path-safety or gate logic here (T-13-02): the
# derived value flows unmodified into check-plan-review.sh --file, which
# runs its own WR-03 canonicalize-and-contain guard. A second, weaker check
# in this wrapper would be a regression surface, not a defense.
# ─────────────────────────────────────────────────────────────────────────────
CPR_FILE=""
case "$TOOL_NAME" in
  apply_patch)
    # tool_input.command carries the patch blob (13-01-SPIKE-FINDINGS.md
    # STEP 7: confirmed field name, verbatim from a live payload). It
    # contains parseable `*** Add File: <path>` / `*** Update File: <path>`
    # header lines; take the first one found.
    #
    # `sed -E` (portable extended regex), NOT basic-regex `\(...\|...\)`
    # (debug session codex-hook-not-firing, 2026-07-19 — found while
    # verifying this fix end-to-end): GNU sed treats `\|` inside a BRE as
    # alternation (a documented GNU extension), but BSD/macOS sed's BRE
    # treats `\|` as a LITERAL pipe character — the pattern never matches
    # on macOS, CPR_FILE silently stays empty, and the gate falls through to
    # phase-only resolution on every real invocation on this operator's
    # machine. `-E` makes `(Add|Update)` portable ERE alternation on both.
    CPR_FILE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null \
                | sed -n -E 's/^\*\*\* (Add|Update) File: //p' | head -1)"
    ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# Exec the unchanged gate, capturing its stderr (the reason text, per
# check-plan-review.sh's own `_cpr_block()` discipline) via `2>&1 1>/dev/null`
# and its exit code. RC is {0,2} by check-plan-review.sh's own documented
# contract; no other value is meaningful.
# ─────────────────────────────────────────────────────────────────────────────
GATE="${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/scripts/check-plan-review.sh"
# GSD_PLAN_REVIEW_SOURCE=native-hook (debug session codex-hook-not-firing,
# 2026-07-19): tags every block this invocation produces as coming from the
# native PreToolUse dispatch, not an agent's own compliant bash self-check.
# See check-plan-review.sh's _cpr_block() for the consuming half.
if [ -n "$CPR_FILE" ]; then
  OUT="$(GSD_PLAN_REVIEW_SOURCE=native-hook "$GATE" --file "$CPR_FILE" 2>&1 1>/dev/null)"
else
  OUT="$(GSD_PLAN_REVIEW_SOURCE=native-hook "$GATE" 2>&1 1>/dev/null)"
fi
RC=$?

if [ "$RC" -eq 0 ]; then
  # ALLOW — silent exit 0, no stdout. Matches check-plan-review.sh's own
  # allow contract and codex-cli's documented "empty stdout is a no-op
  # success" behavior.
  exit 0
fi

if [ -n "$OUT" ]; then
  # BLOCK — primary path: strictly valid deny JSON on stdout, built with
  # jq (never hand-escaped) so a reason containing quotes/newlines cannot
  # produce malformed JSON and flip the gate open (the load-bearing
  # contract above). The block is expressed via the JSON body, not the
  # exit code — this path always exits 0.
  jq -n --arg reason "$OUT" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

# FALLBACK (SC#3's target) — reachable ONLY if check-plan-review.sh somehow
# exited non-zero with EMPTY stderr, which its own `_cpr_block()` discipline
# is designed to make unreachable in practice (RESEARCH.md Assumption A3).
# "Should be unreachable" is exactly the class of assumption this milestone
# does not trust blindly: this branch is mutation-tested (SC#3) to prove it
# always writes a non-empty reason before exit 2 — a silent exit-2 block
# with no reason is indistinguishable from a hang or crash and is the
# fail-open nemesis this contract defends against.
# FALLBACK-STDERR-MARKER: the line below must never be silenced or removed.
echo "plan-review hook wrapper: BLOCKED (exit 2) — check-plan-review.sh exited $RC with no captured reason; blocking CLOSED, not open" >&2
exit 2
