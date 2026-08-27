# TODO

## Next Tasks (in order)

* None open as of 2026-08-26. Item 02 (Open WebUI RAG) was closed by decision:
  the owner does not plan to try it for now. Item 03 (KV-cache quantization)
  was applied 2026-08-26.

## Open Questions

* None open as of 2026-08-26.

## Completed

* [x] 2026-08-26 — project created from `00-project-skeleton`; imported `~/models/` reference material; captured both live router model lists.
* [x] 2026-08-26 — minerva hardware discovered (Ryzen 7 7840U + Radeon 780M, 14 GB RAM, Ubuntu 24.04.4); SSH works with key-athena.
* [x] 2026-08-26 — benchmark reviewed; gpt-oss-120b at 8.42 t/s on CPU (MTP signature); retention analysis written; MTP/RAG documented.
* [x] 2026-08-26 — approved discard executed on beast and athena (28→13, 32→15 models); minerva travel models loaded from athena.
* [x] 2026-08-26 — llama.cpp rebuilt to 0.3.0-dev on both hosts; version review recorded; `cache-reuse = 256` applied.
* [x] 2026-08-26 — tuning applied to both routers: aliases, `parallel = 4`, four GPU preset promotions, Nomic embeddings preset verified (task 01); captures refreshed (task 02).
* [x] 2026-08-26 — DSH `llm-pi-ai` section applied to `~/.dsh/settings.yaml` (beast 11 + athena 6 models, alias ids, correct capacities); `BEAST_API_KEY`/`ATHENA_API_KEY` set (task 03).
* [x] 2026-08-26 — `documents/09-tool-integration.md` completed with router aliases, the three VS Code Chat options, and the llama.vscode decision (task 04).
* [x] 2026-08-26 — `documents/11-minerva-travel-plan.md` finalized with exact GGUF files/sizes, build-and-serve steps, and the offline checklist (task 05).
* [x] 2026-08-26 — retention, MTP, RAG, live-config-location, and minerva-access open questions closed.
* [x] 2026-08-26 — Copilot extension (`ms-azuretools.vscode-azure-github-copilot` 1.0.231) removed from athena; llama.vscode switch complete.
* [x] 2026-08-26 — `Host minerva.lan` block added to `~/.ssh/config` (key-athena); `ssh minerva.lan` verified.
* [x] 2026-08-26 — minerva deployed: llama.cpp 0.3.0-dev built with Vulkan, `llama.service` on `127.0.0.1:2001`, `coder3` verified (task 01).
* [x] 2026-08-26 — athena `llama.service` deduped (4x → 1x `--chat-template llama3`), 15 models up (task 04).
* [x] 2026-08-26 — KV-cache quantization applied: q8_0 K+V common on both routers, q4_0 V on gemma-26b/gemma-12b; memory/spill analysis recorded (task 03).
* [x] 2026-08-26 — Open WebUI RAG (item 02) closed by decision: not pursued for now.
* [x] 2026-08-26 — project pages built (`make site`, sanitized for the publish gate) and published via the homelab project.
