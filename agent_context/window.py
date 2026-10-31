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
"""

import math
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Callable, Dict, Any, List, Optional

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


class SlidingWindow:
    """Sliding window of messages with per-message decay.

    Messages are stored at full fidelity. Compression happens at render
    time, so changing the decay function never loses source data.

    Args:
        max_messages: Maximum messages kept. Oldest are evicted first.
            None means unbounded.
        full_fidelity: Number of newest messages kept uncompressed by the
            default decay function.
        decay: Maps (age, full_fidelity) to a fidelity in [0, 1].
        compressor: Maps (content, fidelity) to compressed content.
        min_fidelity: Messages whose fidelity falls below this are omitted
            from render().
    """

    def __init__(
        self,
        max_messages: Optional[int] = None,
        full_fidelity: int = 5,
        decay: Optional[DecayFn] = None,
        compressor: Optional[Compressor] = None,
        min_fidelity: float = 0.0,
    ):
        if max_messages is not None and max_messages < 1:
            raise ValueError("max_messages must be >= 1 or None")
        if full_fidelity < 0:
            raise ValueError("full_fidelity must be >= 0")
        self.max_messages = max_messages
        self.full_fidelity = full_fidelity
        self.decay = decay or harmonic_decay
        self.compressor = compressor or truncate_compressor
        self.min_fidelity = min_fidelity
        self.messages: List[Message] = []

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
        return evicted

    def fidelity(self, age: int) -> float:
        """Fidelity for a message of the given age, clamped to [0, 1]."""
        return max(0.0, min(1.0, float(self.decay(age, self.full_fidelity))))

    def render(self) -> List[CompressedMessage]:
        """Return messages oldest-first with decay applied."""
        total = len(self.messages)
        out: List[CompressedMessage] = []
        for i, msg in enumerate(self.messages):
            age = total - 1 - i
            fid = self.fidelity(age)
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
        """Render the window as plain text, one `role: content` per message."""
        return "\n".join(f"{m.role}: {m.content}" for m in self.render())
