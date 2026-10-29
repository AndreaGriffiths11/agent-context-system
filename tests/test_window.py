"""Tests for agent_context.window module."""

import pytest
from agent_context import (
    SlidingWindow,
    DECAY_CURVES,
    exponential_decay,
    get_decay,
    harmonic_decay,
    importance_weighted,
    linear_decay,
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


class TestLinearDecay:
    def test_full_fidelity_window(self):
        d = linear_decay(span=4)
        assert [d(age, 3) for age in range(3)] == [1.0, 1.0, 1.0]

    def test_equal_steps_to_zero(self):
        d = linear_decay(span=4)
        assert [d(age, 2) for age in range(2, 8)] == [0.75, 0.5, 0.25, 0.0, 0.0, 0.0]

    def test_invalid_span(self):
        with pytest.raises(ValueError):
            linear_decay(span=0)


class TestExponentialDecay:
    def test_full_fidelity_window(self):
        d = exponential_decay(half_life=2)
        assert d(0, 2) == 1.0 and d(1, 2) == 1.0

    def test_halves_every_half_life(self):
        d = exponential_decay(half_life=2)
        assert d(3, 2) == pytest.approx(0.5)
        assert d(5, 2) == pytest.approx(0.25)
        assert 0 < d(50, 2) < 1e-6

    def test_monotonic(self):
        d = exponential_decay(half_life=3)
        values = [d(age, 1) for age in range(1, 20)]
        assert values == sorted(values, reverse=True)

    def test_invalid_half_life(self):
        with pytest.raises(ValueError):
            exponential_decay(half_life=0)


class TestImportanceWeighted:
    def test_no_importance_matches_base(self):
        d = importance_weighted()
        for age in range(12):
            assert d(age, 3, {}) == harmonic_decay(age, 3)
            assert d(age, 3) == harmonic_decay(age, 3)

    def test_full_importance_never_decays(self):
        d = importance_weighted(base=linear_decay(span=2))
        assert d(100, 1, {"importance": 1.0}) == 1.0

    def test_partial_importance_lifts_base(self):
        d = importance_weighted(base=linear_decay(span=4))
        # base at age 3, full=2 -> 0.5; lifted halfway by importance 0.5
        assert d(3, 2, {"importance": 0.5}) == pytest.approx(0.75)

    def test_importance_clamped_and_invalid_ignored(self):
        d = importance_weighted(base=linear_decay(span=2))
        assert d(5, 0, {"importance": 7}) == 1.0
        assert d(5, 0, {"importance": -3}) == 0.0
        assert d(5, 0, {"importance": "high"}) == 0.0

    def test_custom_key_and_default(self):
        d = importance_weighted(base=linear_decay(span=2), key="pin", default=1.0)
        assert d(5, 0, {}) == 1.0
        assert d(5, 0, {"pin": 0}) == 0.0

    def test_invalid_default(self):
        with pytest.raises(ValueError):
            importance_weighted(default=1.5)

    def test_window_passes_metadata(self):
        w = SlidingWindow(
            full_fidelity=1,
            decay=importance_weighted(base=linear_decay(span=1)),
        )
        w.add("user", "pinned fact", metadata={"importance": 1.0})
        w.add("user", "chatter")
        w.add("user", "latest")
        assert [m.content for m in w.render()] == ["pinned fact", "latest"]


class TestGetDecay:
    def test_registry_names(self):
        assert set(DECAY_CURVES) == {"harmonic", "linear", "exponential", "importance"}

    def test_harmonic_is_default_function(self):
        assert get_decay("harmonic") is harmonic_decay

    def test_kwargs_forwarded(self):
        assert get_decay("linear", span=4)(2, 2) == 0.75
        assert get_decay("exponential", half_life=1)(0, 0) == pytest.approx(0.5)

    def test_importance_base_by_name(self):
        d = get_decay("importance", base="linear", key="w")
        assert d(20, 0, {"w": 0.0}) == 0.0
        assert d(20, 0, {"w": 1.0}) == 1.0

    def test_unknown_name(self):
        with pytest.raises(ValueError):
            get_decay("cubic")

    def test_window_accepts_curve_name(self):
        w = SlidingWindow(full_fidelity=2, decay="exponential")
        assert w.fidelity(1) == 1.0
        assert w.fidelity(6) == pytest.approx(0.5)

    def test_default_window_still_harmonic(self):
        w = SlidingWindow(full_fidelity=3)
        assert w.decay is harmonic_decay
        assert [w.fidelity(a) for a in range(8)] == [harmonic_decay(a, 3) for a in range(8)]


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
