# Security

`.agents.local.md` is gitignored by default. It can contain personal notes, local paths, and session learnings that shouldn't end up in version control.

If you're working on a team:
- `AGENTS.md` is committed — treat it like any other shared doc. No secrets, no personal paths.
- `.agents.local.md` stays local — each developer has their own.
- `agent_docs/` is committed — same rules as AGENTS.md.

The `agent-context init` command adds `.agents.local.md` to `.gitignore` automatically. If you're setting up manually, make sure to add it yourself.
