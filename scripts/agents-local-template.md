# .agents.local.md — Local Agent Scratchpad

> Gitignored. Never committed. Persistent memory across agent sessions.
>
> **For agents:** This is YOUR scratchpad. Write what you learn at the end of each session. Be specific about what worked, what didn't, and why. Future sessions will read this to understand the project's history and quirks.

## Preferences

> **For humans:** Tell the agent how you like to work. Be specific about style, code changes, and planning approach.

- **Style:** [e.g., Friendly, technical, peer-to-peer. No corporate jargon. Skip obvious explanations.]
- **Code:** [e.g., Minimal changes only. Verify before committing. No speculative refactors unless asked.]
- **Planning:** [e.g., Always state the plan before writing code. Break large changes into small PRs.]

## Patterns

> **For agents:** As you discover patterns in this project, document them here. When a pattern appears consistently across 3+ sessions, flag it for promotion to AGENTS.md.

<!-- Settled truths about this project. Examples:
- API routes use /api/v2 prefix, not /api/v1 (v1 is deprecated)
- Tests mock the database using fixtures in tests/fixtures/
- Error messages must be i18n-ready (use error codes, not hardcoded strings)
-->

## Gotchas

> **For agents:** Document traps you've encountered. Include WHY they're traps and what to do instead.

<!-- Things that look right but aren't. Examples:
- Running `npm test` without DB_URL set fails silently — tests pass but skip integration tests
- Changing constants.ts requires restarting the dev server (not hot-reloaded)
- The staging environment uses production API keys (not staging keys) for payment provider
-->

## Dead Ends

> **For agents:** Track approaches that failed. Save future sessions from repeating the same mistakes.

<!-- Approaches tried and failed. Include WHY they failed. Examples:
- Tried using React.lazy for modal components — caused hydration mismatches
- Attempted to use WebSockets for notifications — Vercel serverless doesn't support long-lived connections
- Tried optimistic updates for comments — race conditions with replies made it unreliable
-->

## Ready to Promote

> **For agents:** When compressing this file, flag patterns that have recurred across 3+ sessions here. Use the pipe-delimited format that AGENTS.md expects. The human decides when to move them into AGENTS.md.

<!-- The agent flags items here during compression when a pattern has recurred across 3+ sessions.
     The human decides when to move them into AGENTS.md's Project Knowledge section.
     Use the same pipe-delimited format AGENTS.md expects:
       pattern | where-to-see-it    → goes in Patterns
       rule | reason                → goes in Boundaries
       trap | fix                   → goes in Gotchas
-->

## Session Log

> **For agents:** Append new entries at the END after completing work. One entry per session. Keep each to 5-10 lines. Be specific.

<!-- Append new entries at the END. One entry per session. Keep each to 5-10 lines. -->

### YYYY-MM-DD — Topic

**Template for new sessions (REPLACE THIS):**

- **Done:** (what changed — be specific about files and functionality)
- **Worked:** (approaches that succeeded — reuse these)
- **Didn't work:** (what failed — avoid repeating this)
- **Decided:** (choices and reasoning — why this approach vs alternatives)
- **Learned:** (new patterns or gotchas discovered — especially non-obvious behaviors)

---

## Compression Log

> **For agents:** When this file exceeds 300 lines, compress it. Deduplicate, merge related entries, and flag recurring patterns for promotion. Log the compression here with the date.

<!-- When this file exceeds 300 lines, compress. Log it here.
Example:
2025-03-15 — Compressed from 340 to 180 lines. Merged 8 duplicate gotchas, flagged 3 patterns for promotion.
-->
