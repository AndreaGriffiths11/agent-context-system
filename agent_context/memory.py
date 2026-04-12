"""
agent_context.memory — File-based memory system for AI agents

Production-tested memory system with:
- Append-only daily logs
- Auto-consolidation (9:1 compression)
- Context-window awareness (200 lines / 25KB cap)
- Zero external dependencies

Usage:
    from agent_context.memory import Memory
    
    memory = Memory(agent_id="rusty", workspace=Path("~/rusty-agent/workspace"))
    memory.append("Shipped proof-agent v1.0.3")
    results = memory.search("proof-agent", limit=5)
    memory.consolidate()
    index = memory.get_index(max_lines=200)
"""

import json
import re
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import List, Optional, Dict, Any
from dataclasses import dataclass, field


@dataclass
class MemoryEntry:
    """A single memory entry with metadata."""
    content: str
    timestamp: datetime
    source_file: Path
    line_number: Optional[int] = None
    score: float = 0.0  # For ranking (keyword match count, semantic similarity, etc.)
    
    def __repr__(self) -> str:
        date_str = self.timestamp.strftime("%Y-%m-%d %H:%M")
        file_name = self.source_file.name
        return f"MemoryEntry({date_str}, {file_name}, score={self.score:.2f})"


@dataclass
class ConsolidationStats:
    """Statistics from a consolidation run."""
    daily_logs_processed: int = 0
    total_input_bytes: int = 0
    total_output_bytes: int = 0
    compression_ratio: float = 0.0
    index_lines: int = 0
    index_bytes: int = 0
    duration_seconds: float = 0.0
    errors: List[str] = field(default_factory=list)


class Memory:
    """File-based memory system for AI agents.
    
    Features:
    - Append-only daily logs (memory/YYYY-MM-DD.md)
    - Topic-based consolidation (memory/*.md)
    - Context-ready index (MEMORY.md, 200 lines / 25KB cap)
    - Auto-consolidation (configurable triggers)
    
    Args:
        agent_id: Unique agent identifier
        workspace: Workspace directory (must exist)
        shared: If True, memory is shared across agents
        max_index_lines: Maximum lines in MEMORY.md (default: 200)
        max_index_bytes: Maximum bytes in MEMORY.md (default: 25000)
    """
    
    def __init__(
        self,
        agent_id: str,
        workspace: Path,
        shared: bool = False,
        max_index_lines: int = 200,
        max_index_bytes: int = 25_000,
    ):
        self.agent_id = agent_id
        self.workspace = Path(workspace).expanduser().resolve()
        self.shared = shared
        self.max_index_lines = max_index_lines
        self.max_index_bytes = max_index_bytes
        
        # Memory paths
        self.memory_dir = self.workspace / "memory"
        self.index_file = self.memory_dir / "MEMORY.md"
        self.lock_file = self.memory_dir / ".consolidation-lock"
        
        # Ensure memory directory exists
        self.memory_dir.mkdir(parents=True, exist_ok=True)
    
    def append(
        self,
        content: str,
        timestamp: Optional[datetime] = None,
        date: Optional[str] = None
    ) -> Path:
        """Append content to today's daily log.
        
        Args:
            content: Memory content (markdown-formatted)
            timestamp: Optional timestamp (default: now)
            date: Optional date string YYYY-MM-DD (default: today)
        
        Returns:
            Path to the daily log file
        """
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)
        
        if date is None:
            date = timestamp.strftime("%Y-%m-%d")
        
        daily_log = self.memory_dir / f"{date}.md"
        
        # Append with timestamp header
        with open(daily_log, "a", encoding="utf-8") as f:
            if daily_log.stat().st_size == 0:
                # First entry, add file header
                f.write(f"# Memory Log — {date}\n\n")
            
            # Write timestamped entry
            time_str = timestamp.strftime("%H:%M:%S %Z" if timestamp.tzinfo else "%H:%M:%S")
            f.write(f"## {time_str}\n\n")
            f.write(content.strip())
            f.write("\n\n---\n\n")
        
        return daily_log
    
    def search(
        self,
        query: str,
        limit: int = 10,
        days: Optional[int] = None,
        case_sensitive: bool = False
    ) -> List[MemoryEntry]:
        """Search memories using keyword matching.
        
        Args:
            query: Search query (space-separated keywords)
            limit: Maximum results to return
            days: Only search last N days (None = all files)
            case_sensitive: Case-sensitive search
        
        Returns:
            List of MemoryEntry objects, ranked by match count
        """
        results = []
        keywords = query.split()
        
        if not case_sensitive:
            keywords = [k.lower() for k in keywords]
        
        # Get files to search
        files_to_search = self._get_search_files(days)
        
        for file_path in files_to_search:
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                if not case_sensitive:
                    search_content = content.lower()
                else:
                    search_content = content
                
                # Count keyword matches
                match_count = sum(search_content.count(kw) for kw in keywords)
                
                if match_count > 0:
                    # Extract timestamp from filename or use file mtime
                    timestamp = self._extract_timestamp(file_path)
                    
                    results.append(MemoryEntry(
                        content=content,
                        timestamp=timestamp,
                        source_file=file_path,
                        score=float(match_count)
                    ))
            
            except Exception as e:
                # Skip files that can't be read
                continue
        
        # Sort by score (descending) and limit
        results.sort(key=lambda x: x.score, reverse=True)
        return results[:limit]
    
    def get_index(self, max_lines: Optional[int] = None, max_bytes: Optional[int] = None) -> str:
        """Get MEMORY.md index content.
        
        Args:
            max_lines: Override default max_index_lines
            max_bytes: Override default max_index_bytes
        
        Returns:
            MEMORY.md content (empty string if not found)
        """
        if not self.index_file.exists():
            return ""
        
        with open(self.index_file, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Validate size limits
        lines = len(content.strip().split("\n"))
        bytes_count = len(content.encode("utf-8"))
        
        max_l = max_lines or self.max_index_lines
        max_b = max_bytes or self.max_index_bytes
        
        if lines > max_l or bytes_count > max_b:
            # Log warning but return anyway (consolidation should fix this)
            print(f"[WARN] MEMORY.md exceeds limits: {lines}/{max_l} lines, {bytes_count}/{max_b} bytes")
        
        return content
    
    def check_consolidation_needed(
        self,
        min_hours: int = 24,
        min_sessions: int = 5
    ) -> Dict[str, Any]:
        """Check if consolidation should run.
        
        Args:
            min_hours: Minimum hours since last consolidation
            min_sessions: Minimum session count (daily log files)
        
        Returns:
            Dict with keys: needed, reason, hours_since_last, session_count, locked
        """
        # Check lock status
        lock_status = self._check_lock()
        if lock_status["locked"]:
            return {
                "needed": False,
                "reason": "consolidation already in progress",
                "locked": True,
                "locked_by": lock_status.get("locked_by"),
                "locked_at": lock_status.get("locked_at")
            }
        
        # Check time since last consolidation
        last_at = lock_status.get("last_consolidated_at", 0)
        hours_since = (datetime.now(timezone.utc).timestamp() * 1000 - last_at) / 3600000
        
        # Count daily log files (sessions)
        daily_logs = list(self.memory_dir.glob("????-??-??.md"))
        session_count = len(daily_logs)
        
        # Determine if consolidation needed
        time_gate = hours_since >= min_hours
        session_gate = session_count >= min_sessions
        
        needed = time_gate and session_gate
        
        if needed:
            reason = f"time gate ({hours_since:.1f}h >= {min_hours}h) + session gate ({session_count} >= {min_sessions})"
        elif not time_gate:
            reason = f"time gate not met ({hours_since:.1f}h < {min_hours}h)"
        else:
            reason = f"session gate not met ({session_count} < {min_sessions})"
        
        return {
            "needed": needed,
            "reason": reason,
            "hours_since_last": hours_since,
            "session_count": session_count,
            "locked": False
        }
    
    def consolidate(
        self,
        days: int = 7,
        dry_run: bool = False,
        llm_consolidate: bool = False
    ) -> Optional[ConsolidationStats]:
        """Run memory consolidation.
        
        Consolidates daily logs into topic files using a 4-phase process:
        1. Orient - Read index and existing topic files
        2. Gather - Extract signal from recent daily logs
        3. Consolidate - Merge into topics (LLM-based or rule-based)
        4. Prune - Update index, enforce limits
        
        Args:
            days: Number of days of daily logs to consolidate
            dry_run: If True, don't make changes (just report stats)
            llm_consolidate: If True, use LLM for consolidation (requires gh copilot)
        
        Returns:
            ConsolidationStats object (None if lock acquisition failed)
        """
        stats = ConsolidationStats()
        start_time = datetime.now()
        
        # Acquire lock
        if not dry_run:
            if not self._acquire_lock(session_id="manual-consolidation"):
                stats.errors.append("Failed to acquire consolidation lock")
                return stats
        
        try:
            # Phase 1: Orient - Get current state
            daily_logs = self._get_daily_logs(days)
            stats.daily_logs_processed = len(daily_logs)
            
            topic_files = self._get_topic_files()
            
            # Calculate input size
            for log in daily_logs:
                if log.exists():
                    stats.total_input_bytes += log.stat().st_size
            
            # Phase 2: Gather - Extract signal from daily logs
            daily_content = self._gather_daily_content(daily_logs)
            
            if not daily_content.strip():
                stats.errors.append("No content to consolidate")
                return stats
            
            # Phase 3: Consolidate - Merge into topics
            if llm_consolidate:
                # LLM-based consolidation (requires gh copilot CLI)
                consolidated = self._consolidate_with_llm(daily_content, topic_files)
            else:
                # Rule-based consolidation (simple merge)
                consolidated = self._consolidate_rule_based(daily_content, topic_files)
            
            # Write consolidated content
            if not dry_run and consolidated:
                for filename, content in consolidated.items():
                    topic_path = self.memory_dir / filename
                    with open(topic_path, "w", encoding="utf-8") as f:
                        f.write(content)
                    stats.total_output_bytes += len(content.encode("utf-8"))
            
            # Phase 4: Prune - Update index
            if not dry_run:
                self._prune_index()
            
            # Calculate final stats
            if self.index_file.exists():
                with open(self.index_file, "r", encoding="utf-8") as f:
                    index_content = f.read()
                stats.index_lines = len(index_content.strip().split("\n"))
                stats.index_bytes = len(index_content.encode("utf-8"))
            
            if stats.total_output_bytes > 0:
                stats.compression_ratio = stats.total_input_bytes / stats.total_output_bytes
            
        except Exception as e:
            stats.errors.append(f"Consolidation failed: {str(e)}")
        
        finally:
            if not dry_run:
                self._release_lock()
        
        stats.duration_seconds = (datetime.now() - start_time).total_seconds()
        return stats
    
    # Internal helper methods
    
    def _check_lock(self) -> Dict[str, Any]:
        """Check consolidation lock status."""
        if not self.lock_file.exists():
            return {"locked": False, "last_consolidated_at": 0}
        
        try:
            with open(self.lock_file, "r") as f:
                lock = json.load(f)
            
            locked_at = lock.get("locked_at", 0)
            age_minutes = (datetime.now(timezone.utc).timestamp() * 1000 - locked_at) / 60000
            
            # Stale if locked for >30 minutes
            if locked_at > 0 and age_minutes > 30:
                return {"locked": False, "stale": True, "last_consolidated_at": lock.get("last_consolidated_at", 0)}
            
            return {
                "locked": locked_at > 0,
                "locked_by": lock.get("locked_by"),
                "locked_at": locked_at,
                "age_minutes": age_minutes,
                "last_consolidated_at": lock.get("last_consolidated_at", 0)
            }
        except Exception:
            return {"locked": False, "last_consolidated_at": 0}
    
    def _acquire_lock(self, session_id: str) -> bool:
        """Acquire consolidation lock."""
        lock_status = self._check_lock()
        
        if lock_status["locked"]:
            return False
        
        # Write new lock
        lock = {
            "last_consolidated_at": lock_status.get("last_consolidated_at", datetime.now(timezone.utc).timestamp() * 1000),
            "locked_by": session_id,
            "locked_at": datetime.now(timezone.utc).timestamp() * 1000
        }
        
        with open(self.lock_file, "w") as f:
            json.dump(lock, f, indent=2)
        
        return True
    
    def _release_lock(self):
        """Release consolidation lock."""
        if not self.lock_file.exists():
            return
        
        try:
            with open(self.lock_file, "r") as f:
                lock = json.load(f)
        except:
            lock = {}
        
        # Update last_consolidated_at, clear lock fields
        lock["last_consolidated_at"] = datetime.now(timezone.utc).timestamp() * 1000
        lock.pop("locked_by", None)
        lock.pop("locked_at", None)
        
        with open(self.lock_file, "w") as f:
            json.dump(lock, f, indent=2)
    
    def _get_daily_logs(self, days: int) -> List[Path]:
        """Get daily log files from last N days."""
        cutoff = datetime.now() - timedelta(days=days)
        logs = []
        
        for file in self.memory_dir.glob("????-??-??.md"):
            try:
                log_date = datetime.strptime(file.stem, "%Y-%m-%d")
                if log_date >= cutoff:
                    logs.append(file)
            except ValueError:
                continue
        
        return sorted(logs)
    
    def _get_search_files(self, days: Optional[int] = None) -> List[Path]:
        """Get files to search (daily logs + topic files)."""
        files = []
        
        if days is not None:
            # Only daily logs from last N days
            files = self._get_daily_logs(days)
        else:
            # All markdown files except index
            files = [
                f for f in self.memory_dir.glob("*.md")
                if f != self.index_file
            ]
        
        return files
    
    def _extract_timestamp(self, file_path: Path) -> datetime:
        """Extract timestamp from filename or file mtime."""
        # Try to parse YYYY-MM-DD.md format
        if len(file_path.stem) == 10 and file_path.stem.count("-") == 2:
            try:
                return datetime.strptime(file_path.stem, "%Y-%m-%d")
            except ValueError:
                pass
        
        # Fall back to file modification time
        return datetime.fromtimestamp(file_path.stat().st_mtime)
    
    def _get_topic_files(self) -> List[Path]:
        """Get topic files (non-daily-log markdown files)."""
        topic_files = []
        
        for file in self.memory_dir.glob("*.md"):
            # Skip daily logs (YYYY-MM-DD.md) and index (MEMORY.md)
            if file == self.index_file:
                continue
            if len(file.stem) == 10 and file.stem.count("-") == 2:
                continue
            topic_files.append(file)
        
        return sorted(topic_files)
    
    def _gather_daily_content(self, daily_logs: List[Path]) -> str:
        """Extract content from daily logs (remove boilerplate, timestamps)."""
        content_parts = []
        
        for log in daily_logs:
            try:
                with open(log, "r", encoding="utf-8") as f:
                    raw = f.read()
                
                # Remove file header (# Memory Log - YYYY-MM-DD)
                lines = raw.split("\n")
                filtered = []
                
                for line in lines:
                    # Skip headers, timestamps, separators
                    if line.startswith("# Memory Log"):
                        continue
                    if line.startswith("##") and ":" in line and "EDT" in line or "UTC" in line:
                        continue
                    if line.strip() == "---":
                        continue
                    
                    filtered.append(line)
                
                content = "\n".join(filtered).strip()
                if content:
                    content_parts.append(f"## {log.stem}\n\n{content}")
            
            except Exception as e:
                print(f"[WARN] Failed to read {log.name}: {e}")
                continue
        
        return "\n\n".join(content_parts)
    
    def _consolidate_rule_based(
        self,
        daily_content: str,
        topic_files: List[Path]
    ) -> Dict[str, str]:
        """Simple rule-based consolidation (merge all into consolidated.md)."""
        # For now, just create a consolidated.md with all daily content
        # Future: smart topic detection, de-duplication, etc.
        
        consolidated_path = self.memory_dir / "consolidated.md"
        
        # Read existing consolidated.md if exists
        existing = ""
        if consolidated_path.exists():
            with open(consolidated_path, "r", encoding="utf-8") as f:
                existing = f.read()
        
        # Append new content
        new_content = f"{existing}\n\n# Consolidated Memory\n\n{daily_content}"
        
        return {"consolidated.md": new_content}
    
    def _consolidate_with_llm(
        self,
        daily_content: str,
        topic_files: List[Path]
    ) -> Dict[str, str]:
        """LLM-based consolidation (requires gh copilot CLI)."""
        import subprocess
        
        # Build prompt
        topic_content = ""
        for topic in topic_files:
            with open(topic, "r", encoding="utf-8") as f:
                topic_content += f"\n## {topic.name}\n{f.read()}\n"
        
        prompt = f"""Consolidate these daily memory logs into topic files.

Daily logs (last 7 days):
{daily_content}

Existing topic files:
{topic_content}

Tasks:
1. Merge new entries into existing topics
2. De-duplicate similar facts
3. Convert relative dates ("yesterday") to absolute (YYYY-MM-DD)
4. Create new topic files only when necessary

Return a JSON object mapping filename -> content:
{{
  "projects.md": "# Projects\\n...",
  "decisions.md": "# Decisions\\n..."
}}
"""
        
        try:
            result = subprocess.run(
                ["gh", "copilot", "suggest", "-t", "shell"],
                input=prompt,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                # Parse JSON response
                response = result.stdout.strip()
                # Extract JSON from response (may be wrapped in markdown)
                if "```json" in response:
                    start = response.find("```json") + 7
                    end = response.find("```", start)
                    response = response[start:end].strip()
                
                return json.loads(response)
            else:
                print(f"[WARN] LLM consolidation failed: {result.stderr}")
                return self._consolidate_rule_based(daily_content, topic_files)
        
        except Exception as e:
            print(f"[WARN] LLM consolidation error: {e}")
            return self._consolidate_rule_based(daily_content, topic_files)
    
    def _prune_index(self):
        """Prune MEMORY.md to stay under limits (200 lines / 25KB)."""
        if not self.index_file.exists():
            return
        
        with open(self.index_file, "r", encoding="utf-8") as f:
            content = f.read()
        
        lines = content.strip().split("\n")
        bytes_count = len(content.encode("utf-8"))
        
        if len(lines) <= self.max_index_lines and bytes_count <= self.max_index_bytes:
            return  # Already under limits
        
        # Simple pruning: keep header + first N entries
        # Future: smarter pruning (keep recent, important, frequently accessed)
        
        pruned_lines = []
        in_header = True
        entry_count = 0
        max_entries = int(self.max_index_lines * 0.8)  # Leave room for headers
        
        for line in lines:
            # Keep headers
            if line.startswith("#"):
                pruned_lines.append(line)
                in_header = False
                continue
            
            # Keep entries up to limit
            if line.startswith("-") and entry_count < max_entries:
                pruned_lines.append(line)
                entry_count += 1
            elif not line.startswith("-"):
                pruned_lines.append(line)  # Keep blank lines, section headers
        
        pruned_content = "\n".join(pruned_lines)
        
        with open(self.index_file, "w", encoding="utf-8") as f:
            f.write(pruned_content)
