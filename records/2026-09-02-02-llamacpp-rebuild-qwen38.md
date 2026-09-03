# Record: llama.cpp rebuild on beast (build 10790) + Qwen3.8-Flash-Next (qwen38) CPU preset — 2026-09-02

## llama.cpp rebuild (beast)

- Rebuilt and installed 2026-09-02 21:37–21:40: build **10790**, commit `7cbe657e3` (previous: 10726 / `63f45bd2c`). Full library set replaced (`/usr/local/lib/libllama.so.0.3.0`, `libllama-server-impl.so`, `libggml-*.so.0.22.0`, …) plus `/usr/local/bin/llama-server`.
- `llama.service` restarted 21:44 (MainPID 745958) to load the new build; healthy, 14 models registered, 0 kernel resets.
- **qwen4exp** (Qwen3.8-Flash-Next) support present: `strings /usr/local/lib/libllama.so.0.3.0 | grep -c qwen4exp` → 93. (Earlier "no support" readings in `records/2026-09-02-01` / chat were from the 17 KB launcher binary and `libggml-base` only — the arch table lives in `libllama.so`, which was not grepped.)
- llama.cpp mainline context: PR [ggml-org/llama.cpp #27742](https://github.com/ggml-org/llama.cpp/pull/27742) "model: add Qwen3.8-Flash-Next (qwen4exp)" merged 2026-08-27; follow-up fix [PR #27774](https://github.com/ggml-org/llama.cpp/pull/27774) ("rotated-KV QSA fix") still open — **not** in this build.
- Athena untouched (still build 10712 / commit `f7807f27d`, installed 2026-08-30) — revisit if athena should also gain qwen4exp.

## Qwen3.8-Flash-Next CPU preset (`qwen38`) added to beast

Added to `/usr/local/etc/config.ini` (baseline: `config.ini.bak-20260902-qwen38`):

```ini
[batiai/Qwen3.8-Flash-Next-GGUF:Q4_K_M]
alias = qwen38
ngl = 0
numa = distribute
ctx-size = 32768
temp = 0.6
top-p = 0.95
jinja = true
```

- **Repo/quant choice**: `batiai/Qwen3.8-Flash-Next-GGUF:Q4_K_M` (root-level, 119.2 GB over 3 splits) over `unsloth/Qwen3.8-Flash-Next-GGUF` UD-quants because unsloth keeps its files in per-quant subdirectories and llama.cpp's `--hf-repo` resolution is unverified for subdir layouts; the batiai root layout mirrors every existing working preset.
- **Model facts**: MoE ~6B active; total reported 125–176B across sources; native 256K ctx; multimodal (`mmproj` files published); day-0 GGUFs from unsloth/batiai/AtomicChat/argyelan; MTP draft-head GGUFs exist for speculative decoding.
- Registered in `/v1/models` (status unloaded; beast now lists 14 models). **Not yet downloaded/loaded**: the first `qwen38` request will download ~119 GB (239 GB free on `/home`), then load on CPU — that load is the final end-to-end qwen4exp proof, still pending.
- RAM note: ~119 GB resident when loaded — avoid co-loading with gpt-oss-120b (~59 GB) on the 256 GB box; the router keeps loaded workers resident.

## Notes

- Service restarts are required after a llama.cpp install or config edit: the router snapshots both the binary and `config.ini` at `llama.service` start.
- If unsloth's subdir layout is ever needed, confirm llama.cpp resolution first (cheap failure = no file matched; expensive success = starts the multi-GB download).
