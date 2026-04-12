"""
Basic usage example for agent-context memory system.

Demonstrates:
- Creating a memory instance
- Appending memories
- Searching memories
- Getting the index
- Checking consolidation status
"""

from pathlib import Path
from agent_context import Memory

# Create memory instance
memory = Memory(
    agent_id="example-agent",
    workspace=Path("./example-workspace")
)

print("=" * 80)
print("agent-context Memory System — Basic Example")
print("=" * 80)
print()

# Append some memories
print("[APPEND] Adding memories...")
memory.append("Shipped proof-agent v1.0.3 with security fixes")
memory.append("Added adversarial code review to 6 repositories")
memory.append("TeamXray extension launched in VS Code marketplace")
print("[OK] Added 3 memories to today's daily log")
print()

# Search for memories
print("[SEARCH] Searching for 'proof-agent'...")
results = memory.search("proof-agent", limit=5)
print(f"Found {len(results)} result(s):")
for i, result in enumerate(results, 1):
    print(f"  {i}. {result.source_file.name} (score: {result.score})")
    preview = result.content[:100].replace("\n", " ")
    print(f"     Preview: {preview}...")
print()

# Get index (if exists)
print("[INDEX] Checking MEMORY.md index...")
index = memory.get_index()
if index:
    lines = len(index.strip().split("\n"))
    bytes_count = len(index.encode("utf-8"))
    print(f"[OK] Index exists: {lines} lines, {bytes_count} bytes")
else:
    print("[WARN] Index not found (run consolidation to create)")
print()

# Check consolidation status
print("[CONSOLIDATE] Checking consolidation status...")
status = memory.check_consolidation_needed(min_hours=24, min_sessions=5)
print(f"Consolidation needed: {status['needed']}")
print(f"Reason: {status['reason']}")
print(f"Sessions (daily logs): {status['session_count']}")
print(f"Hours since last: {status['hours_since_last']:.1f}h")
print()

# Show memory directory structure
print("[FILES] Memory directory structure:")
for file in sorted(memory.memory_dir.glob("*")):
    size = file.stat().st_size if file.is_file() else "-"
    print(f"  {file.name} ({size} bytes)" if size != "-" else f"  {file.name}/")
print()

print("=" * 80)
print("[COMPLETE] Example finished!")
print()
print("Memory location:", memory.memory_dir)
print("To clean up: rm -rf example-workspace/")
print("=" * 80)
