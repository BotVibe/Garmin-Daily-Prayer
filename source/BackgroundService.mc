import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

//! Background entry: fire wake dialog at reminder times, then exit quickly.
(:background)
class BackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        // Always advance the schedule first so decline still gets the next slot.
        ReminderScheduler.scheduleNext();

        try {
            Background.requestApplicationWake("Spruch des Tages");
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
