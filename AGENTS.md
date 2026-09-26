# AI Agents Configuration

Do not create tests for changes to this repository. Since these are just configuration changes, we will not use test-driven development methods.

## Key Features
- All AI agents should have their requests routed through weave router to ensure consistent handling and monitoring. Unless specified, Weave router should automatically determine the appropriate routing and handling for each request **(do not use the `force-model` option)**.
- Codex should be configured so that it's requests still go through Weave Router, but each request still uses the ChatGPT Pro subscription (ChatGPT OAuth token). As a result, **we should not require the OPENAI_API_KEY for Codex requests**.

<!-- storm configuration start-->
 ## External packages — DO NOT PATCH

The following Storm Software ecosystems are maintained in **separate repositories**. Do **not** modify their package code, vendored scaffolding, or `node_modules` contents in this repo — including via `patch-package`, manual edits under `node_modules`, or direct changes to generated integration layers.

| Ecosystem | Upstream repository | In this repo (do not patch) |
| --- | --- | --- |
| **powerlines** | [storm-software/powerlines](https://github.com/storm-software/powerlines) | `powerlines`, `@powerlines/*`, and Powerlines-generated CLI scaffolding |
| **power-plant** | [storm-software/power-plant](https://github.com/storm-software/power-plant) | `@power-plant/*` and any power-plant schema or tooling packages |
| **shell-shock** | [storm-software/shell-shock](https://github.com/storm-software/shell-shock) | `@shell-shock/*` and `apps/cli/.shell-shock/` |
| **razorwind** | [storm-software/razorwind](https://github.com/storm-software/razorwind) | `@razorwind/*` |
| **cyclone-ui** | [storm-software/cyclone-ui](https://github.com/storm-software/cyclone-ui) | Consumer configuration and integration owned by this repo (for example `powerlines.config.ts`, `razorwind.config.ts`, `shell-shock.config.ts`, `tools/razorwind/`, and cyclone-ui CLI command implementations under `apps/cli/src/`) |
| **storm-ops** | [storm-software/storm-ops](https://github.com/storm-software/storm-ops) | Reusable workflows, devenv modules, Terraform modules, and other storm-ops artifacts consumed by reference |
| **mindctl** | [storm-software/mindctl](https://github.com/storm-software/mindctl) | `@mindctl/*` and any mindctl schema or tooling packages |

**Allowed in this repository:** consumer configuration and integration owned by this repo (for example `powerlines.config.ts`, `razorwind.config.ts`, `shell-shock.config.ts`, `tools/razorwind/`, and cyclone-ui CLI command implementations under `apps/cli/src/`).

When a bug or feature belongs in one of the ecosystems above:

1. **Stop** — do not patch the external package or its vendored layer in this repository.
2. **Produce a descriptive upstream fix outline** so a human or agent can apply the change in the correct external repository.
3. **Optionally** implement only this repository's workaround or configuration change if one exists and is explicitly requested.
<!-- storm configuration end-->
