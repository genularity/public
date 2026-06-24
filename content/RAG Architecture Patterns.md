---
title: "RAG Architecture Patterns"
date_saved: 2026-06-25
tags:
  - rag
  - retrieval-augmented-generation
  - architecture
  - llm
  - vector-databases
  - context-engineering
summary: >
  RAG (Retrieval-Augmented Generation) connects LLMs to external knowledge bases at
  inference time. This note covers the main architectural patterns — naive RAG, advanced RAG,
  modular RAG, and agentic RAG — and when to use each.
technologies:
  - Vector databases
  - Embeddings
  - LLM
  - Rerankers
  - Knowledge graphs
key_concepts:
  - Naive RAG
  - Advanced RAG
  - Modular RAG
  - Agentic RAG
  - Hybrid search
  - Reranking
  - Chunking strategies
related:
  - "[[Context Engineering - The New Prompt Engineering]]"
  - "[[Memory Systems for AI Agents]]"
  - "[[Context Window Limits - Strategies for Long Documents]]"
  - "[[AI Agents & Agentic Systems]]"
  - "[[AI Evals Fundamentals]]"
status: draft
publish: true
---

# RAG Architecture Patterns

> [!tldr] TL;DR
> RAG is not one thing. There are at least four distinct patterns with very different complexity/capability tradeoffs. Most teams start with naive RAG and should move to hybrid search + reranking before touching agentic approaches.

## The Four Patterns

### 1. Naive RAG
Embed → store → retrieve → generate. The classic pipeline.

```
Query → Embed → Similarity search → Top-K chunks → LLM
```

**When to use:** Prototypes, small corpora, homogeneous content.
**Failure modes:** Retrieval misses, redundant chunks, no query understanding.

---

### 2. Advanced RAG
Adds pre-retrieval and post-retrieval steps around the naive core.

**Pre-retrieval:**
- Query rewriting / HyDE (hypothetical document embeddings)
- Query decomposition for multi-hop questions
- Metadata filtering

**Post-retrieval:**
- Reranking (cross-encoder models score relevance more accurately than embeddings)
- Compression (strip irrelevant sentences from retrieved chunks)
- Deduplication

**When to use:** Production systems with diverse query types.

---

### 3. Modular RAG
Treats each component as a swappable module. Mix and match retrievers, rankers, generators.

Enables:
- Routing queries to different retrieval strategies
- Fusion of multiple retrieval methods (dense + sparse)
- Fallback chains when retrieval confidence is low

---

### 4. Agentic RAG
The retriever is itself an agent. It decides *whether* to retrieve, *what* to retrieve, and *when to stop*.

```
Query → Agent decides retrieval strategy → Multi-step retrieval → Synthesis → Answer
```

Best for complex multi-hop reasoning. High latency cost. Use [[AI Evals Fundamentals]] to validate quality before deploying.

## Hybrid Search is Non-Negotiable

Pure dense (embedding) search misses exact matches. Pure sparse (BM25) misses semantic similarity. Hybrid search combines both — standard in production RAG.

Typical weights: 0.7 dense + 0.3 sparse (tune per domain).

## Chunking Strategies

| Strategy | Best for |
|----------|----------|
| Fixed-size | Homogeneous prose |
| Sentence/paragraph | Structured docs |
| Semantic chunking | Mixed content |
| Document-level | Short documents |
| Parent-child | Hierarchical content |

> [!warning] Chunk size is a retrieval precision vs. recall tradeoff. Smaller chunks = better precision; larger chunks = more context per hit.

## Related

- [[Context Engineering - The New Prompt Engineering]] — context assembly after retrieval
- [[Memory Systems for AI Agents]] — persistent retrieval across sessions
- [[Context Window Limits - Strategies for Long Documents]] — when chunks don't fit
- [[AI Evals Fundamentals]] — evaluating RAG quality
