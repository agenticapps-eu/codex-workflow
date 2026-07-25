#!/usr/bin/env bash
# install-gate.sh — version-arbitrating installer for the shared §18 change-gate.
#
# Usage:
#   install-gate.sh [--dry-run] <source-gate> <destination-path>
#
# Exit: 0 = installed, or deliberately declined (refuse-downgrade is a DECISION,
#         not a failure)
#       1 = broken install — bad arguments, unreadable source, un-creatable
#           destination, or a failed write. Something is actually wrong.
#       2 = lock contention — another installer holds the lock and it is not
#           stale. Retryable; nothing is wrong with this machine.
#
# The split exists so a caller can be loud about 1 and tolerant of 2. Collapsing
# them means a genuinely failed install reads the same as two installers racing.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS EXISTS
# ─────────────────────────────────────────────────────────────────────────────
# All four AgenticApps hosts (claude, codex, opencode, pi) install the change
# gate to ONE shared path: ~/.agenticapps/bin/openspec-change-gate.sh. Without
# arbitration that is last-writer-wins — a host still vendoring an older copy
# silently republishes it over a newer one and reverts the fix for every agent
# on the machine. That is the hazard issue #26 was filed about, and core's gate
# README makes honouring `# gate-version:` a MUST for every host.
#
# It is a separate script rather than a block inside install.sh so that it can
# be driven directly with fixtures. Arbitration exercisable only by running a
# full installer — which also lays down skills and binds upstream — is
# arbitration nobody tests, and untested arbitration is how we got here.
#
# ─────────────────────────────────────────────────────────────────────────────
# THE RULES
# ─────────────────────────────────────────────────────────────────────────────
#   installed > incoming   -> REFUSE, print both versions and the force command
#   installed == incoming  -> WRITE (refresh: repairs a truncated same-version copy)
#   installed < incoming   -> WRITE (upgrade)
#
# A marker that is absent, or is not exactly three dot-separated integers, is
# treated as 0.0.0 — ON BOTH SIDES. Every pre-canonical copy is unmarked, so
# first adoption always proceeds. Symmetrically, an incoming file whose own
# header is corrupt is 0.0.0 and is refused against any real installed version:
# a gate whose provenance cannot be read should not displace one whose can.
#
# `1.3.0-rc1` and `1.2` are treated as oldest rather than ordered by a rule the
# comparison does not implement. The compare is a three-field numeric sort, not
# a semver implementation, and it should degrade to a safe answer rather than
# silently mis-order a shape it cannot parse.
#
# ─────────────────────────────────────────────────────────────────────────────
# CONCURRENCY
# ─────────────────────────────────────────────────────────────────────────────
# Check-then-write is not atomic: two hosts installing concurrently can each
# read the pre-existing version, and the later writer can land the older gate —
# breaking the invariant exactly when arbitration matters. So:
#
#   - the read-compare-write sequence is serialised by a `mkdir` lock (atomic on
#     POSIX, and present on macOS where flock is not), and
#   - the write itself is a temp file in the destination directory + `mv`.
#
# The lock model is BOUNDED RETRY, stated rather than implied: retry to
# OPENSPEC_GATE_LOCK_WAIT, reclaim any lock older than OPENSPEC_GATE_LOCK_STALE,
# otherwise exit non-zero. Naming it matters — under unbounded retry the
# give-up case is unreachable, and under single-attempt fail-fast the
# serialisation guarantee is fiction. Bounded retry makes both reachable.
#
# Residual, accepted: two installers can both judge one lock stale and both
# reclaim it, losing serialisation for that pair. The safety property survives —
# the write is atomic, so the outcome is a wrong version, never a torn file.
set -u

DRY_RUN=0
case "${1:-}" in --dry-run) DRY_RUN=1; shift ;; esac

SRC="${1:-}"
DST="${2:-}"
LOCK_WAIT="${OPENSPEC_GATE_LOCK_WAIT:-10}"     # seconds to retry before giving up
LOCK_STALE="${OPENSPEC_GATE_LOCK_STALE:-300}"  # seconds after which a lock is stale

log() { printf 'install-gate: %s\n' "$*" >&2; }

[ -n "$SRC" ] && [ -n "$DST" ] || { log "usage: install-gate.sh [--dry-run] <source-gate> <destination-path>"; exit 1; }
[ -f "$SRC" ] || { log "source gate not found: $SRC"; exit 1; }

# ── Marker parsing ───────────────────────────────────────────────────────────
# Anything that is not exactly three dot-separated integers is 0.0.0.
gate_version() {
  local v
  [ -f "$1" ] || { printf '0.0.0'; return; }
  v="$(grep -m1 '^# gate-version:' "$1" 2>/dev/null | sed 's/^# gate-version:[[:space:]]*//' | tr -d '[:space:]')"
  case "$v" in
    ''|*[!0-9.]*)  printf '0.0.0'; return ;;
    .*|*.|*..*)    printf '0.0.0'; return ;;
  esac
  [ "$(printf '%s' "$v" | tr -cd '.' | wc -c | tr -d ' ')" = "2" ] || { printf '0.0.0'; return; }
  printf '%s' "$v"
}

# Portable three-field numeric compare. NOT `sort -V`: BSD sort on the macOS leg
# of this repo's CI matrix has no version-sort flag, the same constraint
# test_drift already works around.
# echoes: "gt" if $1 > $2, "eq", or "lt"
version_cmp() {
  [ "$1" = "$2" ] && { printf 'eq'; return; }
  local top
  top="$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
  if [ "$top" = "$1" ]; then printf 'gt'; else printf 'lt'; fi
}

INCOMING="$(gate_version "$SRC")"
INSTALLED="$(gate_version "$DST")"
CMP="$(version_cmp "$INCOMING" "$INSTALLED")"

if [ "$CMP" = "lt" ]; then
  log "REFUSING to downgrade the shared change-gate."
  log "  installed: $INSTALLED   at $DST"
  log "  incoming:  $INCOMING   from $SRC"
  log "  Every AgenticApps host writes this one path, so overwriting a newer gate"
  log "  would revert the fix for every agent on this machine."
  log "  If you genuinely intend to roll back, force it deliberately:"
  log "      install -m 0755 '$SRC' '$DST'"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "would install $INCOMING over ${INSTALLED} at $DST ($([ "$CMP" = eq ] && echo refresh || echo upgrade)); --dry-run, nothing written"
  exit 0
fi

# ── Bounded-retry lock around read-compare-write ─────────────────────────────
DEST_DIR="$(dirname "$DST")"
mkdir -p "$DEST_DIR" || { log "cannot create $DEST_DIR"; exit 1; }
LOCK="$DST.lock"

lock_age() {   # seconds since the lock dir was created; huge if unknowable
  # `stat` is one of the sharpest BSD/GNU divergences, and chaining the two
  # forms with `||` is NOT enough: on GNU, `-f` means --file-system, so
  # `stat -f %m` SUCCEEDS on a directory and prints a non-numeric value. The
  # BSD-first `||` chain therefore never falls through on Linux, the arithmetic
  # below breaks on the garbage, and the lock is never judged stale — the
  # installer times out into contention instead of reclaiming. Caught by the
  # ubuntu leg of the CI matrix; macOS passed, which is exactly why the matrix
  # exists.
  #
  # So: try each form, and VALIDATE the output is an integer before trusting it.
  # Exit status alone does not tell you whether the flag meant what you wanted.
  local mt now
  mt="$(stat -c %Y "$LOCK" 2>/dev/null)" || mt=""            # GNU coreutils
  case "$mt" in ''|*[!0-9]*) mt="$(stat -f %m "$LOCK" 2>/dev/null)" || mt="" ;; esac   # BSD/macOS
  case "$mt" in ''|*[!0-9]*) printf '999999'; return ;; esac  # unknowable -> treat as stale
  now="$(date +%s)"
  printf '%s' "$(( now - mt ))"
}

# The trap is installed BEFORE the acquisition loop, guarded on `acquired`, so an
# interrupt in the window between mkdir succeeding and the trap being registered
# cannot leak the lock. Registering it after `mkdir` leaves exactly that window
# open; the next run would reclaim it via staleness, but only after the operator
# waits out the threshold for no reason.
acquired=0
waited=0
cleanup() { [ "$acquired" -eq 1 ] && rm -rf "$LOCK"; [ -n "${TMP:-}" ] && rm -f "$TMP"; return 0; }
trap cleanup EXIT INT TERM

while [ "$waited" -le "$LOCK_WAIT" ]; do
  if mkdir "$LOCK" 2>/dev/null; then acquired=1; break; fi
  if [ "$(lock_age)" -ge "$LOCK_STALE" ]; then
    log "WARNING — reclaiming a stale lock at $LOCK (age $(lock_age)s >= ${LOCK_STALE}s)."
    log "          A previous installer probably crashed. If two installers reclaim the"
    log "          same lock, serialisation is lost for that pair: the surviving file is"
    log "          whichever completed last. The write is atomic, so it is never torn."
    rm -rf "$LOCK"
    if mkdir "$LOCK" 2>/dev/null; then acquired=1; break; fi
  fi
  sleep 1
  waited=$(( waited + 1 ))
done

if [ "$acquired" -ne 1 ]; then
  log "could not acquire the lock at $LOCK within ${LOCK_WAIT}s, and it is not stale."
  log "  Another installer is mid-write. NOT proceeding unlocked and NOT skipping —"
  log "  a silently skipped install looks exactly like a successful one, and would"
  log "  leave you believing the gate was arbitrated when it was not."
  log "  Retry in a moment; exit 2 means contention, not breakage."
  exit 2
fi

# Re-read under the lock: the value we compared above may be stale by now.
INSTALLED="$(gate_version "$DST")"
if [ "$(version_cmp "$INCOMING" "$INSTALLED")" = "lt" ]; then
  log "REFUSING to downgrade (another installer wrote $INSTALLED while we waited)."
  exit 0
fi

TMP="$(mktemp "$DEST_DIR/.gate.XXXXXX")" || { log "cannot create a temp file in $DEST_DIR"; exit 1; }
cat "$SRC" > "$TMP" && chmod 0755 "$TMP" && mv -f "$TMP" "$DST" || {
  rm -f "$TMP"; log "failed to install $SRC -> $DST"; exit 1;
}
log "installed gate-version $INCOMING at $DST ($([ "$CMP" = eq ] && echo refresh || echo upgrade), was ${INSTALLED})"
exit 0
