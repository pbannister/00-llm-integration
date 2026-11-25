# Model Review Criteria

Status: established 2026-11-24 for the model and engine review.
This file is the authority for the review. A study compares against it and does
not modify it; revisions are recorded in the changelog at the end.

## How a study uses this file

Each candidate gets one study note under `documents/`, using the headings below
in this order. A candidate that cannot answer a heading records the reason
rather than leaving it blank. A claim with no source is marked `unverified`;
the marking carries forward into the synthesis and is never upgraded.

## Headings a study must use

### Role

One of: interactive chat, agent loop, inline completion, long-context, small
direct-use, speech, or vision. A candidate may hold more than one role; name the
primary one first.

### Fit

Parameters, quant, size on disk, and the VRAM or RAM needed to hold it. State
which host it fits and at what context. Use the measured size from the cache
where the model is already downloaded, not the model card's figure.

### Tool calls

Whether the model emits parsed `tool_calls` through the router. This is measured
by sending a request with a tool definition and reading the response; a model
card's claim is not evidence. Record the measurement date.

### Context

Trained context, and the practical context on the host after the KV cache. The
router divides a preset's `ctx-size` by its `parallel`, so a preset at 16384 with
`parallel = 1` gives 16384 per request.

### Licence

The licence, read from the model card. State whether it permits local use and
commercial use.

### Evidence

A primary source URL for each claim, and a measured number where one exists.
Name the command or request that produced a measurement, so a later session can
repeat it.

### Verdict

One of: keep, add, or drop. State the reasoning in one or two sentences. A drop
recommendation names what replaces the candidate.

## Comparison rules

- Throughput is measured warm: a first request loads the model, so a study
  discards the first request and measures the second. A cold number is recorded
  as a load time, not as throughput.
- A comparison between hosts uses the same model and the same prompt. A
  comparison across different models states that it is not like-for-like.
- GPU residency is stated explicitly. A model loaded without `--n-gpu-layers`
  runs on the CPU even when the host has a GPU, and the router reports the
  argument list in `/v1/models`.
- A model in the cache but not in a preset is still advertised by the router.
  The study records whether the candidate is in the preset, in the cache, or
  both.

## Host constraints

- `beast.lan`: AMD Instinct MI25 16 GB VRAM, dual Xeon without AVX2 or FMA, 256
  GB RAM. No working flash-attention path for these presets, so `flash-attn =
  false` and `cache-type-v = f16` are the stable settings. The host also has a
  GTX 1050; the service selects the MI25 with `GGML_VK_VISIBLE_DEVICES=1`, because
  device 0 is the GTX 1050.
- `athena.lan`: RX 5500 XT 8 GB VRAM, Ryzen 9 5900X, 128 GB RAM. It is a
  desktop host, so the GUI and browser compete for the GPU.
- `minerva.lan`: Radeon 780M iGPU, 14 GB shared RAM. The travel laptop.

## Changelog

- 2026-11-24: established. The headings above are the initial set.
