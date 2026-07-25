# Security review — adopt-canonical-reviewer-cli

**Date:** 2026-07-25 · **Mode:** inline assessment by the implementing agent.
**The `/cso` skill was NOT run** — the operator flagged the change was taking too
long and cut the remaining process. Recorded as a deviation, not as a review that
happened.

## Verdict

**No findings.** One accepted residual, already stated in the spec and ADR rather
than discovered here.

## Why the surface is narrow

The repo is markdown and shell. No package manifest, no endpoints, no datastore,
no user data, no LLM prompts built from non-self-authored values. The change adds
no network calls and no new inputs.

The one thing worth reviewing is that the artifact **is** part of a security
control: `reviewer-cli.sh` produces the independent-review evidence the §18 gate
consumes, and `install-gate.sh` decides what lands at a path shared by every
agent on the machine.

## Assessed

- **Shared-path write.** The wrapper install moved from an unarbitrated
  `install -m 0755` to the arbitrating installer: `mkdir` lock, atomic
  temp+`mv`, refuse-downgrade. Strictly stronger than what it replaced. The lock
  is per-destination, so the two artifacts cannot deadlock each other.
- **Marker parsing** reads a fixed-format comment with `grep`/`sed` and rejects
  anything that is not three integers, on both sides. No `eval`, no path
  interpolation into a shell, no unquoted expansion introduced.
- **The vendored wrapper** is byte-identical to core and unmodified; its
  hardening (stdin pinned, hard `timeout`) is core's and unchanged here.
- **The new CI step** interpolates no `${{ }}` expressions, so the GitHub Actions
  injection class does not apply. The harness stubs every vendor CLI in a
  `mktemp` dir — no real reviewer runs, nothing leaves the runner.

## Accepted residual

**A marker is a plain comment, and arbitration compares it.** A host that
publishes a lying `# reviewer-cli-version: 9.9.9` makes this repo refuse to
"downgrade" to its own canonical copy, and the degraded wrapper survives. This
defends against a **stale honest host** — the failure core#41 actually observed —
not a dishonest one. Anything able to write the shared path can already write
whatever it likes there; the marker adds no trust boundary and is documented as
adding none, in `specs/reviewer-cli/spec.md`, ADR-0013, and the producer skill.
Closing it properly needs signing, which is a core-level decision, not a
host-level one.
