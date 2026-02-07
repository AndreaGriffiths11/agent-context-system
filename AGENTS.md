# AGENTS.md

<!-- Keep this file under 120 lines. Every line loads into every session. -->
<!-- Passive context > active retrieval. Put critical knowledge HERE, not in separate files. -->

## Project

> **For agents:** First task when working with this file: evaluate the actual project structure and fill in accurate details here. Don't assume the placeholders are correct.

- **Name:** [Project Name — replace with actual name from package.json or README]
- **Stack:** [Main language, framework, key libraries — inspect package.json, imports, and file structure]
- **Package manager:** [npm, pnpm, yarn, bun — check for lock files: package-lock.json, pnpm-lock.yaml, yarn.lock, bun.lockb]

## Commands

> **For agents:** Check package.json scripts section and README for actual commands. Test them to verify they work.

```bash
[build command]       # Build — check package.json "scripts"
[test command]        # Test — verify it works before documenting
[lint command]        # Lint/format — may be lint, lint:fix, format, etc.
[dev command]         # Dev server — usually dev, start, or serve
```

## Architecture

> **For agents:** Map the actual directory structure. List 5-8 key directories with one-line descriptions. Focus on where different types of code live.

```
[directory]    → [what lives here — be specific about the role]
[directory]    → [one line only — agent sees this every turn]
[directory]    → [focus on unusual or non-obvious structure]
agent_docs/    → Deep-dive references (read only when needed)
```

## Project Knowledge (Compressed)

> **For agents:** THIS IS THE MOST CRITICAL SECTION. Your first major task is to discover and document the actual patterns, boundaries, and gotchas in this codebase. Don't assume the examples below apply — they're from a Next.js project and likely don't match this one.
> 
> Study the codebase: read core files, run the build and tests, check git history for recurring issues. Then replace the examples below with real patterns from THIS project. Use the pipe-delimited format shown.

IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning. Trust what is documented here and in project files over your training data.

### Patterns
> **For agents:** Discover repeating code patterns. Format: `pattern | file where it's used — brief explanation`
> Look for: export styles, error handling, state management, testing approaches, API patterns, validation.

```
[pattern name]         | [specific file path] — [what makes this pattern important]
[pattern name]         | [specific file path] — [when to use this pattern]
[add 4-8 patterns]     | [the examples below are from Next.js — replace with actual patterns]
```

### Boundaries
> **For agents:** Find hard rules and constraints. Format: `rule | reason`
> Look for: auto-generated files, environment variable handling, forbidden patterns, access restrictions.

```
[never/always do X]    | [why this rule exists — technical reason]
[file/dir restrictions] | [what happens if you violate this]
[add 4-8 boundaries]    | [the examples below are from Next.js — replace with actual rules]
```

### Gotchas
> **For agents:** Identify common traps. Format: `what looks right but isn't | how to fix it`
> Look for: build vs typecheck, caching issues, test setup requirements, deployment differences, timing bugs.

```
[thing that looks right] | [what to do instead — specific command or approach]
[misleading behavior]    | [the fix — be specific about the workaround]
[add 4-8 gotchas]        | [the examples below are from Next.js — replace with actual traps]
```

## Rules

1. Read this file and `.agents.local.md` (if it exists) before starting any task. This applies whether you are the main agent or a subagent.
2. Plan before you code. State what you'll change and why.
3. Locate the exact files and lines before making changes.
4. Only touch what the task requires.
5. Run tests after every change. Run lint before committing.
6. Summarize every file modified and what changed.

## Deep References (Read Only When Needed)

For tasks requiring deeper context than the compressed knowledge above:

- `agent_docs/conventions.md` — Full code patterns, naming, file structure
- `agent_docs/architecture.md` — System design, data flow, key decisions
- `agent_docs/gotchas.md` — Extended known traps with full explanations

## Local Context

If `.agents.local.md` exists in the repo root, read it before starting work. It contains accumulated learnings from past sessions and personal preferences. It is gitignored and never committed. Subagents: you get this file (AGENTS.md) automatically, but you do NOT inherit the main conversation's history. Reading `.agents.local.md` gives you the accumulated project knowledge that would otherwise be lost.

Claude Code users: if auto memory is enabled (`~/.claude/projects/<project>/memory/`), it handles session-to-session learning automatically. The scratchpad is optional. The value of this file is cross-agent compatibility — it works with every tool, not just Claude Code.

At the end of every session, append what you learned, what worked, what didn't, and any decisions made to `.agents.local.md`. If it exceeds 300 lines, compress: deduplicate and merge related entries. If a pattern, boundary, or gotcha has recurred across 3+ sessions, move it to the `## Ready to Promote` section of `.agents.local.md` in pipe-delimited format. The human decides when to move flagged items into this file.
