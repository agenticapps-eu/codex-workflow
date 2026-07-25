# ADR-0013: Vendor core's canonical reviewer-cli, and arbitrate it like the gate

**Status**: Accepted  **Date**: 2026-07-25  **Linear**: —
**Supersedes**: nothing. **Extends**: [ADR-0012](0012-vendor-canonical-change-gate.md)
**Upstream**: core#41 (the incident), core#42 (the canonical)

## Context

ADR-0012 stopped this repo maintaining a copy of the §18 change-gate. The gate
**consumes** review evidence. `bin/reviewer-cli.sh` — the wrapper the review
producer calls once per vendor — **produces** it, and it was left forked.

On 2026-07-25, roughly two hours after the gate fork was closed, that fired. A
sibling host's installer delivered the correctly-arbitrated `1.2.2` gate and, in
the same run, blind-installed its 3-arm wrapper over this repo's 4-arm one at the
shared path both write:

```
$ ~/.agenticapps/bin/reviewer-cli.sh opencode <prompt>
reviewer-cli: unknown vendor 'opencode' (expected: gemini | codex | claude)
```

One installer run, two shared artifacts, opposite outcomes. The gate carries
`# gate-version:` and every host compares it before writing. The wrapper carried
no marker, so it was last-writer-wins. That single difference is the whole
incident.

Three copies existed at one path: `codex-workflow` 95 lines / 4 arms,
`pi-agentic-apps-workflow` 85 / 3, `opencode-workflow` 72 / 2.

**The failure mode is worth stating precisely, because it is not the obvious
one.** This was never a gate bypass. A producer that excludes its own host still
had two reachable vendors and §18's `>= 2` threshold held throughout. What was
lost is quieter and worse: a vendor arm that vanishes surfaces mid-review as
`unknown vendor`, is recorded as "reviewer unavailable", and the change proceeds
with one fewer independent opinion. A drifted consumer fails loudly. **A drifted
producer reports clean while supplying less of the evidence the consumer then
accepts.**

Core answered with core#42: the canonical wrapper at
`# reviewer-cli-version: 1.0.0` plus a 14-row conformance harness. Measured
against it before adoption, this repo's copy scored **13 of 14** — failing only
the version-marker row. It was behaviourally the superset of every other copy on
the machine and still the problem, because behaviour was never the problem.

## Decision

Vendor `bin/reviewer-cli.sh` and `tools/reviewer-cli-conformance.sh`
byte-identically from core `60cd83f`, record both in `tools/core-vendor.manifest`
under the one commit that now covers all four vendored files, teach
`bin/install-gate.sh` to arbitrate on an arbitrary marker, route `install.sh`
through it, marker-gate the producer's resolution of the shared copy, and score
the wrapper in CI ahead of the gate.

Five sub-decisions carry the reasoning.

### 1. Parameterise the existing installer; do not duplicate or inline it

`bin/install-gate.sh` takes `--marker <name>`, defaulting to `gate-version`.
`gate_version()` became `artifact_version()`. The gate's call site is
byte-identical, so `test_migration_0014_arbitration` (19 rows) acted as
regression cover for the refactor without being edited — a test changed in the
same commit as the code it guards has stopped guarding.

The lock stays `$DST.lock`, per destination. Two artifacts at two paths never
contend; two hosts racing on the same artifact still serialise. A single global
installer lock would have been simpler and wrong in the direction that costs.

### 2. The producer requires a well-formed marker, and that check verifies nothing

The producer prefers the shared copy only when it carries three dot-separated
integers — the same thing the installer means by "marker". Presence alone would
be weaker than the arbitration it complements: `1.2.a` is `0.0.0` to the
installer, which would overwrite it, so it must not be good enough to execute.

**A marker is a plain comment.** Anything that can write the file can write it.
In the producer it discriminates canonical from pre-canonical and does nothing
else — not integrity, not a signature.

The denial is **scoped to that check**, and the first draft got this wrong by
stating it as a blanket property. The *installer* uses the same marker for
version *comparison*, which is a weak form of version provenance, and it has a
real residual: a host publishing a lying `9.9.9` makes this repo refuse to
"downgrade" to its own canonical copy. Arbitration defends against a stale
**honest** host — the failure core#41 actually observed — not a dishonest one.
Both statements now appear in the spec rather than being left to inference.

### 3. One core commit covers every vendored file

The manifest advanced `750da2e` → `60cd83f` and grew from two files to four.
Advancing it required re-verifying the two it already covered rather than
carrying them forward: core#42 touched neither gate file, both sha256s are
unchanged, and 0014 still scores 37/37 with byte-identity green.

Per-file commits were rejected. They satisfy "each file records a commit" while
permitting exactly the stale-harness pairing the same-commit rule exists to
prevent.

### 4. `reviewer-cli` is its own capability

The gate and the wrapper fail independently, are vendored from different core
artifacts, and have different enforcement surfaces. Separate specs keep each
falsifiable alone.

### 5. A version bump, unlike the 1.2.2 gate re-vendor

That was a vendored dependency moving. This is a new installed artifact plus
changed installer behaviour at a shared path — a re-runnable change with an
on-disk end state, which is what a migration records. 1.1.0 → 1.2.0, migration
0015.

## Alternatives Rejected

**A separate `bin/install-reviewer-cli.sh`.** ~130 duplicated lines of
concurrency-critical code: the comparison, the bounded-retry lock, the GNU/BSD
`stat` handling, the atomic write. A fix applied to one copy and not the other is
divergence at the exact surface this change exists to un-diverge — the same shape
as core#41, one directory over.

**An inline arbitration block in `install.sh`, matching `claude-workflow`.** The
sibling does exactly that, and fleet-uniform source has real value. But it
inlines because it has no separate installer; copying its shape here would drop
the lock and the atomic write that migration 0014 deliberately built,
reintroducing a non-atomic check-then-write. Uniformity of *behaviour* — refuse
downgrades on the marker — is what core#42 asks for. Uniformity of file layout
is not.

**Renaming to `install-shared.sh`.** More honest about what the script now does,
but it breaks the path `test_migration_0014` pins, `install.sh`, and the operator
command recorded in the session handoff, forcing a compat shim or a doc sweep
into an otherwise additive diff. The narrower name is the cheaper wrong thing.

**Leaving the producer's resolution unconditional.** Smaller, and correct once
every host arbitrates — but "once every host adopts" is a state we do not control
and cannot date, and `opencode-workflow` has not. The failure it permits is
silent.

**Hand-merging this repo's 4-arm copy into the canonical.** Core#42 already
merged the three divergent copies — pi's structure (stdin pinned inside
`run_bounded`, one place covering both branches) with codex's coverage (four arms
and the `opencode` model-provenance note). Merging ours in again creates a fourth
variant.

**Correcting the `change-gate` spec's "vendor header" claim in this change.** It
is genuinely wrong — headers were rejected during 0014 because one breaks the
byte-identity it claims to record — but both reviewers returned REQUEST-CHANGES
on bundling it, and `opencode` supplied the argument that settled it: the
scenario being replaced was **unreachable**, so the delta moved an invariant from
an unenforced surface to an enforced one. That is a behavioural change to the
gate, and it should be proposed and reviewed as one. Deferred, with the
instruction to describe it accurately when it is.

## Consequences

- **The shared wrapper goes from 12/14 to 14/14** the first time `install.sh`
  runs, and can no longer be silently downgraded by this host.
- **`bin/install-gate.sh` now has two callers**, so a bug in it breaks two
  artifacts. That is the same trade the shared gate itself makes, and the
  alternative is two copies that drift.
- **The spec set temporarily contradicts itself** — `reviewer-cli` says
  provenance is never in a header, `change-gate` still says it is. This is the
  direct cost of the deferral both reviewers demanded, and it is tracked in
  migration 0015's follow-ups rather than left to be rediscovered.
- **`opencode-workflow` remains a hole.** It ships a 9/14 unmarked copy and does
  not arbitrate, so it can still clobber the shared path. This repo can only stop
  causing the problem and stop trusting the result.
- **Review discipline earned its keep, measurably.** Three rounds, two
  REQUEST-CHANGES rounds, and the change is materially different: one requirement
  dropped, one TDD row found to be untestable as written, one parameter removed,
  four scenarios added. The round-2 finding is the sharpest — task 1.5's RED did
  not reproduce from its own assertion, because "one commit, every listed file
  verifies" was already true of the two-file manifest. That row would have been a
  post-hoc regression test wearing a `tdd="true"` tag, and no amount of care
  reading my own plan had caught it.
