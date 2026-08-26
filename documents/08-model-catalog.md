# Model Catalog — verified 2026-08-26

Derived from the router captures `dataflow.in/endpoints/beast-models.json` (28 models) and `dataflow.in/endpoints/athena-models.json` (32 models), captured 2026-08-26.
`ctx` is the preset `ctx-size`; `ngl` is the offload depth (99 = GPU-resident, 0 = CPU).
The full lists live in the captures; this document records the curated entries that have execution roles.

## Beast (MI25 16 GB GPU + dual Xeon 256 GB CPU)

### GPU-resident (`ngl 99`) — fast, interactive

| Model id | ctx | Role |
| ---- | ---- | ---- |
| `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` | 16384 | default editing and agent work; strong tool calls |
| `unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_M` | 32768 | dev-workflow and tool use |
| `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_XL` | 32768 | reasoning Q&A; weak tool following — not for the agent loop |
| `unsloth/gemma-4-26B-A4B-it-qat-GGUF:Q4_K_XL` | 81920 | very large context; multimodal-capable |

### CPU-heavy (`ngl 0`) — slow, background

| Model id | ctx | Role |
| ---- | ---- | ---- |
| `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` | 65536 | planning, architecture, large repeated background tasks; runs on CPU (`numa = distribute`) so the MI25 stays free |
| `unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:Q4_K_XL` | 32768 | deep reasoning on CPU |
| `unsloth/Llama-3.3-70B-Instruct-GGUF:Q4_K_XL` | 32768 | general 70B chat on CPU |

### Cache entries with roles (no preset yet, CPU, ctx 32768)

The remaining cache entries on beast are the keep-with-tuning candidates from `documents/12-model-retention.md`: `bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M`, `unsloth/Qwen3.5-9B-GGUF:Q4_K_M`, `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`, `unsloth/gemma-4-E2B-it-qat-GGUF:Q4_K_XL`, `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL`, and `unsloth/gpt-oss-20b-GGUF:Q4_K_XL`.
Promote to presets when a role is assigned (see `documents/14-service-tuning-recommendations.md`).

## Athena (RX 5500 XT 8 GB GPU + Ryzen 9 5900X 128 GB CPU)

### GPU-resident (`ngl 99`) — fast, small

| Model id | ctx | Role |
| ---- | ---- | ---- |
| `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` | 8192 | inline completion (FIM-capable), tiny fast tasks |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` | 8192 | inline completion, small edits |
| `unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0` | 8192 | small chat |
| `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL` | 8192 | small gemma chat |

### CPU fallback (`ngl 0`) — used when beast is offline

| Model id | ctx | Role |
| ---- | ---- | ---- |
| `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` | 16384 | editing fallback on 128 GB RAM |
| `unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_XL` | 16384 | reasoning fallback |

### Special-purpose (cache)

| Model id | ctx | Role |
| ---- | ---- | ---- |
| `ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0` | 8192 | embeddings (RAG); needs an embeddings preset |
| `josephmayo/gemma-4-E4B-it-Coder-GGUF:Q5_K_M` | 8192 | coding-tuned small model |
| `unsloth/Qwen3.5-2B-GGUF:Q4_K_M`, `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` | 8192 | minerva travel candidates |

The athena cache also retains `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q4_K_M` and `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q4_K_M` cache quants in the repos whose Q8 presets are kept (remaining cleanup candidates; owner to decide).

## Notes

- Cache entries have no preset; their `ngl 0` and `ctx 8192/32768` come from the router default, not a tuning decision.
- Model ids are exactly as the routers report them; client configs must use these strings verbatim.
- Refresh this document from the captures whenever the routers change; see `prompts/tasks/01-capture-endpoint-facts.md`.
