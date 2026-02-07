#!/bin/bash
# init-agent-context.sh
# Sets up AGENTS.md as your single context file and creates the local scratchpad.
# Run once per clone. Safe to re-run.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOCAL_FILE="$REPO_ROOT/.agents.local.md"
TEMPLATE="$REPO_ROOT/scripts/agents-local-template.md"
GITIGNORE="$REPO_ROOT/.gitignore"

echo "Agent Context System — Init"
echo ""

# --- 1. Create .agents.local.md ---
if [ -f "$LOCAL_FILE" ]; then
    echo "[ok] .agents.local.md already exists."
else
    if [ -f "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$LOCAL_FILE"
        echo "[ok] Created .agents.local.md from template."
    else
        # Fallback: create a minimal scratchpad if the template wasn't copied.
        # This handles the case where someone copies AGENTS.md manually without
        # the full scripts/ directory.
        cat > "$LOCAL_FILE" << 'FALLBACK_EOF'
# .agents.local.md — Local Agent Scratchpad

> Gitignored. Never committed. Persistent memory across agent sessions.

## Preferences

## Patterns

## Gotchas

## Dead Ends

## Ready to Promote

## Session Log

## Compression Log
FALLBACK_EOF
        echo "[ok] Created minimal .agents.local.md (template not found, used fallback)."
    fi
fi

# --- 2. Ensure .gitignore covers local files ---
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "^\.agents\.local\.md$" "$GITIGNORE"; then
        echo ".agents.local.md" >> "$GITIGNORE"
    fi
else
    echo ".agents.local.md" > "$GITIGNORE"
fi
echo "[ok] .agents.local.md is gitignored."

# --- 3. Claude Code symlink ---
# AGENTS.md is the cross-platform standard. Cursor, Copilot, Codex, Windsurf,
# and Factory all read it natively. Claude Code still reads CLAUDE.md as of
# Feb 2026, so we create a symlink. When Claude Code adds AGENTS.md support,
# delete the symlink and this block.
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
if [ -L "$CLAUDE_MD" ]; then
    echo "[ok] CLAUDE.md symlink already exists."
elif [ -f "$CLAUDE_MD" ]; then
    if ! grep -q "AGENTS.md" "$CLAUDE_MD"; then
        echo "" >> "$CLAUDE_MD"
        echo "Read AGENTS.md and .agents.local.md (if it exists) before starting any task." >> "$CLAUDE_MD"
    fi
    echo "[ok] CLAUDE.md already exists — added pointer to AGENTS.md."
else
    ln -s AGENTS.md "$CLAUDE_MD"
    echo "[ok] Created CLAUDE.md -> AGENTS.md symlink."
fi

echo ""
echo "Done. Two files, one idea:"
echo ""
echo "  AGENTS.md          — committed, shared, always in the prompt"
echo "  .agents.local.md   — gitignored, personal, grows over time"
echo ""
echo "Next steps:"
echo "  1. Edit AGENTS.md — fill in your project's stack, commands, and knowledge"
echo "  2. Edit agent_docs/ — add conventions, architecture, gotchas"
echo "  3. Start a session. The agent reads both files, does the task, updates the scratchpad."
