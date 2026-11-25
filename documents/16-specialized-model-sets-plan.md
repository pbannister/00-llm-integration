# Specialized Model Sets — Plan

Status: planned 2026-11-24; no set has been downloaded or tested yet.
This document plans three sets of models beyond the router's general catalog.
It records no finding it has not observed.

## Why separate sets

The router serves the whole subnet. A model in a preset is visible to every
client, and a model in the cache is visible even without a preset. That is right
for general work and wrong for three narrower needs:

- **Direct-use small models** for a single project or script, invoked in-process
  or on a loopback port, where the router's shared state is a liability.
- **Speech** models, which answer a different request shape (audio in, text or
  audio out) and do not belong in a chat router.
- **Vision** models, which need an image or video frame in the request.

Each set gets its own storage and its own launch path, so it does not appear in
the router's `/v1/models` and does not compete for the router's VRAM.

## Set 1 — Direct-use small models

### Purpose

A handful of small models to call directly from a project: a shell script, a
Python helper, a notebook. The caller starts a model on a loopback port, uses it,
and stops it. No router, no preset, no shared cache.

### Constraints

- Each model must fit comfortably in 8 GB so it runs on athena's GPU and on
  minerva's iGPU.
- Startup must be fast enough that starting and stopping per call is practical.
- Storage is per-set: a dedicated directory, not the router's scoped cache.

### Candidates to evaluate

The cache already holds several small models that fit this role; the review
should test them before downloading anything new:

- `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` — coding and editing, FIM-capable.
- `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` — the same, more capable.
- `unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0` — general chat, tool calls verified.
- `unsloth/gemma-4-E4B-it-qat-GGUF:Q4_K_XL` — small, capable, and already
  supports image and audio input.
- `unsloth/Qwen3.5-2B-GGUF:Q4_K_M` and `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` — small
  general chat.

### Open questions

- Which models repay a direct call rather than a router call? A model that is
  already a router preset may not need a second path.
- Should the set share one directory with the travel laptop's models, or keep a
  separate one per host?

## Set 2 — Speech

### Purpose

Spoken interaction: speech in, and either text or speech out. The use case is
talking to the machine, not typing at it.

### What the current stack can do

- `gemma-4-E4B-it-qat` advertises `audio` input in `/v1/models`, and its
  projection file is cached. The athena preset now names `mmproj`, so audio
  input reaches the model. Whether the model transcribes speech well is not yet
  measured.
- llama.cpp has no speech-to-text or text-to-speech server mode in the router.
  A speech pipeline is a separate program that calls the model, or a separate
  engine.

### Candidates to evaluate

The candidates are now measured and the recommendation is recorded in one place:
`documents/18-voice-and-speech-models.md` (verified 2026-11-24). That document
is the authority for which speech models to use; this section points at it and
does not restate its numbers.

- **Text to speech:** Kokoro-82M by default (270 MB, 2.5x realtime on CPU);
  Qwen3-TTS-1.7B where quality matters more than latency. Both run inside
  llama.cpp, through `llama-tts` or `/v1/audio/speech`.
- **Speech to text:** the `gemma-4-E4B` audio input already served by the athena
  router; 0.25 s warm, accurate on measured round trips.
- **Speech-capable LLMs:** the gemma family is the candidate already present.

### Open questions

- How does a travelling project recognise speech with no LAN access? The laptop
  has no local recogniser cached yet; the recommendation document marks this
  `unverified`.
- The "does speech need the CPU?" question is answered for the models measured:
  the GPU added nothing to Kokoro and did not make Qwen3-TTS realtime. It stays
  open only for a model that has not been measured.

## Set 3 — Vision

### Purpose

Visual input from a webcam: an image or a frame goes into the model, and the
answer comes back as text.

### What the current stack can do

- Athena's `gemma-e4` preset now names its cached `mmproj`, and an image was
  accepted and described through the live router on 2026-11-24. This is the
  working baseline.
- Beast's `gemma-12b` advertises `image` input but has no `mmproj` in its preset.
  Adding one needs a projection file and enough VRAM; the MI25 could not load
  the 12B projection at a usable context on 2026-11-24.
- `gemma-4-E4B-it-qat` and `gemma-4-12B-it-qat` both advertise `image`; the
  `mmproj` file is what makes the claim true.

### Candidates to evaluate

- The cached gemma models with their projection files, at a context that fits
  each host.
- A smaller vision model if the gemma projection is too large for the MI25.
- Whether webcam capture should send a single frame per request or a short
  sequence; the answer changes the context budget.

### Open questions

- Which host serves webcam vision: athena's GPU, or beast's MI25?
- Does the webcam path need a frame every second, or one frame on request? The
  first is a streaming problem the router does not solve.

## Storage and isolation

- Each set uses its own directory, named for the set, not the router's scoped
  cache. A model in the router's cache is visible to clients; a set's models are
  not.
- A set's models are launched by the set's own script on a loopback port.
- The router's cache is not the place for a set's models, because the router
  advertises everything in its cache.

## Deliverables

1. A criteria file for these sets, or an extension to the model review criteria.
2. One study note per candidate under `documents/`.
3. A synthesis per set: use list and avoid list.
4. A small launch script per set, following the pattern of the FIM server that
   llama.vscode starts.
5. A record of what was downloaded, its size, and where it lives.

## Order

1. Vision first: it works today on athena, so the review can build on a known
   result rather than a claim.
2. Direct-use small models second: the models are already cached, so the review
   is a comparison, not a download.
3. Speech third: it needs a separate engine, so it is the largest piece of work.
