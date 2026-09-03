# Record: beast per-model tuning verification + op-offload discovery — 2026-09-03

## Discovery: llama.cpp `--op-offload` (default true) ships host-RAM prefill ops to the GPU

While watching gpt-oss-120b (`ngl 0`, CPU preset) on nvtop, the GPU showed ~50 % activity during prompt
processing with the CPU mostly idle. Root cause: llama.cpp's `--op-offload` (default **true**) offloads
"host tensor operations" (big-batch prefill matmuls over CPU-resident weights) to the Vulkan device —
streaming ~58 GB of RAM weights over PCIe. Measured effect (same model/prompt):

| config | prefill | notes |
| ---- | ---- | ---- |
| default (op-offload ON → PCIe GPU) | 14.1 t/s | GPU ~50 %, CPU idle |
| `--no-op-offload` (pure CPU) | 32.1 t/s | 16 cores, GPU 0 % |

Fix applied: `op-offload = false` added to the CPU presets (gpt-oss-120b, r1-70b, llama70, qwen38).
Config key verified to reach child args (`--no-op-offload` in spawn args).

## Per-model verification (each model alone, service restarted between tests)

| Model | config | result | prefill | decode |
| ---- | ---- | ---- | ---- | ---- |
| gpt-oss-120b | CPU preset + no-op-offload | **GPU 0 % whole run**, ~16 CPU cores | 27.5 t/s | 9.8 t/s |
| gemma-26b | ctx 81920 → **8192** + `load-mode = none` | weights fully GPU (VRAM 14.9 GiB, "tensor overrides" warning gone); residual brief CPU bursts from KV side (13.3 GiB weights + KV cannot fully fit 16 GiB) | ~28–49 t/s | ~21 t/s |
| coder32 | fit-trimmed (unchanged) | weights 18.5 GiB **> 16 GiB card**: ~13.5 GiB GPU + ~5 GiB CPU in parallel; physical max | 10.2 t/s | 4.0 t/s |
| qwen38 (Flash-Next, Q4_K_M 111 GiB) | GPU-fit (fit-trimmed ~14.3 GiB) vs CPU-only | GPU-fit wins both metrics | 35.4 vs 23.1 t/s | 7.2 vs 5.0 t/s → **GPU-fit chosen** |

gemma-26b at its old 81920 ctx was mixed GPU/CPU with 2.4 t/s prefill; GPU-only required the ctx cut
(tradeoff: it is no longer the large-context model — it is now a fast mid-ctx GPU model, ~21 t/s decode).

## qwen38

Downloaded 2026-09-03 (~111 GiB, `batiai/Qwen3.8-Flash-Next-GGUF`, 3 splits) into beast's HF cache.
**Not yet backed up** to `/backups/huggingface/` (do so via `sources/models/backup.sh`).

## Config changes (baselines: `config.ini.bak-20260903-opoffload`, earlier `.bak-20260902*`)

- `op-offload = false` on CPU presets: gpt-oss-120b, r1-70b, llama70, qwen38.
- gemma-26b: `ctx-size = 8192`, `load-mode = none`.
- qwen38: switched from CPU-only (ngl 0) to GPU-fit (no ngl; flash-attn false; V f16; op-offload false).

## Notes / open items

- VRAM guard: this llama.cpp build has `--models-max` (default 4, count-based LRU eviction — see
  ggml-org/llama.cpp issue #20137 for its TOCTOU race) but no VRAM-aware scheduler, no unload endpoint,
  and no idle-stop flag. Decision on `--models-max` and cache trimming pending owner review (see chat
  2026-09-03).
- coder32 on beast is a poor fit (weights exceed VRAM; 4.0 t/s decode); candidate for removal.
- gemma-12b likely needs the same ctx/load-mode treatment as gemma-26b (untested).
