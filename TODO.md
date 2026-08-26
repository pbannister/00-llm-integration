# TODO

## Next Tasks (in order)

The owner's ordering decision (2026-08-26): sort the llama service config first, then the DSH settings.

* [x] 01 — complete: retention + discard executed; tuning recommendations APPLIED 2026-08-26 (aliases, `parallel = 4`, four GPU preset promotions, Nomic embeddings preset verified via `/v1/embeddings`); MTP benchmark confirmed gpt-oss native head (9.3 t/s), no config needed.
* [x] 02 — captures refreshed 2026-08-26 with the tuned routers (13 beast / 15 athena); map/catalog docs updated.
* [x] 03 — complete: DSH `llm-pi-ai` section applied to `~/.dsh/settings.yaml` (beast 11 + athena 6 models, alias ids, correct capacities); `BEAST_API_KEY`/`ATHENA_API_KEY` set in `~/.dsh/.credentials.yaml`.
* [x] 04 — complete: `documents/09-tool-integration.md` rewritten with router aliases, the three VS Code Chat options and the decision, per-purpose llama.vscode models, and version-dependent vs stable notes (verified 2026-08-26).
* [x] Apply `cache-reuse = 256` to `[*]` on both hosts (applied 2026-08-26, verified).
* [x] 05 — complete: `documents/11-minerva-travel-plan.md` finalized with exact GGUF files/sizes on minerva, build-and-serve steps, and the offline checklist (verified 2026-08-26). Deployment itself is a follow-up.

## Open Questions

* [x] Owner reviewed retention 2026-08-26: question closed. The approved discard was executed; the leftover quants on athena (`Qwen2.5-Coder-1.5B/3B` Q4_K_M cache quants, unused `ggml-org` 1.5B repo) are kept as-is by decision.
* [x] MTP — resolved 2026-08-26: gpt-oss-120b auto-uses its native MTP head (9.3 t/s measured via scratch server; explicit `draft-mtp` needs a separate drafter and fails on gpt-oss); other families: EAGLE-3/ngram are optional experiments, not adopted (see `records/2026-08-26-05-version-review.md`, `documents/13-mtp-and-rag.md`).
* [x] RAG — resolved 2026-08-26: embeddings preset enabled and verified (`/v1/embeddings` returns 768-dim via `nomic-embed`); purpose documented (`documents/13-mtp-and-rag.md`). Standing up Open WebUI RAG remains an optional future choice.
* [x] `Host minerva.lan` block added to `~/.ssh/config` (key-athena); `ssh minerva.lan` verified 2026-08-26.
* [x] Live config locations confirmed 2026-08-26: `/usr/local/etc/config.ini` on both hosts (edited, backed up, restarted this session); the imported `~/models/config-*.ini` copies are older snapshots (see `documents/12-model-retention.md`).
* [x] VS Code: Copilot extension (`ms-azuretools.vscode-azure-github-copilot` 1.0.231) removed from athena 2026-08-26; llama.vscode switch complete.

## Recently Completed

* [x] 2026-08-26 — project created from `00-project-skeleton`; imported `~/models/` reference material; captured both live router model lists.
* [x] 2026-08-26 — minerva hardware discovered (Ryzen 7 7840U + Radeon 780M, 14 GB RAM, Ubuntu 24.04.4); SSH works with key-athena.
* [x] 2026-08-26 — benchmark reviewed; gpt-oss-120b at 8.42 t/s on CPU (MTP signature); retention analysis written; MTP/RAG documented.
* [x] 2026-08-26 — approved discard executed on beast and athena (28→13, 32→15 models); minerva travel models loaded from athena.
* [x] 2026-08-26 — llama.cpp rebuilt to 0.3.0-dev on both hosts; version review recorded (`records/2026-08-26-05-version-review.md`); `cache-reuse = 256` recommended but not yet applied.
