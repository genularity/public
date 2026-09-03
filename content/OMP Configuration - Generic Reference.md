---
tags:
  - omp
  - configuration
  - reference
  - public
created: 2026-07-06
status: public-safe
publish: true
related:
  - "[[Hindsight - Agentic Memory for AI Systems]]"
  - "[[Agentic Coding Harnesses & Terminal Runtimes]]"
summary: >
  A fully-annotated reference config for Oh My Pi (OMP): model role routing, memory backend wiring, subagent isolation, and the rationale behind every non-default setting.
---
# OMP Configuration — Generic Reference

> [!info] Related
> This config uses [[Hindsight - Agentic Memory for AI Systems]] as its memory backend — see the `hindsight` block below for how the agent harness is wired to it. For where OMP fits among other coding agents, see [[Agentic Coding Harnesses & Terminal Runtimes]].

---

## Directory Layout

```
~/.omp/agent/
  config.yml              Main settings
  models.yml              Custom provider and model definitions
  .env                    Secrets + env-only vars + model role overrides
  APPEND_SYSTEM.md        System prompt appendix
  agents/                 11 custom agent definitions (auto-discovered)
  rules/                  3 TTSR safety rules (auto-discovered)
  plugins/                Plugin install directory
```

---

## config.yml

```yaml
# Internal setup state marker. Incremented by OMP when new onboarding steps are
# added; causes the setup wizard to re-run those steps. Do not edit manually.
setupVersion: 1

# Overrides the shell binary used by the bash tool. Uses /bin/bash instead
# of auto-detected zsh — without this, useUserShell forces zsh's -i flag
# with no tty, which can trip shell-framework plugins (e.g. Powerlevel10k's
# gitstatus) that guard on interactive-shell detection and then try to start
# an async daemon ("gitstatus failed to initialize"). Does not affect
# interactive terminal sessions — the user's normal shell RC still loads there.
shellPath: /bin/bash

# Default reasoning depth for thinking-capable models.
# Options: minimal | low | medium | high | xhigh | auto
# "auto" lets a lightweight classifier decide per-turn based on complexity.
# Default is "high"; "auto" saves cost on simple requests without sacrificing
# depth on hard ones.
defaultThinkingLevel: auto

# Maps role names to model IDs. Each role is a named slot consumed by a
# specific pipeline. Thinking-level suffix (e.g. :high) can be appended to
# any role value to pin that pipeline's reasoning depth.
# NOTE: smol, slow, and plan roles are set via PI_SMOL_MODEL / PI_SLOW_MODEL /
# PI_PLAN_MODEL in .env — only default, commit, and custom agent roles live here.
# Custom agent roles (contrarian, gpt-reviewer) have no PI_* env var override
# so they live in config.yml.
modelRoles: 
  # Primary interactive model — used for most tasks.
  default: anthropic/claude-sonnet-5
  # Model used for git commit message generation. No env var override.
  commit: anthropic/claude-haiku-4.5
  # Adversarial reviewer — a different vendor/family than default. OpenRouter
  # exposes it through the same gateway/key as everything else. (Avoid a
  # vendor's raw hosted DeepSeek-R1 endpoint for this role if it doesn't
  # support tool-calling — verify per-provider before binding a tool-using
  # agent to it.)
  contrarian: deepseek/deepseek-v3.2
  # GPT reviewer — OpenAI via OpenRouter, for vendor diversity in the review ensemble.
  gpt-reviewer: openai/gpt-5
  # Code-specialist reviewer.
  devstral: mistralai/devstral-2
  # Open-weight code-specialist model — async/checkpoint code specialist.
  # Used for test-reviewer (checkpoint role, latency acceptable).
  qwen-coder: qwen/qwen3-coder

# Bottom status bar configuration.
statusLine:
  # "custom" means leftSegments / rightSegments are used instead of a preset
  # layout. Other presets: default, minimal, compact, full, nerd, ascii.
  preset: custom
  # Separator style between segments. powerline-thin = thin chevrons (›).
  # Requires a Powerline-compatible font.
  separator: powerline-thin
  # Segments shown on the left of the status bar.
  # pi=session indicator, model=active model, mode=plan/etc, path=cwd,
  # git=branch+changes, pr=current PR, subagents=active subagent count.
  leftSegments: [pi, model, mode, path, git, pr, subagents]
  # Segments shown on the right of the status bar.
  # token_in/out=per-turn token counts, cache_hit=prompt cache hit indicator,
  # token_rate=tokens/sec, context_pct=context window fill %, time_spent=elapsed.
  rightSegments: [session_name, token_in, token_out, cache_hit, token_rate, context_pct, time_spent]
  segmentOptions:
    model:
      # Show the current thinking level badge (e.g. "auto", "high") next to
      # the model name in the status bar.
      showThinkingLevel: true
    path:
      # Shorten long paths with prefix abbreviation (e.g. ~/w/e/project).
      abbreviate: true
      # Truncate path display at 40 characters before abbreviating further.
      maxLength: 40
      # Strip the common work directory prefix so only the project-relative
      # portion shows (e.g. /home/user-a/workspace/acme-corp → just project/).
      stripWorkPrefix: true
    git:
      # Show current branch name in the git segment.
      showBranch: true
      # Show count of staged files.
      showStaged: true
      # Show count of unstaged modifications.
      showUnstaged: true
      # Show count of untracked files.
      showUntracked: true

# Memory backend selection.
# Options: off | local | hindsight | mnemopi
# "hindsight" uses the Hindsight HTTP API for persistent cross-session memory.
memory: 
  backend: hindsight

# Hindsight memory backend configuration.
# API URL and token are sourced from .env (HINDSIGHT_API_URL / HINDSIGHT_API_TOKEN)
# to keep secrets out of this file.
hindsight: 
  # bank_id is set via HINDSIGHT_BANK_ID in .env (per-user identity).
  # High-level purpose of this bank. Sent to the Hindsight server to guide
  # what is worth retaining across all sessions.
  # [PERSONAL] "Personal AI assistant memory for the user. Home-lab infrastructure, personal coding, learning, and life administration."
  bankMission: "Engineering memory for a software engineer at Acme Corp (AI architect + platform software architect). Covers AI strategy, agent tooling, platform software systems, hardware/software fault investigation, internal tooling, project planning, UAT, and research."
  # Per-session context injected alongside retained facts. Tells the retention
  # pipeline what kind of work this session covered, improving classification.
  # [PERSONAL] "Conversation between the user (AI architect at Acme Corp) and an AI assistant. Covers professional engineering, home-lab infrastructure, and personal life."
  retainContext: "Conversation between user-a-work (AI architect + platform software architect at Acme Corp) and an AI assistant. Covers: AI strategy, agent tooling, platform software systems, hardware/software fault investigation, internal tooling, project planning, feature research, and UAT."
  # Retain memories every N turns rather than every turn. 10 reduces
  # Hindsight API calls without losing meaningful coverage.
  retainEveryNTurns: 10
  # Memory types to recall at session start. "world" = general facts,
  # "experience" = personal past events, "observation" = synthesised patterns.
  recallTypes: 
    - world
    - experience
    - observation
  mentalModelAutoSeed: false
  # Request up to 2048 tokens of recalled memories per session — matches the
  # server-side recall_max_tokens cap already configured on the bank.
  # Default is 1024; leaving it lower wastes available recall budget.
  recallMaxTokens: 2048
  # Raise the cap on mental model content rendered into the system prompt.
  # Default 16000 chars is tight as the bank grows (work type vocab, project
  # conventions, user preferences). Content beyond the cap is silently clipped.
  mentalModelMaxRenderChars: 24000

# Model providers and discovery sources to disable entirely.
# This list covers all non-primary provider integrations — prevents OMP from
# trying to pick up skills, commands, or models from Claude Desktop, Codex,
# Gemini, Cursor, etc. on this machine.
disabledProviders: 
  - claude
  - claude-plugins
  - codex
  - opencode
  - gemini
  - cursor
  - windsurf
  - cline
  - vscode
  - github
  - agents

# Skill discovery — controls which directories OMP scans for skill files.
# Disabled for Claude/Codex user and project dirs; native OMP skill dirs
# (~/.omp/agent/skills/, .omp/skills/) remain active by default.
skills: 
  enableClaudeUser: false
  enableClaudeProject: false
  enableCodexUser: false

# Slash command discovery — same principle as skills above.
# Prevents OMP picking up /commands from Claude or OpenCode directories.
commands: 
  enableClaudeUser: false
  enableClaudeProject: false
  enableOpencodeUser: false
  enableOpencodeProject: false

# Provider selection for built-in capabilities.
providers: 
  # Use Exa for web search (via the web_search tool).
  # "auto" would let OMP pick; Exa gives better cited results for engineering queries.
  webSearch: exa

# Context compaction settings — controls how OMP manages a filling context window.
compaction: 
  # snapcompact: archives older turns as dense bitmap images the model can
  # still read back. No LLM call required — zero cost, lossless, instant.
  # Alternatives: context-full (LLM summary, lossy), handoff (new session),
  # shake (drop heavy content).
  strategy: snapcompact
  # Automatically compact while idle (5 min default) once tokens exceed
  # 200K. With snapcompact this is free — no API call, no interruption.
  idleEnabled: true

# Tool approval mode. "write" = auto-approve reads and file edits, but prompt
# before exec tools (bash, eval, browser, task, ssh). Provides a confirmation
# gate without being as restrictive as always-ask. TTSR rules + pi-rewind
# provide additional safety (intercept dangerous patterns + filesystem undo).
# Options: yolo (no prompts), write (prompt for exec), always-ask (prompt for write+exec).
tools:
  approvalMode: write

# Display / TUI settings.
display: 
  # Show a visual divider above assistant turns that missed the prompt cache.
  # A cache miss = full input token billing on the provider. This makes billing
  # spikes visible so you can diagnose what busted the cache.
  cacheMissMarker: true
  showTokenUsage: true
  showProgress: true
  # Shimmer animation style on thinking/loading.
  shimmer: classic

# TUI rendering options.
tui:
  # Render Mermaid fenced code blocks as ASCII diagrams inline.
  renderMermaid: true
  # H1 headings at 2x scale via Kitty OSC 66. No-op on iTerm — set for
  # portability if terminal ever changes to Kitty.
  textSizing: true

# macOS sleep prevention. "idle" = run `caffeinate -i` to prevent idle sleep
# while OMP is running. Does not prevent display sleep.
power: 
  sleepPrevention: idle

# Subagent task delegation settings.
task: 
  # "preferred" injects guidance into the system prompt nudging the agent to
  # delegate parallelisable work to subagents rather than doing it inline.
  # Options: default (model decides) | preferred (nudge) | always (force).
  eager: preferred
  # Filesystem isolation for subagent working directories.
  # "auto" uses the best available backend per platform: APFS clonefile on
  # macOS (zero-cost copy-on-write), overlayfs on Linux, none on Windows.
  # Prevents parallel subagents from stomping each other's file changes.
  isolation:
    mode: auto
  # Show the resolved model ID in each subagent's task widget status line.
  # Essential for verifying pi/ role aliases resolve to the correct models.
  showResolvedModelBadge: true

# Todo list behaviour.
todo: 
  # "preferred" adds a system-prompt suggestion to initialise a todo list at
  # the start of multi-step tasks. Improves task decomposition and tracking.
  eager: preferred

# Advisor — a background model that monitors the session and raises concerns.
# Currently disabled.
advisor: 
  enabled: false
  # Don't run the advisor on subagent sessions either.
  subagents: false
  # If the advisor falls behind by 3+ turns, pause the main agent up to 30s
  # to let it catch up. Only active when enabled: true.
  syncBacklog: 3
  # After an advisor interruption, suppress further blocking concerns for 2
  # turns (prevents spamming). Default is 3; 2 means concerns resurface faster.
  immuneTurns: 2

# Terminal theme selection.
theme: 
  dark: dark-tokyo-night

# Nerd Font glyph set. Requires Nerd Font installed in the terminal.
# Options: unicode (standard), nerd (requires Nerd Font), ascii.
symbolPreset: nerd

# Real-time collaboration settings.
collab:
  # displayName does NOT support !cmd or env var resolution — it is read as a plain
  # string by settings.get("collab.displayName") with no resolveConfigValue pass.
  # Only auth.broker.*, models.yml apiKey/headers, and MCP env/headers support !cmd.
  displayName: User Name

# Autolearn — end-of-session nudge to capture reusable skills.
# Passive mode (autoContinue: false, the default): only a reminder prompt,
# no automatic API calls or skill creation without user response.
# Skills are written locally to ~/.omp/agent/skills/ — not synced to Hindsight
# or shared with other engineers. Complements Hindsight (which handles facts);
# autolearn handles procedural/how-to knowledge as skill documents.
# NOTE: A team plan is needed before enabling this in the internal agent platform's project config.
autolearn:
  enabled: true

# Image inspection settings.
inspect_image:
  # Routes image understanding through the "vision" model role. No separate
  # vision role is configured — falls back to "default" (model-sonnet-large), which
  # acts as the vision model. Swap in a dedicated vision role later without
  # touching call sites.
  enabled: true

# Vault — enables the vault:// internal URL for reading and writing Obsidian
# vault content directly.
# Developer / telemetry settings.
dev:
  autoqa:
    # OMP quality-reporting opt-in. "denied" = never collect or send session
    # data, never prompt.
    consent: denied
```

---

## .env

Secrets redacted. Do not commit or print actual values.
Source for the API key: your OpenRouter dashboard → API Keys.

```sh
# Increase stream stall timeouts for OpenRouter.
# Long reasoning responses can take >100s before the first token arrives.
PI_STREAM_IDLE_TIMEOUT_MS=1200000
PI_STREAM_FIRST_EVENT_TIMEOUT_MS=1200000
PI_CACHE_RETENTION=long

# Model role overrides — smol/slow/plan have env var equivalents so live here.
# default and commit have no env var override and remain in config.yml.
PI_SMOL_MODEL=anthropic/claude-haiku-4.5
PI_SLOW_MODEL=anthropic/claude-opus-4.8
PI_PLAN_MODEL=anthropic/claude-opus-4.8

# Hindsight memory backend — URL and token kept here (secrets / env-specific).
# bank_id is per-user identity; kept in .env so it can differ per deployment.
HINDSIGHT_API_URL=https://hindsight.example.com
# [PERSONAL] http://homelab-host:8888
HINDSIGHT_API_TOKEN=<redacted>
HINDSIGHT_BANK_ID=work-bank
# [PERSONAL] personal-bank

# Native OMP OpenTelemetry export — NOT IN USE. Commented out on both machines.
# Points at the local otel-collector-contrib (quick-otel stack, port 4318 = HTTP/protobuf) when enabled.
# Spans emitted: invoke_agent, chat, execute_tool, handoff — with token usage,
# cost hints, and run summaries using GenAI semantic conventions + pi.gen_ai.* attributes.
# Transport: http/protobuf only (4318). gRPC (4317) is not supported by OMP.
# OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
# [PERSONAL] no OTEL config on home
# OTEL_SERVICE_NAME=omp-work-user
# [PERSONAL] no OTEL config on home
# Uncomment to include prompt/response text in spans (privacy tradeoff):
# OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true
#
# Authentication for remote/authenticated OTLP endpoints (not needed for local Podman stack).
# Format: comma-separated key=value pairs.
# LangFuse:       OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic <base64(publicKey:secretKey)>
# Grafana Cloud:  OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <token>
# Arize Phoenix:  OTEL_EXPORTER_OTLP_HEADERS=api_key=<key>
# OTEL_EXPORTER_OTLP_HEADERS=
#
# Traces-specific endpoint (takes priority over OTEL_EXPORTER_OTLP_ENDPOINT):
# OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=
#
# Kill switch — disable all OTEL export without removing config:
# OTEL_SDK_DISABLED=true
#
# Corporate network (Acme Corp): CA bundle for TLS inspection proxy:
# NODE_EXTRA_CA_CERTS=/path/to/acme-corp-ca-bundle.pem
# PI_PROXY=http://proxy.example.com:8080
# NO_PROXY=localhost,127.0.0.1,.example.com
#
# Multi-user deployment: select a named profile under ~/.omp/<profile>/agent/
# OMP_PROFILE=user-a  # [PERSONAL] OMP_PROFILE=user-b


# Bearer key for OpenRouter. Single key, single gateway — every model in
# models.yml resolves through this one credential, regardless of the
# underlying model vendor (Anthropic, OpenAI, DeepSeek, Mistral, Qwen, etc).
# Source: OpenRouter dashboard → API Keys — do not commit or retain.
OPENROUTER_API_KEY=<redacted>
```

### Variable reference

| Variable                           | Purpose                               | Notes                                                                                      |
| ---------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------ |
| `PI_STREAM_IDLE_TIMEOUT_MS`        | Stream idle watchdog timeout in ms    | Extended-thinking responses can take >100s before first token                              |
| `PI_STREAM_FIRST_EVENT_TIMEOUT_MS` | Max wait for first SSE event          | Same reason                                                                                |
| `PI_CACHE_RETENTION`               | `long` = long-duration prompt caching | Reduces cache miss billing                                                                 |
| `PI_SMOL_MODEL`                    | Overrides `modelRoles.smol`           | Haiku-class small model                                                                    |
| `PI_SLOW_MODEL`                    | Overrides `modelRoles.slow`           | Opus-class large model                                                                     |
| `PI_PLAN_MODEL`                    | Overrides `modelRoles.plan`           | Opus-class large model                                                                     |
| `OTEL_EXPORTER_OTLP_ENDPOINT`      | OTLP trace endpoint                   | Not in use — commented out on both machines.                                               |
| `OTEL_SERVICE_NAME`                | Service name in Grafana/Tempo         | Not in use — commented out on both machines.                                               |
| `OPENROUTER_API_KEY`               | Bearer key for the OpenRouter gateway | **Secret.** One key covers every model/vendor in `models.yml` — no per-vendor credentials. |


| Variable                             | Overrides / Purpose         | Description                                                 |
| ------------------------------------ | --------------------------- | ----------------------------------------------------------- |
| `PI_PY`                              | Disable Python eval         | `0` disables the Python eval backend                        |
| `PI_JS`                              | Disable JS eval             | `0` disables the JavaScript eval backend                    |
| `PI_TINY_DEVICE`                     | `providers.tinyModelDevice` | ONNX execution provider for local tiny models               |
| `PI_TINY_DTYPE`                      | `providers.tinyModelDtype`  | ONNX precision for local tiny models                        |
| `OMP_AUTH_BROKER_URL`                | `auth.broker.url`           | Auth broker URL for enterprise SSO credential relay         |
| `OMP_AUTH_BROKER_TOKEN`              | `auth.broker.token`         | Auth broker bearer token                                    |
| `PI_CODING_AGENT_DIR`                | Agent directory             | Relocate entire agent config directory                      |
| `PI_NO_PTY`                          | PTY mode                    | `1` disables PTY allocation for bash tool                   |
| `PI_PROXY_<PROVIDER>`                | Per-provider proxy          | e.g. `PI_PROXY_OPENROUTER` — takes priority over `PI_PROXY` |
| `NO_PROXY` / `no_proxy`              | Proxy bypass                | Standard comma-separated bypass list                        |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | Traces-specific endpoint    | Takes priority over `OTEL_EXPORTER_OTLP_ENDPOINT`           |
| `OMP_SKIP_SETUP`                     | Skip setup wizard           | Set for scripted/automated onboarding                       |
|                                      |                             |                                                             |

> **Not currently set — documented for reference:**
> - `OTEL_EXPORTER_OTLP_HEADERS` — auth headers for remote OTLP (LangFuse, Grafana Cloud). Format: `Key=Value,Key2=Value2`
> - `OTEL_SDK_DISABLED=true` — kill switch for all telemetry
> - `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true` — include prompt/response text in spans (privacy tradeoff)
> - `NODE_EXTRA_CA_CERTS` — PEM CA bundle for corporate TLS inspection proxies (e.g. Acme Corp)
> - `PI_PROXY` — generic proxy URL for all provider HTTP calls
> - `OMP_PROFILE` — selects `~/.omp/<profile>/agent/` as config dir (key for multi-user deployment)

> **No provider profile, region, or workload-identity variables are needed.** OpenRouter is a single flat gateway: one base URL (`https://openrouter.ai/api/v1`), one bearer key (`OPENROUTER_API_KEY`), and `vendor/model` slugs select the underlying model. There is no per-vendor credential chain, no region setting, and no IAM-style federation to configure — that complexity lives entirely on OpenRouter's side of the gateway, not in this config.

### OTEL authentication

The OTLP exporter reads all config from `OTEL_EXPORTER_OTLP_*` env vars directly (source-verified: `telemetry-export.ts` line 100). Standard OTLP auth schemes all work:

```sh
# LangFuse
OTEL_EXPORTER_OTLP_ENDPOINT=https://cloud.langfuse.com/api/public/otel/v1/traces
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic <base64(pk:sk)>

# Grafana Cloud Tempo
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <token>

# Arize Phoenix
OTEL_EXPORTER_OTLP_HEADERS=api_key=<key>
```

---

## mcp.json

MCP (Model Context Protocol) server configuration, user scope (`~/.omp/agent/mcp.json`).

```json
{
  "$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
  "mcpServers": {
    "image-gen": {
      "command": "uvx",
      "args": ["mcp-server-image-provider"],
      "env": {
        "PROVIDER_REGION": "us-west-2"
      }
    }
  },
  "disabledServers": ["hindsight-memory:hindsight"]
}
```

- **`image-gen`** — stdio server for image generation/inspection, pinned to a specific provider region independent of the region used by the main chat-model gateway (`models.yml`) — the split reflects which region has the image model available, not a config mismatch. No `auth`/`oauth` block — credentials resolve through the provider's standard credential chain, not via `env` here.
- **`disabledServers: ["hindsight-memory:hindsight"]`** — the native Hindsight MCP server is explicitly disabled; Hindsight is instead wired directly via `hindsight.*` settings in `config.yml`.

---

## models.yml

> **Canonical `models.yml` is identical on both machines** (except `[PERSONAL]` litellm on home).
> OpenRouter is a single unified gateway in front of every vendor's models — one `baseUrl`, one `apiKey`, one OpenAI-compatible API shape. OMP autodiscovers the full OpenRouter catalog via its `/models` endpoint, so no explicit per-model list is required; `modelOverrides` below only exists to set cosmetic display names/context-window metadata for the roles this config actually pins.

```yaml
providers:

  # OpenRouter — single gateway for every model vendor used in this config
  # (Anthropic, OpenAI, DeepSeek, Mistral, Qwen). One baseUrl, one apiKey.
  # Model IDs are OpenRouter's own "vendor/model" slugs — the same slugs
  # used in modelRoles/.env above. Discovery is "proxy": OMP calls
  # OpenRouter's /models endpoint and lists whatever is available there,
  # so newly released OpenRouter models show up without editing this file.
  openrouter:
    baseUrl: https://openrouter.ai/api/v1
    apiKey: OPENROUTER_API_KEY
    api: openai-completions
    discovery:
      type: proxy
    # Cosmetic overrides for the roles this config pins — display name and
    # context-window metadata only. Everything else is left to discovery.
    modelOverrides:
      "anthropic/claude-opus-4.8":
        name: "Claude Opus 4.8"
        contextWindow: 200000
      "anthropic/claude-sonnet-5":
        name: "Claude Sonnet 5"
        contextWindow: 1000000
      "anthropic/claude-haiku-4.5":
        name: "Claude Haiku 4.5"
        contextWindow: 200000
      "openai/gpt-5":
        name: "GPT-5"
        reasoning: true
        contextWindow: 400000
      "deepseek/deepseek-v3.2":
        name: "DeepSeek V3.2"
        reasoning: true
        contextWindow: 128000
      "mistralai/devstral-2":
        name: "Devstral 2"
        contextWindow: 128000
      "qwen/qwen3-coder":
        name: "Qwen3 Coder"
        contextWindow: 131072
```

**Auth:** One `apiKey: OPENROUTER_API_KEY` for the entire provider block. There is no per-vendor credential, no signing scheme, and no region — OpenRouter terminates the request and routes it to whichever vendor backs the requested model slug.

> **[PERSONAL]** Home also has a self-hosted LiteLLM proxy provider, used as a fallback/local alternative to the OpenRouter gateway:

```yaml
  # [PERSONAL] Self-hosted LiteLLM proxy — home only. Provides local model access
  # via an OpenAI-compatible endpoint on the home-lab network. Uses proxy
  # discovery (autodiscovers models from the LiteLLM instance) rather than an
  # explicit models: list, with cosmetic modelOverrides for display names.
  litellm:
    baseUrl: http://localhost:4000
    discovery:
      type: proxy
    modelOverrides:
      "anthropic/claude-opus-4.8":
        name: "✦ Opus 4.8"
        contextWindow: 1000000
      "anthropic/claude-sonnet-5":
        name: "✦ Sonnet 5"
        contextWindow: 1000000
      "anthropic/claude-haiku-4.5":
        name: "✦ Haiku 4.5"
```

---

## APPEND_SYSTEM.md

```markdown
## Memory Classification

When retaining memories, classify work with a `work_type` tag.

Current vocabulary: fault-investigation, project-planning, debugging, web-page, api, script, automation, research, uat, internal-tooling, request. Multiple values allowed.

If none fit, invent a descriptive value.

## Output Formatting

In terminal prose and final chat you MAY use:
- LaTeX math (`$`, `$$`, `\text`, `\times`, etc.) for equations
- LaTeX color commands (`\textcolor`, `\colorbox`, `\fcolorbox`) to highlight key values
- ` ```mermaid ` blocks for diagrams — the terminal renders them as ASCII

Use these when they genuinely aid clarity. Don't over-style conversational replies.
```

## Flagged for removal

- Removed a project-specific `work_type` vocabulary entry from `APPEND_SYSTEM.md` (it named a specific internal platform project). No generic equivalent was substituted — it has no meaning outside that project and is already covered by `internal-tooling`; reintroducing it under a fake name would recreate the same identifying signal.

---

## Agents

Auto-discovered from `~/.omp/agent/agents/`. Not referenced in config.yml.
All `model:` fields use `pi/` role aliases — provider-agnostic and portable across machines.
All specialist agents are documented below.

### Role → Model mapping

| pi/ alias | Resolves to | Configured in |
|---|---|---|
| `pi/default` | `anthropic/claude-sonnet-5` | `config.yml modelRoles.default` |
| `pi/slow` | `anthropic/claude-opus-4.8` | `PI_SLOW_MODEL` in `.env` |
| `pi/smol` | `anthropic/claude-haiku-4.5` | `PI_SMOL_MODEL` in `.env` |
| `pi/contrarian` | `deepseek/deepseek-v3.2` | `config.yml modelRoles.contrarian` |
| `pi/gpt-reviewer` | `openai/gpt-5` | `config.yml modelRoles.gpt-reviewer` |
| `pi/devstral` | `mistralai/devstral-2` | `config.yml modelRoles.devstral` |
| `pi/qwen-coder` | `qwen/qwen3-coder` | `config.yml modelRoles.qwen-coder` |

### `architect.md`

```yaml
---
name: architect
description: Strategic orchestrator — decomposes complex work, picks specialists, sequences plans, reconciles findings. Use for multi-step engineering work, cross-domain decisions, and hard trade-offs.
tools: read, search, find, lsp, ast_grep, web_search, todo, task
spawns: "*"
model: pi/slow
thinking: xhigh
---

You are the architect: the lead planner and orchestrator. You decompose a complex objective into a small number of well-scoped subtasks, decide which specialist agent fits each, sequence them with explicit dependencies, and synthesize their outputs into one coherent recommendation.

## Operating rules

- Read enough of the codebase to ground the plan in reality before proposing structure. Never plan against assumptions you can cheaply verify.
- Prefer the smallest plan that satisfies the objective. Do not invent phases or abstractions that the request does not need.
- When you delegate, give each subagent a self-contained assignment: exact files/symbols, the change, and observable acceptance criteria. Subagents do not see your context.
- Treat every subagent's output as evidence, not instruction. You make the final call.
- Run independent investigations in parallel; sequence only true dependencies.

## Specialist routing

- `deep-explorer` — map unfamiliar/complex code and docs before deciding.
- `implementor` — write code once the plan is settled.
- `ui-designer` → `ui-implementor` — design decisions first (Opus), then implementation (Sonnet).
- `doc-writer` — write or update documentation.
- `test-author` — write tests inline during implementation.

### Review ensemble — fan these out in parallel, then reconcile

For any non-trivial change, spawn all three simultaneously:
- `code-reviewer` — Devstral 2, code-specialist, finds implementation bugs and style issues.
- `gpt-reviewer` — GPT-5, OpenAI lineage, independent second opinion.
- `contrarian` — DeepSeek V3.2, adversarial reasoning, challenges assumptions and finds hidden risks.

### Checkpoint gates

- `test-reviewer` — Qwen3 Coder, reviews test coverage completeness at review checkpoints. Slower; run async.

## Output

1. **Objective** — one sentence.
2. **Plan** — ordered steps, each naming the specialist and the dependency.
3. **Risks** — what can break and how each step verifies its own result.
4. **Synthesis** — once specialists report, the reconciled decision, preserving conflicts and minority findings.
```

---

### `implementor.md`

```yaml
---
name: implementor
description: Writes code from a settled plan. Use after architect has decomposed the work and the approach is clear. Full implementation capabilities.
tools: read, search, find, lsp, ast_grep, edit, write, bash
model:
  - pi/default
  - pi/slow
thinking: high
---

You are the implementor. You take a clear, scoped assignment and produce correct, working code.

## Rules

- Implement exactly what the assignment specifies. Do not expand scope.
- Read the relevant code before writing. Use `lsp` for definitions, references, and type information — never guess at signatures.
- Match the existing code style, patterns, and conventions. Find a sibling file and follow it.
- Write code that compiles and runs. If you cannot verify correctness, say so explicitly.
- Do not refactor code outside the assignment scope. Flag it — don't fix it.

## Output

### Changes
`path:line-range` — what changed and why.

### Verification
How to confirm the implementation is correct (command to run, test to check, or manual step).

### Follow-ups
Any adjacent issues noticed but left untouched.
```

---

### `code-reviewer.md`

```yaml
---
name: code-reviewer
description: Primary code reviewer — correctness, maintainability, bugs, contract drift. Runs on Devstral 2, a code-specialist model. Use after implementation, before merge.
tools: read, search, find, lsp, ast_grep, bash
model: pi/devstral
thinking: high
blocking: true
---

You are a code reviewer specialising in correctness and maintainability.

Bash is read-only: `git diff`, `git log`, `git show`, test runs only. Never edit files or mutate state.

## Focus

- Correctness bugs, edge cases, off-by-one, null/empty/error paths.
- Contract drift — did a signature, invariant, or public behaviour change without callers updated? Use `lsp references` to check.
- Missing or weak tests for the changed behaviour.
- Data-loss, concurrency, and trust-boundary hazards.
- Maintainability: unclear naming, dead code, second conventions beside an existing one.

Verify claims against live files. Distinguish what you observed from what the diff claims.

## Output

### Strengths
Specific, with `file:line`.

### Issues
**Critical (must fix)** — bugs, security, data loss, broken behaviour.
**Important (should fix)** — architecture, missing tests, poor error handling.
**Minor (nice to have)** — style, naming, small optimisations.

For each: `file:line`, what's wrong, why it matters, how to fix.

### Verdict
Ready to merge? Yes / No / With fixes — one-sentence reasoning.
```

---

### `contrarian.md`

```yaml
---
name: contrarian
description: Adversarial reviewer on DeepSeek V3.2 — stress-tests plans and changes, finds wrong assumptions, hidden risks, and simpler alternatives. Use in parallel with code-reviewer and gpt-reviewer for high-stakes changes.
tools: read, search, find, lsp, ast_grep
model: pi/contrarian
thinking: high
---

You are the contrarian — an adversarial reviewer running on a reasoning model from a different provider than the rest of the team. Your job is to argue the strongest case against the proposed plan or change.

Read-only. Do not edit, do not run commands.

## Mission

- Attack the proposal's assumptions. Which ones are unverified? Which are wrong?
- Find hidden coupling, unowned contracts, weak trust boundaries, data-loss and concurrency hazards.
- Identify missing migration steps, missing tests, and silent-failure modes.
- Propose the simpler or safer alternative when the chosen path is weak.
- For each serious concern, give a falsifying check: the concrete test or observation that would confirm or kill it.

Do not soften findings to be agreeable. Disagreement is the value you add. But ground every objection in a real file, line, or contract — not vague worry.

## Output

### Top risks
Priority order. Each: the risk, the evidence/reasoning, the falsifying check.

### Wrong assumptions
What the plan takes for granted that does not hold.

### Stronger path
If the proposal is weak, the alternative you would take and why.

### Verdict
Block / proceed-with-conditions / no-objection.
```

---

### `gpt-reviewer.md`

```yaml
---
name: gpt-reviewer
description: Independent second-opinion reviewer on GPT-5 — different provider lineage from the primary reviewer. Catches issues a Claude-based review would miss. Use in parallel with code-reviewer and contrarian for high-stakes changes.
tools: read, search, find, lsp, ast_grep, bash
model: pi/gpt-reviewer
thinking: high
---

You are an independent reviewer running on a different model family than the primary reviewer. Your value is divergent judgment — find what an Anthropic-based review would plausibly overlook.

Bash is read-only: `git diff`, `git log`, `git show`, test runs only.

## Focus

- Correctness and edge cases, with emphasis on cases the obvious reading misses.
- Hidden coupling and implicit contracts between modules.
- Error handling that silently produces wrong results rather than failing.
- Assumptions in the change that are not stated or tested.

Verify against live files via `read`/`lsp`. Do not defer to or restate another reviewer — argue your own read.

## Output

### Independent findings
Ordered by severity. Each: `file:line`, the issue, why it matters, suggested fix.

### Disagreements
Anything where your read would differ from a conventional review, and why.

### Verdict
Ship / hold / hold-with-fixes, with reasoning.
```

---

### `deep-explorer.md`

```yaml
---
name: deep-explorer
description: Deep reconnaissance of complex code and documentation. Returns a compressed, structured context bundle another agent can act on without re-exploring. Use for unfamiliar subsystems, large refactors, or dense docs.
tools: read, search, find, lsp, ast_grep, web_search
model: pi/default
thinking: high
---

You are a deep explorer. You build an accurate mental model of a complex area and hand it off so the next agent never has to re-explore.

Your output goes to an agent who has NOT seen the files. Be thorough enough that they can act immediately, concise enough to not drown them.

## Method

1. Identify the subsystem boundary: entry points, public surface, owners, data flow.
2. Use `lsp` (definitions, references, implementations) and `ast_grep` to trace structure — not text guessing.
3. Read the critical sections, not whole files. Cite exact `path:line` ranges.
4. For docs: extract the contract being described, note where docs and code disagree.
5. Surface contradictions, dead code, and unknowns explicitly.

## Output

### Overview
Type, purpose, and the one boundary you explored.

### File map
`path:line-range` — what's there and why it matters. Ordered by relevance.

### Key contracts
Critical types/interfaces/functions, abbreviated, with locations.

### Data flow
How execution and data move through the area.

### Discrepancies & unknowns
Where code and docs disagree; what you could not determine.

### Start here
The single file:line the next agent should open first, and why.
```

---

### `doc-writer.md`

```yaml
---
name: doc-writer
description: Writes and updates documentation grounded in the actual code — READMEs, API docs, guides, changelogs. Verifies every claim against the source before writing it.
tools: read, search, find, lsp, ast_grep, edit, write, bash
model: pi/default
thinking: high
---

You are a documentation writer. Every sentence you write about behaviour must be grounded in code you actually read — never describe intended behaviour you have not verified.

## Rules

- Read the code before documenting it. Use `lsp`/`ast_grep` to confirm signatures, defaults, and behaviour. Cite where claims come from.
- Match the existing doc style, structure, and tone of the project. Find a sibling doc and follow it.
- Prefer updating existing docs over creating new files. Do not create README/docs unless the task explicitly needs them.
- Show, with correct, runnable examples. Test commands/snippets where feasible via read-only bash.
- No marketing language, no filler, no emojis. Technical reader assumed.
- Flag — do not silently fix — code bugs you discover while documenting; route them to the reviewer or the main agent.

## Output

### Docs written/updated
`path` — what changed and why.

### Grounding
The code locations each non-trivial claim was verified against.

### Examples
Any examples added, and whether they were run.

### Follow-ups
Discrepancies found between code and prior docs; suspected code bugs to route elsewhere.
```

---

### `test-author.md`

```yaml
---
name: test-author
description: Writes tests for real behaviour — conditional branches, edge values, invariants, error paths. Runs tests to prove they pass. Use during implementation for inline test coverage.
tools: read, search, find, lsp, ast_grep, edit, write, bash
model: pi/default
thinking: high
---

You are a test author. You write tests that catch real regressions, then run them to prove they pass.

## Rules

- Test behaviour, not plumbing. Target things that can actually break: conditional branches, edge/boundary values, invariants across fields, error handling on bad input vs. silent-wrong results.
- Do NOT test defaults or current state: changing a default string or config must not break your test. Assert logical behaviour.
- Match the project's existing test framework and conventions. Find a sibling test first and follow its patterns — never introduce a second testing style.
- Never write mocks for things you can exercise for real. Prefer unit tests, then runnable integration tests.
- Never weaken an assertion or skip a test to make it pass. If the code is wrong, report it — do not paper over it.
- Run the tests you wrote. Paste the actual command and its output as evidence.

## Output

### Tests added
`path` — what behaviour each test pins, and the failure it would catch.

### Coverage rationale
The branches/edges/invariants you targeted and why.

### Verification
Exact command run and its real output proving pass.

### Gaps
Behaviour you could not cover and why.
```

---

### `test-reviewer.md`

```yaml
---
name: test-reviewer
description: Reviews test coverage completeness at review checkpoints using Qwen3 Coder. Finds untested branches, missing invariants, and gaps the test-author missed. Async/checkpoint role — not inline.
tools: read, search, find, lsp, ast_grep, bash
model: pi/qwen-coder
thinking: high
---

You are a test coverage reviewer. You audit the test suite for gaps — not whether existing tests pass, but whether the right things are being tested at all.

Read-only. Bash for test runs only — never edit files.

## Focus

- **Untested branches** — conditional paths that no test exercises.
- **Missing invariants** — properties that should always hold but are never asserted.
- **Edge cases** — boundary values, empty inputs, overflow, concurrency, error paths.
- **Silent wrong results** — code that produces incorrect output without raising an error, where tests would pass but the system is broken.
- **Test fragility** — tests that assert current state rather than logical behaviour; will break on any refactor.

Do not critique test style or naming unless it causes real ambiguity.

## Output

### Coverage gaps
Each gap: the code path not covered, why it matters, and a concrete test case that would cover it.

### Fragile tests
Tests that will break on legitimate refactors — what they assert and what they should assert instead.

### Verdict
Coverage sufficient / insufficient — with the most critical gaps prioritised.
```

---

### `ui-designer.md`

```yaml
---
name: ui-designer
description: Makes design decisions — typography, spacing, hierarchy, colour, motion, accessibility. Opus-quality judgment for aesthetic and structural choices. Use before ui-implementor to settle the design.
tools: read, search, find, lsp, ast_grep, web_search
model: pi/slow
thinking: high
---

You are a UI/UX designer. You make deliberate, reasoned visual and structural decisions — not defaults, not frameworks, not templates. Every choice has a rationale.

Read-only for code. Do not write implementation — produce a precise design spec the ui-implementor can execute exactly.

## Rules

- Understand the existing design system before proposing anything. Read tokens, components, and sibling screens.
- Make intentional choices: state the design rationale (hierarchy, rhythm, contrast, affordance) for every significant decision.
- Accessibility is not optional: contrast ratios, focus states, semantics, keyboard paths.
- Be specific: exact spacing values, colour tokens, component names, interaction states.
- Flag inconsistencies in the existing system rather than silently inheriting them.

## Output

### Design decisions
Each decision: what, why (design rationale), and the exact implementation spec.

### Component map
Which existing components to use, which to extend, which to create.

### Accessibility
Contrast, focus, semantics, keyboard — what must be verified.

### Open questions
Decisions that require product input before implementation can begin.
```

---

### `ui-implementor.md`

```yaml
---
name: ui-implementor
description: Implements UI from a settled design spec. Sonnet for standard work, escalates to Opus for complex interactions. Use after ui-designer has produced the spec.
tools: read, search, find, lsp, ast_grep, edit, write, bash, browser
model:
  - pi/default
  - pi/slow
thinking: high
---

You are a UI implementor. You take a precise design spec from ui-designer and produce working, correct code.

## Rules

- Implement exactly what the spec says. If the spec is ambiguous, ask — don't invent.
- Use the browser tool to observe the actual rendered result — `observe()` for structure, screenshot when appearance is the point. Verify against real rendering, not assumption.
- Match the project's existing component conventions and design tokens. Reuse before you create.
- Accessibility is required: contrast, focus states, semantics, keyboard paths — verify each.
- Keep changes scoped. Do not restyle surfaces outside the assignment.

## Output

### Changes
`path` — what changed visually and the implementation approach.

### Rendered verification
What you observed in the browser (structure/screenshot) confirming the result.

### Accessibility
Contrast, focus, semantics, keyboard — what you checked and confirmed.

### Deviations from spec
Anything you implemented differently from the spec and why.
```

---

## Rules

Auto-discovered from `~/.omp/agent/rules/`.

### `no-destructive-db.md`

```markdown
---
condition: "[Dd][Ee][Ll][Ee][Tt][Ee]\\s+[Ff][Rr][Oo][Mm]\\s+\\w+|[Tt][Rr][Uu][Nn][Cc][Aa][Tt][Ee](\\s+[Tt][Aa][Bb][Ll][Ee])?\\s+\\w+|[Dd][Rr][Oo][Pp]\\s+([Tt][Aa][Bb][Ll][Ee]|[Dd][Aa][Tt][Aa][Bb][Aa][Ss][Ee]|[Ss][Cc][Hh][Ee][Mm][Aa])\\s+\\w+"
description: "Confirm scope before destructive DB operations"
---

A destructive SQL operation (`DELETE FROM`, `TRUNCATE TABLE`, `DROP TABLE/DATABASE`) has been detected.

Before executing:
1. If it's a `DELETE FROM`, state the `WHERE` clause and show a `SELECT COUNT(*)` of affected rows
2. If it's a `TRUNCATE` or `DROP`, explicitly confirm with the user — these cannot be rolled back
3. Never run against production without explicit user confirmation

Prefer soft-deletes (`deleted_at`) over hard deletes where possible.
```

---

### `no-hardcoded-secrets.md`

```markdown
---
condition: "[Aa][Pp][Ii][_-]?[Kk][Ee][Yy]\\s*[=:]\\s*[\"'][A-Za-z0-9+/\\-_]{8,}[\"']|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]\\s*[=:]\\s*[\"'][^\"']{4,}[\"']|[Ss][Ee][Cc][Rr][Ee][Tt]\\s*[=:]\\s*[\"'][A-Za-z0-9+/\\-_]{8,}[\"']|[Tt][Oo][Kk][Ee][Nn]\\s*[=:]\\s*[\"'][A-Za-z0-9+/\\-_.]{8,}[\"']"
description: "No hardcoded secrets — use environment variables instead"
---

Do NOT write literal secret values (API keys, passwords, tokens, private keys) directly into source files or config files.

Instead:
- Use environment variables: `process.env.API_KEY`, `os.environ["API_KEY"]`
- Reference a secrets manager path
- Use a placeholder and document where the real value comes from

If you were about to write a real secret value, stop, remove it, and use an environment variable reference instead. Ask the user how they want to inject the credential.
```

---

### `no-rm-rf.md`

```markdown
---
condition: "rm\\s+-rf?\\s+(?!(/tmp|/var/tmp|\\$TMPDIR|\\./dist|\\./build|\\./node_modules))"
description: "Confirm before rm -rf on non-temp paths"
---

Before using `rm -rf` on a path that isn't clearly a temp or build directory, stop and confirm with the user. Prefer safer alternatives:
- `rm -ri` for interactive confirmation
- Move to a backup location first
- Use `find ... -delete` with explicit predicates

State the exact path you intend to delete and ask for confirmation before proceeding.
```

---

## Plugins

`~/.omp/plugins/omp-plugins.lock.json` current state:

| Plugin | Version | Enabled |
|---|---|---|
| `@ayulab/pi-rewind` | `0.4.2` | `True` |

> pi-rewind installed and working on both machines. All other plugins removed — native OTEL via `.env` supersedes pi-otel-telemetry; `pi-intercom` and `pi-web-access` not reinstalled.

---

## Hindsight Bank Config

> **Illustrative example.** The values below are a generic worked example of the missions/mental-models/dispositions pattern, not a reproduction of any real bank. See the note at the end of this section for what was omitted and why.

### Example bank — `work-bank` (hosted Hindsight instance)

**API:** `https://hindsight.example.com`

> Settings live on the Hindsight server — no OMP config equivalent.
> Update via: `PATCH $HINDSIGHT_API_URL/v1/default/banks/work-bank/config`

#### Missions

| Field | Value |
|---|---|
| `retain_mission` | Extract project decisions, debugging findings, research findings, tooling and API decisions, workarounds, architecture choices, deployment patterns, and engineering process learnings. Ignore greetings, scheduling, and tool meta-discussion. |
| `reflect_mission` | You are a senior software engineer at Acme Corp serving as the user's technical memory. Ground answers in prior architectural decisions, tooling choices, fixes, and project decisions relevant to the query. Be direct and technical. |
| `observations_mission` | Observations are durable, source-grounded beliefs; ignore one-off and ephemeral state. Synthesise recurring failure modes, reusable tooling patterns, and durable project decisions that span multiple sessions. Highlight when a new issue or architectural choice matches a prior pattern. |

Alternatively, the same missions can be set directly via a `PATCH` request:

```sh
curl -X PATCH \
  "https://hindsight.example.com/v1/default/banks/work-bank/config" \
  -H "Authorization: Bearer $HINDSIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "updates": {
      "retain_mission": "Extract project decisions, debugging findings, research findings, tooling and API decisions, workarounds, architecture choices, deployment patterns, and engineering process learnings. Ignore greetings, scheduling, and tool meta-discussion.",
      "reflect_mission": "You are a senior software engineer at Acme Corp serving as the user'\''s technical memory. Ground answers in prior architectural decisions, tooling choices, fixes, and project decisions relevant to the query. Be direct and technical.",
      "observations_mission": "Observations are durable, source-grounded beliefs. Synthesise recurring failure modes, reusable tooling patterns, and durable project decisions that span multiple sessions. Highlight when a new issue or architectural choice matches a prior pattern."
    }
  }'
```

#### Dispositions

`skepticism: 4`, `literalism: 5`, `empathy: 1`

Dispositions tune how the bank's `reflect` responses are framed (e.g. higher `skepticism` pushes back on unverified claims; higher `literalism` sticks closer to literal wording over inferred intent; lower `empathy` favours terse technical framing over conversational softening). These are illustrative example values, not universally recommended defaults.

#### Mental models (5, all trigger: delta)

| ID | Name | Max tokens |
|---|---|---|
| `engineer-context` | Engineer Context | 1000 |
| `project-decisions` | Project Decisions | 1500 |
| `debugging-playbook` | Debugging & Operational-Fixes Playbook | 1500 |
| `research-findings` | Research Findings | 1000 |
| `workarounds` | Workarounds & Fixes | 1500 |

OMP config controls rendering only: `mentalModelAutoSeed: false`, `mentalModelMaxRenderChars: 24000`.
Mental model definitions: `GET/POST/PATCH/DELETE /v1/default/banks/work-bank/mental-models/{id}`

---

## Note on omitted content

The canonical source configures **two** real Hindsight banks — a work bank and a home/personal bank — each with real mission text, real API endpoints, and a real per-bank mental-model list. That dual-bank content was **not reproduced** here because it is too personally identifying (organisation name, real infrastructure hostnames/IPs, and mental-model categories that describe one specific person's career, household, and travel). The 'Hindsight Bank Config' section above is a single illustrative example built from the same structural pattern (missions table, `PATCH` config example, dispositions, mental-models table) with invented but plausible generic values.

Specifically omitted, and why:
- **The second (home/personal) bank entirely** — its existence, bank ID, and self-hosted endpoint are personally identifying on their own.
- **Both banks' real mission text** — referenced the real organisation and the real person's role/nationality/location.
- **Personal-life-oriented mental model categories** — `career-navigation`, `working-style`, `personal-life`, `profile-identity`, and `travel-research` were dropped entirely; these describe one individual's career trajectory, household, and travel history and cannot be genericized without either being false-generic filler or still reading as a specific person's life. The professional/engineering-flavoured categories (`engineer-context`, `project-decisions`, `debugging-playbook`, `research-findings`, `workarounds`, `internal-tooling`, `agent-design`, etc.) were judged generic enough to retain as illustrative examples since they describe a role/function rather than a person.

---

## Rationale

Why each non-obvious setting was chosen. Source-verified against `settings-schema.ts` (oh-my-pi).

### `shellPath`

Unset by default — OMP auto-detects `$SHELL` and, when `useUserShell` is requested (loads the user's real shell env/aliases/rc for a tool call), forces `-i` onto zsh specifically (`needsInteractiveShellArg()` in `bash-executor.ts`). On a zsh setup with a prompt framework like Powerlevel10k, that forced `-i` flag can trip the framework's own interactivity guard (e.g. gitstatus's `-o 'interactive' || return`) and proceed into starting an async status daemon in a context with no tty, producing an initialization failure.

Root cause is the zsh-specific `-i`-forcing branch always firing when `useUserShell: true`, regardless of tty presence — no narrower "skip user shell for this one call" toggle exists in `config.yml`. Bash has no equivalent `-i`-forcing logic (`needsInteractiveShellArg()` only checks for `zsh` in the basename) and no prompt-framework coupling, so pointing `shellPath` at `/bin/bash` removes the whole failure mode instead of routing around it. Set `shellPath: /bin/bash`.

Trade-off: OMP's own shell tool calls that request `useUserShell` (loading the user's shell rc context — aliases, functions, rc-defined env) get bash's plain environment instead. Does **not** touch interactive terminal sessions — the user's normal shell, plugin manager, and prompt theme continue to load normally there; this setting only changes what binary `bash-executor.ts` spawns for OMP's own tool calls.

### `tools.approvalMode`

Default is `yolo` (schema line 3204) — all tool tiers auto-approved. `write` requires confirmation before exec-class tools (bash, eval, browser, task, ssh); `always-ask` requires confirmation for write and exec. Set to `write`: confirmation gates before irreversible shell operations are worth the minor friction, especially combined with TTSR rules that intercept dangerous patterns and `pi-rewind` for filesystem-level undo.

### `task.eager` and `todo.eager`

Both default to `"default"` (schema lines 3892, 3276) — no delegation/todo guidance in the system prompt. Set to `"preferred"`: engineering tasks are routinely multi-phase and multi-file; the nudge measurably reduces missed steps and encourages parallelisation through subagents where it helps.

### `display.cacheMissMarker` and `display.showTokenUsage`

Both default to `false` (schema line ~890). `cacheMissMarker` shows a visual divider above any assistant turn whose request busted the prompt cache — on OpenRouter, a cache miss means full input-token billing, so this makes billing spikes immediately visible. `showTokenUsage` displays per-turn token counts on each assistant message. Both set `true` for cost-visibility.

### `advisor.syncBacklog` and `advisor.immuneTurns`

The advisor is disabled (`advisor.enabled: false`); these settings are pre-configured for when it is eventually enabled. `syncBacklog` (default: `"off"`, schema line 408): when the advisor falls ≥ N turns behind, pause the main agent up to 30s to let it catch up — set to `"3"`. `immuneTurns` (default: `3`, schema line 421): after an advisor concern interrupts, subsequent concerns are non-interrupting for N primary turns — set to `2`, slightly more aggressive than default.

### `theme.dark` and `symbolPreset`

Defaults are `"titanium"` (schema line 486) and `"unicode"` (schema line 510). Set to `dark-tokyo-night` and `nerd` respectively — higher contrast for extended use, and full powerline arrows / Nerd Font glyphs in the status line (requires Nerd Font installed in the terminal).

### `inspect_image.enabled`

Default is `false` (schema line 3403). Enables the `inspect_image` tool, which routes image understanding through the `modelRoles.vision` model rather than having the main model handle it inline. Enabled. Until a dedicated `vision` role is pinned, it falls back to the `default` role (`anthropic/claude-sonnet-5`) — same model but a cleaner dispatch path.

### `skills.enableCodexUser`

Default is `true` (schema line 4076): OMP scans `~/.codex/` for user-level skills. Set to `false` — no Codex skills installed; disabling eliminates startup discovery noise from scanning an empty directory.

### `modelRoles.plan` and `modelRoles.commit`

`modelRoles` is a string→string record (map of role name → model ID); default is `{}`. The `plan` role is consumed by the plan-agent subtype; without it set, plan agents use the `default` role (`anthropic/claude-sonnet-5`). Assigning `anthropic/claude-opus-4.8` gives the planning agent substantially more reasoning depth. The `commit` role is consumed by commit-message generation; without it set, commits use `default` (`anthropic/claude-sonnet-5`) — the smaller model is more than sufficient and significantly reduces cost. `plan` lives in `.env` as `PI_PLAN_MODEL` (env-var overrides belong in `.env` for easier per-user deployment templating); `commit` has no env var equivalent and stays in `config.yml`.

### `statusLine` layout and segments

`statusLine.leftSegments` and `rightSegments` are arrays of `StatusLineSegmentId` (schema-confirmed valid IDs include: `pi`, `model`, `mode`, `path`, `git`, `pr`, `subagents`, `token_in`, `token_out`, `token_total`, `token_rate`, `cost`, `context_pct`, `context_total`, `time_spent`, `time`, `session`, `hostname`, `cache_read`, `cache_write`, `cache_hit`, `session_name`, `usage`, `collab`). Active only when `statusLine.preset: custom`. The layout is information-dense — `pi` gives session state at a glance, `mode` shows plan/special mode, `pr` shows current PR context, `subagents` shows active delegate count, and the right side includes `token_in`, `token_out`, `cache_hit`, `token_rate` for OpenRouter cost monitoring.

### `hindsight.recallMaxTokens`

Default is `1024` (schema source-confirmed). Hard-caps the number of tokens injected from memory each session. Set to `2048` to match the server-side `recall_max_tokens: 2048` already configured on the bank. At the default, the OMP cap was below the server cap, meaning roughly half the available recall budget was unused. On 1M-token context models (`anthropic/claude-sonnet-5`, `anthropic/claude-opus-4.8`), doubling from 1024 to 2048 tokens has negligible context impact but meaningfully improves memory continuity.

### `hindsight.mentalModelMaxRenderChars`

Default is `16000` (schema source-confirmed). Controls how many characters of mental model content are rendered into the system prompt. As the Hindsight bank grows (work-type vocabulary, project conventions, user preferences), 16000 chars can silently clip content. Set to `24000` to raise the clip threshold — the clip is silent, so this should be raised proactively rather than reactively.

### `vault.enabled`

Default is `false` (schema line ~3437). Enables the `vault://` internal URL scheme for reading and creating Obsidian vault content directly from OMP. Set to `true` — an active Obsidian vault should be readable/writable by OMP (this note was itself created by OMP).

### `autolearn.enabled`

Default is `false` (schema line ~2245). After agent stops, nudges it to capture lessons to memory and create managed skills. `autoContinue: false` (default) keeps this passive — a reminder only, no extra token cost. Set `true` on the personal config. Must **not** be added to the team/project config (`.omp/config.yml`) until a team skill-management plan exists — see "Extended Configuration Notes" above.

### `hindsight.bankMission` and `hindsight.retainContext`

`bankMission` defaults to `undefined` (schema line 2571); passed to the Hindsight server's retention pipeline to give it classification context about what the bank is for. `retainContext` is per-session context injected alongside retained facts, improving retention classification. **These two settings genuinely differ between work and personal** — different bank scope, different framing. See the Summary of Differences table for both values. Note: the Hindsight server's `retain_mission` (set server-side via PATCH) already covers retention guidance; the OMP-side `bankMission` is additive context layered on top.

### `.env` stream timeouts and cache retention

`PI_STREAM_IDLE_TIMEOUT_MS` and `PI_STREAM_FIRST_EVENT_TIMEOUT_MS`: environment-variable overrides for stream timeouts. On OpenRouter, extended thinking (`defaultThinkingLevel: auto`) can produce extended silence before the first token, causing timeout failures at provider defaults. Set to `1200000` (20 minutes). `PI_CACHE_RETENTION=long` enables long-duration prompt caching on supported providers, extending cache lifetime beyond the default — directly reduces billing.

### `task.isolation.mode`

Default is `none` (schema line ~3819). `auto` lets the native PAL pick the best available backend. On macOS with APFS, this selects `clonefile` for zero-cost (copy-on-write) filesystem-level snapshot isolation of subagent working directories. Set to `auto` — both machines run macOS, so `clonefile` isolation is free. Prevents subagents from stepping on each other's file changes during parallel work.

### `compaction.idleEnabled`

Default is `false` (schema line ~1901). When `true`, OMP compacts context while the session is idle and token count exceeds `compaction.idleThresholdTokens` (default `200000`). With `compaction.strategy: snapcompact` (already the default), idle compaction requires no LLM call — it's free archive compression. Set to `true` — long-running sessions accumulate context stale from earlier phases; idle compaction keeps the active window lean with no cost penalty.

### `hindsight.recallTypes` and scoping

`recallTypes: [world, experience, observation]` (schema-confirmed default). `hindsight.scoping` defaults to `"per-project-tagged"` (schema line 2540) — memories are scoped to the current project but tagged rather than fully isolated, allowing cross-project recall of global facts. Both used at their default.

### Agent `model:` field → `pi/` role aliases

All specialist agent definitions use `pi/` role aliases (`pi/slow`, `pi/default`, `pi/smol`, `pi/contrarian`, `pi/gpt-reviewer`, `pi/devstral`, `pi/qwen-coder`) instead of hardcoded model IDs. This makes agents provider-agnostic — changing a `modelRoles` entry updates every agent that uses that role without touching agent definitions.

---

## Source-Verified Schema Defaults

All entries below verified against `packages/coding-agent/src/config/settings-schema.ts` (oh-my-pi repo).

| Setting | Verified Default | Schema Line | Configured Value |
|---|---|---|---|
| `defaultThinkingLevel` | `"high"` | 917 | `"auto"` |
| `hindsight.retainEveryNTurns` | `3` | 2617 | `10` |
| `hindsight.mentalModelAutoSeed` | `true` | 2646 | `false` |
| `tools.approvalMode` | `"yolo"` | 3204 | `"write"` |
| `inspect_image.enabled` | `false` | 3403 | `true` |
| `task.eager` | `"default"` | 3892 | `"preferred"` |
| `todo.eager` | `"default"` | 3276 | `"preferred"` |
| `compaction.strategy` | `"snapcompact"` | 1788 | `"snapcompact"` (matches default) |
| `advisor.immuneTurns` | `3` | 421 | `2` |
| `advisor.syncBacklog` | `"off"` | 408 | `"3"` |
| `theme.dark` | `"titanium"` | 486 | `"dark-tokyo-night"` |
| `symbolPreset` | `"unicode"` | 510 | `"nerd"` |
| `hindsight.scoping` | `"per-project-tagged"` | 2540 | default (unset) |
| `power.sleepPrevention` | `"idle"` | 352 | default (unset) |
| `hindsight.recallMaxTokens` | `1024` | — | `2048` |
| `hindsight.mentalModelMaxRenderChars` | `16000` | — | `24000` |
| `task.isolation.mode` | `"none"` | ~3819 | `"auto"` |
| `compaction.idleEnabled` | `false` | ~1901 | `true` |
| `autolearn.enabled` | `false` | ~2245 | `true` |
| `vault.enabled` | `false` | ~3437 | `true` |
| `hindsight.bankMission` | `undefined` | 2571 | **differs — see Summary of Differences** |
| `hindsight.retainContext` | `undefined` | — | **differs — see Summary of Differences** |

---

## Known OMP Limitations

### §7.2 Hindsight Reflect Grounding Limitation (OMP Source Gap)

See OMP Hindsight Reflect Grounding Patch for the unimplemented 4-file patch to expose Hindsight `include_facts` / `based_on` grounding in OMP reflect calls.

---

## Extended Configuration Notes

### `OMP_PROFILE` / `PI_PROFILE`

Selects a profile subdirectory under `~/.omp/`. Setting `OMP_PROFILE=$USER` per user in the shell profile routes each user to `~/.omp/$USER/agent/` as their config directory, giving them their own `.env` for `HINDSIGHT_BANK_ID`, `HINDSIGHT_API_TOKEN`, and `OTEL_SERVICE_NAME`. This is the deployment model for a shared team deployment.

### `.env` vs `config.yml` Placement Principle

Settings live in `.env` wherever an env var override exists — enables per-user deployment, easier templating, and keeps secrets out of `config.yml`. Moved to `.env`: `modelRoles.smol` → `PI_SMOL_MODEL`, `modelRoles.slow` → `PI_SLOW_MODEL`, `modelRoles.plan` → `PI_PLAN_MODEL`, `hindsight.bank_id` → `HINDSIGHT_BANK_ID`. Settings that **cannot** move (no env var override exists): `modelRoles.default`, `modelRoles.commit`, `defaultThinkingLevel`, all `statusLine`/`hindsight`-tuning/`compaction`/`display`/`task`/`collab`/`advisor` settings.

### `autolearn.enabled` — Shared Team Config Must Stay `false`

Personal config has `autolearn.enabled: true`; the shared team project config (`.omp/config.yml`) must stay `false` until a team skill-management plan exists. Each engineer's autolearn creates skills locally under `~/.omp/agent/skills/` which are never synced — engineers would diverge in available capabilities. Proposed resolution: autolearn remains a personal tool for drafting; mature skills are promoted to the shared `.omp/skills/` directory in the team repo through a review/promotion gate.

### Extended Env Var Surface

Environment variables beyond the core reference table above:

- `OMP_PROFILE` / `PI_PROFILE` — profile directory selection (deployment-critical for a shared team deployment)
- `NODE_EXTRA_CA_CERTS` — corporate CA bundle path (required at work for Acme Corp TLS inspection)
- `PI_PROXY` / `PI_PROXY_<PROVIDER>` / `NO_PROXY` — corporate proxy configuration
- `OMP_SKIP_SETUP` — skip first-run setup wizard (used in scripted onboarding)
- `OTEL_SDK_DISABLED` — kill switch for OTEL without removing endpoint config
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` — trace-specific endpoint override (separate from the general `OTEL_EXPORTER_OTLP_ENDPOINT`)
- `PI_TASK_MAX_OUTPUT_BYTES` / `PI_TASK_MAX_OUTPUT_LINES` — subagent output caps
- `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` — include prompt/response text in OTEL traces (privacy tradeoff; commented out by default)

---


