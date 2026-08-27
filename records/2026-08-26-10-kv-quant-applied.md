# Record: KV-cache quantization applied — 2026-08-26

## Outcome

Applied task 03 on both routers (baselines: `/usr/local/etc/config.ini.bak-20260826-kvquant` on each host):

- `[*]` on beast and athena: `cache-type-k = q8_0`, `cache-type-v = q8_0`.
- Beast per-preset override: `cache-type-v = q4_0` for `gemma-26b` and `gemma-12b`.

Verified in child args 2026-08-26: `coder32` k=q8_0 v=q8_0; `gemma-26b`/`gemma-12b` k=q8_0 v=q4_0; athena `coder3` k=q8_0 v=q8_0; 15 models up on athena.

## MI25 (16 GiB) memory and context analysis (weights measured from GGUFs, verified 2026-08-26)

| Model | weights | KV/tok (applied) | KV @ preset ctx | total | fits 16 GiB? | full-GPU ctx limit |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| coder32 | 18.49 G | 0.125 M | 2.00 G @ 16384 | 20.49 G | spill 4.5 G | never (weights > 16 G) |
| coder14 | 8.37 G | 0.094 M | 1.50 G @ 16384 | 9.87 G | yes | ~83k |
| qwen9 | 5.29 G | 0.062 M | 2.00 G @ 32768 | 7.29 G | yes | ~175k |
| gpt-oss-20b | 11.06 G | 0.017 M | 0.53 G @ 32768 | 11.58 G | yes | ~307k |
| gemma-12b | 6.26 G | 0.264 M | 8.45 G @ 32768 | 14.70 G | yes | ~38k |
| devstral | 13.35 G | 0.098 M | 3.12 G @ 32768 | 16.47 G | spill 0.5 G | ~28k |
| gemma-26b | 13.27 G | 0.121 M | 9.66 G @ 81920 | 22.93 G | spill 6.9 G | ~23k |

- "Full-GPU ctx limit" = the context at which weights + KV reach 16 GiB; beyond it the excess runs from the dual-Xeon system RAM (256 G), via `fit = on` keeping layers/KV where they fit. Generation slows at that point (KV reads cross the PCIe/RAM boundary).
- Before/after at preset ctx: gemma-26b KV 12.9 → 9.66 G; gemma-12b 11.3 → 8.45 G (this one crossed from spill to full-GPU fit); coder32 4.0 → 2.0 G; devstral 6.4 → 3.12 G.
- CPU models (RAM): gpt-oss-120b 58.69 G weights + 1.6 G KV = 60.3 G of 256 G; the 70Bs 39.73 G + 5.1 G — q8 KV halves their per-token KV bandwidth.

## Notes

- coder32's 18.49 G weights exceed the MI25 even with zero context: ~2.5 G of layers always run on CPU. It remains the quality option; coder14/gpt-oss-20b are the full-GPU fast paths.
- gemma-26b at its full 81920 context is CPU-resident beyond ~23k tokens by design; q4 V cut ~3.2 G of that traffic.
