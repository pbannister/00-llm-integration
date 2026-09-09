
## TASK-DESCRIPTION
Reconcile the DeepSeek Harness `beast` provider with the live router and verify one request end to end.

Inspect `sources/config/dsh-settings-beast.example.yaml` and the latest `dataflow.in/endpoints/beast-models.json`.

Update `sources/config/dsh-settings-beast.example.yaml` so that:

- Every model `id` matches a router model id exactly, or is documented as an alias that must be configured on the router (`alias = <name>` in the beast preset).
- Every entry carries `contextWindow` matching the preset `ctx-size` from the capture and a `maxTokens` well under it.
- No bare id-only entries remain (they inherit 262144/32768 defaults that exceed every preset).
- The `compat` block stays as `supportsDeveloperRole: false` and `maxTokensField: max_tokens`.
- A comment lists the models recommended for agent/editing work, for reasoning Q&A, and for background CPU work.

Verify the current `~/.dsh/settings.yaml` against this example and record the concrete differences as a checklist in `records/2026-08-26-02-dsh-provider-findings.md` (create it): ids that do not match the router, capacities that exceed presets, and the missing `BEAST_API_KEY` credential. Do not modify `~/.dsh/settings.yaml`; the human applies the fix.

If the router is reachable, run one chat completion against the beast router with a coder model to confirm the endpoint answers, and record the result in the findings record.

## TASK-OUTPUT
Provide a summary: files created or modified, the count of model entries in the example, and the verification result of the live request.
No commentary beyond the summary.

## TASK-CONTEXT
The DSH `llm-pi-ai` adapter re-reads the settings section per request; no restart is needed.
Credentials resolve from `apiKeyEnv` through process environment, `~/.dsh/.credentials.yaml`, then `.env` files.
Feature requirements: `prompts/features/02-dsh-provider-integration.md`, `prompts/features/01-endpoints-and-models.md`.

## TASK-FILES
- `sources/config/dsh-settings-beast.example.yaml` — existing; modify.
- `records/2026-08-26-02-dsh-provider-findings.md` — new.
- `dataflow.in/endpoints/beast-models.json` — existing; inspect only.
