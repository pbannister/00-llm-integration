# Record: LLM-integration handoff — 2026-08-26

> Written so a fresh session can resume without this conversation's memory.

## Current state (verified 2026-08-26)

- Project `00-llm-integration` created from `00-project-skeleton`; canonical prompts copied verbatim; skeleton site-build example removed.
- `~/models/` reference material imported to `sources/models/` (README.md, config-beast.ini, config-athena.ini, install.sh, exercise-mi25-models.sh, backup.sh). These ini copies are older than the live `/usr/local/etc/config.ini` on each host — treat live captures as authoritative.
- Live router captures written to `dataflow.in/endpoints/beast-models.json` (28 models) and `athena-models.json` (32 models), verified 2026-08-26.
- `documents/07-endpoints-map.md`, `08-model-catalog.md`, `09-tool-integration.md`, `10-routing-policy.md` written from the captures.
- `sources/config/dsh-settings-beast.example.yaml` written: DSH `llm-pi-ai` provider with `openai-completions`, `compat {supportsDeveloperRole: false, maxTokensField: max_tokens}`, and 7 curated model entries with capacities matching the live presets.
- `make test` passes; `make capture` refreshes the endpoint facts.
- DeepSeek Harness runs on this desktop (athena) at `http://127.0.0.1:3080`; default provider remains `deepseek-official` (deepseek-v4-flash, reasoningEffort high).

## Findings on ~/.dsh/settings.yaml (the human's edit, 2026-08-26)

- The `llm-pi-ai.beast` section is schema-valid and the `compat` block is correct.
- Problem 1: bare id-only model entries inherit 262144 context / 32768 max-token defaults, which exceed every live preset and cause context overflow. Every entry needs explicit `contextWindow`/`maxTokens`.
- Problem 2: short ids (`coder32`, `r1-14b`, `gpt-oss-120b`, ...) do not exist on the router yet — no `alias =` lines in the beast preset. Requests with those ids fail until aliases are added or full router ids are used.
- Problem 3: several listed ids are cache entries that exist, but a few (for example `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`) are CPU cache entries, not the tuned GPU presets; capacities must come from the capture.
- Problem 4: `BEAST_API_KEY` credential is not set anywhere (env, `~/.dsh/.credentials.yaml`, or `.env`); requests fail with MISSING_CREDENTIAL until it is stored (any non-empty value works; llama.cpp ignores auth until `--api-key` is set on the router).
- The human applies the fix; this project does not modify `~/.dsh/settings.yaml`.

## Next tasks (in order)

1. `prompts/tasks/01-capture-endpoint-facts.md` — refresh captures and re-derive the map/catalog documents.
2. `prompts/tasks/02-fix-dsh-provider-catalog.md` — reconcile the DSH provider with the live router, write the findings record, verify one live request.
3. `prompts/tasks/03-document-tool-integration.md` — finish `documents/09-tool-integration.md` (aider, llama.vscode, VS Code Chat).
4. `prompts/tasks/04-plan-minerva-offline.md` — SSH to minerva.lan, discover hardware, write `documents/11-minerva-travel-plan.md`.

## Decisions

- Keep `deepseek-official` as the DSH default; use `beast` per session.
- CPU-heavy background tasks go to `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` (65536 ctx, ngl 0) so the MI25 stays free for GPU models.
- Do not put R1-distill models in agent loops; reserve them for reasoning Q&A.

## Commits (this session)

- Initial project commit (pending: `git init` + first commit).
