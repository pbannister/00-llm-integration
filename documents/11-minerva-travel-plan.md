# Minerva Travel Plan — deployed 2026-08-26 (hardware verified 2026-08-26)

The offline inference plan for the laptop `minerva.lan` (192.168.8.186).

## Verified Hardware (2026-08-26)

| Fact | Value |
| ---- | ---- |
| Host | `minerva` (Ubuntu 24.04.4 LTS) |
| CPU | AMD Ryzen 7 7840U (16 threads) |
| GPU | AMD Radeon 780M (RDNA3 iGPU, shared memory; Phoenix1) |
| Vulkan | Mesa RADV installed (`/usr/share/vulkan/icd.d/radeon_icd.json` present); `vulkaninfo` (vulkan-tools) not yet installed |
| RAM | 14 GiB total, ~12 GiB available (iGPU VRAM comes out of this) |
| Disk | 935 GB, ~678 GB free |
| llama.cpp | **installed 2026-08-26**: 0.3.0-dev (build 10642), Vulkan backend, `llama.service` active on `127.0.0.1:2001` |
| SSH | `ssh -i ~/.ssh/keys/key-athena preston@minerva.lan` (key-athena works; no dedicated key) |

## Travel Model Selection

The 780M with the shared 14 GiB pool comfortably runs Q4/Q8 models up to ~7B.
All candidate GGUFs are already on minerva (copied from athena 2026-08-26; exact files and sizes verified):

| Model (exact GGUF on disk) | Size | Expected ctx | Use |
| ---- | ---- | ---- | ---- |
| `qwen2.5-coder-3b-instruct-q8_0.gguf` | 3.37 GiB | 8192 | **recommended default**: coding + editing; FIM-capable |
| `Qwen3.5-4B-Q4_K_M.gguf` | 2.55 GiB | 8192 | general chat alternative |
| `gemma-4-E2B-it-qat-UD-Q4_K_XL.gguf` | 2.44 GiB | 8192 | light chat, battery-friendly |
| `qwen2.5-coder-1.5b-instruct-q8_0.gguf` | 1.76 GiB | 8192 | minimal fallback; fastest |

Also on disk (bonus quants that came with the repos): `qwen2.5-coder-3b-instruct-q4_k_m.gguf` (1.96 GiB) and `qwen2.5-coder-1.5b-instruct-q4_k_m.gguf` (1.04 GiB) — usable as lighter fallbacks.

Rationale: the 3B coder Q8 is the sweet spot — full coding capability, FIM support, ~2.5× the size of the 1.5B for far better output quality, and expected ~30–50 t/s on the 780M. Keep at or below 4B for battery life and thermals.

## Deployment Shape — executed 2026-08-26

Build notes: Ubuntu 24.04 needs `glslc` and `spirv-headers` (not `shaderc`, which is beast's package); run `sudo ldconfig` after `cmake --install`.

1. Build llama.cpp from source with the Vulkan backend (same process as athena/beast):
   ```sh
   sudo apt install -y mesa-vulkan-drivers libvulkan-dev vulkan-tools cmake git
   git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
   cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
   cmake --build build -j && sudo cmake --install build
   ```
2. Verify the GPU is seen: `vulkaninfo --summary` shows `AMD Radeon 780M (RADV PHOENIX1)`. Set `GGML_VK_VISIBLE_DEVICES=0` if more than one device appears.
3. Serve one small preset on `127.0.0.1:2001` (no router needed) — a `config.ini` with the default model:
   ```ini
   [*]
   ctx-size = 8192
   flash-attn = true
   [Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0]
   ngl = 99
   temp = 0.2
   top-p = 0.95
   ```
   launched as `llama-server --models-preset config.ini --host 127.0.0.1 --port 2001 --tools all`, ideally under a `systemd` unit (pattern from `sources/models/install.sh`).
4. Point the tools at the local server (aider / llama.vscode / optional DSH `minerva` route):
   - aider: `aider --openai-api-base http://127.0.0.1:2001/v1 --openai-api-key sk-local --model Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0 --edit-format whole`
   - llama.vscode: server URL `http://127.0.0.1:2001/v1`, completion/chat on the 3B coder.
   - Optional: a `minerva` DSH provider route (`llm-pi-ai`) if a DSH session ever runs on the laptop; same shape as the `beast` route in `sources/config/dsh-settings-beast.example.yaml`.
5. The GGUFs are already predownloaded into minerva's HuggingFace cache — nothing to fetch while travelling.

## Offline Checklist — status 2026-08-26

1. [x] `vulkaninfo --summary` shows the 780M (RADV) — verified.
2. [x] `curl http://127.0.0.1:2001/v1/models` lists the models — verified (6 listed).
3. [ ] Chat completion with the network disabled — verified via `coder3` on the live service; the truly-offline test remains for the user (disabling WiFi would drop the SSH session).
4. [ ] aider and llama.vscode answer from the local server with WiFi off — pending the user's offline test.

## Provisioning

`minerva.lan` is in the homelab Ansible inventory (192.168.8.186) with SSH.
A `Host minerva.lan` block in `~/.ssh/config` (User preston, IdentityFile `~/.ssh/keys/key-athena`) was added 2026-08-26; `ssh minerva.lan` verified. Ansible targets of minerva now resolve the key through the SSH config.
