# CR-01 — Runaway strip reproduction (orchestrator-verified)

Recorded 2026-07-15 during Phase 9's `code_review_gate`. Reproduced independently
by the orchestrator, not inherited from the reviewer's claim.

## What it is

`migrations/0009-spec-11-region-aware-placement.md` Step 1 strip pass destroys all
file content after the provenance line when provenance matches but the exact
`## Coding Discipline (NON-NEGOTIABLE)` heading is absent (drifted / renamed).

## Why it happens

The strip's **entry** condition and **exit** condition are decoupled:

```awk
BEGIN { in_block = 0; swallowed_own_h2 = 0 }
/<!-- spec-source: agenticapps-workflow-core@[^[:space:]]+ §11 -->/ {
  in_block = 1          # ENTRY: unanchored provenance substring
  next
}
in_block && !swallowed_own_h2 && /^## Coding Discipline \(NON-NEGOTIABLE\)$/ {
  swallowed_own_h2 = 1  # only the EXACT heading sets this
  next
}
in_block && swallowed_own_h2 && (/^## / || /^<!-- gitnexus:start -->$/) {
  in_block = 0          # EXIT is gated behind swallowed_own_h2
  swallowed_own_h2 = 0
  print
  next
}
in_block { next }       # <- eats every line to EOF
!in_block { print }
```

Heading drifted ⇒ `swallowed_own_h2` stays `0` ⇒ the exit rule can never fire ⇒
`in_block` latches at `1` ⇒ `in_block { next }` consumes the remainder of the file.

The widened terminator alternation — the thing this phase is *about* — sits inside
the exit rule, so it never gets a chance to run.

## Reproduction

Input (16 lines): provenance present, H2 drifted to `## Coding Discipline (RENAMED — drifted)`,
followed by `## Critical Project Rules` and `## Deployment`.

Output: **4 lines.** Everything from the provenance line to EOF destroyed.

```
# My Project

Intro prose.

```

## Why the guards do not catch it

All three post-strip guards pass:

1. `[ -s AGENTS.md.0009.strip ]` — passes; the output is non-empty (4 lines).
2. `grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md.0009.tmp` — passes,
   **because the insert pass re-adds the exact heading the guard looks for.** The
   guard meant to catch a bad strip is satisfied by the pass that follows it.
3. Version/frontmatter checks — unrelated to content loss.

`mv` then commits the truncated file over the user's `AGENTS.md`.

## Reachability

The Step 1 abort branch fires only when:

```sh
grep -q '^## Coding Discipline (NON-NEGOTIABLE)$' AGENTS.md && ! grep -qE "$PROV_RE" AGENTS.md
```

— i.e. **heading present AND provenance absent**. The runaway requires the
**inverse** (provenance present, heading absent), which falls straight through to
the `else` and into the strip. Reachable via:

- a drifted/renamed heading (hand-edited by a user),
- old-version provenance from an earlier migration,
- the orphaned-provenance state the document itself acknowledges at `:282`.

CR-02 compounds it: the provenance regex is unanchored, and 0009's own abort
message instructs operators to paste that exact provenance line into `AGENTS.md`.

## Provenance of the defect

**Faithful port, not a porting error.** Diffed against
`claude-workflow @ 8520f90:0029:192-210` — byte-identical modulo filename. Every
repo carrying 0029 is exposed. Fix locally *and* file upstream.

## What it falsifies

ADR-0010 decision D-26 claims the strip is "bounded by construction, so a drifted
block cannot cause a runaway." **That is false**, and it is load-bearing. This is
D-25's rejected bug class resurfacing inside the boundary chosen to prevent it —
exactly the dynamic decision 2 warns about with terminators.

ADR-0010 must be corrected in Phase 9.1.
