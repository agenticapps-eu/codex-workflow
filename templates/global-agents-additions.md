<!-- BEGIN: codex-workflow global section (do not remove this marker) -->

## AgenticApps Workflow (Global)

All AgenticApps EU repos installed against `codex-workflow` use the
spec-first workflow with the `agentic-apps-workflow` trigger skill.

The trigger skill auto-activates on any code-touching task. It emits
the commitment-ritual block (per `agenticapps-workflow-core` spec/01)
and routes to the right `codex-*` gate skills based on task size and
gate triggers.

Setup a project: `$setup-codex-agenticapps-workflow`.
Update an existing project: `$update-codex-agenticapps-workflow`.

The codex-workflow scaffolder repo:
[github.com/agenticapps-eu/codex-workflow](https://github.com/agenticapps-eu/codex-workflow).

<!-- END: codex-workflow global section -->
