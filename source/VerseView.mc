import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Primary screen: loading / verse / error. Back dismisses to watch face.
//! Tap / Select keep the screen lit (backlight poke) and do not exit.
class VerseView extends WatchUi.View {

    private var _forceRefresh as Boolean;
    private var _status as String = "";
    private var _verseText as String = "";
    private var _reference as String = "";
    private var _version as String = "";
    private var _loading as Boolean = true;
    private var _error as Boolean = false;
    private var _request as VerseApi.Request?;
    private var _fromCache as Boolean = false;
    private var _backlightTimer as Timer.Timer?;
    private var _backlightTicks as Number = 0;

    //! Re-poke interval while reading. OLED burn-in protection typically
    //! rejects holding the backlight past ~1 minute of continuous requests.
    private const BACKLIGHT_INTERVAL_MS as Number = 10000;
    private const BACKLIGHT_MAX_TICKS as Number = 4;

    function initialize(forceRefresh as Boolean) {
        View.initialize();
        _forceRefresh = forceRefresh;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        setLayout(Rez.Layouts.VerseLayout(dc));
    }

    function onShow() as Void {
        loadVerse(_forceRefresh);
        _forceRefresh = false;
        // Clear reminder flag if present
        try {
            Application.Storage.deleteValue("openedFromReminder");
        } catch (e) {
        }
        pokeBacklight();
        startBacklightTimer();
    }

    function onHide() as Void {
        stopBacklightTimer();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var status = findDrawableById("statusLabel") as WatchUi.Text?;
        var verse = findDrawableById("verseText") as WatchUi.TextArea?;
        var ref = findDrawableById("refLabel") as WatchUi.TextArea?;
        var ver = findDrawableById("versionLabel") as WatchUi.Text?;

        if (status != null) {
            if (_loading) {
                status.setText(WatchUi.loadResource(Rez.Strings.Loading) as String);
            } else if (_fromCache && !_error) {
                status.setText(WatchUi.loadResource(Rez.Strings.OfflineCache) as String);
            } else {
                status.setText("");
            }
        }

        if (verse != null) {
            if (_loading) {
                verse.setText("");
            } else if (_error) {
                verse.setText(_status);
            } else {
                verse.setText(_verseText);
            }
        }

        if (ref != null) {
            ref.setText(_error || _loading ? "" : _reference);
        }
        if (ver != null) {
            ver.setText(_error || _loading ? "" : _version);
        }

        View.onUpdate(dc);
    }

    function scrollBy(delta as Number) as Void {
        WatchUi.requestUpdate();
    }

    function refresh() as Void {
        loadVerse(true);
    }

    //! Keep the display lit / reset the system backlight dim timer.
    //! Safe no-op when Attention.backlight is missing or the OLED hold limit trips.
    function pokeBacklight() as Void {
        if (!(Attention has :backlight)) {
            return;
        }
        try {
            // API 4.0+ devices accept Float brightness; 1.0 = brightest allowed.
            Attention.backlight(1.0);
        } catch (e) {
            try {
                Attention.backlight(true);
            } catch (e2) {
                // BacklightOnTooLongException / unsupported — stop auto-repeat
                stopBacklightTimer();
            }
        }
    }

    function onBacklightTimer() as Void {
        _backlightTicks += 1;
        if (_backlightTicks > BACKLIGHT_MAX_TICKS) {
            stopBacklightTimer();
            return;
        }
        pokeBacklight();
    }

    private function startBacklightTimer() as Void {
        stopBacklightTimer();
        _backlightTicks = 0;
        var timer = new Timer.Timer();
        _backlightTimer = timer;
        timer.start(method(:onBacklightTimer), BACKLIGHT_INTERVAL_MS, true);
    }

    private function stopBacklightTimer() as Void {
        if (_backlightTimer != null) {
            try {
                (_backlightTimer as Timer.Timer).stop();
            } catch (e) {
            }
            _backlightTimer = null;
        }
        _backlightTicks = 0;
    }

    private function loadVerse(force as Boolean) as Void {
        _loading = true;
        _error = false;
        _fromCache = false;
        _status = "";
        WatchUi.requestUpdate();

        var langId = AppConfig.getLanguageId();
        var settingCode = AppConfig.getTranslationCode();

        if (!force) {
            var cached = VerseCache.loadIfFresh(langId, settingCode);
            if (cached != null) {
                applyVerse(
                    cached["text"] as String,
                    cached["ref"] as String,
                    cached["code"] as String,
                    false
                );
                return;
            }
        } else {
            VerseCache.clear();
        }

        _request = new VerseApi.Request(langId, settingCode, method(:onVerseResult));
        (_request as VerseApi.Request).start();
    }

    function onVerseResult(success as Boolean, text as String?, reference as String?, apiCode as String?, error as String?) as Void {
        if (success && text != null && reference != null && apiCode != null) {
            applyVerse(text as String, reference as String, apiCode as String, false);
            return;
        }

        var fallback = VerseCache.loadAny();
        if (fallback != null) {
            applyVerse(
                fallback["text"] as String,
                fallback["ref"] as String,
                fallback["code"] as String,
                true
            );
            return;
        }

        _loading = false;
        _error = true;
        if (error != null && (error as String).equals("no_phone")) {
            _status = WatchUi.loadResource(Rez.Strings.ErrorNoPhone) as String;
        } else {
            _status = WatchUi.loadResource(Rez.Strings.ErrorFetch) as String;
        }
        _status += "\n" + (WatchUi.loadResource(Rez.Strings.RetryHint) as String);
        WatchUi.requestUpdate();
    }

    private function applyVerse(text as String, reference as String, apiCode as String, stale as Boolean) as Void {
        _loading = false;
        _error = false;
        _fromCache = stale;
        _verseText = text;
        _reference = reference;
        _version = Translations.codeDisplayName(apiCode);
        WatchUi.requestUpdate();
    }
}

class VerseDelegate extends WatchUi.BehaviorDelegate {

    private var _view as VerseView?;

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function setView(view as VerseView) as Void {
        _view = view;
    }

    function onBack() as Boolean {
        dismiss();
        return true;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new SettingsMainMenu(), new SettingsMainDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

    //! Select / touch must not exit — only reset the backlight dim timer.
    function onSelect() as Boolean {
        keepLit();
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        keepLit();
        return true;
    }

    private function keepLit() as Void {
        if (_view != null) {
            (_view as VerseView).pokeBacklight();
        }
    }

    //! Back leaves the verse (and the app) so the watch returns to its watch face.
    private function dismiss() as Void {
        System.exit();
    }

    function onNextPage() as Boolean {
        if (_view != null) {
            (_view as VerseView).scrollBy(1);
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_view != null) {
            (_view as VerseView).scrollBy(-1);
        }
        return true;
    }
}
