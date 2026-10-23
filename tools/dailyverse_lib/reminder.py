"""Pure-Python mirror of ReminderScheduler local-time scheduling."""

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
    """Mirror ReminderScheduler.momentForLocalClock.

    ``now`` must be timezone-aware (watch local zone). Returns an aware datetime
    at the local wall-clock HH:MM on today (day_offset=0) or tomorrow (+1).
    """
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware (watch local zone)")
    local_midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
    target = local_midnight + timedelta(
        days=day_offset,
        hours=hour,
        minutes=minute,
    )
    return target


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


def compute_next_moment(
    now: datetime,
    slots: list[Slot],
    *,
    min_lead_seconds: int = MIN_LEAD_SECONDS,
    passed_grace_seconds: int = PASSED_GRACE_SECONDS,
    last_temporal: datetime | None = None,
) -> datetime | None:
    """Return earliest future reminder instant in the same tz as ``now``.

    Naive datetimes are treated as local wall time (tests without a zone).
    Timezone-aware datetimes exercise Zurich-style UTC offsets / DST.
    """
    if now.tzinfo is None:
        # Legacy naive path: wall-clock arithmetic only.
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
        candidate = moment_for_local_clock(
            aware_now, slot.hour, slot.minute, day_offset=0
        )
        if candidate <= aware_now + timedelta(seconds=passed_grace_seconds):
            candidate = moment_for_local_clock(
                aware_now, slot.hour, slot.minute, day_offset=1
            )
        if candidate < earliest:
            candidate = earliest
        if best is None or candidate < best:
            best = candidate

    if best is None:
        return None
    if strip_tz:
        return best.replace(tzinfo=None)
    return best


def local_hm_as_utc(
    local_year: int,
    local_month: int,
    local_day: int,
    hour: int,
    minute: int,
    offset_seconds: int,
) -> datetime:
    """Convert local wall HH:MM + UTC offset to a UTC datetime.

    Mirrors the wrong Gregorian.moment pitfall when offset is applied: feeding
    local components to a UTC constructor yields a Moment offset hours early/
    late. Correct conversion subtracts the offset from the local components
    interpreted as civil time.
    """
    as_utc_naive = datetime(local_year, local_month, local_day, hour, minute, 0)
    return as_utc_naive - timedelta(seconds=offset_seconds)
