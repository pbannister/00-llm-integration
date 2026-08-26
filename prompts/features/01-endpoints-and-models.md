# Feature: Endpoints and Models

Defines the live inference endpoints, the model catalog, and the execution roles. This is the base fact source for all other features.

## Endpoints

Two llama.cpp router-mode servers answer on the house LAN:

- `http://beast.lan:2001/v1` — heavy server. MI25 16 GB VRAM (Vulkan backend, `GGML_VK_VISIBLE_DEVICES=1`), dual Xeon, 256 GB RAM. Default context 32768; large per-model contexts (65536–81920) for specific presets.
- `http://athena.lan:2001/v1` — desktop server. RX 5500 XT 8 GB VRAM, Ryzen 9 5900X (12 threads), 128 GB RAM. Default context 8192. Athena is this desktop.

Both answer OpenAI-compatible chat completions with `--tools all`. Model ids are the router preset section names (or `hf-repo` cache names), listed by `GET /v1/models`. Captured responses live in `dataflow.in/endpoints/` and are the source of truth; see `documents/07-endpoints-map.md`.

## Catalog and Execution Roles

Models fall into two execution classes per host:

- GPU-resident (fast, interactive): fully offloaded (`ngl = 99`).
- CPU-heavy (slow, background): zero offload (`ngl = 0`, `numa = distribute` on beast).

Beast GPU-resident: `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` (editing/agent work), `unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_M` (dev workflows), `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:UD-Q4_K_XL` (reasoning Q&A), `unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL` (large context, 81920).

Beast CPU-heavy: `unsloth/gpt-oss-120b-GGUF:UD-Q4_K_XL` (65536 context; planning, large background tasks), `unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:UD-Q4_K_XL`, `unsloth/Llama-3.3-70B-Instruct-GGUF:UD-Q4_K_XL`.

Athena GPU-resident: small coders (`Qwen/Qwen2.5-Coder-1.5B/3B` Q8), `unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0`, `unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL`. Athena CPU fallback: `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` (16384), `unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:UD-Q4_K_XL` (16384) — used when beast is offline.

Athena also lists an embedding model (`ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0`) and a coding-tuned small model (`josephmayo/gemma-4-E4B-it-Coder-GGUF:Q5_K_M`).

The full live lists are captured, not hand-written: refresh with `make capture`.

## Routing Policy

- Interactive work uses GPU-resident models.
- Large repeated background tasks use `gpt-oss-120b` on beast's CPU, leaving the MI25 free for interactive GPU models; the two run concurrently as separate child servers in router mode.
- See `documents/10-routing-policy.md` for the full policy.

## Requirement: facts come from captures

- Any task that states model ids, contexts, or ports must verify them against the latest `dataflow.in/endpoints/` capture or a live `GET /v1/models`, and mark the document `verified <date>`.
- Do not hand-copy model lists into documents; derive them from the captures.
