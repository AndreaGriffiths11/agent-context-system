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
pip install git+https://github.com/AndreaGriffiths11/agent-context-system.git@v0.2.0
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

# Run consolidation
if status['needed']:
    stats = memory.consolidate(days=7)
    print(f"Processed {stats.daily_logs_processed} logs")
    print(f"Compression: {stats.compression_ratio:.1f}:1")
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

### Running Consolidation (v0.2.0+)

**Rule-based consolidation (default):**
```python
stats = memory.consolidate(days=7, llm_consolidate=False)
# Simple merge into consolidated.md
# Fast, reliable, 1:1 compression
```

**LLM-based consolidation (advanced):**
```python
# Requires: gh copilot CLI installed
stats = memory.consolidate(days=7, llm_consolidate=True)
# Smart de-duplication
# Relative → absolute dates ("yesterday" → "2026-04-11")
# Topic detection
# Expected: 5-9:1 compression
```

**Consolidation stats:**
```python
print(f"Processed: {stats.daily_logs_processed} logs")
print(f"Input: {stats.total_input_bytes / 1024:.1f} KB")
print(f"Output: {stats.total_output_bytes / 1024:.1f} KB")
print(f"Compression: {stats.compression_ratio:.1f}:1")
print(f"Duration: {stats.duration_seconds:.2f}s")
```

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

### Sliding Window with Per-Message Decay

For long-running sessions, `SlidingWindow` keeps recent messages at full fidelity and progressively compresses older ones. Messages are stored in full; compression happens at render time, so no source data is lost.

```python
from agent_context import SlidingWindow

window = SlidingWindow(max_messages=50, full_fidelity=5)
evicted = window.add("user", "Deploy proof-agent v1.0.3 to staging")
window.add("assistant", "Deployed. All checks passed.")

for msg in window.render():  # oldest first
    print(msg.age, f"{msg.fidelity:.2f}", msg.content)

prompt = window.to_text()
```

- `full_fidelity`: newest N messages are never compressed.
- `decay(age, full_fidelity) -> float`: fidelity in `[0, 1]` (age 0 = newest). Default `harmonic_decay` returns `1.0` inside the full-fidelity window, then `full_fidelity / (age + 1)`.
- `compressor(content, fidelity) -> str`: default `truncate_compressor` keeps the first `fidelity` share of the text, cut on a word boundary.
- `min_fidelity`: messages below this fidelity are dropped from `render()`.
- `max_messages`: oldest messages are evicted once exceeded; `add()` returns them.

Pass your own `decay` or `compressor` callable to change the behavior.

#### Decay Curves

Built-in curves plug into `decay` (pass a callable or a name). All keep `1.0` inside the `full_fidelity` window.

| Curve | Factory | Name for `get_decay` / `decay=` | Shape past the window |
|-------|---------|---------------------------------|-----------------------|
| Harmonic (default) | `harmonic_decay` | `"harmonic"` | `full_fidelity / (age + 1)` |
| Linear | `linear_decay(span=10)` | `"linear"` | Equal steps, `0` after `span` messages |
| Exponential | `exponential_decay(half_life=5)` | `"exponential"` | Halves every `half_life` messages |
| Importance-weighted | `importance_weighted(base=None, key="importance", default=0.0)` | `"importance"` | `base + (1 - base) * importance` |

```python
from agent_context import SlidingWindow, exponential_decay, importance_weighted, get_decay

SlidingWindow(decay=exponential_decay(half_life=3))
SlidingWindow(decay="linear")                                  # default span
SlidingWindow(decay=get_decay("importance", base="exponential"))

window = SlidingWindow(full_fidelity=2, decay=importance_weighted())
window.add("user", "Prod DB is read-only on Fridays", metadata={"importance": 1.0})  # never decays
```

Importance-weighted decay reads `metadata["importance"]` (clamped to `[0, 1]`). Messages without it follow `base` unchanged. Custom callables can set `fn.uses_metadata = True` to receive `(age, full_fidelity, metadata)`.

#### Summary Checkpointing (opt-in)

When `max_messages` evicts messages, the window can summarize them into `Checkpoint`s instead of dropping them silently. It is off by default; existing behavior is unchanged unless you enable it.

```python
from agent_context import SlidingWindow

window = SlidingWindow(max_messages=20, checkpoint=True)          # default summarizer
window = SlidingWindow(max_messages=20, summarizer=my_llm_summary) # custom (also enables it)

window.checkpoints        # List[Checkpoint(summary, message_count, start, end, created_at)]
window.pending            # evicted messages not yet summarized
window.flush_checkpoint() # summarize pending now, e.g. at session end
window.to_text()          # "summary: ..." lines first, then the window
```

- `summarizer(messages) -> str`: receives the evicted `Message`s oldest-first. Default `default_summarizer` emits one `role: snippet` line per message (~80 chars each).
- `checkpoint_every`: evicted messages per checkpoint. Defaults to `max_messages`, so one checkpoint is written each time a full window has rolled out.
- `render()` is unaffected; only `to_text()` prepends checkpoint summaries.
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
- `consolidate(days=7, dry_run=False, llm_consolidate=False)` → ConsolidationStats

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

### Phase 1: File-Based Core ✅ (v0.1.0)
- [x] Append-only daily logs
- [x] Keyword search
- [x] Consolidation gates
- [x] Lock mechanism
- [x] Context-ready index
- [x] Unit tests (19/19 passing)

### Phase 1.5: Full Consolidation ✅ (v0.2.0)
- [x] Rule-based consolidation (simple merge)
- [x] Optional LLM consolidation (GitHub Copilot CLI)
- [x] 4-phase consolidation process
- [x] Index pruning (enforce 200 lines / 25KB)
- [x] Topic file management

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
