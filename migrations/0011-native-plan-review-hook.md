---
id: 0011
slug: native-plan-review-hook
title: Install the native PreToolUse plan-review hook — HOOK-03 (v0.7.0 -> 0.8.0)
from_version: 0.7.0
to_version: 0.8.0
applies_to:
  - .codex/hooks.json
  - .codex/config.toml
requires: []
optional_for: []
---

# Migration 0011 — Native PreToolUse plan-review hook (v0.7.0 -> 0.8.0)

Implements `HOOK-03` (phase `13-native-enforcement-plan-review-hook`): installs
the codex-cli **native** `PreToolUse` surface for the plan-review gate, closing
the "agent-mediated, not enforced" acceptance ADR-0009 decision 9 recorded and
HOOK-01 supersedes. This is the PROJECT-scoped layer decision 9 believed did
not exist — DOC-03's factual correction (`13-RESEARCH.md`, "Hooks Discovery
Order") establishes that `<repo>/.codex/hooks.json` and `<repo>/.codex/config.toml`
are both documented, discovered, project-scoped layers, not merely the
operator's global `~/.codex/*`.

**This migration writes exactly two project-scoped files, never the operator's
global `~/.codex/*`** (13-01-SPIKE-FINDINGS.md Pitfall 3, reaffirmed by A1):

1. `<repo>/.codex/hooks.json` — merges ONE `PreToolUse` entry pointing at the
   wrapper (`skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh`,
   shipped by plan `13-02`), leaf-level `jq` array-append onto
   `.hooks.PreToolUse`, never a wholesale replacement of `.hooks` or
   `.hooks.PreToolUse` — this machine's own live multi-vendor hooks.json
   proves a pre-existing unrelated vendor's entries in the SAME array are a
   real, not hypothetical, collision surface.
2. `<repo>/.codex/config.toml` — merges `[features] hooks = true`, awk
   append-if-absent, no new TOML-parsing dependency (mirrors the
   `agents-md-additions.md` marker-block append idiom). 13-01-SPIKE-FINDINGS.md's
   A1 line is **CONFIRMED**: a project-scoped `[features] hooks = true`
   genuinely overrides the machine-wide default, so this step's write is
   effective on its own — no operator global-enable fallback is needed (see
   `## Notes`).

**Two files, two file TYPES, never confused with each other or with a
different, unrelated file this repo already has.** Migration 0008's
destination — the host-scoped declarative gate-binding map under
`.planning/`, which other agents read as advisory config — is a completely
different system from codex-cli's own NATIVE, binding, runtime-enforced
`.codex/hooks.json` / `.codex/config.toml` this migration touches
(13-RESEARCH.md Pitfall 1). This migration never touches that declarative
binding map; its `applies_to` list above names only the two native files.

**Matcher decision (13-01-SPIKE-FINDINGS.md, FROZEN):** the `PreToolUse` entry
carries `"matcher": "apply_patch"` — STEP 7 of the spike proved `apply_patch`
IS covered by `PreToolUse` on codex-cli 0.144.4; no `Bash`-matcher arm is
needed (RESEARCH.md Open Question 1).

## Correction — 2026-07-19 (live verification, debug session `codex-hook-not-firing`)

The first live end-to-end verification of this migration (plan `13-05`, on
codex-cli 0.144.6) found that **as originally authored, this migration installed
a hook that never fired.** Two stacked defects, both now fixed above:

1. **Malformed entry schema (silent).** Step 1 wrote the entry FLAT —
   `{"matcher","type","command"}` — but codex-cli expects the matcher group to
   carry a nested `hooks` array: `{"matcher", "hooks":[{"type","command"}]}`.
   A malformed entry is **dropped with no error and no warning**: `/hooks`
   simply did not count it (`PreToolUse: Installed 2` — exactly the two
   pre-existing global hooks). Corrected in Step 1's Idempotency check, Apply,
   Rollback, and Post-check 1, and pinned by `run-tests.sh`
   (`test_migration_0011` asserts the nested shape explicitly, so a regression
   to the flat form fails the suite rather than shipping silently).

2. **Gate B trust left un-surfaced.** The original Skip-cases called the
   interactive hook-trust "not this migration's concern". That framing is what
   made the failure invisible: with the schema fixed the entry loaded but sat
   at `Installed 3, Active 2, Review 1` — **installed but not permitted to
   run** — and an untrusted hook enforces nothing while looking installed. The
   migration still (correctly) does not automate the trust action, but it must
   not treat it as out of scope: Post-check 4 now REQUIRES the operator to
   confirm `Active`, and Step 3's version seal is explicitly not a claim that
   enforcement is live.

**Why the spike missed both.** 13-01-SPIKE-FINDINGS.md validated the mechanism
in a throwaway repo where the operator had granted hook trust by hand — that
trust entry is still visible in `~/.codex/config.toml`
(`[hooks.state."/private/tmp/gsd-phase13-spike/spike-repo/.codex/hooks.json:pre_tool_use:0:0"]`).
The spike's conclusion was true **of the spike repo** and did not transfer,
because the step that made it true was never carried into the migration. A
spike that hand-configures its environment must record that configuration as a
migration requirement, not just its own result.

**Verified fixed:** with both corrections applied, a disallowed `apply_patch`
edit was denied end-to-end in a live operator-observed session — codex reported
`PreToolUse hook (blocked)`, the wrapper's own `Source: native-hook` label
appeared in the denial, `~/.codex/hook-wrapper-plan-review.log` recorded
`tool_name=apply_patch`, and the target file was never created.

**The one-time interactive hook-trust action is NOT automated here, and must
never be.** codex-cli's trust ledger is two independent gates — project trust
(`[projects.<path>] trust_level`) and per-hook trust
(`[hooks.state.<key>] trusted_hash`) — and Gate B is set only by an
INTERACTIVE trust flow the operator runs once (`/hooks`, or the startup
hooks-review prompt). Pre-seeding `trusted_hash` was investigated in the spike
and found **both forbidden (Pitfall 3) and not reproducible black-box**
(13-01-SPIKE-FINDINGS.md, SPIKE item 1) — this migration does not attempt it.
See `## Notes`.

## Pre-flight

```bash
# Project root must be a git repo (repo-name derivation + atomic commit)
test -d .git || { echo "not a git repo — initialize first with: git init"; exit 1; }

# jq is required for the hooks.json merge (mirrors 0008's hard requirement)
command -v jq >/dev/null || { echo "ABORT: jq not found — required for the hooks.json merge"; exit 2; }

# Workflow project version is at the supported floor (0.7.0), or 0.8.0 for
# re-apply. Reuses 0008's `.codex/workflow-version.txt`-only floor pattern —
# NEVER a `skills/**` grep (the V-01 defect class: no target project has a
# local `skills/` tree; the setup skill's project-side surface is AGENTS.md,
# .planning/, .codex/, and docs/decisions/ only).
grep -qE '^0\.(7|8)\.0$' .codex/workflow-version.txt || {
  INSTALLED=$(cat .codex/workflow-version.txt 2>/dev/null)
  echo "ABORT: project version is $INSTALLED (need 0.7.0)."
  echo "       Apply prior migrations first via \$update-codex-agenticapps-workflow."
  echo "       Supported upgrade floor: 0.7.0 -> 0.8.0."
  exit 3
}

# The wrapper must ship before the migration that wires it — a hooks.json
# entry pointing at a missing wrapper is a gate that silently never fires
# (mirrors 0008's check-plan-review.sh pre-flight guard, T-08-25).
CODEX="${CODEX_HOME:-$HOME/.codex}"
test -f "$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh" || {
  echo "ABORT: hook-wrapper-plan-review.sh missing — reinstall the scaffolder (bash install.sh)"; exit 4; }
```

## Steps

### Step 1: Merge the `PreToolUse` entry into `<repo>/.codex/hooks.json`

The destination is codex-cli's own NATIVE hooks file — a new file type for
this repo's migrations, distinct from migration 0008's declarative binding
map under `.planning/` (Pitfall 1 above).

**Idempotency check:** the entry is absent (matched by the wrapper's own
command string, not by array position — a pre-existing vendor may already
occupy index 0):
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
WRAPPER="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
jq -e --arg cmd "$WRAPPER" \
   '(.hooks.PreToolUse // [])[] | (.hooks // [])[] | select(.command == $cmd)' \
   .codex/hooks.json >/dev/null 2>&1
```
(Returns 0 when the wrapper's entry already exists — a prior run of this
migration, or a hand-installed identical entry; this step is then a no-op.)

**Note the nested `(.hooks // [])[]` hop.** A matcher group holds its commands
in a nested `hooks` array; the command is NOT a group-level key. Reading it at
the group level (the pre-2026-07-19 form) never matches, which would make this
check report "absent" on every run and append a duplicate entry each time.

**Pre-condition:** the wrapper ships (checked in pre-flight); `jq` available.

**Apply:**
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
WRAPPER="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"

mkdir -p .codex
if [ ! -f .codex/hooks.json ]; then
  echo '{"hooks":{"PreToolUse":[]}}' > .codex/hooks.json
fi

# Leaf-level jq array-append. NEVER `.hooks.PreToolUse = [...]` (a wholesale
# assignment) and NEVER `.hooks = {...}` — either form silently deletes a
# pre-existing unrelated vendor's PreToolUse entries or other hook-event
# groups in the SAME file. `(. // [])` handles the first-run case where
# `.hooks.PreToolUse` does not exist at all yet (T-13-04).
#
# SCHEMA (corrected 2026-07-19): the matcher group carries a NESTED `hooks`
# array — {"matcher": ..., "hooks": [{"type","command"}]}. The flat form
# {"matcher","type","command"} is silently DROPPED by codex-cli: no error, no
# warning, and `/hooks` simply does not count the entry. See ## Correction.
jq --arg cmd "$WRAPPER" \
   '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"apply_patch","hooks":[{"type":"command","command":$cmd}]}])' \
   .codex/hooks.json > .codex/hooks.json.tmp \
  && mv .codex/hooks.json.tmp .codex/hooks.json
```

**Rollback:** remove only the entry whose `command` matches the wrapper; drop
`.hooks.PreToolUse` only if then empty, and `.hooks` only if then empty too —
never touch a sibling vendor's entries or event groups (T-13-04):
```bash
CODEX="${CODEX_HOME:-$HOME/.codex}"
WRAPPER="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
# Drops the whole matcher GROUP whose nested hooks array carries the wrapper's
# command. A sibling vendor's group — even one sharing the same matcher — is
# selected on its own nested commands and therefore preserved.
jq --arg cmd "$WRAPPER" \
   '.hooks.PreToolUse = [(.hooks.PreToolUse // [])[]
       | select(([(.hooks // [])[] | .command] | index($cmd)) == null)]
    | if (.hooks.PreToolUse // []) == [] then del(.hooks.PreToolUse) else . end
    | if (.hooks // {}) == {} then del(.hooks) else . end' \
   .codex/hooks.json > .codex/hooks.json.tmp \
  && mv .codex/hooks.json.tmp .codex/hooks.json
```

### Step 2: Enable the hooks feature flag in `<repo>/.codex/config.toml`

Project scope only — never `${CODEX_HOME}/config.toml` (Pitfall 3). A NEW file
type for this repo's migrations: 0000-baseline and 0008 only ever wrote
`.codex/workflow-config.md`, `.codex/workflow-version.txt`,
`.planning/config.json`, migration 0008's declarative binding map, and
`AGENTS.md`. TOML merging uses an awk append-if-absent block rather than
introducing a new TOML-parsing dependency (13-RESEARCH.md's explicit
recommendation).

**Idempotency check:** `[features]` already carries `hooks = true`:
```bash
awk '
  /^\[features\]/ { infeatures=1; next }
  /^\[/ { infeatures=0 }
  infeatures && /^hooks[ \t]*=[ \t]*true[ \t]*$/ { found=1 }
  END { exit !found }
' .codex/config.toml 2>/dev/null
```
(Returns 0 when `hooks = true` is already present inside `[features]` — a
prior run of this migration, or a hand-configured install; this step is then
a no-op.)

**Pre-condition:** none beyond the pre-flight's git-repo check — the file may
be entirely absent, and Apply creates it.

**Apply:**
```bash
mkdir -p .codex
if [ ! -f .codex/config.toml ]; then
  # Fresh file: the `[features]` block MUST contain `hooks = true` and
  # NOTHING else (13-01-SPIKE-FINDINGS.md: `[features]` is strictly typed
  # and fail-closed — any non-boolean key bricks codex startup for the
  # repo, naming the exact file path in the error).
  printf '[features]\nhooks = true\n' > .codex/config.toml
elif grep -q '^\[features\]' .codex/config.toml; then
  # An existing `[features]` table: insert/replace ONLY the `hooks` key
  # inside it, scoped to that table — every other table (T-13-05: a decoy
  # `[some_other]` table) and every other key inside `[features]` itself
  # is preserved untouched.
  awk '
    /^\[features\]/ { print; infeatures=1; next }
    /^\[/ { if (infeatures && !wrote) { print "hooks = true"; wrote=1 }; infeatures=0 }
    infeatures && /^hooks[ \t]*=/ { print "hooks = true"; wrote=1; next }
    { print }
    END { if (infeatures && !wrote) print "hooks = true" }
  ' .codex/config.toml > .codex/config.toml.tmp && mv .codex/config.toml.tmp .codex/config.toml
else
  # File exists but carries no `[features]` table at all — append a new
  # table at EOF, never touching any existing table (e.g. an operator's
  # project-scoped MCP/sandbox settings) already in the file.
  printf '\n[features]\nhooks = true\n' >> .codex/config.toml
fi
```

**Rollback:** remove only the `hooks = true` line; drop the `[features]`
table too if it becomes empty (i.e. this migration created it fresh) — never
touch a sibling table:
```bash
awk '
  /^\[features\]/ { in_features=1; header=$0; buf=""; next }
  /^\[/ {
    if (in_features) { if (buf != "") { print header; printf "%s", buf } }
    in_features=0
    print
    next
  }
  {
    if (in_features) {
      if ($0 !~ /^hooks[ \t]*=[ \t]*true[ \t]*$/ && $0 !~ /^[ \t]*$/) { buf = buf $0 "\n" }
      next
    }
    print
  }
  END { if (in_features && buf != "") { print header; printf "%s", buf } }
' .codex/config.toml > .codex/config.toml.tmp && mv .codex/config.toml.tmp .codex/config.toml
```

### Step 3: Record `0.8.0` in `.codex/workflow-version.txt`

Sealed LAST, per 0008's content-steps-then-version-seal convention.

**Idempotency check:** `grep -q '^0.8.0$' .codex/workflow-version.txt 2>/dev/null`

**Pre-condition:** `.codex/` exists (Steps 1/2 already create it if absent).

**Apply:** `echo "0.8.0" > .codex/workflow-version.txt`

**Rollback:** `echo "0.7.0" > .codex/workflow-version.txt`

**This repo's own scaffolder bump (direct edit, not a migration step, this
commit):** this repo's own scaffolder trigger skill's SKILL.md
`version: 0.7.0` -> `0.8.0`, and this repo's own
`.codex/workflow-version.txt` -> `0.8.0` — matching 0008 Step 4's precedent
that a target project's local scaffolder file is never bumped by a migration
step (no target project has one; see 0008's `## Notes`).

## Post-checks

```bash
# 1. hooks.json carries the wrapper's PreToolUse entry, matcher apply_patch,
#    in the NESTED schema (ALWAYS true on success — sibling vendor entries, if
#    any, are untouched but not asserted here since their presence is
#    install-specific). The `.hooks[]` hop is load-bearing: it is what fails
#    if the entry regresses to the silently-dropped flat form (## Correction).
CODEX="${CODEX_HOME:-$HOME/.codex}"
WRAPPER="$CODEX/skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh"
jq -e --arg cmd "$WRAPPER" \
   '(.hooks.PreToolUse // [])[]
      | select(.matcher == "apply_patch")
      | (.hooks // [])[]
      | select(.command == $cmd and .type == "command")' \
   .codex/hooks.json >/dev/null

# 2. config.toml's [features] table carries hooks = true (ALWAYS true on success)
awk '
  /^\[features\]/ { infeatures=1; next }
  /^\[/ { infeatures=0 }
  infeatures && /^hooks[ \t]*=[ \t]*true[ \t]*$/ { found=1 }
  END { exit !found }
' .codex/config.toml

# 3. Project version record bumped (ALWAYS true on success)
grep -q '^0.8.0$' .codex/workflow-version.txt
```

### 4. REQUIRED operator check — the hook must be ACTIVE, not merely installed

**Steps 1-3 passing does NOT mean the gate enforces anything.** An installed
but untrusted hook is inert, and looks identical to a working one from the
filesystem side. This check is the difference between "wired" and "enforcing",
and it cannot be automated — Gate B is an interactive human decision by design.

Run `codex` in the project, then `/hooks`, and read the `PreToolUse` row:

| Reading | Meaning | Action |
|---|---|---|
| `Review 1` / warning `1 hook needs review before it can run` | Installed but **INERT — enforces nothing** | Approve the entry ending `hook-wrapper-plan-review.sh` |
| `Active` count includes this hook, `Review 0` | Enforcing | Done |
| Count unchanged from before the migration | Entry not parsed at all | Schema regression — see `## Correction` |

Optional hard proof that the hook actually dispatches (not just that codex
lists it): the wrapper appends one line per invocation, before any decision
logic, to `${CODEX_HOME:-$HOME/.codex}/hook-wrapper-plan-review.log`. A line
reading `tool_name=apply_patch` after an attempted edit is positive evidence
the NATIVE hook ran — and is the only signal that cannot be confused with the
prompt-based gate in `AGENTS.md`, whose block output is otherwise near-identical.

```bash
tail -3 "${CODEX_HOME:-$HOME/.codex}/hook-wrapper-plan-review.log" 2>/dev/null \
  || echo "(no invocations recorded yet)"
```

- Drift test green: this repo's own scaffolder trigger skill's SKILL.md
  `version` (0.8.0) == semver-max migration `to_version` across
  `migrations/*.md` (0.8.0) == this repo's own `.codex/workflow-version.txt`
  (0.8.0).

## Skip cases

Every skip is step-local — there is no migration-level skip predicate (the
same 0008/T-08-39 lesson: a migration-wide skip keyed on Step 1's artifact
would make skip-with-warning recovery a no-op that reports success).

- **`from_version` mismatch** (project not at 0.7.0) → migration framework
  skips silently. Projects below 0.7.0 replay the chain through 0009 first.
- **Step 1 already present** (the wrapper's entry already exists — a prior
  run, or a hand-installed identical entry) → Step 1 is a no-op; **Steps 2
  and 3 still run**.
- **Step 2 already present** (`[features] hooks = true` already set) → Step 2
  is a no-op; **Steps 1 and 3 still run**.
- **Step 3 already present** (`.codex/workflow-version.txt` already reads
  `0.8.0`) → Step 3 is a no-op.
- **No wrapper installed** → pre-flight aborts (`exit 4`) before any step
  runs — a hooks.json entry pointing at a missing wrapper is a gate that
  silently never fires (T-08-25's identical framing, applied here to HOOK-03).
- **Hook not yet interactively trusted (Gate B)** → the migration completes,
  but **enforcement is NOT yet live and the migration must say so.** This was
  previously worded as "not this migration's concern"; that framing is exactly
  what let an inert hook ship and be mistaken for a working one (see
  `## Correction`). The trust action itself still cannot and must not be
  automated — Gate B is an interactive human decision by design — but it is
  now a REQUIRED, surfaced completion step (Post-check 4), not a footnote.
  Distinguish this from 0008's "missing verifier CLI" split: there, the absent
  piece announces itself loudly at invocation time. Here, an untrusted hook
  fails **silently and open** — no error, no warning, and a `/hooks` row that
  looks installed. Silent-open failure is the one case a migration may not
  leave to the reader to notice.

## Compatibility

- **Additive (minor) bump** to `0.8.0`: no breaking change. Step 1 only adds
  a leaf entry to `.hooks.PreToolUse`, preserving every existing entry in that
  array and every other event group under `.hooks`; Step 2 only adds/updates
  the `hooks` key inside `[features]`, preserving every other table and every
  other key inside `[features]` itself.
- **Project-scoped, never global:** both files live at `<repo>/.codex/*`. This
  migration never writes `${CODEX_HOME}/config.toml` or
  `${CODEX_HOME}/hooks.json` — the operator's global trust ledger and hook
  registry are entirely outside this migration's authority (Pitfall 3).
- **Drift coupling:** as the highest-numbered migration file, 0011's
  `to_version` (0.8.0) is the drift target; this repo's own scaffolder
  trigger skill's SKILL.md is bumped to 0.8.0 in lockstep, in this same
  commit, as a direct edit to this repo (`run-tests.sh` `test_drift`).
- **Supported upgrade floor: 0.7.0 -> 0.8.0.** Every live project already
  sits at 0.7.0 after 0009.
- Per migration immutability, the chain stays contiguous
  (`0000` → … → `0009` → `0011`; `0010` is a version-backport into the
  0.4.0->0.5.0 slot, not part of the drift-target chain — see 0010's own
  framing note).

## Notes

- **Testable** non-interactively via `test_migration_0011` in
  `migrations/run-tests.sh`: it seeds a fixture `.codex/hooks.json` carrying
  a pre-existing unrelated vendor's `PreToolUse` entry and asserts BOTH
  entries survive Step 1's Apply (merge-don't-clobber, T-13-04); seeds a
  fixture `.codex/config.toml` carrying an unrelated `[some_other]` table and
  asserts it survives Step 2's Apply alongside `[features] hooks = true`
  (T-13-05); re-runs both Steps and asserts no duplicate entry / no duplicate
  flag (idempotent re-apply); and asserts a second, untouched sandbox repo
  with no `.codex/hooks.json` carries no plan-review `PreToolUse` entry
  (SC#4's negative half, by absence).
- **The one-time interactive hook-trust action is an EXPECTED operator
  action, not something this migration works around.** codex-cli's trust
  ledger is two independent gates (13-01-SPIKE-FINDINGS.md, STEP 6): Gate A
  (`[projects.<path>] trust_level`, project-directory trust) and Gate B
  (`[hooks.state.<key>] trusted_hash`, per-hook trust). **Trusting the repo
  alone is NOT sufficient to make this hook fire** — the operator must
  separately trust the HOOK, via `/hooks` or the startup hooks-review prompt,
  exactly once per new/changed hook. This migration writes only
  `<repo>/.codex/*`; it never pre-seeds a `trusted_hash` into the operator's
  `~/.codex/config.toml` — the spike found that both forbidden (Pitfall 3)
  and, independently, NOT reproducible black-box (13-01-SPIKE-FINDINGS.md,
  SPIKE item 1: 65 candidate hash inputs tried, none matched). Two prompts
  appear at first run (project trust + hook review), but a single approval
  flow writes both ledger entries in one shot (STEP 4) — one operator
  action, not two occasions.
- **A1 CONFIRMED — no global-enable fallback needed.**
  13-01-SPIKE-FINDINGS.md's A1 line settles RESEARCH.md's Assumption A1
  affirmatively: a project-scoped `[features] hooks = true` in
  `<repo>/.codex/config.toml` genuinely overrides the machine-wide default
  (proven by flipping the project layer against a global default of `true`
  and observing the project layer win). Step 2's write is therefore
  sufficient on its own; this migration does **not** instruct the operator
  to additionally enable `hooks` globally. (Had A1 been falsified, this
  section would instead direct the operator to `codex config set
  features.hooks true` globally — RESEARCH.md's named fallback — since a
  project-scoped write alone would not have activated the surface.)
- **`[features]` is strictly typed and fail-closed** (13-01-SPIKE-FINDINGS.md):
  a non-boolean value anywhere in that table is a hard `codex` startup error
  naming the file's exact path, not a warning. Step 2's Apply therefore
  writes `hooks = true` and nothing else when creating the table fresh, and
  never introduces a second key when merging into an existing one.
- **Mirrors** migration 0008's leaf-merge discipline (never assign a group
  key shallowly) and 0000-baseline Step 6's merge-don't-clobber precedent
  (idempotency-checked append-if-absent to a shared file) — applied here to
  a NATIVE codex-cli file for the first time in this repo's migration chain.

## References

- Phase: `13-native-enforcement-plan-review-hook`
- Spike (frozen): `.planning/phases/13-native-enforcement-plan-review-hook/13-01-SPIKE-FINDINGS.md`
- Research: `.planning/phases/13-native-enforcement-plan-review-hook/13-RESEARCH.md`
- Wrapper: `skills/agentic-apps-workflow/scripts/hook-wrapper-plan-review.sh` (plan `13-02`)
- This repo's ADR: `docs/decisions/0009-plan-review-gate.md` (decision 9, superseded by HOOK-01)
- Sibling precedent: `migrations/0008-plan-review-gate.md` (leaf-merge discipline),
  `migrations/0000-baseline.md` Step 6 (merge-don't-clobber)
- Numbering: `docs/decisions/README.md` — `migration 0011` is independent of
  any ADR number; it is NOT documented by ADR-0011 (no such ADR exists yet).
