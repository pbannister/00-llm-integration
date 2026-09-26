# Model Catalog — verified 2026-09-25

Derived from the router captures `dataflow.in/endpoints/beast-models.json` (6 models), `beast-cpu-models.json` (1 model) and `athena-models.json` (16 models), captured 2026-09-25.
`ctx` is the preset `ctx-size`, which is the per-slot context (see Notes).
The full lists live in the captures; this document records the curated entries that have execution roles.

## Id resolution: preset key versus model id

A preset section key and the router's reported model id can differ.
`config.ini` names the quant selector as it appears in the repository (`unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL`), while `GET /v1/models` reports the resolved file's quant (`unsloth/gpt-oss-20b-GGUF:Q4_K_XL`).

- Clients must use the reported id or the alias.
- Requesting the `UD-` form fails with `model not found` (verified 2026-09-25).
- The applied-config archives under `sources/config/` keep the `UD-` preset keys, because they mirror the host `config.ini` verbatim.

## Beast (MI25 16 GB GPU + dual Xeon 256 GB CPU)

### GPU-resident on `llama.service` (:2001) — fast, interactive, one model at a time

| Model id | alias | ctx | Role |
| ---- | ---- | ---- | ---- |
| `bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M` | `coder14` | 16384 | general chat and editing; the MI25 chat model in the llama.vscode tiered env |
| `unsloth/Qwen3.5-9B-GGUF:Q4_K_M` | `qwen9` | 32768 | general 9B with a longer context |
| `unsloth/gpt-oss-20b-GGUF:Q4_K_XL` | `gpt-oss-20b` | 32768 | agent and tool calls (parsed `tool_calls` verified 2026-09-25); the MI25 agent model |
| `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL` | `gemma-12b` | 32768 | general 12B |
| `unsloth/gemma-4-26B-A4B-it-qat-GGUF:Q4_K_XL` | `gemma-26b` | 81920 | very large context; KV cache spills to CPU |
| `batiai/Qwen3.8-Flash-Next-GGUF:Q4_K_M` | `qwen38` | 16384 | present but not recommended; see the 2026-09-21 MI25 benchmark |

`coder14` does not emit parsed tool calls: it returns a `<tools>` text block, so it is chat-only.

### CPU-heavy on `llama-cpu.service` (:2002)

| Model id | alias | ctx | Role |
| ---- | ---- | ---- | ---- |
| `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` | `gpt-oss-120b` | 65536 | planning, architecture, long-running agent and tool batches; runs in system RAM with `numa = distribute`, so the MI25 stays free. Parsed `tool_calls` verified 2026-09-25 |

## Athena (RX 5500 XT 8 GB GPU + Ryzen 9 5900X 128 GB CPU)

The athena router runs `parallel = 4`, so each request gets a quarter of the preset context (2048 tokens at the 8192 default).

### GPU-resident (`ngl 99`) — fast, small

| Model id | alias | ctx | Role |
| ---- | ---- | ---- | ---- |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` | `coder3` | 8192 | inline completion (FIM-capable) and small edits; the llama.vscode completion model |
| `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` | `coder15` | 8192 | fastest FIM |
| `unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0` | `llama3` | 8192 | small chat; parsed `tool_calls` verified 2026-09-25 |
| `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL` | `gemma-e4` | 8192 | small chat and the offline agent fallback; parsed `tool_calls` verified 2026-09-25 |

### GPU plus CPU split

| Model id | alias | ctx | Role |
| ---- | ---- | ---- | ---- |
| `batiai/Qwen3.8-27B-GGUF:Q4_K_M` | `qwen27` | 16384 | 27B split across the 8 GB VRAM and system RAM; `flash-attn = false`, V cache `f16` |

### CPU fallback (`ngl 0`) — used when beast is offline

| Model id | alias | ctx | Role |
| ---- | ---- | ---- | ---- |
| `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` | `coder32-fallback` | 16384 | editing fallback on 128 GB RAM |
| `unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_XL` | `r1-32b-fallback` | 16384 | reasoning fallback |

### Special-purpose and cache entries

The embedding preset serves RAG; the remaining entries are cache entries with no preset role.

| Model id | alias | ctx | Role |
| ---- | ---- | ---- | ---- |
| `ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0` | `nomic-embed` | 8192 | embeddings (`embeddings = on`) for `/v1/embeddings` and RAG |
| `josephmayo/gemma-4-E4B-it-Coder-GGUF:Q5_K_M` | — | 8192 | coding-tuned small model |
| `unsloth/Qwen3.5-2B-GGUF:Q4_K_M`, `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` | — | 8192 | minerva travel candidates |
| `unsloth/gemma-4-E2B-it-qat-GGUF:Q4_K_XL` | — | 8192 | minerva travel candidate |
| `unsloth/Qwen3.5-9B-GGUF:Q4_K_M` | — | 8192 | athena copy of the beast `qwen9` model; no preset role |
| `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q4_K_M`, `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q4_K_M` | — | 8192 | lighter quants of the two athena coders; kept as fallbacks |
| `unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_M` | — | 8192 | duplicate quant of `r1-32b-fallback` |

## Removed from beast on 2026-09-03

These were presets on the beast GPU router and are no longer served there.
Their weights do not fit the 16 GiB MI25, or a smaller model replaced them.

- `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` (`coder32`) — 18.49 GB of weights; survives only as the athena CPU fallback `coder32-fallback`.
- `unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_M` (`devstral`).
- `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_XL` (`r1-14b`).
- `unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:Q4_K_XL` (`r1-70b`).
- `unsloth/Llama-3.3-70B-Instruct-GGUF:Q4_K_XL` (`llama70`).
- `unsloth/gemma-4-E2B-it-qat-GGUF` and `unsloth/gemma-4-E4B-it-qat-GGUF` — athena keeps the E4B preset.

## Notes

- Model ids are exactly as the routers report them; client configs must use these strings verbatim, or the alias.
- `ctx` is the per-slot context: a preset's `ctx-size` divided by its router's `parallel`. Athena (`parallel = 4`) therefore serves 2048 tokens per request at its 8192 default; beast runs `parallel = 1`.
- Cache entries have no preset; their context comes from the router default, not a tuning decision.
- Refresh this document from the captures whenever the routers change; see `prompts/tasks/02-capture-endpoint-facts.md`.
