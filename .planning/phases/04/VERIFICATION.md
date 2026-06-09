# Phase 4 — VERIFICATION: §12 Authoring Conventions (surgical)

Verified on-disk 2026-06-09.

## must_have: edited skills contain a Mermaid flowchart with a labeled fallback edge

- **Evidence:** `skills/agentic-apps-workflow/SKILL.md` — 1 ```mermaid```
  `flowchart` block; labeled dotted fallback edge
  `size -.->|ambiguous: matches two rows → pick the HIGHER size| size`;
  `report[REPORT: ...]` terminal.
- **Evidence:** `skills/codex-ts-declare-first/SKILL.md` — 1 ```mermaid```
  `flowchart` block; labeled recovery edges (`recover_* --> check`) and a
  `done[... → REPORT to codex-verification]` terminal.

## must_have: no judgment-prose deleted in favor of a diagram

- **Evidence:** trigger skill Step 1 size table (Tiny/Small/Medium/Large,
  4 rows) intact (`grep -F` PASS); Step 2 routing table intact; the §13
  skill's "no-observed-RED investigation" judgment remains in prose below
  its diagram. The flowcharts were ADDED as decision skeletons; the
  criteria tables/prose were preserved (§12: diagram = skeleton, prose =
  criteria).

## must_have: surgical scope honored

- **Evidence:** `gsd-execute-phase/SKILL.md` and other unedited skills were
  NOT converted (bulk conversion not required per §12); `git diff --stat
  main..HEAD` touches only the two edited skills for Mermaid.

## must_have: no regression

- **Evidence:** `bash migrations/run-tests.sh` → PASS 31 / FAIL 0 / SKIP 1
  after the edit.
