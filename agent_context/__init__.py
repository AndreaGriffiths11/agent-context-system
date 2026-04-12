"""
agent_context — Production-tested agent memory and context management

A lightweight, file-based memory system for AI agents with:
- Append-only daily logs for auditability
- Auto-consolidation for context-window efficiency (9:1 compression)
- Zero external dependencies (plain markdown files)
- Optional semantic search (via sqlite-vec)

Usage:
    from agent_context import Memory
    
    memory = Memory(agent_id="rusty", workspace=Path("~/workspace"))
    memory.append("Important fact to remember")
    results = memory.search("important", limit=5)
    memory.consolidate()

Project: https://github.com/AndreaGriffiths11/agent-context-system
License: Apache-2.0
"""

__version__ = "0.2.0"

from .memory import Memory, MemoryEntry, ConsolidationStats

__all__ = [
    "Memory",
    "MemoryEntry",
    "ConsolidationStats",
]
