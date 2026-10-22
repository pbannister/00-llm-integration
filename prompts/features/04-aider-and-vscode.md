# Feature: Aider and VS Code

## Purpose

Defines local-model usage for aider and the VS Code surfaces (llama.vscode, VS Code Chat), so everyday editing, completion, and chat run against the house routers instead of a cloud provider.

## Requirements

- `AIDER-R001` — Use `--edit-format whole`; `diff` formats are unreliable on local models.
- `AIDER-R002` — Editing sessions use the GPU-resident coder (`coder14`).
- `AIDER-R003` — The 120B runs on the CPU router and is slow; reserve it for design work and long batch runs, not routine edits.
- `AIDER-R004` — Architect mode pairs a planner with an editor, but aider applies one `--openai-api-base` per run, so both models must live on the same router.
- `AIDER-R005` — Avoid R1-distill models in the agent loop; they follow tool schemas poorly.
- `AIDER-R006` — `aider` holds the whole conversation in context; keep sessions short, because context is the scarce resource on the GPU models.
- `AIDER-R007` — Use the router alias (`coder14`, `gpt-oss-120b`) or the reported model id, never the `UD-` preset-key form.
- `AIDER-R008` — The canonical llama.vscode settings fragment is `sources/config/llama-vscode-settings.json`; apply it with `scripts/llama-vscode-config-apply.sh`.
- `AIDER-R009` — `tests/03-llama-vscode-settings-validate.sh` guards every referenced model id against the captures.
- `AIDER-R010` — Do not include `/v1` in an `endpoint` value; the extension appends `/infill` and `/v1/chat/completions` itself.
- `AIDER-R011` — Completion must run against a single-model server, never a multi-model router. The extension's FIM-priming and token-counting calls omit the `model` field, which a router rejects with 400 `model name is missing from the request`; completion entries therefore carry a `localStartCommand` that starts a single-model `llama-server` on `127.0.0.1:8012`.
- `AIDER-R012` — Chat and agent requests do carry `model`, so the routers serve those tiers.
- `AIDER-R013` — Completion must use a FIM-capable model; the Qwen2.5-Coder family is the right one in this catalog.
- `AIDER-R014` — Do not offer `coder14` as a tools model; it does not emit parsed `tool_calls`.
- `AIDER-R015` — Keep the MI25 tier to one model per working session; the GPU router runs `--models-max 1` and two different models evict each other.
- `AIDER-R016` — The Chat view must not be left on a Copilot cloud model by default. On a free SKU that model can be rejected with 400 `model_not_supported` and the chat appears to hang.
- `AIDER-R017` — Do not run overlapping agent UIs on the same project at the same time; pick one surface per task.
- `AIDER-R018` — Tool behavior changes; documents describing extensions or flags carry a `verified <date>` marker and cite the version checked.
- `AIDER-R019` — Do not duplicate the router catalog here.

## Behavior

- An edit session against the MI25 completes with `--edit-format whole` and the configured coder model.
- Inline completion is served by the extension's own single-model server on `127.0.0.1:8012`; chat and agent requests are served by the beast routers.
- The Chat view lists a local model only after the `llama-vscode` env is selected.

## Dependencies

- `prompts/features/01-endpoints-and-models.md`

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

## llama.vscode

The official llama.cpp VS Code extension (`ggml-org.llama-vscode`) provides inline completion, chat, an agent, embeddings, and tool selection, and can use a remote llama.cpp server.
It does not need to start `llama-server` itself: `localStartCommand` is optional, so the routers serve it directly.

The tiered mapping:

| Tier | Purpose | Endpoint | Model |
| ---- | ---- | ---- | ---- |
| Local GPU | inline completion (FIM), small and light tasks | `http://127.0.0.1:8012` (single-model server started by the extension) | `coder3` (or `coder15` for lowest latency) |
| MI25 | more complex chat and agent work | `http://beast.lan:2001` | `coder14` for chat, `gpt-oss-20b` for the agent |
| CPU | longer-running and heavier work | `http://beast.lan:2002` | `gpt-oss-120b` |
| Embeddings | RAG and the `search_source` tool | `http://athena.lan:2001` | `nomic-embed` |

## VS Code Chat View

The Chat view is provided by GitHub Copilot Chat, which is installed and authenticated on athena.
Local models reach it through the `llama-vscode` language-model provider that the extension registers, so the env must be selected before any local model appears in the picker.
Options for local or OpenAI-compatible providers, in order of preference for this setup:

1. The llama.vscode provider: select an env, then pick one of its models in the Chat view's model picker.
2. GitHub Copilot BYOK (bring your own key): use the `customoai` provider pointed at a router base URL, since Copilot's BYOK list has no llama.cpp-router entry.
3. Third-party gateway extensions that route Copilot Chat to self-hosted models (for example `github-copilot-llm-gateway`, `AgenticProxy` on the marketplace).
4. Skip the Chat view entirely: the llama.vscode chat and agent panels cover chat and agentic editing without Copilot.
