# agent-context

**Production-tested memory system for AI agents**

[![Version](https://img.shields.io/badge/version-0.2.0-blue)](https://github.com/AndreaGriffiths11/agent-context-system/releases/tag/v0.2.0)
[![Tests](https://img.shields.io/badge/tests-19%2F19%20passing-green)](https://github.com/AndreaGriffiths11/agent-context-system/tree/main/tests)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

---

## Features

- ✅ **Append-only daily logs** — Never lose data, full audit trail
- ✅ **Auto-consolidation** — 9:1 compression ratio (107 KB → 11.6 KB)
- ✅ **Context-window aware** — MEMORY.md capped at 200 lines / 25KB
- ✅ **Zero dependencies** — Plain markdown files, fully offline
- ✅ **Keyword search** — Fast, score-ranked results
- ✅ **Lock mechanism** — Prevents concurrent consolidation

---

## Quick Start

```bash
pip install git+https://github.com/AndreaGriffiths11/agent-context-system.git@v0.2.0
```

```python
from pathlib import Path
from agent_context import Memory

# Create memory
memory = Memory(agent_id="my-agent", workspace=Path("~/workspace"))

# Append
memory.append("Shipped v1.0.3 with security fixes")

# Search
results = memory.search("security", limit=5)

# Consolidate
status = memory.check_consolidation_needed()
if status["needed"]:
    stats = memory.consolidate(days=7)
    print(f"Compression: {stats.compression_ratio:.1f}:1")
```

---

## Documentation

- **[MEMORY.md](docs/MEMORY.md)** — Full documentation
- **[Examples](examples/)** — Working code samples
- **[Tests](tests/)** — Unit tests (19/19 passing)

---

## API

| Method | Description |
|--------|-------------|
| `memory.append()` | Write to daily log (auto-timestamped) |
| `memory.search()` | Keyword search with scoring |
| `memory.get_index()` | Get context-ready index (<200 lines) |
| `memory.check_consolidation_needed()` | Check time + session gates |
| `memory.consolidate()` | 4-phase consolidation (Orient → Gather → Consolidate → Prune) |

---

## Why agent-context?

**Compared to alternatives:**

| Feature | agent-context | mempalace | mem0 | supermemory |
|---------|---------------|-----------|------|-------------|
| Offline | ✅ Yes | ✅ Yes | ⚠️ Optional | ❌ Cloud only |
| Zero deps | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| Compression | ✅ 9:1 | ❌ None | ⚠️ Optional | ✅ Yes |
| Size limits | ✅ 200 lines | ❌ Unbounded | ❌ Unbounded | ✅ Cloud |
| Audit logs | ✅ Append-only | ✅ Verbatim | ⚠️ Silent | ❌ No |
| Cost | $0 | $0 | $0-$$$ | $$$ |

**Best for:** Offline-first agents with context-window constraints and auditability requirements.

---

## Releases

- **[v0.2.0](https://github.com/AndreaGriffiths11/agent-context-system/releases/tag/v0.2.0)** — Full consolidation implementation (current)
- **[v0.1.0](https://github.com/AndreaGriffiths11/agent-context-system/releases/tag/v0.1.0)** — File-based core

---

## Roadmap

- ✅ **Phase 1** (v0.1.0) — File-based core
- ✅ **Phase 1.5** (v0.2.0) — Full consolidation
- 🚧 **Phase 2** (v0.3.0) — Semantic search (sqlite-vec)
- 📅 **Phase 3** — Multi-agent isolation
- 📅 **Phase 4** — Pluggable backends

---

## Contributing

Issues and PRs welcome! See [GitHub](https://github.com/AndreaGriffiths11/agent-context-system).

## License

Apache-2.0 — see [LICENSE](LICENSE) file.

## Credits

Built by Andrea Griffiths ([@acolombiadev](https://github.com/AndreaGriffiths11))

Inspired by:
- mempalace (verbatim storage)
- mem0 (pluggable architecture)
- OpenClaw's proven memory consolidation (9:1 compression)

---

**Project:** https://github.com/AndreaGriffiths11/agent-context-system  
**Docs:** [docs/MEMORY.md](docs/MEMORY.md)  
**Latest:** [v0.2.0](https://github.com/AndreaGriffiths11/agent-context-system/releases/tag/v0.2.0)
