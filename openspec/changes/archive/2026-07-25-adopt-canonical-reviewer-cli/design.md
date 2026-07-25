## Context

Core published the review producer's wrapper as a reference implementation
(core#42) at `# reviewer-cli-version: 1.0.0`, closing core#41. The README states
four obligations for an adopting host, and this design is mostly about how this
repo discharges the third:

1. Copy `reviewer-cli.sh` into `bin/`. Do not edit it.
2. Copy `tools/reviewer-cli-conformance.sh` too, and run it in CI.
3. **Teach the host's installer to honour `# reviewer-cli-version:`** — every
   host writes the same shared path, so without arbitration it is
   last-writer-wins. Treat an unmarked file as `0.0.0`.
4. Run the harness; report the result in the adoption PR.

Obligations 1, 2 and 4 are mechanical. Obligation 3 is where hosts can
legitimately differ, because they do not share an installer.

The fleet is mid-adoption, which constrains what "consistent" means here:

| host | wrapper | arbitration |
|---|---|---|
| `pi-agentic-apps-workflow` | 1.0.0, byte-identical | (adopted before this change) |
| `claude-workflow` | 1.0.0, byte-identical (`88777c9`, unmerged) | inline block in `install.sh` |
| `codex-workflow` (here) | 4-arm superset, **unmarked** | none for this artifact |
| `opencode-workflow` | 9/14, unmarked | none |

## Goals / Non-Goals

**Goals.** Byte-identity with core. A version marker on the shared path. Every
writer of that path arbitrates. Executable conformance in CI. The producer never
silently resolves a pre-canonical copy.

**Non-Goals.** Fixing `opencode-workflow` (its own PR). Changing the producer's
vendor set or its exclusion rule (already correct). Re-litigating core's merge of
the three divergent copies — that decision is core's, and the harness is how we
would argue with it.

## Decision 1 — Parameterise `install-gate.sh` rather than duplicate or inline it

**Chosen.** `bin/install-gate.sh` gains `--marker <name>`, defaulting to
`gate-version`. `gate_version()` becomes `artifact_version()` taking the marker
name. The gate call site is unchanged, so `test_migration_0014` keeps passing
untouched — a regression row rather than a rewritten one.

The operator-facing label in the log lines is **derived** from the marker by
stripping the `-version` suffix (`gate-version` → `gate`, `reviewer-cli-version`
→ `reviewer-cli`), not passed as a second parameter. Round 1 review: a second
flag whose only effect is log wording is convenience, not requirement, and it
introduces a wrong-label-but-harmless failure mode that deriving removes
entirely.

The lock stays `$DST.lock`, derived from the destination. Two artifacts at two
paths therefore never contend with each other, while two hosts racing on the
*same* artifact still serialise. A single global installer lock would have been
simpler and wrong in the direction that costs: it would serialise unrelated
installs and make contention (exit 2) more likely, not less.

**Rejected — a separate `bin/install-reviewer-cli.sh`.** It would duplicate
~130 lines of concurrency-critical code: `version_cmp`, `lock_age`'s
GNU-vs-BSD `stat` handling, the bounded-retry acquisition loop, the temp+`mv`
write. A fix applied to one copy and not the other is divergence at the exact
surface this change exists to un-diverge — the same shape as core#41, one
directory over.

**Rejected — an inline block in `install.sh`, matching `claude-workflow`.** It
is what the sibling does, and fleet-uniform source has real value. But
`claude-workflow` inlines because it has no separate installer; copying its shape
here would drop the `mkdir` lock and the atomic write that migration 0014
deliberately built, reintroducing a non-atomic check-then-write for this
artifact. Uniformity of *behaviour* (refuse-downgrade on the marker) is the
property core#42 asks for; uniformity of file layout is not.

**Rejected — renaming to `install-shared.sh`.** More honest about what the script
now does, but it breaks the path `test_migration_0014` pins, `install.sh`, and
the operator command recorded in `session-handoff.md`, forcing either a compat
shim or a doc/test sweep into a diff that is otherwise additive. The narrower
name is the cheaper wrong thing.

## Decision 2 — The producer resolves marker-first, and the marker is not a signature

`skills/codex-openspec-change-review/SKILL.md` resolves the shared copy first,
then the repo copy. `opencode-workflow` still ships an unmarked 9/14 wrapper and
does not arbitrate, so that path can still be clobbered by a host that has not
adopted. The producer therefore prefers the shared copy **only when it carries a
well-formed `# reviewer-cli-version:`**, mirroring what the gate's local surfaces
already do with `# gate-version:`.

**Well-formed, not merely present.** Round 1 review (`gemini`) found the
asymmetry: the installer treats a malformed marker as `0.0.0` and overwrites it,
while a presence-only producer check would trust and execute the same file. Both
now mean the same thing by "marker" — exactly three dot-separated integers.

**A marker is a plain comment.** Anything that can write the file can write the
marker. Applied in the producer, this check discriminates a canonical copy from
a pre-canonical one and does nothing else — not integrity, not a signature.

The denial is **scoped to that check**, which round 1 (`opencode`) correctly
objected to as too broad in the first draft. The installer uses the same marker
for *comparison*, which is a weak form of version provenance, and it has a real
residual: a host that publishes a lying `9.9.9` makes this repo refuse to
"downgrade" to its own canonical copy. Arbitration defends against a stale
honest host — the failure core#41 actually observed — and not against a
dishonest one. That is now written into the spec rather than left implied, as
ADR-0012 and `SECURITY.md` already do for the gate.

**Rejected — leaving resolution unconditional.** It is smaller and becomes
correct once every host arbitrates. But "once every host adopts" is a state we
do not control and cannot date, and the failure it permits is silent: the
producer runs a degraded wrapper, one arm reports unavailable, and the change
proceeds with one fewer opinion. That is precisely core#41 recurring through a
different door.

**Rejected — preferring the repo copy unconditionally.** It closes the hazard,
but it also defeats the point of a shared path: one machine-wide upgrade should
reach every repo. It would also diverge from the gate's resolution order for no
reason the artifacts differ on.

## Decision 3 — One core commit for all four vendored files

`tools/core-vendor.manifest` names a single `core_commit`. Adding two files from
`60cd83f` while the gate's two were vendored at `750da2e` would force a choice:
weaken the manifest to per-file commits, or advance the shared commit and
re-verify the gate at it.

Advanced, and re-verified: at `60cd83f` the gate is `1105607…` and its harness
`b3c2f6b…`, identical to the recorded values, because core#42 touched neither.
The manifest's own comment — resolve the commit ONCE and vendor every file from
that one revision — is the rule that caught a gate/harness mismatch on
2026-07-25, and it survives this change intact.

**Rejected — per-file `core_commit`.** It satisfies "each file records a commit"
while permitting exactly the stale-harness pairing the same-commit rule exists to
prevent. The `change-gate` spec already argues this; adopting a second artifact
is not a reason to unlearn it.

## Decision 4 — `reviewer-cli` is its own capability

The gate consumes evidence; the wrapper produces it. They fail independently, are
vendored from different core artifacts, and have different enforcement surfaces —
the gate runs at three, the wrapper is exercised by one producer and scored by
CI. A separate `openspec/specs/reviewer-cli/spec.md` keeps each capability's
requirements falsifiable on their own.

**The `change-gate` spec is not touched.** The first draft carried a MODIFIED
delta correcting its claim that vendored files record their commit "in a vendor
header" — headers were rejected during 0014 because one breaks the byte-identity
it claims to record, and the manifest sidecar was used instead, but the delta was
archived without the correction.

Both reviewers returned REQUEST-CHANGES on that bundling, and `opencode` supplied
the argument that settled it: the delta was **mis-described**. The scenario it
replaced was unreachable — no header ever shipped, so header-divergence could
never fire — and its replacement is reachable, enforced by a migration assertion.
Moving an invariant from an unenforced surface to an enforced one is a
behavioural change to the *gate*, and it should be proposed, reviewed and
justified as one. My original justification ("this change extends that manifest")
was a coupling argument, not a necessity argument: the `reviewer-cli` capability
states the manifest and one-commit rules for its own files without reference to
the gate's spec.

Deferred to its own change, recorded in `migrations/0015` follow-ups. The cost is
a second review cycle for a small delta; the cost of the alternative is that the
reviewers of a *producer* adoption must also vet a *consumer* behavioural change,
which is how a diff stops being reviewable.

## Decision 5 — Version bump to 1.2.0 with migration 0015

The gate re-vendor at 1.2.2 took no bump: a vendored dependency moved, the
standard did not. This change is different in kind — downstream projects get a
**new** installed artifact and a **changed** installer behaviour at a shared
path. That is a re-runnable change with an on-disk end state, which is what a
migration records, and it is how 0014 handled the gate adoption.

**Rejected — no bump, matching `claude-workflow`.** Their reasoning is sound for
their repo: 3.0.0 has not reached a consumer, so there is nothing to bump past.
This repo's 1.1.0 has shipped. A project that never re-runs `install.sh` would
have no signal that the shared wrapper's install semantics changed.

## Risks / Trade-offs

- **`install-gate.sh` now has two callers, so a bug in it breaks two artifacts.**
  Accepted: that is the same trade the shared gate itself makes, and the
  alternative is two copies that drift. Mitigated by keeping the gate call site
  byte-identical, so 0014's rows act as regression cover for the refactor.
- **The label is derived by string-stripping**, so a future artifact whose marker
  does not end in `-version` would log its full marker name. Harmless, and
  preferable to a second parameter that can be passed wrongly. Both current
  markers end in `-version`, and core's convention is that they do.
- **The shared path is still writable by a non-arbitrating host.** This change
  cannot fix that from here — it can only stop *this* host from causing it and
  stop this host's producer from trusting the result. `opencode-workflow`'s
  adoption is the remaining hole, and it is named in the migration rather than
  left implicit.

## Open Questions

None blocking. One follow-up, deliberately out of scope: `install-gate.sh`'s
comment justifies its hand-rolled three-field compare by claiming BSD `sort` has
no `-V`. On this machine `/usr/bin/sort` (Apple 2.3) accepts `-V` and orders
correctly, so the stated reason is wrong even though the implementation is fine.
Correcting a comment is not worth widening this diff; noted in the migration's
follow-ups.
