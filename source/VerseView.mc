import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Primary screen: loading / verse / error. Back dismisses to watch face.
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
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var status = findDrawableById("statusLabel") as WatchUi.Text?;
        var verse = findDrawableById("verseText") as WatchUi.TextArea?;
        var ref = findDrawableById("refLabel") as WatchUi.Text?;
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

    function onSelect() as Boolean {
        dismiss();
        return true;
    }

    //! Both back and select leave the verse, which means leaving the app so the
    //! watch returns to its watch face instead of idling in the app.
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
