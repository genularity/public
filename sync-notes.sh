#!/bin/bash
# sync-notes.sh — copy publish:true notes from Obsidian vault to Quartz content/
# Usage: ./sync-notes.sh

VAULT="/home/node/obsidian/Notes"
CONTENT="$(dirname "$0")/content"

# Clear existing content (keep index.md)
find "$CONTENT" -name "*.md" ! -name "index.md" -delete 2>/dev/null

SYNCED=0
SKIPPED=0

while IFS= read -r -d '' file; do
  if head -20 "$file" | grep -qE "^publish:\s*true"; then
    rel="${file#$VAULT/}"
    dest="$CONTENT/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
    ((SYNCED++))
  else
    ((SKIPPED++))
  fi
done < <(find "$VAULT" -name "*.md" ! -path "*/.obsidian/*" ! -path "*/copilot/*" -print0)

echo "Synced: $SYNCED notes | Skipped: $SKIPPED notes"
