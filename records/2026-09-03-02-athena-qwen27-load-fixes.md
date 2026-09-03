# Record: athena qwen3_5/qwen27 load fixes — source sync to 10802, repo mix-up, VRAM contention — 2026-09-03

## Outcome

`qwen27` (batiai Qwen3.8-27B Q4_K_M, GPU+CPU preset) now loads and serves through athena's router (~31 s first load, verified "OK"). Also fixed: qwen3_5-arch models failed to load on athena's intermediate builds.

## Three confounded causes (in order of discovery)

1. **athena build regression (qwen3_5 arch)** — builds 10776 (`2d7523fa7`) and 10788 (`ea88ec9b0`) hung loading *any* `qwen3_5`-arch model (qwen27, qwen3.5-2B/4B/9B), while llama3 (llama arch) loaded fine and beast's build loaded qwen3.5-9B in ~5 s. Fix: synced athena's `~/sources/llama.cpp` to beast's source lineage (`dfc95c594` → master at `fbf821916`; the earlier "build 10801" commit was amended into `fbf821916`), rebuilt → **build 10802**, installed, service restarted. athena's previous local commit kept as branch `athena-local-ea88ec9b0`. qwen3.5-9B verified loading (GPU and CPU paths).
2. **Wrong-repo restore** — the 2026-08-26 backup on `/backups/huggingface/` holds `bartowski/Qwen3.8-27B-GGUF`, but the preset (and the model the router resolves) is **`batiai/Qwen3.8-27B-GGUF`**. Restoring bartowski did not help; the batiai files were web-downloaded instead (this download, at WAN speed with 0 % CPU socket-wait, looked like a "hang" during diagnosis). The bartowski working-cache copy was removed (18 G; archive copy untouched).
3. **VRAM contention stalls the fit probe** — with other workers resident (~1–4 GiB free of the 8 GiB RX 5500 XT), a new qwen27 child stalled silently in its `--fit on` probe instead of trimming or erroring. After a service restart (VRAM free) qwen27 loads in ~31 s. Operational constraint: 8 GiB cannot hold qwen27 (resident ~4–5 GiB) together with qwen3.5-9B (~5.5 GiB) or similar; switch large GPU models by idling/unloading or restarting the service.

## Verification (2026-09-03, master-based build)

After moving the ROCm/HIP commits to the `rocm-work` branch, built athena from clean `master` (`768807b89` = origin/master `e107984bc` + the "Local builds." CMakePresets/Makefile commit only) → **build 10789**, installed, service restarted. Confirmed through the router:
- `qwen27` (batiai Qwen3.8-27B Q4_K_M): content "OK", finish stop.
- `unsloth/Qwen3.5-9B-GGUF:Q4_K_M`: content "OK", finish stop (with `max_tokens` large enough to pass the reasoning preamble; the earlier empty `content` was the reasoning output consuming the token budget, not a load failure).

Conclusion: the qwen3_5 loading fix is **upstream** (present in origin/master `e107984bc`) — the local ROCm/HIP commits were never required for it. Athena currently runs the master-based build 10789; beast still runs 10801 (fbf821916-tree) until its next rebuild from master.

## State

- athena: llama.cpp **build 10802** (`fbf821916`), source = beast's lineage; 17 models listed; qwen27 preset registered and verified.
- Cache note: athena working HF cache ~89 G; `models--batiai--Qwen3.8-27B-GGUF` present (web-downloaded); `bartowski` copy removed.
- beast unchanged (10801/`dfc95c594` installed; source master `fbf821916`).
