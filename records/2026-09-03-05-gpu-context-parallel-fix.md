# Record: GPU-router context fix — parallel 1 + gemma-26b large context restored — 2026-09-03

## Symptom

"Running out of context very quickly" on beast's GPU-only models. Root cause: `parallel = 4`
in the GPU config divided every model's context across 4 slots, so a single conversation was
confined to `n_ctx_slot = preset_ctx / 4` (coder14/qwen38 4096, gemma-26b 2048, others 8192).

## Changes (backup: `config.ini.bak-20260903-parallel`)

- GPU config (`/usr/local/etc/config.ini`, router :2001): `parallel = 4` → **1** — each model
  now serves the full preset context per conversation (verified: qwen9 32768, coder14 16384,
  gemma-26b 8192→81920, qwen38 16384). Rationale: the GPU router already runs one model at a
  time (`--models-max 1`), so 4 slots per model bought little; full context matters more.
  Tradeoff: concurrent requests to the same model now serialize.
- **gemma-26b**: `ctx-size` back to **81920** and `load-mode = none` removed (mmap). Weights
  stay GPU-resident (~14.9 GiB VRAM); the KV cache for long contexts spills to CPU (the
  "tensor overrides to CPU" warning is expected in this mode) — its original large-context
  role. Note KV is f16 V (flash-attn off, 2026-09-02 stability change), so long contexts are
  CPU-traffic-heavy; dial ctx down if too slow.

The CPU router (:2002, gpt-oss-120b) is unchanged (`parallel 4`, 16384/slot, background batches).
