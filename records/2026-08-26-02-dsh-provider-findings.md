# Record: DSH provider findings — 2026-08-26

Task 03 output. Comparison of the live `~/.dsh/settings.yaml` `llm-pi-ai.beast` section against `sources/config/dsh-settings-beast.example.yaml` (verified 2026-08-26, router captures refreshed after the llama.cpp 0.3.0-dev rebuild).

## Current state (verified 2026-08-26)

- The five short-id entries (`coder32`, `r1-14b`, `gpt-oss-120b`, `r1-70b`, `gemma-26b`) are now **valid**: the tuned routers expose exactly these aliases, and their `contextWindow`/`maxTokens` match the presets. No change needed for those.
- `BEAST_API_KEY` credential: not yet set anywhere (env, `~/.dsh/.credentials.yaml`, or `.env`) — requests fail with `MISSING_CREDENTIAL` until a value is stored (any non-empty string works; llama.cpp ignores auth until `--api-key` is added to the router).

## Problems in the live section

1. **Deleted models still listed** (bare ids of models removed by the 2026-08-26 cache discard; the router no longer lists them and a request would fail or trigger a re-download):
   - `bartowski/Qwen3.8-27B-GGUF:Q4_K_M`
   - `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_M`
   - `unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_M`
   - `unsloth/Qwen3.5-27B-GGUF:Q4_K_M`, `unsloth/Qwen3.5-27B-GGUF:Q4_K_S`
   - `unsloth/gpt-oss-120b-GGUF:Q4_K_M`, `unsloth/gpt-oss-20b-GGUF:Q4_K_M`
2. **Existing models with bare entries** inherit 262144/32768 defaults that exceed every preset: `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M`, `unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:Q4_K_XL`, `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_XL`, `unsloth/Llama-3.3-70B-Instruct-GGUF:Q4_K_XL`, `unsloth/Qwen3.5-9B-GGUF:Q4_K_M`, `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`, `unsloth/gemma-4-26B-A4B-it-qat-GGUF:Q4_K_XL`, `unsloth/gemma-4-E2B/E4B-it-qat-GGUF:Q4_K_XL`, `unsloth/gpt-oss-120b-GGUF:Q4_K_XL`, `unsloth/gpt-oss-20b-GGUF:Q4_K_XL` — each needs explicit capacities or an alias.
3. **Missing new presets**: `coder14`, `devstral` (both live on the router) are not in the live list.

## Recommended fix (the human applies)

Replace the whole `beast.models` list with the 11 aliased entries in `sources/config/dsh-settings-beast.example.yaml` (aliases route on the tuned routers, capacities match presets). Optionally add the `athena` provider route from the same example for low-latency local models. Store `BEAST_API_KEY` (and `ATHENA_API_KEY`) in the DSH Models settings.

## Verification

- `GET http://beast.lan:2001/v1/models` lists the 11 aliases with preset contexts (captures refreshed).
- Chat completion through the `coder32` alias answered correctly on beast (verified 2026-08-26).
- `make test` passes.
