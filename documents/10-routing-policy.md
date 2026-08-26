# Routing Policy — verified 2026-08-26

The policy for assigning work to the local models. It exists because the two execution classes compete for nothing: a CPU-heavy model on beast runs in 256 GB of Xeon RAM while the MI25 serves a GPU model concurrently, as separate child servers in router mode.

## Classes

| Class | Host | Hardware | Latency | Use for |
| ---- | ---- | ---- | ---- | ---- |
| GPU-resident (`ngl 99`) | beast MI25 / athena RX 5500 XT | 16 GB / 8 GB VRAM | fast (interactive) | editing, agent loops, chat, completion |
| CPU-heavy (`ngl 0`) | beast dual Xeon (256 GB, `numa = distribute`) | system RAM | slow (many s/token for 120B) | planning, large repeated background tasks, deep reasoning |
| CPU fallback | athena (128 GB) | system RAM | slow | when beast is offline |

## Assignment Rules

- Interactive and agent work uses GPU-resident models: the 32B coder on beast for editing and tool calls; Devstral for dev workflows; small coders on athena for completion.
- Large repeated background tasks go to `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` on beast's CPU. Response time is not a concern for these; the MI25 stays free for interactive users.
- Reasoning Q&A (not tool-driven) can use the R1-distill models; keep them out of agent loops.
- Athena's CPU fallbacks (32B coder, R1-distill-32B) serve only when beast is unreachable; the desktop GPU (8 GB) cannot hold the larger models.
- Do not run the 120B and interactive GPU work on the same session's critical path; schedule background batches so they do not starve interactive latency on the shared memory bus.

## Concurrency Notes

- Router mode runs one child server per active model, so a CPU model and a GPU model run concurrently by default.
- Each child serves one request at a time unless `parallel` is set in its preset; add `parallel = 4` to the `[*]` section when DSH or other agents issue parallel subagent requests.
- The 120B on CPU will still contend with GPU models for memory bandwidth; the policy above keeps their workloads disjoint in time where it matters.

## DSH Defaults

Keep the DeepSeek cloud provider (`deepseek-official`) as the DSH default for the hardest agent runs; use the `beast` provider for private, cheap, and large-context work, and for background goal batches on the 120B.
