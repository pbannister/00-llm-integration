# Tool Integration — verified 2026-08-26

How the local routers are consumed from the desktop tools.
Model ids and contexts come from `documents/08-model-catalog.md`; this document does not restate the catalog.
Router ids below are the tuned aliases (live since 2026-08-26); a full router id works anywhere an alias is shown.

## aider

All workspace projects share the same rule-injection pattern: `.aider.conf.yml` reads the project's `prompts/01-contract.md`, `02-workflow.md`, `03-conventions.md`, the `common/` files, the semantic-sort flavor, and `tools/aider-rules.md`.

Historical usage (observed in the workspace `.aider.*` files, model-router-setup sessions, 2026-08): cloud models via OpenRouter (`--model openrouter/openrouter/auto`, `openrouter-gpt-4o`) through the LiteLLM proxy, `whole` edit format, repo-map 4096 tokens. The local-model path replaces that for private and free work.

Local-model invocation against the beast router (aider 0.86.2):

```sh
# routine edits — GPU-resident coder on beast
aider --openai-api-base http://beast.lan:2001/v1 --openai-api-key sk-local \
      --model coder32 --edit-format whole

# architect mode — 120B plans on CPU, coder edits on GPU
aider --openai-api-base http://beast.lan:2001/v1 --openai-api-key sk-local \
      --model gpt-oss-120b --editor-model coder32 --architect
```

Rules:

- Use `--edit-format whole`; `diff` formats are unreliable on local models.
- Editing sessions use the GPU-resident coder (`coder32`); reserve architect mode (120B planner, slow, CPU) for design work, not routine edits.
- Do not put R1-distill models in the agent loop; they follow tool schemas poorly.
- Keep sessions short: aider holds the whole conversation in context, and `coder32` has 16384 context.
- Athena variant for ultra-low-latency small work: same invocation with `--openai-api-base http://athena.lan:2001/v1` and `--model coder3`.

## llama.vscode

The official llama.cpp extension (`ggml-org.llama-vscode`, version 0.0.63 installed on athena) provides inline completion, chat, an agent, embeddings, and tool selection, and can use a remote llama.cpp server.

Best use against the local routers:

| Purpose | Model |
| ---- | ---- |
| Inline completion (FIM) | `coder3` (athena, local) or `coder32` (beast) |
| Chat | `coder32` or `devstral` (beast) |
| Agent | `gpt-oss-20b` (beast GPU preset since task 01; the extension's own recommended agent model) or `gpt-oss-120b` for heavy runs |
| Embeddings | `nomic-embed` (athena; `/v1/embeddings`) |

Point the extension at `http://beast.lan:2001/v1` (or `http://athena.lan:2001/v1` for the small completions), and select the per-purpose model in its model picker.
Inline completion requires a FIM-capable model — the Qwen2.5-Coder family is the right one in this catalog.
MCP tools from installed VS Code MCP servers can be selected for the agent.

## VS Code Chat View

The Chat view is tied to GitHub Copilot. Three options exist for local or OpenAI-compatible providers:

1. **GitHub Copilot BYOK** (bring your own key): Copilot Chat accepts an OpenAI-compatible base URL and key; point it at `http://beast.lan:2001/v1`. Requires a Copilot plan.
2. **Third-party gateway extensions** that route Copilot Chat to self-hosted models (for example `github-copilot-llm-gateway`, `AgenticProxy` on the marketplace).
3. **Skip the Chat view**: llama.vscode chat and Cline/Roo Code already cover chat and agentic editing without Copilot.

**Decision (2026-08-26): option 3.** The owner suppresses Copilot and uses llama.vscode; no Copilot plan is needed. Suppression steps:

- Extensions panel: disable or uninstall the Copilot extensions. On athena the installed Copilot-related extension is `ms-azuretools.vscode-azure-github-copilot` (1.0.231; plus the standard `github.copilot` / `github.copilot-chat` if present). Not yet done as of 2026-08-26.
- Per-workspace fallback: `"github.copilot.enabled": false` in `.vscode/settings.json` keeps the extensions installed but off.

Do not run overlapping agent UIs on the same project simultaneously; pick one surface per task (DSH for agentic sessions, aider in the CLI, llama.vscode in the editor).

## Tool-Against-Task Summary

| Task | Tool |
| ---- | ---- |
| Agentic repo work, background goals | DeepSeek Harness (DSH) with the beast/athena providers |
| Quick CLI pair-programming in a project | aider with `coder32` |
| Inline completion and in-editor chat | llama.vscode |
| Chat-with-docs, RAG | Open WebUI (optional; embeddings endpoint live on athena) or llama.vscode chat |

## Version-Dependent versus Stable Facts

- **Version-dependent** (recheck on tool upgrades): aider flags and version (checked 0.86.2); llama.vscode capabilities and version (checked 0.0.63); Copilot extension ids/versions; `--edit-format` behavior on local models.
- **Stable (live-state, verified 2026-08-26)**: router endpoints and aliases (`http://beast.lan:2001/v1`, `http://athena.lan:2001/v1`), model roles from `documents/08-model-catalog.md`, the routing policy (`documents/10-routing-policy.md`).
