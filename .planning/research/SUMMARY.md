# Project Research Summary

**Project:** codex-workflow v0.8.0 "Enforcement, Not Intention"
**Domain:** Internal tooling — migration-chain host binding for a Codex CLI spec-first workflow (no application runtime; this milestone closes a "nominal enforcement" debt class across seven already-scoped carried-debt items)
**Researched:** 2026-07-16
**Confidence:** HIGH overall (all four research tracks grounded in primary sources — this repo's own files, `openai/codex` at the exact pinned tag, and live `gh api` calls — with two explicitly flagged MEDIUM-confidence gaps, both concentrated in HOOK-01)

## Executive Summary

v0.8.0 exists because the last two milestones each shipped a fully green test suite over code that didn't do what the suite claimed: v0.6.0 missed two fail-opens despite 104 byte-perfect assertions, and v0.7.0 shipped 314 PASS / 0 FAIL on a migration (0007) whose pre-flight aborts `exit 3` on every real install — the harness manufactured the very precondition that should have made the migration fail. This milestone's seven items are not new features; they are a closure pass on that recurring failure mode, and the four research tracks converge on the same diagnosis and the same prescription: **a guard is not shipped until it has been observed failing**, applied uniformly to CI, migrations, hooks, and fixtures alike.

The most consequential finding is that the migration chain is genuinely, provably severed for every real install between 0.4.0 and 0.5.0: migration 0007's pre-flight greps a scaffolder-relative path (`skills/agentic-apps-workflow/SKILL.md`) that no real target project has, so it hard-aborts before writing anything — no config, no AGENTS.md section, no version bump. 0008 and 0009 do NOT repeat this bug (they correctly read `.codex/workflow-version.txt`), but their correct floor checks can never be satisfied because the version record 0007 was supposed to advance never moved. Self-application never exposed this because this repo, uniquely, has a local `skills/` tree (it *is* the scaffolder) — the exact "sandbox manufactures the precondition" failure mode this milestone exists to close, now found retroactively in the milestone's own diagnostic tooling one level up. The fix is a new forward migration that re-delivers 0007's Steps 1/2/4 (dropping Step 3, an immutability violation) — sized as "large for 0007's payload, not large across 0008/0009," since once the version record correctly reads 0.5.0, 0008/0009's own already-correct logic applies normally on the next update pass.

The second major finding de-risks HOOK-01 substantially: codex-cli's native `PreToolUse` hook is real, stable, and default-enabled at the repo's pinned 0.144.4, and — contrary to ADR-0009's stated rejection reason — it supports a genuine **project-scoped** `<repo>/.codex/hooks.json` config layer, not only a global `~/.codex/hooks.json`. This falsifies ADR-0009's "global rather than per-project" objection and removes HOOK-01's principal design obstacle; the remaining risk is concentrated in two areas — a sharp block-semantics trap (`exit 2` blocks only with non-empty stderr; empty stderr fails OPEN) and two unresolved trust-ledger questions (hash pre-seeding mechanics, and whether project-trust and hook-trust are one gate or two) that need a live spike before implementation. CI-01, by contrast, is fully de-risked: `actions/checkout@v7` with `submodules: recursive` against a confirmed-public submodule, `jq` present on `ubuntu-latest`, and the drift check already wired into `run-tests.sh` as `test_drift` — CI-01 needs no new script, only a workflow file and a deliberate-regression proof that it can actually go red.

## Key Findings

### Recommended Stack

No new language/runtime stack — this milestone pins two *host* surfaces the repo binds against. codex-cli's `PreToolUse` hook (0.144.4) is the enforcement surface HOOK-01 needs; `actions/checkout@v7` + `ubuntu-latest` is the CI surface CI-01 needs. Both were verified against primary sources (byte-identical `openai/codex` at the pinned tag; live `gh api` calls against `actions/checkout` releases and the `agenticapps-shared` submodule's visibility), not documentation that could be stale.

**Core technologies:**
- codex-cli native `PreToolUse` hook (0.144.4) — programmatic, agent-independent block of a tool call before it executes — confirmed `Stable`, `default_enabled: true` at the pinned tag; NOT experimental/off as some third-party docs claim
- `actions/checkout@v7` (current major, 2026-06-18) with `submodules: recursive` — clones the repo plus the public `vendor/agenticapps-shared` submodule the test harness hard-requires; no token needed
- `ubuntu-latest` (24.04 image) — ships `jq` 1.7.1 preinstalled; `awk`/mawk practically certain present as a base Ubuntu package (not itemized in the runner-images doc, low-risk gap)

**Supporting facts, load-bearing:**
- `hooks.json`'s `command` field is a **static string** — no `{{tool_input.file_path}}`-style templating exists. HOOK-01 needs a genuinely new wrapper script that reads the stdin JSON payload and derives `--file` itself; this is not "wiring," it is a new artifact.
- Block semantics: `permissionDecision: "deny"` (JSON, exit 0) blocks reliably. `exit 2` blocks **only if stderr is non-empty** — `exit 2` with empty stderr is treated as a hook *failure* and fails OPEN (the tool call proceeds). Any exit code other than 0 or 2 also fails open. `check-plan-review.sh`'s existing `exit 2` rejection path must be confirmed to always write to stderr before being wired into the hook.
- `<repo>/.codex/hooks.json` (project-scoped) is real, additive, and higher-precedence than the global file — falsifying ADR-0009's stated objection that native hooks are "global rather than per-project."

### Expected Features (acceptance bar, not net-new features)

This is a codebase audit of seven already-scoped debt items, not a feature discovery exercise. No external ecosystem research was needed.

**Must have (table stakes) — testable, one sentence each:**
- CI-01: a workflow on push/PR to `main`, `submodules: recursive`, runs `run-tests.sh` + drift check, fails red on a scratch-branch reverted guard.
- Migration 0007 chain break: a new forward migration re-delivers 0007's actual payload (config block + AGENTS.md section), proven via a fixture seeded at 0.4.0 with none of 0007's artifacts, not merely a version-file bump.
- HOOK-01: `check-plan-review.sh --file <path>` registered as `PreToolUse`, and a disallowed edit through the real Codex CLI tool surface is observably blocked end-to-end (not a script-level unit test).
- Paired §11 markers: explicit `<!-- BEGIN/END -->` markers bound the §11 block; strip/replace keys off markers directly, not heading+terminator inference; a fixture reproduces AG-01 failing under the old logic and passing under the new.
- MIGR-08 execution coverage: extract 0008's Step 4 Apply block via `extract_step_block` (not hand-copy), execute against a 0.5.0-seeded sandbox, assert exact content equality, mutation-prove by breaking the write line and observing RED.
- WR-03: canonicalize the *parent directory* of `--file` (not the file itself) via existing `_canon_dir`/`_is_contained` helpers, reject on symlink-resolved escape.
- 09-REVIEW.md WR-05 + IN-01..04: five small, independently-proven fixes (see below) — do not batch into one undifferentiated "cleanup."

**Explicitly do NOT over-build:**
- No OS-matrix beyond a cheap ubuntu+macos addition (borderline table-stakes, ~3 lines, on-theme given named BSD/GNU hazards) — no lint, shellcheck, caching, or full E2E scaffold-and-migrate smoke test in v0.8.0.
- Do not heal the version pointer alone without re-delivering 0007's payload (reproduces the exact bug class).
- Do not solve the general per-repo hook-scoping problem beyond HOOK-01's own scope; do not extend native binding to the other 15 declarative gates.
- Do not build a generic pluggable marker framework; scope markers to §11 only. Do not fold WR-01 (a separate, real, but unscoped defect) in opportunistically.
- Do not retrofit 0008's Steps 1–3 to the extraction pattern in this pass.
- Do not attempt to close TOCTOU races in WR-03; do not build a second path-safety primitive.

**Defer (explicitly out of v0.8.0 scope, named so it isn't silently re-added):**
- The update skill's multi-hop chain-selection defect (0008's own Notes).
- WR-01 (mirror single-`##`-heading coupling).
- Shellcheck/lint/caching in CI; a real scaffold-and-migrate E2E smoke test (would more directly have caught 0007's bug class, but is scope expansion beyond CI-01's stated definition).

### Architecture Approach

Six architecture questions were settled against primary sources. The chain-break mechanism (Q1) is confirmed with precision: 0008/0009's pre-flight *mechanism* is correct, but the *value* they depend on was never advanced because 0007 aborted before Step 4. Exactly **3 new migrations** are needed (Q2): the 0007-fix (must slot at the exact `0.4.0→0.5.0` step 0007 occupies, since 0007 wrote nothing to heal-later from), HOOK-01 (a new global-file-write migration, following the `0000-baseline.md` Step 6 precedent for `optional_for`-gated global writes), and paired-§11-markers (structurally identical to 0009's re-vendor pattern, emitting a closing marker during the re-vendor it already performs). Everything else (CI-01, MIGR-08 coverage, WR-03, the 09-REVIEW cleanups) is a script/fixture/doc edit with no project-side `applies_to` surface, per `migrations/README.md`'s own contract — not a migration.

**Major components / integration points:**
1. **Migration 0010 (0007-fix)** — corrected pre-flight reading `.codex/workflow-version.txt`; re-delivers Steps 1/2/4 of 0007's payload; drops Step 3 (MIGR-09 violation); fixtures must use the no-local-`skills/`-tree shape, never this repo's own tree.
2. **CI workflow (`.github/workflows/ci.yml`)** — single job running `run-tests.sh` unfiltered (already exercises all fixtures including `test_drift`); a second drift-only job is a UI-clarity nicety, not load-bearing.
3. **HOOK-01 wrapper script + migration** — a new self-scoping wrapper (checks for `.codex/workflow-version.txt` presence, exits 0 if absent, else execs `check-plan-review.sh --file <path>` and translates its exit code into the hook's `permissionDecision` shape) shipped via `install.sh`; a migration merges the `PreToolUse` entry into `hooks.json` and flips the feature flag, following the `0000-baseline.md` Step 6 merge-don't-clobber precedent.
4. **Paired-markers migration** — reuses 0009's *unchanged, immutable* terminator alternation as the legacy-detection fallback for un-migrated installs; newly migrated installs get an explicit closing marker as a fourth alternative (never a replacement) alongside `## `/`gitnexus:start`/EOF.

**Build order (Q6), stated as a dependency-derived constraint, not a preference:** CI-01 lands first, serial, blocking — nothing else is "verified" until it exists. Then three parallelizable tracks with no shared file surface: Track A (migration 0010 + MIGR-08 coverage), Track B (WR-03 + 09-REVIEW cleanups, ADR-0009 Correction for d.12), Track C (HOOK-01 — re-verify Codex CLI hook facts empirically first, then wrapper + migration + ADR-0009 Correction for d.9). Paired-§11-markers lands last — not because anything depends on it, but because it is the most structurally novel change (new marker convention) and most benefits from a CI-verified baseline.

### Critical Pitfalls

1. **CI-01 goes green while testing nothing (the "third green" repeat)** — omitted `submodules: recursive`, `|| true`/piped-to-zero-exit steps, drift check bolted on as informational, or CI added without updating branch-protection required-checks would all let CI-01 exist without enforcing. Avoid by: opening a scratch PR with a deliberate regression and confirming the GitHub Actions UI itself shows red (not just a log line); grep-testing the workflow YAML for `submodules: recursive` inside `run-tests.sh`; verifying required-status-check registration via `gh api repos/:owner/:repo/branches/main/protection`; never merging v0.8.0's own PR on a local green now that real CI exists to merge against.

2. **Migration 0007's fix repeats V-01 verbatim inside the new migration** — the most likely way to ship item 2 wrong is deriving the new pre-flight by analogy/copy-paste and re-introducing a `skills/**/SKILL.md` grep, or writing the new fixture the same manufactured-precondition way that hid the original bug. Avoid by: pre-flight must grep `.codex/workflow-version.txt` exclusively (direct copy of 0008:73-79, not fresh design); a document-contract fixture asserts the pre-flight's literal executable line does NOT contain any `skills/agentic-apps-workflow` substring; the fixture sandbox must NOT manufacture that file.

3. **Paired §11 markers narrow the terminator and silently regress the widened three-way invariant** — implementing "look for the end marker" as the *only* termination condition (rather than a fourth alternative alongside `## `/`gitnexus:start`/EOF) would break every already-migrated project (majority of the fleet) that has no end marker yet. Avoid by: treating the new marker as strictly additive; anchoring its regex from the first draft (learn CR-02 directly); keeping `12-idempotent-rerun` running unmodified plus a new sibling fixture for the "old single-marker, no end marker" transition state; mutation-testing each of the four alternation branches independently.

4. **HOOK-01 ships a config that is never invoked, or fires globally and blocks nothing scoped** — five concrete failure shapes: wrong event/schema name (analogized from Claude Code rather than observed on codex-cli directly — this repo already made exactly this mistake once, ADR-0001's A2), scaffolder never actually writes `hooks.json` on real installs, unscoped matcher fires in unrelated repos, trust-ledger re-grant silently skipped, or an exit-code convention mismatch silently flips block/allow. Avoid by: empirically re-verifying the real schema/flag name on the installed codex-cli version before writing any config (this repo's stack research already did this and found a discrepancy between `[features] hooks = true` — repo's own prior record — and third-party docs citing `codex_hooks`/v0.114; both aliases actually work at 0.144.4, but re-verify per version); a human-observed live smoke test showing a real tool call intercepted, not just a passing unit test; explicitly testing non-firing in a second, unrelated repo on the same machine.

5. **MIGR-08 (and every new fixture this milestone adds) asserts a value the setup already guarantees** — the single most-repeated failure mode across both prior milestones. Concretely: sandbox pre-creates the post-migration value, or the assertion checks file existence/substring rather than exact post-Apply content, or "mutation-tested" is claimed in a SUMMARY.md without being independently re-executed by the verifier. Avoid by: sandbox always starts from the pre-migration value; assert exact content equality; literally comment out the write line, re-run, confirm RED, then restore, with the verifier independently re-running the same cycle rather than trusting the executor's claim — applied as a milestone-wide standard, not just to MIGR-08.

## Implications for Roadmap

Based on combined research, the suggested phase structure follows the architecture research's build-order graph directly, since PROJECT.md already states CI-01-first as a milestone constraint (not a discretionary ordering) and the remaining six items partition cleanly into three tracks with no shared file surface.

### Phase 1: CI-01 — CI that can prove failure
**Rationale:** PROJECT.md states this explicitly as "the prerequisite for trusting every other fix in this milestone." Nothing else is verified until real, remote CI exists — closing the retrospective's named dominant failure mode (local-green merges).
**Delivers:** `.github/workflows/ci.yml` replacing the Phase-0 placeholder; single job, `actions/checkout@v7` with `submodules: recursive`, runs `migrations/run-tests.sh` unfiltered (already exercises `test_drift`); branch protection updated to require the new check.
**Addresses:** CI-01 (table stakes above).
**Avoids:** Pitfall 1 (green-but-toothless CI) — acceptance must include a deliberate-regression scratch PR observed going red in the GitHub UI itself, not just a passing local run.

### Phase 2 (parallel Track A): Migration 0010 — heal the 0007 chain break
**Rationale:** Largest, most consequential single defect found — an unreachable version floor blocking every real pre-0.5.0 install from 0008/0009's already-correct logic. Independent in code from the other tracks; only needs Phase 1 to exist so its own PR runs on real CI.
**Delivers:** New forward migration (next available ID) with a corrected pre-flight (`.codex/workflow-version.txt`), re-delivering 0007's Steps 1/2/4, dropping Step 3; an amendment to `update-codex-agenticapps-workflow/SKILL.md` Stage D describing how a migration-level pre-flight abort (0007, permanently) is handled once a superseding migration (0010) covers the same transition; MIGR-08 execution-coverage fixture ships alongside (same testing surface, no code dependency).
**Uses:** the extraction pattern (`extract_step_block`) already established by `test_migration_0009`.
**Avoids:** Pitfall 2 (repeating V-01 inside the fix) and Pitfall 3 (floor-gate diagnostic mismatch) — requires a document-contract fixture proving the new pre-flight never references `skills/**`, and fixtures shaped like a real target project, never this repo's own tree.
**Decision required before this phase starts (see Open Questions):** whether the new migration also re-delivers 0008's payload, or leaves 0008 to fire normally once the version record is healed (research recommends the latter as the minimal, spec-conformant default).

### Phase 3 (parallel Track B): WR-03 + 09-REVIEW.md cleanup
**Rationale:** Mutually independent script/fixture/doc edits, no shared file surface with Track A or C; low design risk (reuses existing helpers).
**Delivers:** `check-plan-review.sh`'s `--file` guard rewritten to canonicalize the parent directory via `_canon_dir`/`_is_contained` (reused, not reinvented); WR-05 (banner determinism — full-script grep for every mirror-derived stdout value, not just the banner), IN-01 (`extract_step_block` 10+-step prefix bug, tested against a synthetic document), IN-02 (unasserted line-drop evidence, strictly-smaller assertion, no hardcoded line count), IN-03 (one doc line in `docs/decisions/README.md`), IN-04 closed by supersession inside Track A/paired-markers' `mktemp` usage (not edited in place — 0009 is immutable); ADR-0009 Correction section for decision 12's reversal.
**Avoids:** Pitfall 7 (a realpath-shaped guard that is still TOCTOU-bypassable, leaf-only, or substring-containment-bypassable) and Pitfall 8 (bundling four differently-shaped review findings into one undifferentiated checkbox).

### Phase 4 (parallel Track C): HOOK-01 — native unconditional block
**Rationale:** Highest verification cost of the three parallel tracks (requires a live, human-observed codex-cli session, not just CI) — sequence its empirical re-verification step first within its own phase, per the architecture research's explicit prerequisite ordering.
**Delivers:** Empirical re-verification of the exact hooks.json schema/flag name/exit-code convention against the installed codex-cli version (this research already narrows the gap but flags it MEDIUM-confidence); a new self-scoping wrapper script (`install.sh`-shipped) reading stdin JSON and deriving `--file`; a migration merging a `PreToolUse` entry into `.codex/hooks.json` (project-scoped, per the stack research's falsification of ADR-0009's "global" claim) and the enabling feature flag; ADR-0009 Correction sections for both the d.9 supersession and the factual "global" correction.
**Uses:** codex-cli 0.144.4's `PreToolUse` hook surface (Stack finding).
**Avoids:** Pitfall 5 (a config that parses but never fires, or fires unscoped) — requires a live smoke test showing a real tool call intercepted, and an explicit non-firing test in a second, unrelated repo.
**Decision required before this phase starts (see Open Questions):** the two trust-ledger gaps (hash pre-seeding mechanics; whether project-trust and per-hook trust are one gate or two) likely need a short spike before the wrapper/migration design is finalized.

### Phase 5: Paired §11 markers (AG-01's durable fix)
**Rationale:** The largest single design surface in the milestone and the most structurally novel (new marker convention, new idempotency shape) — sequenced last so it benefits from a CI-verified baseline and re-established fixture-extraction/mutation-gate confidence from the smaller items landing first.
**Delivers:** New forward migration inserting explicit `<!-- BEGIN/END -->` markers bounding §11 (syntax not yet finalized — see Open Questions); strip/replace logic keyed off markers as a **fourth** alternative alongside the existing three-way terminator alternation (never a replacement); `mktemp`-in-project-dir Apply blocks (closing IN-04 by supersession, preserving same-filesystem atomic `mv`); a new sibling fixture for the "old single-marker, no end marker yet" transition state; ADR-0010 Correction section closing the open follow-up.
**Implements:** the paired-markers architecture component (Q3).
**Avoids:** Pitfall 4 (narrowing the terminator alternation) — the single highest-consequence pitfall in the milestone, since a regression here is destructive and largely unrecoverable from the tool alone; requires mutation-testing each of the four alternation branches independently and keeping `12-idempotent-rerun` green, unmodified or with an explicitly justified change.

### Phase Ordering Rationale

- CI-01 must be first because PROJECT.md states it as a milestone constraint, not a preference, and because the retrospective names local-green merging as the dominant enabling condition for both prior milestones' failures.
- Tracks A/B/C parallelize safely because architecture research confirms no shared file surface between them (Track A: new migration + its fixtures + the update-skill doc; Track B: `check-plan-review.sh` + its fixtures + ADR-0009/README; Track C: new wrapper + `install.sh` + new migration + a different section of ADR-0009) — Track B should sequence its ADR-0009 edit before Track C's to avoid two PRs touching the same file section simultaneously.
- Paired-markers is sequenced last not due to a dependency but because it is the highest-consequence, most novel item, and benefits most from a CI-verified tree and freshly re-established fixture/mutation-gate discipline from the earlier, lower-risk items.

### Research Flags

Phases likely needing deeper research during planning (`--research-phase`):
- **HOOK-01 phase:** the exact hooks.json schema/flag name was verified against the pinned tag in this research, but two trust-ledger mechanics (hash pre-seeding bytes; whether project-trust and per-hook trust are one gate or two) remain unconfirmed and flagged for a dedicated spike — recommend a short empirical spike at the start of this phase, not full research-phase treatment, since the schema itself is already HIGH confidence.
- **Paired §11 markers phase:** the exact closing-marker syntax was not chosen by any researcher (a proposal only, e.g. `<!-- spec-source-end: ... -->`) — this is a design decision to make during planning, informed by matching the existing outer `<!-- BEGIN/END: agentic-apps-workflow sections -->` idiom, not a research gap requiring external investigation.

Phases with standard, well-documented patterns (skip research-phase):
- **CI-01 phase:** fully de-risked — `actions/checkout@v7`, `submodules: recursive`, `run-tests.sh` invocation are all confirmed against live GitHub state.
- **Migration 0007 chain-break phase:** the mechanism, fix shape, and fixture pattern are all fully specified by architecture/pitfalls research; the only open item is the 0008-payload scoping decision (a requirements-author decision, not a research gap).
- **WR-03 / 09-REVIEW cleanup phase:** reuses existing helpers (`_canon_dir`/`_is_contained`); each of the five sub-items has a fully specified fix and fixture shape already.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against byte-identical primary source (`openai/codex` at the exact pinned tag `rust-v0.144.4`) cross-checked against a live local codex-cli 0.144.4 install; GitHub Actions facts verified live via `gh api`. Two explicit gaps flagged (hash pre-seeding algorithm; project- vs. hook-trust gate disentanglement) — not resolved, correctly labeled as spike-required rather than assumed. |
| Features | HIGH | All seven items grounded in direct reads of PROJECT.md, 09-REVIEW.md, RETROSPECTIVE.md, the actual migration documents, and `run-tests.sh`/`check-plan-review.sh` source — no external ecosystem claims, appropriately so since this is an internal audit, not a product feature survey. |
| Architecture | HIGH | All six questions settled against primary sources with file:line citations; one MEDIUM sub-finding explicitly flagged (Q4's exact Codex CLI flag name/schema, since superseded/tightened by the Stack track's later, more authoritative source read) and one MEDIUM on exact marker syntax (a design choice, not a fact to verify). |
| Pitfalls | HIGH | Every pitfall traced to a specific file/line and an already-observed instance of the same defect class in this repo's own history (V-01, CR-01/02/03, ADR-0001 A2) — not generic advice; explicitly scoped to avoid padding. |

**Overall confidence:** HIGH

### Gaps to Address

- **0008-payload scoping decision (Architecture Q1 / Features item 2):** whether the new 0007-fix migration must also re-deliver 0008's plan-review-gate payload, or whether healing the version record to 0.5.0 is sufficient for 0008's own (unedited) migration to fire normally on the project's next update pass. Research recommends the latter (minimal, most spec-conformant reading of "per 0008's precedent") but flags this as a decision the requirement text must state explicitly, not silently assume. **Resolve during requirements/roadmap authoring, not implementation** — an implicit assumption here is exactly the kind of surprise this milestone exists to prevent.
- **Migration-level pre-flight abort handling (Architecture Q1):** once the 0010 fix migration and the still-broken 0007 coexist as simultaneously-pending migrations for a stuck project, the update skill selects by ascending ID and will attempt 0007 first, which will abort every time. Whether a migration-level pre-flight abort (as opposed to a step-level failure) is even subject to `migrations/README.md`'s existing retry/skip/rollback atomicity contract is undocumented anywhere. Flagged as a required task inside the 0007-fix phase (amend `update-codex-agenticapps-workflow/SKILL.md` Stage D), not a separate item.
- **Two HOOK-01 trust-ledger gaps (Stack Gaps 2 and 3):** (a) the exact hash-input algorithm for the sha256 trust ledger's `trusted_hash` value is not confirmed in the source read — needed only if HOOK-01 wants a migration to pre-seed trust and skip the interactive `/hooks` approval step; (b) whether "project layer trust" (the gate that must pass before `<repo>/.codex/hooks.json` loads at all, per official docs) is the same gate as the per-hook `trusted_hash` state or a separate one-time prompt was not disentangled. Both need a live spike (author a known hook, trust it via `/hooks`, diff results; run `codex` inside a fresh clone carrying a new `.codex/hooks.json` and observe exactly what is prompted) before the HOOK-01 phase's wrapper/migration design is finalized.
- **Closing-marker syntax for paired §11 markers (Architecture Q3):** no researcher chose a final syntax; `<!-- spec-source-end: agenticapps-workflow-core@[version] §11 -->` is a proposal only, meant to mirror the existing outer `<!-- BEGIN/END: agentic-apps-workflow sections -->` idiom and GitNexus's own `gitnexus:start`/`gitnexus:end` pairing. This is a planning-time design decision for the paired-markers phase, not an unresolved research question.
- **Strong vs. weak interpretation of "chain provably runs end to end" (Features item 2):** the update skill's multi-hop chain-selection defect (a project at 0.4.0 may only pick up one migration per invocation, not cascade through 0007-fix→0008→0009 in one pass) is explicitly out of v0.8.0 scope per 0008's own Notes, but bears directly on how strictly this milestone's acceptance criterion should be read. Research recommends stating the weak interpretation (each migration, run individually, completes without aborting) as the v0.8.0 bar and naming the strong interpretation (one invocation reaches current version) as a known, deliberately deferred gap — not silently claiming the strong interpretation is achieved.
- **`awk` availability on `ubuntu-latest` (Stack Gap 4):** not explicitly itemized in the runner-images software list fetched during research (only `jq` was); practically certain to be present as a base Ubuntu package. Trivial to add `apt-get install -y gawk` defensively if CI-01's first run surfaces an `awk: command not found` — cheap enough to add preemptively rather than wait for the failure.

## Sources

### Primary (HIGH confidence)
- `openai/codex` GitHub repo via `gh api`, exact pinned tag `rust-v0.144.4` — `pre_tool_use.rs`, `hook_names.rs`, `hook_config.rs`, `discovery.rs`, `features/src/lib.rs`, generated JSON schemas for hook input/output
- Live local `codex-cli 0.144.4` install — `~/.codex/hooks.json`, `~/.codex/config.toml` trust-ledger state, `codex --version`
- `gh api repos/actions/checkout/releases`, `gh api repos/actions/checkout/contents/README.md`, `gh api repos/agenticapps-eu/agenticapps-shared` — GitHub Actions checkout/submodule facts
- This repo: `.planning/PROJECT.md`, `.planning/RETROSPECTIVE.md`, `.planning/phases/09-region-aware-11-placement/09-REVIEW.md`, `migrations/0000/0001/0004/0006/0007/0008/0009-*.md`, `migrations/README.md`, `migrations/run-tests.sh`, `skills/agentic-apps-workflow/scripts/check-plan-review.sh`, `skills/update-codex-agenticapps-workflow/SKILL.md`, `docs/decisions/0009-plan-review-gate.md`, `docs/decisions/0010-region-aware-spec-11-placement.md`, `docs/decisions/README.md`, `.github/workflows/ci.yml`, `.gitmodules`, `.codex/workflow-version.txt`

### Secondary (MEDIUM confidence)
- Official Codex docs (`developers.openai.com/codex/hooks`, `learn.chatgpt.com/docs/hooks`, `/docs/changelog`) — used to cross-check, superseded by source where they conflicted
- WebSearch third-party report on a Windows-only exit-2 fail-open caveat — single source, not independently reproduced
- `actions/runner-images` Ubuntu 24.04 readme — `jq` explicitly itemized; `awk` presence inferred, not itemized

### Tertiary / falsified (flagged explicitly, do not trust)
- `agenticcontrolplane.com/blog/codex-cli-hooks-reference`'s claim that PreToolUse is "Bash tool only... by design" — directly contradicted by primary source (`hook_names.rs::apply_patch()`)
- ADR-0009's own claim that native hooks are "global rather than per-project" — directly contradicted by primary source (`discovery.rs`'s project-layer config precedence); flagged for the ADR-0009 amendment this milestone already plans

---
*Research completed: 2026-07-16*
*Ready for roadmap: yes*
