## 1. Vendor the instrument first, observe RED, then vendor the wrapper

The harness is the *test tool*, not the thing under test, so it lands first —
then RED is measured against this repo's still-unmarked wrapper, and vendoring
the canonical is the GREEN. Vendoring both in one step would produce a row that
has never been observed failing, which is not a RED.

The expected RED here is **narrow and known**: this repo's copy is behaviourally
the superset and fails exactly one row (the version marker). A one-row RED is
still a RED — but the task notes must record the observed number rather than
assert it in advance, because the harness's row count is core's to change.

Round 1 review (`opencode`) rejected the first ordering: byte-identity and
manifest assertions were sequenced *after* the vendoring they cover, so they
would have passed on first authoring — post-hoc regression tests wearing a
`tdd="true"` tag. Every row below that carries the tag now has a reachable RED
in the documented sequence, and says what failure to observe.

- [x] 1.1 Vendor `tools/reviewer-cli-conformance.sh` byte-identical from core
      `60cd83f`. No edits, no header. This is the instrument.
- [x] 1.2 `tdd="true"` — RED: add `test_migration_0015` asserting the harness
      reports **zero failing rows** against `bin/reviewer-cli.sh`. Run it and
      record the observed failure in the task notes (expected: 1 failing of 14,
      the missing `# reviewer-cli-version:` marker).
- [x] 1.3 `tdd="true"` — RED: assert `bin/reviewer-cli.sh` carries a
      `# reviewer-cli-version: N.N.N` marker. This runs unconditionally, needs no
      core checkout, and is the single row that names the core#41 hazard directly.
      Observe it fail.
- [x] 1.4 `tdd="true"` — RED: add the conditional byte-identity assertion for
      **both** new files against a core checkout resolved via
      `AGENTICAPPS_CORE_ROOT` or the sibling default; SKIP **with a reported
      reason and the path searched** when none resolves, and assert the skip is
      visible rather than silent. Authored here, before the vendoring, it fails
      against the current 4-arm superset — observe that, not the SKIP branch.
- [x] 1.5 `tdd="true"` — RED: assert `tools/core-vendor.manifest` **lists all
      four files this repo vendors from core** — `bin/openspec-change-gate.sh`,
      `tools/change-gate-conformance.sh`, `bin/reviewer-cli.sh`,
      `tools/reviewer-cli-conformance.sh` — under exactly one `core_commit`, and
      that each verifies against that one revision.

      The coverage clause is stated explicitly because round 2 (`opencode`)
      caught that without it the RED does not fire: against today's manifest
      "exactly one commit, and every listed file verifies at it" is already
      **true** — it lists two files at `750da2e` and both verify. An assertion
      implemented literally from the first wording would have been green at RED
      time, which is the exact post-hoc-regression-wearing-a-`tdd`-tag defect the
      round-1 re-sequencing existed to remove. The failure to observe is
      *coverage*: two of four files missing.
- [x] 1.6 GREEN: vendor `bin/reviewer-cli.sh` byte-identical from core `60cd83f`.
      1.2, 1.3 and 1.4 go green. Do not hand-merge this repo's superset into it —
      the canonical already carries all four arms.
- [x] 1.7 GREEN: update `tools/core-vendor.manifest` — advance `core_commit`
      `750da2e` → `60cd83f` and add both new files. 1.5 goes green.
      **Re-verify the gate and its harness at the new commit before advancing
      it**: the manifest asserts one commit describes every listed file, so an
      unverified bump would make it lie about two files it already covered.

## 2. Teach the installer a second artifact

The gate call site must come out of this byte-identical, so `test_migration_0014`
acts as regression cover for the refactor rather than being rewritten alongside
it. A test edited in the same commit as the code it guards has stopped guarding.

- [x] 2.1 `tdd="true"` — RED: assert `bin/install-gate.sh --marker
      reviewer-cli-version` **refuses** a planted `9.9.9` installed wrapper,
      leaves the destination byte-identical, names both versions, and exits 0.
      Observe it fail — the marker is currently hardcoded to `gate-version`.
- [x] 2.2 `tdd="true"` — RED: assert the same invocation **upgrades** an
      unmarked destination (treated as `0.0.0`) and an older marked one, and
      **refuses** when the *incoming* file's own marker is unreadable while the
      installed one carries a real version — the `0.0.0` rule binds both sides,
      and round 2 noted only the installed side had a scenario. Observe it fail.
- [x] 2.3 **Regression pin — not `tdd="true"`, and deliberately so.** Assert that
      with `--marker` omitted the installer still arbitrates on `gate-version`:
      refuses a planted higher gate, upgrades an unmarked one, and leaves the
      refused destination byte-identical. Round 1 (`opencode`) was right that
      tagging a row `tdd="true"` while conceding it is green at RED time is a
      cargo-culted tag producing no §06 evidence. Round 1 (`gemini`) was right
      that asserting the *call site is unchanged* is too weak — a syntactic check
      cannot see a behavioural break inside the refactored script. So this row
      asserts gate **behaviour through the refactored installer**, is written
      before 2.4, and its only guarantee of validity is the mutation check in
      5.4, which must confirm it fails against a deliberately broken installer.
- [x] 2.4 GREEN: parameterise `bin/install-gate.sh` — `--marker <name>`,
      `gate_version()` → `artifact_version()` taking the marker, and the
      operator-facing label **derived** from the marker by stripping `-version`.
      No `--label` flag: round 1 found a second parameter affecting only log
      wording to be scope, and deriving removes the wrong-label failure mode the
      first draft listed as a risk. Keep the lock at `$DST.lock`, the
      bounded-retry model, the atomic temp+`mv`, and the 0 / 1 / 2 exit split
      exactly as they are. 2.1–2.3 go green.
- [x] 2.5 `tdd="true"` — RED: assert `install.sh` writes the shared wrapper
      **through** `install-gate.sh` and that no unarbitrated
      `install -m 0755 …reviewer-cli.sh` remains anywhere in the repo. Observe it
      fail.
- [x] 2.6 GREEN: rewire the `install.sh` call site with the same three-way `rc`
      handling the gate already has (0 = installed or declined, 2 = contention
      warning, other = loud failure naming the deliberate-force command). Wording
      for the wrapper, not copied verbatim from the gate's.

## 3. Stop the producer trusting an unmarked shared copy

- [x] 3.1 `tdd="true"` — RED: assert
      `skills/codex-openspec-change-review/SKILL.md` resolves the shared wrapper
      only when it carries a **well-formed** `# reviewer-cli-version:` — exactly
      three dot-separated integers — and falls back to the repo copy for an
      absent marker, a malformed one (`1.2`, `1.2.a`, `1.3.0-rc1`), and a missing
      file. Observe it fail.
- [x] 3.2 GREEN: update the skill's resolution snippet to match the installer's
      parse. Round 1 (`gemini`) found the asymmetry: a presence-only check would
      trust a marker the installer would overwrite as `0.0.0`, so the two must
      mean the same thing by "marker". State in the same paragraph that a marker
      is a plain comment — discrimination between canonical and pre-canonical,
      not integrity or a signature — and scope that denial to this check, since
      the installer's comparison is a weak form of version provenance with its
      own stated residual.

## 4. Score the producer in CI before trusting a review

- [x] 4.1 `tdd="true"` — RED: assert `.github/workflows/openspec-gate.yml` runs
      `tools/reviewer-cli-conformance.sh bin/reviewer-cli.sh` **before** the step
      that runs the gate. Observe it fail.
- [x] 4.2 GREEN: add the step, with a comment naming why the order matters — a
      drifted producer reports clean while degrading the evidence the gate then
      accepts. No `env -u OPENSPEC_GATE_SELF` needed: the wrapper never reads it.

## 5. Record the change

- [x] 5.1 Write `migrations/0015-adopt-canonical-reviewer-cli.md` (1.1.0 → 1.2.0)
      and bump `.codex/workflow-version.txt`. Name the remaining hole explicitly:
      `opencode-workflow` still ships an unmarked 9/14 copy and does not
      arbitrate, so the shared path can still be clobbered by a host this repo
      does not control. Record two follow-ups: (a) the `change-gate` spec still
      says "vendor header" where the implementation uses the manifest sidecar —
      dropped from this change on both reviewers' objection, to be proposed on
      its own, and it must be described as what it is (retiring an unreachable
      scenario for an enforced one), not as a textual fix; (b) `install-gate.sh`
      justifies its hand-rolled compare by claiming BSD `sort` lacks `-V`, which
      is false on Apple sort 2.3 — the implementation is fine, the stated reason
      is not.
- [x] 5.2 Write `docs/decisions/0013-vendor-canonical-reviewer-cli.md` — the
      parameterised-installer decision with all three rejected alternatives, the
      marker-is-not-a-signature statement, and the one-commit manifest rule.
- [x] 5.3 Update `CHANGELOG.md` under `## [1.2.0]`, with the before/after harness
      numbers and the `--family` fleet table.
- [x] 5.4 **Mutation-check every new row.** For each assertion added above,
      deliberately break its fixture and confirm the row fails. A row that passes
      against a broken fixture is not a row. Record the mutations tried.
- [x] 5.5 Full evidence pass: `migrations/run-tests.sh` (record PASS/FAIL/SKIP
      before and after), `tools/reviewer-cli-conformance.sh --family` (record the
      fleet table after adoption), `openspec validate --all`, and
      `bin/openspec-change-gate.sh --ci` green.

## 6. Review, secure, ship

- [x] 6.1 `/cso` over the diff → `SECURITY.md`. The change touches an installer
      that writes a path shared by every host on the machine, which is the reason
      this is not conditional-away.
- [x] 6.2 Stage-2 independent code review in a fresh context →
      `CODE-REVIEW.md`. `openspec validate` is a spec check and does not
      discharge it.
- [x] 6.3 Archive the change (fold the `reviewer-cli` delta into
      `openspec/specs/`), then ship the PR as a separate act.
