---
name: agent-context
description: Bootstrap persistent project context for AI coding agents.
version: 1.0.0
metadata:
  openclaw:
    requires:
      bins:
        - bash
        - git
    emoji: "🧠"
    homepage: https://github.com/AndreaGriffiths11/agent-context-system
    os:
      - macos
      - linux
---

# Agent Context System

Agents start from zero every session. This skill fixes that.

## The Two-File System

- **`AGENTS.md`** — Project source of truth. Committed and shared. Under 120 lines. Contains compressed project knowledge: patterns, boundaries, gotchas, commands.
- **`.agents.local.md`** — Personal scratchpad. Gitignored. Grows as you log what you learn each session.

## Quick Start

```bash
# Install from ClawHub
clawhub install agent-context

# Initialize in your project
agent-context init
```

## Commands

```bash
agent-context init      # Set up context system in current project
agent-context validate  # Check setup is correct
agent-context promote   # Find patterns to move from scratchpad to AGENTS.md
```

## Workflow

1. **Init**: Run `agent-context init`. Creates `.agents.local.md`, ensures it's gitignored, creates CLAUDE.md symlink.

2. **Work**: Read both files at session start. `AGENTS.md` = project knowledge. `.agents.local.md` = personal learnings.

3. **Log**: At session end, append to scratchpad: what changed, what worked, decisions made, patterns learned.

4. **Compress**: When scratchpad hits 300 lines, compress: dedupe, merge related entries.

5. **Promote**: Patterns recurring across 3+ sessions get flagged. Run `agent-context promote` to see candidates. You decide what moves to `AGENTS.md`.

## Key Resources

- **Project template**: `AGENTS.md` — the committed file structure and format
- **Scripts**: `scripts/` — init, publish
- **Deep docs**: `agent_docs/` — conventions, architecture, gotchas (load on demand)

## Important Context

- **Instruction budget**: Frontier LLMs follow ~150-200 instructions. Keep `AGENTS.md` under 120 lines.
- **Passive context wins**: Vercel evals showed 100% pass rate with embedded context vs 53% when agents decide to look things up.
- **Subagent-ready**: Subagents don't inherit conversation history. They only get root instruction files. Tell them to read `.agents.local.md` too.

## Session Protocol

1. Read `AGENTS.md` and `.agents.local.md` before starting any task
2. Follow project conventions and boundaries
3. At session end, append to scratchpad:
   - Done: (what changed)
   - Worked: (reuse this)
   - Didn't work: (avoid this)
   - Decided: (choices and reasoning)
   - Learned: (new patterns)
4. When scratchpad exceeds 300 lines, compress and flag recurring patterns for promotion
