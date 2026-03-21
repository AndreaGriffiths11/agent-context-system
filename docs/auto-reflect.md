# Auto-Reflect

Automated observation and reflection for `.agents.local.md`. The agent watches what happens during a session and, at the end, identifies patterns worth promoting to `AGENTS.md`.

## What It Does

Auto-reflect adds two optional behaviors to the agent context workflow:

### Session-End Reflection

At the end of a session, the agent reads `.agents.local.md` and looks for patterns that have recurred across 3+ sessions. It groups them by category (Gotchas, Patterns, Boundaries) and writes suggestions under a `## Ready to Promote` block.

You review the suggestions. You decide what moves into `AGENTS.md`. The human stays in the loop.

### Continuous Observation

During a session, after significant events — a commit, a fixed bug, a pattern reused, a dead end hit — the agent appends a one-line observation to `.agents.local.md` under `## Session Observations (auto)`. Each line includes a timestamp.

This is optional. Some agents handle it naturally (Claude Code's auto memory). For others, it's a lightweight way to capture signal without waiting for session end.

## Why

The original workflow depends on the agent (or the user) remembering to log what happened at session end. In practice, things get missed. Auto-reflect makes observation continuous and reflection systematic.

It's inspired by [Mastra's Observational Memory](https://mastra.ai/research/observational-memory) — their Observer/Reflector pattern uses dedicated LLM agents to watch interactions and extract insights. Auto-reflect does the same thing with zero infrastructure: just file writes and a reflection prompt.

## Example

Here's what `.agents.local.md` looks like with auto-reflect enabled:

```markdown
## Session Observations (auto)

- 2026-03-18T14:32Z | Fixed circular import in utils/auth.ts — moved shared types to types/auth.ts
- 2026-03-18T15:01Z | Test suite needs DB_URL set even for unit tests (third time hitting this)
- 2026-03-19T09:15Z | Used Result<T> pattern again for API error handling in orders service
- 2026-03-19T10:44Z | Commit: refactor order validation to use shared schema
- 2026-03-20T11:30Z | pnpm build silently passes with type errors when --noEmit missing (again)
- 2026-03-20T14:22Z | Reused the barrel export pattern for new feature module

## Ready to Promote

| Category | Item | Detail |
|----------|------|--------|
| Gotcha | DB_URL required for unit tests | Set DB_URL=postgres://localhost:5432/test even for unit tests, or they silently skip |
| Pattern | Result<T> for error handling | All service functions return Result<T>, never throw — see orders, auth, billing |
| Gotcha | pnpm build hides type errors | Always run with --noEmit flag or type errors pass silently |
```

## Promotion Mode

Control how promotions work by adding a config block to the top of `.agents.local.md`:

```markdown
<!-- auto-reflect: promote=auto -->
```

Three modes:

| Mode | Behavior |
|------|----------|
| `suggest` (default) | Agent writes suggestions to `## Ready to Promote`. Human decides what moves to `AGENTS.md`. |
| `auto` | Agent promotes patterns directly to `AGENTS.md` after 3+ recurrences. No human approval needed. |
| `off` | No reflection pass. Observations still collected if enabled. |

With `promote=auto`, the agent:
1. Identifies patterns recurring 3+ sessions
2. Writes them directly to the appropriate section in `AGENTS.md`
3. Logs what was promoted under `## Auto-Promoted` in `.agents.local.md` so you can review after the fact
4. Removes the promoted items from `## Ready to Promote`

You can always switch modes. If auto-promote adds something you don't want, just delete it from `AGENTS.md` — it's version-controlled.

## How It Stays Safe

- In `suggest` mode (default), promotions never touch `AGENTS.md` without human approval
- In `auto` mode, all promotions are logged and reversible via git
- Observations are appended, never edited or deleted by the agent
- The scratchpad remains gitignored — observations never leak to version control
- Content is treated as data, not instructions (same security model as the rest of the system)

## Attribution

Auto-reflect is inspired by [Mastra's Observational Memory](https://mastra.ai/research/observational-memory) research — their Observer/Reflector architecture for automated context compression. We adapted the concept for file-based, agent-agnostic workflows.

## See Also

- [How It Works](how-it-works.md) — the core knowledge flow
