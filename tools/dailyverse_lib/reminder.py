"""Pure-Python mirror of ReminderScheduler.computeNextMoment."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class Slot:
    enabled: bool
    hour: int
    minute: int


def compute_next_moment(
    now: datetime,
    slots: list[Slot],
    *,
    min_lead_seconds: int = 5 * 60,
    passed_grace_seconds: int = 30,
) -> datetime | None:
    """Return earliest future reminder instant, or None if no slot enabled."""
    best: datetime | None = None

    for slot in slots:
        if not slot.enabled:
            continue
        candidate = now.replace(
            hour=slot.hour,
            minute=slot.minute,
            second=0,
            microsecond=0,
        )
        if candidate <= now + timedelta(seconds=passed_grace_seconds):
            candidate = candidate + timedelta(days=1)
        earliest = now + timedelta(seconds=min_lead_seconds)
        if candidate < earliest:
            candidate = earliest
        if best is None or candidate < best:
            best = candidate
    return best
