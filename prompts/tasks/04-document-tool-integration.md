
## TASK-DESCRIPTION
- Create: `documents/09-tool-integration.md`
- Modify: `documents/08-model-catalog.md`

Write the tool-integration document.

Create `documents/09-tool-integration.md` covering:

- aider against the local routers: the invocation for editing (coder model, `--edit-format whole`) and architect mode (120B planner, coder editor), plus the historical usage note that past sessions used OpenRouter cloud models.
- llama.vscode: remote-server mode against the local routers, with per-purpose model recommendations (completion, chat, agent, embeddings) drawn from `documents/08-model-catalog.md`.
- VS Code Chat: the three options (GitHub Copilot BYOK with an OpenAI-compatible base URL, third-party gateway extensions, or skipping Chat in favor of llama.vscode/Cline/Roo), with the recommendation that overlapping agent UIs not run on the same project simultaneously.

Mark the document `verified 2026-08-26` and note which facts are version-dependent (extension versions, flags) versus stable.

Do not modify any file outside `documents/09-tool-integration.md`.

## TASK-OUTPUT
Provide a summary of the created document and its section list.
No commentary beyond the summary.

## TASK-CONTEXT
Feature requirements: `prompts/features/04-aider-and-vscode.md`.
Model ids and contexts come from `documents/08-model-catalog.md`; do not restate the catalog independently.
Historical aider usage was observed in the workspace `.aider.*` files (model-router-setup sessions used `openrouter/openrouter/auto` and `openrouter-gpt-4o`).

## TASK-FILES

| Operation | Path |
|---|---|
| create | `documents/09-tool-integration.md` |
| modify | `documents/08-model-catalog.md` |

## TASK-VERIFY
- Run: `make test` from the repository root.
- Expected: exit status 0.

## TASK-FEATURES
- `prompts/features/04-aider-and-vscode.md`

## TASK-ACCEPTANCE
- `AIDER-R001`
- `AIDER-R002`
- `AIDER-R003`

OUTPUT: the content of `documents/09-tool-integration.md`, as TASK-OUTPUT describes, and nothing else.
