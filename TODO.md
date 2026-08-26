# TODO

## Next Tasks (in order)

The owner's ordering decision (2026-08-26): sort the llama service config first, then the DSH settings.

* [x] 01 — complete: retention + discard executed; tuning recommendations APPLIED 2026-08-26 (aliases, `parallel = 4`, four GPU preset promotions, Nomic embeddings preset verified via `/v1/embeddings`); MTP benchmark confirmed gpt-oss native head (9.3 t/s), no config needed.
* [x] 02 — captures refreshed 2026-08-26 with the tuned routers (13 beast / 15 athena); map/catalog docs updated.
* [x] 03 — DSH provider: example updated to router aliases with matching capacities; findings recorded (`records/2026-08-26-02-dsh-provider-findings.md`); `coder32` alias verified live. The human applies the corrected section to `~/.dsh/settings.yaml` (or asks the assistant to).
* [ ] 04 — finish the tool-integration document (aider, llama.vscode, VS Code Chat) (see `prompts/tasks/04-document-tool-integration.md`).
* [ ] Apply `cache-reuse = 256` to `[*]` on both hosts (owner decision; see `records/2026-08-26-05-version-review.md`).
* [ ] 05 — finalize the minerva offline plan (hardware discovered 2026-08-26; see `prompts/tasks/05-plan-minerva-offline.md` and `documents/11-minerva-travel-plan.md`).

## Open Questions

* [ ] Owner reviews `documents/12-model-retention.md` and decides which discard candidates to remove (nothing is deleted without the decision).
* [ ] MTP: confirm the gpt-oss-120b speedup with `llama-bench --spec-type none` vs `draft-mtp`; adopt drafters for other families only where they help.
* [ ] RAG: enable the Nomic embeddings preset (task 01); decide later whether to stand up Open WebUI RAG.
* [ ] Add a `Host minerva.lan` block to `~/.ssh/config` (key-athena works) so Ansible and SSH use it cleanly.
* [ ] Confirm the live `config.ini` locations on both hosts (`/usr/local/etc/config.ini`) versus the imported `~/models/config-*.ini` copies, which are older.
* [ ] VS Code: disable/uninstall the Copilot extension (`ms-azuretools.vscode-azure-github-copilot` on athena) to finish the llama.vscode switch.

## Recently Completed

* [x] 2026-08-26 — project created from `00-project-skeleton`; imported `~/models/` reference material; captured both live router model lists.
* [x] 2026-08-26 — minerva hardware discovered (Ryzen 7 7840U + Radeon 780M, 14 GB RAM, Ubuntu 24.04.4); SSH works with key-athena.
* [x] 2026-08-26 — benchmark reviewed; gpt-oss-120b at 8.42 t/s on CPU (MTP signature); retention analysis written; MTP/RAG documented.
* [x] 2026-08-26 — approved discard executed on beast and athena (28→13, 32→15 models); minerva travel models loaded from athena.
* [x] 2026-08-26 — llama.cpp rebuilt to 0.3.0-dev on both hosts; version review recorded (`records/2026-08-26-05-version-review.md`); `cache-reuse = 256` recommended but not yet applied.
