#!/bin/bash
# validate.sh
# Checks AGENTS.md and agent_docs/ for remaining placeholder content.
#
# Scans for common placeholder markers like "[REPLACE", "REPLACE THIS",
# bracket-wrapped placeholders, and template examples that haven't been
# customized. Exits with code 1 if placeholders are found, 0 if clean.
#
# Usage: ./scripts/validate.sh [--quiet]
#   --quiet   Only output the summary line (useful in CI)

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AGENTS_FILE="$REPO_ROOT/AGENTS.md"
QUIET=false

for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=true ;;
    esac
done

# Placeholder patterns to detect (case-insensitive grep -i patterns)
PATTERNS=(
    'REPLACE THIS'
    'REPLACE THESE'
    '\[Project Name'
    '\[Main language'
    '\[npm, pnpm'
    '\[build command\]'
    '\[test command\]'
    '\[lint command\]'
    '\[dev command\]'
    '\[directory\]'
    '\[what lives here'
    '\[one line only'
    '\[pattern name\]'
    '\[specific file path\]'
    '\[never/always do X\]'
    '\[why this rule exists'
    '\[file/dir restrictions\]'
    '\[thing that looks right\]'
    '\[misleading behavior\]'
    '\[add [0-9]'
    '\[Document timing'
    '\[Or remove this'
    '\[e\.g\.,'
)

files_to_check=()
[ -f "$AGENTS_FILE" ] && files_to_check+=("$AGENTS_FILE")

# Add agent_docs/ files if they exist
if [ -d "$REPO_ROOT/agent_docs" ]; then
    for f in "$REPO_ROOT"/agent_docs/*.md; do
        [ -f "$f" ] && files_to_check+=("$f")
    done
fi

# Note: scripts/agents-local-template.md is intentionally full of placeholders
# (it's a template) and is NOT checked here.

if [ ${#files_to_check[@]} -eq 0 ]; then
    echo "No AGENTS.md or agent_docs/ found. Nothing to validate."
    exit 0
fi

total_found=0
declare -A file_counts

for file in "${files_to_check[@]}"; do
    rel_path="${file#"$REPO_ROOT/"}"
    count=0
    for pattern in "${PATTERNS[@]}"; do
        matches=$(grep -ciE "$pattern" "$file" 2>/dev/null || true)
        if [ "$matches" -gt 0 ]; then
            count=$((count + matches))
            if ! $QUIET; then
                # Show each matching line with line number
                grep -niE "$pattern" "$file" 2>/dev/null | while IFS= read -r line; do
                    echo "  $rel_path:$line"
                done
            fi
        fi
    done
    if [ "$count" -gt 0 ]; then
        file_counts["$rel_path"]=$count
        total_found=$((total_found + count))
    fi
done

echo ""
if [ "$total_found" -eq 0 ]; then
    echo "Validation passed. No placeholder content found."
    exit 0
else
    echo "Validation: $total_found placeholder(s) found in ${#file_counts[@]} file(s)."
    if ! $QUIET; then
        echo ""
        echo "Files with placeholders:"
        for file in "${!file_counts[@]}"; do
            echo "  $file — ${file_counts[$file]} placeholder(s)"
        done
        echo ""
        echo "Replace these with your project's actual details."
        echo "See examples/ directory for a filled-in reference."
    fi
    exit 1
fi
