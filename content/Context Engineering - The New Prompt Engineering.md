---
title: "Context Engineering - The New Prompt Engineering"
date_saved: 2026-06-25
tags:
  - context-engineering
  - llm
  - prompt-engineering
  - ai-agents
  - information-retrieval
summary: >
  Context engineering is the discipline of designing and managing what information flows
  into an LLM's context window — going far beyond prompt crafting to include retrieval,
  compression, memory, and dynamic assembly of context at inference time.
technologies:
  - LLM
  - RAG
  - Vector databases
  - Embeddings
key_concepts:
  - Context windows
  - Context compression
  - Retrieval-Augmented Generation
  - Dynamic context assembly
  - Information density
related:
  - "[[Context Window Limits - Strategies for Long Documents]]"
  - "[[RAG Architecture Patterns]]"
  - "[[Memory Systems for AI Agents]]"
  - "[[Prompt Engineering is Dead - Long Live Context Engineering]]"
  - "[[AI Agents & Agentic Systems]]"
status: draft
publish: true
---

# Context Engineering — The New Prompt Engineering

> [!tldr] TL;DR
> Prompt engineering was about crafting the right words. Context engineering is about curating the right *information* — what goes in, in what order, at what fidelity.

## The Shift

For a long time, "prompt engineering" was the skill. Tweak your system prompt. Add few-shot examples. Fiddle with temperature.

That era is ending.

As models get smarter, *what you say* matters less than *what you give them to work with*. A mediocre prompt with excellent context beats a perfectly crafted prompt with no context.

Context engineering is the discipline of designing that information flow — from raw data sources all the way to the tokens the model actually sees.

## What Context Engineering Actually Covers

- **Retrieval** — what to fetch (RAG, search, memory stores)
- **Filtering** — what to exclude (noise reduction, relevance scoring)
- **Compression** — how to fit more signal into fewer tokens (summarization, chunking strategies)
- **Ordering** — how to arrange context (primacy/recency effects, lost-in-the-middle problem)
- **Assembly** — how to combine sources dynamically at inference time

## The Lost-in-the-Middle Problem

Research shows LLMs systematically underweight information placed in the middle of long contexts. Critical facts belong at the top or bottom. This is a **context ordering** problem, not a model capability problem.

## Key Principles

1. **Density over length** — 2k tokens of dense signal beats 20k tokens of noise
2. **Recency matters** — recent context is weighted more heavily by most models
3. **Source diversity** — multiple independent sources reduce hallucination
4. **Explicit over implicit** — state context relationships explicitly; don't rely on the model to infer

## Tooling

| Tool | Role |
|------|------|
| Vector DB (Pinecone, Weaviate) | Semantic retrieval |
| BM25 / keyword search | Lexical retrieval |
| Rerankers (Cohere, BGE) | Relevance scoring |
| LLMLingua / Selective Context | Context compression |

## Related

- [[RAG Architecture Patterns]] — retrieval layer in depth
- [[Memory Systems for AI Agents]] — long-term context persistence
- [[Context Window Limits - Strategies for Long Documents]] — when context doesn't fit
- [[Prompt Engineering is Dead - Long Live Context Engineering]] — the broader argument
