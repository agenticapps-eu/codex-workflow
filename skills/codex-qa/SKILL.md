---
name: codex-qa
version: 0.1.0
implements_spec: 0.4.0
implements_gate: qa, ui-preview
description: |
  Browser-driven QA in two modes. **ui-preview mode** (per-task,
  pre-commit): boot the dev server, screenshot the changed component,
  reference the screenshot path in the commit message — fires for any
  task modifying a frontend component, route, or visual surface.
  **qa mode** (post-phase): walk user flows in a real browser against
  a running dev server, log interactions, produce a QA report
  referenced from VERIFICATION.md — fires per phase that ships
  user-visible behavior. Use whichever mode the calling context
  selects; the body branches on `mode=preview` vs `mode=phase-qa`.
---

# codex-qa

This skill fulfills both the `ui-preview` (per-task) and `qa`
(post-phase) gates from
[`agenticapps-workflow-core/spec/02-hook-taxonomy.md`](https://github.com/agenticapps-eu/agenticapps-workflow-core/blob/main/spec/02-hook-taxonomy.md).
One skill, two modes — see ADR-0001 D2 for the binding rationale.

## When to invoke

- **ui-preview mode** — any task modifying a frontend component,
  route, or visual surface, before the task's commit lands.
- **qa mode** — any phase that ships user-visible behavior AND a dev
  server is reachable on a host-known local port.

## What this skill does

### ui-preview mode

1. **Confirm dev server.** If not running, boot it. If the project
   has multiple dev servers (frontend, backend, both), boot the
   relevant one. Capture the port for the screenshot URL.
2. **Navigate to the changed surface.** Use the project's browser
   tooling (Codex's Playwright MCP if registered, or whatever
   browser-driver is available) to navigate to the changed
   component's URL.
3. **Screenshot.** Capture default state, plus any clearly-implied
   alternate state (hover, focus, populated form, error). Save under
   `.planning/phases/<NN>-<slug>/screenshots/{{task-id}}/{{state}}.png`
   (or the project's screenshot convention).
4. **Reference in commit message.** The commit body MUST include a
   `Screenshot: <path>` line per state captured. The
   `verification` gate's later check looks for this reference.

### qa mode

1. **Confirm dev server reachable.** If not, the qa gate cannot fire;
   note in VERIFICATION.md that qa was skipped because no dev server
   was reachable, and surface to user.
2. **Walk the user flows.** For each user-visible behavior shipped
   by the phase, exercise it end-to-end:
   - Happy path — navigate, interact, observe expected state
   - Failure path — empty input, malformed input, network failure
     simulation, permission denial
   - Edge case — boundary values, large input, repeat-action,
     concurrent state
3. **Log every interaction.** Capture the URL navigated to, the
   actions taken (click, type, submit), the resulting state
   (screenshot, network response, console output), and any console
   errors / warnings.
4. **Write the QA report.** Append to VERIFICATION.md or create
   `.planning/phases/<NN>-<slug>/QA.md`:

   ```markdown
   # QA report — phase {{N}}

   Tester: codex-qa v0.1.0
   Mode: phase-qa
   Dev server: <URL>:<port>

   ## Flows tested

   ### Flow A — {{description}}
   - Happy path: <pass | fail — see screenshot path>
   - Failure path: <pass | fail>
   - Edge case: <pass | fail>

   ## Console errors / warnings

   - …

   ## Verdict

   <pass | pass-with-followups | block>
   ```
5. **Reference from VERIFICATION.md.** The QA report path appears as
   an Evidence subrow on the relevant must_haves (per spec/06).

## Required evidence (per spec/06)

### ui-preview mode

- A screenshot file exists at the referenced path
- The commit message contains a `Screenshot: <path>` line
- The screenshot URL, browser, and a one-line description match the
  permitted "screenshot path" evidence shape from spec/06

### qa mode

- `QA.md` (or VERIFICATION.md QA section) exists
- At least one live-app interaction is logged with screenshot evidence
- Console errors / warnings are listed (or "none observed" if
  genuinely none)
- The verdict line is explicit

## Failure modes

- **"Dev server isn't worth booting for this change" (red flag, see
  rationalization table).** If you touched JSX/TSX, boot it. 30
  seconds.
- **"Manually verified" (without screenshot path).** Non-conformant
  per spec/06 — produce the screenshot.
- **Skipping qa mode because "we'll catch in production."**
  Non-conformant; production catch is post-incident, not preventive.
- **Conflating the two modes.** ui-preview is per-task pre-commit;
  qa is post-phase pre-merge. They share infrastructure (dev server
  + browser) but produce different artifacts at different times.

## Notes for the Codex host

- The Playwright MCP plugin (registered as
  `mcp__plugin_playwright_playwright__*`) is the preferred browser
  driver if registered. Otherwise fall back to whatever browser
  tooling the project ships (Cypress, Selenium, etc.).
- For headless environments, capture screenshots at standard
  viewport sizes (1280×720 baseline; mobile 390×844 if responsive
  matters to the surface).
- Console error capture is part of the evidence — silent JS errors
  in qa mode are findings, not noise.
