from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from dailyverse_lib.reminder import (
    Slot,
    compute_next_moment,
    local_hm_as_utc,
    moment_for_local_clock,
    utc_offset_seconds,
)

ZURICH = ZoneInfo("Europe/Zurich")


def test_no_enabled_slots_returns_none() -> None:
    now = datetime(2026, 10, 11, 9, 0, 0)
    slots = [
        Slot(False, 8, 0),
        Slot(False, 12, 0),
        Slot(False, 20, 0),
    ]
    assert compute_next_moment(now, slots) is None


def test_picks_earliest_future_slot_today() -> None:
    now = datetime(2026, 10, 11, 9, 0, 0)
    slots = [
        Slot(True, 8, 0),
        Slot(True, 12, 0),
        Slot(True, 20, 0),
    ]
    nxt = compute_next_moment(now, slots)
    assert nxt == datetime(2026, 10, 11, 12, 0, 0)


def test_rolls_to_tomorrow_when_all_passed() -> None:
    now = datetime(2026, 10, 11, 21, 0, 0)
    slots = [
        Slot(True, 8, 0),
        Slot(False, 12, 0),
        Slot(True, 20, 0),
    ]
    nxt = compute_next_moment(now, slots)
    assert nxt == datetime(2026, 10, 12, 8, 0, 0)


def test_enforces_five_minute_minimum_lead() -> None:
    now = datetime(2026, 10, 11, 11, 58, 0)
    slots = [Slot(True, 12, 0)]
    nxt = compute_next_moment(now, slots)
    assert nxt is not None
    assert nxt >= datetime(2026, 10, 11, 12, 3, 0)


def test_respects_last_temporal_event_five_minute_rule() -> None:
    now = datetime(2026, 10, 11, 8, 58, 0, tzinfo=ZURICH)
    last = datetime(2026, 10, 11, 8, 56, 0, tzinfo=ZURICH)
    slots = [Slot(True, 9, 0)]
    nxt = compute_next_moment(now, slots, last_temporal=last)
    # earliest = max(now+5=09:03, last+5=09:01) → 09:03 (past intended 09:00)
    assert nxt == datetime(2026, 10, 11, 9, 3, 0, tzinfo=ZURICH)


def test_last_temporal_can_dominate_when_later_than_now_plus_five() -> None:
    now = datetime(2026, 10, 11, 8, 50, 0, tzinfo=ZURICH)
    last = datetime(2026, 10, 11, 8, 48, 0, tzinfo=ZURICH)
    # Slot at 08:52 is after now but before last+5 (08:53) and now+5 (08:55)
    slots = [Slot(True, 8, 52)]
    nxt = compute_next_moment(now, slots, last_temporal=last)
    assert nxt == datetime(2026, 10, 11, 8, 55, 0, tzinfo=ZURICH)


def test_ignores_disabled_slots() -> None:
    now = datetime(2026, 10, 11, 7, 0, 0)
    slots = [
        Slot(False, 8, 0),
        Slot(True, 20, 0),
    ]
    nxt = compute_next_moment(now, slots)
    assert nxt == datetime(2026, 10, 11, 20, 0, 0)


def test_zurich_summer_offset_is_utc_plus_two() -> None:
    # CEST: last Sunday of March → last Sunday of October
    summer = datetime(2026, 7, 15, 8, 0, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, summer) == 2 * 3600


def test_zurich_winter_offset_is_utc_plus_one() -> None:
    winter = datetime(2026, 1, 15, 8, 0, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, winter) == 1 * 3600


def test_moment_for_local_clock_zurich_summer_nine_am() -> None:
    now = datetime(2026, 7, 15, 8, 0, 0, tzinfo=ZURICH)
    target = moment_for_local_clock(now, 9, 0, day_offset=0)
    assert target == datetime(2026, 7, 15, 9, 0, 0, tzinfo=ZURICH)
    # Same instant as 07:00 UTC while CEST (UTC+2)
    assert target.astimezone(timezone.utc) == datetime(
        2026, 7, 15, 7, 0, 0, tzinfo=timezone.utc
    )


def test_moment_for_local_clock_zurich_winter_nine_am() -> None:
    now = datetime(2026, 1, 15, 8, 0, 0, tzinfo=ZURICH)
    target = moment_for_local_clock(now, 9, 0, day_offset=0)
    assert target == datetime(2026, 1, 15, 9, 0, 0, tzinfo=ZURICH)
    # Same instant as 08:00 UTC while CET (UTC+1)
    assert target.astimezone(timezone.utc) == datetime(
        2026, 1, 15, 8, 0, 0, tzinfo=timezone.utc
    )


def test_compute_next_zurich_summer_schedules_local_nine() -> None:
    now = datetime(2026, 7, 15, 8, 0, 0, tzinfo=ZURICH)
    nxt = compute_next_moment(now, [Slot(True, 9, 0)])
    assert nxt == datetime(2026, 7, 15, 9, 0, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, nxt) == 2 * 3600


def test_compute_next_zurich_winter_schedules_local_nine() -> None:
    now = datetime(2026, 1, 15, 8, 0, 0, tzinfo=ZURICH)
    nxt = compute_next_moment(now, [Slot(True, 9, 0)])
    assert nxt == datetime(2026, 1, 15, 9, 0, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, nxt) == 1 * 3600


def test_legacy_utc_moment_bug_explains_one_hour_winter_skew() -> None:
    """Feeding local HH:MM to a UTC constructor (old Gregorian.moment misuse)
    schedules one hour late in Zurich winter (CET = UTC+1).
    """
    offset = 1 * 3600
    # Correct: local 09:00 CET → 08:00 UTC
    correct_utc = local_hm_as_utc(2026, 1, 15, 9, 0, offset)
    assert correct_utc == datetime(2026, 1, 15, 8, 0, 0)
    # Bug: treat local components as UTC → "09:00 UTC" fires at 10:00 local
    buggy_as_utc = datetime(2026, 1, 15, 9, 0, 0)
    local_fire = buggy_as_utc + timedelta(seconds=offset)
    assert local_fire.hour == 10
    assert local_fire.minute == 0


def test_legacy_utc_moment_bug_explains_two_hour_summer_skew() -> None:
    offset = 2 * 3600
    correct_utc = local_hm_as_utc(2026, 7, 15, 9, 0, offset)
    assert correct_utc == datetime(2026, 7, 15, 7, 0, 0)
    buggy_as_utc = datetime(2026, 7, 15, 9, 0, 0)
    local_fire = buggy_as_utc + timedelta(seconds=offset)
    assert local_fire.hour == 11
