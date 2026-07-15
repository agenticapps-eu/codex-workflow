---
id: 0009
slug: spec-11-region-aware-placement
title: Anchor the §11 block above any GitNexus-managed region (v0.6.0 -> 0.7.0)
from_version: 0.6.0
to_version: 0.7.0
applies_to:
  - AGENTS.md                              # §11 block placement healed (Step 1)
  - skills/agentic-apps-workflow/SKILL.md  # version bump 0.6.0 -> 0.7.0 (Step 2)
  - .codex/workflow-version.txt            # project version recorded (Step 3)
requires: []
optional_for: []
---

# Migration 0009 — Region-aware §11 placement (v0.6.0 -> 0.7.0)

Migration `0001` injects the canonical §11 block immediately before the first
`## ` heading in `AGENTS.md` (`0001:91`), and `0004` re-injects it the same way
(`0004:77`). That is only a safe boundary when the first `## ` heading belongs
to *project* content. In an `AGENTS.md` that leads with the GitNexus block, the
first `## ` is `## Always Do` — which sits **inside**
`<!-- gitnexus:start -->…<!-- gitnexus:end -->`. The block lands in the region,
and the next `gitnexus analyze` regenerates that region and destroys the block
with no diagnostic.

Nothing recovers from that. The update engine marks a migration pending iff
`installed >= from_version && installed < to_version`; `0001`'s `to_version` is
`0.2.0`, so for any 0.6.x project it is permanently not-pending. `0001` and
`0004` are immutable and already applied, so this migration fixes **forward**
rather than editing them.

**On this host the defect is LATENT, not active.** This repo's own `AGENTS.md`
carries §11 at the top and its GitNexus region at L271 — the region does not
lead the file, so the naive anchor happens to land correctly here. There is no
broken repo in this project to repair. This migration exists because every
project this host scaffolds inherits the naive anchor, and any one of them whose
`AGENTS.md` is region-led is one `gitnexus analyze` away from silently losing
§11.

**The anchor rule.** Insert immediately before the first line that is **either**
a `## ` heading **or** a line that is *exactly* `<!-- gitnexus:start -->` —
whichever comes first; EOF if neither. Both marker regexes MUST be anchored
(`/^<!-- gitnexus:start -->$/`, `/^<!-- gitnexus:end -->$/`). An unanchored
substring match also fires on prose that merely *mentions* the marker — which is
exactly what a scaffolded project's own `AGENTS.md` guidance comment does — and
would misjudge a perfectly healthy file as region-led.

The rule anchors on the region **only when the region comes first**. Anchoring
before `gitnexus:start` whenever a region exists anywhere would be wrong: in a
project whose region starts late, the block would land hundreds of lines down,
violating §12's placement advisory. This rule was validated empirically against
this host's real `AGENTS.md` and a synthesized region-led file *before* this
document was written — it re-derives the block's current position byte-identically
on the healthy file (zero churn) and anchors above the region on a region-led one.

**The structural invariant is WIDENED, not preserved.** `0001`/`0004` could
assume the managed block is always followed by a `## ` line or EOF, because their
anchor could only ever *be* a `## ` heading. Once the anchor can also be a
`<!-- gitnexus:start -->` marker, a healed region-led file has the block followed
by that marker, not by a `## ` line. The invariant that actually holds after this
migration is: **the block is always followed by a `## ` line, an anchored
`<!-- gitnexus:start -->` marker, or EOF.** This is not a delta that leaves the
old invariant intact — it replaces it. Every terminator that bounds the managed
section carries the same alternation as the anchor, because the anchor rule and
the terminator rule are **one decision, not two**, and must move together. A
terminator that recognizes only `## ` runs straight past the marker on an
already-healed file and consumes the entire region — see Step 1.

## Why a 0.x minor bump

`0.6.0 -> 0.7.0`. This changes where a managed section is placed in a file the
project owns, and rewrites `AGENTS.md` in place. That is behavioural, not a
patch to vendored bytes (which is what `0004`'s `0.2.0 -> 0.2.1` was), so it
takes a minor bump. `implements_spec` stays **0.4.0** — core's spec version is
unchanged; this migration corrects a *host placement defect*, not a spec version.

## Supported upgrade floor

This migration upgrades **0.6.0 -> 0.7.0 in a single hop**. It does not accept a
lower floor. Every live project already sits at 0.6.0 after `0008`, so a wider
floor would buy nothing real while papering over a known multi-hop
chain-selection defect in the update skill. That defect is deferred and tracked
separately; it does not block this migration.

## Pre-flight

```bash
# 1. Step 1 rewrites AGENTS.md in place and its rollback is `git checkout
#    AGENTS.md`, which requires a git repo to restore from.
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# 2. The project must be at 0.6.0 — or already at 0.7.0, for a re-apply or a
#    partial state. Accepting BOTH is deliberate: an idempotent re-run on an
#    already-migrated project must not abort.
SKILL_FILE=skills/agentic-apps-workflow/SKILL.md
grep -qE '^version: 0\.(6\.0|7\.0)$' "$SKILL_FILE" || {
  INSTALLED=$(grep -E '^version:' "$SKILL_FILE" 2>/dev/null | sed 's/version: //')
  echo "ABORT: workflow scaffolder version is ${INSTALLED:-unknown} (need 0.6.0)."
  echo "       Apply prior migrations first via /update-codex-agenticapps-workflow."
  exit 3
}

# 3. The vendored §11 mirror must be present AND non-empty. `test -f` alone is
#    insufficient: it passes on a zero-byte file, which is exactly what an
#    interrupted `git pull` in the scaffolder clone produces. Because Step 1
#    re-vendors §11 from this mirror as its SOLE source, a zero-byte mirror
#    would strip the project's existing §11 block and inject nothing in its
#    place — silently committing a maimed AGENTS.md. `test -s` catches that
#    before any file surgery runs.
MIRROR="${CODEX_HOME:-$HOME/.codex}/skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md"
test -s "$MIRROR" || {
  echo "ABORT: vendored §11 canonical block missing or empty at:"
  echo "       $MIRROR"
  echo "       Re-install: re-run codex-workflow's install.sh"
  exit 3
}

# 4. Non-empty is not the same as un-truncated. The block's own heading sits on
#    LINE 1 of the mirror, so a mirror truncated at the tail still satisfies
#    `test -s` above AND still satisfies Step 1's pre-`mv` shape assertion
#    (which greps for that same line-1 heading) — both are single-point guards
#    on a continuum, not guards against truncation. So assert the block's LAST
#    section is present too: a real truncation or a corrupt mirror loses the
#    tail long before it loses the head.
#
#    This is NOT the rejected content-sentinel pattern. That anti-pattern
#    coupled a STRIP TERMINATOR to §11's last PROSE line, so prose drift made
#    the strip run away and eat the rest of the file. This is a read-only
#    integrity check on a DIFFERENT file, anchored to a structural `### `
#    heading; it bounds nothing and cannot run away. It is not a byte-identity
#    or checksum check either — vendored-file integrity is git's job and
#    `0004`'s — it is the cheapest guard that closes the gap between "has a
#    heading" and "is the whole block".
grep -q '^### 4\. Goal-Driven Execution$' "$MIRROR" || {
  echo "ABORT: vendored §11 canonical block at:"
  echo "       $MIRROR"
  echo "       is missing its final section — it looks truncated or corrupt."
  echo "       Re-install: re-run codex-workflow's install.sh"
  exit 3
}
```

Pre-flight is deliberately **permissive on the missing-`AGENTS.md` path**: Step 1
emits an informational message and Step 2 still runs. This diverges **on
purpose** from `0004:44`, which hard-aborts when the project has no `AGENTS.md`,
and the divergence is load-bearing. The update engine marks a migration pending iff
`installed >= from_version && installed < to_version`. An abort here would mean
Step 2 never records `0.7.0`, so 0009 stays pending forever *and* every future
migration `0010+` never becomes pending either — the project is stranded at
0.6.0 permanently, unrecoverable without manual intervention. A skip costs
nothing. An abort is unrecoverable.

## Steps
