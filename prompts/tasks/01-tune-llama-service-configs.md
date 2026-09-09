
## TASK-DESCRIPTION
Sort the llama.cpp service configuration on beast and athena before any client-side (DSH) work.

The owner's ordering decision: llama service config first, then the DSH settings. This task produces the tuning recommendations; it does not apply them to the live hosts.

Inspect the live presets on both hosts (`/usr/local/etc/config.ini` on beast and athena) and the captured router model lists in `dataflow.in/endpoints/`.

Create `documents/12-model-retention.md` with a model-by-model retention analysis:

- Mark each router model as keep, keep-with-tuning, or discard-candidate.
- Discard candidates must be flagged but never deleted (the owner decides); record the exact GGUF location in the HuggingFace cache (`HF_HUB_CACHE`).
- Base the analysis on execution role and the benchmark numbers in `sources/models/_combine-amd-rx-5500.md` (imported reference) and `sources/models/logs/`.
- Cover: triple 1.5B coder entries on beast, 3B coder on beast, Llama-3.2-1B, Mistral-Nemo-12B, the 27B family (Qwen3.5 Q4_K_M/Q4_K_S, Qwen3.8), duplicate quants of the same model, and the 70B/120B cache entries on athena.

Create `prompts/tasks/01-tune-llama-service-configs.md` (this file) as the executable task and record in it, as concrete tuning recommendations:

- Add `alias = <name>` lines to each preset section so clients can use short ids (`coder32`, `devstral`, `r1-14b`, `gemma-26b`, `gpt-oss-120b`, `r1-70b`, `llama70`; athena equivalents).
- Add `parallel = 4` under `[*]` on both hosts so agent clients (DSH subagents) do not serialize.
- Promote useful cache models to presets where they fit the host GPU: on beast, `Qwen/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M`, `unsloth/Qwen3.5-9B-GGUF:Q4_K_M`, `unsloth/gpt-oss-20b-GGUF:Q4_K_XL`, `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL`; decide the fate of the 27B family.
- Configure an embeddings preset on athena for `ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0` (verify the preset key with `llama-server --help | grep -i embed`) so `/v1/embeddings` works for RAG.
- MTP: benchmark `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` on beast with `--spec-type none` versus `--spec-type draft-mtp` (llama-bench), and enable MTP in its preset when it helps. Record the result.
- Do not change the live hosts; the human reviews and applies.

## TASK-OUTPUT
Provide a summary: files created, per-host tuning recommendation counts, and the MTP benchmark outcome if run.
No commentary beyond the summary.

## TASK-CONTEXT
The owner downloaded the first model set by interest, then benchmarked; some of that set is likely not useful. Nothing is discarded without the owner's decision.
Beast runs build 10628 (dev) with `--spec-type` supporting `draft-mtp`; athena runs build 10129.
The owner's benchmark shows `gpt-oss-120b` at 8.42 t/s generation on CPU versus 0.91 t/s for the 70B models — consistent with MTP speculation already active; verify explicitly.
Feature requirements: `prompts/features/01-endpoints-and-models.md`.

## TASK-FILES
- `documents/12-model-retention.md` — new.
- `prompts/tasks/01-tune-llama-service-configs.md` — new (this file, being the executable task).
- `dataflow.in/endpoints/beast-models.json` and `athena-models.json` — existing; inspect.
- `sources/models/_combine-amd-rx-5500.md` and `sources/models/logs/` — existing; inspect.
