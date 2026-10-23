from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from dailyverse_lib.reminder import (
    Slot,
    compute_next_moment,
    is_reminder_due,
    local_hm_as_utc,
    moment_for_local_clock,
    should_request_wake,
    simulate_fires,
    utc_offset_seconds,
)

ZURICH = ZoneInfo("Europe/Zurich")

# User report: only Reminder 1 at 09:00; R2/R3 disabled (stored 12:00 / 20:00 ignored).
ONLY_NINE = [
    Slot(True, 9, 0),
    Slot(False, 12, 0),
    Slot(False, 20, 0),
]

TWO_CUSTOM = [
    Slot(False, 8, 0),
    Slot(True, 14, 7),
    Slot(True, 22, 36),
]

ALL_OFF = [
    Slot(False, 9, 0),
    Slot(False, 12, 0),
    Slot(False, 20, 0),
]


def test_no_enabled_slots_returns_none() -> None:
    now = datetime(2026, 10, 11, 9, 0, 0)
    assert compute_next_moment(now, ALL_OFF) is None


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


def test_enforces_five_minute_minimum_lead_with_late_delivery() -> None:
    now = datetime(2026, 10, 11, 11, 58, 0)
    slots = [Slot(True, 12, 0)]
    nxt = compute_next_moment(now, slots)
    assert nxt is not None
    # 12:00 is 2 min ahead; earliest is 12:03 → late delivery still within due window
    assert nxt == datetime(2026, 10, 11, 12, 3, 0)


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
    summer = datetime(2026, 7, 15, 8, 0, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, summer) == 2 * 3600


def test_zurich_winter_offset_is_utc_plus_one() -> None:
    winter = datetime(2026, 1, 15, 8, 0, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, winter) == 1 * 3600


def test_moment_for_local_clock_zurich_summer_nine_am() -> None:
    now = datetime(2026, 7, 15, 8, 0, 0, tzinfo=ZURICH)
    target = moment_for_local_clock(now, 9, 0, day_offset=0)
    assert target == datetime(2026, 7, 15, 9, 0, 0, tzinfo=ZURICH)
    assert target.astimezone(timezone.utc) == datetime(
        2026, 7, 15, 7, 0, 0, tzinfo=timezone.utc
    )


def test_moment_for_local_clock_zurich_winter_nine_am() -> None:
    now = datetime(2026, 1, 15, 8, 0, 0, tzinfo=ZURICH)
    target = moment_for_local_clock(now, 9, 0, day_offset=0)
    assert target == datetime(2026, 1, 15, 9, 0, 0, tzinfo=ZURICH)
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
    offset = 1 * 3600
    correct_utc = local_hm_as_utc(2026, 1, 15, 9, 0, offset)
    assert correct_utc == datetime(2026, 1, 15, 8, 0, 0)
    buggy_as_utc = datetime(2026, 1, 15, 9, 0, 0)
    local_fire = buggy_as_utc + timedelta(seconds=offset)
    assert local_fire.hour == 10
    assert local_fire.minute == 0


def test_legacy_utc_moment_bug_explains_eleven_am_cest_extra() -> None:
    """v1.0.0: local 09:00 fed to Gregorian.moment (UTC) → fires 11:00 CEST.

    That matches the Zurich report of an extra alert at ~11:00 with only 09:00
    enabled (UTC+2). Current scheduler must not select 11:00.
    """
    offset = 2 * 3600
    buggy_as_utc = datetime(2026, 10, 23, 9, 0, 0)
    local_fire = buggy_as_utc + timedelta(seconds=offset)
    assert local_fire.hour == 11
    assert local_fire.minute == 0

    now = datetime(2026, 10, 23, 8, 0, 0, tzinfo=ZURICH)
    nxt = compute_next_moment(now, ONLY_NINE)
    assert nxt == datetime(2026, 10, 23, 9, 0, 0, tzinfo=ZURICH)
    assert nxt.hour != 11


# --- Owner spec cases -------------------------------------------------


def test_nine_am_only_never_schedules_eleven_in_zurich_summer() -> None:
    now = datetime(2026, 10, 23, 8, 30, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, now) == 2 * 3600
    nxt = compute_next_moment(now, ONLY_NINE)
    assert nxt == datetime(2026, 10, 23, 9, 0, 0, tzinfo=ZURICH)
    # After the 09:00 fire, next is tomorrow 09:00 — never 11:00 / 12:00 / 20:00.
    after = datetime(2026, 10, 23, 9, 5, 0, tzinfo=ZURICH)
    nxt2 = compute_next_moment(after, ONLY_NINE)
    assert nxt2 == datetime(2026, 10, 24, 9, 0, 0, tzinfo=ZURICH)


def test_disabled_slot_times_are_ignored_entirely() -> None:
    now = datetime(2026, 10, 23, 10, 0, 0, tzinfo=ZURICH)
    # R2 stored as 12:00 and R3 as 20:00 but disabled — must not schedule them.
    nxt = compute_next_moment(now, ONLY_NINE)
    assert nxt == datetime(2026, 10, 24, 9, 0, 0, tzinfo=ZURICH)
    assert not is_reminder_due(datetime(2026, 10, 23, 12, 0, 0, tzinfo=ZURICH), ONLY_NINE)
    assert not is_reminder_due(datetime(2026, 10, 23, 20, 0, 0, tzinfo=ZURICH), ONLY_NINE)


def test_all_disabled_means_no_schedule_and_no_due() -> None:
    now = datetime(2026, 10, 23, 9, 0, 0, tzinfo=ZURICH)
    assert compute_next_moment(now, ALL_OFF) is None
    assert not should_request_wake(now, ALL_OFF)


def test_two_reminders_fire_once_each_over_multiple_days() -> None:
    start = datetime(2026, 10, 20, 0, 0, 0, tzinfo=ZURICH)
    end = datetime(2026, 10, 23, 0, 0, 0, tzinfo=ZURICH)
    fires = simulate_fires(start, end, TWO_CUSTOM)
    expected = []
    for day in (20, 21, 22):
        expected.append(datetime(2026, 10, day, 14, 7, 0, tzinfo=ZURICH))
        expected.append(datetime(2026, 10, day, 22, 36, 0, tzinfo=ZURICH))
    assert fires == expected


def test_changing_settings_reschedules_to_new_slot_only() -> None:
    now = datetime(2026, 10, 23, 8, 0, 0, tzinfo=ZURICH)
    before = compute_next_moment(now, ONLY_NINE)
    assert before == datetime(2026, 10, 23, 9, 0, 0, tzinfo=ZURICH)

    # User moves Reminder 1 from 09:00 → 10:30 via Connect / on-watch.
    changed = [
        Slot(True, 10, 30),
        Slot(False, 12, 0),
        Slot(False, 20, 0),
    ]
    after = compute_next_moment(now, changed)
    assert after == datetime(2026, 10, 23, 10, 30, 0, tzinfo=ZURICH)
    # Old 09:00 must not be due anymore.
    assert not is_reminder_due(datetime(2026, 10, 23, 9, 0, 0, tzinfo=ZURICH), changed)
    assert is_reminder_due(datetime(2026, 10, 23, 10, 30, 0, tzinfo=ZURICH), changed)


def test_non_due_background_wake_shows_nothing_at_eleven() -> None:
    """Stray TemporalEvent at 11:00 CEST with only 09:00 enabled → no wake."""
    eleven = datetime(2026, 10, 23, 11, 0, 0, tzinfo=ZURICH)
    assert utc_offset_seconds(ZURICH, eleven) == 2 * 3600
    assert not should_request_wake(eleven, ONLY_NINE)
    assert not is_reminder_due(eleven, ONLY_NINE)
    # Still schedules tomorrow's real 09:00 if asked after a non-due event.
    nxt = compute_next_moment(eleven, ONLY_NINE)
    assert nxt == datetime(2026, 10, 24, 9, 0, 0, tzinfo=ZURICH)


def test_due_window_allows_few_minutes_late_but_not_hours() -> None:
    slot = ONLY_NINE
    assert should_request_wake(datetime(2026, 10, 23, 9, 0, 0, tzinfo=ZURICH), slot)
    assert should_request_wake(datetime(2026, 10, 23, 9, 10, 0, tzinfo=ZURICH), slot)
    assert should_request_wake(datetime(2026, 10, 23, 9, 15, 0, tzinfo=ZURICH), slot)
    assert not should_request_wake(datetime(2026, 10, 23, 9, 16, 0, tzinfo=ZURICH), slot)
    assert not should_request_wake(datetime(2026, 10, 23, 10, 7, 0, tzinfo=ZURICH), slot)


def test_app_start_midday_does_not_mark_due() -> None:
    """scheduleNext on app start / settings sync must not imply a wake."""
    midday = datetime(2026, 10, 23, 11, 0, 0, tzinfo=ZURICH)
    assert not should_request_wake(midday, ONLY_NINE)
    # Only reschedules the next real slot.
    assert compute_next_moment(midday, ONLY_NINE) == datetime(
        2026, 10, 24, 9, 0, 0, tzinfo=ZURICH
    )


def test_never_schedules_non_slot_catchup_far_from_hhmm() -> None:
    """If earliest legal is far past today's slot, roll to tomorrow — no fake time."""
    now = datetime(2026, 10, 23, 8, 50, 0, tzinfo=ZURICH)
    # Artificial last_temporal so earliest is 10:00 — far from 09:00 (>15 min).
    last = datetime(2026, 10, 23, 9, 55, 0, tzinfo=ZURICH)
    nxt = compute_next_moment(now, ONLY_NINE, last_temporal=last)
    # earliest = last+5 = 10:00; 09:00 today is before earliest by >15min → tomorrow
    # but tomorrow 09:00 is also before earliest 10:00 today... wait tomorrow is fine.
    assert nxt == datetime(2026, 10, 24, 9, 0, 0, tzinfo=ZURICH)
    assert nxt.hour == 9 and nxt.minute == 0
