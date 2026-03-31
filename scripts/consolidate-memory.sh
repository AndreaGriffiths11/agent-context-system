#!/bin/bash
# Memory consolidation for agent-context-system
#
# 4-phase process:
#   1. Orient — Read index + existing topic files
#   2. Gather — Scan recent daily logs
#   3. Consolidate — Merge into topic files
#   4. Prune — Update index, stay under 200 lines
#
# Usage:
#   ./scripts/consolidate-memory.sh [--dry-run] [--days N]

set -euo pipefail

AGENTS_DIR="${AGENTS_DIR:-.agents}"
LOGS_DIR="$AGENTS_DIR/logs"
TOPICS_DIR="$AGENTS_DIR/topics"
LOCK_FILE="$AGENTS_DIR/.consolidation-lock"

MAX_INDEX_LINES=200
MAX_INDEX_BYTES=25000
DEFAULT_DAYS=7

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

# Parse args
DRY_RUN=false
DAYS=$DEFAULT_DAYS

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" == true ]]; then
  log_warn "DRY RUN MODE (showing what would happen)"
fi

# Check structure
if [[ ! -d "$LOGS_DIR" ]] || [[ ! -d "$TOPICS_DIR" ]]; then
  log_error "Missing logs/ or topics/ directories"
  log_error "Run: ./scripts/migrate-to-daily-logs.sh first"
  exit 1
fi

# Find recent daily logs
log_info "Scanning for daily logs from last $DAYS days..."
CUTOFF_DATE=$(date -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-"${DAYS}"d +%Y-%m-%d 2>/dev/null || echo "2000-01-01")

recent_logs=()
total_size=0

while IFS= read -r log_file; do
  log_date=$(basename "$log_file" .md)
  if [[ "$log_date" > "$CUTOFF_DATE" ]] || [[ "$log_date" == "$CUTOFF_DATE" ]]; then
    recent_logs+=("$log_file")
    size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
    total_size=$((total_size + size))
  fi
done < <(find "$LOGS_DIR" -name "*.md" | sort)

log_info "Found ${#recent_logs[@]} daily logs ($total_size bytes total)"

if [[ ${#recent_logs[@]} -eq 0 ]]; then
  log_warn "No daily logs to consolidate"
  exit 0
fi

for log in "${recent_logs[@]}"; do
  log_info "  - $(basename "$log")"
done

# Build consolidation prompt
PROMPT=$(cat <<'EOF'
# Memory Consolidation

You are performing a memory consolidation — a reflective pass over daily logs and topic files.
Synthesize what you've learned recently into durable, well-organized memories.

**Memory directory:** `.agents/`

---

## Phase 1 — Orient

Read the current state:

1. **Index** (`.agents/local.md`) — Understand current organization
2. **Topic files** (`.agents/topics/*.md`) — Check existing patterns, gotchas, preferences
3. **Recent daily logs** (listed below) — Identify new information

**Recent daily logs to consolidate:**
EOF
)

for log in "${recent_logs[@]}"; do
  PROMPT+=$'\n'"- $(basename "$log") ($(stat -c%s "$log" 2>/dev/null || stat -f%z "$log" 2>/dev/null || echo 0) bytes)"
done

PROMPT+=$(cat <<EOF


## Phase 2 — Gather Signal

Scan recent daily logs for information worth persisting:

1. **Session observations** — Patterns that recurred 3+ times
2. **Gotchas** — Traps that appeared multiple times
3. **Preferences** — Stable choices across sessions
4. **Dead ends** — Things tried that didn't work

**Skip:**
- One-time events
- Transient state ("currently debugging X")
- Code snippets (link to files instead)
- Secrets (never store)

## Phase 3 — Consolidate

For each piece of signal:

1. **Check for duplicates** — Does this already exist in a topic file?
2. **Merge if duplicate** — Update existing entry, don't create new
3. **Convert relative dates** — "yesterday" → "2026-03-31", "last week" → "2026-03-24"
4. **Create topic entry** — If truly new and recurring

**Topic file format:**

\`\`\`markdown
---
type: pattern  # pattern | gotcha | preference
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Title

## What
[Brief description]

## Where
[Where this appears, with links]

## Why
[Reasoning or context]

## Example
[Concrete example or command]
\`\`\`

**Topic files:**
- \`.agents/topics/patterns.md\` — Recurring patterns
- \`.agents/topics/gotchas.md\` — Traps and fixes
- \`.agents/topics/preferences.md\` — Stable choices

## Phase 4 — Prune and Index

Update \`.agents/local.md\` to stay under $MAX_INDEX_LINES lines AND ~$((MAX_INDEX_BYTES / 1024))KB.

**Rules:**
- Index is a **pointer**, not content storage
- Each entry: one line, ~150 chars max
  \`- [Title](topics/file.md#anchor) — Hook\`
- Remove pointers to stale/contradicted entries
- Add pointers to newly important memories
- Keep simple markdown (no complex tables)

**Example index:**

\`\`\`markdown
# Memory Index

## Patterns
- [Result<T> Pattern](topics/patterns.md#result-pattern) — Error handling without throw (seen 5 sessions)
- [Barrel Exports](topics/patterns.md#barrel-exports) — Module organization (seen 3 sessions)

## Gotchas
- [pnpm build hides errors](topics/gotchas.md#pnpm-build) — Always use --noEmit flag
- [DB_URL in unit tests](topics/gotchas.md#db-url) — Set even for mocked tests

## Preferences
- [Dark mode everywhere](topics/preferences.md#dark-mode) — All editors, terminals
\`\`\`

---

**Return a brief summary:**
- What was consolidated
- What was updated
- What was pruned
- Compression ratio (KB in → KB out)

If nothing changed, say so.
EOF
)

# Show prompt (dry run or verbose)
if [[ "$DRY_RUN" == true ]]; then
  echo
  log_info "Would spawn consolidation with prompt:"
  echo "----------------------------------------"
  echo "$PROMPT" | head -50
  echo "... (truncated, full prompt is $(echo "$PROMPT" | wc -l) lines)"
  echo "----------------------------------------"
  echo
  exit 0
fi

# In production, this would spawn an agent session
# For agent-context-system, we leave this as a manual step
# (agent reads this script and executes the consolidation)

log_info "Consolidation prompt ready"
log_info ""
log_info "Next steps:"
log_info "  1. Copy the prompt above to your agent"
log_info "  2. Run consolidation in your agent session"
log_info "  3. Review changes to .agents/topics/*.md"
log_info "  4. Commit if satisfied"
log_info ""
log_info "Or: Use auto-consolidation (if configured in your agent)"

# Release lock (if we acquired it)
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_JSON=$(cat "$LOCK_FILE")
  if echo "$LOCK_JSON" | grep -q '"locked_by"'; then
    # Update lock
    NOW_MS=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
    NEW_LOCK=$(cat <<EOF
{
  "last_consolidated_at": $NOW_MS,
  "locked_by": null,
  "locked_at": null
}
EOF
)
    echo "$NEW_LOCK" > "$LOCK_FILE"
    log_info "Lock released"
  fi
fi
