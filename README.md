# LLM Integration

This project owns the local-LLM integration story for the home subnet: which models run where, how each tool reaches them, and the policies for splitting work between GPU-fast and CPU-heavy models.

## Scope

The project covers:

- The three inference hosts: `beast.lan` (MI25 16 GB + dual Xeon 256 GB), `athena.lan` (RX 5500 XT 8 GB + Ryzen 9 5900X + 128 GB), and `minerva.lan` (travel laptop, specs pending).
- The llama.cpp router services on `beast.lan:2001` and `athena.lan:2001`.
- Client tool integration: DeepSeek Harness (`llm-pi-ai` providers), aider, llama.vscode, VS Code Chat.
- The execution policy: GPU-resident fast models for interactive work; CPU-heavy models (`gpt-oss-120b`) for large repeated background tasks so the GPU stays free.
- The offline travel plan for `minerva.lan`.

The router deployment itself (systemd, presets, Ansible) is owned by the sibling `model-router` project; this project owns the live model catalog and the client-side consumption of those endpoints. `sources/models/` holds imported copies of `~/models/` material for reference.

## Reading Order

The LLM should begin by reading these files in order (the numeric prefix marks load order):

1. `prompts/01-contract.md`
2. `prompts/02-workflow.md`
3. `prompts/03-conventions.md`

These define the interaction rules, workflow, and formatting conventions. The LLM must follow the workflow defined in `prompts/02-workflow.md` for every task.

Human contributors should begin with:

- `prompts/README.md`
- `documents/README.md`
- `documents/07-endpoints-map.md` (the canonical live map)

Note there are rules meant only to constrain Aider behavior:

- `tools/aider-rules.md` (Aider users only)

## Top-Level Map

- `README.md` — this overview.
- `TODO.md` — pending and completed project tasks.
- `prompts/` — LLM interaction rules, common requirements, feature requirements, and task definitions.
- `documents/` — human-consumption documents, including the endpoints map, model catalog, and tool integration.
- `records/` — version-controlled outcome, incident, and handoff records.
- `tools/` — tool-specific rules (`aider-rules.md` for Aider only).
- `sources/models/` — imported reference material from `~/models/` (install script, machine configs, benchmark notes).
- `sources/config/` — example client configuration (DSH provider section, aider invocation).
- `dataflow.in/endpoints/` — captured `/v1/models` responses from the live routers (live-state input, versioned).
- `scripts/` — project scripts, including `endpoints-capture.sh` and the test runner.
- `tests/` — tests and validation code.
- `dataflow.out/` / `logs/` / `site.out/` — generated output (not version-controlled).
- `Makefile` — drives tests (`make test`) and endpoint capture (`make capture`).

## Live-State Discipline

Live facts (model lists, contexts, ports) change; every document that reflects them carries a `verified <date>` marker, and the captured router responses in `dataflow.in/endpoints/` are the source of truth for the catalog.

## History

- Started 2026-08-26 from `00-project-skeleton` (homelab lessons incorporated).
- Imports `~/models/` reference material into `sources/models/`.
- Supersedes nothing; complements the `model-router` project, which owns router deployment.
