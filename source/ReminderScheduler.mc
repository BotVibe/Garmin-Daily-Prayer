import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Schedules a single TemporalEvent at the next enabled reminder slot.
//!
//! Guarantees (best-effort within Connect IQ limits):
//! - Only *enabled* slots are scheduled; disabled hour/minute values are ignored.
//! - Each active slot fires at most once per local calendar day at its HH:MM
//!   (watch local clock / time zone / DST).
//! - Temporal events that are not near an enabled slot never show a wake dialog
//!   (`isReminderDueNow`); see BackgroundService.
//! - Never register a non-slot "catch-up" Moment just to satisfy the 5-minute rule.
//!
//! Platform precision: Garmin allows at most one temporal event every 5 minutes
//! (`now` and `getLastTemporalEventTime`). Delivery may therefore be up to about
//! 5 minutes after the configured minute, plus ordinary OS wake latency. We do
//! not invent extra alerts to "make up" for a missed window.
(:background)
module ReminderScheduler {

    const MIN_LEAD_SECONDS as Number = 5 * 60;
    const PASSED_GRACE_SECONDS as Number = 30;
    //! How late a temporal wake may still count as that slot (covers 5-min rule + OS lag).
    const DUE_WINDOW_SECONDS as Number = 15 * 60;

    //! Register the next wake Moment. Safe to call from app or background.
    //! Replaces any previous temporal event. Never registers a non-slot time.
    function scheduleNext() as Void {
        if (!(System has :ServiceDelegate)) {
            return;
        }

        var next = computeNextMoment();
        if (next == null) {
            try {
                Background.deleteTemporalEvent();
            } catch (e) {
                // ignore if none registered
            }
            return;
        }

        try {
            Background.registerForTemporalEvent(next);
        } catch (e) {
            // Too soon / rejected. Do NOT fall back to "now+5min" — that would
            // wake the user at a time that is not a configured reminder.
            // App start / settings change will retry when legal.
        }
    }

    //! Earliest future Moment among enabled slots (today or tomorrow), local wall time.
    function computeNextMoment() as Time.Moment? {
        var nowValue = Time.now().value();
        var best = null as Time.Moment?;
        var earliest = earliestLegalSeconds();

        for (var slot = 1; slot <= 3; slot++) {
            if (!AppConfig.isSlotEnabled(slot)) {
                continue;
            }
            var hour = AppConfig.getSlotHour(slot);
            var minute = AppConfig.getSlotMinute(slot);
            var today = momentForLocalClock(hour, minute, 0);
            var tomorrow = momentForLocalClock(hour, minute, 1);
            var candidate = today;

            if (today.value() <= nowValue + PASSED_GRACE_SECONDS) {
                candidate = tomorrow;
            } else if (today.value() < earliest) {
                // Slot is still ahead but too soon to register. Deliver a few
                // minutes late only if still inside the due window; otherwise
                // skip to tomorrow (no mid-day catch-up alert).
                if ((earliest - today.value()) <= DUE_WINDOW_SECONDS) {
                    candidate = new Time.Moment(earliest);
                } else {
                    candidate = tomorrow;
                }
            }

            if (candidate.value() < earliest) {
                // Tomorrow (or late delivery) still illegal — skip this slot.
                continue;
            }
            if (best == null || candidate.value() < (best as Time.Moment).value()) {
                best = candidate;
            }
        }
        return best;
    }

    //! True when local wall time is within DUE_WINDOW of an *enabled* slot.
    //! Used so a stray / leftover TemporalEvent never shows a wake dialog.
    function isReminderDueNow() as Boolean {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var nowMinutes = ((info.hour as Number) * 60) + (info.min as Number);
        var windowMinutes = DUE_WINDOW_SECONDS / 60;

        for (var slot = 1; slot <= 3; slot++) {
            if (!AppConfig.isSlotEnabled(slot)) {
                continue;
            }
            var slotMinutes = (AppConfig.getSlotHour(slot) * 60) + AppConfig.getSlotMinute(slot);
            var delta = nowMinutes - slotMinutes;
            if (delta < 0) {
                delta = -delta;
            }
            // Wrap around midnight (e.g. slot 23:58, now 00:02).
            var wrap = (24 * 60) - delta;
            var nearest = delta;
            if (wrap < nearest) {
                nearest = wrap;
            }
            if (nearest <= windowMinutes) {
                return true;
            }
        }
        return false;
    }

    //! Earliest Unix second at which the platform will accept a new TemporalEvent.
    function earliestLegalSeconds() as Number {
        var nowValue = Time.now().value();
        var earliest = nowValue + MIN_LEAD_SECONDS;
        if (Background has :getLastTemporalEventTime) {
            var last = Background.getLastTemporalEventTime();
            if (last != null) {
                var afterLast = (last as Time.Moment).value() + MIN_LEAD_SECONDS;
                if (afterLast > earliest) {
                    earliest = afterLast;
                }
            }
        }
        return earliest;
    }

    //! Moment for today's (dayOffset=0) or tomorrow's (dayOffset=1) local HH:MM.
    //!
    //! Built from local midnight derived via Gregorian.info (device local clock),
    //! not the UTC-based Gregorian moment factory. Across a DST transition,
    //! tomorrow is approximately +24h from local midnight (platform limitation
    //! without a location-based LocalMoment).
    function momentForLocalClock(hour as Number, minute as Number, dayOffset as Number) as Time.Moment {
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var secondsFromMidnight = ((info.hour as Number) * Gregorian.SECONDS_PER_HOUR)
            + ((info.min as Number) * Gregorian.SECONDS_PER_MINUTE)
            + (info.sec as Number);
        var localMidnight = now.value() - secondsFromMidnight;
        var target = localMidnight
            + (dayOffset * Gregorian.SECONDS_PER_DAY)
            + (hour * Gregorian.SECONDS_PER_HOUR)
            + (minute * Gregorian.SECONDS_PER_MINUTE);
        return new Time.Moment(target);
    }

    //! UTC offset currently in effect on the watch (time zone + DST), seconds east of UTC.
    function currentUtcOffsetSeconds() as Number {
        var clock = System.getClockTime();
        return clock.timeZoneOffset + clock.dst;
    }
}
