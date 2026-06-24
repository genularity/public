---
title: "Context Window Limits - Strategies for Long Documents"
date_saved: 2026-06-25
tags:
  - context-engineering
  - llm
  - long-context
  - rag
  - compression
  - architecture
summary: >
  Even with 200k+ token context windows, throwing everything at a model is rarely the right
  move. This note covers practical strategies for handling content that exceeds useful context
  limits — from chunking and summarization to hierarchical processing.
technologies:
  - LLM
  - RAG
  - LLMLingua
  - MapReduce
key_concepts:
  - Lost-in-the-middle
  - Context compression
  - Hierarchical summarization
  - MapReduce pattern
  - Selective context
  - Token budgeting
related:
  - "[[Context Engineering - The New Prompt Engineering]]"
  - "[[RAG Architecture Patterns]]"
  - "[[Memory Systems for AI Agents]]"
  - "[[Prompt Engineering is Dead - Long Live Context Engineering]]"
status: draft
publish: true
---

# Context Window Limits — Strategies for Long Documents

> [!tldr] TL;DR
> Bigger context windows don't solve the problem — they delay it and introduce new ones. The lost-in-the-middle effect means quality degrades with length even when content fits. Strategy beats size.

## The Bigger-Window Trap

Models now support 128k, 200k, even 1M tokens. The temptation: just stuff everything in.

The reality:
- **Cost** scales linearly (or worse) with context length
- **Latency** scales with context length
- **Quality** degrades non-linearly — the lost-in-the-middle effect worsens with length
- **Attention dilution** — relevant signal competes with more noise

Fitting isn't the same as working.

## The Lost-in-the-Middle Effect

Empirically validated: LLMs are significantly better at using information placed at the **start** or **end** of context. Information in the middle is systematically underweighted.

Implication: if your critical content lands in position 40k of a 100k context, performance drops — even if it "fits."

**Fix:** Put the most important content first and last. Don't bury the answer.

## Strategy 1: Selective Retrieval (RAG)

Don't include the whole document. Retrieve only the relevant chunks.

Best for: large corpora, Q&A over documents, knowledge bases.
See [[RAG Architecture Patterns]] for implementation.

## Strategy 2: Hierarchical Summarization

Process in layers:
```
Document → Chunk summaries → Section summaries → Document summary → Query
```

Trade detail for breadth. Useful when you need overview before diving in.

## Strategy 3: MapReduce Pattern

Split → process in parallel → reduce.

```
Long doc → Split into N chunks
         → LLM processes each chunk independently (Map)
         → LLM combines results (Reduce)
```

Works well for: extraction tasks, translation, analysis of large codebases.
Doesn't work well for: tasks requiring cross-chunk reasoning.

## Strategy 4: Context Compression

Use a model or algorithm to compress context before sending to the main model.

- **LLMLingua** — token-level compression, removes low-importance tokens
- **Selective Context** — sentence-level, removes low-perplexity sentences
- **Recomp** — trains a compressor specifically for RAG

Typical compression ratio: 2-5x with <5% quality loss at moderate compression levels.

## Strategy 5: Iterative Refinement

Instead of one large context, use multiple focused passes:

1. First pass: high-level summary / structure extraction
2. Second pass: targeted deep-dive on relevant sections
3. Third pass: synthesis

More latency, better quality on complex tasks.

## Token Budgeting

Treat context as a budget. Allocate explicitly:

| Component | Budget |
|-----------|--------|
| System prompt | 500-2k tokens |
| Retrieved context | 4-8k tokens |
| Conversation history | 2-4k tokens |
| Current query + output | 1-2k tokens |

Enforce budgets in code, not in hope.

## Related

- [[Context Engineering - The New Prompt Engineering]] — the broader discipline
- [[RAG Architecture Patterns]] — selective retrieval in depth
- [[Memory Systems for AI Agents]] — managing context across sessions
