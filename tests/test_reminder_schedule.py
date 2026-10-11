from __future__ import annotations

from datetime import datetime

from dailyverse_lib.reminder import Slot, compute_next_moment


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


def test_ignores_disabled_slots() -> None:
    now = datetime(2026, 10, 11, 7, 0, 0)
    slots = [
        Slot(False, 8, 0),
        Slot(True, 20, 0),
    ]
    nxt = compute_next_moment(now, slots)
    assert nxt == datetime(2026, 10, 11, 20, 0, 0)
