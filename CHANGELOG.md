# Changelog

All notable changes to `codex-workflow` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This repo cites `implements_spec: <version>` against
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
in every shipped artifact's frontmatter.

## [Unreleased]

### Backlog (beyond conformance)

- Plugin packaging — re-evaluate after in-the-wild use (ADR-0001 F2).
- Cross-host Stage 2 review via Claude Code MCP (ADR-0002 Option B).
- Upstream follow-up: `agenticapps-observability` `init` Phase 6 emits the
  §10.8 metadata block to `CLAUDE.md`; making it host-aware (`AGENTS.md` on
  Codex) would remove migration 0003's relocate round-trip.
- Real CI: `.github/workflows/ci.yml` is still the Phase 0 placeholder and
  verifies nothing; `migrations/run-tests.sh` runs only locally.

## [0.9.0] — 2026-07-19

### Changed

- **The always-loaded `AGENTS.md` carried ~150 lines that only bind once a code
  task is underway, and four of the five blocks were already duplicated in the
  trigger skill** (migration `0012`). Core spec **0.10.0** added an
  "Instruction-surface economy (eager vs lazy)" SHOULD to §12 (core ADR-0020),
  extending §12 from *where in* the eager file prose sits to *what belongs in it
  at all*: the always-loaded file carries the §11 canonical block plus a short
  pointer to the trigger skill; procedural content lives in the lazily-loaded
  skill.

  `AGENTS.md` is injected on **every** turn, including turns that never touch
  code, so its whole content is re-billed per turn. The §02 gate table, task-size
  routing, the §15 ritual tail and the plan-review procedure all already existed
  in `skills/agentic-apps-workflow/SKILL.md` — the plan-review section was
  **byte-identical** between the two files, and §15 had been obliged to live in
  the skill by core §15 since `0007`. Only the session-handoff protocol genuinely
  moved; step 1 places it in the skill before step 2 removes it from `AGENTS.md`,
  so the contract is never absent from both at once.

  `AGENTS.md` goes **269 → 120 lines**.

  **Enforcement did not move — only prose.** §12 is explicit that a host whose
  runtime enforces a gate programmatically keeps the hook wiring where the
  runtime needs it. The plan-review gate is the case in point: its *procedure*
  moved to the skill, while `.codex/hooks.json`, `hook-wrapper-plan-review.sh`
  and `check-plan-review.sh` are untouched — a test asserts it. Removing the
  prose weakens no gate; the hook is what blocks, and it still does.

  **The installer template is deliberately left heavy.** Slimming it too was
  tried and is wrong: this host installs by **replay**, so
  `templates/agents-md-additions.md` is an *input to the chain*, not the end
  state, and migrations `0007`/`0008`/`0010` read their sections out of it.
  Removing them breaks those immutable migrations — `0010` would silently insert
  nothing, regressing the very D-06 defect it exists to heal, and a project that
  stopped at `0010` would end up with §15 in neither file. A fresh install
  applies the heavy template early and `0012` slims the result at the end of the
  same replay, so it lands slim either way. The suite caught this.

### Fixed

- **The conformance citation had been stale by six spec versions.**
  `implements_spec` read **0.4.0** while the repo already satisfied everything
  through 0.9.1. Audited 2026-07-19: §02's `plan-review` gate (0.5.0), §15
  knowledge capture (0.7.0), §04's red-flag composition rules (0.8.0) and §08's
  setup end-state amendment (0.9.0) were all already satisfied by shipped
  implementation.

  **§14 (0.6.0) was the one real gap — and it was a declaration gap, not a code
  gap.** This scaffolder builds no LLM prompts from non-self-authored values, so
  §14's trigger condition cannot occur and it qualifies for trivial conformance
  — but §09 requires the host to *say so*, and it never did. That undeclared
  state was the sole substantive barrier to any claim at or above 0.6.0. Now
  declared in `docs/ENFORCEMENT-PLAN.md` and the trigger skill's new
  `## Spec deltas` section, with downstream coverage delegated to
  `injection-guard`. Migration `0012` step 5 **refuses to advance the claim**
  unless step 4 (the declaration) has landed.

  Claim advances **0.4.0 → 0.10.0** on `skills/agentic-apps-workflow/SKILL.md`
  only — spec/09 makes that file the normative carrier. The gate, GSD-entry and
  lifecycle skills keep `implements_spec: 0.4.0`: they cite the *gate contract*
  they implement, not the host claim, and those contracts are unchanged. A test
  pins that distinction so a future bulk sed cannot collapse it.

  Also corrected while here: `docs/ENFORCEMENT-PLAN.md` records §08 as satisfied
  **by replay**. Core's own CHANGELOG (v0.9.0) asserts this host "installs from a
  snapshot" and therefore carries pre-0.9.0 §08 exposure — that is false. Setup
  walks `0000`→latest step by step, there is no `check-snapshot-parity.sh`, and
  CI runs only `run-tests.sh`. Replay is §08's first-listed strategy, so the
  drift-guard obligation never applied here.

  Suite: **453 → 468 PASS / 0 FAIL / 1 SKIP** (15 new `0012` assertions, whose
  transform is extracted from the migration document and executed so the test
  cannot drift from what ships).

## [0.7.0] — 2026-07-15

### Fixed
- **The §11 Coding Discipline block now anchors above a leading GitNexus
  region instead of inside it** (migration `0009`;
  [ADR-0010](docs/decisions/0010-region-aware-spec-11-placement.md)). In a
  project whose `AGENTS.md` opens with a GitNexus-managed region, the §11
  block was placed *inside* that region — where the next `gitnexus analyze`
  regenerated the region and destroyed the block silently, with no error and
  no diagnostic. The block now lands above the region when the region leads
  the file, and stays exactly where it is when it does not, honoring spec
  §12's advice that behavior-critical prose live near the top of the file
  where a model reliably reads it. The defect was **latent on this host** —
  no repo here was ever broken, because this repo's own region does not lead
  its `AGENTS.md` — so this closes the defect for every project this host
  scaffolds rather than repairing anything in place.
- **Existing installs pick the fix up by running
  `/update-codex-agenticapps-workflow`**, which applies migration `0009`
  (`0.6.0` → `0.7.0`). The migration is idempotent and deliberately
  conservative: it heals a block that sits inside a region, injects one that
  is missing entirely, leaves a correctly anchored block byte-identical
  (healthy repos see no churn), and refuses with an error rather than
  overwriting a §11 section you wrote by hand.

## [0.6.0] — 2026-07-15

### Added
- **Bind the plan-review pre-execution gate — spec §02** (migration `0008`;
  [ADR-0009](docs/decisions/0009-plan-review-gate.md)). Multi-AI plan review
  must now run before execution begins on this host: a hybrid enforcement
  (ADR-0009) binds `pre_execution.plan_review` declaratively in
  `.planning/config.codex.json` and pairs it with a programmatic verifier,
  `skills/agentic-apps-workflow/scripts/check-plan-review.sh`, invoked by
  ritual text in `AGENTS.md` and the trigger
  `skills/agentic-apps-workflow/SKILL.md` before the first code-touching edit
  of a phase. The remedy on a block is the new `codex-plan-review` producer
  skill, which writes `<NN>-REVIEWS.md` with at least two independent
  external reviewers. Core spec v0.5.0 added this gate and `spec/02:105-109`
  names this repo as an outstanding follow-up; it closes the failure core
  ADR-0018 records, where cparx phases 04.9 through 05 silently dropped
  multi-AI plan review for 8 consecutive phases with nothing catching the
  omission. It went unnoticed here because the bindings table covered
  exactly the 15 pre-0.5.0 gates and jumped straight from `design-critique`
  to `tdd`, and the gap was never recorded as a Spec Delta.
- **Migration `0008` teaches an existing install the same shape a fresh
  install now gets by construction** — the config block, the ritual section,
  and the bindings-table corrections (D-19, D-20), every row sourced from a
  single template so migrated and fresh installs cannot drift apart.
  `check-plan-review.sh` ports claude-workflow's reference resolver with
  care, not verbatim — the port corrects three defects in the reference
  resolver (see ADR-0009).
- **16 distinct gates, not 15 (D-20).** The bindings table's duplicate `tdd`
  row is collapsed to match `spec/02`; every gate table in this repo, and in
  a migrated install after `0008`, now reads 16 rows / 16 distinct gates,
  identical to a fresh install.
- **Enforcement is agent-mediated, not a runtime hook.** The verifier's
  `exit 2` is a hard stop once it runs, but invocation is via ritual text an
  agent reads and follows, not a Codex-native `PreToolUse` hook — see
  ADR-0009 for the deferred native-hook upgrade path.
- **Verified** by `run-tests.sh`'s `test_check_plan_review_resolver`,
  `test_check_plan_review_enforcement`, `test_check_plan_review_contract`,
  and `test_migration_0008` (a no-op on a second run), against all seven of
  ROADMAP.md's Phase 8 success criteria.

### Changed
- Scaffolder `version` `0.5.0 → 0.6.0` (trigger SKILL.md +
  `.codex/workflow-version.txt`) via migration `0008`; migration chain now
  `0000`–`0008`. `implements_spec` stays at `0.4.0`: it tracks the last
  full-conformance audit, not one gate (mirrors the `0.5.0` entry's own note
  below) — this phase delivers the §02 *content* a future `0.5.0` claim would
  require, without making that claim itself.

### Fixed
- **Wire update-path migration discovery.** `$update-codex-agenticapps-workflow`
  reads migrations from
  `${CODEX_HOME}/skills/update-codex-agenticapps-workflow/migrations/`, but that
  path was empty — the canonical migrations live at repo-root `migrations/` and
  were never exposed under `~/.codex`, so the update path discovered **zero**
  migrations in target repos (latent since the migration framework landed; the
  repo dogfoods via direct edits and `run-tests.sh` synthetic fixtures, so it
  went unnoticed). Added a committed symlink
  `skills/update-codex-agenticapps-workflow/migrations → ../../migrations`; since
  the whole skill dir is symlinked into `~/.codex`, migrations now resolve at the
  expected installed path (verified: all of `0000`–`0006` discoverable). Canonical
  location and the drift/version coupling are unchanged (no version bump — this is
  scaffolder wiring with no per-project effect, so no migration). `run-tests.sh`
  gains a regression guard asserting the symlink resolves.
- **Wire setup-path migration discovery** (same class as the update-path fix
  above). The *setup* skill walked `migrations/0000-baseline.md` via a **relative**
  path, which only resolved from the scaffolder checkout — so
  `$setup-codex-agenticapps-workflow` could not find the baseline migration when
  run inside a target project. Added the committed symlink
  `skills/setup-codex-agenticapps-workflow/migrations → ../../migrations` and
  rewrote the skill's operative references to the stable installed path
  `${CODEX_HOME}/skills/setup-codex-agenticapps-workflow/migrations/` (matching
  the update skill's convention), with a host note making the path authoritative.
  Verified `0000-baseline.md` resolves through the install path; `run-tests.sh`
  gains a matching regression guard. No version bump (scaffolder wiring, no
  per-project effect, no migration).

## [0.5.0] — 2026-07-06

### Added
- **Knowledge capture into the Obsidian vault — spec §15 (migration `0007`,
  [ADR-0008](docs/decisions/0008-knowledge-capture.md); mirrors core ADR-0017
  and claude-workflow ADR-0038).** A `## Knowledge Capture — Ritual Tail
  (spec §15)` section is wired into this host's always-loaded surfaces — the
  trigger `skills/agentic-apps-workflow/SKILL.md` and the project `AGENTS.md`
  (via the `agents-md-additions.md` template) — instructing the agent to distill
  **1–5 transferable learnings** to **one Obsidian note per repo** as the FINAL
  step of the three rituals: session handoff, plan completion, phase completion.
  Entries carry the `(codex)` host tag in the append-only Log heading; the
  curated `## Key Learnings` section is reconciled on each write. The write never
  blocks the ritual, is never committed to the repo, and skips gracefully
  (one info line) when the config block is absent/disabled or the vault folder
  is missing.
- **Config-routed, host-neutral destination.** The `knowledge_capture`
  `{enabled, note}` block lives in the **shared** `.planning/config.json` — *not*
  the namespaced `.planning/config.codex.json` — so codex and claude sharing a
  working tree read the identical block and write to the same per-repo note,
  differing only by the host tag (dual-host workflow-testbed finding; standard
  §4/§5). Seeded by migration `0007` as a `. + {knowledge_capture}` merge that
  preserves every existing key (a claude co-install's hooks stay intact) and is
  skipped when the block already exists. The `<repo-name>` placeholder is
  resolved to the repo directory name at configuration time (spec §15.2).
- **Vendored, self-contained templates:**
  `templates/config-knowledge-capture.json` (the host-neutral block) and
  `templates/obsidian-learnings-note.md` (first-write note skeleton). No
  claude-workflow path is referenced at runtime.

### Changed
- Scaffolder `version` `0.4.0 → 0.5.0` (trigger SKILL.md +
  `.codex/workflow-version.txt`); migration chain now `0000`–`0007`.
  `run-tests.sh`: adds `test_migration_0007` (config merge resolves `<repo-name>`
  and preserves a pre-existing claude key; codex-only create yields a block-only
  file; AGENTS.md section insert + idempotency; version-bump round-trip) plus
  layout guards for the two new templates and ADR-0008.
- Standard conformance checklist gains a §15 knowledge-capture line
  ([`docs/standards/gsd-binding-and-planning.md`](docs/standards/gsd-binding-and-planning.md)).

### Notes
- `implements_spec` stays at `0.4.0`: it tracks the last full-conformance audit;
  §15 wiring is real either way, and citing 0.7.0 requires auditing the §§ added
  in 0.5.0/0.6.0 (out of scope). Codex ships no snapshot, so there is no
  snapshot drift-guard analog — the fresh-install path is conformant by
  construction (the template carries the section; the migration chain seeds the
  config).

## [0.4.0] — 2026-07-02

### Changed
- **Commit phase artifacts — never gitignore `.planning/phases/` (migration
  `0006`, mirrors the shared
  [ADR-0037](https://github.com/agenticapps-eu/claude-workflow/blob/main/docs/decisions/0037-commit-phase-artifacts.md)
  downstream-hosts note).** Phase artifacts (`.planning/phases/<NN>-<slug>/`
  contexts, plans, verifications, and the AgenticApps gate outputs
  `REVIEW.md`/`QA.md`/`DB-AUDIT.md`) are the shared cross-host project plan and
  are **committed by default** — the workflow's normal `git add`/commit captures
  them, no `git add -f` needed. Migration `0006` makes this authoritative for
  existing installs by stripping a **whole-tree** `.planning/phases/` ignore from
  the project `.gitignore` (surgical, anchored to a bare directory line; narrow
  under-tree scratch ignores and `.planning/cache/`/`.planning/state/` are
  preserved). This closes the dual-host workflow-testbed benchmark friction
  (rounds 1+2, 2026-07-01/02) where the round-2 codex run had to improvise
  `git add -f` to commit phase evidence.
- **Standard §5 amendment + conformance-checklist line**
  ([`docs/standards/gsd-binding-and-planning.md`](docs/standards/gsd-binding-and-planning.md),
  mirrors the claude-workflow amendment): phase artifacts are committed evidence
  (only `.planning/cache/`, `.planning/state/`, and host session-handoffs may be
  ignored); each host's update path strips a whole-tree ignore; `git add -f` is
  demoted to a single-commit stopgap, not the sanctioned path.
- Scaffolder `version` `0.3.0 → 0.4.0` (trigger SKILL.md +
  `.codex/workflow-version.txt`); migration chain now `0000`–`0006`.
  `run-tests.sh`: PASS 68 / FAIL 0 / SKIP 1 (adds `test_migration_0006` — strip
  whole-tree ignore, preserve narrow + transient ignores, version-bump
  round-trip).

### Notes
- Verified this repo's codex scaffolder was already conformant *before* the
  migration: the setup skill's atomic commit stages `.planning/` wholesale, the
  committed root `.gitignore` ignores only cache/state/handoffs, and neither
  `install.sh` nor any migration ever emitted a `.planning/phases/` ignore rule
  (`git check-ignore` clean; 18 phase files tracked). The benchmark friction was
  in host projects' own `.gitignore` (mis-attributed by the testbed to "the GSD
  config"), not this repo's scaffolder. Migration `0006` is the defensive
  existing-install fix + the mirror of ADR-0037's downstream obligation. Codex
  ships no snapshot, so there is no snapshot drift-guard §6 analog.

## [0.3.0] — 2026-07-01

### Changed
- **Bind upstream GSD + Superpowers; stop re-porting (migration `0005`,
  [ADR-0007](docs/decisions/0007-bind-upstream-gsd.md)).** `codex-workflow` is
  now a **thin binding**, symmetric with `opencode-workflow` and per the shared
  standard [`docs/standards/gsd-binding-and-planning.md`](docs/standards/gsd-binding-and-planning.md).
  GSD is bound from `get-shit-done-codex` (TÂCHES lineage), which installs 18
  `/prompts:gsd-*` Codex prompts under `~/.codex/prompts` (verified v1.4.1 on
  Codex CLI 0.142.0 — supersedes ADR-0003's "no prompts idiom" premise);
  Superpowers is bound from the official `superpowers` Codex plugin
  (`codex plugin add superpowers`, openai-curated marketplace; verified v6.1.0 —
  skills namespaced `superpowers:<skill>`). The six Superpowers-duplicate
  gates rebind to `superpowers:*`: `brainstorm-*` → `superpowers:brainstorming`,
  `tdd` → `superpowers:test-driven-development`, `verification` →
  `superpowers:verification-before-completion`, `code-review` →
  `superpowers:requesting-code-review`, `branch-close` →
  `superpowers:finishing-a-development-branch`, and bug tasks →
  `superpowers:systematic-debugging` directly (no `gsd-debug` prompt). Execute
  is `/prompts:gsd-execute-plan`; this distribution ships no `gsd-quick`.
- **GSD-native phase-subdirectory layout (get-shit-done v1.42.3).** The
  earlier **invented** `.planning/phases/<N>/` variant (bare number, bare
  `PLAN.md`) is superseded by GSD's real layout: `.planning/phases/<NN>-<slug>/`
  holding `<NN>-CONTEXT.md`, `<NN>-<MM>-PLAN.md`, `<NN>-VERIFICATION.md`,
  `<NN>-<MM>-SUMMARY.md`, with AgenticApps artifacts (`REVIEW.md`, `QA.md`,
  `DB-AUDIT.md`, `IMPECCABLE-AUDIT.md`, `screenshots/`) written **inside** the
  phase directory alongside GSD's files — so plans are byte-compatible across
  hosts. Existing `.planning/phases/**` are kept as provenance.
- **Namespaced hook config (standard §4).** `.planning/config.json` →
  `.planning/config.codex.json` so a codex + claude tree can coexist.
- Scaffolder `version` `0.2.1 → 0.3.0` (trigger SKILL.md +
  `.codex/workflow-version.txt`); migration chain now `0000`–`0005`.
  `run-tests.sh`: PASS 59 / FAIL 0 / SKIP 1.

### Removed
- The re-ported GSD entry-point skills (`skills/gsd-discuss-phase`,
  `gsd-plan-phase`, `gsd-execute-phase`, `gsd-debug`, `gsd-quick`) — now
  provided by upstream `get-shit-done-codex` as `/prompts:gsd-*`.
- The six Superpowers-duplicate gate skills (`codex-brainstorming`,
  `codex-tdd`, `codex-verification`, `codex-finishing-branch`,
  `codex-code-review`, `codex-systematic-debugging`) — now provided by
  upstream Superpowers.
- ADR-0003 ("GSD entry points as skills") is **superseded** by ADR-0007.

### Added
- [`docs/BINDING.md`](docs/BINDING.md) — the three-layer architecture, install
  order, Codex invocation idiom (`/prompts:gsd-*`), planning layout, coexistence
  rules, and verified-vs-open status.
- [`docs/decisions/0007-bind-upstream-gsd.md`](docs/decisions/0007-bind-upstream-gsd.md).
- `install.sh` now binds the upstreams (runs `npx get-shit-done-codex` via the
  non-interactive `-p get-shit-done-codex get-shit-done-cc --global` bin, notes
  the Superpowers install) with a `--skip-upstream` flag.
- Trigger skill Step 1 makes the Stage-2 code-review gate + an ADR **mandatory**
  for medium/large tasks (standard §6 enforcement parity), bound to
  `superpowers:requesting-code-review`.

## [0.2.1] — 2026-06-09

### Fixed
- **§11 mirror byte-drift vs current core (migration `0004`).** The v0.2.0
  mirror was vendored from a stale local checkout of `agenticapps-workflow-core`;
  core `10f2c96` (merged via core #12) had added blank lines around the §11
  anti-pattern lists (block 75 → 79 lines, fence 26–102 → 26–106), so the
  shipped mirror + `AGENTS.md` block had drifted from the authoritative core
  §11 — a canonical-prose conformance defect (§09 item 1). Migration `0004`
  (`0.2.0 → 0.2.1`, additive to `implements_spec` which stays `0.4.0`)
  re-vendors the mirror byte-identical to current core and re-injects the
  corrected block into `AGENTS.md`.
- **Harness hardened against recurrence.** `run-tests.sh` now extracts the
  canonical block **fence-relative** (between the four-backtick fences) instead
  of by hardcoded line numbers, so future spec line-shifts cannot silently
  reintroduce the drift; `test_migration_0004` asserts the live `AGENTS.md`
  block matches the corrected (79-line) mirror. `run-tests.sh`: PASS 46 / FAIL
  0 / SKIP 1.

### Changed
- Scaffolder `version` `0.2.0 → 0.2.1` (trigger SKILL.md + `.codex/workflow-version.txt`).
  `implements_spec` unchanged at `0.4.0` (10f2c96 is a markdown-clean patch, not
  a spec version bump).

## [0.2.0] — 2026-06-09

Catch-up to `agenticapps-workflow-core` **spec 0.4.0** (full conformance),
from the 0.1.0 baseline. Feature-bearing minor: new canonical prose, a new
skill, observability delegation, and surgical Mermaid. Migration chain
`0001`–`0003` (contiguous; `0001` is the sole version/`implements_spec`
bumper). `run-tests.sh`: PASS 43 / FAIL 0 / SKIP 1.

### Added
- **§11 Coding Discipline (canonical prose).** Reproduced verbatim in
  `AGENTS.md` behind the provenance anchor
  `<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->`; vendored
  byte-identical mirror at
  `skills/setup-codex-agenticapps-workflow/templates/spec-mirrors/11-coding-discipline-0.4.0.md`.
  Migration `0001` (from 0.1.0 → 0.2.0) injects it and is the **sole bumper**
  of `version` (→0.2.0) and `implements_spec` (→0.4.0). (Phase 1)
- **§13 declare-first TypeScript.** New gate skill `codex-ts-declare-first`
  (strengthens the `tdd` gate): three atomic commits
  `declare(ts):` → `test(ts):` (RED) → `feat(ts):` (GREEN), three refusals,
  three separate phase templates. Bound in the trigger Step 3 gate table and
  `config-hooks.json`. Migration `0002` (additive). (Phase 2)
- **§12 authoring conventions (surgical Mermaid).** `flowchart` decision
  skeletons for the newly authored/edited branchy workflows
  (`codex-ts-declare-first` refusals; trigger Step 2 routing); criteria stay
  in prose. No bulk conversion (§12 does not require it). (Phase 4)
- **§10 observability (delegation).** Satisfied by delegating to the
  standalone `agenticapps-observability` skill — installed on Codex via that
  repo's new `install-codex.sh` (agenticapps-observability v0.12.0, PR #3) —
  rather than re-owning a generator. Migration `0003` records the delegation,
  relocates the §10.8 metadata block into `AGENTS.md`, and repoints a stale
  skill ref (no auto-install; D-03 mirror). ADR-0004 (decision), ADR-0005
  (adopt core ADR-0014), `docs/observability-delegation.md`. (Phase 3)
- Drift test in `migrations/run-tests.sh` (`SKILL.md version` == latest
  migration `to_version`); per-migration tests `0001`–`0003`.
- ADR-0006 records the core ADR-0015 outcome (secret scanner **stays on
  gitleaks**; no scanner code change here). (Phase 5)

### Changed
- `implements_spec: 0.4.0` across the trigger, 14 gate skills, 5 GSD
  entry-point skills, 2 lifecycle skills, and `config-hooks.json`. (Phase 5)
- `.codex/workflow-version.txt` → `0.2.0`; trigger `SKILL.md` `version` → `0.2.0`.
- `docs/ENFORCEMENT-PLAN.md` conformance claim 0.1.0 → 0.4.0 (+ §10 delegated
  binding section, §13 binding row). README + this CHANGELOG updated. (Phase 5)
- **install.sh restructure (Phase 6):** `templates/` moved permanently under
  `skills/setup-codex-agenticapps-workflow/templates/` (history-preserving);
  the secondary templates-symlink step removed (no install-time write inside
  the source tree); the obsolete `skills/*/templates` `.gitignore` rule dropped.
  Fixed a dangling-symlink bug — `install_one` now tests `-L` before `-e`, so
  stale/dangling skill links (e.g. after a repo relocation) are repointed
  instead of leaving `ln -s` to fail "File exists".
- **agenticapps-shared submodule (Phase 6):** added at `vendor/agenticapps-shared/`
  (pinned v1.0.0); `migrations/run-tests.sh` now sources the shared harness
  primitives (helpers / fixture-runner / drift-test) instead of local copies;
  install.sh refreshes the submodule. SPLIT-01 parity.

### Verified (Phase 6)
- Empirical checks recorded in ADR appendices (Codex 0.130.0): AGENTS.md
  concat is git-root-down to cwd (ADR-0001 A2); `allow_implicit_invocation:
  false` is honored — the GSD entry points do not leak into unrelated sessions
  (ADR-0003 F2).

## [0.1.0] — 2026-05-10

Initial release. Full-conformance Codex CLI host implementation of
[`agenticapps-workflow-core`](https://github.com/agenticapps-eu/agenticapps-workflow-core)
v0.1.0. Sibling of [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow)
and [`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow).

### Inventory

- 1 trigger skill — `agentic-apps-workflow` (canonical-prose blocks
  byte-matched against spec/01, /03, /04, /05)
- 13 gate-fulfilling skills — every spec/02 gate has a binding
- 5 GSD entry-point skills — explicit-only via
  `policy.allow_implicit_invocation: false`
- 2 lifecycle skills — `setup-codex-agenticapps-workflow`,
  `update-codex-agenticapps-workflow`
- 5 project-side templates
- Migration framework — `0000-baseline.md`, `run-tests.sh`,
  `test-fixtures/`, `README.md` (implements
  spec/08-migration-format.md)
- `install.sh` — symlinks skills into `$CODEX_HOME/skills/`
- 3 architecture decision records
- `docs/ENFORCEMENT-PLAN.md` documenting `full` conformance with
  Spec Deltas for gates whose triggers cannot occur on a UI-less
  DB-less scaffolder (per spec/09)
- `docs/dogfood-2026-05-10.md` — Phase 6 self-apply log

### Phase-by-phase

- Phase 0 — Repo bootstrap and Codex CLI research
  - README skeleton, MIT LICENSE, .gitignore, AGENTS.md placeholder
  - Trivial CI workflow (`.github/workflows/ci.yml`) that prints the phase
    name; replaced with real CI in Phase 7
  - Three ADRs documenting the five Phase 0 research findings:
    - `docs/decisions/0001-codex-skill-naming.md` — skill directory paths,
      naming convention, packaging choice (loose skills + `install.sh` for
      v0.1.0; plugin manifest deferred to v0.2.0)
    - `docs/decisions/0002-stage2-independent-reviewer-on-codex.md` — Stage 2
      reviewer is implemented via `codex exec` child process with optional
      `--model` override; cross-host review via Claude Code MCP deferred
    - `docs/decisions/0003-gsd-entry-points-as-prompts.md` — Codex has no
      native `prompts/` surface; GSD entry points ship as skills with
      `policy.allow_implicit_invocation: false` and `default_prompt` in
      `agents/openai.yaml`
  - `research-complete` tag marks the end of Phase 0

- Phase 1 — Trigger skill
  - `skills/agentic-apps-workflow/SKILL.md` authored against
    `agenticapps-workflow-core` v0.1.0
  - Frontmatter cites `implements_spec: 0.1.0` per spec/09 conformance
  - Four canonical-prose blocks reproduced verbatim and byte-match
    confirmed against `agenticapps-workflow-core/spec/`:
    - Step 0 — Commitment Ritual (spec/01)
    - Rationalization Table (spec/03)
    - 13 Red Flags (spec/04)
    - Pressure-Test Scenarios (spec/05)
  - Step 1 (4-row task-size table), Step 2 (GSD entry-point routing),
    Step 3 (15-gate binding table mapping every spec/02 gate to a
    `codex-*` skill), Step 4 (ADR capture pointers), Verification
    Check (5 host-specific bash snippets covering commitment block,
    TDD commit pairs, Stage 2 evidence, per-`must_have` evidence,
    and `implements_spec` currency)

- Phase 2 — 13 gate-fulfilling skills
  - Each skill cites `implements_spec: 0.1.0` and an `implements_gate`
    field naming the spec/02 gate(s) it satisfies. Codex's loader reads
    only `name` and `description`; the extension fields are ignored at
    load and read by conformance audits per ADR-0001 D6.
  - **Every-phase skills** — `codex-tdd` (RED + GREEN commit pair),
    `codex-verification` (refuses completion without `must_have`
    evidence per spec/06), `codex-spec-review` (Stage 1 of the
    two-stage review per spec/07), `codex-code-review` (Stage 2,
    spawns independent reviewer via `codex exec` per ADR-0002)
  - **Pre-phase + design** — `codex-brainstorming` (≥2 named
    alternatives for UI or architecture per spec/02), `codex-design-shotgun`
    (≥3 visual variants), `codex-design-critique` (impeccable-style
    7-dimension scoring + 24-anti-pattern scan per ADR-0011)
  - **Security + QA** — `codex-cso` (OWASP-aligned phase audit),
    `codex-qa` (dual-mode: per-task `ui-preview` + post-phase
    `qa`), `codex-impeccable-audit` (post-implementation visual
    audit, blocks branch close on Red findings per ADR-0011),
    `codex-database-sentinel-audit` (dual-mode: phase-scoped sub-gate
    + pre-launch full-surface, blocks on Critical/High per ADR-0012)
  - **Methodology + finishing** — `codex-systematic-debugging`
    (Observe → Hypothesize → Test → Conclude four-phase protocol;
    not bound to a spec gate, invoked by `$gsd-debug`),
    `codex-finishing-branch` (composes PR description from phase
    artifacts; opens PR via `gh`)

- Phase 3 — 5 GSD entry-point skills (per ADR-0003: skills, not prompts)
  - Each skill ships as `skills/gsd-<verb>/SKILL.md` plus
    `agents/openai.yaml` carrying
    `policy.allow_implicit_invocation: false` and a
    `default_prompt` that names the skill as `$gsd-<verb>` per the
    Codex `openai_yaml.md` reference's explicit-mention rule.
  - **`gsd-discuss-phase`** — surfaces open questions, writes
    `CONTEXT.md` with resolved decisions; routes to
    `codex-brainstorming` when a brainstorm gate fires
  - **`gsd-plan-phase`** — reads `CONTEXT.md`, decomposes into
    tasks with gate triggers and must_haves, authors `PLAN.md`
    plus `RESEARCH.md` / `UI-SPEC.md` as needed; pre-flight checks
    that every required `codex-*` skill is installed
  - **`gsd-execute-phase`** — heavyweight wave executor; emits
    commitment block per task, fires applicable spec/02 gates,
    refuses task completion without `codex-verification` evidence,
    runs the post-phase pipeline (spec-review → code-review →
    security/qa/audits) and finishes with `codex-finishing-branch`
  - **`gsd-quick`** — for tiny/small tasks; minimal commitment
    block + direct route to `codex-tdd` / `codex-verification` /
    `codex-finishing-branch`; refuses medium/large tasks and
    routes to `gsd-discuss-phase` instead
  - **`gsd-debug`** — thin user-facing entry that hands off to
    `codex-systematic-debugging` (the four-phase protocol)

- Phases 4 + 5 — Lifecycle skills, migration framework, templates, install.sh
  - **Templates** at `templates/` — five project-side artifacts that
    setup copies into a fresh project:
    - `agents-md-additions.md` — workflow sections for project AGENTS.md
    - `workflow-config.md` — project-specific config with
      `{{PLACEHOLDERS}}` (project name / repo / client / budget /
      backend / frontend / database / LLM / quality bars / etc.)
    - `config-hooks.json` — `.planning/config.json` template binding
      every spec/02 gate to its `codex-*` skill
    - `adr-db-security-acceptance.md` — ADR template for accepting
      database-sentinel Critical/High findings (per ADR-0012)
    - `global-agents-additions.md` — optional `~/.codex/AGENTS.md`
      append for Option A install
  - **Migration framework** at `migrations/` — implements the
    declarative contract from
    `agenticapps-workflow-core/spec/08-migration-format.md`:
    - `README.md` — host-side manifestation of the migration format
      contract, with Codex paths
    - `0000-baseline.md` — six-step baseline migration (project
      workflow-config, .planning/config.json, AGENTS.md sections,
      docs/decisions/README.md, .codex/workflow-version.txt, optional
      global AGENTS.md additions)
    - `run-tests.sh` — fixture-based test harness; SKIPs the
      interactive-only baseline; runs repo layout sanity checks
    - `test-fixtures/README.md` — fixture contract (extract from git
      refs rather than static fixture files)
  - **Lifecycle skills** at `skills/`:
    - `setup-codex-agenticapps-workflow` — apply baseline migration
      to a fresh project; pre-flights Codex CLI + scaffolder install;
      gathers placeholder values; refuses to re-run on installed
      project
    - `update-codex-agenticapps-workflow` — apply pending migrations
      between project's recorded version and scaffolder version;
      supports `--dry-run`, `--migration NNNN`, `--from VERSION`
  - **`install.sh`** — symlinks every `skills/<name>/` into
    `$CODEX_HOME/skills/<name>/` (default `~/.codex/skills/`) plus a
    `templates/` symlink so migration apply steps can `cp` from a
    stable scaffolder path; idempotent; refuses to clobber non-symlink
    directories; `--copy` and `--dry-run` flags

- Phase 6 — Self-applied workflow + dogfood
  - **Real `bash install.sh`** run against `~/.codex/skills/`. 22
    entries created (21 skill symlinks + 1 templates symlink).
    Idempotent re-run confirms 0 installed / 22 skipped.
  - **AGENTS.md populated** — placeholder replaced with the
    populated structure (Development Workflow, Workflow Enforcement
    Hooks table marking which gates apply to the scaffolder vs which
    don't, Skill routing, Session handoff)
  - **`.planning/config.json`** seeded from
    `templates/config-hooks.json`
  - **`.codex/workflow-config.md`** authored with substituted values
    for codex-workflow's own metadata (project = codex-workflow,
    no UI, no DB, no dev server — gates whose triggers can't fire
    are documented as Spec Deltas in ENFORCEMENT-PLAN, NOT a
    `partial` conformance claim per spec/09)
  - **`.codex/workflow-version.txt`** = `0.1.0` (the durable record
    that `update-codex-agenticapps-workflow` will read on future
    upgrades)
  - **`docs/decisions/README.md`** — index of the three Phase 0 ADRs
  - **`docs/ENFORCEMENT-PLAN.md`** — gate-to-skill bindings for
    codex-workflow's own development; explicitly enumerates the 8
    gates that don't fire on this scaffolder (with rationale per
    spec/09); claims `full` conformance
  - **`docs/dogfood-2026-05-10.md`** — log of the Phase 6 self-apply
    plus a walk-through of a `$gsd-quick` micro-cycle (the README
    refresh that's part of this PR); records the open follow-ups
    for the AGENTS.md root-down concat verification and the
    `policy.allow_implicit_invocation: false` empirical check
  - **README refresh** (the dogfood micro-cycle) — Status, What
    ships, Layout, and Install sections updated to reflect the
    actual shipped state

- Phase 7 — Release
  - This CHANGELOG entry; final README pass
  - `v0.1.0` git tag
  - Repo flipped from private to public
  - Sibling PR against `agenticapps-workflow-core` updating the
    `reference-implementations/README.md` codex-workflow row from
    "repo not yet created" to "v0.1.0 shipped, full-conformance"
  - Follow-up issue opened against `agenticapps-dashboard` for
    Codex host detection in HostAdapter
