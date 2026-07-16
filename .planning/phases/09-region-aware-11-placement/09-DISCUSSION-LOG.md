# Phase 9: Region-Aware §11 Placement - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-15
**Phase:** 9-Region-Aware §11 Placement
**Areas discussed:** Block strip boundary, Move verbatim vs re-vendor, Fixture extraction mechanism, Absent AGENTS.md + malformed region

---

## Area selection

All four offered gray areas were selected for discussion.

Areas were derived from scouting rather than a generic category list. The
decisive discovery: **migration 0004 already implements strip-then-reinject** —
structurally what State B needs — but delimits the block by matching §11's last
prose line, and prose drift in that exact block is why 0004 had to exist. The
reference design does not address the strip boundary at all.

---

## Block strip boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Structural: next `## ` or EOF | Block = provenance → own `## ` heading → up to next `/^## /` or EOF. Uses the invariant ANCHOR-05 already guarantees. Content-agnostic, bounded. | ✓ |
| Content sentinel (0004's shape) | Reuse `/session-level discipline the model brings to every diff\.$/`. Consistent with 0004 and already covered by run-tests.sh. | |
| Structural + verbatim assertion | Structural, plus assert the stripped span is byte-identical to the mirror; abort otherwise. | |

**User's choice:** Structural: next `## ` or EOF

**Notes:** Grounded in a verified fact — the mirror is 79 lines with exactly one
`## ` (its own heading at L1); its four subsections are `### `, which does not
match awk's `/^## /`. Structural is therefore viable.

Decisive against the content sentinel: a **runaway-strip hazard** found during
scouting. 0004's awk is `inblk {next}` until the sentinel matches, so if §11's
last line ever changes, the strip never terminates and **deletes the rest of the
file**. 0004 escaped this only because its own drift (75→79 lines) added blanks
*inside* the block, leaving the closing line intact.

Rejecting the assertion variant (option 3) was itself meaningful: it would make a
drifted-but-managed block **refuse to be placed**, turning 0004's content problem
into 0009's placement problem. Recorded as D-26: strip blind, trust the invariant.

**Knock-on effect** (recorded, not separately asked): choosing structural collapses
States B and C onto one code path, and MIGR-07 (leave healthy-but-off-anchor blocks
alone) falls out of the idempotency predicate rather than needing a special case.

---

## Move verbatim vs re-vendor

| Option | Description | Selected |
|--------|-------------|----------|
| Re-vendor from the mirror | Strip, then re-inject fresh from the spec mirror — what 0001 and 0004 both do. One code path for States B and C. | ✓ |
| Relocate existing bytes verbatim | Capture the stripped span, re-emit unchanged. Strictly a placement fix; drift stays 0004's problem. Costs a second code path. | |

**User's choice:** Re-vendor from the mirror

**Notes:** Consistent with both existing §11 migrations, and unifies the inject
path. Two consequences recorded rather than left implicit (D-28): the pre-flight
must verify the mirror exists (0004's shape), and a State-B move now **silently
repairs a drifted block** as a side effect — which belongs in the ADR as a stated
consequence, not an accident.

---

## Fixture extraction mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Native idiom + ported extractor | `test_migration_0009` in run-tests.sh with six printf-synthesized cases, plus claude-workflow's fence-extractor and shape assertion. | ✓ |
| Port claude-workflow's fixture dirs | `test-fixtures/0009/{01..06}/` with common-setup.sh + common-verify.sh, mirroring claude-workflow 1:1. | |
| Native + shared-lib extractor | As selected, but the extractor lands in `vendor/agenticapps-shared` so both hosts share one implementation. | |

**User's choice:** Native idiom + ported extractor

**Notes:** The deciding fact was found by reading this repo's own contract:
`migrations/test-fixtures/README.md` has a **"Why no static fixture files"**
section that explicitly rejects checked-in fixture directories — the exact layout
claude-workflow uses. Porting it would contradict this repo's documented contract
and add a second competing idiom. The README's "Limits" section authorizes
synthesized fixtures for state git refs can't capture, which is precisely 0009's
six shapes.

Option 3 (shared-lib extractor) was genuinely stronger in principle — it kills the
drift class structurally rather than detecting it — but `vendor/agenticapps-shared`
is a submodule, making it cross-repo work with its own PR and version bump before
Phase 9 could go GREEN.

The ported shape assertion (D-36) is the antidote to the dead-by-construction
defect Phase 8 hit three times. The reference's own comment is the rationale:
*"Non-empty is not the same as correct."*

---

## TEST-04 blast radius

| Option | Description | Selected |
|--------|-------------|----------|
| Just `:119`, the named site | Convert the §11 injection copy; leave 0008's inline copies alone. Log the rest as follow-up. | ✓ |
| All inlined migration shell in the harness | Also convert 0008's Step-3 copy (~:985) and any others. Kills the whole class. | |
| Only 0009's own fixtures | New fixtures document-sourced; existing copies untouched. Leaves TEST-04 unmet. | |

**User's choice:** Just `:119`, the named site

**Notes:** Clarified during the question that `:119` inlines **0001's** awk, and
0001 is legitimately naive and immutable — so document-sourcing it faithfully
asserts 0001's naive behavior. A fidelity improvement, not a behavior change, and
no conflict with TEST-02 (which concerns 0009's fixtures going RED). 0008's ~:985
copy logged as deferred.

---

## Absent AGENTS.md

| Option | Description | Selected |
|--------|-------------|----------|
| Informational skip, still bump | Step 1 reports and returns success; Step 2 still records 0.7.0. Matches the reference design's `04-no-claudemd`. | ✓ |
| Abort in pre-flight (0004's shape) | `test -f AGENTS.md || exit 1`. Consistent with 0004/0001; surfaces an impossible state loudly. | |

**User's choice:** Informational skip, still bump

**Notes:** The deciding argument is mechanical, not stylistic: the update engine
marks a migration pending iff `installed >= from_version && installed < to_version`.
An abort would strand the project at `0.6.0` **permanently** — 0010+ would never
become pending. A deliberate divergence from 0004's pre-flight (`0004:44`),
recorded as such.

---

## Malformed region (gitnexus:start with no gitnexus:end)

| Option | Description | Selected |
|--------|-------------|----------|
| Fail closed — treat as in-region, move it | `in_region = prov > start AND (end == 0 OR prov < end)`. Block moved above the start marker to safety. | ✓ |
| Fail open — treat as not-in-region, skip | Only a well-delimited start..end pair counts. Conservative about touching malformed files. | |
| Refuse — exit 3 | A malformed region is a state 0009 shouldn't reason about. | |

**User's choice:** Fail closed — treat as in-region, move it

**Notes:** Same outcome as the well-formed case, so no separate branch and no extra
fixture. Fail-open was rejected because it leaves the block inside something
gitnexus may still regenerate — the exact defect this migration exists to close.
Noted that the anchor rule itself is unaffected either way (it only needs `start`);
this only bites the region predicate that decides skip-vs-move.

---

## Claude's Discretion

- Exact awk implementation of the anchor alternation, structural strip, and
  line-number region predicate — mechanics, not policy.
- Plan/wave decomposition, subject to ROADMAP.md's two hard orderings
  (validate-before-write; RED-before-GREEN).
- Whether the empirical anchor validation is a throwaway script or a committed
  harness addition — but its evidence must be recorded either way.
- ADR number and its exact section shape.

---

## Findings that changed scope (verification, not discussion)

These were established by checking rather than by asking, and are recorded here
because they altered the phase's shape:

1. **claude-workflow's migration 0029 does not exist.** Only the approved design
   (dated today) and RED fixtures. This is concurrent propagation of a design, not
   a port of shipped code — there is nothing to diff against.
2. **A third rejected alternative exists** that the source prompt never mentioned:
   *"always immediately after the H1."* DOC-01 must record both rejections.
3. **§12's placement advisory is advisory** — `spec/12:95-97` says lower-case
   "should", not RFC 2119, not a conformance gate. Both the prompt and the
   reference design phrase this loosely; the ADR must not overclaim.
4. **§08 resolves SETUP-01.** End state is normative, not mechanism; replay and
   snapshot are both conformant. This host is replay (setup walks 0000-baseline
   only, landing at `0.1.0`); claude-workflow is snapshot — which is exactly why it
   needs a parity guard and we do not.
5. **The multi-hop defect has a verified consequence.** A freshly scaffolded
   project at `0.1.0` cannot walk the chain to `0.7.0` in one invocation. This
   bounds what SETUP-01 can honestly claim. Recorded, not fixed.
6. **Migrations 0002/0003 declare `from == to`** and can never be pending — dead
   migrations. Incidental find; logged for separate investigation.

## Deferred Ideas

- De-inline 0008's Step-3 insert-awk copy (`run-tests.sh` ~:985)
- Investigate migrations 0002/0003's `from_version == to_version`
- The update skill's multi-hop chain-selection defect (carried from Phase 8)
- `implements_spec` 0.4.0 → 0.5.0+ (D-17 stands)
- Native `~/.codex/hooks.json` PreToolUse enforcement (HOOK-01)
- Real CI (CI-01) — the placeholder still echoes and exits 0
- WR-03 — lexical-`..`-only symlink guard
- Upstream note to claude-workflow: codex implemented from the design, not the code
