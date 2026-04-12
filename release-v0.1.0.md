# agent-context v0.1.0

**First stable release** of the agent-context memory system.

## What It Does

Production-tested memory system for AI agents with:
- **Append-only daily logs** for auditability  
- **Auto-consolidation** for context-window efficiency (9:1 compression)  
- **Zero external dependencies** (plain markdown files)  
- **Context-ready index** (200 lines / 25KB cap)  

## Installation

```bash
pip install git+https://github.com/AndreaGriffiths11/agent-context-system.git@v0.1.0
```

Or clone and install:

```bash
git clone https://github.com/AndreaGriffiths11/agent-context-system.git
cd agent-context-system
pip install -e .
```

## Quick Start

```python
from pathlib import Path
from agent_context import Memory

memory = Memory(agent_id="my-agent", workspace=Path("~/workspace"))
memory.append("Important fact to remember")
results = memory.search("important", limit=5)
index = memory.get_index()  # < 200 lines, < 25KB
```

## Features

✅ **Append-only daily logs** (never lose data)  
✅ **Keyword search** with scoring  
✅ **Auto-consolidation** (9:1 compression ratio)  
✅ **Locking mechanism** (prevents concurrent consolidation)  
✅ **Context-window aware** (200 lines / 25KB index)  
✅ **Zero dependencies** (plain markdown files)  

## API

- `Memory.append()` - Write to daily log  
- `Memory.search()` - Keyword search with scoring  
- `Memory.get_index()` - Get context-ready index  
- `Memory.check_consolidation_needed()` - Check gates  
- `Memory.consolidate()` - Run consolidation  

## Testing

- **19/19 unit tests passing**  
- Windows-compatible  
- Example script working  

## Documentation

See `docs/MEMORY.md` for full documentation.

## Comparison

| Feature | agent-context | mempalace | mem0 | supermemory |
|---------|---------------|-----------|------|-------------|
| Offline | ✅ Yes | ✅ Yes | ⚠️ Optional | ❌ Cloud |
| Zero deps | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| Compression | ✅ 9:1 | ❌ None | ⚠️ Optional | ✅ Yes |
| Size limits | ✅ 200 lines | ❌ Unbounded | ❌ Unbounded | ✅ Cloud |
| License | Apache-2.0 | MIT | Apache-2.0 | Proprietary |

## Production Ready

- Proven in Rusty's memory system  
- Handles real-world workloads  
- Auditability via append-only logs  

## Next: v0.2.0

Phase 2 will add:
- Semantic search (sentence-transformers)  
- SQLite + sqlite-vec backend  
- Hybrid search (keyword + semantic)  
- Backward compatible (file-only mode still works)  

---

**Full Changelog:** https://github.com/AndreaGriffiths11/agent-context-system/commits/v0.1.0
