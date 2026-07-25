# Security review — adopt-canonical-change-gate

**Date:** 2026-07-25 · **Mode:** `/cso --code --diff` (daily, 8/10 confidence gate)
**Verification:** self-verified; independent sub-task not used (subagents not authorized this session)
**Machine-readable report:** `.gstack/security-reports/2026-07-25-change-gate-adoption.json` (gitignored)

## Verdict

**No findings at the 8/10 confidence gate.** One accepted risk is recorded below, and one
candidate was filtered — with its reasoning, rather than dropped silently.

This change is worth reviewing precisely because the artifact *is* a security control: the
gate decides whether code may be committed without independent review. A bypass here is not
a bug in a feature, it is the absence of the control.

## Why most phases have no trigger

The repo is markdown and shell. No package manifest, no Dockerfile, no IaC, no inbound
endpoints, no datastore, no user data, and no LLM prompts built from non-self-authored values
(§14 trivially conformant). Dependency supply chain, infrastructure, webhooks, LLM security,
and data classification have nothing to scan — recorded so the empty result reads as *scoped*
rather than *skipped*.

## Checks run

| Check | Result |
|---|---|
| Secrets in the branch diff (AKIA, `sk-`, `ghp_`, `xoxb-`, private keys, inline creds) | clean |
| `eval` / `exec` of untrusted values in the new shell | none — no `eval`; every command substitution is on a controlled value |
| Version-marker parsing | `grep`+`sed`+`tr`, charset-validated to digits and dots, no shell expansion |
| Lock handling | `mkdir` lock; `rm -rf` scoped to `"$DST.lock"` with `$DST` validated non-empty before use |
| Temp-file race on install | `mktemp` 0600 → `chmod 0755` → `mv -f`, inside a 0700 parent; window not exploitable |
| Shared execution path permissions | `~/.agenticapps` is `drwx------`; nothing under it is group- or world-writable |
| CI workflow injection via `${{ github.event.* }}` | none — the `BASE_SHA` interpolation went away with the base-ref plumbing |
| `pull_request_target` | not used |

## Accepted risk

**The shared gate path is an execution path, and the marker check is not an integrity
control.** (informational · confidence 9/10 · VERIFIED)

`bin/git-hooks/pre-commit` and the `PreToolUse` wrapper `exec` whatever resolves at
`~/.agenticapps/bin/openspec-change-gate.sh` — on every commit and every edit, for every repo
on the machine. This change adds a `# gate-version:` check before trusting that copy, and it
is important to be precise about what that buys: **a marker is a plain comment. Anyone who can
write the file can write the marker.** It discriminates pre-canonical copies from canonical
ones, which is exactly what the fleet transition needs. It is not authentication, and it must
not be read as one.

Not a finding because it is pre-existing and inherent to the shared-path design rather than
introduced here: anyone able to write that path already has code execution by writing the gate
itself, so the marker check neither adds nor removes exposure. Verified that the path is
owner-only (`0700`), with nothing group- or world-writable beneath it.

Recorded in ADR-0012 and the spec delta so a later reader does not mistake the marker for a
signature.

## Filtered candidate, stated rather than dropped

`lock_age()` in `bin/install-gate.sh` returns `999999` when `stat` fails, so a lock whose age
cannot be read is always treated as stale and reclaimed. Traced it: reaching that state needs
write access to a `0700`-gated directory, which already implies code execution. A robustness
nit, not a security finding — below the gate, and recorded here so the judgement is auditable
rather than invisible.

---

*This is an AI-assisted scan, not a professional security audit. It catches common
vulnerability patterns; it is not comprehensive and not a substitute for a qualified security
firm on systems handling sensitive data, payments, or PII.*
