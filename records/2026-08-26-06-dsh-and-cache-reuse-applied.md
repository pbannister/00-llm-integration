# Record: DSH settings and cache-reuse applied — 2026-08-26

## Outcome

Completed the two pending applies from the previous session, both verified.

## 1. DSH provider sections applied (task 03 completion)

`~/.dsh/settings.yaml` `llm-pi-ai` section replaced with the corrected routes:

- `beast` — 11 models by router alias (`coder32`, `coder14`, `devstral`, `qwen9`, `gpt-oss-20b`, `gemma-12b`, `r1-14b`, `gemma-26b`, `gpt-oss-120b`, `r1-70b`, `llama70`), `contextWindow`/`maxTokens` matching the live presets, `compat {supportsDeveloperRole: false, maxTokensField: max_tokens}`.
- `athena` — 6 models (`coder15`, `coder3`, `llama3`, `gemma-e4`, `coder32-fallback`, `r1-32b-fallback`) with the same compat block.
- `agent-default-model` left unchanged (`deepseek-official` / `deepseek-v4-flash` / `reasoningEffort high`).

Credentials in `~/.dsh/.credentials.yaml`: `BEAST_API_KEY` (already present, non-empty) and `ATHENA_API_KEY` (generated random value). Both refs verified non-empty. The DSH adapter resolves credentials per stream call, so no restart is needed; if the model picker does not show the new providers, reload the GUI page.

## 2. cache-reuse applied

Added `cache-reuse = 256` under `[*]` in `/usr/local/etc/config.ini` on both hosts (baselines backed up as `config.ini.bak-20260826-cachereuse`), restarted both `llama.service`s.

## Verification (all 2026-08-26)

- Beast: 13 models, child args show `--cache-reuse 256`, `--parallel 4`; athena: 15 models, same args.
- Aliases intact on both routers; captures refreshed (`dataflow.in/endpoints/`).
- `~/.dsh/settings.yaml` parses and mirrors `sources/config/dsh-settings-beast.example.yaml` (validated by `make test`).
- `make test` passes.

## Commits

- (pending) records + doc updates for this apply.
