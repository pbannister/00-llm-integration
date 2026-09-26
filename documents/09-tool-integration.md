# Tool Integration — verified 2026-09-25

How the local routers are consumed from the desktop tools.
Model ids and contexts come from `documents/08-model-catalog.md`; this document does not restate the catalog.
Router ids below are the tuned aliases; a full router id works anywhere an alias is shown, but the `UD-` preset-key form does not (see the catalog's id-resolution rule).

## aider

All workspace projects share the same rule-injection pattern: `.aider.conf.yml` reads the project's `prompts/01-contract.md`, `02-workflow.md`, `03-conventions.md`, the `common/` files, the semantic-sort flavor, and `tools/aider-rules.md`.

Historical usage (observed in the workspace `.aider.*` files, model-router-setup sessions, 2026-08): cloud models via OpenRouter (`--model openrouter/openrouter/auto`, `openrouter-gpt-4o`) through the LiteLLM proxy, `whole` edit format, repo-map 4096 tokens.
The local-model path replaces that for private and free work.

Local-model invocation against the beast routers:

```sh
# routine edits — GPU-resident coder on the MI25
aider --openai-api-base http://beast.lan:2001/v1 --openai-api-key sk-local \
      --model coder14 --edit-format whole

# long planning run — 120B on the CPU router
aider --openai-api-base http://beast.lan:2002/v1 --openai-api-key sk-local \
      --model gpt-oss-120b --edit-format whole
```

Rules:

- Use `--edit-format whole`; `diff` formats are unreliable on local models.
- Editing sessions use the GPU-resident coder (`coder14`); the 120B is the CPU planner and batch model, and it is slow.
- Architect mode pairs a planner with an editor, but aider applies one `--openai-api-base` per run, so the planner and editor must share a router. `--model gpt-oss-120b --editor-model gpt-oss-120b --architect` against `:2002` plans and edits with the 120B; a coder-edited plan needs its own session against `:2001`.
- Tool use is not needed for aider edits, but if it is used, only the gpt-oss and gemma models emit parsed `tool_calls`; `coder14` does not.
- Do not put R1-distill models in the agent loop; they follow tool schemas poorly.
- Keep sessions short: aider holds the whole conversation in context, and `coder14` has 16384 context.
- Athena variant for ultra-low-latency small work: same invocation with `--openai-api-base http://athena.lan:2001/v1` and `--model coder3`. Remember its 8192 context is divided over four slots.

## llama.vscode

The official llama.cpp extension (`ggml-org.llama-vscode`, version 0.0.67 installed on athena) provides inline completion, chat, an agent, embeddings, and tool selection, and can use a remote llama.cpp server.

The extension does not need to start `llama-server` itself: `localStartCommand` is optional, and a model entry carrying only `endpoint` and `aiModel` is contacted over HTTP. The routers therefore serve it directly under the three-tier split:

| Tier | Purpose | Endpoint | Model |
| ---- | ---- | ---- | ---- |
| Local GPU | inline completion (FIM), small and light work | `http://athena.lan:2001` | `coder3` (`coder15` when latency matters most) |
| MI25 | more complex chat and agent work | `http://beast.lan:2001` | `coder14` for chat, `gpt-oss-20b` for the agent |
| CPU | long-running and heavier work | `http://beast.lan:2002` | `gpt-oss-120b` |
| Embeddings | RAG and `search_source` | `http://athena.lan:2001` | `nomic-embed` |

The canonical settings fragment is `sources/config/llama-vscode-settings.json`, applied by `scripts/llama-vscode-config-apply.sh`.
It defines four envs: the tiered split above, an MI25-only variant with `gpt-oss-20b` for chat and agent, an athena-only offline variant, and a CPU-heavy 120B variant.

Facts that shape the mapping (verified 2026-09-25):

- `coder14` returns a `<tools>` text block rather than parsed tool calls, so it is not offered as a tools model.
- `gpt-oss-20b`, `gpt-oss-120b`, `gemma-e4` and `llama3` all returned parsed `tool_calls`.
- Athena's `parallel = 4` divides its 8192 context into 2048 tokens per request, so it is kept for FIM rather than chat.
- The beast GPU router runs `--models-max 1`; asking it for two different models makes them evict each other, which the tiered env avoids by putting the agent model on the CPU router.

Do not include `/v1` in the extension's `endpoint` value; it appends `/infill` and `/v1/chat/completions` itself.
Inline completion requires a FIM-capable model; the Qwen2.5-Coder family is the right one in this catalog.
MCP tools from installed VS Code MCP servers can be selected for the agent.

## VS Code Chat View

The Chat view is tied to GitHub Copilot. Three options exist for local or OpenAI-compatible providers:

1. **GitHub Copilot BYOK** (bring your own key): Copilot Chat accepts an OpenAI-compatible base URL and key; point it at `http://beast.lan:2001/v1`. Requires a Copilot plan.
2. **Third-party gateway extensions** that route Copilot Chat to self-hosted models (for example `github-copilot-llm-gateway`, `AgenticProxy` on the marketplace).
3. **Skip the Chat view**: llama.vscode chat and Cline/Roo Code already cover chat and agentic editing without Copilot.

**Decision (2026-08-26): option 3.** The owner suppresses Copilot and uses llama.vscode; no Copilot plan is needed. Suppression steps:

- Extensions panel: disable or uninstall the Copilot extensions. On athena the installed Copilot-related extension was `ms-azuretools.vscode-azure-github-copilot` (1.0.231) — **removed 2026-08-26** (extension directory deleted; llama.vscode is unaffected). The standard `github.copilot` / `github.copilot-chat` were not present.
- Per-workspace fallback: `"github.copilot.enabled": false` in `.vscode/settings.json` keeps the extensions installed but off.

Do not run overlapping agent UIs on the same project simultaneously; pick one surface per task (DSH for agentic sessions, aider in the CLI, llama.vscode in the editor).

## Tool-Against-Task Summary

| Task | Tool |
| ---- | ---- |
| Agentic repo work, background goals | DeepSeek Harness (DSH) with the beast/athena providers |
| Quick CLI pair-programming in a project | aider with `coder14` |
| Inline completion and in-editor chat and agent | llama.vscode, three-tier env |
| Chat-with-docs, RAG | Open WebUI (optional; embeddings endpoint live on athena) or llama.vscode chat |

## Version-Dependent versus Stable Facts

- **Version-dependent** (recheck on tool upgrades): aider flags and version (checked 0.86.2 on 2026-08-26); llama.vscode capabilities and version (checked 0.0.67 on 2026-09-25); Copilot extension ids/versions; `--edit-format` behavior on local models.
- **Stable (live-state, verified 2026-09-25)**: router endpoints and aliases (`http://beast.lan:2001/v1`, `http://beast.lan:2002/v1`, `http://athena.lan:2001/v1`), model roles from `documents/08-model-catalog.md`, the routing policy (`documents/10-routing-policy.md`).
