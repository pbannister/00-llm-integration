# Routing Policy — verified 2026-09-25

The policy for assigning work to the local models.
It exists because the two execution classes compete for nothing: a CPU-heavy model on beast runs in system RAM while the MI25 serves a GPU model concurrently.
Since 2026-09-03 these are **separate routers**: `llama.service` (GPU presets, port 2001, `--models-max 1`) and `llama-cpu.service` (`gpt-oss-120b`, port 2002) — see `records/2026-09-03-04`.

## Classes

| Class | Host | Hardware | Latency | Use for |
| ---- | ---- | ---- | ---- | ---- |
| GPU-resident | beast MI25 (`llama.service` :2001) | 16 GB VRAM | fast (interactive) | chat, agent loops, editing on the MI25 |
| CPU-heavy | beast dual Xeon (`llama-cpu.service` :2002) | system RAM | slow | planning, long-running agent and tool batches |
| Local GPU (small) | athena RX 5500 XT (:2001) | 8 GB VRAM | fastest | inline completion, small chat |
| CPU fallback | athena 128 GB | system RAM | slow | when beast is offline |

## Assignment Rules

- Small, light, latency-sensitive work stays on the local athena GPU: `coder3` and `coder15` for completion, `llama3` and `gemma-e4` for small chat.
- Interactive and agent work on beast uses the MI25: `coder14` for chat and `gpt-oss-20b` for agent and tool calls; `qwen9`, `gemma-12b` and `gemma-26b` cover general and large-context chat.
- Only models that emit parsed `tool_calls` belong in an agent loop. Verified 2026-09-25: `gpt-oss-20b`, `gpt-oss-120b`, `gemma-e4` and `llama3` do; `coder14` does not (it returns a `<tools>` text block).
- Large or long-running background tasks go to `gpt-oss-120b` on beast's CPU. Response time is not a concern for these, and the MI25 stays free for interactive users.
- Reasoning presets were removed from beast 2026-09-03; athena's `r1-32b-fallback` remains for beast-offline reasoning.
- Athena's CPU fallbacks (`coder32-fallback`, `r1-32b-fallback`) serve only when beast is unreachable; the desktop GPU (8 GB) cannot hold the larger models.
- `qwen38` remains listed on the beast GPU router but is not policy-approved: at 111 GiB it cannot fit, and every measured offload configuration was worse than CPU-only (see `records/2026-09-21-01-mi25-inference-benchmarks.md`).
- Do not run the 120B and interactive GPU work on the same session's critical path; schedule background batches so they do not starve interactive latency on the shared memory bus.

## Tool Tiering

The three llama.vscode tiers are the visible form of this policy, and DSH and aider follow the same shape.

| Tier | Endpoint | Model | Work |
| ---- | ---- | ---- | ---- |
| Local GPU | `http://athena.lan:2001` | `coder3` | inline completion and other small, light tasks |
| MI25 | `http://beast.lan:2001` | `coder14` (chat), `gpt-oss-20b` (agent) | more complex interactive work |
| CPU | `http://beast.lan:2002` | `gpt-oss-120b` | long-running and heavier agent or batch work |

## Concurrency Notes

- Router mode runs one child server per active model, so a CPU model and a GPU model run concurrently by default.
- The beast GPU router runs `parallel = 1`: one conversation gets the full context, and `--models-max 1` means two different GPU models evict each other. Keep the GPU tier to one model per working session.
- The CPU router also runs `parallel = 1`, with a 65536 context, so a single long conversation is not divided.
- The athena router runs `parallel = 4`: its 8192 default context becomes 2048 tokens per request. It is sized for FIM, not chat.
- The 120B on CPU still contends with GPU models for memory bandwidth; the policy above keeps their workloads disjoint in time where it matters.

## Router split and VRAM guard (2026-09-03)

- GPU router `llama.service` on :2001 runs `--models-max 1`: exactly one GPU-resident model at a time; requesting another evicts the current one (verified: qwen38 evicted when gemma-26b loaded).
- CPU router `llama-cpu.service` on :2002 (gpt-oss-120b) coexists freely.
- Isolation is enforced by scoped HF caches per router (`~/.cache/hf-gpu`, `~/.cache/hf-cpu`, symlinked model dirs) because llama.cpp has no VRAM-aware scheduler and the `--models-preset-only` flag is not merged upstream (ggml-org/llama.cpp PR #24434).

## DSH Defaults

Keep the DeepSeek cloud provider (`deepseek-official`) as the DSH default for the hardest agent runs; use the `beast` provider for private, cheap, and large-context work, and for background goal batches on the 120B.
