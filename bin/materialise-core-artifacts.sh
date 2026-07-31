#!/usr/bin/env bash
# materialise-core-artifacts-version: 1.0.0
#
# materialise-core-artifacts.sh — put the pinned core artifacts on disk at
# bin/, verified against tools/core-vendor.manifest.
#
# WHY THIS EXISTS
#
# This host used to VENDOR core's gate and reviewer wrapper: real bytes,
# committed, re-vendored by hand on every core release. They drifted, which is
# what copies do. On 2026-07-31 this repo still carried gate 1.3.1 against
# core's 2.0.0 and wrapper 1.1.0 against 1.2.0 — it had missed the release in
# which reviews stopped being enforced, and nothing noticed.
#
# ADR-0047 replaced the copies with a pin. But unlike claude-workflow, where
# deleting the copies outright was clean, this repo has SEVERAL consumers that
# legitimately want the artifacts at a stable path:
#
#   - skills/setup-codex-agenticapps-workflow/templates/*.sh are SYMLINKS into
#     bin/, and migration 0013 installs a target repo's copies from that stable
#     installed path
#   - bin/openspec-gate-ci.sh scores and runs the gate
#   - migrations/run-tests.sh drives it from a dozen places
#
# So bin/ stays — as a CACHE, not as source. The bytes are gitignored and
# regenerated from the pin, so they cannot drift: a wrong byte fails the
# resolver's sha256 check and nothing lands.
#
# Idempotent. Re-running with the artifacts already correct is a no-op.
#
# USAGE
#   materialise-core-artifacts.sh [--check]
#
#     --check   verify only; do not write. Non-zero if anything is missing or
#               does not match the pin.
#
# ENV
#   CORE_CHECKOUT   explicit path to a core working copy; tried first.
#   CORE_OFFLINE=1  never reach the network; fail if no local source resolves.
#
# EXIT
#   0  every artifact is present and matches the pin
#   1  could not resolve, or --check found a mismatch

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/tools/core-vendor.manifest"
RESOLVER="$ROOT/bin/resolve-core-artifact.sh"

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# The artifacts this host materialises. Every one is a `file=` key in the
# manifest, so the resolver verifies each against a recorded sha256.
ARTIFACTS="bin/openspec-change-gate.sh bin/reviewer-cli.sh"

[ -f "$MANIFEST" ] || { echo "materialise: no tools/core-vendor.manifest" >&2; exit 1; }
[ -x "$RESOLVER" ] || { echo "materialise: no executable bin/resolve-core-artifact.sh" >&2; exit 1; }

sha_of() {
  if   command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum    >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else echo "materialise: no sha256sum/shasum on PATH" >&2; exit 1; fi
}

want_sha_for() { # $1 = logical path
  awk -v f="$1" '$0 ~ "^file="f"[[:space:]]" {
    for (i = 1; i <= NF; i++) if ($i ~ /^sha256=/) { sub(/^sha256=/, "", $i); print $i; exit }
  }' "$MANIFEST"
}

rc=0
for logical in $ARTIFACTS; do
  dst="$ROOT/$logical"
  want="$(want_sha_for "$logical")"
  if [ -z "$want" ]; then
    echo "materialise: $logical is not pinned in the manifest — refusing to guess" >&2
    rc=1; continue
  fi

  # Already correct? Then neither mode has anything to do. This is what makes
  # the script cheap enough to call from install.sh, CI and the test suite.
  if [ -f "$dst" ] && [ "$(sha_of "$dst")" = "$want" ]; then
    continue
  fi

  if [ "$CHECK_ONLY" -eq 1 ]; then
    if [ -f "$dst" ]; then
      echo "materialise: $logical does not match the pin (stale or edited)" >&2
    else
      echo "materialise: $logical is not materialised" >&2
    fi
    rc=1; continue
  fi

  if ! src="$("$RESOLVER" "$MANIFEST" "$logical")"; then
    echo "materialise: could not resolve $logical from core (diagnostics above)" >&2
    rc=1; continue
  fi
  # `install` sets the mode explicitly; the resolver hands back a 0600 mktemp,
  # which is right for it but useless to a consumer that execs the file.
  install -m 0755 "$src" "$dst" || rc=1
  rm -f "$src"
done

exit "$rc"
