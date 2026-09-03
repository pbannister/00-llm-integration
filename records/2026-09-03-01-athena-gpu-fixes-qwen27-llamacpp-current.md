# Record: athena GPU fixes + qwen27 preset; llama.cpp current on both hosts — 2026-09-03

## llama.cpp builds live on both hosts (2026-09-03)

- **beast**: build **10801**, commit `dfc95c594` (source `~/sources/llama.cpp` at that HEAD; installed 05:54, `llama.service` restarted 05:58). Health OK, 14 models.
- **athena**: build **10776**, commit `2d7523fa7` (the local "Local builds." commit; re-installed 05:53 from `~/sources/llama.cpp/build-x64-linux-vulkan-release`; `llama.service` restarted 05:58). Health OK, **16 models**.
- `qwen4exp` (Qwen3.8-Flash-Next) arch present on both (93 refs each).
- **Note**: athena's `~/sources/llama.cpp` HEAD is ~12 h behind beast's (`2d7523fa7` vs `dfc95c594`) — fetch on athena and rebuild if build parity is wanted.

## athena GPU was disabled — root cause and fix

- Symptom: every llama worker logged `no usable GPU found, --gpu-layers option will be ignored`; all athena models silently ran on CPU. The GPU itself was healthy (amdgpu bound to Navi 14; RADV enumerated fine from a normal preston session).
- Root cause: `/etc/systemd/system/llama.service` carried `Environment="GGML_VK_VISIBLE_DEVICES="` — an **empty** device list, which llama.cpp parses as zero usable devices. Reproduced directly: empty value → the warning; `=0` → GPU engages.
- Fix: set the value to `0` (RX 5500 XT device index). Unit backup: `llama.service.bak-20260902`.
- Verified with `llama-bench` (Llama-3.2-3B Q8, RX 5500 XT via RADV, Mesa 26.1.7-kisak): **prefill 49 → 438 t/s (9×), generation 10.7 → 26.0 t/s (2.4×)**.

## athena chat completions were corrupt — fix

- The router forced `--chat-template llama3` in the unit `ExecStart`, applying the Llama-3 chat template to **every** model (wrong for Qwen/gemma and even corrupting Llama-3.2 itself). Removed the flag so models use their native GGUF templates (beast's unit never had it).
- Verified: `llama3` and `coder3` answer "OK" through the router.

## qwen27 preset added (athena)

```ini
[batiai/Qwen3.8-27B-GGUF:Q4_K_M]
alias = qwen27
ctx-size = 16384
flash-attn = false
cache-type-v = f16
temp = 0.6
top-p = 0.95
```

- Dense 27B, `qwen3_5` arch (supported by athena's build), native 256K ctx; Q4_K_M is a ~16 GB single-file GGUF.
- No explicit `ngl` → `fit` trims layers to the 8 GB VRAM, excess on CPU (same stability pattern as beast's 2026-09-02 GPU-preset change: `flash-attn = false` requires `cache-type-v = f16`). Athena's other small fully-offloaded GPU presets keep their original settings.
- Registered (unloaded; athena now 16 models). Baseline: `config.ini.bak-20260903`. First use downloads ~16 GB.

## Notes

- beast `qwen38` (Qwen3.8-Flash-Next, 119 GB Q4) still unloaded — first use downloads ~119 GB (239 GB free on `/home`).
- Both hosts now run llama.cpp with `qwen4exp` + `qwen35` support; athena GPU confirmed working end-to-end via llama-bench and router smoke tests.
