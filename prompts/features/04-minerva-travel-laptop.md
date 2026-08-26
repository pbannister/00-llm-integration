# Feature: Minerva Travel Laptop

Defines the offline inference plan for the laptop `minerva.lan` (192.168.8.186, WiFi, SSH available per the homelab inventory).

## Hardware (verified 2026-08-26)

- CPU: AMD Ryzen 7 7840U (16 threads).
- GPU: AMD Radeon 780M (RDNA3 iGPU, shared memory) — Vulkan via Mesa RADV expected; confirm with `vulkaninfo --summary`.
- RAM: 14 GB total (~11 GB available); iGPU VRAM comes out of this pool.
- Disk: 935 GB, ~691 GB free.
- OS: Ubuntu 24.04.4 LTS. llama.cpp not yet installed.
- SSH: `ssh -i ~/.ssh/keys/key-athena preston@minerva.lan` works (key-athena is the access key).

## Goal

When travelling, the laptop has no LAN access to beast or athena. The laptop should run a small model locally so aider and llama.vscode keep working offline.

## Discovery First

Before any deployment, discover:

- GPU: `lspci | grep -iE 'vga|3d'`, `vulkaninfo --summary` (Vulkan-capable?), or CUDA (`nvidia-smi`).
- RAM: `free -h`.
- Disk: `df -h ~` (the GGUF must be predownloaded).

Record the findings in `records/` and update `documents/07-endpoints-map.md`.

## Model Candidates (from the existing catalog)

- `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` — recommended default: coding + editing, FIM-capable; fits the shared-memory iGPU comfortably.
- `unsloth/gemma-4-E2B-it-qat-GGUF:UD-Q4_K_XL` — 2B QAT gemma, small and capable.
- `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` — general chat alternative.
- `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` — minimal fallback; fastest.
- `unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL` — 4B, upper bound for the laptop.

Keep the travel model at or below 4B parameters for battery life and thermals.

## Deployment Shape

- Install llama.cpp on minerva (Vulkan backend for AMD/Intel iGPUs; CUDA for NVIDIA), following the pattern in `sources/models/install.sh` adapted to a single preset or a small router preset on `127.0.0.1:2001`.
- Point aider (`--openai-api-base http://127.0.0.1:2001/v1`) and llama.vscode at the local server.
- The same `llm-pi-ai` provider shape from `02-dsh-provider-integration.md` applies if a DSH session ever runs on the laptop.
- Predownload the chosen GGUF into the HuggingFace cache before travelling.

## Requirement: offline-verified

- The travel plan must state the model, the exact GGUF, its size on disk, and the expected context, each verified on minerva before the plan is marked done.
- Use the homelab Ansible inventory (`minerva.lan`, SSH) for provisioning once specs are known.
