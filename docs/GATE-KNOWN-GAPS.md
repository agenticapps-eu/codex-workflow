# Known gaps — `bin/openspec-change-gate.sh`

**Status:** open · **Recorded:** 2026-07-25 · **Closes when:** the canonical
gate is published in `agenticapps-workflow-core` and this repo re-syncs to it.

This repo ships the §18 change-gate **byte-identical** to the copy
`opencode-workflow` merged, because §18's design is ONE shared enforcement
script rather than a per-host re-authoring. That copy has four verified defects.
They are recorded here — with reproductions — rather than patched locally,
because patching locally would fork the shared script a fifth way and is not
this repo's call to make.

**This repo does not own the fix.** `agenticapps-workflow-core` is working the
canonical gate in parallel; `claude-workflow` carries its own
`bin/GATE-DIVERGENCE.md` recording three of the same four. Codex's job is to
make its exposure visible and testable until the canonical lands.

## Pinned fingerprint

```
a32678b32c40fb0f2ba1740b9663c178687bf99ef10821c88a77c52c1bbdfdb0
```

`test_gate_known_gaps` pins this. If `bin/openspec-change-gate.sh` changes —
which is what re-syncing to the fixed canonical looks like — the suite fails
loudly and demands every gap below be re-verified before this file is updated
or deleted. A gap must never be assumed fixed because the script moved.

## The gaps

Every reproduction below assumes a repo with an active, unreviewed change:

```sh
git init -q . && mkdir -p openspec/changes/active-change
GATE=~/.agenticapps/bin/openspec-change-gate.sh
```

`OPENSPEC_BIN=true` stubs `openspec validate --all` green, isolating the branch
under test.

### GAP-1 — the gate is cwd-relative, so it fails open from any subdirectory

`changes_dir="openspec/changes"` is resolved against the current working
directory; the script never calls `git rev-parse --show-toplevel`. From a
subdirectory it finds no `openspec/changes`, concludes there is no active
change, and allows the edit — logging a line that reads like a correct
decision, which is what makes it dangerous.

```sh
printf '{"tool":"edit","tool_input":{"file_path":"main.go"}}' | OPENSPEC_BIN=true bash "$GATE"
#   from repo root : exit 2  BLOCK
#   from sub/dir   : exit 0  ALLOW (no openspec/changes — nothing to gate)
```

Exposure: `.git/hooks/pre-commit` is safe (git runs hooks from the worktree top
level) and `bin/openspec-gate-ci.sh` is safe (it `cd`s to `$ROOT`). The exposed
surface is the `PreToolUse` hook, whose cwd is the session's.

Found by codex's own review of PR #25.

### GAP-2 — the `openspec/**` exemption matches any path component named `openspec`

The exemption is `case "$rel" in openspec/*|*/openspec/*)`, so any file under
*any* directory named `openspec/` is treated as a change artifact and edited
freely while the gate is unsatisfied — including paths outside the repo, since
an absolute path that does not start with `$PWD` is left absolute and still
matches `*/openspec/*`.

```sh
printf '{"tool":"edit","tool_input":{"file_path":"src/openspec/app.ts"}}'  | OPENSPEC_BIN=true bash "$GATE"  # exit 0
printf '{"tool":"edit","tool_input":{"file_path":"/tmp/openspec/evil.ts"}}' | OPENSPEC_BIN=true bash "$GATE"  # exit 0
```

This is the serious one: it is a live bypass of the gate, not a corner case.
Found by the cross-AI review of `claude-workflow` PR #95.

### GAP-3 — reviewer counting counts headings, not independent reviewers

`grep -cE '^##[[:space:]]+Reviewer:'` counts matching lines. It does not skip
fenced code blocks and does not require distinct vendors, so both of these
satisfy the "≥2 independent reviewers" rule with zero reviews performed:

```sh
# two headings, one vendor
printf '# r\n\n## Reviewer: gemini\nx\n\n## Reviewer: gemini\ny\n' > openspec/changes/active-change/REVIEWS.md   # exit 0

# headings inside a fenced example block
printf '# r\n\n```markdown\n## Reviewer: gemini\n## Reviewer: claude\n```\n' > openspec/changes/active-change/REVIEWS.md   # exit 0
```

The `codex-openspec-change-review` producer names both as failure modes and
refuses to do either — but the *gate* is the enforcement surface, and it cannot
tell the difference. Found by the cross-AI review of `claude-workflow` PR #95.

### GAP-4 — unparseable stdin falls through to policy instead of failing open

§18 requires failing open on a **parse** error and never on policy. Empty stdin
and brace-garbage do fail open correctly. Whitespace-containing non-JSON does
not: the plain `"TOOL<TAB>PATH"` test-line branch strips the first field and
treats the remainder as a path, so `not json at all` parses to the path
`json at all`, which is non-empty and proceeds to policy evaluation.

```sh
printf ''                | OPENSPEC_BIN=true bash "$GATE"   # exit 0  correct
printf '{{{'             | OPENSPEC_BIN=true bash "$GATE"   # exit 0  correct
printf 'not json at all' | OPENSPEC_BIN=true bash "$GATE"   # exit 2  WRONG — policy on a parse error
```

Recorded honestly: codex observed this behaviour during the PR #25 work,
judged it a §18 grey area, and left it in order to preserve byte-identity with
the opencode copy. That was a rationalisation — unparseable stdin is a parse
error by any reading. `claude-workflow`'s review classified it correctly.

## To close this

1. `agenticapps-workflow-core` publishes `gate/` (it is currently untracked and
   absent from `origin/main` — the root cause of the four-way fork) with the
   four gaps fixed.
2. This repo re-syncs: `cp <core>/gate/openspec-change-gate.sh bin/`.
3. `test_gate_known_gaps` fails on the fingerprint change. Re-run every
   reproduction above; each must flip to the expected result.
4. Convert the gap assertions to hard requirements in `test_migration_0013`,
   and delete this file.
