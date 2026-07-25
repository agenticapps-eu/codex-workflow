## ADDED Requirements

### Requirement: The change-gate is vendored from core, not maintained here

`codex-workflow` SHALL ship `bin/openspec-change-gate.sh` as a byte-identical
copy of core's published reference implementation
(`reference-implementations/openspec-change-gate/openspec-change-gate.sh`), and
SHALL NOT modify it. Behaviour changes are made in core with a matching
conformance-harness row and re-vendored.

The conformance harness `tools/change-gate-conformance.sh` SHALL be vendored
alongside it from the same core commit, because a stale harness certifies a
stale gate. Both files SHALL record **the same** core commit in a vendor header —
"each records a commit" is not sufficient, since a gate from one commit and a
harness from another satisfies that reading while violating the rule.

Byte-identity against core is verifiable only where a core checkout exists, so
it is a **conditional** guard, not the primary one. The unconditional guard is
the harness requirement below, which runs everywhere.

#### Scenario: The vendored gate matches core when core is reachable
- **WHEN** a checkout of `agenticapps-workflow-core` resolves, via
  `AGENTICAPPS_CORE_ROOT` or the sibling default path
- **THEN** `bin/openspec-change-gate.sh` and `tools/change-gate-conformance.sh`
  are byte-identical to core's published copies at the commit named in their
  vendor headers

#### Scenario: The identity check reports its own absence
- **WHEN** no core checkout resolves
- **THEN** the check SKIPs and reports that it skipped, naming the path it
  looked for — it never silently passes, because a silent pass is
  indistinguishable from a verified match

#### Scenario: The gate and the harness come from the same commit
- **WHEN** the two vendor headers name different core commits
- **THEN** the check fails, even though each file may be byte-identical to core
  at its own header's commit — a harness from one commit certifying a gate from
  another is precisely the stale-harness failure the same-commit rule exists to
  prevent, and per-file identity alone cannot detect it

### Requirement: Gate conformance is proven by execution, not asserted in prose

The repo SHALL score its vendored gate with the vendored conformance harness in
CI, before that gate's verdict is trusted. **Every row the harness declares SHALL
pass and zero SHALL fail.**

The threshold is the harness's own row count, never a literal number. The harness
grows — this change itself proposes two new rows upstream — and a hardcoded count
would be stale the moment core adds them, while reading as though it still
verified something.

#### Scenario: Conformance runs before enforcement
- **WHEN** the `openspec-gate` workflow runs
- **THEN** `tools/change-gate-conformance.sh bin/openspec-change-gate.sh` executes
  and must pass **before** the step that runs the gate itself

#### Scenario: A drifted gate fails the build
- **WHEN** the vendored gate fails one or more harness rows
- **THEN** CI fails on the conformance step, rather than proceeding to enforce
  with a gate that does not implement §18

#### Scenario: A grown harness raises the bar automatically
- **WHEN** a re-vendored harness declares more rows than the previous one
- **THEN** all of the new rows must pass, with no edit to this repo's assertions

### Requirement: Each enforcement surface resolves a named gate path

Which copy of the gate enforces is not incidental. The repo SHALL pin it per
surface:

- **CI** SHALL use the repo-local `bin/openspec-change-gate.sh` — the copy it
  vendored and just scored. A GitHub Actions runner has no
  `~/.agenticapps/bin/`, and enforcing with an unscored copy would contradict the
  conformance requirement above.
- The **`PreToolUse` hook** and the **git `pre-commit` hook** SHALL prefer
  `$OPENSPEC_CHANGE_GATE`, then the shared `~/.agenticapps/bin/` copy, then
  repo-local — so that a single machine-wide upgrade reaches every repo.

`$OPENSPEC_CHANGE_GATE`, when set, SHALL be used only if it names an executable
file. If it does not, the surface SHALL fall through to the remaining paths and
warn — an override pointing at a typo must not silently disable the surface.

The shared copy SHALL be trusted **only if it carries a well-formed
`# gate-version:` marker**, where *well-formed* means exactly the shape the
installer requirement below defines: three dot-separated integers. The surfaces
and the installer MUST agree on that definition; a marker one accepts and the
other rejects would put the trust decision and the arbitration decision out of
step. If the marker is absent or malformed, the local surfaces SHALL fall back to
the repo-local vendored copy and warn.

This is the transitional defence. Arbitration (below) stops *this* host
downgrading the shared path, but the other three hosts do not arbitrate yet: any
of them can blind-write its copy over ours. Shared-first resolution would then
have our own floors enforcing with a gate we never scored.

**The marker discriminates marked from unmarked — not newer from older.** It is
sufficient against the *pre-adoption* fleet, where every copy is unmarked. It
does not defend against a sibling that has vendored a marker-bearing but older
post-#33 gate and does not yet arbitrate: that copy is trusted. Closing that case
requires the siblings to arbitrate, which is fleet work tracked upstream, not
something this host can do alone.

#### Scenario: An explicit override that resolves is used as-is
- **WHEN** `$OPENSPEC_CHANGE_GATE` names an executable file
- **THEN** the surface uses it without a marker check — the override is the
  operator's deliberate choice, and second-guessing it would make the escape
  hatch unusable for the case it exists for

#### Scenario: An explicit override that does not resolve falls through
- **WHEN** `$OPENSPEC_CHANGE_GATE` is set to a path that is not an executable
  file
- **THEN** the surface warns and continues to the shared and repo-local paths,
  rather than treating the surface as having no gate

#### Scenario: A marker-bearing older copy is trusted, and that is known
- **WHEN** a sibling host that does not arbitrate writes a marker-bearing gate
  older than this host's vendored copy
- **THEN** the local surfaces use it, because the marker check cannot compare
  versions — this is the accepted residual, closed only when every host
  arbitrates

#### Scenario: CI never depends on the shared path
- **WHEN** the workflow runs on a fresh runner with no `~/.agenticapps/bin/`
- **THEN** both the conformance step and the gate step use the repo-local
  vendored copy, and the run does not silently pass for want of a gate

#### Scenario: A machine-wide upgrade reaches the local surfaces
- **WHEN** a marker-bearing gate is installed at the shared path
- **THEN** the `PreToolUse` and `pre-commit` surfaces use it in preference to the
  repo-local copy

#### Scenario: A pre-adoption host's overwrite cannot pull the floors back
- **WHEN** a host that does not yet arbitrate overwrites the shared path with an
  unmarked or malformed-marker copy
- **THEN** the `PreToolUse` and `pre-commit` surfaces ignore it, fall back to the
  repo-local vendored gate, and warn that they did so

#### Scenario: The PreToolUse hook fails open when no gate resolves
- **WHEN** no gate resolves at any of the hook's search paths
- **THEN** the hook allows the edit **and records that it did, naming the paths
  it searched, in its invocation log** — matching the `pre-commit` posture,
  because neither surface may brick a session or a commit on a machine that never
  installed the workflow. CI remains the fail-closed surface
- **AND** the record is mandatory, not best-effort: a surface that silently stops
  enforcing is indistinguishable from one that is enforcing and finding nothing
  wrong, which is how the fleet drift went unnoticed for as long as it did

### Requirement: All three enforcement surfaces use the gate's real modes

The `PreToolUse` hook SHALL use hook mode, the git `pre-commit` hook SHALL invoke
`--pre-commit`, and the CI check SHALL invoke `--ci`. No surface may synthesize a
tool-call payload in order to reach hook mode from a non-hook context, because
enforcement reached that way is not demonstrable by the direct script invocation
§18 requires.

`--ci` SHALL be whole-repo: every active change must validate and carry the
reviewer threshold, regardless of which files a pull request touched.

If the resolved gate is **absent**, the `pre-commit` surface SHALL fail **open**
with a warning on stderr. This is a deliberate, security-relevant exception owned
by this spec and not left to the task list: a commit hook that hard-fails because
tooling is missing trains people to pass `--no-verify`, which disables the floor
permanently. CI is the surface that cannot be bypassed, and it fails closed.

#### Scenario: The pre-commit floor blocks a real commit
- **WHEN** code is staged while an active change lacks the reviewer threshold
- **THEN** `openspec-change-gate.sh --pre-commit` exits `1`, the commit is
  refused, and `HEAD` does not move

#### Scenario: The pre-commit floor fails open when no gate is installed
- **WHEN** no gate resolves at any of the pre-commit surface's three paths
- **THEN** the commit proceeds and a warning naming the path searched is written
  to stderr

#### Scenario: The PreToolUse hook blocks a code edit in hook mode
- **WHEN** the codex wrapper receives an `apply_patch` payload targeting a code
  file while an active change lacks the reviewer threshold
- **THEN** it translates the path into the shape the gate parses, the gate exits
  `2`, and the wrapper emits valid `permissionDecision: deny` JSON

#### Scenario: The CI floor blocks an unreviewed change
- **WHEN** an active change lacks the reviewer threshold
- **THEN** `openspec-change-gate.sh --ci` exits `1`, even if the pull request
  changed no code

#### Scenario: An unrelated unreviewed change blocks a satisfied one
- **WHEN** two changes are active, one fully reviewed and one not, and a pull
  request touches only files belonging to the reviewed one
- **THEN** `--ci` still exits `1`, because the mode is whole-repo — this is the
  behavioural difference from the diff-scoped driver it replaces

#### Scenario: Authoring the change is never blocked at the edit surfaces
- **WHEN** only files under this repo's `openspec/` slot are edited or staged
- **THEN** the `PreToolUse` and `pre-commit` surfaces allow the write, so a
  proposal can always be authored and its reviews recorded
- **AND** `--ci` may still report *any* active change as unsatisfied, including
  an unrelated one, because CI gates whether the repository is *ready to merge*,
  not whether a change may be *written*

### Requirement: The installer cannot downgrade the shared gate

Every AgenticApps host installs to the same
`~/.agenticapps/bin/openspec-change-gate.sh`. `install.sh` SHALL read the
`# gate-version:` marker from both the incoming and the installed file and SHALL
**refuse to write when the installed version is strictly greater than the
incoming version.** Equal versions SHALL install, refreshing the file. On a
refusal it SHALL print both versions, the reason, and the exact command to force
the write.

A marker that is absent, or that is not exactly three dot-separated integers,
SHALL be treated as `0.0.0` — **on both sides of the comparison.** Every
pre-adoption copy is unmarked, so first adoption always proceeds; a malformed or
pre-release marker is treated as oldest rather than compared with a rule the
comparison does not implement. Symmetrically, an *incoming* file with a corrupt
header is `0.0.0` and so is refused against any real installed version, which is
the safe direction: a gate whose own provenance cannot be read should not
displace one whose can.

The write SHALL be atomic — a temporary file in the destination directory
followed by `mv` — and the read-compare-write sequence SHALL be serialised by a
lock. Check-then-write is not atomic: two hosts installing concurrently can both
read the pre-existing version and the later writer can land an older gate,
breaking the invariant precisely when arbitration matters most.

The lock model SHALL be **bounded retry**: the installer retries acquisition for
a declared maximum wait, reclaiming with a warning any lock older than a declared
staleness threshold, and exiting non-zero if it can neither acquire nor reclaim
within that window. Both the max-wait and the staleness threshold SHALL be stated
in the installer rather than left implicit.

Naming the model matters because the two scenarios below describe different
outcomes, and under an unbounded retry loop the second is unreachable while under
single-attempt fail-fast the first is fiction. Bounded retry makes both reachable:
the common case acquires and serialises, and a lock held longer than the max-wait
but younger than the staleness threshold is the genuine give-up case.

The installer SHALL NOT proceed unlocked and SHALL NOT silently skip the gate
install — a skipped install is indistinguishable from a successful one to the
operator, and leaves them believing a gate was arbitrated when none was.

The installer SHALL create the destination directory when it does not exist: on a
fresh machine there is no `~/.agenticapps/bin/` at all, and the atomic
temp-file-then-`mv` write requires the directory to be present.

The installer SHALL support `--dry-run`, reporting the decision it would take
without writing. Arbitration that cannot be inspected before it runs is
arbitration an operator has to discover by consequence.

#### Scenario: An older gate does not replace a newer one
- **WHEN** the installed `# gate-version:` is strictly greater than the incoming
  one
- **THEN** the shared file is left byte-for-byte unchanged, and the installer
  prints both versions, the reason it declined, and the command to force it

#### Scenario: A newer gate installs
- **WHEN** the incoming `# gate-version:` is strictly greater than the installed
  one
- **THEN** the shared file is replaced with the incoming gate

#### Scenario: An equal version refreshes
- **WHEN** the installed and incoming versions are equal
- **THEN** the file is written, so a corrupted or truncated copy at the same
  version can be repaired by re-running the installer

#### Scenario: First adoption always proceeds
- **WHEN** the installed file carries no `# gate-version:` marker, as every
  pre-adoption copy does
- **THEN** it is treated as `0.0.0` and the vendored gate is installed over it

#### Scenario: A malformed marker is treated as oldest
- **WHEN** the installed file's marker is not three dot-separated integers —
  `1.2`, `1.3.0-rc1`, or empty
- **THEN** it is treated as `0.0.0` and the incoming gate installs

#### Scenario: Concurrent installers cannot interleave into a downgrade
- **WHEN** two hosts' installers run concurrently against the shared path and
  neither reclaims a stale lock
- **THEN** the lock serialises them, each observes the other's completed write,
  and the file that remains is the highest version of the two

#### Scenario: A reclaimed stale lock degrades the guarantee, and says so
- **WHEN** two installers both judge a pre-existing lock stale and both reclaim it
- **THEN** serialisation is lost for that pair and the surviving file is whichever
  completed last, which may be the older version
- **AND** each reclaim is warned about, so the degraded outcome is attributable
  rather than mysterious
- **AND** the file is never torn, because the write is atomic — the failure mode
  is a wrong version, never a corrupt one

The first scenario is the guarantee; the second is the honest limit of it. Stating
only the first would assert an invariant that a path this design accepts can
break.

#### Scenario: An unacquirable lock stops the installer
- **WHEN** the lock is held for longer than the declared max-wait but is younger
  than the staleness threshold, so it can be neither acquired nor reclaimed
- **THEN** the installer reports it and exits non-zero, having written nothing

#### Scenario: A dry run decides without writing
- **WHEN** `install.sh --dry-run` runs
- **THEN** it reports which decision it would take and writes nothing

### Requirement: The reviewer threshold counts independent vendors

`OPENSPEC_GATE_SELF` SHALL be set to `codex` **explicitly by each surface this
repo ships** — the `PreToolUse` wrapper, the git `pre-commit` hook, and the CI
workflow — rather than inherited from the operator's environment. A human running
`git commit` has no such variable set, so an inherited-only binding would leave
the floor counting this host's own reviews while CI did not.

A gate that accepts self-review disagrees with the §02 evidence verifier, which
rejects it.

#### Scenario: Self-review does not reach the threshold at any surface
- **WHEN** `REVIEWS.md` carries `## Reviewer: codex` and one other vendor
- **THEN** the hook, the pre-commit floor, and CI each count one independent
  reviewer and block

#### Scenario: One vendor reviewing twice is one reviewer
- **WHEN** `REVIEWS.md` carries two `## Reviewer: gemini` headings and no others
- **THEN** the count is one and the gate blocks — the threshold is distinct
  vendors, not headings

### Requirement: Regressions the shared harness does not cover stay pinned

Two defects fixed by core's implementation are not covered by its harness. This
repo SHALL assert both directly, so a future re-vendor cannot regress them while
still passing every declared row.

These assertions SHALL run **on every CI run**, not only when a developer invokes
the migration suite by hand. A pin whose execution path is not guaranteed is not a
pin: a regression introduced by a future re-vendor would pass the conformance step
— the harness still reports every declared row green, because neither defect has a
row — and reach `main` unchallenged. `migrations/run-tests.sh` already runs on
every push and pull request across a two-OS matrix (`.github/workflows/ci.yml`),
which satisfies this; the requirement exists so that a later change cannot quietly
remove that coupling.

#### Scenario: The gate resolves the repository root, not the working directory
- **WHEN** a code edit is evaluated from a subdirectory of the repository while an
  active change is unsatisfied
- **THEN** the gate blocks, exactly as it does from the repository root

#### Scenario: Unparseable stdin fails open, never onto policy
- **WHEN** stdin carries whitespace-containing non-JSON such as `not json at all`
- **THEN** the gate exits `0`, because failing open is required on a parse error
  and forbidden on policy

#### Scenario: The pins run wherever the suite runs
- **WHEN** a pull request is opened or a commit is pushed
- **THEN** the migration suite carrying both assertions executes, so a re-vendored
  gate that regressed either defect fails the build rather than merging green
