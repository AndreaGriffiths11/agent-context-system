# Research

Why this works, with receipts.

## Agents have an instruction budget (~150-200 instructions)

HumanLayer found frontier LLMs reliably follow about 150-200 instructions. Claude Code's system prompt eats ~50. That's why `AGENTS.md` stays under 120 lines.

## Available docs ≠ used docs

Vercel ran evals:
- No docs: 53% pass rate
- Skills where agent decides when to read: **53%** (identical to nothing)
- Compressed docs embedded in root file: **100%**

When docs are embedded directly, the agent cannot miss them.

## Context has a lifecycle

LangChain's framework: Write, Select, Compress, Isolate.

- **Write**: Scratchpad at session end
- **Select**: Read both files at start
- **Compress**: At 300 lines, dedupe and merge
- **Isolate**: Project vs personal (committed vs gitignored)

## Sources

| Finding | Source |
|---------|--------|
| Instruction budgets | [HumanLayer](https://www.humanlayer.dev/blog/writing-a-good-claude-md) |
| Passive context 100% pass rate | [Vercel](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals) |
| 2,500+ repos analyzed | [GitHub](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) |
| Context lifecycle framework | [LangChain](https://blog.langchain.com/context-engineering-for-agents/) |
| Three-tier progressive disclosure | [Anthropic](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) |
