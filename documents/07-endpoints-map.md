# Endpoints Map — verified 2026-08-26

Live-state facts captured from `GET /v1/models` on both routers (last refreshed 2026-09-03).
Captured responses: `dataflow.in/endpoints/beast-models.json`, `dataflow.in/endpoints/athena-models.json`.

## Inference Hosts

| Host | Role | Hardware | RAM | Backend |
| ---- | ---- | ---- | ---- | ---- |
| `beast.lan` (192.168.8.20) | heavy server | AMD Instinct MI25, 16 GB VRAM (Vulkan, `GGML_VK_VISIBLE_DEVICES=1`) | 256 GB (dual Xeon, NUMA) | llama.cpp router |
| `athena.lan` (192.168.8.21) | desktop (this machine) | AMD RX 5500 XT, 8 GB VRAM | 128 GB (Ryzen 9 5900X, 12 threads) | llama.cpp router |
| `minerva.lan` (192.168.8.186) | travel laptop | unverified | unverified | none yet (planned) |

## Endpoints

| Endpoint | Base URL | Default context | Auth |
| ---- | ---- | ---- | ---- |
| beast GPU router | `http://beast.lan:2001/v1` | 32768 | none configured (`--api-key` not set) |
| beast CPU router | `http://beast.lan:2002/v1` | 65536 (gpt-oss-120b) | none configured |
| athena router | `http://athena.lan:2001/v1` | 8192 | none configured |
| DSH web GUI (athena) | `http://127.0.0.1:3080` | — | — |

Both routers answer OpenAI-compatible chat completions with `--tools all`.
Model ids are preset section names or `hf-repo` cache names; the routers list 6 (beast GPU :2001), 1 (beast CPU :2002) and 17 (athena) models as of the 2026-09-03 capture.) with the preset file at `/usr/local/etc/config.ini` on each host (to confirm; the imported copies in `sources/models/config-*.ini` are older snapshots).
Each model entry in the capture carries its full child-server command line (`status.args`) and the generated preset text, including `ctx-size`, `ngl`, and `--alias`.

## Request Flow

1. A client (DSH, aider, llama.vscode, curl) sends an OpenAI-compatible request to a router base URL with a `model` id.
2. The router loads the matching child server (or uses the cached one) and forwards the request.
3. GPU models (no explicit `ngl`; `fit` trims layers to VRAM, excess on CPU) run on the host GPU; CPU models (`ngl 0`) run in system RAM with `numa = distribute` on beast.
4. The router returns the OpenAI-formatted streamed response.

## Concurrency

Router mode runs one child server per active model.
A CPU-heavy model (for example `gpt-oss-120b`) and a GPU model can be active concurrently, which is the basis of the routing policy in `documents/10-routing-policy.md`.
Each child serves one request at a time unless `parallel` is set in the preset.
