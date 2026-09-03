---
title: "Daily Dev Tools Digest - Cron Job and Scripts"
date_saved: 2026-08-31
tags:
  - reference
  - automation
  - agentic-harnesses
  - multi-agent
  - developer-tools
summary: >
  Full source dump of AgentShadow's "Daily Dev Tools Changelog" OpenClaw cron job:
  the verbatim orchestrator prompt (9-subagent fan-out over GitHub repos + fuzzy
  web scans, watermark-based diffing, JSON-schema-validated synthesis, Telegram
  digest delivery), all 5 Python helper scripts it shells out to, both JSON
  schemas it validates against, and 3 concrete example artifacts (watermark
  state file, one full log entry, one target-history file). Intended as a
  reconstitution kit — everything needed to rebuild this pipeline from scratch
  in a different OpenClaw environment.
technologies:
  - OpenClaw cron (agentTurn / isolated session)
  - uv (PEP 723 inline-dependency Python scripts)
  - GitHub REST API
  - JSON Schema (draft-07) via jsonschema
  - Telegram (announce delivery)
key_concepts:
  - Watermark-based incremental diffing (last-SHA / last-release-tag)
  - Subagent fan-out + polling (not sessions_yield) for isolated cron sessions
  - Schema-validated inter-agent report contracts
  - Append-only markdown log as source of truth + JSON mirror for convenience reads
  - Per-target narrative history for cross-run continuity
status: processed
publish: true
---

# Daily Dev Tools Digest — Cron Job and Scripts

> [!tldr] TL;DR
> This is the complete, verbatim source for AgentShadow's daily dev-tools changelog
> pipeline: one OpenClaw cron job (orchestrator prompt) that fans out to 9 subagents
> checking GitHub repos (oh-my-pi, hindsight, opencode, openclaw, pi, Kiro, Orca) plus
> two fuzzy web scans (Claude Code, broader tooling), backed by 5 Python scripts and
> 2 JSON schemas for watermarking, validation, and append-only logging. Everything
> below is copy-pasteable to rebuild the same pipeline in a fresh environment.

## How to Recreate This in a New Environment

1. **Recreate the directory layout** under the new workspace root:
   - `scripts/` — all 5 `.py` files (sections 2–6 below), plus the 2 schema `.json` files (sections 7–8)
   - `data/` — empty initially; `dev-tools-changelog.md`, `dev-tools-changelog-state.json`,
     `dev-tools-changelog-reports/`, and `dev-tools-target-history/` are all created
     automatically by the scripts on first run (see section 10–11 for the shapes they'll produce)
2. **Copy the 5 scripts verbatim** (sections 2–6) — each is a self-contained `uv run` script
   with no external dependency file beyond what's inline (`validate_json.py` declares
   `jsonschema` via a PEP 723 `# /// script` block; `uv` resolves it automatically).
3. **Copy both schema files verbatim** (sections 7–8) into `scripts/`.
4. **Update all absolute paths** in the cron prompt (section 1) from
   `~/.openclaw/workspace/...` to the new environment's workspace root if it differs.
5. **Update the target list** (Step 2 in the prompt) if the tracked repos/owners have
   changed, or the Telegram `delivery.to` chat/topic id if posting somewhere else.
6. **Recreate the cron job** with the job config table in section 1 (schedule, tools
   allow-list, session target, delivery) and the verbatim `payload.message` as the prompt.
7. **First run is a cold start** — `get_last_watermarks.py` will find no log file, return
   `{}`, and every script-backed target gets `--last-sha none` (48h window fallback).
   This is expected and matches the original first run (see section 11 for what that
   looked like).
8. Everything downstream (log growth, watermark state, target history) self-assembles
   from that point — no manual seeding required.

---

## 1. Cron Job — Orchestrator Prompt

**Job config**

| Field | Value |
|---|---|
| `name` | Daily Dev Tools Changelog |
| `id` | `61786f79-00b2-44e0-ae6a-9b39961b408d` |
| `schedule` | `{ "kind": "cron", "expr": "0 12 * * *", "tz": "Europe/Stockholm" }` |
| `sessionTarget` | `isolated` |
| `wakeMode` | `now` |
| `payload.kind` | `agentTurn` |
| `payload.timeoutSeconds` | `600` |
| `payload.toolsAllow` | `exec`, `read`, `write`, `web_fetch`, `message`, `sessions_spawn`, `subagents`, `sessions_yield` |
| `delivery` | `{ "mode": "announce", "channel": "telegram", "to": "telegram:-1003799367327:topic:2109", "bestEffort": false }` |
| `agentId` | `main` |
| `enabled` | `true` |

**`payload.message` (verbatim content, rendered as markdown — heading levels shifted down by 2 so they nest under this note's own headings; wording is unchanged)**

> [!warning] Paths are specific to this environment
> Every path below (`~/.openclaw/workspace/scripts/...`, `~/.openclaw/workspace/data/...`) is this environment's workspace root. When recreating this job elsewhere, replace `~/.openclaw/workspace` throughout with the new environment's actual workspace root — the scripts, schemas, log, and target-history paths all need to match wherever you copy sections 2–8 to. Same for the GitHub owner/repo list in Step 2 if the tracked targets differ, and the Telegram `delivery.to` chat/topic in the job config below.

You are the ORCHESTRATOR for the daily dev-tools changelog digest. Do NOT fetch data yourself. Spawn 9 independent subagents (one per investigation target below), let each produce a validated report + update its own history file, then ALWAYS synthesize a final digest yourself (even if some/all subagents failed), validate the synthesis, and append it to the running log.

#### Shared paths
- Diff script: ~/.openclaw/workspace/scripts/github_repo_diff.py
- Per-target report schema: ~/.openclaw/workspace/scripts/dev-tools-report.schema.json
- Synthesis schema: ~/.openclaw/workspace/scripts/dev-tools-synthesis.schema.json
- Generic validator: ~/.openclaw/workspace/scripts/validate_json.py <schema.json> <instance.json>  (exits 0 + prints VALID if instance matches schema; else exits 1 with field-level errors to stderr)
- Running log (source of truth for watermarks + digest history): ~/.openclaw/workspace/data/dev-tools-changelog.md
- Watermark reader: ~/.openclaw/workspace/scripts/get_last_watermarks.py <log.md>  (prints last watermark JSON block; {} + exit 1 if none found = cold start)
- Watermark/digest writer: ~/.openclaw/workspace/scripts/append_changelog_entry.py <log.md> <digest_body_file.md> <watermarks.json>  (appends one entry to the log AND regenerates dev-tools-changelog-state.json as a flat-JSON mirror of the watermarks for convenience reads; this is the ONLY sanctioned write to the log)
- Per-target history writer: ~/.openclaw/workspace/scripts/append_target_history.py <target> <entry_text_file>  (appends a narrative entry to ~/.openclaw/workspace/data/dev-tools-target-history/<target>.md; auto-creates file/dir). Purpose: continuity across runs, e.g. so a subagent sees "parts 1-3 of this overhaul landed over the past week" instead of only seeing today's isolated diff.
- Per-target history reader: plain `read`/`cat` of ~/.openclaw/workspace/data/dev-tools-target-history/<target>.md (may not exist yet on first run — that's fine, treat as no prior context)
- Run directory for this run's reports: create ~/.openclaw/workspace/data/dev-tools-changelog-reports/<UTC timestamp, e.g. 2026-07-14T1200Z>/ and have each subagent write its report to <rundir>/<target>.json

#### Step 1 — read watermarks
Run `uv run ~/.openclaw/workspace/scripts/get_last_watermarks.py ~/.openclaw/workspace/data/dev-tools-changelog.md`. If it errors/returns {}, treat all script-backed repos as cold-start (pass --last-sha none). Create the run directory. Note the current time — you have a 600s total budget for this whole job.

#### Step 2 — spawn 9 subagents in parallel
Give each subagent this brief (adapt per target):

> Investigate <target>. First, read ~/.openclaw/workspace/data/dev-tools-target-history/<target>.md if it exists, for context on recent history (e.g. an in-progress multi-day effort) — use this to describe the bigger picture accurately (e.g. "the overhaul that's been running for a week just finished" rather than just "part 4 landed"), not just today's isolated diff.
> <If script-backed: Run `uv run ~/.openclaw/workspace/scripts/github_repo_diff.py --owner <owner> --repo <repo> --branch <branch> --last-sha <lastSha or none> [--track-releases --last-release-tag <tag or none>]`. If it exits 0, the new_commits/new_releases are exactly what's new since last check — write a report with status=ok (or no-changes if empty) summarizing anything genuinely interesting (skip routine fixes/refactors/tests for Tier 2: opencode, openclaw, pi, Kiro, Orca; full detail for Tier 1: oh-my-pi, hindsight), informed by the history context above. If the script exits non-zero or its JSON has non-null "error", DO NOT try to fix the script — investigate WHY with your own judgment/tools (web_fetch/exec: repo/branch/org moved? rate-limited? network issue?) and write status=script-failed with a plain-language explanation in `summary` and raw reason in `script_error`. If the fetch succeeded, set new_head_sha/new_release_tag from the script output.> <If fuzzy-scan (Claude Code, broader tooling): normal web/API scan, no script, kind=fuzzy-scan, no watermark to set. If nothing found, status=no-changes with a one-line note.>
> Write your report JSON to <rundir>/<target>.json, then run `uv run ~/.openclaw/workspace/scripts/validate_json.py ~/.openclaw/workspace/scripts/dev-tools-report.schema.json <rundir>/<target>.json`. Fix and re-validate until it prints VALID.
> Then write a short 1-3 sentence narrative summary of what happened this run (for future-you's context, not the same as the Telegram summary) to a temp text file and run `uv run ~/.openclaw/workspace/scripts/append_target_history.py <target> <that_temp_file>`. Do this even for no-changes/script-failed runs — e.g. "checked, nothing new" or "script failed again for the same reason as before" is still useful continuity.
> End your turn with a short text summary of what you found; no need to message anyone.

##### Target 1 — oh-my-pi (script-backed, Tier 1 detail)
owner=can1357 repo=oh-my-pi branch=main track-releases=yes. Full commit + release changelog.

##### Target 2 — hindsight (script-backed, Tier 1 detail)
owner=vectorize-io repo=hindsight branch=main track-releases=yes. Full commit + release changelog.

##### Target 3 — opencode (script-backed, Tier 2 light touch)
owner=anomalyco repo=opencode branch=dev track-releases=no (NOTE: moved from sst/opencode to anomalyco/opencode, default branch `dev` not `main` — already corrected). 1-3 bullets on genuinely interesting new features/ideas only.

##### Target 4 — openclaw (script-backed, Tier 2 light touch)
owner=openclaw repo=openclaw branch=main track-releases=no. 1-3 bullets on genuinely interesting new features/ideas only.

##### Target 5 — pi (script-backed, Tier 2 light touch)
owner=earendil-works repo=pi branch=main track-releases=no. 1-3 bullets on genuinely interesting new features/ideas only.

##### Target 6 — Kiro (script-backed, Tier 2 light touch)
owner=kirodotdev repo=Kiro branch=main track-releases=no. Amazon's agentic IDE (spec-driven development, agent hooks). Added to research list 2026-08-29 at Kent's request. 1-3 bullets on genuinely interesting new features/ideas only.

##### Target 7 — Orca (script-backed, Tier 2 light touch)
owner=stablyai repo=orca branch=main track-releases=no. Open-source Agent Development Environment (ADE) for running a fleet of parallel coding agents (Claude Code, Codex, Cursor, etc.) across isolated worktrees. Added to research list 2026-08-29 at Kent's request. 1-3 bullets on genuinely interesting new features/ideas only.

##### Target 8 — claude-code (fuzzy-scan)
Check Anthropic's Claude Code changelog/release notes (https://docs.anthropic.com/en/release-notes/claude-code or similar) for anything published in the last 24-48h.

##### Target 9 — broader-tooling (fuzzy-scan)
Quick scan for anything notable in the broader AI coding agent/dev tools space in the last 24-48h (Cursor, Windsurf, Aider, Codex CLI, etc.) beyond the named tools above. If nothing stands out, status=no-changes — don't force a finding.

#### Step 3 — wait for completion by POLLING, not sessions_yield
IMPORTANT: this is an isolated cron session. Do NOT call sessions_yield here — confirmed on 2026-07-14 that sessions_yield does not reliably resume isolated cron sessions (a run spawned 7 subagents, called sessions_yield, and the cron system marked the run "finished" ~100s later while the 7 subagents kept running for ~10 more minutes with nothing left to receive their completion; the job silently produced no digest that day). Instead:
- Repeatedly call `subagents action=list recentMinutes=20`, spaced roughly 45-60 seconds apart (use `exec sleep 45` between checks — do not tight-loop), to see which of your 9 spawned tasks show status=done.
- Keep polling until either all 9 show done, or you are within ~120 seconds of this job's 600s total budget (track elapsed time from Step 1) — whichever comes first. Never poll past that safety margin; you must leave enough time to still complete Steps 4-6.
- For every subagent that IS done by the time you stop polling, read its report file from the run directory as normal.
- For every subagent that is NOT done (still running, errored, or produced no file) by the time you stop polling, do NOT wait longer and do NOT silently drop it — synthesize a placeholder yourself: {target, kind, status: "investigation-failed", summary: "subagent did not return within the polling window (last seen status: <status from subagents list, or 'no task found'>) — treated as failed for this run; its watermark will be left untouched so next run retries"}.
- The result of this step must ALWAYS be exactly 9 target entries (real report or placeholder) — never a run that just stops here with no output. Even if zero subagents returned in time, proceed to Step 4 with 9 placeholders: an "all-failed" synthesis that still gets sent to Kent is a correct, useful outcome. Going silent / producing nothing is never acceptable.

#### Step 4 — synthesize (always, even on partial/total failure, even if some subagents never returned in time)
Build a synthesis JSON object matching dev-tools-synthesis.schema.json: run_at (now, ISO-8601), overall_status ("ok" if all 9 targets have real reports with no script-failed/investigation-failed; "partial-failure" if some but not all failed; "all-failed" if every target failed/is missing), targets (array of all 9 target sub-reports, using placeholders from Step 3 for missing ones), failures (array of plain-language TL;DR strings for each failed target, omit key if none), and digest_markdown (the full Telegram-friendly digest text, built as: Tier 1 section (oh-my-pi, hindsight) full detail; Tier 2 section (opencode, openclaw, pi, Kiro, Orca) 1-3 bullets or one-liner; Claude Code + broader tooling brief, omit if nothing notable; for ANY script-failed/investigation-failed target, do NOT attempt a fix — end that tool's section with a clear **TL;DR: why it didn't work** line; if overall_status is all-failed, the whole digest can just be one clear TL;DR paragraph explaining the situation, but it must still be sent).
Write this synthesis object to <rundir>/synthesis.json, then run `uv run ~/.openclaw/workspace/scripts/validate_json.py ~/.openclaw/workspace/scripts/dev-tools-synthesis.schema.json <rundir>/synthesis.json`. Fix and re-validate until VALID — do not skip this even if some targets failed; a failure-only synthesis still needs to pass the schema.

#### Step 5 — build + append new watermarks
Start from the watermarks read in Step 1. For every script-backed target with status=ok or no-changes (new_head_sha non-null), update its lastSha (and lastReleaseTag if present). Leave any script-failed/investigation-failed/missing target's watermark exactly as read in Step 1 (so next run retries from the same point). Write the merged JSON map to <rundir>/watermarks.json. Write digest_markdown (from the validated synthesis) to <rundir>/digest.md. Run `uv run ~/.openclaw/workspace/scripts/append_changelog_entry.py ~/.openclaw/workspace/data/dev-tools-changelog.md <rundir>/digest.md <rundir>/watermarks.json`. Should print APPENDED. This always runs, including after partial/total failure — the log entry itself IS the failure record for future runs to see, and for the per-target history files too (append a short note for any target you had to placeholder, e.g. "subagent didn't return in time this run").

#### Step 6 — send (mandatory, no exceptions)
Send digest_markdown as your reply. Keep it Telegram-skimmable, not raw JSON. This step must run even if overall_status is all-failed — Kent must always get a message from this job, even if that message is just explaining that everything failed and why. A run that produces no message at all is a bug.
## 2. Script — `scripts/github_repo_diff.py`
```python
#!/usr/bin/env python3
"""
Generic deterministic GitHub repo diff fetcher.

Given an owner/repo (+ optional branch), and a previously-stored watermark
(last commit SHA, and optionally last release tag), fetches exactly what's
new since the watermark. Falls back to a 48h window if the watermark isn't
found in the returned page (repo moved too fast, force-push, cold start).

Always prints a single JSON object to stdout, even on failure, so callers
can parse the result either way. Exit code 0 = fetch succeeded (mode may
still be a fallback), exit code 1 = fetch failed (network/API error) and
the JSON will have "error" set with a plain-language reason.

Usage:
  uv run github_repo_diff.py --owner can1357 --repo oh-my-pi \
      [--branch main] [--last-sha <sha>] [--last-release-tag <tag>] \
      [--track-releases] [--per-page 50] [--window-hours 48]

Pass "none" (or omit) for --last-sha / --last-release-tag to indicate no
prior watermark (cold start).
"""
import argparse
import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone

API = "https://api.github.com"


def gh_get(path, params=None):
    url = f"{API}{path}"
    if params:
        qs = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"{url}?{qs}"
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "openclaw-dev-tools-changelog/1.0",
    })
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.status, json.loads(resp.read().decode("utf-8"))


def parse_date(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fetch_commits(owner, repo, branch, last_sha, per_page, window_hours):
    status, commits = gh_get(f"/repos/{owner}/{repo}/commits",
                              {"sha": branch, "per_page": per_page})
    if not isinstance(commits, list) or not commits:
        return {"mode": "empty-response", "new_commits": [], "new_head_sha": last_sha}

    head_sha = commits[0]["sha"]

    if not last_sha or last_sha.lower() == "none":
        cutoff = datetime.now(tz=timezone.utc) - timedelta(hours=window_hours)
        new_commits = [c for c in commits
                       if parse_date(c["commit"]["author"]["date"]) > cutoff]
        return {"mode": "cold-start-window", "new_commits": new_commits, "new_head_sha": head_sha}

    new_commits = []
    for c in commits:
        if c["sha"] == last_sha:
            return {"mode": "exact-watermark", "new_commits": new_commits, "new_head_sha": head_sha}
        new_commits.append(c)

    # watermark not found in this page -> fallback to window, flag it
    cutoff = datetime.now(tz=timezone.utc) - timedelta(hours=window_hours)
    new_commits = [c for c in commits
                   if parse_date(c["commit"]["author"]["date"]) > cutoff]
    return {"mode": "watermark-not-found-fallback-window", "new_commits": new_commits, "new_head_sha": head_sha}


def fetch_releases(owner, repo, last_tag):
    status, releases = gh_get(f"/repos/{owner}/{repo}/releases")
    if not isinstance(releases, list):
        return {"new_releases": [], "new_release_tag": last_tag}
    if not releases:
        return {"new_releases": [], "new_release_tag": last_tag}

    top_tag = releases[0].get("tag_name")

    if not last_tag or last_tag.lower() == "none":
        return {"new_releases": releases[:1], "new_release_tag": top_tag}

    new_releases = []
    for r in releases:
        if r.get("tag_name") == last_tag:
            break
        new_releases.append(r)
    return {"new_releases": new_releases, "new_release_tag": top_tag}


def slim_commit(c):
    return {
        "sha": c.get("sha"),
        "message": (c.get("commit", {}).get("message") or "").split("\n")[0],
        "author": c.get("commit", {}).get("author", {}).get("name"),
        "date": c.get("commit", {}).get("author", {}).get("date"),
        "url": c.get("html_url"),
    }


def slim_release(r):
    return {
        "tag_name": r.get("tag_name"),
        "name": r.get("name"),
        "published_at": r.get("published_at"),
        "body": (r.get("body") or "")[:2000],
        "url": r.get("html_url"),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--branch", default="main")
    ap.add_argument("--last-sha", default="none")
    ap.add_argument("--last-release-tag", default="none")
    ap.add_argument("--track-releases", action="store_true")
    ap.add_argument("--per-page", type=int, default=50)
    ap.add_argument("--window-hours", type=int, default=48)
    args = ap.parse_args()

    out = {
        "owner": args.owner,
        "repo": args.repo,
        "branch": args.branch,
        "error": None,
    }

    try:
        commit_result = fetch_commits(args.owner, args.repo, args.branch,
                                        args.last_sha, args.per_page, args.window_hours)
        out["mode"] = commit_result["mode"]
        out["new_commits"] = [slim_commit(c) for c in commit_result["new_commits"]]
        out["new_head_sha"] = commit_result["new_head_sha"]
    except urllib.error.HTTPError as e:
        out["error"] = f"HTTP {e.code} fetching commits: {e.reason}"
        print(json.dumps(out, indent=2))
        sys.exit(1)
    except urllib.error.URLError as e:
        out["error"] = f"network error fetching commits: {e.reason}"
        print(json.dumps(out, indent=2))
        sys.exit(1)
    except Exception as e:
        out["error"] = f"unexpected error fetching commits: {type(e).__name__}: {e}"
        print(json.dumps(out, indent=2))
        sys.exit(1)

    if args.track_releases:
        try:
            rel_result = fetch_releases(args.owner, args.repo, args.last_release_tag)
            out["new_releases"] = [slim_release(r) for r in rel_result["new_releases"]]
            out["new_release_tag"] = rel_result["new_release_tag"]
        except urllib.error.HTTPError as e:
            out["releases_error"] = f"HTTP {e.code} fetching releases: {e.reason}"
        except urllib.error.URLError as e:
            out["releases_error"] = f"network error fetching releases: {e.reason}"
        except Exception as e:
            out["releases_error"] = f"unexpected error fetching releases: {type(e).__name__}: {e}"

    print(json.dumps(out, indent=2))
    sys.exit(0)


if __name__ == "__main__":
    main()
```

## 3. Script — `scripts/get_last_watermarks.py`
```python
#!/usr/bin/env python3
"""
Extract the most recent watermark block from the dev-tools-changelog.md log.

The log file contains one or more HTML comment blocks of the form:

<!-- watermarks
{ ... json ... }
-->

This prints the JSON from the LAST such block found in the file (i.e. the
most recent run's watermarks). If no block is found, prints "{}" and exits 1.

Usage:
  uv run get_last_watermarks.py <path-to-log.md>
"""
import json
import re
import sys


def main():
    if len(sys.argv) != 2:
        print("Usage: uv run get_last_watermarks.py <path-to-log.md>", file=sys.stderr)
        sys.exit(2)

    path = sys.argv[1]
    try:
        with open(path, "r") as f:
            content = f.read()
    except FileNotFoundError:
        print("{}")
        print(f"no log file found at {path} — treat all repos as cold-start", file=sys.stderr)
        sys.exit(1)

    blocks = re.findall(r"<!--\s*watermarks\s*\n(.*?)\n-->", content, re.DOTALL)

    if not blocks:
        print("{}")
        print("no watermark block found in log — treat all repos as cold-start", file=sys.stderr)
        sys.exit(1)

    last_block = blocks[-1]
    try:
        data = json.loads(last_block)
    except json.JSONDecodeError as e:
        print("{}")
        print(f"last watermark block is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    print(json.dumps(data, indent=2))
    sys.exit(0)


if __name__ == "__main__":
    main()
```

## 4. Script — `scripts/append_changelog_entry.py`
```python
#!/usr/bin/env python3
"""
Append one dated entry to the dev-tools-changelog.md log: a markdown heading,
the digest body text, then a fresh watermark HTML-comment block. This is the
ONLY sanctioned way to write to the log — always appends, never truncates or
rewrites earlier entries, so a bad run can't corrupt prior history.

As a convenience side-effect, also writes the same watermark map out to a
flat JSON file (dev-tools-changelog-state.json, next to the log) so anything
that just wants a quick read of current watermarks doesn't have to parse
markdown — the .md log remains the source of truth; the .json is a mirror
regenerated every run.

Usage:
  uv run append_changelog_entry.py <log.md> <digest_body_file.md> <watermarks.json>

- <log.md>: path to the running log file (created if missing, with a header).
- <digest_body_file.md>: path to a file containing the synthesized digest
  text for this run (markdown, no heading needed — one is added automatically).
- <watermarks.json>: path to a JSON file with the new watermark map to persist,
  e.g. {"oh-my-pi": {"lastSha": "...", "lastReleaseTag": "..."}, ...}

Prints "APPENDED" on success.
"""
import json
import os
import sys
from datetime import datetime, timezone

HEADER = """# Dev Tools Changelog — Running Log

This file is the single source of truth for the daily dev-tools changelog job. Each run appends one dated entry containing the synthesized digest, followed by a machine-readable watermark block. The orchestrator reads the **last** watermark block in this file at the start of each run to know what SHA/release-tag each repo was last checked against, then appends a fresh entry (digest + new watermark block) at the end when done.

Do not edit the watermark blocks by hand unless recovering from a bad run — the orchestrator parses the last one verbatim.

---
"""


def main():
    if len(sys.argv) != 4:
        print("Usage: uv run append_changelog_entry.py <log.md> <digest_body_file.md> <watermarks.json>", file=sys.stderr)
        sys.exit(2)

    log_path, digest_path, watermarks_path = sys.argv[1], sys.argv[2], sys.argv[3]

    try:
        with open(digest_path, "r") as f:
            digest = f.read().strip()
    except FileNotFoundError:
        print(f"digest body file not found: {digest_path}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(watermarks_path, "r") as f:
            watermarks = json.load(f)
    except FileNotFoundError:
        print(f"watermarks file not found: {watermarks_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"watermarks file is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    now = datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    watermarks_json_str = json.dumps(watermarks, indent=2)

    entry = f"""
## Run — {now}

{digest}

<!-- watermarks
{watermarks_json_str}
-->

---
"""

    # Create the file with the standard header if it doesn't exist yet.
    try:
        with open(log_path, "r") as f:
            existing = f.read()
    except FileNotFoundError:
        existing = HEADER

    with open(log_path, "w") as f:
        f.write(existing.rstrip("\n") + "\n" + entry)

    # Mirror the watermark map to a flat JSON file next to the log, purely
    # for convenience reads. The .md log is still the authoritative source;
    # this file is regenerated wholesale every run and never hand-edited.
    mirror_path = os.path.join(os.path.dirname(os.path.abspath(log_path)), "dev-tools-changelog-state.json")
    with open(mirror_path, "w") as f:
        json.dump(watermarks, f, indent=2)
        f.write("\n")

    print("APPENDED")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

## 5. Script — `scripts/append_target_history.py`
```python
#!/usr/bin/env python3
"""
Append one entry to a target's persistent history log
(data/dev-tools-target-history/<target>.md).

This is separate from the main running changelog (dev-tools-changelog.md).
Its purpose is giving each subagent continuity of *narrative* across runs —
e.g. so a subagent picking up "part 4 of an overhaul" can see in its own
target's history that parts 1-3 already landed over the past week, and
report "the overhaul finished" instead of just "part 4 done" with no
context. This file is NOT used for watermarks — github_repo_diff.py's
--last-sha is the only thing that decides what's "new"; this is pure
narrative memory for the summarizing subagent to read back.

Usage:
  uv run append_target_history.py <target> <entry_text_file>

Appends a dated bullet-ish entry to
  ~/.openclaw/workspace/data/dev-tools-target-history/<target>.md
(created automatically, including the directory, if missing).

Prints "APPENDED" on success.
"""
import os
import sys
from datetime import datetime, timezone

BASE_DIR = os.path.expanduser("~/.openclaw/workspace/data/dev-tools-target-history")


def main():
    if len(sys.argv) != 3:
        print("Usage: uv run append_target_history.py <target> <entry_text_file>", file=sys.stderr)
        sys.exit(2)

    target, entry_path = sys.argv[1], sys.argv[2]

    try:
        with open(entry_path, "r") as f:
            entry_text = f.read().strip()
    except FileNotFoundError:
        print(f"entry text file not found: {entry_path}", file=sys.stderr)
        sys.exit(1)

    if not entry_text:
        print("entry text is empty, nothing to append", file=sys.stderr)
        sys.exit(1)

    os.makedirs(BASE_DIR, exist_ok=True)
    hist_path = os.path.join(BASE_DIR, f"{target}.md")

    now = datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    if not os.path.exists(hist_path):
        header = f"# {target} — investigation history\n\nAppend-only narrative log for the `{target}` investigation target. Read this before investigating to understand recent context (e.g. a multi-day overhaul in progress) — don't just look at the latest diff in isolation.\n\n---\n"
        with open(hist_path, "w") as f:
            f.write(header)

    with open(hist_path, "a") as f:
        f.write(f"\n## {now}\n\n{entry_text}\n\n---\n")

    print("APPENDED")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

## 6. Script — `scripts/validate_json.py`
```python
#!/usr/bin/env python3
"""
Generic JSON Schema (draft-07) validator. Works against any schema file.

Usage:
  uv run validate_json.py <schema.json> <instance.json>

Exit code 0 = valid, prints "VALID".
Exit code 1 = invalid (or file/JSON errors), prints details to stderr.
Exit code 2 = usage error.
"""
# /// script
# dependencies = ["jsonschema"]
# ///
import json
import sys

import jsonschema


def main():
    if len(sys.argv) != 3:
        print("Usage: uv run validate_json.py <schema.json> <instance.json>", file=sys.stderr)
        sys.exit(2)

    schema_path, instance_path = sys.argv[1], sys.argv[2]

    try:
        with open(schema_path, "r") as f:
            schema = json.load(f)
    except FileNotFoundError:
        print(f"INVALID: schema file not found: {schema_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"INVALID: schema file is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(instance_path, "r") as f:
            instance = json.load(f)
    except FileNotFoundError:
        print(f"INVALID: instance file not found: {instance_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"INVALID: instance file is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    validator = jsonschema.Draft7Validator(schema)
    errors = sorted(validator.iter_errors(instance), key=lambda e: e.path)

    if errors:
        print("INVALID: instance failed schema validation:", file=sys.stderr)
        for err in errors:
            path = ".".join(str(p) for p in err.path) or "(root)"
            print(f"  - {path}: {err.message}", file=sys.stderr)
        sys.exit(1)

    print("VALID")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

## 7. Schema — `scripts/dev-tools-report.schema.json`
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "dev-tools-changelog investigation report",
  "type": "object",
  "required": ["target", "kind", "status", "summary", "generated_at"],
  "properties": {
    "target": {
      "type": "string",
      "description": "Short identifier for the investigation target, e.g. 'oh-my-pi', 'claude-code', 'broader-tooling'."
    },
    "kind": {
      "type": "string",
      "enum": ["script-backed", "fuzzy-scan"],
      "description": "Whether this target used the deterministic GitHub script (script-backed) or a free-form scan (fuzzy-scan, e.g. Claude Code / broader tooling space)."
    },
    "status": {
      "type": "string",
      "enum": ["ok", "no-changes", "script-failed", "investigation-failed"],
      "description": "ok = new content found and reported. no-changes = checked, nothing new. script-failed = the deterministic script errored and the agent is reporting why (not attempting a fix). investigation-failed = fuzzy-scan target could not be completed."
    },
    "summary": {
      "type": "string",
      "description": "Human-readable summary for this target. For status=ok, describe what's new. For status=script-failed/investigation-failed, explain plainly why, in 1-3 sentences."
    },
    "details": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Optional bullet points (new commits, releases, features) backing the summary."
    },
    "script_error": {
      "type": ["string", "null"],
      "description": "Raw error/reason if status=script-failed. Null otherwise."
    },
    "new_head_sha": {
      "type": ["string", "null"],
      "description": "For script-backed targets: the new watermark SHA to persist, if the fetch succeeded. Null if it failed."
    },
    "new_release_tag": {
      "type": ["string", "null"],
      "description": "For script-backed Tier 1 targets: the new release-tag watermark to persist, if applicable and successful."
    },
    "generated_at": {
      "type": "string",
      "description": "ISO-8601 timestamp when this report was generated."
    }
  },
  "additionalProperties": true
}
```

## 8. Schema — `scripts/dev-tools-synthesis.schema.json`
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "dev-tools-changelog synthesis report",
  "description": "The orchestrator's final combined output for one run. Must validate before the run is appended to the log.",
  "type": "object",
  "required": ["run_at", "overall_status", "targets", "digest_markdown"],
  "properties": {
    "run_at": {
      "type": "string",
      "description": "ISO-8601 timestamp when synthesis was produced."
    },
    "overall_status": {
      "type": "string",
      "enum": ["ok", "partial-failure", "all-failed"],
      "description": "ok = all 7 targets reported successfully (ok/no-changes/investigation not required to find anything). partial-failure = at least one target (but not all) is script-failed/investigation-failed/missing. all-failed = every target failed or is missing."
    },
    "targets": {
      "type": "array",
      "description": "One entry per investigation target (should be exactly 7 in practice: oh-my-pi, hindsight, opencode, openclaw, pi, claude-code, broader-tooling). If a subagent crashed and produced no report at all, the orchestrator must synthesize a placeholder entry here itself with status=investigation-failed, rather than omitting the target.",
      "type": "array",
      "items": {
        "type": "object",
        "required": ["target", "kind", "status", "summary"],
        "properties": {
          "target": { "type": "string" },
          "kind": { "type": "string", "enum": ["script-backed", "fuzzy-scan"] },
          "status": { "type": "string", "enum": ["ok", "no-changes", "script-failed", "investigation-failed"] },
          "summary": { "type": "string" }
        },
        "additionalProperties": true
      }
    },
    "failures": {
      "type": "array",
      "description": "Optional list of plain-language TL;DR strings, one per failed/missing target, explaining why it didn't work. Populated whenever overall_status is partial-failure or all-failed.",
      "items": { "type": "string" }
    },
    "digest_markdown": {
      "type": "string",
      "description": "The full synthesized digest text, exactly as sent to the user and appended to the running log."
    }
  },
  "additionalProperties": true
}
```

## 9. Example — `data/dev-tools-changelog-state.json` (watermark mirror)
```json
{
  "oh-my-pi": {
    "lastSha": "cdb9c4d985bc7d3ca8526b7e55a0133ef3cf2287",
    "lastReleaseTag": "v18.0.11"
  },
  "hindsight": {
    "lastSha": "d2e8fa7286b37012b7e45de8f1b10dc333274918",
    "lastReleaseTag": "v0.9.2"
  },
  "herdr": {
    "lastSha": "7b675f42af35508eab66ac42fe1598628597a893",
    "lastReleaseTag": "v0.8.2"
  },
  "opencode": {
    "lastSha": "10765ff2a9da8c3b88e4de873aa383a49c318912"
  },
  "openclaw": {
    "lastSha": "e42bb23a84933669c67173ed3b7640567b6f1ce9"
  },
  "pi": {
    "lastSha": "853a80d26c90a14c1886f0ebb8ffaae133ca2185"
  },
  "Kiro": {
    "lastSha": "bfe7ff30d9b21e583566c844d75e3dd2b572e2c7"
  },
  "Orca": {
    "lastSha": "3d0bd6a3ec029be176bf05a8f9d0906250f16f82"
  }
}
```

## 10. Example — `data/dev-tools-changelog.md` (header + last log entry)
````markdown
# Dev Tools Changelog — Running Log

This file is the single source of truth for the daily dev-tools changelog job. Each run appends one dated entry containing the synthesized digest, followed by a machine-readable watermark block. The orchestrator reads the **last** watermark block in this file at the start of each run to know what SHA/release-tag each repo was last checked against, then appends a fresh entry (digest + new watermark block) at the end when done.

Do not edit the watermark blocks by hand unless recovering from a bad run — the orchestrator parses the last one verbatim.

---

## Run — 2026-08-30T10:07:24Z

🌑 **Dev Tools Changelog — 2026-08-30**

**Tier 1 — full detail**

**oh-my-pi** → v18.0.11 (patch, from v18.0.10), 47 commits (fallback window — watermark had drifted out of range)
- Reliability patch: fixes agent startup/context-compaction crashes for models with unrecognized tokenizer encodings, Anthropic-compatible stream retries on premature stream end, Gemini 3.x tool-call continuations over OpenAI-compatible endpoints, and HTTP 402/deactivated-workspace credential fallback being misclassified as quota exhaustion.
- Big catalog-correction batch: Baseten GLM reasoning classification, Cloudflare AI Gateway Workers AI model discovery, Cursor Kimi K3/Grok 4/Composer 2.5 image-input support, OpenRouter GLM-5.3/DeepSeek V4 Pro reasoning-effort preservation, MiniMax-M3 output-cap fix, GLM-5.3-Flash promo pricing fix.
- Two new community provider integrations merged (unreleased): native ClinePass provider, and Devin's native CLI surface with dynamic catalog/router/usage tracking.
- Worth watching: in the last ~10 minutes of the check window, a major *unreleased* architecture shift kicked off — catalog identity being reorganized around a centralized KDL taxonomy, with a new unified KDL policy engine/compat layer and restructured model/variant handling. Nothing shipped yet, but this looks like the start of a bigger multi-day effort.

**hindsight** → quiet day, still on v0.9.2
- Only one new commit since the last check: an automated "chore: update star history" bot commit — no functional changes, no new release.

**Tier 2 — light touch**

- **opencode**: 2 routine commits (removed Hy3 Free promo docs, Go chart rendering fix) — nothing notable.
- **openclaw**: 47 commits, almost entirely routine fix/perf/chore churn (gateway restart draining, plugin-approval messaging, package provenance display). No feature-scale additions; 22nd day in a row the watermark fell into fallback-window mode.
- **pi**: 0 new commits — unchanged since yesterday.
- **Kiro** (first-ever check, cold start): no commits in the 48h window; last activity (Aug 27) was a README refresh + Dependabot fix. Notably bumped its default model to Opus 4.6 back in June.
- **Orca** (first-ever check, cold start): mostly fixes/refactors/CI hardening, but a clear theme of deepening in-app browser integration — address-bar convergence (link previews ↔ browser tabs convert in place), and SSH terminal links / linked code reviews now open in the embedded Orca Browser instead of an external one.

**Claude Code** → No new release in the 24-48h window; still on v2.1.251 (Aug 28), already covered yesterday.

**Broader tooling** → Standout: OpenAI announced (Aug 28-29) it's cutting off Cursor's access to OpenAI models, with a proposed shutoff date of Nov 12, 2026 — citing distrust that SpaceX (which closed its ~$60B acquisition of Cursor/Anysphere on Aug 14) will honor OpenAI's terms of service. Cursor CEO Michael Truell says OpenAI models are only ~5% of Cursor's traffic and the two sides are negotiating. A real model-supply-chain rupture tied to the SpaceX acquisition. Otherwise routine cadence: GitHub Copilot's weekly release added Copilot-in-Slack/Teams shared agent sessions and moved Copilot CLI to a native Rust runtime; Codex CLI shipped rust-v0.151.0 (MCP grace periods/result filtering); Replit added Auto model-routing; JetBrains shipped a fully offline Junie Local agent.

<!-- watermarks
{
  "oh-my-pi": {
    "lastSha": "cdb9c4d985bc7d3ca8526b7e55a0133ef3cf2287",
    "lastReleaseTag": "v18.0.11"
  },
  "hindsight": {
    "lastSha": "d2e8fa7286b37012b7e45de8f1b10dc333274918",
    "lastReleaseTag": "v0.9.2"
  },
  "herdr": {
    "lastSha": "7b675f42af35508eab66ac42fe1598628597a893",
    "lastReleaseTag": "v0.8.2"
  },
  "opencode": {
    "lastSha": "10765ff2a9da8c3b88e4de873aa383a49c318912"
  },
  "openclaw": {
    "lastSha": "e42bb23a84933669c67173ed3b7640567b6f1ce9"
  },
  "pi": {
    "lastSha": "853a80d26c90a14c1886f0ebb8ffaae133ca2185"
  },
  "Kiro": {
    "lastSha": "bfe7ff30d9b21e583566c844d75e3dd2b572e2c7"
  },
  "Orca": {
    "lastSha": "3d0bd6a3ec029be176bf05a8f9d0906250f16f82"
  }
}
-->

---
````

## 11. Example — `data/dev-tools-target-history/oh-my-pi.md` (first entries)
````markdown
# oh-my-pi — investigation history

Append-only narrative log for the `oh-my-pi` investigation target. Read this before investigating to understand recent context (e.g. a multi-day overhaul in progress) — don't just look at the latest diff in isolation.

---

## 2026-08-11T08:28:19Z

2026-08-11: First-run (cold start) check of can1357/oh-my-pi. No new commits reported in the tracked window, but captured release v17.2.12 (2026-08-09) in full: bug fixes across pi-ai, pi-catalog, pi-coding-agent, pi-tui, and pi-natives (shell builtins consolidated into one crate), plus a hashline breaking change tightening register-paste safety and new tree-sitter-backed edit boundary repair logic. Watermarks set: head_sha=45e12e5bb758198a920c6070e7e64cb33b21beac, release_tag=v17.2.12.

---

## 2026-08-12T10:03:09Z

````
