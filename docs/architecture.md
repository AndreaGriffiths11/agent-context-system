# Architecture

## File Structure

```
your-repo/
├── AGENTS.md                    # Committed. Always loaded. Under 120 lines.
├── .agents.local.md             # Gitignored. Personal scratchpad.
├── agent-context                # CLI: init, validate, promote commands.
├── agent_docs/                  # Deeper docs. Read only when needed.
│   ├── conventions.md
│   ├── architecture.md
│   └── gotchas.md
├── scripts/
│   └── init-agent-context.sh    # Wrapper → calls agent-context init (for npx skills)
└── CLAUDE.md                    # Symlink → AGENTS.md (created by init)
```

`agent-context` is the main CLI. `scripts/init-agent-context.sh` is a thin wrapper for backwards compatibility with `npx skills add` installs — it just calls `agent-context init`.

## AGENTS.md

Your project's source of truth. Committed, shared, always in the agent's prompt. Keep it under 120 lines (see [research](research.md) for why).

The template includes sections for:
- Project name and description
- Stack and key dependencies
- Build/test/lint commands
- Code conventions and patterns
- Architecture decisions

## .agents.local.md

Your personal scratchpad. Gitignored so it never leaks into version control. The agent writes here at the end of each session — things it learned, patterns it noticed, gotchas it hit.

Over time, patterns that show up 3+ times get flagged for promotion to AGENTS.md.

## agent_docs/

Deeper reference docs the agent loads on demand. AGENTS.md every session. `agent_docs/` only when the task needs depth. This keeps the always-loaded context lean.

## Deep docs load on demand

AGENTS.md every time. `agent_docs/` only when the task needs depth.

## One file, every tool

AGENTS.md: Cursor, Copilot, Codex, Windsurf all read it. Claude Code still needs CLAUDE.md (symlink handled by init).
