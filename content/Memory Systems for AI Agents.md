---
title: "Memory Systems for AI Agents"
date_saved: 2026-06-25
tags:
  - memory
  - ai-agents
  - context-engineering
  - rag
  - llm
  - architecture
summary: >
  AI agents need more than a context window. This note covers the four types of memory
  available to agents — in-context, external/semantic, episodic, and procedural — and
  practical patterns for combining them.
technologies:
  - Vector databases
  - LLM
  - Key-value stores
  - Knowledge graphs
key_concepts:
  - In-context memory
  - Semantic memory
  - Episodic memory
  - Procedural memory
  - Memory consolidation
  - Forgetting curves
related:
  - "[[Context Engineering - The New Prompt Engineering]]"
  - "[[RAG Architecture Patterns]]"
  - "[[Context Window Limits - Strategies for Long Documents]]"
  - "[[AI Agents & Agentic Systems]]"
  - "[[Prompt Engineering is Dead - Long Live Context Engineering]]"
status: draft
publish: true
---

# Memory Systems for AI Agents

> [!tldr] TL;DR
> Agents have four types of memory. Most systems only use one or two. The gap between toy demos and production agents is often just missing memory architecture.

## The Four Types

### 1. In-Context Memory (Working Memory)
Everything currently in the context window. Fast, zero-latency, but ephemeral and size-limited.

- Lost when the context is cleared
- Subject to the [[Context Window Limits - Strategies for Long Documents|lost-in-the-middle problem]]
- The only memory type most demos use

### 2. External / Semantic Memory
Persistent storage retrieved via similarity search. The "long-term memory" of RAG systems.

- Vector databases (Pinecone, Weaviate, Chroma)
- Retrieved on demand, not always present
- Quality depends on embedding model + chunking strategy
- See [[RAG Architecture Patterns]] for retrieval patterns

### 3. Episodic Memory
Records of *what happened* — past interactions, tool call results, prior decisions.

Enables:
- Learning from past failures
- Not repeating the same retrieval
- Personalization over time

Implementation: append-only logs, summarization pipelines, conversation history stores.

### 4. Procedural Memory
How to do things — skills, workflows, tool usage patterns. Usually baked into the system prompt or tool definitions, but can be made dynamic.

Dynamic procedural memory = agents that improve their own procedures based on experience.

## Memory Consolidation

The human analogy: working memory → short-term → long-term.

For agents:
```
Recent interactions → Summarize → Store in semantic memory
                   → Extract facts → Update knowledge base
                   → Identify patterns → Update procedures
```

This is expensive to do per-turn. Run consolidation asynchronously or on a schedule.

## The Forgetting Problem

More memory isn't always better. Stale, contradictory, or irrelevant memories degrade performance.

Strategies:
- **TTL (time-to-live)** — expire old memories
- **Confidence scoring** — weight memories by reliability
- **Contradiction detection** — flag conflicting memories for review
- **Importance scoring** — retain high-signal memories longer

## Practical Architecture

For most production agents:

1. **In-context** — last N turns + system prompt
2. **Semantic** — RAG over domain knowledge + past interactions
3. **Episodic** — summarized session history (last 30 days)
4. Skip procedural unless you have evidence it's needed

## Related

- [[Context Engineering - The New Prompt Engineering]] — how memory feeds into context
- [[RAG Architecture Patterns]] — the retrieval layer for semantic memory
- [[Context Window Limits - Strategies for Long Documents]] — managing what fits in working memory
- [[AI Agents & Agentic Systems]] — broader agent architecture
