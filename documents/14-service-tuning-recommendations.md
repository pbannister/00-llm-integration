# Service Tuning Recommendations — APPLIED 2026-08-26

Task 01 output. Applied to both hosts on 2026-08-26 and verified (aliases route, `--parallel 4` in child args, embeddings endpoint answers).
Applied configs archived at `sources/config/beast-config.applied.ini` and `sources/config/athena-config.applied.ini`; live baselines backed up as `/usr/local/etc/config.ini.bak-20260826` on each host.
Model facts from `documents/08-model-catalog.md` and `documents/12-model-retention.md`.

## Beast

### 1. `[*]` global section

| Key | Current | Proposed | Why |
| ---- | ---- | ---- | ---- |
| `parallel` | unset (1) | `4` | DSH subagents and multiple clients currently serialize on one slot |
| `ctx-size` | 32768 | keep | cache entries use it |

### 2. Aliases (one per preset section)

Add `alias = <name>` to each preset so clients use short ids:

| Preset | Alias |
| ---- | ---- |
| `[Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M]` | `coder32` |
| `[unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q4_K_M]` | `devstral` |
| `[unsloth/DeepSeek-R1-Distill-Qwen-14B-GGUF:UD-Q4_K_XL]` | `r1-14b` |
| `[unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL]` | `gemma-26b` |
| `[unsloth/gpt-oss-120b-GGUF:UD-Q4_K_XL]` | `gpt-oss-120b` |
| `[unsloth/DeepSeek-R1-Distill-Llama-70B-GGUF:UD-Q4_K_XL]` | `r1-70b` |
| `[unsloth/Llama-3.3-70B-Instruct-GGUF:UD-Q4_K_XL]` | `llama70` |

### 3. Promote cache models to presets (all fit the MI25 GPU)

| New preset | Proposed settings | Role |
| ---- | ---- | ---- |
| `[bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M]` | `ngl = 99`, `ctx-size = 16384`, `temp = 0.2`, `alias = coder14` | mid-size GPU coder |
| `[unsloth/Qwen3.5-9B-GGUF:Q4_K_M]` | `ngl = 99`, `ctx-size = 32768`, `alias = qwen9` | general 9B |
| `[unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL]` | `ngl = 99`, `ctx-size = 32768`, `alias = gpt-oss-20b` | llama.vscode agent model |
| `[unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL]` | `ngl = 99`, `ctx-size = 32768`, `alias = gemma-12b` | general 12B |

### 4. MTP on the 120B — benchmarked 2026-08-26, no change needed

Measured on beast with a scratch llama-server (`scripts/mtp-bench-beast.sh`), `gpt-oss-120b` UD-Q4_K_XL, `-ngl 0`, 319-token prompt, 128 generated tokens:

| Run | Generation t/s | Prompt t/s | Note |
| ---- | ---- | ---- | ---- |
| default (no flags) | 9.30 | 2.38 | "graphs reused = 127" in the server log |
| `--spec-type draft-mtp` | failed to start | — | expects a separate drafter model ("failed to create llama_context from model") |

Conclusion: llama.cpp **auto-enables the gpt-oss built-in MTP head** — the default run already hits 9.3 t/s (matching the owner's earlier 8.42 t/s benchmark, and ~10× the 70B models' 0.91 t/s). No `spec-type` preset line is needed or valid for gpt-oss.
Second finding: prompt processing is slow (2.4 t/s) — the 120B suits generation-heavy background batches with modest prompts, not long-context agent sessions (see `documents/10-routing-policy.md`).

### 5. gemma-26B context

- `ctx-size = 81920` is kept (owner's choice) but note the KV cost; the commented `65536` is a lighter alternative. No change proposed.

## Athena

### 1. `[*]` global

| Key | Current | Proposed | Why |
| ---- | ---- | ---- | ---- |
| `parallel` | unset (1) | `4` | same as beast |

### 2. Aliases

| Preset | Alias |
| ---- | ---- |
| `[Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0]` | `coder15` |
| `[Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0]` | `coder3` |
| `[unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0]` | `llama3` |
| `[unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL]` | `gemma-e4` |
| `[Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M]` | `coder32-fallback` |
| `[unsloth/DeepSeek-R1-Distill-Qwen-32B-GGUF:UD-Q4_K_XL]` | `r1-32b-fallback` |

### 3. Embeddings preset (RAG enabler)

| New preset | Proposed settings | Role |
| ---- | ---- | ---- |
| `[ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0]` | `embeddings = on`, `pooling = mean` (verify keys against `llama-server --help`), `alias = nomic-embed` | `/v1/embeddings` for RAG |

Verify the preset key spelling on athena's build (10129) before applying: `llama-server --help | grep -i embed`.

## Apply Procedure (done 2026-08-26)

1. Edit `/usr/local/etc/config.ini` on beast, then `sudo systemctl restart llama.service` on beast.
2. Same for athena.
3. Refresh captures: `make capture`; confirm the new aliases and presets in `/v1/models`.
4. Re-run `make test`.

## Open items

- 27B family was discarded (retention decision); no preset is proposed for it.
- ~~Verify the coder-14B, qwen-9B, gpt-oss-20b, gemma-12B promotions actually fit MI25 VRAM at their contexts after restart (watch `llama-server` logs for offload spill).~~ **Resolved 2026-09-02**: explicit `ngl = 99` was defeating `fit = on`; presets now omit `ngl` so layers trim to 16 GiB VRAM (see the GPU-preset stability section above).


## KV-cache quantization analysis (task 03) — 2026-08-26

- KV quant is a runtime setting (`cache-type-k/v`), not a weight change: **no model downloads or variants needed**.
- Measured from GGUF metadata (`scripts/kv-cache-size.py`): q8_0 halves KV memory everywhere; the big levers are gemma-26b at 81920 ctx (12.9 → 6.4 GB) and gemma-12b at 32768 (11.3 → 5.6 GB).
- APPLIED 2026-08-26: `cache-type-k = q8_0` + `cache-type-v = q8_0` in `[*]` on both routers; `cache-type-v = q4_0` per-preset for gemma-26b/gemma-12b. Analysis in `records/2026-08-26-09-kv-quant-analysis.md`; memory/spill table in `records/2026-08-26-10-kv-quant-applied.md`.

## Upgrade checklist (learned 2026-09-10)

- **Validate preset keys against the new binary before restarting anything**: `scripts/preset-keys-check.sh <llama-server> <config.ini>`. Preset keys are CLI option names, so an upstream rename/removal (0.4.0 dropped `mmap` for `load-mode`) makes the router refuse to start in a systemd restart loop.
- Dry-run the config on a scratch port, then restart; keep a dated config backup and re-sync `sources/config/*.applied.ini`.
- See `records/2026-09-10-01-llamacpp-mmap-preset-key-removed.md`.

## Version review 2026-08-26 (llama.cpp 0.3.0-dev rebuild)

- Verified the tuned configs work unchanged on beast 10657 / athena 10643; aliases and `parallel = 4` intact.
- New recommendation from the rebuild: `cache-reuse = 256` under `[*]` on both hosts (KV shifting reuse across requests; targets the 120B's slow prompt processing with repeated system prompts). APPLIED 2026-08-26 and verified in child args. Baselines: `/usr/local/etc/config.ini.bak-20260826-cachereuse`. See `records/2026-08-26-06-dsh-and-cache-reuse-applied.md`.
- `--parallel` default is now auto; the explicit `4` still applies.

## GPU-preset stability change 2026-09-02 (beast)

After recurring amdgpu ring timeouts / Vulkan device loss on the MI25 (60 device-lost events since Jul 31 — see `records/2026-09-02-01-mi25-vulkan-device-lost-tuning.md`), the beast GPU presets changed 2026-09-02 (baseline `/usr/local/etc/config.ini.bak-20260902`):

- Removed explicit `ngl = 99` from all GPU presets — `fit = on` now trims layers to the 16 GiB VRAM, with excess layers on CPU. Resolves the Aug 26 open item below: the explicit `ngl = 99` was defeating `fit` (coder32's 18.49 G weights exceed 16 G even at zero context).
- `flash-attn = false` on GPU presets (VEGA10/gfx900 FA instability).
- `cache-type-v = f16` on GPU presets — a quantized V cache requires flash-attn in llama.cpp; f16 V keeps attention valid with FA off (K stays `q8_0`).
- CPU heavyweights unchanged (`ngl = 0`).
- Gotcha: the router snapshots `config.ini` at `llama.service` start — edits need `sudo systemctl restart llama.service`.
- Athena unchanged; revisit if athena's GPU shows the same resets.

## Update 2026-09-25 — the preset set changed after this application

The alias and promotion tables above record what was applied on 2026-08-26; they are not the current preset set.
The beast cache and presets were trimmed again on 2026-09-03 (`records/2026-09-03-04-cpu-gpu-router-split-and-cache-trim.md`), and the routers are split into a GPU service on `:2001` and a CPU service on `:2002`.

Current presets, verified 2026-09-25:

| Host / router | Presets |
| ---- | ---- |
| beast `llama.service` :2001 (GPU) | `coder14`, `qwen9`, `gpt-oss-20b`, `gemma-12b`, `gemma-26b`, `qwen38` |
| beast `llama-cpu.service` :2002 (CPU) | `gpt-oss-120b` |
| athena :2001 | `coder3`, `coder15`, `llama3`, `gemma-e4`, `qwen27`, `nomic-embed`, `coder32-fallback`, `r1-32b-fallback` |

The aliases `coder32`, `devstral`, `r1-14b`, `r1-70b` and `llama70` no longer exist on any router.
`gpt-oss-120b` is served only by `:2002`; `:2001` does not answer for it.
Roles and contexts are in `documents/08-model-catalog.md`.
Note also that `config.ini` writes the repository quant selector (`:UD-Q4_K_XL`) while `GET /v1/models` reports the resolved quant (`:Q4_K_XL`); clients must use the reported id or the alias.

The MTP finding in section 4 still stands: llama.cpp auto-enables the gpt-oss built-in MTP head, and no `spec-type` preset line is needed.
