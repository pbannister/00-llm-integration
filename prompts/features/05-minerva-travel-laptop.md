# Feature: Minerva Travel Laptop

## Purpose

Defines the offline inference plan for the laptop `minerva.lan` (192.168.8.186, WiFi, SSH available per the homelab inventory).

The laptop uses only local models. It does not call beast or athena by default, whether or not it is on the home subnet. A local llama.cpp server on `127.0.0.1:2001` is the only inference endpoint its clients use. This keeps the laptop usable when travelling, keeps its latency predictable, and stops a laptop session from occupying a router slot on a shared host.

## Requirements

- `MINERVA-R001` — Before any deployment, discover the GPU (`lspci`, `vulkaninfo --summary`, `nvidia-smi`), the RAM (`free -h`), and the disk (`df -h ~`); record the findings in `records/` and update `documents/07-endpoints-map.md`.
- `MINERVA-R002` — Keep the travel model at or below 4B parameters, for battery life and thermals.
- `MINERVA-R003` — Install llama.cpp on minerva with the backend the discovered GPU needs (Vulkan for AMD and Intel iGPUs, CUDA for NVIDIA), following the pattern in `sources/models/install.sh` adapted to a single preset or a small router preset on `127.0.0.1:2001`.
- `MINERVA-R004` — Point aider (`--openai-api-base http://127.0.0.1:2001/v1`) and llama.vscode at the local server. **Corrected 2026-11-24 (owner):** the laptop uses only local models. Its client configuration must name `127.0.0.1:2001` and must not name `beast.lan` or `athena.lan`, whether or not the laptop is on the home subnet. Reaching a router from the laptop is not a default; it is a deliberate, per-session choice.
- `MINERVA-R005` — Predownload the chosen GGUF into the HuggingFace cache before travelling.
- `MINERVA-R006` — The travel plan must state the model, the exact GGUF, its size on disk, and the expected context, each verified on minerva before the plan is marked done.
- `MINERVA-R007` — Use the homelab Ansible inventory (`minerva.lan`, SSH) for provisioning once the specifications are known.
- `MINERVA-R008` — Archive the laptop's model cache to beast's `/backups/huggingface/` while the two are on the same subnet. The laptop has no `/backups` volume of its own (single 935 GB volume), so beast is its archive. A backup run with beast unreachable skips and reports it; it does not fall back to a local archive.

## Behavior

- With no LAN access, aider and llama.vscode reach a local llama.cpp server on `127.0.0.1:2001` and complete an edit and a chat turn.
- On the home subnet, the same local server serves the same clients. The laptop does not switch to beast or athena when they are reachable.
- The plan is marked done only after the stated model, GGUF, size on disk, and context have been observed on minerva.

## Dependencies

- `prompts/features/03-dsh-provider-integration.md`

## Hardware (verified 2026-08-26)

- CPU: AMD Ryzen 7 7840U (16 threads).
- GPU: AMD Radeon 780M (RDNA3 iGPU, shared memory) — Vulkan via Mesa RADV expected; confirm with `vulkaninfo --summary`.
- RAM: 14 GB total (~11 GB available); iGPU VRAM comes out of this pool.
- Disk: 935 GB, ~691 GB free.
- OS: Ubuntu 24.04.4 LTS. llama.cpp not yet installed.
- SSH: `ssh -i ~/.ssh/keys/key-athena preston@minerva.lan` works (key-athena is the access key).

## Model Candidates (from the existing catalog)

- `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` — recommended default: coding + editing, FIM-capable; fits the shared-memory iGPU comfortably.
- `unsloth/gemma-4-E2B-it-qat-GGUF:Q4_K_XL` — 2B QAT gemma, small and capable.
- `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` — general chat alternative.
- `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` — minimal fallback; fastest.
- `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL` — 4B, upper bound for the laptop.

## Deployment Shape

- The same `llm-pi-ai` provider shape from `prompts/features/03-dsh-provider-integration.md` applies if a DSH session ever runs on the laptop.
- The local server mirrors the router preset shape already used on beast and athena, so the client configuration differs only in `baseURL` — and that `baseURL` is `http://127.0.0.1:2001/v1`, never a router address (`MINERVA-R004`).
- Backups: `make backup-models HOSTS=minerva` archives the laptop's cache to beast's `/backups/huggingface/` while the two are on the same subnet (`MINERVA-R008`).
