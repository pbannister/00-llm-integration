# MTP and RAG — verified 2026-08-26

Two capabilities the owner has not yet used: MTP (performance) and RAG (retrieval).
This document explains what each is and what the local setup already offers.

## MTP — Multi-Token Prediction

### What it is

Most models predict one next token per forward pass. An MTP (multi-token prediction) model has an extra head that predicts K next tokens in the same pass.
Speculative decoding then verifies all K draft tokens in a single forward pass, so the model reads its weights once and emits up to K tokens.
Inference on CPU is memory-bandwidth-bound (reading weights dominates), so MTP multiplies tokens per second nearly linearly on CPU hosts.

### Local support

- Beast runs llama.cpp build 10628 (dev), which supports `--spec-type draft-mtp` (plus `--spec-draft-model` for a separate drafter file when the model has no native head).
- The gpt-oss architecture carries a native MTP head, so `unsloth/gpt-oss-120b-GGUF:Q4_K_XL` is the natural MTP candidate.
- Evidence it already works: the owner's own benchmark shows gpt-oss-120b at **8.42 t/s on CPU**, versus 0.91 t/s for the 70B models on the same host — the MTP signature. Verify explicitly in task 01 with `llama-bench` comparing `--spec-type none` and `draft-mtp`, then enable it in the preset (`spec-type = draft-mtp`) when it helps.
- Other families may need a separate MTP drafter GGUF (for example unsloth publishes MTP drafters for some gemma/Qwen models; DeepSeek-R1 uses one too). Only adopt a drafter when the model's preset runs on a host that can afford the extra memory.

### Action

- Task 01 benchmarks and enables MTP on the 120B preset.
- Re-benchmark CPU models before assuming MTP helps; it costs memory for the drafter.

## RAG — Retrieval-Augmented Generation

### What it is

RAG answers questions from a corpus of your documents instead of the model's training data.
A pipeline embeds the corpus (each chunk → a vector), and for each query retrieves the most similar chunks by vector distance, then injects those chunks into the prompt context.
The model then answers grounded in the retrieved text, with citations to the source chunks.

### What the local setup already offers

- **Embedding model**: `ggml-org/Nomic-Embed-Text-V2-GGUF:Q8_0` is already in the athena catalog (cache entry).
  It needs an embeddings preset on the athena router so `/v1/embeddings` answers (task 01).
- **Reranking**: llama.cpp supports a rerank endpoint; a reranker improves retrieval order after the first vector pass.
- **Open WebUI**: has built-in RAG (document upload, chunking, retrieval) and can point at the local routers, so RAG needs no new infrastructure — just the embeddings endpoint.
- **Use cases here**: ask questions over project READMEs and documents (for example the homelab docs, this project's documents/) without pasting them into prompts; or semantic code search over a repository.

### Boundaries

- DeepSeek Harness is an agent harness, not a RAG application; it does not index documents.
  RAG belongs in Open WebUI or a small script that calls `/v1/embeddings` and the chat endpoint.
- RAG adds retrieval latency and depends on chunk quality; start with a single corpus (for example `documents/` of one project) before scaling.

### Action

- No deployment yet. Task 01 enables the embeddings preset; a later task can stand up Open WebUI RAG against it when the owner wants it.
