# LLM Integration — MOVED

**This repository is archived. The project moved to the homelab.**

Merged 2026-11-24 into `00-homelab` (`github.com/pbannister/00-homelab`),
under `sources/projects/llm-integration/`.

The routers, model catalog, and client configuration are homelab
infrastructure. The homelab already owned the inventory, the Ansible tooling,
and the publishing path, so keeping the LLM work separate meant the inventory
and the deployment drifted apart. The merge puts them in one place.

## Where things are now

| What | New location |
|---|---|
| Documents | `sources/projects/llm-integration/documents/` |
| Service driver and scripts | `sources/projects/llm-integration/scripts/` |
| Tracked presets and client config | `sources/projects/llm-integration/sources/` |
| Tests | `sources/projects/llm-integration/tests/` |
| Records | `sources/projects/llm-integration/records/` |
| Endpoint captures | `sources/projects/llm-integration/dataflow.in/endpoints/` |

The four shared-skeleton documents (`00-pattern-of-interaction.md`,
`01-async-worktree.md`, `02-tool-universe.md`, `03-conversation-summary.md`)
live in the homelab's own `documents/` directory. The project-pages summary
was dropped in favour of the homelab's canonical
`documents/09-project-pages-conventions.md`.

## Commands

Run from the homelab repository root:

```sh
make llm-test                 # the project's own tests
make llm-site                 # build the project pages
make llama-service-dry-run    # check all three routers, change nothing
make llama-service            # install/configure all three routers
make backup-models            # archive model caches to /backups
```

## Why archived rather than deleted

The history is real and worth keeping: the router fixes, the model review, the
measured benchmarks, and the incidents behind them. The homelab is the working
copy; this repository is the record of how the work got there.

Do not resume work here. Open the homelab instead.
