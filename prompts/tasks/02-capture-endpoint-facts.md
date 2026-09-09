
## TASK-DESCRIPTION
Refresh the live endpoint captures and derive the endpoints map and model catalog documents.

Run `make capture` from the repository root to refresh `dataflow.in/endpoints/beast-models.json` and `dataflow.in/endpoints/athena-models.json` from `GET /v1/models` on both routers.

Inspect the captures and create these documents:

- Create `documents/07-endpoints-map.md`: hosts, ports, base URLs, hardware, default contexts, and the request flow. Mark the document `verified 2026-08-26` only if the facts come from a capture taken on that date.
- Create `documents/08-model-catalog.md`: for each host, the model list derived from the capture, with the preset `ctx-size` (from each model's `status.args` or `preset`), execution class (GPU-resident or CPU-heavy, from `ngl` in the preset), and the recommended role. Do not hand-type model ids; derive them from the capture.

Do not modify any file outside `dataflow.in/endpoints/`, `documents/07-endpoints-map.md`, and `documents/08-model-catalog.md`.

## TASK-OUTPUT
Provide a summary listing each created file and the per-host model counts.
No commentary beyond the summary.

## TASK-CONTEXT
The endpoints are `http://beast.lan:2001/v1` and `http://athena.lan:2001/v1`.
The router response includes per-model `status.args` and `preset` text that contain the context size and offload (`ngl`) settings.
Feature requirements: `prompts/features/01-endpoints-and-models.md`.
Generated documents must carry the provenance header rule from `prompts/03-conventions.md` section 6.1 only when a generator produced them; these are hand-written from captures, so they instead carry a `verified <date>` marker per the live-state discipline in `README.md`.

## TASK-FILES
- `scripts/endpoints-capture.sh` — existing; invoked by `make capture`.
- `dataflow.in/endpoints/beast-models.json` — existing; refresh via `make capture`.
- `dataflow.in/endpoints/athena-models.json` — existing; refresh via `make capture`.
- `documents/07-endpoints-map.md` — new.
- `documents/08-model-catalog.md` — new.
