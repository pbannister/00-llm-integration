# Record: Tuning applied — 2026-08-26

## Outcome

Applied the task-01 tuning recommendations from `documents/14-service-tuning-recommendations.md` to both hosts and verified.

## What changed

Beast (`/usr/local/etc/config.ini`, baseline backed up as `.bak-20260826`):

- `[*]`: `parallel = 4`.
- Aliases on all 11 presets (`coder32`, `coder14`, `qwen9`, `gpt-oss-20b`, `gemma-12b`, `devstral`, `r1-14b`, `gemma-26b`, `gpt-oss-120b`, `r1-70b`, `llama70`).
- Four cache models promoted to GPU presets (`ngl = 99`): `bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M`, `unsloth/Qwen3.5-9B-GGUF:Q4_K_M`, `unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL`, `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`.

Athena (`/usr/local/etc/config.ini`, baseline backed up as `.bak-20260826`):

- `[*]`: `parallel = 4`.
- Aliases on the presets (`coder15`, `coder3`, `llama3`, `gemma-e4`, `coder32-fallback`, `r1-32b-fallback`).
- New embeddings preset `[ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0]` with `embeddings = on`, alias `nomic-embed`.

## Verification (all 2026-08-26)

- `GET /v1/models` on both routers shows the aliases; child args include `--parallel 4` (beast checked).
- Chat completion routed through the `coder32` alias answered correctly on beast.
- `POST /v1/embeddings` with model `nomic-embed` on athena returned a 768-dim vector — the RAG endpoint is live.
- Captures refreshed (`dataflow.in/endpoints/`, 13 beast / 15 athena); `make test` passes.

## Commits

- (pending) tuning applied + applied-config archives.
