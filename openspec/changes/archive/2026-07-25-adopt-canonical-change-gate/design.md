## Context

The §18 change-gate is one shared shell script installed by four host repos
(`claude-`, `codex-`, `opencode-`, `pi-agentic-apps-workflow`) to a single path,
`~/.agenticapps/bin/openspec-change-gate.sh`. It was never published from core:
`gate/` was untracked and absent from `origin/main`, so each host copied it from
a local unpublished directory. By 2026-07-25 there were **five divergent copies**
and none was conformant.

`codex-workflow` recorded its exposure honestly rather than patching — see
`docs/GATE-KNOWN-GAPS.md` and commit `54a2b37`, which pinned the gate's sha256 so
that re-syncing would turn the suite red and force re-verification. That pin has
now done its job.

Core resolved the fork in #33 / ADR-0022 by publishing
`reference-implementations/openspec-change-gate/` plus
`tools/change-gate-conformance.sh`, a 28-row executable harness. Core's
implementation is composed from `pi-193` and `claude-184`'s reviewer counter —
deliberately *not* from this repo's 164-line variant, because adopting ours
wholesale would have deleted both enforcement floors in core.

Measured on this branch, 2026-07-25:

| copy | harness score |
|---|---|
| `codex-workflow/bin/openspec-change-gate.sh` | 16 / 28 |
| core reference implementation | 28 / 28 |

## Goals / Non-Goals

**Goals:**

- Stop maintaining a gate implementation in this repo. Vendor core's.
- Make conformance *executable and continuously checked*, not asserted in prose.
- Make all three enforcement surfaces (PreToolUse hook, git pre-commit, CI) use
  the gate's real mode dispatch, so what §18 requires to be demonstrable actually
  is.
- Make the installer incapable of downgrading the shared gate.
- Preserve the two regression reproductions the harness does not cover.

**Non-Goals:**

- Improving the gate's *behaviour*. If we want different behaviour, it changes in
  core with a matching harness row, then we re-vendor. Not here.
- Reconciling `bin/reviewer-cli.sh`, which is separate fleet drift (this repo
  ships a superset with `claude`/`opencode` arms). Tracked in the handoff's open
  questions; out of scope.
- Touching the `PreToolUse` wrapper's `apply_patch` translation. Still required,
  still load-bearing, unchanged.
- Finishing phase 13, whose subject (the plan-review native hook) migration 0013
  already superseded.

## Decisions

### D1 — Vendor verbatim; never hand-patch

`bin/openspec-change-gate.sh` and `tools/change-gate-conformance.sh` are copied
byte-identical from core and carry a vendor header naming the source commit. The
migration test asserts byte-identity against core's published copy **when a core
checkout resolves**, and always asserts every harness row passes.

The `opencode` review was right that this makes the identity leg conditional, and
that the first draft's scenario ("a host-local edit to the gate is caught")
over-promised: on a CI runner with no core checkout, that `THEN` never executes.
Two consequences, both now explicit in the spec delta:

- The identity check **reports its own skip**, naming the path it searched. A
  silent pass and a verified match must not look alike — that ambiguity is a
  smaller version of the same problem this whole change addresses.
- The **unconditional** guard is the harness, which runs everywhere. It does not
  prove the file came from core, but it proves the file behaves as §18 requires,
  which is the property that actually matters at enforcement time.

A third leg was added after the second review round: **the two vendor headers must
name the same core commit.** Per-file byte-identity is individually satisfiable by
a gate from commit A and a harness from commit B, and that combination is exactly
the stale-harness-certifies-a-stale-gate failure the same-commit rule exists to
prevent. Identity against core cannot detect it; comparing the two headers to each
other can, and costs nothing.

This is weaker than the sha256 pin it replaces in exactly one respect, and the
review named it: the pin was an integrity check that needed nothing but the file
itself. The trade is deliberate — that pin also had to be hand-edited on every
legitimate re-vendor, which is friction on the *correct* action, and friction
there is what kept this repo on a defective gate for as long as it did.

*Rationale:* five copies diverged precisely because each host fixed its own. The
README states the rule directly — "a host-local fix is how the copies diverged in
the first place". A local patch here would make it six.

**Rejected — patch our 164-line copy to close the 12 failing rows.** It would be
faster and would preserve our diff-scoped CI. It also reproduces the exact failure
mode this change exists to end, and would strand us again the next time core moves.

**Rejected — symlink to core rather than vendor.** Removes copy drift entirely,
but requires every consumer machine to have a core checkout at a predictable path.
`install.sh` must work on a machine that has only this repo. Vendoring plus a
byte-identity assertion gets the same guarantee without the dependency.

### D2 — Adopt core's whole-repo `--ci`, dropping our diff-scoped driver

`bin/openspec-gate-ci.sh` stops looping over changed files and becomes a thin
wrapper: score the gate with the harness, then `exec "$GATE" --ci`.

*Consequence, accepted:* a PR that touches only docs now fails CI while any active
change lacks two reviewers, and a proposal-only PR is red until `REVIEWS.md`
lands. This is stricter than what we had.

*Rationale:* it matches §18's wording — every active change must validate and
carry ≥2 reviewers before code merges — and our own lifecycle gets reviews before
code, so the red window is the window in which the change genuinely is not ready.
Keeping a bespoke mode is divergence at exactly the surface this change exists to
un-diverge.

**Rejected — keep diff-scoping and upstream a `--ci-diff` mode.** Preserves
today's ergonomics, but leaves the harness's section-C CI row unattested for this
host and re-forks the script pending an upstream feature that may never land.

We keep the `bin/openspec-gate-ci.sh` *entry point* rather than calling the gate
directly from the workflow, because `migrations/run-tests.sh` and migration 0013
both assert that path exists, and the setup skill installs it into scaffolded
projects. Deleting the filename would break those for no benefit.

### D3 — Pin GAP-1 and GAP-4 locally, and file them upstream

Neither gap is covered by the 28 rows. Both are fixed in core's implementation —
verified directly, both copies, 2026-07-25. Left unpinned, a future re-vendor
could silently regress them and the harness would still read 28/28.

They become hard assertions in `test_migration_0014`, phrased as regressions
rather than as known gaps:

```
GAP-1  code edit from $ROOT/sub/dir   -> exit 2   (was 0 before adoption)
GAP-4  'not json at all' on stdin     -> exit 0   (was 2 before adoption)
```

An issue is filed on core proposing the two rows for the shared harness, so the
other three hosts get the coverage too.

**Rejected — rely on the 28-row score alone.** The gaps we can currently measure
would go unmeasured the moment core's harness is the only check, which is how the
fleet drift went unnoticed for as long as it did.

### D4 — Delete `docs/GATE-KNOWN-GAPS.md`; history moves to the ADR

The file's own closing section, step 4, says to delete it once the gaps are
converted to hard assertions. `test_gate_known_gaps` — the sha256 pin and four
`KNOWN-GAP` reports — is replaced by `test_migration_0014`.

This repo's convention is *supersede, never delete*, but that convention names
migrations and ADRs, which stay as provenance. A status document whose title
claims open gaps that no longer exist is actively misleading. Its content — the
four gaps it records (GAP-1..GAP-4), their reproductions, the two further defects
core's harness surfaced, and the five-copy root cause — is preserved in
ADR-0012's Context.

**Rejected — retain it with `Status: closed`.** Maximally conservative, but leaves
a reader diffing a stale doc against the ADR to work out which of the two is true.

### D5 — Installer arbitration by `# gate-version:`, atomic and locked

`install.sh` reads the marker from the incoming file and from any file already at
`$AA_BIN/openspec-change-gate.sh` and **refuses to write when the installed
version is strictly greater than the incoming one**, printing both versions, the
reason, and the exact command to force it. Equal versions install, so a truncated
copy at the same version is repairable by re-running the installer.

An absent marker, or one that is not exactly three dot-separated integers, is
treated as `0.0.0`. Every pre-#33 copy is unmarked, so first adoption always
proceeds. Treating `1.2` and `1.3.0-rc1` as oldest is deliberate: the comparison
below is a three-field numeric sort, not a semver implementation, and it should
degrade to "install" rather than silently mis-order a shape it cannot parse.

Comparison is pure shell (`sort -t. -k1,1n -k2,2n -k3,3n`), consistent with the
portable-sort discipline `test_drift` already uses — BSD `sort` on the macOS leg
of the CI matrix has no version-sort flag.

**Check-then-write is not atomic**, and both reviewers flagged the consequence:
two hosts installing concurrently can each read the pre-existing version, and the
later writer can land the older gate — breaking the invariant exactly when
arbitration matters. So the sequence is serialised by a `mkdir`-based lock
(atomic on POSIX, and unlike `flock` present on macOS), and the write itself is a
temp file in the destination directory followed by `mv`. The lock is released on
exit via a trap, and a stale lock older than a threshold is reclaimed with a
warning rather than deadlocking the installer.

*Rationale:* this is the hazard issue #26 was filed about. Core's README makes it
a MUST for every host.

**Correction, from the second review round.** The first draft called this "the
only defence that works when the operator runs another host's installer
afterwards." That is true only once *every* host arbitrates. Today none of the
other three do, so any of them can blind-write its unmarked pre-#33 copy over
ours — and D7's shared-first resolution would then have our own floors enforcing
with the defective gate. Arbitration protects the path from *us*; it does not
protect us from *them*. The marker-validation rule in D7 is what closes the
transitional window.

### D6 — `OPENSPEC_GATE_SELF=codex`, set explicitly by every surface

Set by the `PreToolUse` wrapper before it execs the gate, **set by the git
`pre-commit` hook**, and set in the CI workflow's env. Not inherited.

The first draft had the pre-commit floor inherit it from the environment,
matching core's default. Both reviewers rejected that independently: a human
running `git commit` has no such variable, so the floor would count
`## Reviewer: codex` toward the threshold while CI did not. An enforcement rule
that holds in CI but not on the developer's machine is exactly the unpredictable
behaviour this change exists to remove.

Setting it in our own wrapper scripts does not violate D1 — those are host-owned
adapters, not the vendored gate.

*Rationale:* without it the gate accepts two `## Reviewer: codex` headings that
the §02 evidence verifier rejects. A gate that disagrees with its own verifier is
the ADR-0018 drift pattern reappearing inside the tooling.

### D7 — Each surface resolves a named gate path

CI uses the **repo-local** vendored gate. The `PreToolUse` and `pre-commit`
surfaces prefer `$OPENSPEC_CHANGE_GATE`, then the **shared** copy, then
repo-local.

*Rationale:* raised by the `opencode` review, and it is a real hole. A GitHub
Actions runner has no `~/.agenticapps/bin/`, so a shared-first CI would either
fail open on every fresh runner or — worse, once the shared path existed —
enforce with a copy CI never scored, contradicting D1's conformance guarantee. CI
must score and then enforce with *the same file*.

The local surfaces keep shared-first for the opposite reason: one machine-wide
upgrade should reach every repo on the machine without re-vendoring each one.
That is the whole point of the shared path.

**But shared-first is only safe if the shared copy is trustworthy**, and during
the fleet transition it may not be — see the correction in D5. So the local
surfaces trust the shared copy **only when it carries a well-formed
`# gate-version:` marker**, and otherwise fall back to repo-local with a warning.

The marker is a clean discriminator for exactly this window: every post-#33
conformant gate carries one, and every pre-adoption copy — the thing we are
defending against — lacks one. It is not a signature and does not prove
conformance; a malicious or hand-edited file could carry a marker. It is
proportionate to the actual threat, which is an out-of-date sibling installer,
not an attacker.

The scenario wording was corrected too: it now reads "a **marker-bearing** gate",
not "a newer **conformant** gate". The surfaces check the marker; they do not run
the harness. Claiming otherwise would describe a verification that does not
happen — the same class of error as a silent skip reading like a pass.

### D8 — The bar is the harness's row count, not a number

The first draft wrote "28/28" into the spec and the tasks. The `opencode` review
pointed out this change *itself* proposes two new upstream rows (D3), so the
constant would be stale on arrival and would read as verification while
verifying less than the harness offers. The requirement is now "every declared
row passes, zero fail" — a re-vendored harness with more rows raises the bar with
no edit here.

### Dropped for minimality

Both reviewers flagged the `actions/setup-node` v4 → v7 bump in the first draft
of task 2.5 as opportunistic scope, and they were right — no requirement pins it
and it has nothing to do with the gate. It is removed from this change.

For the record, `opencode` also doubted v7 exists. It does: core's live
workflows use `actions/setup-node@v7` and `actions/checkout@v7`, and core#31
bumped them deliberately. The bump is dropped on minimality grounds, not because
the reviewer's factual doubt was correct — a later reader should not re-litigate
it as a bug.

## Risks / Trade-offs

**The `--ci` semantics change can surprise.** A docs-only PR failing because an
unrelated change is unreviewed reads as a broken build until you know the rule.
Mitigated by the gate's own log line naming the change and its reviewer count, and
by documenting the change in `CHANGELOG.md` and `docs/WORKFLOW.md`.

**Vendoring is a snapshot, and snapshots go stale.** A conformant copy today is a
stale copy in three months. Mitigated by the CI harness step: when core bumps the
gate and adds rows, re-vendoring is a copy plus a green suite, and the byte-identity
assertion tells us we have drifted whenever a core checkout is present.

**`install.sh` refusing to write is a new failure mode.** An operator who
*intends* to roll back will find the installer silently declining. Mitigated by
printing the two versions and the exact `install -m 0755 …` command to force it.

**We are trading a known-good mechanism for an attested one.** Our current floors
do enforce — the handoff records two real commit refusals. Rewiring them to
`--pre-commit`/`--ci` briefly puts working enforcement at risk for the sake of
conformance. Mitigated by TDD: every floor task writes a failing assertion first,
and the live `git commit` refusal is re-demonstrated before the change is archived.

**The harness itself is vendored and could go stale independently.** A stale
harness certifies a stale gate — core's README warns about exactly this. The
migration test asserts both files come from the same core commit when a checkout
is available. In the no-checkout path this is unguarded, and the GAP-1/GAP-4 pins
of D3 exist partly because of it: they are assertions this repo owns outright,
independent of both core's availability and core's harness.

**Integrity verification is weaker without the sha256 pin, in the no-checkout
case.** Named by the `opencode` review and accepted; see D1 for the trade and why
it is worth making.

**The installer lock is a new way to fail.** A crashed installer could leave a
stale lock directory. Mitigated by reclaiming a lock older than a threshold with a
warning rather than deadlocking, and by the trap that releases it on normal exit.
A lock that cannot be acquired must never make the installer silently skip the
gate install — it reports and exits non-zero. Two installers both judging the same
lock stale and both reclaiming it is a residual race, accepted: the window is
narrow, the atomic `mv` means the loser's write is still a complete file, and the
worst outcome is the arbitration being decided by whichever completed last —
which is the pre-change behaviour, not worse than it.

**The fleet transition leaves a real residual, now defended but not eliminated.**
Until the other three hosts arbitrate, any of them can overwrite the shared path.
D7's marker check keeps *our* floors off a defective gate, but it cannot stop that
host's own floors — or any other repo on the machine resolving the shared path —
from using it. Fully closing this needs all four hosts adopted; issue #26 and
core's fleet tracker (core#34) are where that is sequenced. Naming it here so the
next reader does not mistake the marker check for a complete fix.

**The force-install path is documented but unpinned.** The spec requires the
refusal message to print the force command; no scenario proves that command
actually lands the file, because it is an operator action outside the installer's
own control flow. Accepted, and named rather than left implicit.
