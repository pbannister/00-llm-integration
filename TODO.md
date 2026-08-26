# TODO

## Next Tasks (in order)

The owner's ordering decision (2026-08-26): sort the llama service config first, then the DSH settings.

* [x] 01 — retention analysis written and discard executed 2026-08-26; tuning recommendations drafted in `documents/14-service-tuning-recommendations.md` (aliases, `parallel`, promotions, embeddings preset); MTP benchmark result appended. Owner applies the preset changes and restarts.
* [ ] 02 — refresh the live endpoint captures and re-derive the map/catalog documents (see `prompts/tasks/02-capture-endpoint-facts.md`).
* [ ] 03 — fix the DSH `beast` provider catalog to match the tuned router (aliases or full ids) and verify a request (see `prompts/tasks/03-fix-dsh-provider-catalog.md`).
* [ ] 04 — finish the tool-integration document (aider, llama.vscode, VS Code Chat) (see `prompts/tasks/04-document-tool-integration.md`).
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
