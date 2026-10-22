# Feature: DeepSeek Harness Provider Integration

## Purpose

Defines how the DeepSeek Harness (the `dsh` web GUI on this desktop) reaches the local routers through the `llm-pi-ai` adapter, so a `dsh` session uses the same models as aider and llama.vscode instead of a cloud provider.

## Requirements

- `DSH-R001` — A model `id` must match a router model id exactly (`GET /v1/models`) or an alias configured on the router; an unknown id fails with `UNKNOWN_MODEL`.
- `DSH-R002` — `contextWindow` must match or undershoot the router preset `ctx-size`. A bare entry without capacities inherits the 262144/32768 defaults, which exceed every local preset and cause context overflow failures.
- `DSH-R003` — `maxTokens` must sit well under `contextWindow`, typically 4096–16384.
- `DSH-R004` — Prefer a curated list of the models actually used; the router may list many more.
- `DSH-R005` — Local models are non-reasoning: do not request a reasoning effort when a beast model is selected; leave the effort off.
- `DSH-R006` — The `compat` block is required for llama.cpp. pi-ai cannot recognise the endpoint URL, so without it the adapter sends OpenAI's dialect (`developer` role, `max_completion_tokens`), which llama.cpp does not reliably accept. `supportsDeveloperRole: false` selects the `system` role and `maxTokensField: max_tokens` selects the `max_tokens` field.
- `DSH-R007` — Store any non-empty credential under the `BEAST_API_KEY` reference through the GUI Models settings, which writes `~/.dsh/.credentials.yaml`, or export it in the `dsh` launch environment. If `--api-key` is later added to the llama.service on beast, the same value must be stored.
- `DSH-R008` — Any task that writes or corrects the DSH provider section must read the latest `dataflow.in/endpoints/` capture for the router model ids and contexts.

## Behavior

- A route declared in `~/.dsh/settings.yaml` serves its configured models on the next request; no restart is needed.
- Credentials resolve from `apiKeyEnv` through the process environment, then `~/.dsh/.credentials.yaml`, then `.env` files.

## Dependencies

- None.

## Mechanism

DeepSeek Harness ships a generic multi-provider adapter (`@deepseek-ai/dsh-llm-pi-ai`) keyed by provider route in the `llm-pi-ai` settings namespace (`~/.dsh/settings.yaml`). A route that pi-ai does not ship is declared outright with `api`, `baseURL`, and a `models` list.

## Canonical Route

The `beast` route is the canonical local provider. The corrected example lives in `sources/config/dsh-settings-beast.example.yaml`.

```yaml
llm-pi-ai:
  providers:
    beast:
      displayName: Beast (llama.cpp)
      apiKeyEnv: BEAST_API_KEY
      api: openai-completions
      baseURL: http://beast.lan:2001/v1
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: <router model id>
          contextWindow: <preset ctx-size>
          maxTokens: <safe output cap, well under ctx-size>
```

## Credential

llama.cpp ignores `Authorization` unless the router runs with `--api-key`.

## GUI Surface

The Models settings section in the web GUI offers a custom-provider creation card (route, display name, base URL, protocol, API key, models) and per-model advanced fields (context window, max tokens). The card does not expose `compat`; add the `compat` block by editing `~/.dsh/settings.yaml` directly.
