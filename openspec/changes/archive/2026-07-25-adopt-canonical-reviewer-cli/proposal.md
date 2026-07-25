## Why

The §18 change-gate **consumes** review evidence. `bin/reviewer-cli.sh` **produces**
it. Core published the consumer as a reference implementation in
[core#33](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/33)
and this repo adopted it (ADR-0012, v1.1.0) — and left the producer forked.

That fork fired on 2026-07-25, about two hours after the gate fork was closed.
A sibling host's installer delivered the correctly-arbitrated `1.2.2` gate and,
**in the same run**, blind-installed its 3-arm wrapper over this repo's 4-arm
superset at the shared path:

```
$ ~/.agenticapps/bin/reviewer-cli.sh opencode <prompt>
reviewer-cli: unknown vendor 'opencode' (expected: gemini | codex | claude)
```

The gate survived the same run because it carries `# gate-version:` and every
host arbitrates on it. The wrapper had no marker, so one installer run upgraded
one shared artifact and silently downgraded the other. Filed as
[core#41](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/41);
core answered with
[core#42](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/42),
publishing the canonical wrapper at `# reviewer-cli-version: 1.0.0` plus a
14-row conformance harness.

**This is not a gate bypass, which is why it is worth a change.** A producer
excluding its own host still had two reachable vendors, so §18's `>= 2`
threshold held. What was lost is quieter: a reviewer that vanishes mid-review is
recorded as "reviewer unavailable" and the change proceeds with one fewer
opinion. A drifted *consumer* fails loudly; a drifted *producer* reports clean
while degrading the exact evidence §18 exists to compel.

Measured on this branch, 2026-07-25, with core's harness at `60cd83f`:

```
tools/reviewer-cli-conformance.sh --family
  core canonical                14 passed, 0 failed
  pi-agentic-apps-workflow      14 passed, 0 failed
  claude-workflow               14 passed, 0 failed   (88777c9, unmerged)
  codex-workflow  (this repo)   13 passed, 1 failed   <- no version marker
  opencode-workflow              9 passed, 5 failed
  ~/.agenticapps/bin (shared)   12 passed, 2 failed   <- no opencode arm, no marker
```

This repo's own copy is behaviourally the superset — it fails exactly one row,
the version marker. That single row is the whole hazard: without it every
installer on the machine reads `0.0.0` and cannot refuse a downgrade.

## What Changes

**Vendored verbatim from core `60cd83f`, never edited here:**

- `bin/reviewer-cli.sh` ← the canonical 135-line wrapper, `# reviewer-cli-version: 1.0.0`
- `tools/reviewer-cli-conformance.sh` ← the 14-row harness

`tools/core-vendor.manifest` advances `core_commit` `750da2e` → `60cd83f` and
records both files. The gate and its harness are byte-identical at `60cd83f`
(verified by `git show`; `1105607…` and `b3c2f6b…` unchanged), so **one commit
still describes all four vendored files** and the same-commit invariant is
preserved rather than weakened to "each file names some commit".

**The installer learns to arbitrate a second artifact:**

- `bin/install-gate.sh` gains `--marker <name>`, defaulting to `gate-version`.
  One implementation of parse → compare → refuse-downgrade → `mkdir` lock →
  atomic temp+`mv`, two callers. The operator-facing label is **derived** from
  the marker rather than passed separately — two parameters for two call sites,
  where the second only affects log wording, is not minimal.
- `install.sh` stops blind-writing `~/.agenticapps/bin/reviewer-cli.sh` with
  `install -m 0755` and routes it through that installer.

**The producer stops trusting an unmarked shared copy:**

- `skills/codex-openspec-change-review/SKILL.md` prefers the shared wrapper only
  when it carries `# reviewer-cli-version:`, else falls back to the repo copy —
  the same marker-validated resolution the gate's surfaces already use, for the
  same reason: `opencode-workflow` still ships a 9/14 copy and does not
  arbitrate, so it can still clobber that path.

**CI scores the producer before trusting a review:**

- `.github/workflows/openspec-gate.yml` gains one step running the vendored
  harness against `bin/reviewer-cli.sh`, ahead of the gate step.

**Not changing:**

- **The producer's vendor set or its call convention.** The skill already invokes
  `reviewer-cli.sh <vendor> <prompt-file>` and never a vendor CLI directly, and
  already excludes `codex` as the implementing host. The rework `claude-workflow`
  needed at `88777c9` does not apply here.
- **The gate, its harness, or any of the three enforcement surfaces.** They are
  re-verified at the new manifest commit and are byte-identical.
- **`opencode-workflow`'s 9/14 copy.** A different repo's adoption PR.

## Capabilities

### New Capabilities

- `reviewer-cli`: what this repo guarantees about the §18 review **producer's**
  wrapper — that it is vendored from core rather than maintained here, that its
  conformance is proven by executable harness in CI, that every writer of the
  shared path arbitrates on the version marker and cannot downgrade it, and that
  the producer refuses to resolve an unmarked shared copy.

### Modified Capabilities

None.

Round 1 of the review carried a `change-gate` delta correcting that spec's claim
that vendored files record their core commit "in a vendor header" — the
implementation rejected headers during 0014 and uses the
`tools/core-vendor.manifest` sidecar instead. **Both reviewers returned
REQUEST-CHANGES on it and it has been dropped**, for a reason sharper than
"scope": `opencode` observed that the delta was mis-described. The existing
scenario it replaced was **unreachable** — no header ever shipped, so the
header-divergence branch could never fire — and the replacement is reachable,
enforced by a migration assertion. That is a behavioural change to the gate's
same-commit enforcement surface, not a textual correction, and it belongs to a
change whose subject is the gate.

The drift is real and pre-dates this change. It is filed as a follow-up in
`migrations/0015`, to be proposed on its own once this ships. Nothing here
depends on it: the new `reviewer-cli` capability states the manifest and
one-commit rules for its own files directly.

## Impact

- **Scripts:** `bin/reviewer-cli.sh` (new, vendored),
  `tools/reviewer-cli-conformance.sh` (new, vendored), `bin/install-gate.sh`
  (parameterised), `install.sh`, `tools/core-vendor.manifest`
- **Skills:** `skills/codex-openspec-change-review/SKILL.md`
- **CI:** `.github/workflows/openspec-gate.yml`
- **Migration:** `migrations/0015-adopt-canonical-reviewer-cli.md`, 1.1.0 → 1.2.0,
  with assertions in `migrations/run-tests.sh`
- **Docs:** `docs/decisions/0013-vendor-canonical-reviewer-cli.md` (new),
  `CHANGELOG.md`
- **Downstream:** every project scaffolded by this repo, and — via the shared
  `~/.agenticapps/bin/` path — every AgenticApps host on the operator's machine.
  The shared wrapper goes from 12/14 to 14/14 the first time `install.sh` runs.
