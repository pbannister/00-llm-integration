# Record: llama.vscode three-tier configuration applied — 2026-09-25

## Outcome

The `llama-vscode.*` settings in `~/.config/Code/User/settings.json` were replaced with a configuration that matches the live routers, and a canonical copy now lives in the repository.

The owner chose the tier mapping, the change scope, and to leave the athena router untouched.

- Tier 1, local GPU, small and light work: athena `coder3` (`Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0`) for inline completion.
- Tier 2, MI25 on beast, more complex work: beast `:2001` `coder14` (`bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M`) for chat.
- Tier 3, CPU and the larger model, long-running work: beast `:2002` `gpt-oss-120b` (`unsloth/gpt-oss-120b-GGUF:Q4_K_XL`) for agent and tool loops.
- Embeddings for RAG: athena `nomic-embed` (`ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0`).

Router mode is kept. It works with the extension and is the better fit here; the evidence is below.

## Previous settings defects (verified 2026-09-25)

All four model lists named models the routers no longer serve, or named the wrong endpoint:

| Defect | Detail |
| ---- | ---- |
| Removed beast models | `Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M`, `unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_M`, and `unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:UD-Q4_K_XL` were removed from beast on 2026-09-03 and are absent from `GET /v1/models`. |
| Wrong router for the 120B | Every `gpt-oss-120b` entry used `http://beast.lan:2001`; the 120B is served only by the CPU router on `:2002`. |
| Wrong quant suffix | gpt-oss and gemma ids were written `:UD-Q4_K_XL`; the live ids end `:Q4_K_XL`. Requests would fail with `model not found`. |
| No embeddings model | `llama-vscode.embeddings_models_list` was unset, so RAG and the `search_source` tool had no embedding endpoint. |
| Off-schema field | One tools entry carried `apiKey` and a trailing-slash endpoint; `apiKey` is not in the extension schema, and keys are stored per endpoint in the extension's own persistence. |

## Live router facts (verified 2026-09-25)

| Endpoint | Role | Live models |
| ---- | ---- | ---- |
| `http://beast.lan:2001` | MI25 GPU router, `--models-max 1` | `coder14` (16384), `qwen9` (32768), `gemma-12b` (32768), `gemma-26b` (81920), `gpt-oss-20b` (32768), `qwen38` (16384) |
| `http://beast.lan:2002` | CPU router | `gpt-oss-120b` (65536) |
| `http://athena.lan:2001` | desktop GPU router | 16 models, 8 aliased: `coder15`, `coder3`, `llama3`, `gemma-e4`, `qwen27`, `coder32-fallback`, `r1-32b-fallback`, `nomic-embed` |

## Router mode assessment

The extension does not require `localStartCommand`. A model entry with only `endpoint` and `aiModel` is contacted over HTTP, and the extension runs a shell command only when `localStartCommand` is set (`selectStartModel` in `dist/extension.js`).

Everything llama.vscode sends was exercised against the routers:

| Call | Result |
| ---- | ---- |
| `POST <endpoint>/infill` | Proxied to the child server and honors `model`. `coder3` returned a valid FIM completion in 0.40 s. |
| `POST <endpoint>/v1/chat/completions` with `tools` | Returns OpenAI `tool_calls` for gpt-oss and gemma models. |
| `POST <endpoint>/v1/embeddings` | `nomic-embed` returned a 768-dimension vector in 1.9 s. |
| `GET <endpoint>/health` | `{"status":"ok"}` at router level. |
| `GET <endpoint>/v1/models` | Reports `owned_by: "llamacpp"` and a `meta` block, which is exactly what the extension's provider detection and token-limit extraction read. |
| `GET <endpoint>/props?model=<id>&autoload=false` | Forwarded to the child and returns its `default_generation_settings` and `model_path`. |

The endpoint value must not include `/v1`. Chat is built as `${endpoint}/${ai_api_version}/chat/completions` and FIM as `${endpoint}/infill`.

Two router-mode caveats are recorded rather than fixed:

- A bare `GET /props` returns the router's own properties (`"role":"router"`, `n_ctx 0`), not a model's. The model-scoped form works, but returns `{"error": ... "not found"}` for a model that is not yet instantiated. The extension therefore falls back to its default advertised limits until a model has been loaded once.
- `--models-max 1` on the beast GPU router means two different selected models evict each other. The recommended env asks the MI25 for one model only and puts the agent model on the CPU router.

### Tool-call behavior by model

| Model | Endpoint | `tool_calls` | Note |
| ---- | ---- | ---- | ---- |
| `gpt-oss-20b` | beast:2001 | yes | 28 s cold, load included |
| `gpt-oss-120b` | beast:2002 | yes | 94 s cold, load included |
| `gemma-4-E4B` | athena:2001 | yes | |
| `Llama-3.2-3B` | athena:2001 | yes | |
| `Qwen2.5-Coder-14B` | beast:2001 | **no** | Emitted a `<tools>{...}</tools>` text block instead; usable for chat, not for the agent. |

`coder14` is therefore absent from `tools_models_list` on purpose.

### Context is per slot, not per model

`default_generation_settings.n_ctx` is the per-slot context. Athena runs `parallel = 4`, so its 8192 context yields 2048 tokens per request; beast GPU runs `parallel = 1`, so `coder14` reports its full 16384. This is why athena is used for FIM completion only.

## Applied configuration

The canonical fragment is `sources/config/llama-vscode-settings.json`. Four envs are defined:

| Env | Completion | Chat | Tools |
| ---- | ---- | ---- | ---- |
| Tiered - Athena FIM, MI25 chat, CPU 120B agent | athena `coder3` | beast `coder14` | beast:2002 `gpt-oss-120b` |
| MI25 single model - gpt-oss-20B chat and agent | athena `coder3` | beast `gpt-oss-20b` | beast `gpt-oss-20b` |
| Athena only - local GPU, beast offline | athena `coder3` | athena `Llama-3.2-3B` | athena `gemma-e4` |
| CPU heavy - 120B chat and agent | athena `coder3` | beast:2002 `gpt-oss-120b` | beast:2002 `gpt-oss-120b` |

`gpt-oss-120b` is listed only against `http://beast.lan:2002`. `qwen38` is not referenced: the 2026-09-21 benchmark concluded it cannot be made to work well on this host.

## Files

- create `sources/config/llama-vscode-settings.json` — canonical `llama-vscode.*` fragment.
- create `scripts/llama-vscode-config-apply.sh` — merges the fragment into a JSONC settings file, backing it up first.
- create `tests/03-llama-vscode-settings-validate.sh` — checks every referenced model id against the captures.
- modify `~/.config/Code/User/settings.json` — the live editor settings, outside the repository.
- backup `~/.config/Code/User/settings.json.bak-20260925-175041` — the pre-change settings.

## Verification

- `make test` passes, including the new `03-llama-vscode-settings-validate.sh` (29 model references verified against the captures).
- All 29 live model references were re-checked against live `GET /v1/models`; 0 unresolved.
- The merge is idempotent and, by a JSONC-aware key diff, added only `llama-vscode.auto` and `llama-vscode.embeddings_models_list`, changed only the four model lists, and removed no keys.

## Open items

- The OpenRouter entries that previously sat in `tools_models_list` were dropped when that list was replaced. They remain in the backup if wanted.
- `documents/07-endpoints-map.md`, `documents/08-model-catalog.md`, `documents/09-tool-integration.md`, and `prompts/features/01-endpoints-and-models.md` and `03-aider-and-vscode.md` still describe the removed beast models. The owner chose not to update them in this change; they are now the main stale artifacts.
- Health checks (`llama-vscode.health_check_*_enabled`) were left at their defaults; enabling them would refresh model status in the UI but does not change the token-limit fallback described above.
- Athena's `parallel = 4` was left as-is by owner choice.

## Commits

- See `git log -- records/2026-09-25-01-llama-vscode-config-applied.md` — `feat: three-tier llama.vscode config for athena GPU, beast MI25, and beast CPU`.
  The commit that adds this file is cited by subject and path rather than by hash, because a commit cannot contain its own hash.
