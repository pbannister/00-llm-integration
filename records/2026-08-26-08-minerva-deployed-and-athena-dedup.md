# Record: Minerva deployed; athena service deduped — 2026-08-26

## Outcome

- Deployed llama.cpp to minerva (task 01): built 0.3.0-dev (build 10642) from source with the Vulkan backend, installed, `llama.service` enabled and active on `127.0.0.1:2001`, four presets (`coder3` Q8 default, `qwen4`, `gemma-e2`, `coder15`), RADV device pinned via `GGML_VK_VISIBLE_DEVICES=0`.
- Deduped athena's `llama.service` ExecStart (task 04): the repeated `--chat-template llama3` (4x) reduced to one; service restarted, 15 models up.

## Decisions

- Ubuntu 24.04 build deps: `glslc` + `spirv-headers` (beast's distro uses the `shaderc` package instead); `sudo ldconfig` required after `cmake --install` for the shared-library loader.
- Minerva serves on `127.0.0.1:2001` only (travel laptop; no LAN exposure), matching `documents/11-minerva-travel-plan.md`.

## Verification (2026-08-26)

- `vulkaninfo`: `AMD Radeon 780M Graphics (RADV PHOENIX)` (+ llvmpipe fallback, pinned away).
- `curl http://127.0.0.1:2001/v1/models` on minerva: 6 models listed (4 presets + 2 cache quants).
- Chat completion via `coder3` alias on minerva: answered "OK".
- Athena router: 15 models up after the dedup restart; service file now has one `--chat-template llama3`.

## Open items

- Minerva offline test (WiFi disabled) is left for the user — disabling the interface would drop the SSH session used for deployment.
- TODO 02 (Open WebUI RAG) deferred by the owner.
