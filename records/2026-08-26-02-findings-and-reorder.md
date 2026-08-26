# Record: Findings and task reorder — 2026-08-26

## Outcome

Sorted the project's next steps per the owner's decision: llama service config first, then DSH settings.
Documented minerva hardware, the model retention analysis, and the MTP/RAG position.

## Decisions

- Ordering: task 01 tunes the llama.cpp service configs on beast and athena; task 03 (DSH provider) runs after aliases are settled there.
- Copilot Chat is suppressed; llama.vscode (0.0.63 installed) replaces it for in-editor chat and agent.
- Discard candidates are noted in `documents/12-model-retention.md`; nothing is deleted without the owner's decision.
- MTP is adopted for gpt-oss-120b after an explicit benchmark confirms it (its 8.42 t/s on CPU already shows the MTP signature).
- RAG stays knowledge-only: the Nomic embeddings preset is enabled in task 01; Open WebUI RAG comes later if wanted.

## Findings

- Minerva (verified 2026-08-26): Ubuntu 24.04.4, Ryzen 7 7840U + Radeon 780M iGPU (shared memory), 14 GB RAM, 935 GB disk, no llama.cpp yet.
- Minerva SSH: `ssh -i ~/.ssh/keys/key-athena preston@minerva.lan` works; no `Host minerva.lan` block in `~/.ssh/config` yet (open question in TODO).
- Beast runs llama.cpp build 10628 with `--spec-type` including `draft-mtp`; athena runs build 10129.
- Both routers list far more models than the presets (cache entries); retention analysis identifies the redundant/roleless ones.

## Verification

- `make test` passes (structure, config validation, live captures).
- Live router captures refreshed 2026-08-26 into `dataflow.in/endpoints/`.

## Commits

- (pending) task reorder + findings documents.
