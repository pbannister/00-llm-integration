# Feature: Aider and VS Code

Defines local-model usage for aider and the VS Code surfaces (llama.vscode, VS Code Chat).

## Aider

Aider is the CLI pair-programmer used across the workspace projects.
Every project shares the same rule-injection pattern: `.aider.conf.yml` reads the project's `prompts/01-contract.md`, `02-workflow.md`, `03-conventions.md`, the `common/` files, the semantic-sort flavor, and `tools/aider-rules.md`.
Historical sessions used cloud models via OpenRouter (`openrouter/openrouter/auto`) through the LiteLLM proxy; the local-model path replaces that for private and free work.

Local-model invocation against the beast routers:

```sh
# routine edits — GPU-resident coder on the MI25
aider --openai-api-base http://beast.lan:2001/v1 --openai-api-key sk-local \
      --model coder14 --edit-format whole

# long planning or batch run — 120B on the CPU router
aider --openai-api-base http://beast.lan:2002/v1 --openai-api-key sk-local \
      --model gpt-oss-120b --edit-format whole
```

Rules:

- Use `--edit-format whole`; `diff` formats are unreliable on local models.
- Editing sessions use the GPU-resident coder (`coder14`).
- The 120B runs on the CPU router and is slow; reserve it for design work and long batch runs, not routine edits.
- Architect mode pairs a planner with an editor, but aider applies one `--openai-api-base` per run, so both models must live on the same router.
- Avoid R1-distill models in the agent loop; they follow tool schemas poorly.
- `aider` holds the whole conversation in context; keep sessions short because context is the scarce resource on the GPU models.
- Use the router alias (`coder14`, `gpt-oss-120b`) or the reported model id, never the `UD-` preset-key form; see `01-endpoints-and-models.md`.

## llama.vscode

The official llama.cpp VS Code extension (`ggml-org.llama-vscode`) provides inline completion, chat, an agent, embeddings, and tool selection, and can use a remote llama.cpp server.
It does not need to start `llama-server` itself: `localStartCommand` is optional, so the routers serve it directly.

The tiered mapping:

| Tier | Purpose | Endpoint | Model |
| ---- | ---- | ---- | ---- |
| Local GPU | inline completion (FIM), small and light tasks | `http://athena.lan:2001` | `coder3` (or `coder15` for lowest latency) |
| MI25 | more complex chat and agent work | `http://beast.lan:2001` | `coder14` for chat, `gpt-oss-20b` for the agent |
| CPU | longer-running and heavier work | `http://beast.lan:2002` | `gpt-oss-120b` |
| Embeddings | RAG and the `search_source` tool | `http://athena.lan:2001` | `nomic-embed` |

Requirements:

- The canonical settings fragment is `sources/config/llama-vscode-settings.json`; apply it with `scripts/llama-vscode-config-apply.sh`.
- `tests/03-llama-vscode-settings-validate.sh` guards every referenced model id against the captures.
- Do not include `/v1` in an `endpoint` value; the extension appends `/infill` and `/v1/chat/completions` itself.
- Completion must use a FIM-capable model; the Qwen2.5-Coder family is the right one in this catalog.
- Do not offer `coder14` as a tools model; it does not emit parsed `tool_calls`.
- Keep the MI25 tier to one model per working session; the GPU router runs `--models-max 1` and two different models evict each other.

## VS Code Chat View

The Chat view is tied to GitHub Copilot.
Options for local or OpenAI-compatible providers, in order of preference for this setup:

1. GitHub Copilot BYOK (bring your own key): Copilot Chat accepts an OpenAI-compatible base URL and key; point it at `http://beast.lan:2001/v1`. Requires a Copilot plan.
2. Third-party gateway extensions that route Copilot Chat to self-hosted models (for example `github-copilot-llm-gateway`, `AgenticProxy` on the marketplace).
3. Skip the Chat view entirely: llama.vscode chat and Cline/Roo Code already cover chat and agentic editing without Copilot.

Avoid running overlapping agent UIs on the same project simultaneously; pick one surface per task.

## Requirement: usage notes stay verified

- Tool behavior changes; documents describing extensions or flags carry a `verified <date>` marker and cite the version checked.
- Do not duplicate the router catalog here; reference `01-endpoints-and-models.md`.
