# Tool Integration — verified 2026-08-26

How the local routers are consumed from the desktop tools.
Model ids and contexts come from `documents/08-model-catalog.md`; do not restate the catalog here.

## aider

All workspace projects share the same rule-injection pattern: `.aider.conf.yml` reads the project's `prompts/01-contract.md`, `02-workflow.md`, `03-conventions.md`, the `common/` files, the semantic-sort flavor, and `tools/aider-rules.md`.

Historical usage (observed in the workspace `.aider.*` files, model-router-setup sessions, 2026-08): cloud models via OpenRouter (`--model openrouter/openrouter/auto`, `openrouter-gpt-4o`) through the LiteLLM proxy, `whole` edit format, repo-map 4096 tokens.

Local-model usage:

```sh
# routine edits — GPU-resident coder on beast
aider --openai-api-base http://beast.lan:2001/v1 --openai-api-key sk-local \
      --model Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M --edit-format whole

# architect mode — 120B plans on CPU, coder edits on GPU
aider --openai-api-base http://beast.lan:2001/v1 --openai-api-key sk-local \
      --model unsloth/gpt-oss-120b-GGUF:Q4_K_XL \
      --editor-model Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M --architect
```

Rules:

- Use `--edit-format whole`; `diff` formats are unreliable on local models.
- Keep sessions short: aider holds the whole conversation in context, and the GPU coder has 16384 context.
- Do not put R1-distill models in the agent loop; they follow tool schemas poorly.
- Shorter aliases work only after `alias = <name>` is added to the beast preset.

## llama.vscode

The official llama.cpp extension (`ggml-org.llama-vscode`, version checked 2026-08) provides inline completion, chat, an agent, embeddings, and tool selection, and can use a remote llama.cpp server.

Best use against the local routers:

| Purpose | Model |
| ---- | ---- |
| Inline completion (FIM) | `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` (athena, local) or the 32B coder (beast) |
| Chat | `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M` or Devstral (beast) |
| Agent | `unsloth/gpt-oss-20b-GGUF:Q4_K_XL` or the 120B for heavy runs |
| Embeddings | `ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0` (athena) |

Point the extension at `http://beast.lan:2001/v1` (or `http://athena.lan:2001/v1` for the small completions), and select the per-purpose model in its model picker.

## VS Code Chat View — decision 2026-08-26: suppress Copilot, use llama.vscode

The Chat view is tied to GitHub Copilot, and the owner decided (2026-08-26) to suppress it and use llama.vscode instead.

How to suppress:

- Extensions panel: disable or uninstall the Copilot extensions. On athena the installed Copilot-related extension is `ms-azuretools.vscode-azure-github-copilot` (plus the standard `github.copilot` / `github.copilot-chat` if present).
- Per-workspace fallback: `"github.copilot.enabled": false` in `.vscode/settings.json` keeps the extensions installed but off.

The replacement is llama.vscode (`ggml-org.llama-vscode`, version 0.0.63 installed on athena):

- Chat and the Llama Agent run entirely against the local routers; no Copilot plan needed.
- The Llama Agent works best with gpt-oss-20b (the extension's own recommendation); promote `unsloth/gpt-oss-20b-GGUF:Q4_K_XL` to a beast GPU preset in task 01.
- Inline completion needs a FIM-capable model: the Qwen2.5-Coder family (1.5B/3B on athena, 32B on beast).
- MCP tools from installed VS Code MCP servers can be selected for the agent.

Do not run overlapping agent UIs on the same project simultaneously; pick one surface per task (DSH for agentic sessions, aider in the CLI, llama.vscode in the editor).

## Tool-Against-Task Summary

| Task | Tool |
| ---- | ---- |
| Agentic repo work, background goals | DeepSeek Harness (DSH) with a beast provider |
| Quick CLI pair-programming in a project | aider with the coder model |
| Inline completion and in-editor chat | llama.vscode |
| Chat-with-docs, RAG | Open WebUI (optional) or llama.vscode chat |
