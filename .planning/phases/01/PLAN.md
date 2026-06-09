# Phase 1 — PLAN: §11 Coding Discipline (canonical prose)

- Spec: `agenticapps-workflow-core` §11 (canonical-prose MUST, §09 item 1)
- Goal: reproduce §11 verbatim in `AGENTS.md`; ship the vendored mirror;
  author migration `0001` (the **sole** bumper to version 0.2.0 /
  implements_spec 0.4.0).
- Model: claude-workflow `migrations/0014` (adapted to Codex paths).

## Tasks

1. **Vendor the mirror** — `templates/spec-mirrors/11-coding-discipline-0.4.0.md`
   = core spec §11 lines 27–101 (content between the fences), generated via
   `sed` for zero-transcription byte-identity. No provenance comment inside
   (would alter verbatim prose). NB: claude-workflow's own mirror has drifted
   from current core §11 (extra blank lines) — we vendor from **core**, the
   authoritative source, not from the reference host's copy.
2. **Inject into AGENTS.md** — provenance anchor
   `<!-- spec-source: agenticapps-workflow-core@0.4.0 §11 -->` + the verbatim
   block, immediately before the first `## ` heading (lands as first managed
   section, near the top per §11 SHOULD + §12 advisory). Streamed from the
   mirror via `awk` (no transcription). Fence excluded (a code fence in
   AGENTS.md would render the discipline as a code block; §09 requires the
   block "including its heading" — the heading is `## Coding Discipline`,
   not the fence).
3. **Migration `0001`** — `from_version: 0.1.0` → `to_version: 0.2.0`.
   Steps: inject §11 (idempotent on provenance anchor) with conflict
   pre-flight (heading without provenance → abort exit 3, two hand-resolution
   paths) + post-apply byte-identity assertion; bundle the version +
   implements_spec bump (both or neither); record 0.2.0 in
   `.codex/workflow-version.txt`.
4. **Bump the conformance claim** — trigger SKILL.md `version` 0.1.0→0.2.0,
   `implements_spec` 0.1.0→0.4.0, and the prose citation line. Sole bumper;
   `0002`/`0003` ride on `to_version: 0.2.0`.
5. **Test harness** — add `test_migration_0001` (idempotency / conflict /
   byte-identity / mirror==core) and `test_drift` (SKILL.md version ==
   latest migration to_version) to `run-tests.sh`; add the mirror +
   migration to the layout check; wire the dispatcher.

## Gates fired (per AGENTS.md enforcement table)

- `codex-verification` — evidence in VERIFICATION.md (this phase).
- `codex-spec-review` / `codex-code-review` — two-stage post-phase review.
- `codex-cso` — N/A (no auth/storage/api/llm code touched).
- `codex-qa` — N/A (no dev server).

## Out of scope

- Bumping `implements_spec` on the gate skills / GSD entry points → Phase 5.
- §10 / §12 / §13 → Phases 2–4.
