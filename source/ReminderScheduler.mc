import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Schedules a single TemporalEvent at the next enabled reminder slot.
(:background)
module ReminderScheduler {

    //! Register the next wake Moment. Safe to call from app or background.
    function scheduleNext() as Void {
        if (!System has :ServiceDelegate) {
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
            // Device may reject too-soon events; try +5 minutes
            var later = new Time.Moment(Time.now().value() + 5 * 60);
            try {
                Background.registerForTemporalEvent(later);
            } catch (e2) {
                // give up silently — will retry on next app start
            }
        }
    }

    //! Earliest future Moment among enabled slots (today or tomorrow).
    function computeNextMoment() as Time.Moment? {
        var now = Time.now();
        var nowValue = now.value();
        var best = null as Time.Moment?;

        for (var slot = 1; slot <= 3; slot++) {
            if (!AppConfig.isSlotEnabled(slot)) {
                continue;
            }
            var hour = AppConfig.getSlotHour(slot);
            var minute = AppConfig.getSlotMinute(slot);
            var candidate = momentForToday(hour, minute);
            if (candidate.value() <= nowValue + 30) {
                // Already passed (or within 30s) → tomorrow
                candidate = new Time.Moment(candidate.value() + (24 * 60 * 60));
            }
            // Enforce Garmin 5-minute minimum from now
            if (candidate.value() < nowValue + 5 * 60) {
                candidate = new Time.Moment(nowValue + 5 * 60);
            }
            if (best == null || candidate.value() < (best as Time.Moment).value()) {
                best = candidate;
            }
        }
        return best;
    }

    function momentForToday(hour as Number, minute as Number) as Time.Moment {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var options = {
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => hour,
            :minute => minute,
            :second => 0
        };
        return Gregorian.moment(options);
    }
}
