import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

//! Background entry: at a due reminder TemporalEvent, ask to open the app; else idle.
//!
//! Does not fetch verses or touch the network. A TemporalEvent that is not near an
//! enabled slot (stray schedule, leftover after settings change, platform quirk)
//! only advances the schedule — never shows a wake dialog.
(:background)
class BackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        // Always advance the schedule first so decline / non-due still get the next slot.
        ReminderScheduler.scheduleNext();

        if (!ReminderScheduler.isReminderDueNow()) {
            // Not at an enabled reminder HH:MM — no user-visible alert.
            Background.exit(null);
            return;
        }

        try {
            // Resources are unavailable in the background process, so the app name
            // is inlined here. Keep it in sync with @Strings.AppName.
            Background.requestApplicationWake("Daily Verse");
        } catch (e) {
            // ignore — still exit cleanly
        }

        // Flag for foreground: opened via reminder accept
        try {
            Application.Storage.setValue("openedFromReminder", true);
        } catch (e2) {
        }

        Background.exit(null);
    }
}
