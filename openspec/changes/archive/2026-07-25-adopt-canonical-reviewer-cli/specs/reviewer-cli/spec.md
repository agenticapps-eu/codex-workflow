## ADDED Requirements

### Requirement: The review wrapper is vendored from core, not maintained here

`codex-workflow` SHALL ship `bin/reviewer-cli.sh` as a byte-identical copy of
core's published reference implementation
(`reference-implementations/reviewer-cli/reviewer-cli.sh`), and SHALL NOT modify
it. Behaviour changes are made in core with a matching conformance-harness row
and re-vendored.

This binds the wrapper's completeness as well as its text: **every** vendor arm
ships here, including `codex`, this host's own. The wrapper is installed at one
path shared by every host, so dropping an arm because "this host would never use
it" breaks the sibling that calls it. Vendor exclusion is the producer's job, and
that separation is the direct cause of core#41.

The conformance harness `tools/reviewer-cli-conformance.sh` SHALL be vendored
alongside it, because a stale harness certifies a stale wrapper. Provenance for
both SHALL be recorded in `tools/core-vendor.manifest`, never in a header inside
the files themselves — a vendor header would break the byte-identity it claimed
to record.

The manifest SHALL name **one** core commit covering every file it lists.
"Each file records a commit" is not sufficient: a wrapper from one commit and a
harness from another satisfies that reading while violating the rule.

#### Scenario: The vendored wrapper matches core when core is reachable
- **WHEN** a checkout of `agenticapps-workflow-core` resolves, via
  `AGENTICAPPS_CORE_ROOT` or the sibling default path
- **THEN** `bin/reviewer-cli.sh` and `tools/reviewer-cli-conformance.sh` are
  byte-identical to core's published copies at the commit named in
  `tools/core-vendor.manifest`

#### Scenario: The identity check reports its own absence
- **WHEN** no core checkout resolves
- **THEN** the check SKIPs and reports that it skipped, naming the path it looked
  for — it never silently passes, because a silent pass is indistinguishable
  from a verified match

#### Scenario: Every vendored file is listed, and all come from one commit
- **WHEN** `tools/core-vendor.manifest` is read
- **THEN** it names exactly one `core_commit`; it lists **every** file this repo
  vendors from core, the wrapper and its harness among them; and each listed
  file verifies against that one revision. Consistency among the entries is not
  sufficient on its own — a manifest that omits a vendored file is internally
  consistent while recording nothing about the file it omits

### Requirement: Wrapper conformance is proven by execution, not asserted in prose

The repo SHALL score its vendored wrapper with the vendored conformance harness
in CI. **Every row the harness declares SHALL pass and zero SHALL fail.**

The threshold is the harness's own row count, never a literal number. The harness
grows as core adds rows, and a hardcoded count would be stale the moment it does
while reading as though it still verified something.

The scoring step SHALL run before the step that runs the change gate. A drifted
*consumer* fails loudly; a drifted *producer* reports clean while degrading the
evidence the consumer then accepts.

#### Scenario: Conformance runs before enforcement
- **WHEN** the `openspec-gate` workflow runs
- **THEN** `tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh` executes and
  must pass **before** the step that runs the gate itself

#### Scenario: A drifted wrapper fails the build
- **WHEN** `bin/reviewer-cli.sh` fails any row the harness declares
- **THEN** the workflow fails, whatever the gate would have said about the
  repo's active changes

#### Scenario: A grown harness raises the bar automatically
- **WHEN** a re-vendored harness declares more rows than the previous one
- **THEN** every new row must pass, with no edit to this repo's assertions —
  because the assertion is "zero failures", not a count this repo maintains

### Requirement: Every writer of the shared wrapper path arbitrates on its version

`~/.agenticapps/bin/reviewer-cli.sh` is written by the claude, codex, opencode
and pi installers alike. Every surface in this repo that writes it SHALL compare
the incoming `# reviewer-cli-version:` marker against the installed one and
SHALL refuse to overwrite a higher version. A marker that is absent, or is not
exactly three dot-separated integers, SHALL be treated as `0.0.0` on **both**
sides.

Refusing a downgrade is a decision, not a failure: the installer SHALL report it
and exit successfully, naming both versions and the command that would force the
rollback deliberately.

The read-compare-write sequence SHALL be serialised and the write SHALL be
atomic, because check-then-write across two concurrent installers can otherwise
land the older copy — the failure exactly when arbitration matters.

This repo SHALL NOT write that path with an unarbitrated `install`.

**Known residual, stated rather than implied.** Arbitration reads a marker that
anything able to write the file can also write. A host that publishes a *lying*
higher marker defeats it: this repo will then refuse to "downgrade" to its own
canonical copy and the degraded wrapper survives. The comparison is therefore a
weak form of version provenance, not an integrity control — it defends against
a stale honest host, which is the failure core#41 actually observed, and not
against a dishonest one. The `change-gate` capability carries the same residual
for the same reason.

#### Scenario: A newer installed wrapper is not overwritten
- **WHEN** the installed wrapper's marker is higher than the incoming one
- **THEN** the installer refuses, leaves the file byte-identical, reports both
  versions, and exits 0

#### Scenario: An unmarked installed wrapper is upgraded
- **WHEN** the installed wrapper carries no marker, or a malformed one
- **THEN** it is treated as `0.0.0` and the incoming canonical copy is installed

#### Scenario: An unreadable incoming marker is refused, not trusted
- **WHEN** the **incoming** wrapper's own marker is absent or malformed, and the
  installed one carries a real version
- **THEN** the install is refused — the `0.0.0` rule applies to both sides, so a
  copy whose provenance cannot be read never displaces one whose can

#### Scenario: The same arbitration covers the gate and the wrapper
- **WHEN** either shared artifact is installed
- **THEN** the same implementation performs the parse, the comparison, the
  refusal, the lock and the atomic write — the two SHALL NOT have separate
  copies of that logic, and the artifact under arbitration is selected by the
  marker name passed to it

### Requirement: The producer never resolves an unmarked shared wrapper

The review producer resolves the shared wrapper before the repo-local one, so
one machine-wide upgrade reaches every repo. It SHALL accept the shared copy
**only when that copy carries a well-formed `# reviewer-cli-version:` marker**,
and SHALL otherwise fall back to `bin/reviewer-cli.sh`.

"Well-formed" means the same thing here as it does to the installer: exactly
three dot-separated integers. A presence-only check would be weaker than the
arbitration it is meant to complement — a malformed marker such as `1.2.a` is
`0.0.0` to the installer, which would overwrite it, while a presence-only
producer would trust and execute it. The two checks SHALL agree on what counts
as a marker.

**This check discriminates, it does not verify.** A marker is a plain comment
and anything that can write the file can write it. Applied here, the check
separates a canonical copy from a pre-canonical one and nothing more; it SHALL
NOT be described, in the skill or elsewhere, as integrity or a signature. The
denial is scoped to *this* check: the installer's use of the same marker for
version comparison is a weak form of version provenance, and its residual is
stated in the arbitration requirement above.

#### Scenario: An unmarked shared copy is bypassed
- **WHEN** `~/.agenticapps/bin/reviewer-cli.sh` exists without a version marker,
  because a host that has not yet adopted wrote it
- **THEN** the producer uses the repo-local `bin/reviewer-cli.sh` instead

#### Scenario: A malformed marker is treated as no marker
- **WHEN** the shared copy carries a marker that is not exactly three
  dot-separated integers — `1.2`, `1.2.a`, `1.3.0-rc1`
- **THEN** the producer falls back to the repo-local copy, matching the
  installer's rule that an unparseable marker is `0.0.0` rather than a version

#### Scenario: A marked shared copy is preferred
- **WHEN** the shared copy carries a well-formed version marker
- **THEN** the producer uses it, so a single machine-wide install reaches every
  repo on the machine

#### Scenario: A marked-but-older shared copy is trusted, and that is known
- **WHEN** the shared copy carries a well-formed marker naming a version older
  than the repo-local copy's
- **THEN** the producer still uses it — the check does not compare versions,
  only well-formedness. This residual is closed by every host re-vendoring, not
  by the producer, and is recorded here so a reader of this capability alone
  cannot mistake the check for a version guard

