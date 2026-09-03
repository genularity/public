#!/bin/bash
# publish-notes.sh — one mechanical step: sync the vault into content/, then
# commit and push. Authenticates from the GITHUB_TOKEN environment variable.
#
# Why this exists: sync-notes.sh only mirrors the vault into content/. The
# commit and push used to be improvised by hand on every publish, including
# re-creating a throwaway GIT_ASKPASS shim after every container restart.
# That was the fragile part, so it lives here now.
#
# What is deliberately NOT automated:
#   - Deciding what publishes. That is `publish: true` in a vault note's
#     frontmatter, set by Kent. This script never adds or removes that flag.
#   - The homepage THEMES paragraph. It is hand-written prose guarded by
#     themes-hash; a stale hash ABORTS this script (see below) rather than
#     silently shipping a homepage intro that omits half the published notes.
#   - Triggering. Publishing is a public, external action — it stays manual
#     and must never be wired into a heartbeat or cron.
#
# Usage:
#   ./publish-notes.sh                     # sync, commit, push
#   ./publish-notes.sh -m "custom message" # override commit message
#   ALLOW_STALE_THEMES=1 ./publish-notes.sh  # push despite a stale themes hash
#
# Requires: GITHUB_TOKEN in the environment (container env var; see the
# service's own `environment:` block in docker-compose.yml — a Portainer
# stack-level variable alone does NOT reach the container).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

COMMIT_MSG="sync notes"
while [ $# -gt 0 ]; do
  case "$1" in
    -m|--message) COMMIT_MSG="${2:?-m needs a message}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ---- 1. credential present? ------------------------------------------------
# Checked before doing any work, so we fail before making local changes we
# then cannot push. Never echo the value; a length check is enough.
if [ -z "${GITHUB_TOKEN:-}" ]; then
  cat >&2 <<'MSG'
ERROR: GITHUB_TOKEN is not set in this environment — cannot push.

Verify without exposing the value:
  docker exec openclaw-gateway sh -c 'printf "%s" "$GITHUB_TOKEN" | sha256sum'
A hash of e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
means the variable is EMPTY (that is the sha256 of the empty string).

Fix: add an explicit line to the service's own environment: block in
docker-compose.yml, then recreate the container:
  environment:
    - GITHUB_TOKEN=${GITHUB_TOKEN}
MSG
  exit 1
fi

# ---- 2. pre-flight: repo must be clean apart from expected paths -----------
# Unscoped on purpose. Scoping this to content/ would hide exactly the
# unrelated uncommitted work it exists to catch.
UNEXPECTED="$(git status --porcelain | grep -vE '^.{2}"?(content/|quartz\.config\.ts)' || true)"
if [ -n "$UNEXPECTED" ]; then
  echo "ERROR: unexpected changes outside content/ — refusing to touch this repo:" >&2
  echo "$UNEXPECTED" >&2
  echo "Resolve or stash these first; do not let a notes sync carry someone else's work." >&2
  exit 1
fi

# ---- 3. sync the vault -----------------------------------------------------
SYNC_LOG="$(mktemp)"
trap 'rm -f "$SYNC_LOG"' EXIT
bash "$SCRIPT_DIR/sync-notes.sh" 2>&1 | tee "$SYNC_LOG"

if grep -q "themes paragraph is STALE" "$SYNC_LOG"; then
  if [ "${ALLOW_STALE_THEMES:-0}" != "1" ]; then
    cat >&2 <<'MSG'

ERROR: aborting — the homepage THEMES paragraph is stale (see warning above).

The published set changed, so the hand-written intro on the homepage no longer
describes what is actually live. Fix it at the source, not in content/:
  1. Edit the QUARTZ:THEMES-START/END block in the vault note
     /home/node/obsidian/Notes/GitHub Pages Home.md
  2. Set themes-hash: to the current hash printed in the warning above
  3. Re-run this script

Override with ALLOW_STALE_THEMES=1 only if shipping a stale intro is deliberate.
MSG
    exit 1
  fi
  echo "WARNING: proceeding with a stale themes paragraph (ALLOW_STALE_THEMES=1)." >&2
fi

# ---- 4. post-sync check, then commit --------------------------------------
UNEXPECTED="$(git status --porcelain | grep -vE '^.{2}"?(content/|quartz\.config\.ts)' || true)"
if [ -n "$UNEXPECTED" ]; then
  echo "ERROR: sync produced changes outside content/ — not committing:" >&2
  echo "$UNEXPECTED" >&2
  exit 1
fi

git add content/
if git diff --cached --quiet; then
  echo "Nothing to publish — content/ already matches the vault. No commit, no push."
  exit 0
fi

echo "--- staged for commit ---"
git diff --cached --stat

git -c user.name="${GIT_AUTHOR_NAME:-AgentShadow}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-agentshadow@kentsworld.com}" \
    commit -m "$COMMIT_MSG"

# ---- 5. push, feeding the token via GIT_ASKPASS ---------------------------
# GIT_ASKPASS keeps the token out of argv, out of the remote URL, and out of
# any log or shell history. Never interpolate $GITHUB_TOKEN into a command.
ASKPASS="$(mktemp)"
trap 'rm -f "$SYNC_LOG" "$ASKPASS"' EXIT
cat > "$ASKPASS" <<'SHIM'
#!/bin/sh
case "$1" in
  *[Uu]sername*) printf '%s' 'x-access-token' ;;
  *) printenv GITHUB_TOKEN ;;
esac
SHIM
chmod 700 "$ASKPASS"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0 git push origin "$BRANCH"

echo
echo "Pushed $(git rev-parse --short HEAD) to origin/$BRANCH."
echo "GitHub Actions rebuilds the site; live in ~2 minutes: https://genularity.github.io/"
echo
echo "Live URLs use Quartz's own slug format, not a plain kebab-case title."
echo "Read them off the homepage rather than guessing:"
echo "  curl -s https://genularity.github.io/ | grep -oE 'href=\"\\./[^\"]*\"' | grep -v 'tags/\\|\\.css\\|\\.js'"
