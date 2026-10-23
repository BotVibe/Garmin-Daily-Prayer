"""Pure-Python mirror of ReminderScheduler local-time scheduling and due checks."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone, tzinfo


@dataclass(frozen=True)
class Slot:
    enabled: bool
    hour: int
    minute: int


MIN_LEAD_SECONDS = 5 * 60
PASSED_GRACE_SECONDS = 30
DUE_WINDOW_SECONDS = 15 * 60


def utc_offset_seconds(tz: tzinfo, at: datetime) -> int:
    """Total UTC offset (standard + DST) at ``at``, matching System.ClockTime."""
    aware = at if at.tzinfo is not None else at.replace(tzinfo=tz)
    offset = aware.utcoffset()
    if offset is None:
        raise ValueError("tzinfo produced no utcoffset")
    return int(offset.total_seconds())


def moment_for_local_clock(
    now: datetime,
    hour: int,
    minute: int,
    *,
    day_offset: int = 0,
) -> datetime:
    """Mirror ReminderScheduler.momentForLocalClock."""
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware (watch local zone)")
    local_midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
    return local_midnight + timedelta(
        days=day_offset,
        hours=hour,
        minutes=minute,
    )


def earliest_legal(
    now: datetime,
    *,
    last_temporal: datetime | None = None,
    min_lead_seconds: int = MIN_LEAD_SECONDS,
) -> datetime:
    """Mirror ReminderScheduler.earliestLegalSeconds as an aware datetime."""
    earliest = now + timedelta(seconds=min_lead_seconds)
    if last_temporal is not None:
        after_last = last_temporal + timedelta(seconds=min_lead_seconds)
        if after_last > earliest:
            earliest = after_last
    return earliest


def is_reminder_due(
    now: datetime,
    slots: list[Slot],
    *,
    due_window_seconds: int = DUE_WINDOW_SECONDS,
) -> bool:
    """Mirror ReminderScheduler.isReminderDueNow — enabled slots only."""
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware for due checks")
    now_minutes = now.hour * 60 + now.minute
    window_minutes = due_window_seconds // 60
    for slot in slots:
        if not slot.enabled:
            continue
        slot_minutes = slot.hour * 60 + slot.minute
        delta = abs(now_minutes - slot_minutes)
        nearest = min(delta, (24 * 60) - delta)
        if nearest <= window_minutes:
            return True
    return False


def should_request_wake(
    now: datetime,
    slots: list[Slot],
    *,
    due_window_seconds: int = DUE_WINDOW_SECONDS,
) -> bool:
    """True only when a TemporalEvent should show the Accept/Decline dialog."""
    return is_reminder_due(now, slots, due_window_seconds=due_window_seconds)


def compute_next_moment(
    now: datetime,
    slots: list[Slot],
    *,
    min_lead_seconds: int = MIN_LEAD_SECONDS,
    passed_grace_seconds: int = PASSED_GRACE_SECONDS,
    due_window_seconds: int = DUE_WINDOW_SECONDS,
    last_temporal: datetime | None = None,
) -> datetime | None:
    """Return earliest future reminder instant in the same tz as ``now``.

    Naive datetimes are treated as local wall time (legacy tests without a zone).
    Never invents a non-slot catch-up time far from an enabled HH:MM.
    """
    if now.tzinfo is None:
        aware_now = now.replace(tzinfo=timezone.utc)
        strip_tz = True
    else:
        aware_now = now
        strip_tz = False

    best: datetime | None = None
    earliest = earliest_legal(
        aware_now,
        last_temporal=last_temporal,
        min_lead_seconds=min_lead_seconds,
    )

    for slot in slots:
        if not slot.enabled:
            continue
        today = moment_for_local_clock(aware_now, slot.hour, slot.minute, day_offset=0)
        tomorrow = moment_for_local_clock(
            aware_now, slot.hour, slot.minute, day_offset=1
        )

        if today <= aware_now + timedelta(seconds=passed_grace_seconds):
            candidate = tomorrow
        elif today < earliest:
            if (earliest - today) <= timedelta(seconds=due_window_seconds):
                candidate = earliest
            else:
                candidate = tomorrow
        else:
            candidate = today

        if candidate < earliest:
            continue
        if best is None or candidate < best:
            best = candidate

    if best is None:
        return None
    if strip_tz:
        return best.replace(tzinfo=None)
    return best


def simulate_fires(
    start: datetime,
    end: datetime,
    slots: list[Slot],
    *,
    step: timedelta = timedelta(minutes=1),
) -> list[datetime]:
    """Walk ``[start, end)`` and record times where a due wake would be shown
    if a TemporalEvent ran at that minute (for multi-day expectation checks).
    """
    fires: list[datetime] = []
    t = start
    while t < end:
        if should_request_wake(t, slots):
            # Collapse a due window to a single fire at the slot minute.
            for slot in slots:
                if not slot.enabled:
                    continue
                if t.hour == slot.hour and t.minute == slot.minute:
                    fires.append(t)
                    break
        t += step
    return fires


def local_hm_as_utc(
    local_year: int,
    local_month: int,
    local_day: int,
    hour: int,
    minute: int,
    offset_seconds: int,
) -> datetime:
    """Convert local wall HH:MM + UTC offset to a UTC datetime."""
    as_utc_naive = datetime(local_year, local_month, local_day, hour, minute, 0)
    return as_utc_naive - timedelta(seconds=offset_seconds)
