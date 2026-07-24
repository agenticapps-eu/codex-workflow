#!/usr/bin/env bash
# openspec-gate-ci.sh — CI driver for the §18 OpenSpec change-gate.
#
# The gate script itself (openspec-change-gate.sh) is deliberately ONE
# host-agnostic file, byte-identical across every AgenticApps host, and it
# speaks exactly one protocol: a tool-call payload on stdin, a {0,2} exit code
# out. This driver is the thin CI adapter around it — it does NOT re-implement
# any verdict logic.
#
# It is the sibling of bin/git-hooks/pre-commit: same loop, different file set.
# pre-commit gates what is STAGED; this gates what a PR CHANGED. Together they
# are the agent-agnostic enforcement floor — they catch edits from any agent or
# a human, including the session that installed the per-agent hook (a PreToolUse
# hook cannot gate its own installing session, §18).
#
# Usage:
#   bin/openspec-gate-ci.sh [<base-ref>]
#     <base-ref>  the ref to diff against (default: origin/main, then main,
#                 then HEAD~1 — whichever resolves first)
#
# Exit: 0 = every changed non-OpenSpec file is allowed; 1 = the gate blocked.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

GATE=""
for c in "${OPENSPEC_CHANGE_GATE:-}" \
         "$HOME/.agenticapps/bin/openspec-change-gate.sh" \
         "$ROOT/bin/openspec-change-gate.sh"; do
  [ -n "$c" ] && [ -x "$c" ] && { GATE="$c"; break; }
done
[ -n "$GATE" ] || { echo "openspec-gate-ci: no gate script found — nothing to enforce" >&2; exit 0; }

# No spec slot => the repo has not adopted OpenSpec => nothing to gate.
if [ ! -d "openspec/changes" ]; then
  echo "openspec-gate-ci: no openspec/changes/ — repo has no spec slot yet, skipping"
  exit 0
fi

BASE="${1:-}"
if [ -z "$BASE" ]; then
  for candidate in origin/main main HEAD~1; do
    if git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then BASE="$candidate"; break; fi
  done
fi
[ -n "$BASE" ] || { echo "openspec-gate-ci: no base ref resolved — skipping" >&2; exit 0; }

blocked=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in openspec/*) continue ;; esac   # authoring the change is exempt
  payload="{\"tool\":\"edit\",\"tool_input\":{\"file_path\":\"$f\"}}"
  if ! printf '%s' "$payload" | "$GATE"; then
    blocked=1
    break   # one block is enough; the gate already explained why on stderr
  fi
done < <(git diff --name-only --diff-filter=ACM "$BASE"...HEAD)

if [ "$blocked" -ne 0 ]; then
  echo "openspec-gate-ci: BLOCKED by the OpenSpec change-gate (§18)." >&2
  echo "  The active change must pass 'openspec validate --all' AND carry" >&2
  echo "  REVIEWS.md with >=2 '## Reviewer:' sections before code lands." >&2
  exit 1
fi
echo "openspec-gate-ci: OK — every changed file is allowed by the change-gate."
exit 0
