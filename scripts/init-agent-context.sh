#!/bin/bash
# init-agent-context.sh
# Sets up the local agent scratchpad and agent tool integrations.
# Run once per clone. Safe to re-run.

set -euo pipefail

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
        echo "[!!] Template not found at $TEMPLATE"
        exit 1
    fi
fi

# --- 2. Ensure .gitignore covers local files ---
ensure_gitignored() {
    local pattern="$1"
    if [ -f "$GITIGNORE" ]; then
        if grep -q "^${pattern}$" "$GITIGNORE"; then
            return
        fi
        echo "$pattern" >> "$GITIGNORE"
    else
        echo "$pattern" > "$GITIGNORE"
    fi
}

ensure_gitignored ".agents.local.md"
echo "[ok] .agents.local.md is gitignored."

# --- 3. Agent integrations ---
echo ""
echo "Which agents do you use? (comma-separated, or 'all', or 'none')"
echo "  Options: claude, cursor, windsurf, copilot, all, none"
read -r AGENTS

setup_claude() {
    local target="$REPO_ROOT/CLAUDE.md"
    # Symlink AGENTS.md -> CLAUDE.md so Claude Code reads the same file
    if [ -L "$target" ]; then
        echo "  [ok] CLAUDE.md symlink already exists."
    elif [ -f "$target" ]; then
        # Existing CLAUDE.md — append pointer instead of replacing
        if ! grep -q "AGENTS.md" "$target"; then
            echo "" >> "$target"
            echo "## Agent Context" >> "$target"
            echo "Read \`AGENTS.md\` and \`.agents.local.md\` (if it exists) before starting any task." >> "$target"
            echo "Follow the self-updating protocol defined in \`AGENTS.md\`." >> "$target"
            echo "  [ok] Added agent context section to existing CLAUDE.md."
        else
            echo "  [ok] CLAUDE.md already references AGENTS.md."
        fi
    else
        if [ -f "$REPO_ROOT/AGENTS.md" ]; then
            ln -s AGENTS.md "$target"
            echo "  [ok] Created CLAUDE.md -> AGENTS.md symlink."
        else
            echo "  [skip] AGENTS.md not found — skipping CLAUDE.md symlink."
        fi
    fi
    echo ""
    echo "  Note: Claude Code has built-in auto memory (~/.claude/projects/<project>/memory/)."
    echo "  If auto memory is enabled, it handles session-to-session learning for Claude Code."
    echo "  The .agents.local.md scratchpad is still useful for cross-agent compatibility"
    echo "  and for the promotion pathway into AGENTS.md."
}

setup_cursor() {
    local target="$REPO_ROOT/.cursorrules"
    if [ -f "$target" ] && grep -q "AGENTS.md" "$target"; then
        echo "  [ok] .cursorrules already references AGENTS.md."
        return
    fi
    local directive="Before starting any task, read AGENTS.md and .agents.local.md in the repo root. Follow the self-updating protocol defined in AGENTS.md."
    if [ -f "$target" ]; then
        echo "" >> "$target"
        echo "$directive" >> "$target"
        echo "  [ok] Added agent context to existing .cursorrules."
    else
        echo "$directive" > "$target"
        echo "  [ok] Created .cursorrules."
    fi
}

setup_windsurf() {
    local target="$REPO_ROOT/.windsurfrules"
    if [ -f "$target" ] && grep -q "AGENTS.md" "$target"; then
        echo "  [ok] .windsurfrules already references AGENTS.md."
        return
    fi
    local directive="Before starting any task, read AGENTS.md and .agents.local.md in the repo root. Follow the self-updating protocol defined in AGENTS.md."
    if [ -f "$target" ]; then
        echo "" >> "$target"
        echo "$directive" >> "$target"
        echo "  [ok] Added agent context to existing .windsurfrules."
    else
        echo "$directive" > "$target"
        echo "  [ok] Created .windsurfrules."
    fi
}

setup_copilot() {
    local dir="$REPO_ROOT/.github"
    local target="$dir/copilot-instructions.md"
    mkdir -p "$dir"
    if [ -f "$target" ] && grep -q "AGENTS.md" "$target"; then
        echo "  [ok] copilot-instructions.md already references AGENTS.md."
        return
    fi
    if [ -f "$target" ]; then
        echo "" >> "$target"
        echo "## Agent Context" >> "$target"
        echo "Read \`AGENTS.md\` and \`.agents.local.md\` (if it exists) before starting any task." >> "$target"
        echo "Follow the self-updating protocol defined in \`AGENTS.md\`." >> "$target"
        echo "  [ok] Added agent context to existing copilot-instructions.md."
    else
        cat > "$target" << 'EOF'
# Copilot Instructions

## Agent Context
Read `AGENTS.md` and `.agents.local.md` (if it exists) before starting any task.
Follow the self-updating protocol defined in `AGENTS.md`.
EOF
        echo "  [ok] Created .github/copilot-instructions.md."
    fi
}

if [ "$AGENTS" = "none" ] || [ -z "$AGENTS" ]; then
    echo "Skipping agent integrations."
else
    echo ""
    if [ "$AGENTS" = "all" ]; then
        setup_claude
        setup_cursor
        setup_windsurf
        setup_copilot
    else
        IFS=',' read -ra SELECTED <<< "$AGENTS"
        for agent in "${SELECTED[@]}"; do
            agent=$(echo "$agent" | xargs)
            case "$agent" in
                claude)   setup_claude ;;
                cursor)   setup_cursor ;;
                windsurf) setup_windsurf ;;
                copilot)  setup_copilot ;;
                *)        echo "  [??] Unknown agent: $agent (skipping)" ;;
            esac
        done
    fi
fi

echo ""
echo "Done."
echo ""
echo "Next steps:"
echo "  1. Edit AGENTS.md — fill in your project stack and commands"
echo "  2. Edit agent_docs/ — add conventions, architecture, gotchas"
echo "  3. Edit .agents.local.md — add your personal preferences"
echo "  4. Start a session with any agent. It reads, it learns, it updates."
