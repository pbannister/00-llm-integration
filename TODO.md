# TODO

## Next Tasks (in order)

* [ ] 01 — capture endpoint facts: refresh `dataflow.in/endpoints/` captures, derive the catalog tables, and write `documents/07-endpoints-map.md` and `documents/08-model-catalog.md` (see `prompts/tasks/01-capture-endpoint-facts.md`).
* [ ] 02 — fix the DSH `beast` provider catalog: reconcile model ids and capacities with the live router, set `BEAST_API_KEY`, and confirm a beast model answers in DeepSeek Harness (see `prompts/tasks/02-fix-dsh-provider-catalog.md`).
* [ ] 03 — document tool integration: aider local-model usage, llama.vscode, and VS Code Chat options in `documents/09-tool-integration.md` (see `prompts/tasks/03-document-tool-integration.md`).
* [ ] 04 — plan the minerva offline laptop: discover hardware, pick a small model, and draft the install/usage path (see `prompts/tasks/04-plan-minerva-offline.md`).

## Open Questions

* [ ] Decide whether `beast` router presets get short aliases (`alias = coder32`) for client friendliness, or clients use full router ids.
* [ ] Decide whether the DSH `beast` provider should list every router model or only the curated set with correct capacities.
* [ ] Decide where VS Code Chat fits: GitHub Copilot BYOK vs third-party gateway extensions vs skipping it in favor of llama.vscode/Cline/Roo.
* [ ] Minerva hardware specs are unknown; confirm GPU/RAM before choosing the travel model.
* [ ] Confirm the live `config.ini` locations on both hosts (`/usr/local/etc/config.ini`) versus the imported `~/models/config-*.ini` copies, which are older.

## Recently Completed

* [x] 2026-08-26 — project created from `00-project-skeleton`; imported `~/models/` reference material; captured both live router model lists.
