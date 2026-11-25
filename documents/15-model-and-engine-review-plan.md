# Model and Engine Review — Plan

Status: planned 2026-11-24; no review has been run yet.
This document plans the review. It records no finding it has not observed.

## Why now

The preset set was last reviewed 2026-08-26 and tuned 2026-09-03. Since then the
service has drifted in ways that only showed up in use: a preset key named a
quant that was not on disk, the athena router split its context four ways, and a
model the policy rejected stayed listed. The catalog needs a scheduled review
rather than another incident-driven fix.

## What the review covers

1. New models and new versions of existing models.
2. New or updated engines for running models (llama.cpp first, then others).
3. Whether to run engines other than llama.cpp.
4. Whether the set of downloaded local models should change.
5. A set of small models for direct project use (not through the router).
6. Models well suited to spoken interaction.
7. Models well suited to visual input from a webcam.

## Constraints the review works within

- `beast.lan`: MI25 16 GB VRAM, dual Xeon, 256 GB RAM. The MI25 has no working
  flash-attention path for these presets, so `flash-attn = false` and
  `cache-type-v = f16` are the stable settings.
- `athena.lan`: RX 5500 XT 8 GB VRAM, Ryzen 9 5900X, 128 GB RAM. The GPU is the
  smallest of the three, so it hosts small models and fallbacks.
- `minerva.lan`: Radeon 780M iGPU, 14 GB shared RAM. The travel laptop; runs one
  small model on `127.0.0.1:2001`.
- Clients are OpenAI-compatible: DSH, aider, llama.vscode, VS Code Chat. A
  candidate that only speaks a proprietary protocol needs a proxy before it
  counts as usable here.
- The router reads `/v1/models` from the preset and from the scoped cache. A
  model in either place is visible to clients, so the review must decide both
  what is in the preset and what is in the cache.

## Method

Follow `prompts/how-to-write-research.md`: one criteria file, one study per
candidate, one synthesis. The criteria file is the authority for the comparison;
the studies do not change it.

### Proposed criteria file

`prompts/common/04-model-review-criteria.md`, covering for each candidate:

- Role: interactive chat, agent loop, inline completion, long-context, small
  direct-use, speech, or vision.
- Fit: parameters, quant, size on disk, VRAM or RAM needed, and the host it fits.
- Tool calls: whether it emits parsed `tool_calls` (measured, not claimed).
- Context: trained context, and the practical context on the host after KV cache.
- Licence: whether the licence permits local and commercial use.
- Evidence: a primary source URL, and a measured number where one exists.
- Verdict: keep, add, or drop, with the reasoning.

### Study order

1. **Engine review.** Compare llama.cpp builds and the alternatives that matter
   for these hosts. See "Engines" below.
2. **New and updated models.** Sweep the model families already in the catalog
   for newer versions, then consider families not represented.
3. **Direct-use small models.** A set intended to be invoked directly in
   projects, not through the router.
4. **Speech models.** For spoken interaction.
5. **Vision models.** For webcam input.

Each study is one candidate on one page, using the criteria headings.

## Engines

### llama.cpp

- Pin the build per host and record the commit. The three hosts have drifted:
  beast runs build 10628 in some records and 11193 in others, and athena ran
  12673 at the 2026-11-23 repair. The review should establish one build and one
  upgrade path.
- Track the flags the presets depend on: `--models-preset`, `--tools`,
  `--allow-unauthenticated-tools`, `--models-max`, `--fit`, `--mmproj`, and
  `--cache-type-k/v`. A flag that disappears breaks a preset.
- Note the security change found 2026-11-23: builds from 1.0.0-dev refuse to
  enable server tools on a non-loopback address without
  `--allow-unauthenticated-tools`. That flag is now in all three units.

### Alternatives to consider

- **vLLM** — high-throughput serving, but needs more VRAM than the MI25 offers
  for the models in use, and its hardware support is narrower. Compare only if
  the GPU set changes.
- **Ollama** — easier model management, but its preset control and router
  behaviour are weaker than llama.cpp's, and it duplicates the model store.
- **llamafile** — a single-file distribution; interesting for the travel laptop,
  not for the servers.
- **ExLlamaV2 / TensorRT-LLM** — NVIDIA-oriented; not applicable to these AMD
  hosts.
- **llama.cpp server variants** — the router already covers the multi-model
  need, so the question is version and flags, not a replacement.

The review should state plainly whether any alternative beats llama.cpp on these
three hosts. The default expectation is no, and the review must justify a change
rather than assume one.

## Deliverables

1. `prompts/common/04-model-review-criteria.md` — the criteria file.
2. One study note per candidate under `documents/`.
3. A synthesis that pools the studies into a use list and an avoid list, and
   recommends what to drop.
4. Updates to `documents/08-model-catalog.md` and `documents/12-model-retention.md`
   from the synthesis, not from memory.
5. A refresh of `dataflow.in/endpoints/` after any change lands.

## Open questions this review must answer

- Is the MI25 worth keeping as the interactive GPU, or should the interactive
  tier move to a smaller model on athena's GPU?
- Should beast's CPU router keep the 120B, or is a smaller model fast enough to
  make the 120B's latency unnecessary?
- Which models should be in the cache but not in a preset? The cache is visible
  to clients, so an unused model in the cache is a client-facing risk.
- What is the right build policy when a build changes a flag the presets use?

## Not in scope

- Changing the router deployment mechanics; that is the `make llama-service`
  path and the homelab migration question.
- Re-tuning KV cache quantization; that was settled 2026-08-26.
