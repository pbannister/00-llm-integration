# Record: Copilot extension removed — 2026-08-26

## Outcome

Removed the GitHub Copilot-related VS Code extension from athena, completing the llama.vscode switch (decision from `documents/09-tool-integration.md`).

## What happened

- Removed `~/.vscode/extensions/ms-azuretools.vscode-azure-github-copilot-1.0.231-linux-x64/` (directory deletion; the `code` CLI could not run under the sandbox due to snap confinement).
- `github.vscode-github-actions` was left in place (unrelated to Copilot).
- Verified: no `*copilot*` extension directories remain; `ggml-org.llama-vscode-0.0.63` intact; no stale `.obsolete` entry.

## Verification

- 2026-08-26: `ls ~/.vscode/extensions | grep -i copilot` → empty.
