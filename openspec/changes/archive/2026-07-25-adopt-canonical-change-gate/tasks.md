## 1. Vendor the harness first, then observe RED, then vendor the gate

The ordering matters and the first draft got it wrong: task 1.1 asserted a harness
score while the harness was still vendored by a later task. You cannot observe
16/28 from a harness that does not exist in the tree. The harness is the *test
tool*, not the thing under test, so it lands first — then RED is measured against
the still-defective gate, and vendoring the gate is the GREEN.

- [x] 1.1 Vendor `tools/change-gate-conformance.sh` byte-identical from core
      `ae90483` into a new `tools/` dir, with a vendor header naming the commit.
      No behaviour change — this is the instrument.
- [x] 1.2 `tdd="true"` — RED: add `test_migration_0014` asserting the harness
      reports zero failing rows against `bin/openspec-change-gate.sh`. Run it and
      **record the observed failure** (expected: 12 failing of 28) in the task
      notes. This is a genuine RED against the real pre-adoption gate.
- [x] 1.3 `tdd="true"` — RED: pin GAP-1 (code edit from a subdirectory blocks,
      exit 2) and GAP-4 (`not json at all` fails open, exit 0) as hard
      assertions. Observe both fail against the pre-adoption gate — recorded
      measurements are `0` and `2` respectively, the inverse of correct.
- [x] 1.4 GREEN: vendor `bin/openspec-change-gate.sh` byte-identical from core
      `ae90483`, with the same vendor header. 1.2 and 1.3 go green.
- [x] 1.5 `tdd="true"` — add the conditional byte-identity assertion: compare both
      vendored files against a core checkout resolved via `AGENTICAPPS_CORE_ROOT`
      or the sibling default; SKIP **with a reported reason and the path
      searched** when none resolves. Assert the skip is visible, not silent.
- [x] 1.6 `tdd="true"` — assert the two vendor headers name the **same** core
      commit. This runs unconditionally — it needs no core checkout — and catches
      the gate-from-A + harness-from-B mismatch that per-file identity cannot.

## 2. Rewire the enforcement floors to real mode dispatch

All three pre-commit RED assertions land **before** the single GREEN that
satisfies them. The first draft interleaved them, which produced a RED (absent-gate
fail-open) whose GREEN had already shipped — so it could only pass on first run,
which is not a RED at all.

- [x] 2.1 `tdd="true"` — RED: assert `bin/git-hooks/pre-commit` blocks a staged
      code file under an unsatisfied change **via `--pre-commit`**, that it sets
      `OPENSPEC_GATE_SELF=codex` itself, and that it contains no synthesized
      `tool_input` payload.
- [x] 2.2 `tdd="true"` — RED: assert the absent-gate path fails **open** — exit 0
      with a warning on stderr — per the spec's explicit exception. Note that a
      bare `exec "$GATE" --pre-commit` against a missing path exits non-zero,
      i.e. fails *closed*; the resolve→absent→warn→`exit 0` branch must be
      explicit, not implied by `exec`.
- [x] 2.3 `tdd="true"` — RED: assert the shared copy is ignored in favour of
      repo-local when its `# gate-version:` marker is absent or malformed, and
      that the fallback warns.
- [x] 2.4 GREEN: rewrite `bin/git-hooks/pre-commit` as a thin wrapper satisfying
      2.1–2.3 — resolve (`$OPENSPEC_CHANGE_GATE`, then shared **if
      marker-bearing**, then repo-local), export `OPENSPEC_GATE_SELF=codex`,
      warn-and-`exit 0` if nothing resolved, otherwise `exec "$GATE"
      --pre-commit`. Keep this repo's documented `GSD_SKIP_REVIEWS` note.
- [x] 2.5 `tdd="true"` — RED: assert `bin/openspec-gate-ci.sh` runs the harness
      before the gate, invokes `--ci`, resolves the **repo-local** gate, and no
      longer takes a base-ref argument.
- [x] 2.6 GREEN: rewrite `bin/openspec-gate-ci.sh` accordingly, preserving the
      filename and its no-op-without-a-spec-slot behaviour.
- [x] 2.7 Update `.github/workflows/openspec-gate.yml`: add the conformance step
      before the gate step, drop the `BASE_SHA` plumbing `--ci` no longer needs,
      and set `OPENSPEC_GATE_SELF: codex` in the job env.
- [x] 2.8 `tdd="true"` — RED then GREEN: assert the `PreToolUse` wrapper falls
      back to repo-local when the shared copy has no valid marker, and fails open
      (recording that it did) when no gate resolves at all.
- [x] 2.9 Verify migration 0013 does not break: `run-tests.sh` asserts only that
      `bin/openspec-gate-ci.sh` exists and is executable, never invoking it with a
      base-ref (checked 2026-07-25). Re-confirm after the rewrite and record it.

## 3. Installer arbitration

- [x] 3.1 `tdd="true"` — RED: assert `install.sh` leaves an installed gate
      byte-for-byte unchanged when its `# gate-version:` is strictly greater than
      the incoming one, and that it prints both versions and the force command.
- [x] 3.2 `tdd="true"` — RED: assert the equal-version case installs, and that an
      absent or malformed marker (`1.2`, `1.3.0-rc1`, empty) is treated as
      `0.0.0` and installs.
- [x] 3.3 GREEN: implement the marker read, the portable three-field numeric
      compare (`sort -t. -k1,1n -k2,2n -k3,3n`, no GNU-only version-sort), and
      the refusal message.
- [x] 3.4 `tdd="true"` — RED then GREEN: make the write atomic (temp file in the
      destination dir + `mv`) and serialise read-compare-write with a `mkdir`
      lock, creating `$AA_BIN` when absent. Implement **bounded retry** with a
      declared max-wait and a declared staleness threshold. Assert a lock past the
      staleness threshold is reclaimed with a warning rather than deadlocking, and
      that a lock held past the max-wait but younger than the threshold exits
      non-zero rather than silently skipping the gate install.
- [x] 3.5 `tdd="true"` — assert the fresh-machine bootstrap: no
      `~/.agenticapps/bin/` directory at all, and the install still succeeds.
- [x] 3.6 Verify live against a real `$AA_BIN` copy, and confirm `--dry-run`
      reports the decision without writing.

## 4. Self-review exclusion

- [x] 4.1 Cross-surface regression guard (**not** `tdd`, deliberately): assert all
      three surfaces set `OPENSPEC_GATE_SELF=codex` explicitly. Tasks 2.4 and 2.7
      already make the pre-commit and CI legs green, so labelling this RED-first
      would be a false claim — its value is catching a later regression at any one
      surface, which is worth an assertion but is not test-driving anything.
- [x] 4.2 `tdd="true"` — RED: assert two `## Reviewer: gemini` headings count as
      one independent reviewer and block.
- [x] 4.3 GREEN: export it in
      `skills/agentic-apps-workflow/scripts/hook-wrapper-openspec-gate.sh`,
      leaving its `apply_patch` translation logic untouched. (The pre-commit and
      CI surfaces are covered by 2.4 and 2.7.)
- [x] 4.4 Re-point the wrapper's GAP-1 assertion in `migrations/run-tests.sh`: the
      wrapper must still NOT `cd` to the repo root, but the reason is now "the
      gate owns root resolution", not "the gap is unfixed".

## 5. Retire the known-gaps record

- [x] 5.1 Delete `docs/GATE-KNOWN-GAPS.md` and remove `test_gate_known_gaps` and
      its entry in the test runner's list.
- [x] 5.2 Write `docs/decisions/0012-vendor-canonical-change-gate.md`, carrying
      all six defects from the proposal's accounting table, GAP-1..GAP-4's
      reproductions, and the five-copy root cause into
      Context, and D1–D8 from `design.md` into Decision / Alternatives Rejected.
- [x] 5.3 Remove every remaining `GATE-KNOWN-GAPS.md` reference — including its
      entry in the file-existence list in `migrations/run-tests.sh` (~line 4380),
      which otherwise goes red the moment the file is deleted.

## 6. Migration and documentation

- [x] 6.1 Write `migrations/0014-adopt-canonical-gate.md`, 1.0.0 → 1.1.0, with a
      real Apply block. `run-tests.sh` extracts and executes it — do not
      re-implement the steps inline.
- [x] 6.2 Bump `skills/agentic-apps-workflow/SKILL.md` `version:` and
      `.codex/workflow-version.txt` to 1.1.0 so `test_drift` stays green.
- [x] 6.3 Update `CHANGELOG.md`, `docs/WORKFLOW.md`, and the §18 line in the
      skill's spec-delta section to describe the vendored gate, the whole-repo
      `--ci` semantics, and the per-surface gate-path resolution.

## 7. Verification and review

- [x] 7.1 Full suite green: `bash migrations/run-tests.sh`. Baseline is
      520 PASS / 0 FAIL / 1 SKIP; report the new counts.
- [x] 7.2 Report the harness result — every declared row passing, zero failures —
      in the PR, with the row count as observed rather than as a constant.
- [x] 7.3 Live floor proof: attempt a real `git commit` of a code file under an
      unsatisfied change; capture the refusal and `git rev-parse HEAD` before and
      after.
- [x] 7.4 Stage-2 independent code review (`superpowers:requesting-code-review`).
      `openspec validate` does not discharge this.
- [x] 7.5 `/cso` — the gate is the enforcement trust boundary and this change
      closes a live bypass. Write `SECURITY.md` into the change directory.
- [x] 7.6 File the upstream core issue proposing GAP-1 and GAP-4 harness rows;
      link it from ADR-0012 and from issue #26.
- [x] 7.7 Reply on issue #26 correcting the "pre-commit and CI are no-ops"
      inference — the floors did enforce, via driver wrappers rather than mode
      dispatch — and report the adoption.
