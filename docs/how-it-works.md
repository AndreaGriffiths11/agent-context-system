# How It Works

## How knowledge moves

<img width="955" height="502" alt="knowledge flow" src="https://github.com/user-attachments/assets/a5c29763-9eb4-48ef-878d-935797b6febe" />

1. **Write**: Agent logs learnings to `.agents.local.md` at session end
2. **Compress**: Scratchpad compresses when it hits 300 lines
3. **Flag**: Patterns recurring 3+ times get flagged "Ready to Promote"
4. **Promote**: Run `agent-context promote` to review, or `--autopromote` to auto-append to `AGENTS.md`

## Session Logging Reality

Agents don't have session-end hooks. Sessions end when you stop talking. Logging only happens if:

1. Agent proactively logs before conversation ends (rare), or
2. **You prompt it:** "log this session" or "update the scratchpad"

Claude Code handles this well with auto memory. For others, get in the habit of prompting for the log when meaningful work was done.

## After setup

1. **Edit `AGENTS.md`** — Fill in your project name, stack, commands. Replace placeholders with real patterns from your codebase.
2. **Fill in `agent_docs/`** — Add deeper references. Delete what doesn't apply.
3. **Customize `.agents.local.md`** — Add your preferences.
4. **Work** — Agent reads both files, does the task, updates scratchpad.
5. **Promote** — Run `agent-context promote` to see flagged patterns. Move stable ones to AGENTS.md.
