# Routing Policy — verified 2026-08-26

The policy for assigning work to the local models. It exists because the two execution classes compete for nothing: a CPU-heavy model on beast runs in system RAM while the MI25 serves a GPU model concurrently. Since 2026-09-03 these are **separate routers**: `llama.service` (GPU presets, port 2001, `--models-max 1`) and `llama-cpu.service` (gpt-oss-120b, port 2002) - see `records/2026-09-03-04`.

## Classes

| Class | Host | Hardware | Latency | Use for |
| ---- | ---- | ---- | ---- | ---- |
| GPU-resident (fit-trimmed) | beast MI25 (`llama.service` :2001) / athena RX 5500 XT | 16 GB / 8 GB VRAM | fast (interactive) | editing, agent loops, chat, completion |
| CPU-heavy (`ngl 0`) | beast dual Xeon (`llama-cpu.service` :2002) | system RAM | slow | planning, large repeated background tasks |
| CPU fallback | athena (128 GB) | system RAM | slow | when beast is offline |

## Assignment Rules

- Interactive and agent work uses GPU-resident models: `coder14` and `gpt-oss-20b` on beast for editing/agent/tool calls; small coders on athena for completion. (`coder32`/`devstral` removed from beast 2026-09-03 - their weights do not fit the 16 GiB MI25.)
- Large repeated background tasks go to `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` on beast's CPU. Response time is not a concern for these; the MI25 stays free for interactive users.
- Reasoning presets were removed from beast 2026-09-03; athena's `r1-32b-fallback` remains for beast-offline reasoning.
- Athena's CPU fallbacks (32B coder, R1-distill-32B) serve only when beast is unreachable; the desktop GPU (8 GB) cannot hold the larger models.
- Do not run the 120B and interactive GPU work on the same session's critical path; schedule background batches so they do not starve interactive latency on the shared memory bus.

## Concurrency Notes

- Router mode runs one child server per active model, so a CPU model and a GPU model run concurrently by default.
- Each child serves one request at a time unless `parallel` is set in its preset; add `parallel = 4` to the `[*]` section when DSH or other agents issue parallel subagent requests.
- The 120B on CPU will still contend with GPU models for memory bandwidth; the policy above keeps their workloads disjoint in time where it matters.

## Router split and VRAM guard (2026-09-03)

- GPU router `llama.service` on :2001 runs `--models-max 1`: exactly one GPU-resident model at a time; requesting another evicts the current one (verified: qwen38 evicted when gemma-26b loaded).
- CPU router `llama-cpu.service` on :2002 (gpt-oss-120b) coexists freely.
- Isolation is enforced by scoped HF caches per router (`~/.cache/hf-gpu`, `~/.cache/hf-cpu`, symlinked model dirs) because llama.cpp has no VRAM-aware scheduler and the `--models-preset-only` flag is not merged upstream (ggml-org/llama.cpp PR #24434).

## DSH Defaults

Keep the DeepSeek cloud provider (`deepseek-official`) as the DSH default for the hardest agent runs; use the `beast` provider for private, cheap, and large-context work, and for background goal batches on the 120B.
