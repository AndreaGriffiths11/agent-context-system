"""Tests for agent_context.memory module."""

import pytest
import tempfile
import shutil
from pathlib import Path
from datetime import datetime, timedelta
from agent_context import Memory, MemoryEntry


class TestMemory:
    """Test Memory class."""
    
    @pytest.fixture
    def temp_workspace(self):
        """Create temporary workspace."""
        temp_dir = Path(tempfile.mkdtemp())
        yield temp_dir
        shutil.rmtree(temp_dir)
    
    @pytest.fixture
    def memory(self, temp_workspace):
        """Create Memory instance."""
        return Memory(agent_id="test-agent", workspace=temp_workspace)
    
    def test_init_creates_memory_dir(self, temp_workspace):
        """Memory initialization creates memory/ directory."""
        memory = Memory(agent_id="test", workspace=temp_workspace)
        assert memory.memory_dir.exists()
        assert memory.memory_dir.is_dir()
    
    def test_append_creates_daily_log(self, memory):
        """append() creates daily log file."""
        date = "2026-04-12"
        memory.append("Test memory entry", date=date)
        
        daily_log = memory.memory_dir / f"{date}.md"
        assert daily_log.exists()
        
        content = daily_log.read_text()
        assert "Memory Log" in content
        assert "2026-04-12" in content
        assert "Test memory entry" in content
    
    def test_append_multiple_entries(self, memory):
        """Multiple append() calls add to same daily log."""
        date = "2026-04-12"
        memory.append("Entry 1", date=date)
        memory.append("Entry 2", date=date)
        memory.append("Entry 3", date=date)
        
        daily_log = memory.memory_dir / f"{date}.md"
        content = daily_log.read_text()
        
        assert "Entry 1" in content
        assert "Entry 2" in content
        assert "Entry 3" in content
        assert content.count("---") == 3  # 3 separators
    
    def test_search_finds_entries(self, memory):
        """search() finds matching entries."""
        memory.append("proof-agent v1.0.3 released", date="2026-04-11")
        memory.append("Fixed security issues", date="2026-04-11")
        memory.append("TeamXray extension launched", date="2026-04-11")
        
        results = memory.search("proof-agent")
        assert len(results) == 1
        assert "proof-agent" in results[0].content
    
    def test_search_keyword_scoring(self, memory):
        """search() scores results by keyword match count."""
        memory.append("proof-agent security fix", date="2026-04-11")
        memory.append("proof-agent proof-agent proof-agent", date="2026-04-12")
        
        results = memory.search("proof-agent")
        assert len(results) == 2
        # Entry with 3 matches should rank higher
        assert results[0].score > results[1].score
    
    def test_search_limit(self, memory):
        """search() respects limit parameter."""
        # Create entries on different days
        for i in range(10):
            date = f"2026-04-{11+i:02d}"
            memory.append(f"proof-agent entry {i}", date=date)
        
        results = memory.search("proof-agent", limit=5)
        assert len(results) == 5
    
    def test_search_days_filter(self, memory):
        """search() can filter by days."""
        old_date = (datetime.now() - timedelta(days=10)).strftime("%Y-%m-%d")
        recent_date = datetime.now().strftime("%Y-%m-%d")
        
        memory.append("old entry with keyword", date=old_date)
        memory.append("recent entry with keyword", date=recent_date)
        
        # Search last 7 days only
        results = memory.search("keyword", days=7)
        assert len(results) == 1
        assert "recent" in results[0].content
    
    def test_get_index_empty(self, memory):
        """get_index() returns empty string when MEMORY.md doesn't exist."""
        index = memory.get_index()
        assert index == ""
    
    def test_get_index_content(self, memory):
        """get_index() returns MEMORY.md content."""
        index_content = "# MEMORY.md\n\n## Test Section\n- Item 1\n- Item 2\n"
        memory.index_file.write_text(index_content)
        
        index = memory.get_index()
        assert index == index_content
    
    def test_get_index_warns_on_overflow(self, memory, capfd):
        """get_index() warns when index exceeds size limits."""
        # Create index that exceeds line limit
        lines = ["Line " + str(i) for i in range(250)]
        memory.index_file.write_text("\n".join(lines))
        
        index = memory.get_index()
        captured = capfd.readouterr()
        
        assert "[WARN]" in captured.out
        assert "exceeds limits" in captured.out
        assert len(index) > 0  # Still returns content
    
    def test_check_consolidation_needed_time_gate(self, memory):
        """check_consolidation_needed() respects time gate."""
        # Create enough sessions to pass session gate
        for i in range(6):
            date = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
            memory.append(f"Entry from day {i}", date=date)
        
        # Now check with time gate that won't pass
        status = memory.check_consolidation_needed(min_hours=999999, min_sessions=5)
        
        # Time gate should not pass
        assert "time gate not met" in status["reason"].lower()
    
    def test_check_consolidation_needed_session_gate(self, memory):
        """check_consolidation_needed() respects session gate."""
        # Create daily logs
        for i in range(3):
            date = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
            memory.append(f"Entry from day {i}", date=date)
        
        status = memory.check_consolidation_needed(min_hours=0, min_sessions=5)
        
        # Time gate passes (min_hours=0), but not enough sessions
        assert "session gate not met" in status["reason"].lower()
    
    def test_check_consolidation_needed_both_gates(self, memory):
        """check_consolidation_needed() returns True when both gates pass."""
        # Create enough sessions
        for i in range(6):
            date = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
            memory.append(f"Entry from day {i}", date=date)
        
        # Set time gate to 0 (always passes)
        status = memory.check_consolidation_needed(min_hours=0, min_sessions=5)
        
        assert status["needed"] is True
        assert status["locked"] is False
    
    def test_consolidate_dry_run(self, memory):
        """consolidate() dry_run doesn't modify files."""
        memory.append("Entry 1", date="2026-04-11")
        memory.append("Entry 2", date="2026-04-12")
        
        stats = memory.consolidate(days=7, dry_run=True)
        
        assert stats is not None
        assert stats.daily_logs_processed == 2
        assert stats.total_input_bytes > 0
    
    def test_memory_entry_repr(self):
        """MemoryEntry has useful repr."""
        entry = MemoryEntry(
            content="test content",
            timestamp=datetime(2026, 4, 12, 10, 30),
            source_file=Path("memory/2026-04-12.md"),
            score=3.5
        )
        
        repr_str = repr(entry)
        assert "2026-04-12" in repr_str
        assert "2026-04-12.md" in repr_str
        assert "score=3.50" in repr_str


class TestConsolidationLocking:
    """Test consolidation locking mechanism."""
    
    @pytest.fixture
    def temp_workspace(self):
        """Create temporary workspace."""
        temp_dir = Path(tempfile.mkdtemp())
        yield temp_dir
        shutil.rmtree(temp_dir)
    
    @pytest.fixture
    def memory(self, temp_workspace):
        """Create Memory instance."""
        return Memory(agent_id="test-agent", workspace=temp_workspace)
    
    def test_acquire_lock_success(self, memory):
        """_acquire_lock() creates lock file."""
        success = memory._acquire_lock("test-session")
        assert success is True
        assert memory.lock_file.exists()
    
    def test_acquire_lock_prevents_concurrent(self, memory):
        """_acquire_lock() prevents concurrent consolidation."""
        memory._acquire_lock("session-1")
        
        # Second acquire should fail
        success = memory._acquire_lock("session-2")
        assert success is False
    
    def test_release_lock(self, memory):
        """_release_lock() releases lock."""
        memory._acquire_lock("test-session")
        memory._release_lock()
        
        # Should be able to acquire again
        success = memory._acquire_lock("test-session-2")
        assert success is True
    
    def test_stale_lock_ignored(self, memory):
        """Stale locks (>30min) are ignored."""
        import json
        import time
        
        # Create stale lock (31 minutes old)
        stale_time = (datetime.now().timestamp() - 31 * 60) * 1000
        lock = {
            "locked_by": "stale-session",
            "locked_at": stale_time,
            "last_consolidated_at": stale_time
        }
        
        memory.lock_file.parent.mkdir(parents=True, exist_ok=True)
        with open(memory.lock_file, "w") as f:
            json.dump(lock, f)
        
        # Should be able to acquire despite existing lock
        success = memory._acquire_lock("new-session")
        assert success is True
