---
tags:
  - ai-agents
  - agentic-coding
  - docker
  - sandboxes
  - developer-tools
  - security
status: processed
created: 2026-08-07
updated: 2026-08-07
publish: true
summary: >
  Docker Sandboxes ships "kits" — a spec.yaml contract that pre-configures an
  empty agent microVM with tools, network allowlists, and proxy-brokered
  credentials, so isolation doesn't collapse back into "just run it on the host."
related: ["[[Agentic Coding Harnesses & Terminal Runtimes]]", "[[Agentic Project Guidelines - Proposing and Evaluating Agentic Work]]"]
source: https://www.docker.com/blog/empty-sandboxes-break-developer-experience/
---

# Docker Sandbox Kits - Configuring AI Agent Sandboxes

Source: Oleg Šelajev (Docker), "Why Empty Sandboxes Break Developer Experience," Aug 2026.

## The Problem

Docker Sandboxes give AI coding agents an isolated microVM: clean filesystem, restricted network, clean credentials. Good security boundary — but also empty. The agent immediately needs `gcloud`, a JDK, an internal CLI, registry credentials, and team-specific tacit knowledge. Real dev machines already have all this; a fresh sandbox has none of it.

The failure mode isn't dramatic — it's death by friction: agent burns minutes installing packages, hits a blocked registry, asks for an API key it shouldn't have. At that point the dev's choice is "spend 10 min prepping the sandbox" vs. "just run the agent on the host." Convenience wins, and the isolation boundary gets bypassed in practice.

**Core principle:** isolation only survives contact with developers when it's at least as convenient as skipping it.

## The Fix: Kits

A **kit** = `spec.yaml` + optional files. It's the contract between a sandbox and a tool/capability you want available inside it. Applied when the sandbox starts.

A kit can:
- **Install tools** (e.g. `apt-get install -y jq`)
- **Set network policy** — `allowedDomains` / `deniedDomains` (e.g. allow `api.example.com`, `*.cdn.example.com`; deny `telemetry.example.com`)
- **Wire credentials without copying secrets into the microVM** — the real secret stays on the host; the agent sees a sentinel env var (e.g. `MY_SERVICE_API_KEY=***`); a host-side proxy injects the real header only for approved outbound domains
- Drop files into `/home/agent/` or the workspace, set non-secret env vars, run startup commands, start background services, inject agent context into `CLAUDE.md`/`AGENTS.md`

### Two kit shapes
- `kind: sandbox` — full agent runtime (image, entrypoint, policy). Use when building an agent from scratch.
- `kind: mixin` (the common case) — extends an existing sandbox with **one** capability: installs a tool, opens a narrow network path, wires credentials, adds usage instructions. Mixins **stack**.

```
sbx run claude . \
  --kit docker.io/acme/sbx-java-kit:1.0 \
  --kit docker.io/acme/sbx-gcloud-kit:1.0 \
  --kit docker.io/acme/sbx-tessl-kit:1.0
```

Design rule: many small mixins with clear jobs (Java kit, gcloud kit, YouTube-transcript kit, Tessl/skills kit) — not one giant "my whole laptop" kit, which becomes a maintenance incident.

### Distribution
Kits support local dirs, Git URLs, and OCI artifacts. For sharing: keep source in Git (review/patch there), publish the artifact to an OCI registry (Docker Hub etc.) for easy consumption — `--kit docker.io/acme/sbx-my-product-kit:1.0`. Avoids the "stale wiki page → someone pastes a token into a config file" failure mode of ad hoc setup scripts.

## Why This Matters (Kent's context: AI architecture / agentic tooling)

- Same instinct as OpenClaw's node/sandbox model: the credential-proxy pattern (secret stays on host, agent gets a sentinel, proxy injects on egress) is the right shape for any agent-sandbox integration — worth comparing against how OpenClaw brokers credentials to sub-agents/nodes.
- Relevant to evaluating any "agent runs in isolated env" tool (see [[Agentic Coding Harnesses & Terminal Runtimes]]) — the kits model is a reusable framework for judging whether a sandboxed agent tool is actually usable day-to-day or just secure-on-paper.
- Docs: https://docs.docker.com/ai/sandboxes/customize/kits/ and https://docs.docker.com/ai/sandboxes/customize/kit-examples/

## Related
- [[Agentic Coding Harnesses & Terminal Runtimes]]
- Agentic Project Guidelines - Proposing and Evaluating Agentic Work
