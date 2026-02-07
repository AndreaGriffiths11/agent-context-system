#!/bin/bash
# compress.sh
# Assists with compressing .agents.local.md when it grows too large.
#
# What it does:
#   1. Reports current line count and section sizes
#   2. Identifies duplicate or near-duplicate entries across sessions
#   3. Finds patterns recurring 3+ times (candidates for Ready to Promote)
#   4. Creates a backup before any manual compression
#
# This script does NOT automatically rewrite the file — compression requires
# judgment about what to keep. It gives you the data to make good decisions.
#
# Usage: ./scripts/compress.sh [--backup]
#   --backup   Create a timestamped backup of .agents.local.md

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOCAL_FILE="$REPO_ROOT/.agents.local.md"
COMPRESS_THRESHOLD=300  # lines before compression is recommended
PROMOTE_THRESHOLD=3     # sessions before flagging for promotion

if [ ! -f "$LOCAL_FILE" ]; then
    echo "No .agents.local.md found. Nothing to compress."
    exit 0
fi

# --- Handle --backup flag ---
for arg in "$@"; do
    case "$arg" in
        --backup|-b)
            backup_file="$REPO_ROOT/.agents.local.md.backup.$(date +%Y%m%d-%H%M%S)"
            cp "$LOCAL_FILE" "$backup_file"
            echo "Backup created: $backup_file"
            echo ""
            ;;
    esac
done

# --- 1. Line count and section sizes ---
total_lines=$(wc -l < "$LOCAL_FILE")
echo "Compression Analysis"
echo "===================="
echo ""
echo "Total lines: $total_lines (threshold: $COMPRESS_THRESHOLD)"

if [ "$total_lines" -lt "$COMPRESS_THRESHOLD" ]; then
    echo "Status: No compression needed yet."
else
    echo "Status: COMPRESSION RECOMMENDED"
fi
echo ""

echo "── Section sizes ───────────────────────────────────────────"
echo ""

current_section=""
section_start=0
line_num=0
declare -A section_sizes

while IFS= read -r line; do
    line_num=$((line_num + 1))
    if echo "$line" | grep -qE "^##\s"; then
        if [ -n "$current_section" ]; then
            size=$((line_num - section_start))
            section_sizes["$current_section"]=$size
        fi
        current_section=$(echo "$line" | sed -E 's/^##\s+//')
        section_start=$line_num
    fi
done < "$LOCAL_FILE"

# Last section
if [ -n "$current_section" ]; then
    size=$((line_num - section_start + 1))
    section_sizes["$current_section"]=$size
fi

# Sort sections by size (largest first)
for section in "${!section_sizes[@]}"; do
    echo "${section_sizes[$section]} $section"
done | sort -rn | while read -r size name; do
    printf "  %-25s %d lines\n" "$name" "$size"
done
echo ""

# --- 2. Count sessions ---
session_count=$(grep -cE "^###\s+[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}" "$LOCAL_FILE" 2>/dev/null || echo "0")
echo "── Session log stats ───────────────────────────────────────"
echo ""
echo "  Sessions: $session_count"

if [ "$session_count" -gt 0 ]; then
    # Show oldest and newest sessions
    first_session=$(grep -E "^###\s+[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}" "$LOCAL_FILE" | head -1 | sed -E 's/^###\s+//')
    last_session=$(grep -E "^###\s+[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}" "$LOCAL_FILE" | tail -1 | sed -E 's/^###\s+//')
    echo "  Oldest: $first_session"
    echo "  Newest: $last_session"
fi
echo ""

# --- 3. Find duplicate/near-duplicate entries ---
echo "── Duplicate entries (safe to merge) ─────────────────────"
echo ""

temp_file=$(mktemp)
trap "rm -f '$temp_file'" EXIT

# Extract all learning-type entries from session logs
in_session_log=false
while IFS= read -r line; do
    if echo "$line" | grep -qiE "^##\s+Session\s+Log"; then
        in_session_log=true
        continue
    fi
    if $in_session_log && echo "$line" | grep -qE "^##\s" && ! echo "$line" | grep -qiE "^##\s+Session\s+Log"; then
        break
    fi
    if $in_session_log; then
        if echo "$line" | grep -qiE "^\s*-\s+\*\*(Learned|Worked|Didn'?t\s*work|Decided|Done|Gotcha)"; then
            echo "$line" >> "$temp_file"
        fi
    fi
done < "$LOCAL_FILE"

has_dupes=false
if [ -s "$temp_file" ]; then
    sort "$temp_file" | uniq -c | sort -rn | while read -r count entry; do
        if [ "$count" -ge 2 ]; then
            echo "  [${count}x] $entry"
            has_dupes=true
        fi
    done
fi

if ! $has_dupes; then
    echo "  (no exact duplicates found)"
fi
echo ""

# --- 4. Promotion candidates ---
echo "── Promotion candidates (${PROMOTE_THRESHOLD}+ sessions) ──────────────────"
echo ""

if [ "$session_count" -lt "$PROMOTE_THRESHOLD" ]; then
    echo "  Not enough sessions yet ($session_count < $PROMOTE_THRESHOLD)."
else
    # Find significant recurring words
    has_candidates=false
    if [ -s "$temp_file" ]; then
        cat "$temp_file" | \
            sed -E 's/^\s*-\s+\*\*[^*]*\*\*:?\s*//' | \
            tr '[:upper:]' '[:lower:]' | \
            tr -cs '[:alnum:]' '\n' | \
            sort | uniq -c | sort -rn | \
            while read -r count word; do
                if [ ${#word} -lt 4 ]; then continue; fi
                case "$word" in
                    this|that|with|from|have|been|were|they|them|their|what|when|where|which|will|would|could|should|does|also|more|than|into|only|other|some|just|about|very|after|before|first|still|because|through|between|each|under|same|over|such|most|then|these|those|being|using|used|make|made|need|like|work|file|files|code|dont|didnt|cant|wont) continue ;;
                esac
                if [ "$count" -ge "$PROMOTE_THRESHOLD" ]; then
                    echo "  [${count}x] \"$word\""
                fi
            done
    fi

    if ! $has_candidates; then
        echo "  (no strong promotion candidates yet)"
    fi
fi

echo ""
echo "── Compression checklist ─────────────────────────────────"
echo ""
echo "  1. Run ./scripts/compress.sh --backup to save a copy first"
echo "  2. Merge duplicate session entries (same learnings across sessions)"
echo "  3. Move stable patterns to ## Ready to Promote (pipe-delimited format)"
echo "  4. Delete session entries older than ~10 sessions (keep recent context)"
echo "  5. Consolidate ## Dead Ends (remove entries that are no longer relevant)"
echo "  6. Log the compression in ## Compression Log:"
echo "     $(date +%Y-%m-%d) — Compressed from $total_lines to [new count] lines. [summary]"
echo ""
