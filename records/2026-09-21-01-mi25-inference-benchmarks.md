# Record: MI25 inference benchmarks on beast — 2026-09-21

## Outcome

Measured MI25 (Vulkan, RADV VEGA10) throughput on beast for the models that fit fully in VRAM, and for Qwen3.8-Flash-Next with and without offload.
The GPU is a large win for resident models: 6.4x and 7.0x generation speedups at `ngl 99` over CPU-only.
Qwen3.8-Flash-Next cannot be made to work well on this host: CPU-only is 4.43 t/s, and full offload is 5.3x *slower* (0.84 t/s).
The limiting component on beast is the CPU, not the GPU: the E5-2667 v2 has no AVX2 and no FMA.
No service config was changed, and no files outside this record.

## Measurements (verified 2026-09-21, beast.lan)

All numbers from `llama-bench`, one repetition, `--no-warmup`, running against the splits already in the standard HF cache.
Generation is `tg`; prefill is `pp`.

### Models that fit VRAM

| Model | Quant | Weights | `ngl` | Prefill | Generation |
| ---- | ---- | ---- | ---- | ---- | ---- |
| `unsloth/Qwen3.5-9B-GGUF` | Q4_K_M | 5.28 GiB | 0 | 130.00 t/s | 6.04 t/s |
| `unsloth/Qwen3.5-9B-GGUF` | Q4_K_M | 5.28 GiB | 99 | 456.84 t/s | 42.18 t/s |
| `unsloth/gemma-4-12B-it-qat-GGUF` | UD-Q4_K_XL | 6.24 GiB | 0 | 97.46 t/s | 4.69 t/s |
| `unsloth/gemma-4-12B-it-qat-GGUF` | UD-Q4_K_XL | 6.24 GiB | 99 | 235.76 t/s | 30.10 t/s |

Offload gain: Qwen3.5-9B 7.0x generation and 3.5x prefill; gemma-4-12B 6.4x generation and 2.4x prefill.

### Qwen3.8-Flash-Next

`batiai/Qwen3.8-Flash-Next-GGUF:Q4_K_M`, reported by llama.cpp as `qwen4exp A3B Q4_K - Medium`, 110.96 GiB, 176.94 B params.

| `ngl` | Prefill (pp256) | Generation (tg32) | Note |
| ---- | ---- | ---- | ---- |
| 0 | 9.01 t/s | 4.43 t/s | best available configuration |
| 99 | 10.57 t/s | 0.84 t/s | 5.3x slower than `ngl 0` |

The `ngl 99` result is a silent VRAM spill, not a load failure.
The verbose load log shows `load_tensors` assigning every layer to Vulkan0 while the device reported roughly 141 MiB free, with no error and no warning.
This reproduces the offload cliff reported for this model elsewhere, on this host.

## Decisions

- Do not deploy `qwen38` on the MI25. At 111 GiB it cannot fit, and every offload configuration measured worse than CPU-only.
- Keep `qwen38` at `ngl = 0` (CPU) if it is kept at all, as a batch tool. Its realistic ceiling on beast is 4.43 t/s, which is below leaving a 9B model on CPU.
- Treat the MI25 as the fast path on beast for models that fit, and prefer GPU-resident 9B-12B models for interactive work.
- Do not change generation thread count. `config.ini` sets no thread keys, so llama.cpp uses its default of 16 of 32. Prompt processing scales with threads but generation is bandwidth-bound and flat past roughly 8-16, so raising `-t` is not justified by evidence.
- `threads-batch = 32` for faster prefill remains an untested hypothesis with a mechanism, not a measured result. It needs its own A/B before being applied.

## Supporting facts (verified 2026-09-21)

- MI25 total VRAM is 17,163,091,968 bytes (15.98 GiB), as reported by `rocm-smi --showmeminfo vram`.
- PCIe link is 8 GT/s x16 (PCIe 3.0 x16) at full negotiated width, from `lspci -vv` `LnkSta` and sysfs `current_link_width`.
- beast CPU is `Intel Xeon E5-2667 v2`, 32 threads, two NUMA nodes of 128 GB each.
  The flag set is `avx` and `f16c` but **no `avx2` and no `fma`**, which slows llama.cpp's Q4_K/Q5_K paths and is the reason CPU-only inference sits at 4.7-6 t/s.
- llama.cpp on beast is 0.4.0-dev, build 10893, commit `79b0048df`.
- All six beast GPU presets override the globals with `flash-attn = false` and `cache-type-v = f16`, so none silently runs flash attention on gfx900. Verified by reading every preset body in `/usr/local/etc/config.ini`.
- A live child server spawned from the router confirmed `--ctx-size 32768` for `gemma-12b`.
- The MI25 has produced no device-loss events in the seven days before this record.

## Corrections to earlier claims

These statements were made during this session and are wrong. They are recorded so a later session does not act on them.

- **"The MI25 sits on a PCIe x4 riser."** Never verified and false. The link is 3.0 x16.
- **"The Vulkan backend has no GDN/DeltaNet kernels."** A substring artifact: searching for `gdn` missed the spelled-out `gated_delta_net`, of which `libggml-vulkan.so.0.23.0` has 23 occurrences, plus `gated_linear_attn` and the SSM scan/conv kernels. Kernel presence does not by itself prove a working gfx900 path, but their absence was never the reason Qwen3.8 fails here.
- **"The per-router caches are empty and re-download models."** The entries under `~/.cache/hf-gpu/hub` and `~/.cache/hf-cpu/hub` are symlinks into `/home/preston/.cache/huggingface/hub`, so each model is stored once and the scoped-cache isolation in `documents/10-routing-policy.md` works as described. `find` without `-L` and `du` on a symlink reported them as empty.

## Verification

- `llama-bench` runs above, 2026-09-21, from `/usr/local/bin/llama-bench` with `GGML_VK_VISIBLE_DEVICES=1`, against files under `~/.cache/huggingface/hub/models--batiai--Qwen3.8-Flash-Next-GGUF/` and `.../models--unsloth--gemma-4-12B-it-qat-GGUF/`.
- Measure again with, for example:
  `GGML_VK_VISIBLE_DEVICES=1 llama-bench -m <model.gguf> -ngl 0,99 -p 512 -n 128 -r 1 --no-warmup`
- Temporary reconnaissance scripts used for this episode were removed from the host and are not committed.
- Router state after measurement: `gemma-12b` left resident on `:2001` by the child-args check; all other presets unloaded.

## Commits

- See `git log -- records/2026-09-21-01-mi25-inference-benchmarks.md` — docs: MI25 inference benchmarks on beast (9B/12B offload wins, qwen38 spill); record 2026-09-21.
  The commit that adds this file is cited by subject and path rather than by hash, because a commit cannot contain its own hash: writing that hash into the file changes the hash again.
