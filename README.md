# axp-chctl

## Goal

Use AXP scenarios to understand how agents discover, install, and use `chctl` for ClickHouse workflows. The plan measures both task completion and downstream behavior: tool choice, command grounding, help usage, errors, project-context recovery, skill discovery, and whether the agent completes real database workflows.

## Quick Start

Install AXP:

```sh
bash <(curl -fsSL https://dl.514.ai/install.sh) axp
```

Set the model API key used by the agent runtime in `.env`:

```sh
echo 'ANTHROPIC_API_KEY=...' > .env
```

Validate the scenarios:

```sh
axp validate ./chctl-discovery-install.yaml
axp validate ./chctl-local-db.yaml
axp validate ./chctl-cloud-move.yaml
```

Run the scenarios:

```sh
axp run --env-file .env ./chctl-discovery-install.yaml
axp run --env-file .env ./chctl-local-db.yaml
axp run --env-file .env ./chctl-cloud-move.yaml
```

For a no-model-cost smoke check:

```sh
axp run ./chctl-discovery-install.yaml --dry-run
axp run ./chctl-local-db.yaml --dry-run
axp run ./chctl-cloud-move.yaml --dry-run
```

Run outputs are written under `.axp/runs/<run-group-id>/`.

## Key Files

- [`chctl-discovery-install.yaml`](./chctl-discovery-install.yaml): baseline discovery test for whether agents find `chctl` without being told.
- [`chctl-local-db.yaml`](./chctl-local-db.yaml): local project/database/table/seed/query workflow across the variant ladder.
- [`chctl-cloud-move.yaml`](./chctl-cloud-move.yaml): local-to-cloud handoff workflow across the same variant ladder.
- `.axp/runs/<run-group-id>/variants/<variant>/workspace/report.json`: local workflow report produced by the agent.
- `.axp/runs/<run-group-id>/variants/<variant>/workspace/cloud_move_report.json`: cloud workflow report produced by the agent.
- `.axp/runs/<run-group-id>/variants/<variant>/workspace/trace-command-metrics.json`: trace-derived metrics for tool choice, help usage, errors, fallback behavior, and skill behavior.
- `.axp/runs/<run-group-id>/variants/<variant>/agent-events.jsonl`: raw trace for manual inspection.

## Scenario 1: Discovery / Install

File: [`chctl-discovery-install.yaml`](./chctl-discovery-install.yaml)

Task shape: ask the agent to create a new local ClickHouse-style project without naming `chctl`.

Hypothesis: agents will not discover `chctl` unless it is explicitly surfaced through the prompt, environment, docs, or installed tooling.

Expected learning:

- Whether agents naturally search for a ClickHouse-specific project workflow tool.
- Whether they install raw ClickHouse instead of `chctl`.
- Whether they mention `chctl`, `clickhousectl`, or agent skills without being prompted.

Variants:

| Variant | Starting condition | Hypothesis |
| --- | --- | --- |
| `baseline` | No `chctl`, no skill hint, neutral prompt | The agent will not discover `chctl` and will use raw ClickHouse tooling or generic project scaffolding. |

## Scenario 2: Local DB Workflow

File: [`chctl-local-db.yaml`](./chctl-local-db.yaml)

Task shape: ask the agent to complete a local ClickHouse workflow for `demo-app`, without telling it which tool to use.

Workflow to complete:

1. Initialize a project.
2. Create a database.
3. Create a table.
4. Seed some rows.
5. Query the table and show evidence that the seeded rows are present.

Hypothesis: `chctl` availability and discoverability determine tool choice, but downstream quality depends on whether the agent uses help output, runs commands from the project directory, avoids hallucinated commands, and completes the full table/seed/query workflow.

Variants:

| Variant | Starting condition | Prompt condition | Hypothesis |
| --- | --- | --- | --- |
| `baseline` | `chctl` absent, skills absent | Neutral local DB workflow prompt | The agent will complete the task with raw `clickhouse`, `clickhouse-server`, or `clickhouse-client`, not `chctl`. |
| `install-hint` | `chctl` absent, skills absent | Soft hint that local `chctl` may make the workflow easier | The agent may search for `chctl`, but a hint without a link may not be enough to install it successfully. |
| `install-hint-docs-link` | `chctl` absent, skills absent | Hint plus link to `chctl` docs or GitHub/install source | A concrete source should improve `chctl` installation and reduce raw ClickHouse fallback. |
| `chctl-preinstalled` | `chctl` present, skills absent | Neutral local DB workflow prompt | Availability alone should lead the agent to use `chctl`, but it may still hallucinate commands or run from the wrong directory. |
| `chctl-preinstalled-skills-hint` | `chctl` present, skills absent | Hint that relevant agent skills may exist | The agent may try `npx skills ...`, `chctl skills ...`, or side-load skills before continuing the local DB workflow. |
| `chctl-preinstalled-skills-preinstalled` | `chctl` present, `chctl`-provided skills present | Neutral local DB workflow prompt | Preinstalled skills should improve downstream command choice, reduce errors, and improve project-context recovery. |

Metrics are defined in the scenario's application and introspection tests. The resulting `trace-command-metrics.json` is the source of truth for tool choice, help usage, errors, command quality, workflow completion, and skill behavior.

## Scenario 3: Move Local DB To Cloud

File: [`chctl-cloud-move.yaml`](./chctl-cloud-move.yaml)

Task shape: provide a local ClickHouse project and ask the agent to move or prepare it for a managed cloud ClickHouse environment so a teammate can connect. Do not tell the agent which tool or cloud provider to use.

Hypothesis: agents may choose ClickHouse Cloud for managed ClickHouse, but `chctl` availability, docs, and skills will determine whether they produce an executable, safe cloud handoff instead of a generic plan.

Auth expectation: cloud auth may block real provisioning. That is acceptable; the test should measure whether the agent handles the blocker safely, uses dry-run or planning commands where appropriate, and records exact next steps.

Variants:

| Variant | Starting condition | Prompt condition | Hypothesis |
| --- | --- | --- | --- |
| `baseline` | Local project exists, `chctl` absent, skills absent | Neutral cloud move prompt | The agent may recommend ClickHouse Cloud but use generic docs, raw `clickhouse-client`, or non-`chctl` tooling. |
| `install-hint` | Local project exists, `chctl` absent, skills absent | Soft hint that local `chctl` may make the cloud handoff easier | The agent may search for `chctl`, but may still fail to find or install it. |
| `install-hint-docs-link` | Local project exists, `chctl` absent, skills absent | Hint plus link to `chctl` docs or GitHub/install source | A concrete source should increase `chctl` use for cloud planning and reduce generic cloud migration output. |
| `chctl-preinstalled` | Local project exists, `chctl` present, skills absent | Neutral cloud move prompt | Availability should increase `chctl` use, but auth may stop provisioning; the agent should stop safely and write prerequisites. |
| `chctl-preinstalled-skills-hint` | Local project exists, `chctl` present, skills absent | Hint that relevant agent skills may exist | The agent may discover/install skills through `npx skills ...`, `chctl skills ...`, or side-loading, then use that guidance for the cloud plan. |
| `chctl-preinstalled-skills-preinstalled` | Local project exists, `chctl` present, `chctl`-provided skills present | Neutral cloud move prompt | Preinstalled skills should improve provider choice, auth handling, dry-run safety, and the concreteness of the handoff. |

Metrics are defined in the scenario's application and introspection tests. The resulting `trace-command-metrics.json` is the source of truth for provider choice, tool choice, auth/resource safety, migration quality, help usage, errors, and skill behavior.

## Reporting Principle

Pass/fail should confirm that the agent produced required artifacts. The main learning should come from trace-based metrics and trace inspection that describe how the agent worked: which tools it chose, how much help it needed, where it failed, whether it recovered, and whether skills changed the workflow.
