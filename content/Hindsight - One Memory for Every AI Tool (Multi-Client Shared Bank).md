---
title: "Hindsight - One Memory for Every AI Tool (Multi-Client Shared Bank)"
url: "https://hindsight.vectorize.io/blog/2026/04/07/one-memory-for-every-ai-tool"
date_saved: 2026-08-06
date_published: 2026-04-07
tags:
  - hindsight
  - memory
  - ai-agents
  - architecture
  - mcp
  - context-engineering
technologies:
  - Hindsight
  - MCP
  - OAuth 2.1
  - Cloudflare Workers
  - Cloudflare Tunnel
  - OpenClaw
  - Claude Code
related:
  - "[[Hindsight - Agentic Memory for AI Systems]]"
  - "[[Hindsight - Bank Strategy for Agent Memory]]"
status: processed
publish: true
---

# Hindsight — One Memory for Every AI Tool (Multi-Client Shared Bank)

> [!tldr] TL;DR
> A field report on running **one shared Hindsight bank across many AI clients** — OpenClaw, the Claude desktop/mobile apps, Claude Code CLI, VS Code extension, and Codex — so context (preferences, past decisions, project reasoning) carries between every tool instead of each one starting from zero. Local clients hit Hindsight over localhost; remote cloud clients connect via MCP through a Cloudflare Worker (~250 lines) that implements the full OAuth 2.1 / DCR / PKCE handshake the Claude apps require and proxies to a Bearer-auth self-hosted Hindsight behind a Cloudflare Tunnel. Hindsight Cloud speaks OAuth 2.1 natively, so it skips the proxy entirely. **This is about carried-over *memory*, not a store for reference documents** — an important distinction for the tool42 reference-material question.

## The core pattern

Every AI tool normally starts from zero: you explain your project to Claude, again to Codex, again in each new Claude Code session — context doesn't travel. The pattern here is one Hindsight **bank** that all clients read from and write to, so the effect is cumulative: an idea started in the Claude mobile app, refined on desktop, then built in Claude Code, then handed to OpenClaw — each tool picks up where the last left off from the same shared memory.

## How the clients connect

| Client | Connection |
|---|---|
| OpenClaw | Same machine → `hindsight-openclaw` plugin talks directly over localhost |
| Claude desktop/mobile apps | Remote → MCP through the OAuth-proxy Worker |
| Claude Code CLI + VS Code ext | Remote → MCP through the same Worker |
| Codex | Remote → MCP through the same Worker |

**The bridge (self-hosted only):** cloud clients (Claude apps) require OAuth 2.1 with Dynamic Client Registration + PKCE to talk to an MCP server, but self-hosted Hindsight only speaks Bearer-token auth. The gap is closed by:

- Hindsight in Docker, bound to localhost
- Cloudflare Tunnel exposing it via a subdomain
- A Cloudflare Worker (~250 lines, built with `@cloudflare/workers-oauth-provider`, KV namespace for token state) implementing discovery/DCR/PKCE-S256/token-exchange and translating OAuth tokens ↔ Hindsight's Bearer token
- Cloud clients connect via MCP through the Worker

> [!note] Hindsight Cloud skips all of this
> Hindsight Cloud already speaks OAuth 2.1, so all cloud clients connect directly — the Worker/Tunnel setup is only for self-hosters. The author is working to contribute the Worker as a generic reference OAuth proxy for self-hosters.

## Getting memories stored automatically

- **OpenClaw** and **Claude Code CLI** have native hook systems the plugins latch onto: auto-retain after each turn, auto-recall before each response (Claude Code uses SessionStart / UserPromptSubmit / Stop hooks). No prompting.
- **Claude apps outside the CLI** have no hooks, so memory is driven by *instructions* — a user-level `CLAUDE.md` for Claude Code/VS Code, and "user preferences" text in the Claude app settings telling the model when to recall/retain/reflect. Works in practice for the majority of sessions; author double-checks retain on important ones.
- **Open gap the author flags:** if the Claude *apps* exposed lifecycle hooks (e.g. `onConversationEnd`) like the CLI does, memory capture wouldn't depend on prompt instructions at all.

## Why this matters here

This is the concrete, worked version of the Hindsight as Shared Memory Substrate Across Kiro, tool42, helparoo-DejaRoo idea — one bank, many surfaces — with the actual connection mechanics (MCP + OAuth proxy) spelled out. If tool42/helparoo/OMP ever want a genuinely shared memory across different client harnesses (not just across OMP sessions), this is the reference implementation for the transport/auth layer.

**But note the scope boundary that answers the reference-material question:** this article is about **memory** — carried-over preferences, decisions, and project reasoning that improve as they accumulate. It is *not* proposing Hindsight as a store for reference documents/design material where exact content must come back verbatim. The retain/recall/reflect loop it relies on still extracts and consolidates facts (see [[Hindsight - Agentic Memory for AI Systems]]), which is lossy by design. So this post *strengthens* the case for a single shared bank as the **discovery/pointer** layer for reference material (one bank all clients can search to *find* where a doc lives), while leaving the exact-content store in git/object-store/Haystack — see tool42 - Access to Shared Reference Material (EDS and Beyond) for that split.

## Links

- [Original post — Hindsight / Vectorize blog](https://hindsight.vectorize.io/blog/2026/04/07/one-memory-for-every-ai-tool)
- [[Hindsight - Agentic Memory for AI Systems]] — retain/recall/reflect mechanics this pattern sits on
- [[Hindsight - Bank Strategy for Agent Memory]] — deciding what a shared bank's boundary should be

## Related

- Hindsight as Shared Memory Substrate Across Kiro, tool42, helparoo-DejaRoo — the project-level shared-substrate idea this article is a concrete implementation of
- tool42 - Access to Shared Reference Material (EDS and Beyond) — where the memory-vs-reference-material distinction is applied to t42's actual problem
- [[Hindsight - Bank Strategy for Agent Memory]] — the "if A retains, should B recall it?" boundary question this multi-client pattern answers with "yes, one bank"
