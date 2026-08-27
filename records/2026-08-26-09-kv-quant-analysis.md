# Record: KV-cache quantization analysis — 2026-08-26

Task 03 analysis. Computed from the actual GGUF metadata on beast (`scripts/kv-cache-size.py`), verified 2026-08-26.

## Key facts

- KV-cache quantization is a **runtime** setting (`cache-type-k` / `cache-type-v`); it quantizes the per-token key/value cache, NOT the model weights. **No model downloads or variant changes are needed** — every existing GGUF works with any KV cache type.
- KV bytes per token (K+V) at f16 / q8_0 / q4_0, and total at each preset's context:

| Model (beast alias) | arch | layers×kv×hdim | KV/tok f16 | preset ctx | KV f16 | KV q8_0 | KV q4_0 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| coder32 | qwen2 | 64×8×128 | 0.250 MB | 16384 | 4.0 GB | 2.0 GB | 1.0 GB |
| coder14 | qwen2 | 48×8×128 | 0.188 MB | 16384 | 3.0 GB | 1.5 GB | 0.8 GB |
| qwen9 | qwen35 | 32×4×256 | 0.125 MB | 32768 | 4.0 GB | 2.0 GB | 1.0 GB |
| gpt-oss-20b | gpt-oss | 24×8×45 | 0.033 MB | 32768 | 1.0 GB | 0.5 GB | 0.3 GB |
| gemma-12b | gemma4 | 48×8×240 | 0.352 MB | 32768 | 11.3 GB | 5.6 GB | 2.8 GB |
| devstral | mistral3 | 40×8×160 | 0.195 MB | 32768 | 6.2 GB | 3.1 GB | 1.6 GB |
| gemma-26b | gemma4 | 30×8×176 | 0.161 MB | 81920 | 12.9 GB | 6.4 GB | 3.2 GB |
| gpt-oss-120b | gpt-oss | 36×8×45 | 0.049 MB | 65536 | 3.1 GB | 1.6 GB | 0.8 GB |
| r1-70b | llama | 80×8×128 | 0.312 MB | 32768 | 10.0 GB | 5.0 GB | 2.5 GB |
| llama70 | llama | 80×8×128 | 0.312 MB | 32768 | 10.0 GB | 5.0 GB | 2.5 GB |

(r1-14b ≈ coder14/coder32 class, qwen2, 0.19 MB/tok.)

## Gains

- **Memory**: halves KV everywhere at q8_0 (near-lossless). The elephants: gemma-26b at its 81920 context (12.9 GB → 6.4 GB, and that is on top of ~17 GB of weights against a 16 GB MI25 — this is the single biggest lever), gemma-12b at 32768 (11.3 → 5.6 GB), the 70B CPU models (10 → 5 GB of RAM, less critical with 256 GB but halves bandwidth).
- **Speed**: smaller KV = less memory bandwidth per generated token; on the MI25 (no int-dot, fp16 compute) and on the CPU 70B/120B models this shows up as faster generation, especially at long contexts.
- **Quality**: q8_0 KV is near-lossless in practice. q4_0 on V (values) is the aggressive option (small measurable quality cost on long-context reasoning); q4_0 on K is worse. Safe default: K q8_0 + V q8_0; per-preset V q4_0 only where memory is tight (gemma-26b / gemma-12b).

## Recommendation (pending owner decision)

- Add to `[*]` on both routers: `cache-type-k = q8_0` and `cache-type-v = q8_0`.
- Optional per-preset override for gemma-26b and gemma-12b: `cache-type-v = q4_0`.
- No downloads; same GGUFs.
