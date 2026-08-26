# Minerva Travel Plan — hardware verified 2026-08-26

The offline inference plan for the laptop `minerva.lan` (192.168.8.186).

## Verified Hardware (2026-08-26)

| Fact | Value |
| ---- | ---- |
| Host | `minerva` (Ubuntu 24.04.4 LTS) |
| CPU | AMD Ryzen 7 7840U (16 threads) |
| GPU | AMD Radeon 780M (RDNA3 iGPU, shared memory; Phoenix1) — Vulkan via Mesa RADV expected; confirm `vulkaninfo --summary` and install `mesa-vulkan-drivers` if missing |
| RAM | 14 GB total, ~11 GB available (iGPU VRAM comes out of this) |
| Disk | 935 GB, ~691 GB free |
| llama.cpp | not installed |
| SSH | `ssh -i ~/.ssh/keys/key-athena preston@minerva.lan` (the key-athena key works; no dedicated minerva key) |

## Travel Model Selection

The 780M iGPU with shared memory comfortably runs Q4/Q8 models up to ~7B with the 14 GB pool.
Candidates from the existing catalog (all already downloaded):

| Model | Size | Use |
| ---- | ---- | ---- |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` | 3.36 GB | recommended default: coding + editing; FIM-capable |
| `unsloth/gemma-4-E2B-it-qat-GGUF:Q4_K_XL` | 2.43 GB | light chat, battery-friendly |
| `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` | ~2.5 GB | general chat alternative |
| `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` | 1.76 GB | minimal fallback; fastest |

Keep at or below 4B for battery life and thermals; the 3B coder Q8 is the sweet spot (expected ~30–50 t/s on the 780M).

## Deployment Shape

- Install llama.cpp with the Vulkan backend (`GGML_VK_VISIBLE_DEVICES=0` if more than one device appears).
- Serve one small preset on `127.0.0.1:2001` (pattern from `sources/models/install.sh`, adapted to a laptop service; no router needed).
- Point aider at `http://127.0.0.1:2001/v1` (`--edit-format whole`) and llama.vscode at the same base URL.
- Optional: a `minerva` DSH provider route (`llm-pi-ai`) if a DSH session ever runs on the laptop; same shape as the `beast` route in `sources/config/dsh-settings-beast.example.yaml`.
- Predownload the chosen GGUF into the HuggingFace cache before travelling.

## Offline Checklist

1. Confirm Vulkan works: `vulkaninfo --summary` shows the 780M.
2. Serve the model; `curl http://127.0.0.1:2001/v1/models` lists it.
3. One chat completion succeeds with the laptop's network disabled.
4. aider and llama.vscode answer from the local server with WiFi off.

## Provisioning

`minerva.lan` is in the homelab Ansible inventory (192.168.8.186) with SSH.
Add the key-athena path as the SSH key for minerva in the inventory or `~/.ssh/config` before Ansible targets it.
