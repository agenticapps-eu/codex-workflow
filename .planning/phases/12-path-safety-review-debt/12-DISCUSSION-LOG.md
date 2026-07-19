# Phase 12: Path Safety & Review Debt - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-17
**Phase:** 12-path-safety-review-debt
**Areas discussed:** WR-03 guard shape & fail-mode, WR-03 containment root & ordering, ADR-0009 Phase 12 vs 13 coordination, REV-04 doc-fix depth

---

## WR-03 guard shape & fail-mode

### Q1 — Replace or augment the lexical `..` check?

| Option | Description | Selected |
|--------|-------------|----------|
| Augment (keep '..' + add canon) | Keep lexical `..` reject (T-08-37) as cheap first-line, then add parent-dir canonicalization + containment. Belt-and-suspenders; `..` still fires when parent doesn't exist. | ✓ |
| Replace (canon only) | Remove the `..` loop; rely solely on parent canon. Matches requirement's literal wording but loses `..` protection for the not-yet-created-parent case. | |

**User's choice:** Augment.
**Notes:** Protects the not-yet-created-parent case and preserves the existing T-08-37 mutation-test guarantee. CONTEXT D-01 records that WR-03's literal "replace" wording is honored as "supersede as the symlink defense" while keeping the lexical check as a defensive floor.

### Q2 — Fail-mode when the parent dir can't be canonicalized?

| Option | Description | Selected |
|--------|-------------|----------|
| Fall through to the gate | Empty canon → containment fails → bypass doesn't fire → normal resolution decides. Existing documented semantics (`:80-82`). Never fails open. | ✓ |
| Reject hard (exit 2 block) | Treat un-canonicalizable parent as suspicious and block. Would false-block the legitimate new-file-in-new-dir case; contradicts the fall-through design. | |

**User's choice:** Fall through to the gate.
**Notes:** Failing open is the milestone's nemesis; falling through is fail-safe. The kept lexical `..` check still catches traversal on this path.

### Q3 — Symlink policy for the `--file` target?

| Option | Description | Selected |
|--------|-------------|----------|
| Resolve-then-contain | Canonicalize the parent (resolving symlinks); accept iff contained in the allowed root. A symlink staying inside is fine; only an escape is rejected. Matches WR-03's "symlink-resolved escape". | ✓ |
| Reject any symlink | Reject any symlinked component like the REVIEWS.md evidence guard (`:470`). Over-broad here — that guard is deliberately asymmetric for evidence, not edit targets. | |

**User's choice:** Resolve-then-contain.
**Notes:** Mirrors the current-phase pointer's canonicalize-and-contain treatment (`:270-272`).

---

## WR-03 containment root & ordering

### Q1 — How does the guard get a root (it runs before repo-root location)?

| Option | Description | Selected |
|--------|-------------|----------|
| Hoist repo-root above the bypass | Move repo-root self-location up to just after the GSD_SKIP_REVIEWS hatch; contain against `$REPO_ROOT/.planning`. Verdict stays cwd-independent. Bigger diff; re-verify T-08-* ordering. | ✓ |
| cwd-relative canon in place | No reorder; `_canon_dir '.planning'` relative to cwd. Smaller diff, but bypass silently no-ops from a nested subdir (still safe, falls to gate). | |

**User's choice:** Hoist repo-root above the bypass.
**Notes:** Keeps the script's own stated principle (cwd-independent verdicts, `:157-164`) true for the `--file` guard. GSD_SKIP_REVIEWS stays step 1.

### Q2 — What is the allowed root?

| Option | Description | Selected |
|--------|-------------|----------|
| `$REPO_ROOT/.planning` only | Contain strictly within this repo's `.planning`. Tightens the guard — a vendored `*/.planning/*` no longer bypasses (falls to gate). Flag the behavior change. | ✓ |
| Preserve `*/.planning/*` too | Also accept nested `.planning` dirs, matching the current lexical prefix exactly. Zero behavior change but re-introduces the looser surface; no evidence any workflow needs it. | |

**User's choice:** `$REPO_ROOT/.planning` only.
**Notes:** Intentional correctness improvement (don't bypass this repo's gate via a sub-project's planning doc). The `*/.planning/*` tightening must be flagged in SUMMARY + ADR marker, not silent.

---

## ADR-0009 Phase 12 vs 13 coordination

### Q1 — What does Phase 12 write into ADR-0009?

| Option | Description | Selected |
|--------|-------------|----------|
| In-place marker, no Correction section | Edit decision 12 in place ("Reversed (Phase 12, WR-03)") + mark Open-follow-up resolved; no Correction section. Phase 13's DOC-03 authors the single consolidated Correction. | ✓ |
| Phase 12 opens the Correction section | Phase 12 creates the Correction with just d.12; Phase 13 appends the rest. Both touch the same region — the two-PRs-racing hazard. | |
| Defer all ADR text to Phase 13 | Phase 12 records d.12 reversal only in its SUMMARY/commit; ADR untouched. Contradicts the roadmap's "this phase's ADR-0009 touch lands before Phase 13's." | |

**User's choice:** In-place marker, no Correction section.
**Notes:** Respects the roadmap sequencing; the Correction section is written exactly once (Phase 13). CONTEXT D-09 additionally requires the marker to describe the mechanism actually shipped (parent-canonicalization), not the ADR's speculative walk-each-prefix description.

---

## REV-04 doc-fix depth

### Q1 — How much should Phase 12 write to `docs/decisions/README.md`?

| Option | Description | Selected |
|--------|-------------|----------|
| Normative convention subsection | State the two series are independent AND prescribe "always qualify as `ADR-NNNN` or `migration NNNN`, never bare `NNNN`", with the ADR-0010→migration-0009 collision as the worked example. | ✓ |
| Single clarifying sentence | One line: "ADR-NNNN numbering is independent of migration-NNNN." Satisfies SC#5's letter but gives no forward rule. | |

**User's choice:** Normative convention subsection.
**Notes:** REV-04 is cited as the constraint the roadmapper honors when assigning Phase 13/14 migration numbers, so a bare sentence is too thin.

---

## Claude's Discretion

- Fixture file naming/placement within `run-tests.sh` (and `test-fixtures/` reuse) for the new WR-03 and REV tests — provided each new assertion is independently mutation-proven and the verifier re-runs the RED→GREEN cycle.
- Exact wording of the ADR-0009 in-place marker and the REV-04 README subsection, within the contracts fixed by D-08/D-09/D-10.
- Whether the WR-03 containment logic factors into a shared function or inlines, as long as `_canon_dir`/`_is_contained` are reused not reinvented (SC#1).

REV-01/REV-02/REV-03 were not put to the user as gray areas — their success criteria fully prescribe the approach (recorded as D-11/D-12/D-13 in CONTEXT.md).

## Deferred Ideas

- DOC-03 — the full dated ADR-0009 Correction section → Phase 13.
- IN-04 — predictable temp-file names in CWD → Phase 14 (MARK-04's `mktemp`, by supersession).
- WR-01 — the strip's single-`##`-heading coupling to the mirror → open debt, explicitly not folded into MARK scope.
