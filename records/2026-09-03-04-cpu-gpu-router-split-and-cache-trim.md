# Record: beast cache trim + CPU/GPU router split (VRAM guard) — 2026-09-03

## Cache trim (executed 2026-09-03)

Removed from beast cache and config (backup: `config.ini.bak-20260903-removals`):
coder32 (19 G — weights 18.5 GiB exceed the 16 GiB MI25), devstral (14 G), llama70 (40 G),
r1-70b (40 G — ~1 t/s CPU), gemma-4-E2B/E4B (9.2 G — minerva decision, keep elsewhere),
r1-14b (preset only, files already gone). **~122 G freed**; config rewritten cleanly.
Beast now runs 7 presets (6 GPU-fit + gpt-oss-120b CPU).

## Router split (VRAM guard) — executed 2026-09-03

Goal (owner): CPU-only models freely coexisting; GPU-preferred models strictly one-at-a-time.
Stock llama.cpp cannot express that in one router (`--models-max` is a global count; the
`--models-preset-only` flag is [PR #24434](https://github.com/ggml-org/llama.cpp/pull/24434),
not merged upstream). Implemented:

- **`llama.service` (GPU router, port 2001)**: preset `/usr/local/etc/config.ini` (6 GPU
  models), `--models-max 1`. Verified: requesting gemma-26b while qwen38 was loaded evicted
  qwen38 (one model resident, VRAM ~14.9 GiB).
- **`llama-cpu.service` (CPU router, port 2002, new unit)**: preset
  `/usr/local/etc/config-cpu.ini` (gpt-oss-120b only), no cap — coexists with the GPU router.
- **Isolation via scoped HF caches** (both routers otherwise auto-discover every cached
  model): `~/.cache/hf-gpu/hub` (symlinks to the 6 GPU model dirs) and `~/.cache/hf-cpu/hub`
  (symlink to gpt-oss-120b), each unit's `HF_HUB_CACHE` pointed at its scope. The real store
  `~/.cache/huggingface/hub` stays the master (backup via `backup.sh`); downloads through a
  symlink land in the real store. New models must be symlinked into the relevant scope.

## Client impact

- DSH/aider/llama.vscode: CPU models (gpt-oss-120b) now live at `http://beast.lan:2002/v1`
  (provider `beast-cpu`); GPU models stay on :2001. Live `~/.dsh/settings.yaml` needs the
  split + removal of coder32/devstral/r1-70b/llama70 ids (repo example updated:
  `sources/config/dsh-settings-beast.example.yaml`).
- `gemma-26b` ctx is 8192 (see records/2026-09-03-03); update any 81920-based expectations.

## Known limits

- `--models-max` has a known TOCTOU race under concurrent first loads (ggml-org/llama.cpp
  issue #20137); sequential use (per router) is fine as verified.
- Reload cost on GPU-model switch: ~15–40 s (page-cache warm).
- qwen38 (111 G) still to be backed up to `/backups/huggingface/`.
