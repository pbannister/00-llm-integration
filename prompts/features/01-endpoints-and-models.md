# Feature: Endpoints and Models

## Purpose

Defines the live inference endpoints, the model catalog, and the execution roles.
This is the base fact source for all other features.

## Requirements

- `ENDPOINTS-R001` — Clients must use the router's reported model id or its alias; the `UD-` preset-key form fails with `model not found`.
- `ENDPOINTS-R002` — `GET /v1/models` is the source of truth for model ids; a preset section key and the reported id can differ.
- `ENDPOINTS-R003` — Only models that emit parsed `tool_calls` belong in an agent loop. Verified 2026-11-24 against the live routers: `gpt-oss-20b`, `gpt-oss-120b`, `gemma-12b`, `gemma-e4`, `qwen9` and `llama3` do; `coder14` returns a `<tools>` text block and `coder3` returns a fenced JSON block instead. The 2026-09-25 verification named only four of these and missed `gemma-12b` and `qwen9`.
- `ENDPOINTS-R004` — Small and light work uses the local athena GPU.
- `ENDPOINTS-R005` — Interactive complex work uses the beast MI25.
- `ENDPOINTS-R006` — Long-running and heavier work uses the 120B on beast's CPU, leaving the MI25 free; the two run concurrently as separate routers.
- `ENDPOINTS-R007` — Any task that states model ids, contexts, or ports must verify them against the latest `dataflow.in/endpoints/` capture or a live `GET /v1/models`, and mark the document `verified <date>`.
- `ENDPOINTS-R008` — Do not hand-copy model lists into documents; derive them from the captures.
- `ENDPOINTS-R009` — The full live lists are captured, not hand-written; refresh them with `make capture`.

## Behavior

- Three llama.cpp router-mode servers answer OpenAI-compatible chat completions with `--tools all` on the house LAN.
- A client that uses a reported id or an alias completes a chat turn; one that uses the `UD-` preset-key form receives `model not found`.
- The routing policy is described in `documents/10-routing-policy.md` and the three-tier tool mapping in `documents/09-tool-integration.md`.

## Dependencies

- None.

## Endpoints

Three llama.cpp router-mode servers answer on the house LAN:

- `http://beast.lan:2001/v1` — heavy server, GPU router. MI25 16 GB VRAM (Vulkan backend, `GGML_VK_VISIBLE_DEVICES=1`), dual Xeon, 256 GB RAM, `--models-max 1`, `parallel = 1`. Default context 32768; large per-model contexts up to 81920.
- `http://beast.lan:2002/v1` — heavy server, CPU router. `unsloth/gpt-oss-120b-GGUF` at `ngl = 0`, `numa = distribute`, 65536 context, `parallel = 1`.
- `http://athena.lan:2001/v1` — desktop server. RX 5500 XT 8 GB VRAM, Ryzen 9 5900X (12 threads), 128 GB RAM, `parallel = 1`. Default context 16384. Changed 2026-11-24 from `parallel = 4` at 8192, which gave each request only 2048 tokens and failed any longer editor or agent request with `exceeds the available context size`.

Model ids are the resolved preset names or `hf-repo` cache names, and each preset also carries a short alias.
Captured responses live in `dataflow.in/endpoints/`; see `documents/07-endpoints-map.md`.

## Id Resolution

A preset section key and the router's reported model id can differ.
`config.ini` writes the repository quant selector (`unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL`), while `GET /v1/models` reports the resolved file quant (`unsloth/gpt-oss-20b-GGUF:Q4_K_XL`).

## Catalog and Execution Roles

Models fall into execution classes per host:

- Local GPU (athena): `coder3` and `coder15` (`Qwen/Qwen2.5-Coder-3B`/`1.5B` Q8) for FIM completion, `llama3` (`unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0`) and `gemma-e4` (`unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL`) for small chat and tools, and `qwen27` (`batiai/Qwen3.8-27B-GGUF:Q4_K_M`) as a GPU plus CPU split.
- Athena CPU fallback, used when beast is offline: `coder32-fallback` (`Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M`) and `r1-32b-fallback` (`unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_M`), both 16384 context at `ngl = 0`. The r1 preset key named `UD-Q4_K_XL` until 2026-11-24, but the cache holds only `Q4_K_M`, so the child server failed to load; the key now names the quant on disk.
- Athena embeddings: `nomic-embed` (`ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0`), serving `/v1/embeddings`.

Beast GPU-resident on :2001: `coder14` (`bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M`, 16384) for chat and editing, `qwen9` (`unsloth/Qwen3.5-9B-GGUF:Q4_K_M`, 32768), `gpt-oss-20b` (`unsloth/gpt-oss-20b-GGUF:Q4_K_XL`, 32768) for agent and tool calls, `gemma-12b` (`unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`, 32768), and `gemma-26b` (`unsloth/gemma-4-26B-A4B-it-qat-GGUF:Q4_K_XL`, 81920). `qwen38` (`batiai/Qwen3.8-Flash-Next-GGUF:Q4_K_M`) was removed from the router on 2026-11-24: policy never approved it, and listing it only invited clients to select a model that cannot fit the MI25.

Beast CPU-heavy on :2002: `gpt-oss-120b` (`unsloth/gpt-oss-120b-GGUF:Q4_K_XL`, 65536) for planning, long-running agent loops, and large background tasks.

## Multimodal Input

The routers advertise `input_modalities` in `/v1/models`, but the advertised value is not proof the router accepts that input. Verified 2026-11-24:

- `gemma-12b`, `gemma-26b`, `gemma-e4`, `qwen9` and `qwen27` advertise `image`; `gemma-12b` and `gemma-e4` also advertise `audio`.
- No preset passed `--mmproj` until 2026-11-24, so a vision request reached the router without a projection model. On beast an image request to `gemma-12b` returns `400 Failed to load image or audio file`.
- The `mmproj-BF16.gguf` projection file is already in both caches, so enabling vision is a preset change, not a download.
- Vision on the MI25 does not fit: loading `gemma-4-12B` with its projection at 8192 context exhausts the 16 GiB card (`allocateMemory ErrorOutOfDeviceMemory`). Athena's `gemma-e4` with its projection loads and accepts an image request (verified 2026-11-24).
- A vision preset must therefore name `mmproj` explicitly and be sized to the host; do not treat the advertised modality as available.
- Fixed 2026-11-24: the athena `gemma-e4` preset now names its cached `mmproj`, so an image request through the live router returns "The image is red." The beast `gemma-12b` preset stays text-only: its projection does not fit the MI25 at a usable context.

## Routing Policy

- Long work and the MI25 run concurrently as separate routers, so the two never contend for the GPU.
- The full policy is in `documents/10-routing-policy.md`; the three-tier tool mapping is in `documents/09-tool-integration.md`.
