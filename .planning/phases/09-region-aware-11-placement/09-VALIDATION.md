---
phase: 9
slug: region-aware-11-placement
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-15
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `09-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Native shell harness — `migrations/run-tests.sh` (bash + awk assertions). No external test framework; none to install. |
| **Config file** | none — harness is self-contained. Requires `vendor/agenticapps-shared` submodule present (harness hard-fails without it). |
| **Quick run command** | `migrations/run-tests.sh 0009` |
| **Full suite command** | `migrations/run-tests.sh` |
| **Estimated runtime** | ~seconds (local shell; baseline 278 PASS / 1 SKIP / 0 FAIL verified 2026-07-15) |

**No Wave 0 framework install is required.** The harness exists and is green today.

---

## Sampling Rate

- **After every task commit:** `migrations/run-tests.sh 0009` (filter support verified — `run-tests.sh:7`)
- **After every plan wave:** `migrations/run-tests.sh` (full suite; expect `FAIL: 0`)
- **Before `/gsd:verify-work`:** Full suite green, including the pre-existing 278 assertions (no regression)
- **Max feedback latency:** < 30 seconds

**Known gap — state plainly, do not silently fix:** there is no CI sampling rate. `.github/workflows/ci.yml` is still the Phase 0 placeholder (`echo` + `exit 0`); CI-01 is deferred to its own phase. Phase 9 merges on a **local green only**, exactly as v0.6.0 did. Plans must not assume CI catches a regression it currently cannot.

---

## Per-Task Verification Map

Populated by the planner. Every task touching migration `0009` or `test_migration_0009` MUST carry an automated command from the Sampling Rate table above.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _TBD by planner_ | — | — | — | — | — | — | — | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Dimension 8 — Anti-Dead-Assertion Contract (phase-critical)

**This is the single most important section in this file.** Phase 8 shipped assertions that could never match (08-05 twice; 08-09 caught only by the plan-checker). They passed, and read as coverage, while testing nothing. D-36's antidote: *"Non-empty is not the same as correct."*

Every assertion introduced in Phase 9 MUST be proven to fail when it should:

1. **Extraction assertions (TEST-01 / TEST-04).** Before trusting any `extract_0009_*` helper to gate a fixture, run it once against a deliberately wrong document shape (point it at 0001's document, or markdown missing `### Step 1`) and confirm the shape guard **fails loudly** rather than silently returning empty-but-unchecked. Port all three of `claude-workflow`'s `case` guards (Step 1 Idempotency / Apply / Rollback), and demonstrate each guard's failure branch once during implementation. Record the demonstration in the task's evidence.

2. **RED-before-GREEN (TEST-02)** is this hazard's suite-level instance, and it is a **hard ordering constraint from ROADMAP.md**. `test_migration_0009` must FAIL against the current naive anchor (`/^## / && !done`) *before* 0009 exists, then turn GREEN once 0009 ships. The auditable evidence is the commit shape: a `test(RED)` commit with fixtures failing, then a `feat(GREEN)` commit. A suite that was never observed RED is not evidence.

3. **The widened strip terminator (D-24, corrected 2026-07-15).** Prove a fixture where the OLD `/^## /`-only terminator would have destroyed the file — i.e. MIGR-06 idempotent re-run against an already-healed, region-led State-B file — actually exercises the widened path and leaves the region content intact and paired. **This is the assertion the pre-correction CONTEXT.md would not have caught.** Without it the phase can ship green and still eat a GitNexus region.

4. **`07-prose-mention-not-a-region` (D-46.1) is a dead-assertion detector by design.** A substring marker match passes every other fixture and fails only this one. If it passes with a substring match, the fixture is wrong.

---

## Double-Sided Idempotency Contract (D-38)

Per `migrations/test-fixtures/README.md` § Contract: each step's check must return **non-zero** against the before-state and **zero** against the after-state. Catches a too-permissive check (skips unapplied work) and a too-strict one (re-applies applied work).

Step 1's region-aware check must be asserted in **all four states**, not two:

| State | Shape | Required check result | Why it matters |
|-------|-------|----------------------|----------------|
| **A** | Correct anchor, current provenance, not in region | **zero** (skip) | Guards MIGR-07 — a healthy-but-off-anchor block must be left alone (D-31) |
| **B** | Provenance present **but block in region** | **non-zero** (heal) | *"Provenance alone must not short-circuit the heal"* — the design doc calls this conjunction the whole point. A check that returns zero here is the defect. |
| **C** | No provenance at all | **non-zero** (inject) | Plain absent case |
| **D** | §11 heading, no provenance | gated by the **pre-flight** (`exit 3`), not the idempotency check | Assert separately; file must be unmodified |

---

## Empirical Replay Evidence (ANCHOR-03 / ANCHOR-04)

Success Criterion 1 says the anchor rule *"has been validated empirically … **before** migration 0009 is written."* That is a **recorded-evidence** requirement, not a claim to assert.

- **Mechanism:** a **committed** validation script (not a throwaway), run against this host's real `AGENTS.md` plus a synthesized gitnexus-led file.
- **Evidence captured:** the script's output recorded in the phase evidence trail (`09-VALIDATION-EVIDENCE.md`, the ADR, or the commit message) — sufficient for a verifier to confirm the replay happened and what it showed.
- **Must demonstrate:** (a) replay on the healthy real file re-derives §11's current position with **zero churn** (byte-identical), and (b) replay on a gitnexus-led file anchors **above** the region.
- **Ordering:** this completes and passes **before** 0009's apply-block is authored (ROADMAP hard ordering 1).

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — `migrations/run-tests.sh` exists, is green (278 PASS / 1 SKIP / 0 FAIL), and supports per-migration filtering. No test framework install, no stub files, no `conftest` equivalent needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ADR records the anchor decision, **both** rejected alternatives (D-22), and the drift-repair side effect (D-28.2) | DOC-01 | Prose quality/completeness — not mechanically assertable | Read the ADR; confirm both rejected alternatives and the corrected invariant (D-21) appear with their reasoning |
| CHANGELOG records the fix at release altitude | DOC-02 | Editorial judgment | Read CHANGELOG entry for 0.7.0. Note: no "known issues" section exists (verified) — the source prompt's "retire the known-issues entry" is a **no-op** |
| SETUP-01's written confirmation is honest about the multi-hop limitation (D-45) | SETUP-01 | Claim-accuracy review | Confirm the record states setup applies 0000-baseline only, lands at `0.1.0`, and does **not** assert an end-state conformance it cannot demonstrate |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references *(N/A — no Wave 0 needed)*
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] **Every new assertion demonstrated to fail when it should (Dimension 8 contract above)**
- [ ] **RED observed before GREEN for `test_migration_0009` (TEST-02)**
- [ ] **Empirical replay evidence recorded before 0009's apply-block authored (ANCHOR-03/04)**
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
