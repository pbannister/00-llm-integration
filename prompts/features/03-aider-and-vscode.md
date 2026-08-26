# Feature: Aider and VS Code

Defines local-model usage for aider and the VS Code surfaces (llama.vscode, VS Code Chat).

## Aider

Aider is the CLI pair-programmer used across the workspace projects. Every project shares the same rule-injection pattern: `.aider.conf.yml` reads the project's `prompts/01-contract.md`, `02-workflow.md`, `03-conventions.md`, the `common/` files, the semantic-sort flavor, and `tools/aider-rules.md`. Historical sessions used cloud models via OpenRouter (`openrouter/openrouter/auto`) through the LiteLLM proxy; the local-model path is the goal of this feature.

Local-model invocation against the beast router:

```sh
aider --openai-api-base http://beast.lan:2001/v1 --openai-api-key sk-local \
      --model <router model id or alias> --edit-format whole
```

Rules:

- Use `--edit-format whole`; `diff` formats are unreliable on local models.
- Editing sessions use the GPU-resident coder (`Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M`).
- Architect mode splits planning from editing: `--model <gpt-oss-120b id> --editor-model <coder id> --architect`. The 120B runs on CPU and is slow; reserve it for design work, not routine edits.
- Avoid R1-distill models in the agent loop; they follow tool schemas poorly.
- `aider` holds the whole conversation in context; keep sessions short because context is the scarce resource on the GPU models.
- Use the router model id, or an alias once configured on the router (`alias = coder32` in the preset). See `prompts/features/01-endpoints-and-models.md`.

## llama.vscode

The official llama.cpp VS Code extension (`ggml-org.llama-vscode`) provides inline completion, chat, an agent, embeddings, and tool selection. It can use a remote llama.cpp server. Best use against the local routers:

- Completion model: a FIM-capable small coder (`Qwen/Qwen2.5-Coder-1.5B/3B` on athena, or the 32B coder on beast).
- Chat model: the GPU-resident coder or Devstral on beast.
- Agent: `gpt-oss-20b` or `gpt-oss-120b` (both in the router catalogs).
- Embeddings: `ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0` (athena).

## VS Code Chat View

The Chat view is tied to GitHub Copilot. Options for local or OpenAI-compatible providers, in order of preference for this setup:

1. GitHub Copilot BYOK (bring your own key): Copilot Chat accepts an OpenAI-compatible base URL and key; point it at `http://beast.lan:2001/v1`. Requires a Copilot plan.
2. Third-party gateway extensions that route Copilot Chat to self-hosted models (for example `github-copilot-llm-gateway`, `AgenticProxy` on the marketplace).
3. Skip the Chat view entirely: llama.vscode chat and Cline/Roo Code already cover chat and agentic editing without Copilot.

Avoid running overlapping agent UIs on the same project simultaneously; pick one surface per task.

## Requirement: usage notes stay verified

- Tool behavior changes; documents describing extensions or flags carry a `verified <date>` marker and cite the version checked.
- Do not duplicate the router catalog here; reference `01-endpoints-and-models.md`.
