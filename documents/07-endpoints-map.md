# Endpoints Map — verified 2026-09-25

Live-state facts captured from `GET /v1/models` on the routers.
Captured responses: `dataflow.in/endpoints/beast-models.json` (6 models), `dataflow.in/endpoints/beast-cpu-models.json` (1 model), `dataflow.in/endpoints/athena-models.json` (16 models).

## Inference Hosts

| Host | Role | Hardware | RAM | Backend |
| ---- | ---- | ---- | ---- | ---- |
| `beast.lan` (192.168.8.20) | heavy server | AMD Instinct MI25, 16 GB VRAM (Vulkan, `GGML_VK_VISIBLE_DEVICES=1`) | 256 GB (dual Xeon, two 128 GB NUMA nodes) | llama.cpp router |
| `athena.lan` (192.168.8.21) | desktop (this machine) | AMD RX 5500 XT, 8 GB VRAM | 128 GB (Ryzen 9 5900X, 12 threads) | llama.cpp router |
| `minerva.lan` (192.168.8.186) | travel laptop | AMD Radeon 780M iGPU | 14 GB shared | llama.cpp, single preset |

## Endpoints

| Endpoint | Base URL | Preset file | Default context | Parallel | Auth |
| ---- | ---- | ---- | ---- | ---- | ---- |
| beast GPU router | `http://beast.lan:2001/v1` | `/usr/local/etc/config.ini` | 32768 | 1 | none (`--api-key` not set) |
| beast CPU router | `http://beast.lan:2002/v1` | `/usr/local/etc/config-cpu.ini` | 65536 | 1 | none |
| athena router | `http://athena.lan:2001/v1` | `/usr/local/etc/config.ini` | 8192 | 4 | none |

Preset-file paths verified on the hosts 2026-09-25.
Both beast routers answer OpenAI-compatible chat completions with `--tools all`.
Model ids are the resolved preset names or `hf-repo` cache names, and each preset also carries a short alias; see `documents/08-model-catalog.md` for the curated list and the preset-key-versus-id rule.
Each model entry in the capture carries its full child-server command line (`status.args`) and the generated preset text, including `ctx-size`, offload depth, and `--alias`.

## Request Flow

1. A client (DSH, aider, llama.vscode, curl) sends an OpenAI-compatible request to a router base URL with a `model` id or alias.
2. The router loads the matching child server (or uses the already-resident one) and forwards the request.
3. GPU presets run on the host GPU, with `fit = on` trimming layers to VRAM and excess layers on CPU; CPU presets (`ngl 0`) run in system RAM with `numa = distribute` on beast.
4. The router returns the OpenAI-formatted streamed response.

The endpoint value a client stores must not include `/v1` for llama.vscode: the extension appends `/infill` for FIM and `/v1/chat/completions` for chat, and accepts either form for other clients.

## Concurrency

Router mode runs one child server per active model.
A CPU-heavy model (for example `gpt-oss-120b` on `:2002`) and a GPU model on `:2001` can be active concurrently, which is the basis of the routing policy in `documents/10-routing-policy.md`.
The beast GPU router runs `--models-max 1`, so two different GPU models evict each other; the CPU router coexists freely.
Each child serves one request at a time unless `parallel` is set in the preset.
Context is per slot: a preset's `ctx-size` is divided by the router's `parallel`, so the athena default is 2048 tokens per request.
