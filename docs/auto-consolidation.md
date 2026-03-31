### Auto-Consolidation

**Status:** NEW (added 2026-03-31)

Automatic memory consolidation inspired by [claude-code's auto-dream system](https://github.com/lowcortisolprogrammer/claude-code).

#### What It Does

Consolidates daily logs into topic files automatically when:
- ≥24 hours since last consolidation
- ≥5 sessions accumulated
- No other consolidation in progress (lock mechanism)

#### How It Works

**4-Phase Process:**

1. **Orient** — Read `.agents/local.md` index + existing topic files
2. **Gather** — Scan recent daily logs for new signal
3. **Consolidate** — Merge into topic files, de-duplicate, convert relative dates
4. **Prune** — Update index, stay under 200 lines / 25KB

**Compression:** ~9:1 ratio (validated: 107 KB → 11.6 KB on first run)

#### Structure

```
.agents/
├── local.md                    # Index (200 lines max, ~25KB cap)
├── .consolidation-lock         # Lock file (multi-process safety)
├── logs/
│   ├── 2026-03-25.md           # Daily log (append-only, raw)
│   ├── 2026-03-26.md           # Daily log (append-only, raw)
│   └── 2026-03-31.md           # Daily log (append-only, raw)
└── topics/
    ├── patterns.md             # Curated patterns (de-duplicated, dated)
    ├── gotchas.md              # Curated gotchas (de-duplicated, dated)
    └── preferences.md          # Curated preferences (de-duplicated, dated)
```

#### Daily Logs (Append-Only)

**Location:** `.agents/logs/YYYY-MM-DD.md`

**Format:**
```markdown
# Daily Log — YYYY-MM-DD

## Session HH:MM EDT

### What Changed
- Added feature X
- Fixed bug Y

### What Worked
- Pattern Z applied successfully

### What Didn't
- Approach A failed (use B instead)

### Patterns Learned
- When X happens, do Y

### Decisions Made
- Chose A over B because C
```

**Rules:**
- **Append-only** — Never edit past logs
- **Raw stream** — No de-duplication, no editing
- **Date-stamped** — One file per day (YYYY-MM-DD.md)
- **Session-scoped** — Group by session time

#### Topic Files (Curated)

**Location:** `.agents/topics/*.md`

**Format:**
```markdown
---
type: pattern  # pattern | gotcha | preference
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Title

## What
[Brief description]

## Where
[Where this appears, with links]

## Why
[Reasoning or context]

## Example
[Concrete example or command]

## History
- Added: YYYY-MM-DD (first seen)
- Updated: YYYY-MM-DD (merged from session X)
```

**Rules:**
- **De-duplicated** — No near-duplicates (merge similar entries)
- **Dated** — Track when created + last updated
- **Absolute dates** — Convert "yesterday" → "2026-03-31"
- **Curated** — Only proven patterns (3+ sessions)

#### Index File (Pointer)

**Location:** `.agents/local.md`

**Format:**
```markdown
# Memory Index

## Patterns
- [Result<T> Pattern](topics/patterns.md#result-pattern) — Error handling without throw (seen 5 sessions)
- [Barrel Exports](topics/patterns.md#barrel-exports) — Module organization (seen 3 sessions)

## Gotchas
- [pnpm build hides errors](topics/gotchas.md#pnpm-build) — Always use --noEmit flag
- [DB_URL in unit tests](topics/gotchas.md#db-url) — Set even for mocked tests

## Preferences
- [Dark mode everywhere](topics/preferences.md#dark-mode) — All editors, terminals
```

**Rules:**
- **Pointer only** — Not content storage
- **One line per entry** — ~150 chars max
- **Cap:** 200 lines AND ~25KB
- **Auto-prune** — During consolidation, remove stale entries

#### Lock Mechanism

**Location:** `.agents/.consolidation-lock`

**Format:**
```json
{
  "last_consolidated_at": 1774952228616,
  "locked_by": "auto-consolidation",
  "locked_at": 1774952228616
}
```

**Timeout:** 30 minutes (stale lock detection)

**Purpose:** Prevent concurrent consolidation (multi-process safety)

#### Gates

**Time Gate:**
- Requires: ≥24 hours since `last_consolidated_at`
- Check: Compare current time vs lock file timestamp

**Session Gate:**
- Requires: ≥5 sessions accumulated
- Check: Count daily log files modified since `last_consolidated_at`

**Lock Gate:**
- Requires: No other consolidation in progress
- Check: Lock file has `locked_by: null` OR lock is stale (>30min old)

#### Scripts

**Check if consolidation should trigger:**
```bash
./scripts/auto-consolidation-trigger.sh --check
```

**Force consolidation (bypass time/session gates):**
```bash
./scripts/auto-consolidation-trigger.sh --force
./scripts/consolidate-memory.sh
```

**Migrate from old `.agents.local.md`:**
```bash
./scripts/migrate-to-daily-logs.sh
```

**Dry-run consolidation:**
```bash
./scripts/consolidate-memory.sh --dry-run
```

#### Integration with auto-reflect

Auto-reflect now writes to **daily logs** instead of `.agents.local.md`:

**Before (old):**
```markdown
## Session Observations (auto)
- 2026-03-31T14:32Z | Fixed circular import
```

**After (new):**
```markdown
# Daily Log — 2026-03-31

## Session 14:32 EDT

### Observations (auto)
- Fixed circular import in utils/auth.ts — moved shared types to types/auth.ts
```

**Consolidation reads these observations and merges recurring patterns into topic files.**

#### Comparison: Old vs New

| Feature | Old (auto-reflect) | New (auto-consolidation) |
|---------|-------------------|--------------------------|
| **Trigger** | Session end (manual) | Time (24h) + Sessions (5) |
| **Raw logs** | `.agents.local.md` (monolithic) | `.agents/logs/YYYY-MM-DD.md` (daily) |
| **Curated** | Same file (sections) | `.agents/topics/*.md` (separate files) |
| **Index** | No cap | 200 lines / 25KB cap |
| **Compression** | Manual | Automatic (9:1 ratio) |
| **Lock** | None | Multi-process safety |

#### Benefits

1. **Systematic** — Consolidation triggers automatically (not dependent on agent memory)
2. **Safe** — Daily logs are append-only (no corruption risk)
3. **Compressed** — 9:1 ratio (107 KB → 11.6 KB validated)
3. **Multi-process safe** — Lock prevents concurrent consolidation
4. **Scalable** — Index stays under 200 lines (fast agent reading)
5. **Reviewable** — Daily logs + topic files both in git (if desired)

#### Migration Path

**Step 1: Migrate structure**
```bash
./scripts/migrate-to-daily-logs.sh
```

This creates:
- `.agents/logs/` directory
- `.agents/topics/` directory  
- `.agents/local.md` (new index format)
- Backup of old `.agents.local.md` → `.agents.local.md.backup`

**Step 2: Update AGENTS.md**
Already done (see "Memory System" section).

**Step 3: Start logging to daily logs**
Instead of appending to `.agents.local.md`, append to:
```
.agents/logs/YYYY-MM-DD.md
```

**Step 4: Wait for first consolidation**
After 24h + 5 sessions, consolidation triggers automatically.

**Step 5: Review results**
Check:
- `.agents/topics/*.md` (curated topic files)
- `.agents/local.md` (index updated)
- Compression ratio (target: 5:1 minimum, 9:1 ideal)

#### Success Criteria

- ✅ At least 1 auto-consolidation ran
- ✅ Compression ratio ≥ 5:1 (target: 9:1)
- ✅ Index stays under 200 lines
- ✅ Zero contradictions in topic files
- ✅ Zero secrets stored
- ✅ Zero lock conflicts

#### Attribution

Inspired by [claude-code's auto-dream system](https://github.com/lowcortisolprogrammer/claude-code) (discovered 2026-03-31).

Both systems independently arrived at the same solution:
- MEMORY.md / local.md index (200 lines cap)
- Daily logs (append-only)
- Topic files (curated)
- 4-phase consolidation (orient/gather/consolidate/prune)
- Lock mechanism (multi-process safety)

agent-context-system adds:
- **Agent-agnostic** — Works across Claude Code, Copilot, Cursor, Windsurf
- **File-based** — No background processes, no infrastructure
- **Git-friendly** — All files are reviewable, committable

#### See Also

- [auto-reflect.md](auto-reflect.md) — Session-end reflection (complements auto-consolidation)
- [how-it-works.md](how-it-works.md) — Core knowledge flow
- [AGENT-CONTEXT-LEARNINGS.md](../AGENT-CONTEXT-LEARNINGS.md) — Full analysis (Rusty's workspace)
