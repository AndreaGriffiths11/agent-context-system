"""Tests for agent_context.window module."""

import pytest
from agent_context import (
    SlidingWindow,
    harmonic_decay,
    truncate_compressor,
)


class TestHarmonicDecay:
    def test_recent_messages_full_fidelity(self):
        for age in range(5):
            assert harmonic_decay(age, 5) == 1.0

    def test_older_messages_decay_monotonically(self):
        values = [harmonic_decay(age, 5) for age in range(5, 20)]
        assert all(0 < v < 1 for v in values)
        assert values == sorted(values, reverse=True)

    def test_zero_full_fidelity(self):
        assert harmonic_decay(0, 0) == 0.0


class TestTruncateCompressor:
    def test_full_fidelity_unchanged(self):
        assert truncate_compressor("hello world", 1.0) == "hello world"

    def test_zero_fidelity_empty(self):
        assert truncate_compressor("hello world", 0.0) == ""

    def test_cuts_on_word_boundary(self):
        out = truncate_compressor("alpha beta gamma delta", 0.5)
        assert out == "alpha beta…"

    def test_shorter_than_original(self):
        text = "one two three four five six seven eight"
        assert len(truncate_compressor(text, 0.3)) < len(text)


class TestSlidingWindow:
    def test_add_and_len(self):
        w = SlidingWindow()
        w.add("user", "hi")
        w.add("assistant", "hello")
        assert len(w) == 2

    def test_eviction_returns_oldest(self):
        w = SlidingWindow(max_messages=3)
        for i in range(3):
            assert w.add("user", f"m{i}") == []
        evicted = w.add("user", "m3")
        assert [m.content for m in evicted] == ["m0"]
        assert [m.content for m in w.messages] == ["m1", "m2", "m3"]

    def test_invalid_args(self):
        with pytest.raises(ValueError):
            SlidingWindow(max_messages=0)
        with pytest.raises(ValueError):
            SlidingWindow(full_fidelity=-1)

    def test_render_recent_full_older_compressed(self):
        w = SlidingWindow(full_fidelity=2)
        long_text = " ".join(f"word{i}" for i in range(40))
        for _ in range(6):
            w.add("user", long_text)
        rendered = w.render()
        assert [m.age for m in rendered] == [5, 4, 3, 2, 1, 0]
        assert rendered[-1].content == long_text
        assert rendered[-2].content == long_text
        assert not rendered[-1].compressed
        assert rendered[0].compressed
        lengths = [len(m.content) for m in rendered]
        assert lengths == sorted(lengths)

    def test_render_does_not_mutate_source(self):
        w = SlidingWindow(full_fidelity=0)
        w.add("user", "alpha beta gamma delta epsilon")
        w.add("user", "zeta")
        w.render()
        assert w.messages[0].content == "alpha beta gamma delta epsilon"

    def test_custom_decay_extension_point(self):
        calls = []

        def decay(age, full):
            calls.append((age, full))
            return 1.0 if age == 0 else 0.0

        w = SlidingWindow(full_fidelity=3, decay=decay)
        w.add("user", "old")
        w.add("user", "new")
        rendered = w.render()
        assert [m.content for m in rendered] == ["new"]
        assert (1, 3) in calls and (0, 3) in calls

    def test_decay_output_clamped(self):
        w = SlidingWindow(decay=lambda age, full: 5.0 if age == 0 else -1.0)
        assert w.fidelity(0) == 1.0
        assert w.fidelity(1) == 0.0

    def test_custom_compressor(self):
        w = SlidingWindow(full_fidelity=1, compressor=lambda c, f: c.upper())
        w.add("user", "old")
        w.add("user", "new")
        assert [m.content for m in w.render()] == ["OLD", "new"]

    def test_min_fidelity_drops_old_messages(self):
        w = SlidingWindow(full_fidelity=1, min_fidelity=0.4)
        for i in range(5):
            w.add("user", f"m{i}")
        # fidelities by age: 1.0, 0.5, 0.33, 0.25, 0.2
        assert [m.age for m in w.render()] == [1, 0]

    def test_metadata_preserved(self):
        w = SlidingWindow()
        w.add("user", "hi", metadata={"importance": 0.9})
        assert w.render()[0].metadata == {"importance": 0.9}

    def test_to_text(self):
        w = SlidingWindow()
        w.add("user", "hi")
        w.add("assistant", "hello")
        assert w.to_text() == "user: hi\nassistant: hello"
