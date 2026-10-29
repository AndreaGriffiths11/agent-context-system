"""
agent_context.window — Sliding context window with per-message decay

Recent messages stay at full fidelity. Older messages are progressively
compressed based on a decay function that maps a message's age to a
fidelity value between 0.0 and 1.0.

Usage:
    from agent_context import SlidingWindow

    window = SlidingWindow(max_messages=50, full_fidelity=5)
    window.add("user", "Deploy proof-agent v1.0.3 to staging")
    window.add("assistant", "Deployed. All checks passed.")
    for msg in window.render():
        print(msg.role, msg.fidelity, msg.content)

Extension points:
    decay:      Callable[[age, full_fidelity], float]  -> fidelity in [0, 1]
    compressor: Callable[[content, fidelity], str]     -> compressed content

Built-in decay curves:
    harmonic_decay                  default, full_fidelity / (age + 1)
    linear_decay(span)              straight line to 0 over `span` messages
    exponential_decay(half_life)    halves every `half_life` messages
    importance_weighted(base)       lifts `base` by metadata["importance"]
    get_decay(name, **kwargs)       look up a curve by name

Summary checkpointing (opt-in):
    window = SlidingWindow(max_messages=20, checkpoint=True)
    # Evicted messages are batched and summarized into window.checkpoints.
    summarizer: Callable[[List[Message]], str]  -> summary text
"""

import math
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Callable, Dict, Any, List, Optional, Union

DecayFn = Callable[[int, int], float]
Compressor = Callable[[str, float], str]


@dataclass
class Message:
    """A message stored in the window at full fidelity."""
    role: str
    content: str
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class CompressedMessage:
    """A message as rendered for the context window."""
    role: str
    content: str
    fidelity: float
    age: int
    original_length: int
    timestamp: datetime
    metadata: Dict[str, Any] = field(default_factory=dict)

    @property
    def compressed(self) -> bool:
        return len(self.content) < self.original_length


def harmonic_decay(age: int, full_fidelity: int) -> float:
    """Default decay: full fidelity for the newest messages, then 1/age falloff.

    age is 0 for the newest message. Messages with age < full_fidelity keep
    fidelity 1.0. After that fidelity is full_fidelity / (age + 1), so it
    drops smoothly toward 0 without reaching it.
    """
    if age < full_fidelity:
        return 1.0
    return full_fidelity / (age + 1)


def linear_decay(span: int = 10) -> DecayFn:
    """Linear decay: fidelity drops in equal steps and reaches 0 after `span`
    messages past the full-fidelity window (at age full_fidelity + span - 1).
    """
    if span < 1:
        raise ValueError("span must be >= 1")

    def decay(age: int, full_fidelity: int) -> float:
        if age < full_fidelity:
            return 1.0
        return max(0.0, 1.0 - (age - full_fidelity + 1) / span)

    return decay


def exponential_decay(half_life: float = 5.0) -> DecayFn:
    """Exponential decay: fidelity halves every `half_life` messages past the
    full-fidelity window. Never reaches 0.
    """
    if half_life <= 0:
        raise ValueError("half_life must be > 0")

    def decay(age: int, full_fidelity: int) -> float:
        if age < full_fidelity:
            return 1.0
        return 0.5 ** ((age - full_fidelity + 1) / half_life)

    return decay


def importance_weighted(
    base: Optional[DecayFn] = None,
    key: str = "importance",
    default: float = 0.0,
) -> DecayFn:
    """Importance-weighted decay: important messages decay more slowly.

    Reads `metadata[key]` (clamped to [0, 1], `default` when missing) and
    lifts the base curve toward full fidelity:

        fidelity = base + (1 - base) * importance

    importance 0 follows `base` exactly; importance 1 never decays.
    With the default `default=0.0`, messages without importance metadata
    behave exactly like `base`.
    """
    base_fn = base or harmonic_decay
    if not 0.0 <= default <= 1.0:
        raise ValueError("default must be in [0, 1]")

    def decay(age: int, full_fidelity: int, metadata: Optional[Dict[str, Any]] = None) -> float:
        b = max(0.0, min(1.0, float(base_fn(age, full_fidelity))))
        raw = (metadata or {}).get(key, default)
        try:
            importance = max(0.0, min(1.0, float(raw)))
        except (TypeError, ValueError):
            importance = default
        return b + (1.0 - b) * importance

    decay.uses_metadata = True  # type: ignore[attr-defined]
    return decay


DECAY_CURVES: Dict[str, Callable[..., DecayFn]] = {
    "harmonic": lambda: harmonic_decay,
    "linear": linear_decay,
    "exponential": exponential_decay,
    "importance": importance_weighted,
}


def get_decay(name: str, **kwargs: Any) -> DecayFn:
    """Build a decay curve by name, e.g. get_decay("exponential", half_life=3).

    For "importance", `base` may itself be a curve name or a callable.
    """
    factory = DECAY_CURVES.get(name)
    if factory is None:
        raise ValueError(f"unknown decay curve {name!r}; choose from {sorted(DECAY_CURVES)}")
    if name == "importance" and isinstance(kwargs.get("base"), str):
        kwargs["base"] = get_decay(kwargs["base"])
    return factory(**kwargs)


def truncate_compressor(content: str, fidelity: float) -> str:
    """Default compressor: keep the first `fidelity` share of the content.

    Cuts on a word boundary when possible and marks the cut with an ellipsis.
    Returns "" when fidelity <= 0.
    """
    if fidelity >= 1.0:
        return content
    if fidelity <= 0.0:
        return ""
    keep = math.ceil(len(content) * fidelity)
    if keep >= len(content):
        return content
    cut = content[:keep]
    space = cut.rfind(" ")
    if space > 0:
        cut = cut[:space]
    return cut.rstrip() + "…"


Summarizer = Callable[[List[Message]], str]


@dataclass
class Checkpoint:
    """A summary of messages that left the window."""
    summary: str
    message_count: int
    start: datetime
    end: datetime
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


def default_summarizer(messages: List[Message], max_chars: int = 80) -> str:
    """Default summarizer: one `role: snippet` line per message.

    Each snippet is the message content collapsed to one line and truncated
    to roughly `max_chars` characters with truncate_compressor.
    """
    lines = []
    for msg in messages:
        text = " ".join(msg.content.split())
        if len(text) > max_chars:
            text = truncate_compressor(text, max_chars / len(text))
        lines.append(f"{msg.role}: {text}")
    return "\n".join(lines)


class SlidingWindow:
    """Sliding window of messages with per-message decay.

    Messages are stored at full fidelity. Compression happens at render
    time, so changing the decay function never loses source data.

    Args:
        max_messages: Maximum messages kept. Oldest are evicted first.
            None means unbounded.
        full_fidelity: Number of newest messages kept uncompressed by the
            default decay function.
        decay: Maps (age, full_fidelity) to a fidelity in [0, 1], or the
            name of a built-in curve ("harmonic", "linear", "exponential",
            "importance"). Callables with `uses_metadata = True` also
            receive the message metadata as a third argument.
        compressor: Maps (content, fidelity) to compressed content.
        min_fidelity: Messages whose fidelity falls below this are omitted
            from render().
        checkpoint: Enable summary checkpointing of evicted messages.
            Off by default. Passing `summarizer` also enables it.
        summarizer: Maps a list of evicted messages to summary text.
            Defaults to default_summarizer.
        checkpoint_every: Number of evicted messages per checkpoint.
            Defaults to max_messages, i.e. one checkpoint each time a full
            window's worth of messages has rolled out.
    """

    def __init__(
        self,
        max_messages: Optional[int] = None,
        full_fidelity: int = 5,
        decay: Optional[Union[DecayFn, str]] = None,
        compressor: Optional[Compressor] = None,
        min_fidelity: float = 0.0,
        checkpoint: bool = False,
        summarizer: Optional[Summarizer] = None,
        checkpoint_every: Optional[int] = None,
    ):
        if isinstance(decay, str):
            decay = get_decay(decay)
        if max_messages is not None and max_messages < 1:
            raise ValueError("max_messages must be >= 1 or None")
        if full_fidelity < 0:
            raise ValueError("full_fidelity must be >= 0")
        if checkpoint_every is not None and checkpoint_every < 1:
            raise ValueError("checkpoint_every must be >= 1 or None")
        self.max_messages = max_messages
        self.full_fidelity = full_fidelity
        self.decay = decay or harmonic_decay
        self.compressor = compressor or truncate_compressor
        self.min_fidelity = min_fidelity
        self.messages: List[Message] = []
        self.checkpointing = checkpoint or summarizer is not None
        self.summarizer = summarizer or default_summarizer
        self.checkpoint_every = checkpoint_every or max_messages or 1
        self.checkpoints: List[Checkpoint] = []
        self._pending: List[Message] = []

    def __len__(self) -> int:
        return len(self.messages)

    def add(
        self,
        role: str,
        content: str,
        timestamp: Optional[datetime] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> List[Message]:
        """Add a message. Returns any messages evicted from the window."""
        msg = Message(role=role, content=content, metadata=metadata or {})
        if timestamp is not None:
            msg.timestamp = timestamp
        self.messages.append(msg)

        evicted: List[Message] = []
        if self.max_messages is not None and len(self.messages) > self.max_messages:
            overflow = len(self.messages) - self.max_messages
            evicted = self.messages[:overflow]
            self.messages = self.messages[overflow:]
        if evicted and self.checkpointing:
            self._pending.extend(evicted)
            while len(self._pending) >= self.checkpoint_every:
                batch = self._pending[:self.checkpoint_every]
                self._pending = self._pending[self.checkpoint_every:]
                self._make_checkpoint(batch)
        return evicted

    def _make_checkpoint(self, batch: List[Message]) -> Checkpoint:
        cp = Checkpoint(
            summary=self.summarizer(list(batch)),
            message_count=len(batch),
            start=batch[0].timestamp,
            end=batch[-1].timestamp,
        )
        self.checkpoints.append(cp)
        return cp

    @property
    def pending(self) -> List[Message]:
        """Evicted messages not yet summarized into a checkpoint."""
        return list(self._pending)

    def flush_checkpoint(self) -> Optional[Checkpoint]:
        """Summarize any pending evicted messages now, e.g. at session end.

        Returns the new checkpoint, or None if nothing was pending or
        checkpointing is disabled.
        """
        if not self.checkpointing or not self._pending:
            return None
        batch, self._pending = self._pending, []
        return self._make_checkpoint(batch)

    def fidelity(self, age: int, metadata: Optional[Dict[str, Any]] = None) -> float:
        """Fidelity for a message of the given age, clamped to [0, 1]."""
        if getattr(self.decay, "uses_metadata", False):
            value = self.decay(age, self.full_fidelity, metadata or {})  # type: ignore[call-arg]
        else:
            value = self.decay(age, self.full_fidelity)
        return max(0.0, min(1.0, float(value)))

    def render(self) -> List[CompressedMessage]:
        """Return messages oldest-first with decay applied."""
        total = len(self.messages)
        out: List[CompressedMessage] = []
        for i, msg in enumerate(self.messages):
            age = total - 1 - i
            fid = self.fidelity(age, msg.metadata)
            if fid <= 0.0 or fid < self.min_fidelity:
                continue
            out.append(CompressedMessage(
                role=msg.role,
                content=msg.content if fid >= 1.0 else self.compressor(msg.content, fid),
                fidelity=fid,
                age=age,
                original_length=len(msg.content),
                timestamp=msg.timestamp,
                metadata=dict(msg.metadata),
            ))
        return out

    def to_text(self) -> str:
        """Render the window as plain text, one `role: content` per message.

        When checkpointing is enabled, checkpoint summaries come first, each
        prefixed with `summary:`.
        """
        lines = [f"summary: {cp.summary}" for cp in self.checkpoints]
        lines.extend(f"{m.role}: {m.content}" for m in self.render())
        return "\n".join(lines)
