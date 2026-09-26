# Record: llama.vscode FIM is incompatible with router mode — 2026-09-26

## What happened

The owner reported that the llama.vscode configuration was not working, and that chat did not respond.
The freshly synced configuration was read correctly by the extension, so the models and endpoints were not the fault.

Diagnosis from the extension's own log (`~/.config/Code/logs/20260925*/window*/exthost/output_logging_*/*-llama-vscode.log`) found two independent failures.

1. **Inline completion**: 82 `FIM_PREP_POST_ERROR` lines in one session, every one of them `http://athena.lan:2001/infill | error=model name is missing from the request`.
2. **Agent**: one request failed with `TOOLS_STREAM_POST_ERROR | /v1/chat/completions | model=none | error=Invalid URL`, and an earlier one from the *old* config failed against `http://beast.lan:2001/v1/chat/completions | model=Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M | 400`.

Chat itself produced no llama.vscode request at all.

## Root cause 1 — the router rejects model-less calls

The extension's FIM context-priming payload omits the `model` field.
In `dist/llama-server.js`, `createRequestPayload(noPredict, ...)` includes `...(model.trim() != "" && { model: model })` only on the **non**-preparation branch; the preparation branch (lines 632-647) never sets it.
The same omission appears in the agent token-counting path, which falls back to the global `ai_model` instead of the resolved model.

The payload is written for a single-model `llama serve` on localhost.
A multi-model llama.cpp **router requires the model name to pick a child**, so it rejects the request.

Reproduced with curl on 2026-09-26:

| Call | athena router | single-model server |
| ---- | ---- | ---- |
| `POST /infill` with no `model` | 400 `model name is missing from the request` | 200 |
| `POST /v1/messages/count_tokens` with no `model` | 400 | 200 |

The extension's newer call sites are not at fault: `llama-vscode` v0.0.67 (2026-09-18) is the latest release, so there is nothing to upgrade to.
This is the same defect class Continue fixed by [including the model name in the completion request body](https://github.com/continuedev/continue/pull/11803).

## Root cause 2 — the Chat view used a Copilot cloud model

`GitHub Copilot Chat` 0.67.0 is present, authenticated, and on the `free_limited_copilot` SKU.
Its own log shows the request that "hung":

```
Server error: 400 {"error":{"message":"The requested model is not supported.","code":"model_not_supported","param":"model"}}
ccreq:9aa711e9.copilotmd | failed | gpt-5-mini
```

llama.vscode registers a language-model provider (vendor `llama-vscode`), and `provideLanguageModelChatInformation` returns an **empty list** when no chat endpoint is selected, because there is nothing to list from.
With no local model offered, the Chat view fell back to `gpt-5-mini`, which the free SKU rejects.

This also corrects `documents/09-tool-integration.md`, which claimed Copilot had been removed on 2026-08-26 and that the Chat view was skipped.
Copilot Chat does not appear under `~/.vscode/extensions`, so deleting an extension directory never controlled it.

## Fix applied

The completion tier no longer uses a router.
Two completion entries now carry a `localStartCommand` that starts a single-model server on `127.0.0.1:8012`, and the extension launches it on model selection and kills it on deselect:

```
/usr/local/bin/llama-server -hf 'Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0' --host 127.0.0.1 --port 8012 \
  --alias coder3 --ctx-size 8192 --n-gpu-layers 99 --flash-attn true --cache-reuse 256
```

A `coder15` variant uses the same port, so only one FIM server runs at a time.
Chat, agent and embeddings stay on the routers, because those requests do carry `model`.
The canonical fragment `sources/config/llama-vscode-settings.json` holds the wiring and `scripts/llama-vscode-config-apply.sh` applied it.

## Verification

- The exact launch command was started on athena 2026-09-26 and answered the previously failing model-less `/infill` preparation with **200**.
- `/props` on that server reported `n_ctx = 8192`, against 2048 per slot through the router's `parallel = 4`.
- The server was stopped, port 8012 was confirmed released, and athena's router was confirmed healthy afterwards (`/health` ok, 16 models listed).
- `POST /models/unload` on the router was used to free the router's copy of `coder3` for the test.
- `make test` passes, including `tests/03-llama-vscode-settings-validate.sh`, which was extended to accept local-start-command entries (28 model references verified).

## Lesson

- A multi-model router is not a drop-in replacement for `llama serve` for every client. Any client that omits `model` on a llama.cpp endpoint works only against a single-model server.
- llama.vscode is built around one local server per role. Remote endpoints work for chat, tools and embeddings, but completion needs its own single-model server.
- The provider lists models from the selected chat endpoint, so an unselected env silently yields an empty picker and a fallback to Copilot's cloud models.

## Open items

- The owner must re-select an env after this change, because llama.vscode persists its own copy of the previous selection; a stale selection kept pointing at the removed `coder32` on beast `:2001`.
- For chat, a local model must be chosen in the VS Code Chat view's model picker; otherwise the free Copilot SKU rejects its own cloud model.
- Athena VRAM is 8 GB total. The router and the FIM server can each hold `coder3`; when that becomes tight, use the `coder15` completion entry, which is roughly half the size.

## Commits

- See `git log -- records/2026-09-26-01-llama-vscode-router-fim-incompatibility.md`.
  The commit that adds this file is cited by subject and path rather than by hash, because a commit cannot contain its own hash.
