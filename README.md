# Agent Context System

I keep a running list of fundamentals. Git. Tests. CI. The stuff that doesn't change every six months. The stuff that makes everything else easier once you learn it.

I think context engineering just made the list.

Not because it's trendy. Because I kept having the same frustrating experience: I'd spend an hour getting my coding agent up to speed on a project, close the session, and start from zero the next day. The agent forgot everything. Every session was a cold start.

So I started digging. I read everything I could find on how agents actually consume context, what they ignore, and why some teams get wildly different results from the same tools. What I found changed how I think about working with agents, and I built this template so you don't have to piece it together yourself.

## What this is

Two markdown files. One committed, one gitignored. The agent reads both at the start of every session and updates the local one at the end.

- `AGENTS.md` — your project's source of truth. Committed and shared. Always in the agent's prompt.
- `.agents.local.md` — your personal scratchpad. Gitignored. Grows over time as the agent logs what it learns each session.

That's it. No plugins, no infrastructure, no background processes. The convention lives inside the files themselves, and the agent follows it.

```
your-repo/
├── AGENTS.md                    # Committed. Always loaded. Under 120 lines.
├── .agents.local.md             # Gitignored. Personal scratchpad.
├── SKILL.md                     # Copilot Custom Skill (full knowledge base).
├── agent_docs/                  # Deeper docs. Read only when needed.
│   ├── conventions.md
│   ├── architecture.md
│   └── gotchas.md
├── docs/                        # Diagrams and visual references.
│   ├── subagent-context.svg
│   └── subagent-context.excalidraw
├── github-copilot/              # Copilot-specific skill definition.
│   └── SKILL.md
├── scripts/
│   ├── init-agent-context.sh
│   ├── publish-template.sh
│   └── agents-local-template.md
├── .github/
│   └── workflows/
│       └── shellcheck.yml       # CI: lints all shell scripts.
├── package.json                 # Skill package metadata for npx skills.
└── CLAUDE.md                    # Symlink → AGENTS.md (created by init)
```

## Install as a Copilot Custom Skill

This repo is packaged as a <a href="https://code.visualstudio.com/docs/copilot/customization/agent-skills">Copilot Custom Skill</a>. You can install it directly into any project so Copilot learns the agent context system patterns.

```bash
# Install the skill into your current project
npx skills add AndreaGriffiths11/agent-context-system
```

That drops a `SKILL.md` into your `.github/skills/` directory. Copilot picks it up automatically when the skill description matches your prompt context. In VS Code, make sure `chat.useAgentSkills` is enabled.

You can also copy `github-copilot/SKILL.md` manually into `.github/skills/agent-context-system/SKILL.md` if you prefer not to use the CLI.

After installing the skill, run the init script to create your local scratchpad:

```bash
bash .agents/skills/agent-context-system/scripts/init-agent-context.sh
```

<details>
<summary><strong>What I learned building this</strong></summary>

I'm going to walk you through the research because understanding the _why_ matters more than copying the files. These are fundamentals. If you understand them, you can adapt the template to your own setup instead of treating it like a black box.

### Agents have an instruction budget and you're probably blowing it

This one surprised me. HumanLayer found that frontier LLMs reliably follow about 150-200 instructions. Sounds generous until you realize Claude Code's system prompt already uses about 50 of those. HumanLayer's own CLAUDE.md is under 60 lines.

It gets worse. Claude Code wraps your CLAUDE.md with a system message that says the content "may or may not be relevant." So anything in your root file that isn't universally applicable to every single task risks getting quietly deprioritized.

That's why `AGENTS.md` in this template stays under 120 lines. I had to be ruthless about what goes in and what gets pushed to separate files.

### Available docs aren't the same as used docs

This was the finding that shaped the whole design. Vercel ran evals testing how agents use documentation:

- No docs: 53% pass rate
- Skills where the agent decides when to read docs: 53%. Identical to having nothing.
- Skills with explicit instructions to use them: 79%
- Compressed docs embedded directly in the root file: 100%

The agents had access to the documentation. They just didn't use it in over half the test cases. When the docs were embedded directly in the root file, there was no decision to make. The agent got the knowledge on every turn automatically.

I used to think the answer was writing better docs and putting them in the right place. Turns out the answer is putting the critical stuff where the agent literally cannot miss it. That's why AGENTS.md has an inline "Project Knowledge" section with compressed patterns, boundaries, and gotchas right in the file.

### The files that actually work are specific

GitHub analyzed over 2,500 agents.md files across public repos. The ones that help are specialists. They put executable commands early. They use code examples instead of paragraphs of explanation. They set explicit boundaries about what not to touch.

"You are a helpful coding assistant" does nothing. "TypeScript, Next.js 15, pnpm, named exports only" does everything. I already knew this from teaching developers — specific beats general every time — but it was good to see the data backing it up at scale.

### Context isn't static. It has a lifecycle.

LangChain frames agent context as four operations: Write, Select, Compress, Isolate. This clicked for me because it explains why just having a good AGENTS.md isn't enough. You also need a place for knowledge to accumulate and a way for it to flow back into the root file over time.

In this template: the agent writes to the scratchpad at session end. It selects by reading both files at session start. The scratchpad compresses when it hits 300 lines. And project context stays isolated from personal context because one is committed and the other is gitignored.

### Deep docs should load on demand

Anthropic's Agent Skills architecture loads context in tiers: metadata first, full instructions when they're relevant, detailed references only when needed. Same idea here. AGENTS.md loads every time. The `agent_docs/` folder is there for when a task needs more depth than the compressed version provides. The agent reads those files when the task calls for it, not by default.

### One file works across every tool

AGENTS.md is the cross-platform standard now. Cursor, Copilot, Codex, Windsurf, Factory all recognize it. Claude Code still only reads CLAUDE.md — the feature request to add AGENTS.md support is open but hasn't shipped as of February 2026. The init script creates a symlink so you maintain one file.

</details>


## How knowledge moves between the files

This is the part that ties it all together. Knowledge doesn't just sit in one place. It flows.

Learnings start as session notes in `.agents.local.md`. The agent writes them at the end of each session. During compression, if a pattern has shown up across 3+ sessions, the agent flags it in the scratchpad's "Ready to Promote" section using the same pipe-delimited format that AGENTS.md expects. Then you decide when to move it into AGENTS.md.

```
Session notes → .agents.local.md → agent flags stable patterns → you promote to AGENTS.md
                    (personal)                                        (shared)
```

The scratchpad is where things are still experimental. AGENTS.md is where proven knowledge lives. The agent flags candidates. You make the call.

## Quick start

### New repo from template

```bash
gh repo create my-project --template YOUR_USERNAME/agent-context-system --private
cd my-project
chmod +x scripts/init-agent-context.sh
./scripts/init-agent-context.sh
```

### Installed as a skill

If you installed via `npx skills add`, the scripts live inside the skill directory, not at the project root:

```bash
bash .agents/skills/agent-context-system/scripts/init-agent-context.sh
```

The init script auto-detects the skill installation and prints the correct re-run path.

### Existing repo

Copy `AGENTS.md`, `agent_docs/`, and `scripts/` into your project root, then run the init script.

### Publish this as your template

```bash
chmod +x scripts/publish-template.sh
./scripts/publish-template.sh
```

## Agent compatibility

The init script asks which tools you use and wires up the right config:

| Agent | What gets created |
|---|---|
| Claude Code | `CLAUDE.md` symlink → `AGENTS.md` |
| Cursor | `.cursorrules` pointing to `AGENTS.md` |
| Windsurf | `.windsurfrules` pointing to `AGENTS.md` |
| GitHub Copilot | `.github/copilot-instructions.md` pointing to `AGENTS.md` |

### A note on Claude Code

Claude Code still reads CLAUDE.md, not AGENTS.md. The feature request is open but as of February 2026 it hasn't shipped. The init script creates a symlink so you maintain one file.

Claude Code also shipped auto memory in late 2025. It creates a `~/.claude/projects/<project>/memory/` directory where Claude writes its own notes as it works and loads them at the start of each session. That's basically our `.agents.local.md` concept, built into the tool.

If you use Claude Code exclusively, auto memory handles session-to-session learning and the scratchpad is optional. The template's value for you is the AGENTS.md file itself: the compressed project knowledge, instruction budget discipline, and the promotion pathway that gives you a structured way to take what auto memory learns and move the stable parts into your root file where they become passive context.

If your team uses multiple agents (which is increasingly common — GitHub just shipped Agent HQ with Copilot, Claude, and Codex side by side), the scratchpad matters because auto memory only works in Claude Code. The scratchpad works everywhere.

### When one agent becomes five

Claude Code now ships subagents. You can spawn parallel agents that explore your codebase, review code, write tests, and debug — all at the same time, each in its own context window. Copilot CLI just shipped `/fleet` in experimental mode (February 5, 2026), which dispatches parallel subagents with a sqlite database tracking dependency-aware tasks. Both tools are moving toward the same model: a lead agent that coordinates a team of specialists.

Subagents don't inherit the main conversation's history. Each one starts with a clean context window. The only shared knowledge they all have is your root instruction file. In Claude Code, that's CLAUDE.md (or AGENTS.md via the symlink). In Copilot CLI, that's your `copilot-instructions.md` pointing to AGENTS.md.

So when you go from one agent to five parallel agents, AGENTS.md goes from "helpful project context" to "the only thing preventing five agents from independently making conflicting decisions about your codebase." The compressed project knowledge, the boundaries section, the gotchas — that's the shared brain. Without it, each subagent rediscovers your project from scratch.

This is why the template explicitly tells subagents to read `.agents.local.md` too. They won't get it by default. They need the instruction.

It's also why instruction budget discipline matters even more. If your AGENTS.md is 500 lines, you're paying that token cost for every subagent you spawn. Five parallel agents reading a bloated root file adds up fast. Under 120 lines, compressed and dense, is a feature not a limitation.

Claude Code's subagent ecosystem is already maturing. You can define custom subagents as markdown files in `.claude/agents/`, give them specific tools and permissions, inject skills, and even give them their own persistent memory directories. Agent Teams (experimental) go further with agents that message each other and share a task board. The pattern is moving from "one smart agent" to "coordinated team reading the same playbook."

That playbook is AGENTS.md.

## CI

Shell scripts in `scripts/` are linted on every push and pull request via <a href="https://www.shellcheck.net/">ShellCheck</a>. The workflow lives in `.github/workflows/shellcheck.yml`.

## Session logging

The system tells agents to "update the scratchpad at session end." But most agents don't have session-end hooks. Copilot Chat, Cursor, and Windsurf sessions just end when you stop talking — no signal fires, no cleanup runs.

Claude Code is the exception: it has auto memory and persistent session context that handle this automatically.

For every other agent, session logging only happens if:
1. The agent sees the instruction early and proactively logs before the conversation ends, or
2. **You prompt the agent.** Say "log this session" or "update the scratchpad" before closing.

The template mitigates this by:
- Putting session-logging as **Rule 7** in `AGENTS.md` (not buried in a Local Context section)
- Making every agent config directive (`.cursorrules`, `.windsurfrules`, `copilot-instructions.md`) explicitly say "at session end, append to `.agents.local.md`" instead of "follow the self-updating protocol"
- Adding a nudge in Rule 7: "If the user ends the session without asking, prompt them to let you log it"

But there's no guarantee. If a long debugging session ends abruptly, the learnings may be lost. Get in the habit of prompting "log this session" when meaningful work was done.

## After setup

1. **Edit `AGENTS.md`.** Fill in your project name, stack, commands. Replace the placeholder patterns and gotchas with real ones from your codebase. This is the highest-leverage edit you'll make.
2. **Fill in `agent_docs/`.** Add deeper references. Delete what doesn't apply.
3. **Customize `.agents.local.md`.** Add your preferences.
4. **Work.** The agent reads everything, does the task, updates the scratchpad.
5. **Promote what sticks.** During compression, the agent flags patterns that have recurred across 3+ sessions in the scratchpad's "Ready to Promote" section. You decide when to move them into AGENTS.md.

## Sources

| What I learned | Where I learned it |
|---|---|
| Write/Select/Compress/Isolate framework | <a href="https://blog.langchain.com/context-engineering-for-agents/">LangChain — Context Engineering for Agents</a> |
| Instruction budgets, root file discipline | <a href="https://www.humanlayer.dev/blog/writing-a-good-claude-md">HumanLayer — Writing a Good CLAUDE.md</a> |
| What makes agents.md files actually work | <a href="https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/">GitHub Blog — Lessons from 2,500+ Repositories</a> |
| Passive context vs skill retrieval eval data | <a href="https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals">Vercel — AGENTS.md Outperforms Skills</a> |
| Three-tier progressive disclosure | <a href="https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills">Anthropic — Equipping Agents with Skills</a> |
| Cross-platform standard adoption | <a href="https://www.aihero.dev/a-complete-guide-to-agents-md">AI Hero — A Complete Guide to AGENTS.md</a> |
| Subagent context isolation, custom agents | <a href="https://code.claude.com/docs/en/sub-agents">Anthropic — Claude Code Subagents Docs</a> |
| Parallel fleets with dependency-aware tasks | <a href="https://x.com/_Evan_Boyle/status/2019497961777172488">Copilot CLI /fleet announcement</a> |
| Built-in agents, auto-compaction, context mgmt | <a href="https://github.blog/changelog/2026-01-14-github-copilot-cli-enhanced-agents-context-management-and-new-ways-to-install/">GitHub Changelog — Copilot CLI Enhanced Agents</a> |

## License

MIT
