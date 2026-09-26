# Feature: Endpoints and Models

Defines the live inference endpoints, the model catalog, and the execution roles.
This is the base fact source for all other features.

## Endpoints

Three llama.cpp router-mode servers answer on the house LAN:

- `http://beast.lan:2001/v1` — heavy server, GPU router. MI25 16 GB VRAM (Vulkan backend, `GGML_VK_VISIBLE_DEVICES=1`), dual Xeon, 256 GB RAM, `--models-max 1`, `parallel = 1`. Default context 32768; large per-model contexts up to 81920.
- `http://beast.lan:2002/v1` — heavy server, CPU router. `unsloth/gpt-oss-120b-GGUF` at `ngl = 0`, `numa = distribute`, 65536 context, `parallel = 1`.
- `http://athena.lan:2001/v1` — desktop server. RX 5500 XT 8 GB VRAM, Ryzen 9 5900X (12 threads), 128 GB RAM, `parallel = 4`. Default context 8192, which is 2048 tokens per request after the slot split.

All three answer OpenAI-compatible chat completions with `--tools all`.
Model ids are the resolved preset names or `hf-repo` cache names, and each preset also carries a short alias; `GET /v1/models` is the source of truth.
Captured responses live in `dataflow.in/endpoints/`; see `documents/07-endpoints-map.md`.

## Id Resolution

A preset section key and the router's reported model id can differ.
`config.ini` writes the repository quant selector (`unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL`), while `GET /v1/models` reports the resolved file quant (`unsloth/gpt-oss-20b-GGUF:Q4_K_XL`).
Clients must use the reported id or the alias; the `UD-` form fails with `model not found`.

## Catalog and Execution Roles

Models fall into execution classes per host:

- Local GPU (athena): `coder3` and `coder15` (`Qwen/Qwen2.5-Coder-3B`/`1.5B` Q8) for FIM completion, `llama3` (`unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0`) and `gemma-e4` (`unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL`) for small chat and tools, and `qwen27` (`batiai/Qwen3.8-27B-GGUF:Q4_K_M`) as a GPU plus CPU split.
- Athena CPU fallback, used when beast is offline: `coder32-fallback` (`Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M`) and `r1-32b-fallback` (`unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_XL`), both 16384 context at `ngl = 0`.
- Athena embeddings: `nomic-embed` (`ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0`), serving `/v1/embeddings`.

Beast GPU-resident on :2001: `coder14` (`bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M`, 16384) for chat and editing, `qwen9` (`unsloth/Qwen3.5-9B-GGUF:Q4_K_M`, 32768), `gpt-oss-20b` (`unsloth/gpt-oss-20b-GGUF:Q4_K_XL`, 32768) for agent and tool calls, `gemma-12b` (`unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`, 32768), `gemma-26b` (`unsloth/gemma-4-26B-A4B-it-qat-GGUF:Q4_K_XL`, 81920), and `qwen38` (`batiai/Qwen3.8-Flash-Next-GGUF:Q4_K_M`, 16384, present but not recommended).

Beast CPU-heavy on :2002: `gpt-oss-120b` (`unsloth/gpt-oss-120b-GGUF:Q4_K_XL`, 65536) for planning, long-running agent loops, and large background tasks.

Only models that emit parsed `tool_calls` belong in an agent loop.
Verified 2026-09-25: `gpt-oss-20b`, `gpt-oss-120b`, `gemma-e4` and `llama3` do; `coder14` returns a `<tools>` text block instead.

The full live lists are captured, not hand-written: refresh with `make capture`.

## Routing Policy

- Small and light work uses the local athena GPU.
- Interactive complex work uses the beast MI25.
- Long-running and heavier work uses the 120B on beast's CPU, leaving the MI25 free; the two run concurrently as separate routers.
- See `documents/10-routing-policy.md` for the full policy and `documents/09-tool-integration.md` for the three-tier tool mapping.

## Requirement: facts come from captures

- Any task that states model ids, contexts, or ports must verify them against the latest `dataflow.in/endpoints/` capture or a live `GET /v1/models`, and mark the document `verified <date>`.
- Do not hand-copy model lists into documents; derive them from the captures.
