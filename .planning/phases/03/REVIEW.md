# Phase 3 — REVIEW (two-stage, spans two repos)

## Stage 1 — Spec compliance (codex-spec-review, inline)

§10 generator obligation (§10.7) satisfied by delegation to the consumable
`observability` skill — a §09-blessed "host mechanism (a skill binding)".
§10 is at spec_version 0.3.2 with no 0.4.0 delta, so the obs skill
(`implements_spec: 0.3.2`) fully covers the §10 portion of the 0.4.0 claim.
Recorded as a delegation (satisfied MUST), not a spec delta. Verdict: PASS.

## Stage 2 — Independent review + security pass (codex-code-review / codex-cso)

Independent reviewer (separate context) reviewed both repos by running
commands (the installer, jq/sed round-trips, the full harness, clobber tests).

- **install-codex.sh (security):** logic-only diff vs the audited `install.sh`
  = 4 expected deltas; all security-bearing lines byte-identical. Verified by
  execution: idempotent; refuses to clobber a real dir (exit 1, file untouched);
  replaces stale symlink; quoted `$CODEX_HOME`/`$HOME`; no `eval`/secret/data-loss
  path. PASS.
- **§09 delegation framing:** correct — §09 `full` item 2 blesses "a skill
  binding" as a satisfying mechanism. PASS.
- **migration 0003:** faithful to claude 0022 (requires/verify, exit-3 hard
  abort, no auto-install D-03); additive 0.2.0→0.2.0; jq apply/rollback exact;
  sed touches only the skill ref. PASS.
- **chain/drift:** 0000→0001→0002→0003 contiguous; no shipped migration mutated;
  drift green. PASS.
- **SPLIT integrity:** codex-workflow ships no generator/templates/baseline. PASS.

**Verdict: APPROVE-WITH-NITS** — no BLOCK/HIGH.

### MEDIUM (FIXED in this phase)

- **§10.8 AGENTS.md block not materialised on a fresh Codex project.** The obs
  `init` writes the block to CLAUDE.md (not host-aware); migration 0003 Step 2
  originally only *repointed* (no-op on fresh). Since the target is **full**
  conformance, a §10.8 MUST left "pending" is not acceptable.
  **Fix applied:** migration 0003 gains a **relocate step** — it moves the
  anchored `observability:` block (init's real content) from CLAUDE.md to
  AGENTS.md (the canonical Codex file), then repoints. The host migration
  owning the host's instruction-file block mirrors claude-workflow. New test
  `Step 2 relocates the §10.8 block CLAUDE.md→AGENTS.md (content preserved)`
  PASS; ENFORCEMENT-PLAN §10.8 row + delegation doc corrected to describe the
  relocate (no overstatement). run-tests.sh now PASS 41 / FAIL 0 / SKIP 1.

### NITs

- Step 3 repoint sed tightened to a line-leading `^…skill:` anchor (was
  unanchored) — applied.
- test inline jq omits some non-load-bearing keys (`init`/`scan`/`note`) — left
  (still validates `delegated_to`).
- obs README references the follow-up via PR #3 rather than a dedicated issue
  number — left (the PR body documents the follow-up).
