# Agent Compatibility

| Agent | Setup |
|-------|-------|
| OpenClaw | Clone into `skills/` directory — reads AGENTS.md natively |
| Claude Code | `CLAUDE.md` symlink → `AGENTS.md` |
| Cursor | `.cursorrules` pointing to AGENTS.md |
| Windsurf | `.windsurfrules` pointing to AGENTS.md |
| GitHub Copilot | `.github/copilot-instructions.md` pointing to AGENTS.md |

## Claude Code Auto Memory

Auto memory (late 2025) handles session-to-session learning in `~/.claude/projects/<project>/memory/`. If you use Claude exclusively, auto memory covers the scratchpad's job. The value here is AGENTS.md itself: structured promotion pathway, instruction budget discipline, and cross-agent compatibility.

## Subagents: When one becomes five

Claude Code has subagents. Copilot CLI has `/fleet` (experimental). Both dispatch parallel agents that don't inherit conversation history.

<img width="855" height="635" alt="subagent context isolation" src="https://github.com/user-attachments/assets/c561960b-6f87-4753-9381-8762c35cbcb6" />

Each subagent starts fresh. The only shared brain is your root instruction file. AGENTS.md goes from "helpful context" to "the only thing preventing five agents from making conflicting decisions."

This is why the template explicitly tells subagents to read `.agents.local.md` too. They won't get it otherwise.
