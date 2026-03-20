# FAQ

**I use OpenClaw. Do I need this?**

If OpenClaw is your only coding agent, you probably don't — OpenClaw reads AGENTS.md natively. But if you also code with Claude Code, Cursor, Copilot, or Windsurf, agent-context gives you one shared context file that works across every agent. Write your project rules once, every tool picks them up.

**How is this different from built-in memory (Claude auto memory, Copilot Memory)?**

Built-in memory learns about *you* — your preferences, patterns, style. Agent-context handles what every agent needs to know about *your project* — stack, conventions, architecture decisions. It's shared, version-controlled, and reviewable in PRs.

**Why 120 lines?**

HumanLayer found frontier LLMs follow ~150-200 instructions reliably. Your agent's system prompt uses ~50. That leaves ~120 for project context. Deeper docs go in `agent_docs/` and load on demand.
