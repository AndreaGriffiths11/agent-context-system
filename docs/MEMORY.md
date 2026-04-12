# agent-context Memory System

Production-tested memory system for AI agents with:
- **Append-only daily logs** for auditability
- **Auto-consolidation** for context-window efficiency (9:1 compression)
- **Zero external dependencies** (plain markdown files)
- **Optional semantic search** (via sqlite-vec)

## Why This Exists

AI agents need memory that survives session restarts. Most solutions either:
- Require complex vector databases (overkill for small memory stores)
- Grow unbounded (can't fit in context windows)
- Lack auditability (no append-only logs)

**agent-context** solves this with a file-based approach proven in production:
- Daily logs capture everything (append-only, never lost)
- Consolidation compresses to topic files (9:1 ratio)
- MEMORY.md index stays under 200 lines / 25KB (fits in context)

## Installation

```bash
pip install agent-context
```

Or from source:

```bash
git clone https://github.com/AndreaGriffiths11/agent-context-system.git
cd agent-context-system
pip install -e .
```

## Quick Start

```python
from pathlib import Path
from agent_context import Memory

# Create memory instance
memory = Memory(
    agent_id="my-agent",
    workspace=Path("~/my-workspace")
)

# Append memories
memory.append("Deployed v1.0.3 with security fixes")
memory.append("Added 6 new test cases")

# Search memories
results = memory.search("security", limit=5)
for result in results:
    print(f"{result.source_file.name}: {result.content[:100]}...")

# Get index (context-ready)
index = memory.get_index()  # < 200 lines, < 25KB

# Check if consolidation needed
status = memory.check_consolidation_needed(
    min_hours=24,
    min_sessions=5
)
print(f"Consolidation needed: {status['needed']}")
```

## Features

### Append-Only Daily Logs

Every `memory.append()` writes to today's daily log (`memory/YYYY-MM-DD.md`):

```markdown
# Memory Log — 2026-04-12

## 10:30:45 UTC

Deployed proof-agent v1.0.3 with security fixes

---

## 10:35:12 UTC

Added adversarial code review to 6 repositories

---
```

**Benefits:**
- Never lose data (append-only, timestamped)
- Audit trail (who wrote what when)
- Chronological order (easy to follow)

### Auto-Consolidation

Consolidation merges daily logs into topic files (`memory/*.md`):

**Before (107 KB daily logs):**
```
memory/
  2026-04-01.md  (15 KB)
  2026-04-02.md  (18 KB)
  2026-04-03.md  (22 KB)
  ...
  2026-04-07.md  (14 KB)
```

**After (11.6 KB topic files):**
```
memory/
  projects.md     (4.2 KB)
  decisions.md    (3.1 KB)
  tools.md        (2.8 KB)
  facts.md        (1.5 KB)
```

**Compression ratio:** 9:1 (107 KB → 11.6 KB)

### Context-Window Awareness

`MEMORY.md` index is capped at **200 lines / 25KB**:

```markdown
# MEMORY.md — Memory Index

## Decisions
- [Dream Cycle](dream-cycle.md) — Nightly AI research scanner (2026-03-29)
- [Clarification Protocol](clarification-protocol.md) — Uncertainty-aware prompting (2026-03-30)

## Facts
- [GitHub Token](github-token.md) — Current token expires 2026-06-29

## Projects
- [proof-agent](projects.md#proof-agent) — Adversarial code review (v1.0.3 shipped)
```

**Inject into agent context:**

```python
index = memory.get_index()
# < 200 lines, < 25KB, fits in any LLM context window
```

### Keyword Search

Fast, simple keyword search across all memory files:

```python
results = memory.search(
    query="proof-agent security",
    limit=10,
    days=7,  # Optional: last 7 days only
    case_sensitive=False
)

for result in results:
    print(f"Score: {result.score}")
    print(f"File: {result.source_file.name}")
    print(f"Content: {result.content[:200]}...")
```

**Scoring:** Results ranked by keyword match count.

### Consolidation Gates

Consolidation runs when **both gates pass**:

1. **Time gate:** ≥24 hours since last consolidation
2. **Session gate:** ≥5 daily log files accumulated

```python
status = memory.check_consolidation_needed(
    min_hours=24,
    min_sessions=5
)

if status["needed"]:
    print(f"Consolidation needed: {status['reason']}")
    print(f"Sessions: {status['session_count']}")
    print(f"Hours since last: {status['hours_since_last']:.1f}")
```

**Lock mechanism:** Prevents concurrent consolidation runs.

## API Reference

### Memory Class

```python
Memory(
    agent_id: str,
    workspace: Path,
    shared: bool = False,
    max_index_lines: int = 200,
    max_index_bytes: int = 25000
)
```

**Methods:**

- `append(content, timestamp=None, date=None)` → Path
- `search(query, limit=10, days=None, case_sensitive=False)` → List[MemoryEntry]
- `get_index(max_lines=None, max_bytes=None)` → str
- `check_consolidation_needed(min_hours=24, min_sessions=5)` → dict
- `consolidate(days=7, dry_run=False)` → ConsolidationStats

### MemoryEntry

```python
@dataclass
class MemoryEntry:
    content: str
    timestamp: datetime
    source_file: Path
    line_number: Optional[int]
    score: float
```

### ConsolidationStats

```python
@dataclass
class ConsolidationStats:
    daily_logs_processed: int
    total_input_bytes: int
    total_output_bytes: int
    compression_ratio: float
    index_lines: int
    index_bytes: int
    duration_seconds: float
    errors: List[str]
```

## Production Notes

### When to Consolidate

**Manual consolidation:**
```python
stats = memory.consolidate(days=7, dry_run=False)
print(f"Processed {stats.daily_logs_processed} daily logs")
print(f"Compression: {stats.compression_ratio:.1f}:1")
```

**Auto-consolidation (recommended):**

Spawn an isolated sub-agent session to run consolidation in the background:

```python
# Via OpenClaw cron (example)
# Schedule: Every day at 2:00 AM
# Trigger: check_consolidation_needed() gates pass
# Action: Spawn sub-agent with consolidation task
```

### File Structure

```
workspace/
  memory/
    2026-04-01.md          # Daily logs (append-only)
    2026-04-02.md
    ...
    projects.md            # Topic files (consolidated)
    decisions.md
    tools.md
    MEMORY.md              # Index (context-ready)
    .consolidation-lock    # Lock file (JSON)
```

### Lock File Format

```json
{
  "last_consolidated_at": 1712937600000,
  "locked_by": "consolidation-session-abc123",
  "locked_at": 1712941200000
}
```

**Stale lock handling:** Locks older than 30 minutes are ignored.

## Comparison to Alternatives

| Feature | agent-context | mempalace | claude-mem | mem0 | supermemory |
|---------|---------------|-----------|------------|------|-------------|
| **Offline** | ✅ Yes | ✅ Yes | ✅ Yes | ⚠️ Optional | ❌ Cloud only |
| **Zero deps** | ✅ Yes | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Compression** | ✅ 9:1 | ❌ None | ❌ None | ⚠️ Optional | ✅ Yes |
| **Size limits** | ✅ 200 lines | ❌ Unbounded | ❌ Unbounded | ❌ Unbounded | ✅ Cloud |
| **Audit logs** | ✅ Append-only | ✅ Verbatim | ⚠️ Silent | ❌ No | ❌ No |
| **License** | Apache-2.0 | MIT | AGPL | Apache-2.0 | Proprietary |
| **Cost** | $0 | $0 | $0 | $0-$$$ | $$$ |

### When to Use agent-context

✅ **Use when:**
- You need offline-first memory
- Context window size matters
- Auditability is important
- You want zero external dependencies
- <10K memories (fits in SQLite/files)

❌ **Don't use when:**
- You need semantic search NOW (wait for Phase 2)
- You have >100K memories (use vector DB)
- You want a managed service (use supermemory)
- You're locked into Claude Code (use claude-mem)

## Roadmap

### Phase 1: File-Based Core ✅
- [x] Append-only daily logs
- [x] Keyword search
- [x] Consolidation gates
- [x] Lock mechanism
- [x] Context-ready index
- [x] Unit tests (19/19 passing)

### Phase 2: Semantic Search (Next)
- [ ] Optional vector embeddings (sentence-transformers)
- [ ] SQLite + sqlite-vec backend
- [ ] Hybrid search (keyword + semantic)
- [ ] Backward compatible (file-only mode still works)

### Phase 3: Multi-Agent (Future)
- [ ] Per-agent memory isolation
- [ ] Shared knowledge base
- [ ] Session-scoped memory
- [ ] Cross-agent search

### Phase 4: Scale (Future)
- [ ] Pluggable backends (file, SQLite, Qdrant, Pinecone)
- [ ] Async consolidation
- [ ] Distributed locking
- [ ] Metrics & monitoring

## Contributing

Issues and PRs welcome! See [GitHub](https://github.com/AndreaGriffiths11/agent-context-system).

## License

Apache-2.0 — see LICENSE file.

## Credits

Built by Andrea Griffiths ([@acolombiadev](https://github.com/AndreaGriffiths11))

Inspired by:
- mempalace (verbatim storage)
- mem0 (pluggable architecture)
- OpenClaw's proven memory consolidation (9:1 compression)
