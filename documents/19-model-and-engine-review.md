# Model and Engine Review — Survey and Synthesis

Status: reviewed 2026-11-24. Every number below was measured on that date on the
named host; the command that produced it is given so a later session can repeat
it. Claims that no measurement supports are marked `unverified`.
Criteria: `prompts/11-model-review-criteria.md`.

## Method

Throughput is measured warm: the first request loads the model, so each
measurement sends a warm-up request and then measures a second 60-token
completion. The prompt is "Write a Python function that returns the sum of a
list." with `temperature` 0. The measurement is a `POST` to
`/v1/chat/completions` and the figure is `completion_tokens / wall seconds`.
A cold figure is reported as a load time, not as throughput.

## Host baseline measured 2026-11-24

| Host | GPU | Build | State |
|---|---|---|---|
| `beast.lan` | MI25 16 GB, GTX 1050 idle | 1.0.0-dev 12721, `b12690-31-g56726d81c` | active, 5 models, 0 restarts |
| `athena.lan` | RX 5500 XT 8 GB | 1.0.0-dev 12721, `b12690-31-g7520e8ed7` | active, 15 models, 0 restarts |
| `minerva.lan` | Radeon 780M iGPU | 1.0.0-dev 12729, `b12690-39-g7e44f1b6` | active, 8 models |

The three builds are 31, 31 and 39 commits past tag `b12690`. Beast and athena
are the same build; minerva is 8 commits ahead. This narrows the build-policy
question the review plan raised: the hosts are not scattered across distant
builds, and one build is a realistic target.

## Throughput measured warm 2026-11-24

### beast.lan, MI25 GPU (`:2001`)

| Alias | Model | tok/s |
|---|---|---|
| `gpt-oss-20b` | `unsloth/gpt-oss-20b-GGUF:UD-Q4_K_XL` | 36.4 |
| `qwen9` | `unsloth/Qwen3.5-9B-GGUF:Q4_K_M` | 32.4 |
| `gemma-12b` | `unsloth/gemma-4-12B-it-qat-GGUF:Q4_K_XL` | 16.4 |
| `gemma-26b` | `unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL` | 14.8 |
| `coder14` | `bartowski/Qwen2.5-Coder-14B-Instruct-GGUF:Q4_K_M` | 9.2 |

### beast.lan, CPU router (`:2002`)

| Alias | Model | tok/s |
|---|---|---|
| `gpt-oss-120b` | `unsloth/gpt-oss-120b-GGUF:UD-Q4_K_XL` | 9.4 |

### athena.lan, RX 5500 XT (`:2001`)

| Alias | Model | tok/s |
|---|---|---|
| `gemma-e4` | `unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL` | 48.4 |
| `coder15` | `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` | 11.4 |
| `coder3` | `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` | 5.7 |
| `llama3` | `unsloth/Llama-3.2-3B-Instruct-GGUF:Q8_0` | 4.1 |
| `qwen27` | `batiai/Qwen3.8-27B-GGUF:Q4_K_M` | 1.9 |

### minerva.lan, Radeon 780M iGPU (`:2001`)

| Model | tok/s |
|---|---|
| `unsloth/gemma-4-E2B-it-qat-GGUF:Q4_K_XL` | 50.2 |
| `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q8_0` | 45.7 |
| `unsloth/Qwen3.5-4B-GGUF:Q4_K_M` | 24.1 |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF:Q8_0` | 23.5 |

**The laptop is the fastest host measured.** Its 780M iGPU serves a 2B at 50.2
tok/s and a 3B at 23.5 tok/s, while athena's discrete RX 5500 XT serves a 3B at
5.7 tok/s and a 1.5B at 11.4 tok/s. The laptop's figures are like-for-like only
against the same model; the models differ between hosts, so the comparison is
indicative, not exact. The explanation is contention: athena is a desktop host
whose GUI and browser share the 8 GB card, and the router there loads four
models at once without `--models-max`.

### Tool calls measured 2026-11-24

A request carrying one tool definition; the response either contains a parsed
`tool_calls` array or does not.

| Host | Model | `tool_calls` |
|---|---|---|
| beast | `qwen9` | yes |
| beast | `gemma-12b` | yes |
| beast | `gpt-oss-20b` | yes |
| beast | `coder14` | no |
| athena | `llama3` | yes |
| athena | `gemma-e4` | yes |
| athena | `coder3` | no |
| athena | `coder15` | no |

The Qwen2.5-Coder models do not emit parsed tool calls; the Qwen3.5, gemma-4 and
gpt-oss models do. This matches the earlier finding recorded in
`documents/09-tool-integration.md`.

## The cache is visible to clients

The router advertises every model in its cache, not only those in its preset.
This was measured on both hosts by comparing the preset sections against
`/v1/models`.

- **beast:** 5 preset sections, 5 advertised. The two `UD-Q4_K_XL` preset keys
  surface as `Q4_K_XL`, which is the cache quant name; the preset key and the
  advertised id differ, so an alias is the only reliable way to select a model.
- **athena:** 8 preset sections, **15 advertised**. Eight models are visible to
  clients without being configured: `Qwen2.5-Coder-1.5B:Q4_K_M`,
  `Qwen2.5-Coder-3B:Q4_K_M`, `josephmayo/gemma-4-E4B-it-Coder-GGUF:Q5_K_M`,
  `Qwen3.5-2B`, `Qwen3.5-4B`, `Qwen3.5-9B`, `gemma-4-E2B`, and
  `gemma-4-E4B:Q4_K_XL`. A client can select any of them, and each load competes
  for the 8 GB card.

This is the answer to the review's third open question: a model in the cache is
client-facing whether or not it has a preset. Removing a preset does not hide a
model; the cache has to change.

## Speech and vision

The measured speech and vision results are in
`documents/18-voice-and-speech-models.md` and are not repeated here. In summary,
from that document's measurements: Kokoro-82M synthesises speech at 2.5x realtime
on CPU alone, and `gemma-4-E4B` transcribes Kokoro's output accurately with 0.25 s
warm latency. Neither model is in any host's cache today, so both are candidates
to add rather than models already deployed.

## Engines

llama.cpp is the only engine in use. Ollama is installed on both servers and is
inactive on both. The alternatives the review plan listed were not evaluated by
measurement in this review; the plan's expectation was that vLLM's VRAM
requirement exceeds the MI25 for the models in use, that Ollama duplicates the
model store without adding router capability, and that llamafile targets the
travel laptop. Those three statements remain `unverified` here — no measurement
was taken, and the synthesis does not upgrade them.

## Use list

Models to keep or add, with the reason and the measurement.

| Model | Role | Host | Reason |
|---|---|---|---|
| `gpt-oss-20b` | agent loop, interactive chat | beast MI25 | 36.4 tok/s, tool calls, 11 GiB fits the MI25 |
| `qwen9` | interactive chat | beast MI25 | 32.4 tok/s, tool calls, 5.3 GiB |
| `gemma-12b` | interactive chat, vision | beast MI25 | 16.4 tok/s, tool calls, 6.2 GiB |
| `gemma-26b` | long-context | beast MI25 | 14.8 tok/s at 81920 context |
| `gpt-oss-120b` | heavy background work | beast CPU | 9.4 tok/s with no GPU at all |
| `gemma-e4` | interactive chat, vision, speech recognition | athena | 48.4 tok/s, tool calls, audio and image input |
| `coder15` | inline completion | athena | 11.4 tok/s |
| `gemma-e2b` | travel default | minerva | 50.2 tok/s, the fastest measured figure |
| `coder1.5` | travel completion | minerva | 45.7 tok/s |
| Kokoro-82M | speech synthesis | any host | 2.5x realtime on CPU, 270 MB |

## Avoid list

| Model | Reason |
|---|---|
| `coder3` on athena | 5.7 tok/s, no tool calls, and a 1.5B at 11.4 tok/s serves the same role |
| `llama3` on athena | 4.1 tok/s and no role the other models do not cover |
| `qwen27` on athena | 1.9 tok/s at 27B on an 8 GB card; it loads without GPU offload and holds 27B in system RAM while competing for the card |
| `coder14` on beast | 9.2 tok/s, the slowest MI25 model, and no tool calls |
| Qwen3-TTS on the laptop | 0.87x realtime on CPU and 8.1 GB peak RSS, per `documents/18-voice-and-speech-models.md` |

## Recommendations to drop

The human decides these; the review only recommends.

1. **`qwen27` (`batiai/Qwen3.8-27B-GGUF:Q4_K_M`) on athena.** It is the slowest
   model measured at 1.9 tok/s, it loads without GPU offload, and at 27B it
   cannot fit the 8 GB card. The policy already called it a discard candidate on
   beast. Dropping it would free the system RAM it holds and remove a model that
   cannot serve its role.
2. **`coder3` and `llama3` on athena.** Both are slower than `coder15` in the
   same role and neither emits tool calls.
3. **The eight cache-only models on athena.** They are client-facing without
   being configured. Either give them presets or remove them from the cache;
   leaving them visible is the risk the review plan named.

## Answers to the review's open questions

**Is the MI25 worth keeping as the interactive GPU?** Yes. It serves 20B and 26B
models at 14–36 tok/s, which the 8 GB RX 5500 XT cannot hold. The GTX 1050 on
beast is idle and is not used. The MI25's limits are real — 9.2 tok/s on a 14B,
and no flash attention — but no other host can serve those models at all.

**Should beast's CPU router keep the 120B?** Yes, as a background tier. It runs
at 9.4 tok/s on CPU with no GPU, which is usable for long-running work and not
for interactive chat. Nothing measured suggests a smaller model would replace it
at a role it uniquely fills.

**Which models should be in the cache but not in a preset?** None on athena:
the seven cache-only models are client-facing. On beast the cache and the preset
match. The recommendation is to make the cache and the preset agree on every
host.

**What is the right build policy when a build changes a flag the presets use?**
The three hosts are 31, 31 and 39 commits past `b12690`. The policy this review
recommends is: pin one build per host, record the commit in the unit, and run
`make llama-service-dry-run` after any build change — it validates the preset
keys against the installed binary and fails before a restart. Minerva's
`mmap` → `load-mode` failure was caught by exactly this check.

## What remains unverified

- The alternative engines (vLLM, Ollama's router capability, llamafile) were not
  measured; the plan's expectations about them are carried forward unverified.
- The cold-start load time per model was not measured separately; the warm-up
  request's duration is recorded but not analysed.
- The laptop's figures were measured on its own server, not through a router, so
  router overhead on the laptop is not measured.
- Speech and vision figures are quoted from
  `documents/18-voice-and-speech-models.md`, where seven claims are already
  marked `unverified`.

## Proposed criteria revisions

The criteria held up, with one gap: they did not ask a study to record whether a
model is in the preset or only in the cache. That distinction decided the athena
finding, so it is proposed as a criterion rather than left to the studies. The
criteria file is not modified here; this is a proposal for the human.
