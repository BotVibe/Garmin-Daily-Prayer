import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Schedules a single TemporalEvent at the next enabled reminder slot.
//!
//! Reminder times are wall-clock local time on the watch (Gregorian.info /
//! System.getClockTime, including the device UTC offset and DST).
//! Do not feed local hour/minute into Gregorian's UTC moment factory.
(:background)
module ReminderScheduler {

    const MIN_LEAD_SECONDS as Number = 5 * 60;
    const PASSED_GRACE_SECONDS as Number = 30;

    //! Register the next wake Moment. Safe to call from app or background.
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
            // Device may reject too-soon events (5 min since last run); retry at earliest legal time
            var later = new Time.Moment(earliestLegalSeconds());
            try {
                Background.registerForTemporalEvent(later);
            } catch (e2) {
                // give up silently — will retry on next app start
            }
        }
    }

    //! Earliest future Moment among enabled slots (today or tomorrow), in local wall time.
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
            var candidate = momentForLocalClock(hour, minute, 0);
            if (candidate.value() <= nowValue + PASSED_GRACE_SECONDS) {
                // Already passed (or within grace) → same clock time tomorrow
                candidate = momentForLocalClock(hour, minute, 1);
            }
            // Garmin: at most one temporal event every 5 minutes (from now and last run)
            if (candidate.value() < earliest) {
                candidate = new Time.Moment(earliest);
            }
            if (best == null || candidate.value() < (best as Time.Moment).value()) {
                best = candidate;
            }
        }
        return best;
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
    //! Exposed for tests / diagnostics; scheduling uses momentForLocalClock instead.
    function currentUtcOffsetSeconds() as Number {
        var clock = System.getClockTime();
        return clock.timeZoneOffset + clock.dst;
    }
}
