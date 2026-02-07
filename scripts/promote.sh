#!/bin/bash
# promote.sh
# Analyzes .agents.local.md and suggests patterns to promote into AGENTS.md.
#
# What it does:
#   1. Shows anything already in the "Ready to Promote" section
#   2. Scans session logs for recurring themes (words/phrases appearing in 3+ sessions)
#   3. Prints suggestions in pipe-delimited format ready to paste into AGENTS.md
#
# Usage: ./scripts/promote.sh

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOCAL_FILE="$REPO_ROOT/.agents.local.md"
AGENTS_FILE="$REPO_ROOT/AGENTS.md"
THRESHOLD=3  # minimum session occurrences to flag

if [ ! -f "$LOCAL_FILE" ]; then
    echo "No .agents.local.md found. Nothing to analyze."
    exit 0
fi

# --- Count sessions ---
session_count=$(grep -c "^### [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" "$LOCAL_FILE" 2>/dev/null || echo "0")
echo "Promotion Analysis"
echo "=================="
echo ""
echo "Sessions logged: $session_count"
echo "Threshold: ${THRESHOLD}+ occurrences across sessions"
echo ""

# --- 1. Show existing Ready to Promote items ---
echo "── Ready to Promote (already flagged) ──────────────────────"
echo ""

# Extract content between "## Ready to Promote" and the next "##" heading
in_promote=false
has_items=false
while IFS= read -r line; do
    if echo "$line" | grep -q "^## Ready to Promote"; then
        in_promote=true
        continue
    fi
    if $in_promote && echo "$line" | grep -q "^## "; then
        break
    fi
    if $in_promote; then
        # Skip HTML comments and blank lines
        if echo "$line" | grep -q "^<!--" || echo "$line" | grep -q "^$" || echo "$line" | grep -q "-->"; then
            continue
        fi
        if [ -n "$line" ]; then
            echo "  $line"
            has_items=true
        fi
    fi
done < "$LOCAL_FILE"

if ! $has_items; then
    echo "  (none)"
fi
echo ""

# --- 2. Analyze session logs for recurring Learned/Gotcha/Pattern entries ---
echo "── Recurring themes across sessions ────────────────────────"
echo ""

if [ "$session_count" -lt "$THRESHOLD" ]; then
    echo "  Not enough sessions yet ($session_count < $THRESHOLD). Keep working."
    echo ""
else
    # Extract lines from session logs that contain learnings
    # Look for Learned:, Worked:, Didn't work:, and pattern-like lines
    temp_file=$(mktemp)

    in_session_log=false
    current_session=""
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## Session Log"; then
            in_session_log=true
            continue
        fi
        if $in_session_log && echo "$line" | grep -q "^## " && ! echo "$line" | grep -q "^## Session Log"; then
            break
        fi
        if $in_session_log; then
            if echo "$line" | grep -q "^### [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}"; then
                current_session=$(echo "$line" | sed 's/^### //')
            fi
            # Extract learning-type entries
            if echo "$line" | grep -qiE "^\- \*\*(Learned|Worked|Didn't work|Decided):\*\*"; then
                # Strip the markdown prefix to get the content
                content=$(echo "$line" | sed 's/^- \*\*[^*]*\*\* *//')
                if [ -n "$content" ] && [ -n "$current_session" ]; then
                    echo "$content" >> "$temp_file"
                fi
            fi
        fi
    done < "$LOCAL_FILE"

    if [ -s "$temp_file" ]; then
        # Find significant words (3+ chars, not common stopwords) that appear frequently
        # This is a rough heuristic — group by shared significant tokens
        cat "$temp_file" | \
            tr '[:upper:]' '[:lower:]' | \
            tr -cs '[:alnum:]' '\n' | \
            sort | uniq -c | sort -rn | \
            while read -r count word; do
                # Skip short words and common stopwords
                if [ ${#word} -lt 4 ]; then continue; fi
                case "$word" in
                    this|that|with|from|have|been|were|they|them|their|what|when|where|which|will|would|could|should|does|also|more|than|into|only|other|some|just|about|very|after|before|first|still|because|through|between|each|under|same|over|such|most|then|these|those|being|using|used|make|made|need|like|work|file|files|code|dont|didnt|cant|wont) continue ;;
                esac
                if [ "$count" -ge "$THRESHOLD" ]; then
                    echo "  [${count}x] \"$word\" — appears in $count entries"
                fi
            done

        # Show the actual entries that contain recurring words
        echo ""
        echo "── Full entries for review ────────────────────────────────"
        echo ""

        # Also check for near-duplicate entries (lines appearing more than once)
        sort "$temp_file" | uniq -c | sort -rn | while read -r count entry; do
            if [ "$count" -ge 2 ]; then
                echo "  [${count}x] $entry"
            fi
        done
    else
        echo "  No learning entries found in session logs."
        echo "  (Entries should use the format: - **Learned:** ...)"
    fi

    rm -f "$temp_file"
fi

echo ""

# --- 3. Check scratchpad sections for items not yet in AGENTS.md ---
echo "── Scratchpad items not in AGENTS.md ───────────────────────"
echo ""

found_new=false
for section in "Patterns" "Gotchas"; do
    in_section=false
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## ${section}$"; then
            in_section=true
            continue
        fi
        if $in_section && echo "$line" | grep -q "^## "; then
            break
        fi
        if $in_section; then
            # Skip comments and empty lines
            if echo "$line" | grep -q "^<!--" || echo "$line" | grep -q "^$" || echo "$line" | grep -q "-->"; then
                continue
            fi
            if [ -n "$line" ] && ! echo "$line" | grep -q "^#"; then
                # Check if this content already exists in AGENTS.md
                # Use first significant phrase (first 30 chars) for matching
                check=$(echo "$line" | sed 's/^- //' | cut -c1-30)
                if [ -n "$check" ] && ! grep -qF "$check" "$AGENTS_FILE" 2>/dev/null; then
                    echo "  [$section] $line"
                    found_new=true
                fi
            fi
        fi
    done < "$LOCAL_FILE"
done

if ! $found_new; then
    echo "  (nothing new — scratchpad entries already reflected in AGENTS.md)"
fi

echo ""
echo "── What to do ──────────────────────────────────────────────"
echo ""
echo "  To promote an item, add it to the appropriate section in AGENTS.md:"
echo "    Patterns  → ### Patterns  (format: pattern | where-to-see-it)"
echo "    Boundaries → ### Boundaries (format: rule | reason)"
echo "    Gotchas   → ### Gotchas   (format: trap | fix)"
echo ""
echo "  Then remove it from .agents.local.md's Ready to Promote section."
echo ""
