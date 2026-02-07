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

# Clean up temp files on exit
temp_file=""
cleanup() { [ -n "$temp_file" ] && rm -f "$temp_file"; return 0; }
trap cleanup EXIT

if [ ! -f "$LOCAL_FILE" ]; then
    echo "No .agents.local.md found. Run ./scripts/init-agent-context.sh first."
    exit 0
fi

if [ ! -f "$AGENTS_FILE" ]; then
    echo "Warning: AGENTS.md not found. Scratchpad diff will be skipped."
fi

# --- Count sessions ---
# Accept flexible session header formats:
#   ### 2024-01-15              (date only)
#   ### 2024-01-15 — Topic      (em dash)
#   ### 2024-01-15 - Topic      (hyphen)
#   ### 2024-1-5 — Topic        (single-digit month/day)
session_count=$(grep -cE "^###\s+[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}" "$LOCAL_FILE" 2>/dev/null || echo "0")
echo "Promotion Analysis"
echo "=================="
echo ""
echo "Sessions logged: $session_count"
echo "Threshold: ${THRESHOLD}+ occurrences across sessions"
echo ""

# --- Helper: skip lines inside HTML comments ---
# Reads stdin, outputs only lines that are not inside <!-- ... --> blocks.
filter_comments() {
    local in_comment=false
    while IFS= read -r line; do
        if $in_comment; then
            # Check for end of comment
            if echo "$line" | grep -q -- '-->'; then
                in_comment=false
            fi
            continue
        fi
        # Check for single-line comment: <!-- ... -->
        if echo "$line" | grep -q '<!--' && echo "$line" | grep -q -- '-->'; then
            continue
        fi
        # Check for start of multi-line comment
        if echo "$line" | grep -q '<!--'; then
            in_comment=true
            continue
        fi
        echo "$line"
    done
}

# --- 1. Show existing Ready to Promote items ---
echo "── Ready to Promote (already flagged) ──────────────────────"
echo ""

in_promote=false
has_items=false
while IFS= read -r line; do
    if echo "$line" | grep -qiE "^##\s+Ready to Promote"; then
        in_promote=true
        continue
    fi
    if $in_promote && echo "$line" | grep -qE "^##\s"; then
        break
    fi
    if $in_promote; then
        echo "$line"
    fi
done < "$LOCAL_FILE" | filter_comments | while IFS= read -r line; do
    # Skip blank lines and blockquote instructions
    if [ -z "$line" ] || echo "$line" | grep -q "^>"; then
        continue
    fi
    echo "  $line"
    # Signal that we found items (write to a temp marker)
    echo "found" > /tmp/.promote_found_$$ 2>/dev/null || true
done

if [ -f /tmp/.promote_found_$$ ]; then
    rm -f /tmp/.promote_found_$$
    has_items=true
fi

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
    temp_file=$(mktemp)

    in_session_log=false
    current_session=""
    while IFS= read -r line; do
        # Match "## Session Log" flexibly (allow trailing whitespace, case variation)
        if echo "$line" | grep -qiE "^##\s+Session\s+Log"; then
            in_session_log=true
            continue
        fi
        # Stop at next ## section that isn't Session Log
        if $in_session_log && echo "$line" | grep -qE "^##\s" && ! echo "$line" | grep -qiE "^##\s+Session\s+Log"; then
            break
        fi
        if $in_session_log; then
            # Match session date headers flexibly
            if echo "$line" | grep -qE "^###\s+[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}"; then
                current_session=$(echo "$line" | sed 's/^###\s*//')
            fi
            # Extract learning-type entries with flexible matching:
            #   - **Learned:** ...    (standard)
            #   - **Learned**: ...    (colon outside bold)
            #   - **Learned** ...     (no colon)
            #   Also accept Done, Worked, Didn't work, Decided
            if echo "$line" | grep -qiE "^\s*-\s+\*\*(Learned|Worked|Didn'?t\s*work|Decided|Done)"; then
                # Strip the markdown prefix to get the content
                content=$(echo "$line" | sed -E 's/^\s*-\s+\*\*[^*]*\*\*:?\s*//')
                if [ -n "$content" ] && [ -n "$current_session" ]; then
                    echo "$content" >> "$temp_file"
                fi
            fi
        fi
    done < "$LOCAL_FILE"

    if [ -s "$temp_file" ]; then
        # Find significant words (4+ chars, not common stopwords) that appear frequently
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

        # Show near-duplicate entries
        echo ""
        echo "── Full entries for review ────────────────────────────────"
        echo ""

        sort "$temp_file" | uniq -c | sort -rn | while read -r count entry; do
            if [ "$count" -ge 2 ]; then
                echo "  [${count}x] $entry"
            fi
        done
    else
        echo "  No learning entries found in session logs."
        echo "  (Entries should use formats like: - **Learned:** ... or - **Worked:** ...)"
    fi
fi

echo ""

# --- 3. Check scratchpad sections for items not yet in AGENTS.md ---
echo "── Scratchpad items not in AGENTS.md ───────────────────────"
echo ""

if [ ! -f "$AGENTS_FILE" ]; then
    echo "  (skipped — AGENTS.md not found)"
else
    found_new=false
    for section in "Patterns" "Gotchas" "Dead Ends"; do
        in_section=false
        in_comment=false
        while IFS= read -r line; do
            # Match section header flexibly
            if echo "$line" | grep -qiE "^##\s+${section}\s*$"; then
                in_section=true
                continue
            fi
            if $in_section && echo "$line" | grep -qE "^##\s"; then
                break
            fi
            if $in_section; then
                # Track HTML comments
                if $in_comment; then
                    echo "$line" | grep -q -- '-->' && in_comment=false
                    continue
                fi
                if echo "$line" | grep -q '<!--' && echo "$line" | grep -q -- '-->'; then
                    continue
                fi
                if echo "$line" | grep -q '<!--'; then
                    in_comment=true
                    continue
                fi

                # Skip blank lines, blockquotes, headers
                [ -z "$line" ] && continue
                echo "$line" | grep -qE "^(>|#)" && continue

                # Check if this content already exists in AGENTS.md
                # Use first significant phrase (first 40 chars) for matching
                check=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | cut -c1-40)
                if [ -n "$check" ] && ! grep -qF "$check" "$AGENTS_FILE" 2>/dev/null; then
                    echo "  [$section] $line"
                    found_new=true
                fi
            fi
        done < "$LOCAL_FILE"
    done

    if ! $found_new; then
        echo "  (nothing new — scratchpad entries already reflected in AGENTS.md)"
    fi
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
