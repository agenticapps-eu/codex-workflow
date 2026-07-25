---
id: 0015
slug: adopt-canonical-reviewer-cli
title: Vendor core's canonical reviewer-cli; arbitrate it like the gate (v1.1.0 -> 1.2.0)
from_version: 1.1.0
to_version: 1.2.0
applies_to:
  - ~/.agenticapps/bin/reviewer-cli.sh                      # now version-arbitrated, never blind-overwritten
  - .codex/workflow-version.txt                             # record new project version
  # Scaffolder-side (shipped by the release, not written into a target project):
  - bin/reviewer-cli.sh                                     # REPLACED — vendored byte-identical from core
  - tools/reviewer-cli-conformance.sh                       # NEW — vendored harness (the instrument)
  - tools/core-vendor.manifest                              # core_commit 750da2e -> 60cd83f, 2 -> 4 files
  - bin/install-gate.sh                                     # --marker <name>; gate-version stays the default
  - install.sh                                              # routes the wrapper install through install-gate.sh
  - skills/codex-openspec-change-review/SKILL.md            # marker-validated shared-path resolution
  - .github/workflows/openspec-gate.yml                     # wrapper conformance step, before the gate step
  - docs/decisions/0013-vendor-canonical-reviewer-cli.md    # NEW — the adoption ADR
requires:
  - tool: openspec
    verify: "openspec --version"
    install: "npm i -g @fission-ai/openspec"
---

# Migration 0015 — Adopt the canonical reviewer-cli (v1.1.0 → 1.2.0)

Migration 0014 adopted the canonical **consumer** of review evidence — the §18
change-gate. This adopts the canonical **producer** of it.

The full rationale and the rejected alternatives are in
[ADR-0013](../docs/decisions/0013-vendor-canonical-reviewer-cli.md). The short
version: core published the gate and left `reviewer-cli.sh` forked across three
hosts at one shared path with no marker and no arbitration. On 2026-07-25, about
two hours after the gate fork was closed, a sibling host's installer delivered
the correctly-arbitrated `1.2.2` gate and, **in the same run**, blind-installed
its 3-arm wrapper over this repo's 4-arm one:

```
$ ~/.agenticapps/bin/reviewer-cli.sh opencode <prompt>
reviewer-cli: unknown vendor 'opencode' (expected: gemini | codex | claude)
```

The gate survived because it carries `# gate-version:` and every host compares
it. The wrapper had no marker, so one installer run upgraded one shared artifact
and silently downgraded the other. Filed as core#41; answered by core#42, which
publishes the canonical at `# reviewer-cli-version: 1.0.0` with a 14-row harness.

**This is not a gate bypass, and that is the point.** A producer excluding its
own host still had two reachable vendors, so §18's `>= 2` threshold held. What
was lost is quieter: a reviewer that vanishes mid-review is recorded as
"reviewer unavailable" and the change proceeds with one fewer opinion. A drifted
consumer fails loudly. A drifted producer reports clean.

Measured before adoption, with core's harness at `60cd83f`:

| copy | score |
|---|---|
| core canonical | 14 / 14 |
| `pi-agentic-apps-workflow` | 14 / 14 |
| `claude-workflow` | 14 / 14 (`88777c9`) |
| **`codex-workflow`** | **13 / 14** — no version marker |
| `opencode-workflow` | 9 / 14 — missing `claude` and `opencode` arms, no marker |
| **`~/.agenticapps/bin/` (shared)** | **12 / 14** — no `opencode` arm, no marker |

This repo's copy was behaviourally the **superset** and still failed, because
behaviour was never the problem. Provenance was.

### Step 1: Vendor the wrapper and its harness from core

**Idempotency check:** `grep -q '^# reviewer-cli-version:' bin/reviewer-cli.sh && test -x tools/reviewer-cli-conformance.sh`
**Pre-condition:** a core checkout, or network access to fetch one
**Apply:**

```bash
CORE="${AGENTICAPPS_CORE_ROOT:-../agenticapps-workflow-core}"
REV=60cd83f8d236b4ef8646976f547e17edafb53eeb   # resolve ONCE; origin/main advances

git -C "$CORE" show "$REV:reference-implementations/reviewer-cli/reviewer-cli.sh" > bin/reviewer-cli.sh
git -C "$CORE" show "$REV:tools/reviewer-cli-conformance.sh" > tools/reviewer-cli-conformance.sh
chmod 0755 bin/reviewer-cli.sh tools/reviewer-cli-conformance.sh
```

Byte-identical, no local header — a "vendored from `<commit>`" comment would
itself break the byte-identity it claimed to record. Provenance lives in
`tools/core-vendor.manifest`, which now names **four** files under **one**
commit. Advancing that commit means re-verifying the two files it already
covered: core#42 touched neither gate file, both sha256s are unchanged, and 0014
still scores 37/37 with byte-identity green.

Do **not** hand-merge this repo's 4-arm copy into the canonical. Core#42 already
merged the three divergent host copies — pi's structure with codex's coverage.
Merging ours in again creates a fourth variant, which is the thing being adopted
away from.

### Step 2: Arbitrate the shared wrapper — supersedes 0013 Step 3

Migration `0013` Step 3 blind-installs the wrapper:

```bash
install -m 0755 "$TPL/reviewer-cli.sh" "$HOME/.agenticapps/bin/reviewer-cli.sh"
```

That line is **retained** in 0013 per §08 supersede-don't-delete, exactly as
0013's blind *gate* install was retained when 0014 superseded it. A replay runs
0013 and then reaches this step, so the end state is arbitrated. Rewriting 0013
would falsify the record of what it did.

**Idempotency check:** `grep -q -- '--marker reviewer-cli-version' install.sh`
**Apply:**

```bash
# install.sh now routes the shared wrapper through bin/install-gate.sh, which
# takes --marker and applies the same rules it already applies to the gate:
#   installed >  incoming -> refuse, naming both versions and the force command
#   installed == incoming -> write (repairs a truncated same-version copy)
#   installed <  incoming -> write
# Absent/malformed markers are 0.0.0 on BOTH sides. Atomic (temp + mv) under a
# bounded-retry mkdir lock, per-destination so the two artifacts never contend.
bash bin/install-gate.sh --dry-run --marker reviewer-cli-version \
  bin/reviewer-cli.sh "$HOME/.agenticapps/bin/reviewer-cli.sh"
```

The arbitration is **parameterised, not duplicated**. A second installer would
copy the comparison, the lock, the GNU/BSD `stat` handling and the atomic write,
and a fix applied to one copy and not the other is divergence at the exact
surface this exists to un-diverge.

### Step 3: Stop the producer trusting an unmarked shared copy

`skills/codex-openspec-change-review/SKILL.md` resolves the shared wrapper first
so one machine-wide install reaches every repo — but now only when it carries a
**well-formed** `# reviewer-cli-version:` (three dot-separated integers, the same
thing the installer means by it). Otherwise it falls back to the repo copy.

A marker is a plain comment: this check discriminates canonical from
pre-canonical and verifies nothing. It is not integrity and not a signature.

### Step 4: Score the producer in CI, before the gate

`.github/workflows/openspec-gate.yml` runs
`tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh` ahead of the gate step.
The harness stubs every vendor CLI on `PATH` in a `mktemp` dir; no real reviewer
is invoked.

### Step 5: Bump versions (1.1.0 → 1.2.0)

```bash
printf '1.2.0\n' > .codex/workflow-version.txt
# skills/agentic-apps-workflow/SKILL.md `version:` -> 1.2.0 (test_drift asserts both agree)
```

A bump, unlike the 1.2.2 gate re-vendor which took none. That was a vendored
dependency moving. This is a **new** installed artifact plus **changed**
installer behaviour at a shared path — a re-runnable change with an on-disk end
state, which is what a migration records.

## Verification

```bash
bash migrations/run-tests.sh          # test_migration_0015{,_arbitration,_surfaces}
bash tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh   # 14 passed, 0 failed
bash tools/reviewer-cli-conformance.sh --family              # the fleet, if siblings are checked out
```

## Fleet state at adoption

**The fleet converged during this change.** `opencode-workflow` adopted in its
#19 while this was in review, so the 9/14 copy this migration was partly written
against no longer exists. Measured after adoption:

| copy | score |
|---|---|
| `claude-workflow` · `codex-workflow` · `opencode-workflow` · `pi-agentic-apps-workflow` | 14 / 14 each |
| `~/.agenticapps/bin/` (shared) | 14 / 14 |

All five are byte-identical to the canonical (`32718bb9…`). A dry-run against the
live shared path now reports `would install reviewer-cli 1.0.0 over 1.0.0
(refresh)` — arbitration working end-to-end, from four divergent copies to one
file, inside a day.

**The marker check does not become decoration because of that.** Convergence is
a state, not a property. It is undone by any host reinstalling from an older
checkout, by a fifth host, or by a hand-edited shared copy — and the check costs
one `grep`.

## Known holes, named rather than implied

- **Arbitration reads a marker anyone able to write the file can write.** A host
  publishing a lying `9.9.9` makes this repo refuse to "downgrade" to its own
  canonical copy. It defends against a stale *honest* host — the failure core#41
  observed — not a dishonest one.
- **`--family` mode does not work from a vendored copy.** The harness resolves
  the canonical as `$(dirname $0)/../reference-implementations/reviewer-cli/…`,
  which only exists in a core checkout, so a host running `--family` scores a
  phantom row `FAIL file not found` on top of an otherwise clean fleet (`70
  passed, 1 failed` — five real copies at 14 each). It does **not** affect CI,
  which scores a single named file. Do not patch it here: file it upstream, per
  the rule this whole change exists to enforce.

## Follow-ups (deliberately not in this migration)

1. **The `change-gate` spec still says "vendor header".** `openspec/specs/change-gate/spec.md`
   requires the vendored files to record their commit in a header; the
   implementation rejected headers during 0014 and uses the manifest sidecar. A
   delta correcting it was in this change and **both reviewers asked for it to be
   removed** — not merely as scope, but because it was mis-described: the
   scenario it replaced was unreachable (no header ever shipped), so the delta
   moved an invariant from an unenforced surface to an enforced one. That is a
   behavioural change to the *gate*. Propose it separately, and describe it as
   what it does.
2. **`bin/install-gate.sh` justifies its hand-rolled compare with a false claim.**
   The comment says BSD `sort` has no version-sort flag; Apple `sort` 2.3 accepts
   `-V` and orders correctly. The three-field numeric compare is fine and stays —
   the stated reason is what is wrong, and correcting a comment did not justify
   widening this diff.
