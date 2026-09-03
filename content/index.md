---
title: genularity
publish: true
quartz-homepage: true
themes-hash: "9d624784fecd"
---

# Kent's Notes

<span class="dict-entry"><strong>genularity</strong> <span class="ipa">/ˌdʒɛn.jʊˈlær.ɪ.ti/</span> · <em>noun</em>: the state in which a system's degrees of freedom approach infinity as its generality approaches everything.</span>

I'm an AI Architect based in Sweden. These notes are my thinking-out-loud: patterns I've found useful, ideas worth sharing, things I want to remember.

<!-- QUARTZ:THEMES-START -->
Right now that means the plumbing behind AI agents that don't forget: [[Hindsight - Agentic Memory for AI Systems|persistent memory as a service]], [[Hindsight - Bank Strategy for Agent Memory|where to draw its recall boundaries]], and [[Hindsight - One Memory for Every AI Tool (Multi-Client Shared Bank)|how to share one bank across every tool you use]]; the [[OMP Configuration - Generic Reference|harness config]] that wires model routing, subagents, and memory backends into something that actually runs in production, plus [[Overriding Agent Memory Tools Cleanly - Interception vs Reimplementation|how to cleanly override an agent's memory tools]] and a [[Agentic Coding Harnesses & Terminal Runtimes|field guide to the coding agents themselves]]. Around that: what [[KV, Prefix, Prompt and Semantic Caching in LLMs — Clearly Explained|"caching" actually means]] in an LLM stack, how to [[Docker Sandbox Kits - Configuring AI Agent Sandboxes|sandbox agents without the isolation collapsing]], and [[Daily Dev Tools Digest - Cron Job and Scripts|the cron job that keeps me current]] on all of it.
<!-- QUARTZ:THEMES-END -->

---

## Start Here

<!-- QUARTZ:NOTE-LIST-START -->
- [[Agentic Coding Harnesses & Terminal Runtimes]] — A field guide to agentic coding tools, split into two categories that get conflated constantly: harnesses that actually write code (terminal-native, IDE-integrated, cloud/multi-agent) and runtime containers that orchestrate multiple harnesses in parallel
- [[Daily Dev Tools Digest - Cron Job and Scripts]] — Full source dump of AgentShadow's "Daily Dev Tools Changelog" OpenClaw cron job: the verbatim orchestrator prompt (9-subagent fan-out over GitHub repos + fuzzy web scans, watermark-based diffing, JSON-schema-validated synthesis, Telegram digest delivery), all 5 Python helper scripts it shells out to, both JSON schemas it validates against, and 3 concrete example artifacts (watermark state file, one full log entry, one target-history file)
- [[Docker Sandbox Kits - Configuring AI Agent Sandboxes]] — Docker Sandboxes ships "kits" — a spec.yaml contract that pre-configures an empty agent microVM with tools, network allowlists, and proxy-brokered credentials, so isolation doesn't collapse back into "just run it on the host."
- [[Hindsight - Agentic Memory for AI Systems]] — Hindsight is a standalone memory API for AI agents — a persistent, searchable memory layer that any agent or LLM application can plug into
- Hindsight - One Bank or Many? Designing Agent Memory Boundaries — Vectorize's field guide to structuring agent memory in Hindsight: a "bank" is a recall boundary, not a performance knob
- [[Hindsight - One Memory for Every AI Tool (Multi-Client Shared Bank)]]
- KV vs Prefix vs Prompt vs Semantic Caching — Four different things in an LLM system all get called 'caching' and they're not the same: KV cache (the model saves its own in-progress work so it doesn't redo it word by word), prefix caching (the server keeps that saved work around after a request ends, for reuse if the next request starts with identical text), prompt caching (the same idea as a paid API feature — ~10% cost to reuse, ~125% to store), and semantic caching (matches meaning via embeddings, not exact text, and returns a stored answer without running the model at all)
- [[OMP Configuration - Generic Reference]] — A fully-annotated reference config for Oh My Pi (OMP): model role routing, memory backend wiring, subagent isolation, and the rationale behind every non-default setting
- Overriding Agent Memory Tools Cleanly — Interception vs Reimplementation — |
<!-- QUARTZ:NOTE-LIST-END -->

---

## Browse

Use the **explorer** on the left or hit `Ctrl+K` to search. The **graph view** on the right shows how notes connect.

---

*Updated automatically from my Obsidian vault.*
