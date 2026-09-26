# Phases

Project work proceeds in numbered phases. A phase is a milestone that
groups one or more episodes (the reviewable work units; see
`prompts/how-to-write-episodes.md` §9 and the homelab project-pages
conventions `documents/09-project-pages-conventions.md` §6).

**Change the current phase only when committing the project** (owner rule
2026-08-26): the phase belongs to this project, not to the homelab
registry. The homelab reads it from the generated `site.out/phase.txt`
(emitted by `scripts/site-condense.sh` from the `Current:` line below) and
shows it next to the activity status (active/planned/deferred/complete),
which the human declares in the homelab registry.

Current: phase 2 — started

- Phase 1 — initial integration: router tuning (aliases, parallel, cache reuse, KV quant), model catalog and retention, DeepSeek Harness providers, tooling docs, travel-laptop deployment — complete
- Phase 2 — usage and hardening: retrieval-augmented chat UI (deferred by decision 2026-08-26), agent workflow tuning, further benchmarking — started 2026-09-25 (MI25 inference benchmarks, `records/2026-09-21-01-mi25-inference-benchmarks.md`); phase 2 was declared started by the owner on 2026-09-25

States: `not-started` | `started` | `complete`. Keep this file in sync
with the episodes that advance each phase and with `TODO.md`.
