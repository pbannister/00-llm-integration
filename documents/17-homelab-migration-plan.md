# Homelab Migration — Plan

Status: planned 2026-11-24; nothing has been moved.
This document plans incorporating `00-llm-integration` into `00-homelab`, and
using Ansible to deploy the services and the shared development configuration.
It records no finding it has not observed.

## Why migrate

The routers, the model catalog, and the client configuration are homelab
infrastructure, not a separate project's concern. They already reach into every
host: three systemd units, three preset files, a scoped cache layout, and client
configuration on athena. The homelab already owns the inventory, the Ansible
setup, and the publishing path. Keeping the LLM work in a separate project means
the inventory and the deployment drift apart.

## What moves, and what stays

### Moves into the homelab

- The service definition: three systemd units (`llama.service` on beast and
  athena, `llama-cpu.service` on beast), their preset files, and the scoped
  cache layout.
- The deployment driver: `scripts/llama-service-install.sh` and its Makefile
  targets.
- The client configuration: the DSH provider section, the llama.vscode settings,
  and the aider configuration.
- The live-state facts: the endpoints map and the model catalog, as documents
  the homelab owns.

### Stays in `00-llm-integration`

- The project's own rules, prompts, and records. The rules are pinned to
  `00-project-rules`; moving them changes the pin.
- The generated pages and the publishing path. The homelab already publishes
  this project's pages through `pages_source`.
- The research and review documents (`15-model-and-engine-review-plan.md`,
  `16-specialized-model-sets-plan.md`), until the review settles.

The split is: the homelab owns the deployment, and this project owns the model
work. A model review changes presets, not units.

## Ansible scope

### What Ansible should own

- The three router units and their environment files. Today the units are
  hand-edited and the driver renders them; Ansible should render the same units
  from templates so the desired state is in one place.
- The preset files. The presets are the part that changes most often, so they
  should be templated from the project's `sources/config/*.applied.ini` rather
  than copied by hand.
- The scoped cache layout: the directories and the symlinks that decide which
  model is visible to which router. This is exactly the mechanism that made
  `qwen38` visible after its preset was removed.
- The client configuration on athena: the DSH provider file, the llama.vscode
  settings, and the aider configuration.

### What Ansible should not own

- The model downloads. They are large, slow, and change rarely; a play that
  downloads a 40 GB model is not a play anyone wants to run on every deploy.
  The play should check that a model is present and report a missing one, not
  fetch it.
- The llama.cpp build. The build is a one-off per host with a long compile time.
  The play should verify the installed build and its flags, and fail when the
  build lacks a flag the presets need.

### The shared development configuration

The client configuration is the part that should be common across hosts. The
homelab's inventory already names `athena.lan` and `beast.lan`; a group variable
can hold the router addresses and the model aliases, and each host's client
configuration can render from it. That removes the current duplication where the
same provider section is written by hand in more than one place.

## Proposed Ansible layout

```
sources/plays/
  llm-service.yaml          # the three units and their environment files
  llm-presets.yaml          # the preset files, rendered from the project
  llm-client-config.yaml    # the DSH, llama.vscode, and aider configuration
sources/inventory/group_vars/
  llm_servers.yaml          # router addresses, ports, and model aliases
sources/roles/
  llm_service/              # templates for the units and the preset files
  llm_client/               # templates for the client configuration
```

The plays live with the homelab's other plays, so one inventory and one
`ansible.cfg` govern them.

## Migration steps

1. **Freeze the current state.** Capture the units, the presets, and the client
   configuration from all three hosts, and commit them. The capture is the
   reference the Ansible templates must reproduce.
2. **Write the role templates.** Start with the units and the presets. Run the
   play in check mode against the live hosts and confirm it reports no change.
   A play that reports a change means the template does not match the host.
3. **Move the driver.** Point the Makefile's `llama-service` targets at the
   Ansible play, or keep the driver as the check and let Ansible do the render.
   The driver's checks — reachability, preset keys, a scratch-port dry run — are
   worth keeping either way.
4. **Add the client configuration.** Template the DSH provider section and the
   llama.vscode settings from the group variables.
5. **Retire the duplicate.** When the play reproduces the state, remove the
   hand-edited copies and record the change.
6. **Update the registry.** The homelab's `sources/projects.yaml` already lists
   `llm-integration` with `parent: llm-server`. The migration should decide
   whether it stays a project with its own pages or becomes part of the
   `llm-server` project.

## Risks

- **The cache is the fragile part.** The scoped cache decides what each router
  advertises. Ansible should own it explicitly, or a model will reappear after a
  preset change, which is the failure this plan exists to prevent.
- **The driver and Ansible can disagree.** Two tools that both render the units
  will drift. Pick one owner for the render and keep the other as a check.
- **The build is not reproducible yet.** The hosts run different llama.cpp
  builds. Ansible cannot pin a build it does not build; the build policy has to
  be settled first, in the model and engine review.
- **Client configuration is per-user.** The DSH settings live in a user's home
  directory. Ansible can template them, but the user may also edit them by hand;
  the play needs a way to tell a managed file from a hand edit.

## Open questions

- Does the LLM integration become a homelab project, or a subproject of
  `llm-server`? The registry already nests it under `llm-server`.
- Should the preset files stay in this project's repository and be rendered into
  the homelab, or move into the homelab outright?
- Which tool owns the unit render: Ansible or the existing driver?
- Does the homelab want the model review documents, or should they stay here?

## Order

1. The model and engine review (`15-model-and-engine-review-plan.md`) settles the
   build policy and the preset set. Migrating a set that is still changing
   migrates a moving target.
2. The migration follows, with the cache layout as the first thing Ansible owns.
