# Record: MI25 Vulkan device-lost — GPU-preset stability tuning — 2026-09-02

## Incident

- 2026-09-02 20:40:55 on beast: amdgpu `ring comp_1.1.0 timeout` on the MI25 (0000:43:00.0) while the `llama.service` coder32 worker (Qwen2.5-Coder-32B, pid 731052) was mid-decode (~64 s into its first heavy prompt after a 20:37 lazy spawn). The ring reset recovered the GPU, but the Vulkan context was destroyed (`ErrorDeviceLost`, `device lost on Vulkan0`), the in-flight task errored, and slot 3's KV state was left torn — later coder32 requests failed with `Invalid input batch` (KV ended at pos 511, batch started at 1526) until the worker aborted on its own at 20:52:09 (`vk::DeviceLostError` during teardown). The router (PID 653773) survived and respawned workers on demand.
- **Not a one-off**: 60 device-lost events in the `llama.service` journal since Jul 31 (storms Aug 24, Aug 31, Sep 1 evening — 8 resets 18:00–19:30 — and Sep 2). Matches the upstream llama.cpp Vulkan-on-AMD device-lost class: [ggml-org/llama.cpp #21724](https://github.com/ggml-org/llama.cpp/issues/21724) (device lost from GPU job/batch size), [ggml-org/llama.cpp #20515](https://github.com/ggml-org/llama.cpp/issues/20515) (sensitive to ubatch/ctx length). gfx900 (VEGA10 = MI25) is legacy in RADV (Mesa 25.2.8) and is already being blocked as unsupported by consumers such as [ollama #12481](https://github.com/ollama/ollama/pull/12481).

## Root cause analysis

- The GPU presets forced `ngl = 99`, which **defeats `fit = on`** (`failed to fit params to free device memory: n_gpu_layers already set by user to 99, abort`) — coder32's 18.49 G Q4 weights exceed the 16 GiB MI25 even at zero context (see `records/2026-08-26-10-kv-quant-applied.md`), so the explicit 99 forced VRAM overcommit / GTT pressure during decode instead of the intended CPU fallback for excess layers.
- `flash-attn = true` on VEGA10 — FA kernels are implicated in the device-lost class.
- Contributing: `parallel = 4` + `cache-reuse 256` KV juggling, llama.cpp build 10726 (commit 63f45bd2c), kernel 6.8.0-138.
- Fanctl ramping to junction ~72 °C before the crash was normal load response, not a thermal trip (HBM2 junction limit is well above that).

## Change applied (beast only; baseline `/usr/local/etc/config.ini.bak-20260902`)

For all eight GPU presets (coder32, coder14, qwen9, gpt-oss-20b, gemma-12b, devstral, r1-14b, gemma-26b):

- removed `ngl = 99` so `fit = on` trims layers to the 16 GiB VRAM (excess layers run on the dual-Xeon CPU — the intended design per `records/2026-08-26-10`);
- `flash-attn = false`;
- `cache-type-v = f16` — **required**: llama.cpp refuses a quantized V cache without flash-attn (`quantized V cache requires flash_attn to be enabled`); K cache stays `q8_0`.

CPU heavyweights (gpt-oss-120b, r1-70b, llama70) untouched — still `ngl = 0`, CPU-only. Athena untouched (its presets genuinely fit its GPU); revisit if athena's GPU shows the same resets. CORS not changed (tools mode defaults to localhost-only origins; optional `--cors-origins` in the unit's `ExecStart`).

## Gotcha discovered

The router **snapshots `/usr/local/etc/config.ini` at `llama.service` start** — it does not re-read the preset file per worker spawn. Edits require `sudo systemctl restart llama.service` to take effect (observed: post-edit respawns kept `--flash-attn true` until the restart).

## Verification

- `llama.service` restarted, active, `NRestarts=0`; **0 kernel resets** during/after.
- coder32 and coder14 respawn with `--flash-attn false --cache-type-v f16` and no `--n-gpu-layers`; both answered smoke tests ("OK") in 13–21 s.
- Remaining GPU presets share the same settings — verify on first lazy load.

## Notes / recommendations

- Watch: `journalctl -k | grep -E 'timeout|wedge'` and `journalctl -u llama.service | grep -E 'device lost'`.
- If hangs recur with FA off + fit-trimmed layers: drop `parallel` to 2 on GPU presets, shrink coder32 `ctx-size`, or move off gfx900 (legacy platform).
- On the next hang, grab `/sys/class/drm/card1/device/devcoredump/data` immediately — the kernel auto-expires it in ~5 min (already gone by the time of this investigation).
- Minor: a llama.cpp crash handler run under gdb prints a long backtrace into the journal on abort; harmless.
