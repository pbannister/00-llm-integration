# Model Retention Analysis — verified 2026-08-26

Purpose: note which downloaded models are likely not useful, so the owner can decide.
Nothing is discarded without the owner's decision.
The first model set was downloaded by interest, then benchmarked (see `sources/models/_combine-amd-rx-5500.md` and `sources/models/logs/`).
GGUF files live in the HuggingFace cache on each host (`HF_HUB_CACHE=/home/preston/.cache/huggingface/hub` on beast; default cache on athena).

## Discard executed 2026-08-26

The owner approved the discard on 2026-08-26; the files below marked "Discard candidates" were deleted from the HuggingFace cache on beast and athena by `scripts/cache-discard.sh`.
Backups exist at `/backups/huggingface/` on both hosts and are not managed by this project; a re-download is also possible if a model is needed later.
Beast freed ~163 GB (28 → 13 models); athena freed ~306 GB (32 → 15 models). Services were restarted to rescan the caches.
One incident during execution: the blob-cleanup step of the first script run deleted keeper quants (`gpt-oss-120b`/`gpt-oss-20b` UD-Q4_K_XL on beast) because `stat -c %i` did not dereference symlinks; the keepers were restored over LAN from athena before athena's own discard ran. See `records/2026-08-26-03-cache-discard.md`.

Classes: keep (preset, has a role), keep-with-tuning (cache entry that should become a preset or serve a role), discard-candidate (redundant or roleless — deleted 2026-08-26).

## Beast (28 models)

### Keep (presets, have roles)

| Model id | ctx | class | role |
| ---- | ---- | ---- | ---- |
| `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` | 16384 | GPU | editing, agent |
| `unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_M` | 32768 | GPU | dev workflows |
| `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_XL` | 32768 | GPU | reasoning Q&A |
| `unsloth/gemma-4-26B-A4B-it-qat-GGUF:Q4_K_XL` | 81920 | GPU | large context |
| `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` | 65536 | CPU | planning, background |
| `unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:Q4_K_XL` | 32768 | CPU | deep reasoning |
| `unsloth/Llama-3.3-70B-Instruct-GGUF:Q4_K_XL` | 32768 | CPU | general 70B |

### Keep-with-tuning (cache → promote to presets; all fit the MI25 GPU)

| Model id | size | note |
| ---- | ---- | ---- |
| `bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M` | ~9 GB | 14B coder; strong candidate for a GPU preset between 3B and 32B |
| `unsloth/Qwen3.5-9B-GGUF:Q4_K_M` | ~5.5 GB | general 9B; fits GPU |
| `unsloth/gpt-oss-20b-GGUF:Q4_K_XL` | ~13 GB | llama.vscode's recommended agent model; fits GPU |
| `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL` | ~8 GB | fits GPU |
| `unsloth/gemma-4-E2B-it-qat-GGUF:Q4_K_XL` | 2.43 GB | keep for minerva (travel) decision |
| `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL` | 3.91 GB | keep for minerva (travel) decision |

### Discard candidates (redundant or roleless on beast) — deleted 2026-08-26

| Model id | reason |
| ---- | ---- |
| `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q4_K_M` | athena serves the Q8 preset; beast copy redundant |
| `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` | same; third 1.5B coder copy |
| `ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF:Q8_0` | same; third 1.5B coder copy |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q4_K_M` | athena serves the Q8 preset; beast copy redundant |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` | same |
| `unsloth/Llama-3.2-1B-Instruct-GGUF:Q8_0` | no role |
| `unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0` | athena serves the preset; beast copy redundant |
| `bartowski/Mistral-Nemo-Instruct-2407-GGUF:Q4_K_M` | no role; Qwen coders dominate for code |
| `bartowski/Qwen3.8-27B-GGUF:Q4_K_M` | 27B family: three near-duplicates, none fits the GPU, CPU-only and slow |
| `unsloth/Qwen3.5-27B-GGUF:Q4_K_M` | 27B family (keep at most one) |
| `unsloth/Qwen3.5-27B-GGUF:Q4_K_S` | 27B family (keep at most one) |
| `unsloth/gpt-oss-120b-GGUF:Q4_K_M` | the `Q4_K_XL` preset is the keeper; duplicate quant |
| `unsloth/gpt-oss-20b-GGUF:Q4_K_M` | the `Q4_K_XL` is the keeper (promote it); duplicate quant |
| `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_M` | the `Q4_K_XL` preset is the keeper; duplicate quant |
| `unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_M` | athena serves it as CPU fallback preset; beast copy redundant |

## Athena (32 models)

### Keep (presets)

`Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0`, `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0`, `unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0`, `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL` (GPU), `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M`, `unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:Q4_K_XL` (CPU fallback when beast is offline).

### Keep-with-tuning

| Model id | note |
| ---- | ---- |
| `ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0` | embeddings for RAG; needs an embeddings preset (`/v1/embeddings`) |
| `josephmayo/gemma-4-E4B-it-Coder-GGUF:Q5_K_M` | coding-tuned small model; candidate for athena completion |
| `unsloth/Qwen3.5-2B-GGUF:Q4_K_M`, `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` | keep for minerva (travel) decision |

### Discard candidates (redundant or roleless on athena) — deleted 2026-08-26

The 70B/120B/27B and big GPU cache entries on athena run at ~1 t/s on the 5900X and duplicate beast presets:

- `unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:Q4_K_XL`, `unsloth/Llama-3.3-70B-Instruct-GGUF:Q4_K_XL`, `unsloth/gpt-oss-120b-GGUF:Q4_K_M`/`Q4_K_XL` — beast is their home.
- `unsloth/gpt-oss-20b-GGUF:Q4_K_M`/`Q4_K_XL`, `unsloth/Qwen3.5-27B-GGUF:Q4_K_M`/`Q4_K_S`, `bartowski/Qwen3.8-27B-GGUF:Q4_K_M`, `unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_M`, `unsloth/gemma-4-26B-A4B-it-qat-GGUF:Q4_K_XL`, `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`, `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_M` — beast presets are authoritative; athena copies run CPU-only.
- `bartowski/Mistral-Nemo-Instruct-2407-GGUF:Q4_K_M` — no role.
- `unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF:Q4_K_XL`, `unsloth/Llama-3.2-1B-Instruct-GGUF:Q4_K_M`/`Q8_0` — no role.
- `unsloth/Llama-3.2-3B-Instruct-GGUF:Q4_K_M` — the Q8 preset is the keeper.

## Remaining cleanup candidates (not in the approved list)

- on athena: `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q4_K_M` and `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q4_K_M` cache quants remain in repos whose Q8 presets are kept; and the unused `ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF` repo remains on disk. Owner to decide; no deletion performed.

## Benchmark reference

From `sources/models/_combine-amd-rx-5500.md` (athena, 2026-07-28), generation t/s (tg128):

| Model | t/s |
| ---- | ---- |
| Qwen-2.5-Coder-1.5B Q8 (GPU) | 98.0 |
| Qwen-2.5-Coder-3B Q8 (GPU) | 53.7 |
| Gemma-4-E4B QAT (GPU) | 45.7 |
| Llama-3.2-3B Q8 (GPU) | 29.8 |
| GPT-OSS-120B (CPU) | 8.42 |
| Gemma-4-E2B QAT (CPU) | 21.7 |
| Llama-3.3-70B (CPU) | 0.91 |
| DeepSeek-R1-Distill-70B (CPU) | 0.91 |

Notes: the 120B at 8.42 t/s on CPU versus 0.91 t/s for the 70B models is the signature of MTP speculative decoding (the gpt-oss architecture has a native MTP head); verify with `--spec-type none` versus `draft-mtp` in task 01. See `documents/13-mtp-and-rag.md`.
