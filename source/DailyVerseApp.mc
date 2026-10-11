import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Connect IQ watch-app entry point.
class DailyVerseApp extends Application.AppBase {

    private var _inBackground as Boolean = false;
    private var _verseView as VerseView?;

    function initialize() {
        AppBase.initialize();
    }

    function getVerseView() as VerseView? {
        return _verseView;
    }

    function onStart(state as Dictionary?) as Void {
        // Reschedule whenever the app (or background) starts.
        if (!_inBackground) {
            ReminderScheduler.scheduleNext();
        }
    }

    function onStop(state as Dictionary?) as Void {
        if (!_inBackground) {
            ReminderScheduler.scheduleNext();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new VerseView(false);
        _verseView = view;
        var delegate = new VerseDelegate();
        delegate.setView(view);
        return [view, delegate] as [Views, InputDelegates];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        _inBackground = true;
        return [new BackgroundService()] as [System.ServiceDelegate];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        ReminderScheduler.scheduleNext();
    }

    function onSettingsChanged() as Void {
        ReminderScheduler.scheduleNext();
        WatchUi.requestUpdate();
    }
}

function getApp() as DailyVerseApp {
    return Application.getApp() as DailyVerseApp;
}
