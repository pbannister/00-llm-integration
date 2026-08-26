# Record: llama.cpp version review — 2026-08-26

The owner rebuilt llama.cpp from the latest GitHub source and restarted both routers.
Before: beast 0.2.0-dev (10628), athena 10129. After: **beast 0.3.0-dev (10657, a58d57cea)**, **athena 0.3.0-dev (10643, d6cf9b091)** — the athena version gap is closed.

## Verified unchanged

- The tuned presets work as-is on the new builds: `/v1/models` still lists 13 (beast) / 15 (athena) models with the aliases and `--parallel 4` (checked on beast).
- `--spec-type` option list unchanged (draft-simple/eagle3/mtp/dflash/dspark/ngram-*); gpt-oss native MTP still auto-enables. `--draft-max` was renamed `--spec-draft-n-max` (no config impact).
- KV cache quantization (`-ctk`/`-ctv`) and `--fit` unchanged.

## New in this build — changed recommendations

1. **`--cache-reuse N` is now available** (KV shifting reuse across requests; "requires prompt caching", default 0). This is the headline change: it lets repeated request prefixes (DSH's system prompt, aider's injected rules) reuse cached KV instead of reprocessing. The 120B's prompt processing measured 2.4 t/s; cache-reuse directly attacks that. **Recommendation: add `cache-reuse = 256` under `[*]` on both hosts** (not yet applied — pending owner approval).
2. **`--parallel` default is now auto (-1)** instead of 1. The explicit `parallel = 4` in the tuned configs still overrides it; no change needed.
3. **`--n-cpu-moe N`** (keep first N MoE layers' weights in CPU) is new — relevant only to the MoE model `gemma-4-26B-A4B` on the 16 GB MI25, as an alternative to naive layer spill. Optional experiment; not recommended as a default.

## Standing recommendations (unchanged)

- KV cache quant (`cache-type-k/v = q8_0`) — the memory lever for gemma-26b at 81920 ctx; speed/quality tradeoff for the owner.
- EAGLE-3 drafter trial for gemma-26b; ngram for the CPU 70Bs (both optional).
- Avoid IQ quants on the MI25 (Vulkan `int dot: 0`).

## Verification

- Alias routing verified on the new build: `coder32` chat completion answered correctly (2026-08-26).
- Captures refreshed; `make test` passes.
