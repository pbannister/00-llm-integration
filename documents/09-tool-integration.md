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

`localStartCommand` is optional per model entry: an entry carrying only `endpoint` and `aiModel` is contacted over HTTP, and an entry carrying a command makes the extension start and stop that server itself.
Chat, tools and embeddings run against the routers, but inline completion needs a server of its own:

| Tier | Purpose | Endpoint | Model |
| ---- | ---- | ---- | ---- |
| Local GPU | inline completion (FIM), small and light work | `http://127.0.0.1:8012` (single-model server, started by the extension) | `coder3` (or `coder15` for lowest latency) |
| MI25 | more complex chat and agent work | `http://beast.lan:2001` | `coder14` for chat, `gpt-oss-20b` for the agent |
| CPU | long-running and heavier work | `http://beast.lan:2002` | `gpt-oss-120b` |
| Embeddings | RAG and `search_source` | `http://athena.lan:2001` | `nomic-embed` |

The canonical settings fragment is `sources/config/llama-vscode-settings.json`, applied by `scripts/llama-vscode-config-apply.sh`.
It defines four envs: the tiered split above, an MI25-only variant with `gpt-oss-20b` for chat and agent, an athena-only offline variant, and a CPU-heavy 120B variant.

### Why completion must not run through the router

The extension's FIM context-priming payload and its token-counting call omit the `model` field, because they were written for a single-model `llama serve` on localhost.
A multi-model llama.cpp router rejects a model-less request.

| Call | Router (multi-model) | Single-model server |
| ---- | ---- | ---- |
| `POST /infill` with no `model` | 400 `model name is missing from the request` | 200 |
| `POST /v1/messages/count_tokens` with no `model` | 400 | 200 |

Both rows verified 2026-09-26 against athena's router and a throwaway single-model server.
The completion entries therefore carry a `localStartCommand` that starts a single-model server on `127.0.0.1:8012`; the extension launches it when the model is selected and kills it on deselect.
Two side benefits: the server reports the full preset context (8192, against 2048 per slot through the router's `parallel = 4`), and the model id comes back as the alias, so the extension's model-less priming request succeeds.
Chat and agent requests do carry `model`, so the routers serve those unchanged.

### VS Code Chat view and the llama-vscode provider

llama.vscode registers a language-model provider (vendor `llama-vscode`) that exposes the models of the selected chat endpoint to the VS Code Chat view.
Two consequences:

- The provider returns no models when neither a chat nor a tools model is selected, because there is no endpoint to list from. Select an env first, or the picker shows nothing local.
- Without a `llama-vscode` model chosen in the Chat view's model picker, the Chat view uses a GitHub Copilot cloud model. On a `free_limited_copilot` SKU that fails with 400 `model_not_supported` and the chat appears to hang. This is unrelated to the local routers; pick the local model in the picker.

Facts that shape the mapping (verified 2026-09-25, router compatibility verified 2026-09-26):

- `coder14` returns a `<tools>` text block rather than parsed tool calls, so it is not offered as a tools model.
- `gpt-oss-20b`, `gpt-oss-120b`, `gemma-e4` and `llama3` all returned parsed `tool_calls`.
- The beast GPU router runs `--models-max 1`; asking it for two different models makes them evict each other, which the tiered env avoids by putting the agent model on the CPU router.
- The athena router's `parallel = 4` divides its 8192 context into 2048 tokens per request, which is why athena serves completion from its own single-model server rather than from the router.

Do not include `/v1` in the extension's `endpoint` value; it appends `/infill` and `/v1/chat/completions` itself.
Inline completion requires a FIM-capable model; the Qwen2.5-Coder family is the right one in this catalog.
MCP tools from installed VS Code MCP servers can be selected for the agent.

## VS Code Chat View

The Chat view is provided by GitHub Copilot Chat.
**Correction 2026-09-26:** Copilot Chat is present and authenticated on athena (version 0.67.0, signed in, `free_limited_copilot` SKU), and it does not appear under `~/.vscode/extensions`, so removing an extension directory is not what controls it.
The earlier "option 3, Copilot suppressed" decision is therefore superseded.

Options for local or OpenAI-compatible models, in order of preference for this setup:

1. **The llama.vscode provider (preferred)**: select an env in llama.vscode, then pick one of its models in the Chat view's model picker. Requests go to the selected chat endpoint's router.
2. **GitHub Copilot BYOK** (bring your own key): Copilot Chat accepts an OpenAI-compatible base URL and key, but its BYOK provider list (`ollama`, `anthropic`, `gemini`, `xai`, `openai`, `openrouter`, `azure`, `customoai`, `customendpoint`) has no llama.cpp-router entry, so use `customoai` pointed at `http://beast.lan:2001/v1`, or option 1.
3. **Third-party gateway extensions** that route Copilot Chat to self-hosted models (for example `github-copilot-llm-gateway`, `AgenticProxy` on the marketplace).
4. **Skip the Chat view**: the llama.vscode chat and agent panels cover chat and agentic editing without Copilot.

Pitfalls (verified 2026-09-26):

- The Chat view defaults to a Copilot cloud model. On the free SKU that model can be rejected with 400 `model_not_supported`, so the chat appears to hang until a local model is chosen in the picker.
- `llama-vscode.chat_models_list` and `llama-vscode.tools_models_list` are separate from the Chat view's picker: the picker lists whatever the selected chat endpoint serves, so the env must be selected first.
- Per-workspace `"github.copilot.enabled": false` keeps Copilot off where preferred.

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
