import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Primary screen: loading / verse / error. Back dismisses to watch face.
//! Tap / Select keep the screen lit (backlight poke) and do not exit.
//! Long verses that do not fit scroll; short verses keep the fixed layout.
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

    private var _scrollable as Boolean = false;
    private var _scrollOffset as Number = 0;
    private var _scrollLines as Array<String>?;
    private var _refLineStart as Number = 0;
    private var _visibleLines as Number = 0;
    //! Fixed font for scroll mode (readable; short verses keep the TextArea ladder).
    private const SCROLL_FONT as Graphics.FontDefinition = Graphics.FONT_TINY;

    //! Re-poke interval while reading. OLED burn-in protection typically
    //! rejects holding the backlight past ~1 minute of continuous requests.
    private const BACKLIGHT_INTERVAL_MS as Number = 10000;
    private const BACKLIGHT_MAX_TICKS as Number = 4;

    //! Gold used for the Bible reference (matches layout color 0xC8A060).
    private const REF_COLOR as Number = 0xC8A060;

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

        var useScroll = false;
        if (!_loading && !_error && verse != null && ref != null) {
            useScroll = !verseFitsInArea(dc, _verseText, verse.width, verse.height);
        }
        _scrollable = useScroll;

        if (useScroll && verse != null && ref != null) {
            verse.setVisible(false);
            ref.setVisible(false);
            if (ver != null) {
                ver.setText(_version);
            }
            rebuildScrollLines(dc, verse.width);
            View.onUpdate(dc);
            drawScrollContent(dc, verse, ref, ver);
            return;
        }

        if (verse != null) {
            verse.setVisible(true);
            if (_loading) {
                verse.setText("");
            } else if (_error) {
                verse.setText(_status);
            } else {
                verse.setText(_verseText);
            }
        }

        if (ref != null) {
            ref.setVisible(true);
            ref.setText(_error || _loading ? "" : _reference);
        }
        if (ver != null) {
            ver.setText(_error || _loading ? "" : _version);
        }

        _scrollLines = null;
        _scrollOffset = 0;
        _visibleLines = 0;
        View.onUpdate(dc);
    }

    //! Scroll by one page (delta +1 = next / down content, -1 = previous).
    //! No-op when the verse fits on one screen.
    function scrollBy(delta as Number) as Void {
        if (!_scrollable || _scrollLines == null) {
            return;
        }
        var lines = _scrollLines as Array<String>;
        var step = VerseScroll.pageDelta(_visibleLines);
        _scrollOffset = VerseScroll.clampOffset(
            _scrollOffset + (delta * step),
            lines.size(),
            _visibleLines
        );
        pokeBacklight();
        WatchUi.requestUpdate();
    }

    function refresh() as Void {
        loadVerse(true);
    }

    //! Keep the display lit / reset the system backlight dim timer at the
    //! user's system brightness. Boolean true = system level (never raises
    //! above the watch setting). Float brightness is intentionally unused.
    //! Safe no-op when Attention.backlight is missing or the OLED hold limit trips.
    function pokeBacklight() as Void {
        if (!(Attention has :backlight)) {
            return;
        }
        try {
            Attention.backlight(true);
        } catch (e) {
            // BacklightOnTooLongException / unsupported — stop auto-repeat
            stopBacklightTimer();
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

    //! Whether the verse fits the fixed TextArea at the smallest ladder font.
    private function verseFitsInArea(
        dc as Graphics.Dc,
        text as String,
        areaWidth as Numeric,
        areaHeight as Numeric
    ) as Boolean {
        var w = areaWidth.toNumber();
        var h = areaHeight.toNumber();
        if (w <= 0 || h <= 0 || text.length() == 0) {
            return true;
        }
        var font = Graphics.FONT_XTINY;
        var lineH = dc.getFontHeight(font);
        var wrapped = wrapText(dc, text, font, w);
        return !VerseScroll.needsScroll(wrapped.size(), lineH, h);
    }

    private function rebuildScrollLines(dc as Graphics.Dc, areaWidth as Numeric) as Void {
        var w = areaWidth.toNumber();
        var font = SCROLL_FONT;
        var verseLines = wrapText(dc, _verseText, font, w);
        var refLines = wrapText(dc, _reference, font, w);
        var lines = [] as Array<String>;
        var i;
        for (i = 0; i < verseLines.size(); i++) {
            lines.add(verseLines[i] as String);
        }
        var refStart = lines.size();
        if (refLines.size() > 0) {
            lines.add("");
            refStart = lines.size();
            for (i = 0; i < refLines.size(); i++) {
                lines.add(refLines[i] as String);
            }
        }
        _scrollLines = lines;
        _refLineStart = refStart;
        _scrollOffset = VerseScroll.clampOffset(_scrollOffset, lines.size(), _visibleLines);
    }

    private function drawScrollContent(
        dc as Graphics.Dc,
        verse as WatchUi.TextArea,
        ref as WatchUi.TextArea,
        ver as WatchUi.Text?
    ) as Void {
        if (_scrollLines == null) {
            return;
        }
        var lines = _scrollLines as Array<String>;
        var font = SCROLL_FONT;
        var lineH = dc.getFontHeight(font);
        if (lineH <= 0) {
            return;
        }

        var x = verse.locX.toNumber();
        var y = verse.locY.toNumber();
        var w = verse.width.toNumber();
        var bottom;
        if (ver != null) {
            bottom = ver.locY.toNumber() - 4;
        } else {
            bottom = y + verse.height.toNumber() + ref.height.toNumber();
        }
        var areaH = bottom - y;
        if (areaH < lineH) {
            areaH = lineH;
        }

        // Leave a few pixels for the "more below" chevron.
        var hintH = 10;
        var textH = areaH - hintH;
        if (textH < lineH) {
            textH = areaH;
            hintH = 0;
        }
        _visibleLines = textH / lineH;
        if (_visibleLines < 1) {
            _visibleLines = 1;
        }
        _scrollOffset = VerseScroll.clampOffset(_scrollOffset, lines.size(), _visibleLines);

        var cx = x + (w / 2);
        var drawY = y;
        var end = _scrollOffset + _visibleLines;
        if (end > lines.size()) {
            end = lines.size();
        }
        var idx;
        for (idx = _scrollOffset; idx < end; idx++) {
            var line = lines[idx] as String;
            if (line.length() > 0) {
                if (idx >= _refLineStart) {
                    dc.setColor(REF_COLOR, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                }
                dc.drawText(
                    cx,
                    drawY,
                    font,
                    line,
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
            drawY += lineH;
        }

        if (hintH > 0 && VerseScroll.moreBelow(_scrollOffset, lines.size(), _visibleLines)) {
            drawMoreBelowHint(dc, cx, bottom - 2);
        }
    }

    //! Subtle chevron: more text is below the fold.
    private function drawMoreBelowHint(dc as Graphics.Dc, cx as Number, y as Number) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 5, y - 6, cx, y);
        dc.drawLine(cx, y, cx + 5, y - 6);
    }

    //! Word-wrap ``text`` to ``maxWidth`` pixels for ``font``.
    private function wrapText(
        dc as Graphics.Dc,
        text as String,
        font as Graphics.FontDefinition,
        maxWidth as Number
    ) as Array<String> {
        var lines = [] as Array<String>;
        if (text.length() == 0) {
            return lines;
        }

        var wordStart = 0;
        var current = "";
        var i;
        var len = text.length();
        for (i = 0; i <= len; i++) {
            var atEnd = i >= len;
            var ch = atEnd ? "" : text.substring(i, i + 1);
            var isBreak = atEnd || ch.equals(" ") || ch.equals("\n");
            if (!isBreak) {
                continue;
            }
            if (i > wordStart) {
                var word = text.substring(wordStart, i);
                var trial = current.length() == 0 ? word : (current + " " + word);
                if (dc.getTextWidthInPixels(trial, font) <= maxWidth) {
                    current = trial;
                } else {
                    if (current.length() > 0) {
                        lines.add(current);
                    }
                    current = word;
                }
            }
            if (ch.equals("\n")) {
                lines.add(current);
                current = "";
            }
            wordStart = i + 1;
        }
        if (current.length() > 0 || lines.size() == 0) {
            lines.add(current);
        }
        return lines;
    }

    private function loadVerse(force as Boolean) as Void {
        _loading = true;
        _error = false;
        _fromCache = false;
        _status = "";
        _scrollable = false;
        _scrollOffset = 0;
        _scrollLines = null;
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
        _version = translationName(apiCode);
        _scrollOffset = 0;
        _scrollLines = null;
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

    //! Down button / swipe up → next page of a long verse.
    function onNextPage() as Boolean {
        if (_view != null) {
            (_view as VerseView).scrollBy(1);
        }
        return true;
    }

    //! Up button / swipe down → previous page of a long verse.
    function onPreviousPage() as Boolean {
        if (_view != null) {
            (_view as VerseView).scrollBy(-1);
        }
        return true;
    }
}
