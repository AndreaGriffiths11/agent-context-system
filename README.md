# Agent Context System

Coding agents are good at using context. They are terrible at keeping it consistent.

Tools like GitHub Copilot Memory are doing great work on the individual side. Copilot remembers your preferences, your patterns, your stack. That's a real step forward for developer experience.

But there's a layer that built-in memory doesn't cover: shared, reviewable, version-controlled project context. The stuff that lives in your repo and works across every agent your team uses. Teams still hit the same walls:

- The "rules of the repo" live in chat threads and tribal knowledge
- A new agent or subagent starts without the constraints that matter
- The agent learns something once, then you can't review it like code
- Context drifts because nobody promotes stable decisions into a shared source of truth

This project is a small, boring fix. It doesn't replace built-in memory. It complements it. Built-in memory handles what the tool learns about *you*. This handles what every agent needs to know about *your project*. It makes that context explicit, reviewable, and portable.

## What this is

Two markdown files. One committed, one gitignored. The agent reads both at the start of every session and updates the local one at the end.

- `AGENTS.md` is your project's source of truth. Committed and shared. Always in the agent's prompt.
- `.agents.local.md` is your personal scratchpad. Gitignored. It grows over time as the agent logs what it learns each session.

That's it. No plugins, no infrastructure, no background processes. The convention lives inside the files themselves, and the agent follows it.

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

## Quick Start

```bash
./agent-context init
```

This creates `AGENTS.md`, `.agents.local.md`, symlinks, and adds gitignore entries. See [setup docs](docs/setup.md) for all install options.

## Docs

| Doc | What's in it |
|-----|-------------|
| [Setup](docs/setup.md) | All install options (Copilot, OpenClaw, manual, template, fork) |
| [How It Works](docs/how-it-works.md) | Knowledge flow, session logging, promotion workflow |
| [Architecture](docs/architecture.md) | File structure, AGENTS.md and .agents.local.md templates |
| [Agent Compatibility](docs/agent-compatibility.md) | Supported agents, Claude Code auto memory, subagent context |
| [Research](docs/research.md) | Instruction budgets, Vercel evals, context lifecycle |
| [Security](docs/security.md) | What's committed vs gitignored, team considerations |
| [FAQ](docs/faq.md) | Common questions |

## Auto-Reflect

Agents can now observe during sessions and reflect at session end, automatically surfacing patterns worth promoting to `AGENTS.md`. Inspired by [Mastra's Observational Memory](https://mastra.ai/research/observational-memory), adapted for the file-based world — zero infrastructure, works with any agent.

→ [docs/auto-reflect.md](docs/auto-reflect.md)

## Auto-Consolidation (NEW)

**Automatic memory consolidation** inspired by [claude-code's auto-dream system](https://github.com/lowcortisolprogrammer/claude-code).

Daily logs are consolidated into topic files automatically when:
- ≥24 hours since last consolidation
- ≥5 sessions accumulated
- No other consolidation in progress

**4-phase process:** Orient → Gather → Consolidate → Prune  
**Compression:** ~9:1 ratio (107 KB → 11.6 KB validated)  
**Structure:** Daily logs (append-only) + topic files (curated) + index (200 lines max)

→ [docs/auto-consolidation.md](docs/auto-consolidation.md)

## License

MIT
