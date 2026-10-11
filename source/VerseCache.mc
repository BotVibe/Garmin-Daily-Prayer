import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Persist today's verse to avoid repeated network use.
(:background)
module VerseCache {

    const KEY_DATE as String = "verseDate";
    const KEY_TEXT as String = "verseText";
    const KEY_REF as String = "verseRef";
    const KEY_CODE as String = "verseCode";
    const KEY_LANG as String = "verseLang";
    const KEY_SETTING as String = "verseSetting";

    function todayKey() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var y = info.year as Number;
        var m = info.month as Number;
        var d = info.day as Number;
        return Lang.format("$1$-$2$-$3$", [
            y.format("%04d"),
            m.format("%02d"),
            d.format("%02d")
        ]);
    }

    function clear() as Void {
        Storage.deleteValue(KEY_DATE);
        Storage.deleteValue(KEY_TEXT);
        Storage.deleteValue(KEY_REF);
        Storage.deleteValue(KEY_CODE);
        Storage.deleteValue(KEY_LANG);
        Storage.deleteValue(KEY_SETTING);
    }

    function save(text as String, reference as String, apiCode as String, langId as String, settingCode as String) as Void {
        Storage.setValue(KEY_DATE, todayKey());
        Storage.setValue(KEY_TEXT, text);
        Storage.setValue(KEY_REF, reference);
        Storage.setValue(KEY_CODE, apiCode);
        Storage.setValue(KEY_LANG, langId);
        Storage.setValue(KEY_SETTING, settingCode);
    }

    //! Returns Dictionary with text/ref/code/lang or null if missing/stale/mismatch.
    function loadIfFresh(langId as String, settingCode as String) as Dictionary? {
        var date = Storage.getValue(KEY_DATE);
        var text = Storage.getValue(KEY_TEXT);
        var reference = Storage.getValue(KEY_REF);
        var code = Storage.getValue(KEY_CODE);
        var lang = Storage.getValue(KEY_LANG);
        var setting = Storage.getValue(KEY_SETTING);

        if (!(date instanceof String) || !(text instanceof String) || !(reference instanceof String)
            || !(code instanceof String) || !(lang instanceof String) || !(setting instanceof String)) {
            return null;
        }
        if (!(date as String).equals(todayKey())) {
            return null;
        }
        if (!(lang as String).equals(langId)) {
            return null;
        }
        if (!(setting as String).equals(settingCode)) {
            return null;
        }

        return {
            "text" => text as String,
            "ref" => reference as String,
            "code" => code as String,
            "lang" => lang as String
        } as Dictionary;
    }

    //! Last cached verse regardless of day (offline fallback).
    function loadAny() as Dictionary? {
        var text = Storage.getValue(KEY_TEXT);
        var reference = Storage.getValue(KEY_REF);
        var code = Storage.getValue(KEY_CODE);
        if (!(text instanceof String) || !(reference instanceof String)) {
            return null;
        }
        var c = "—";
        if (code instanceof String) {
            c = code as String;
        }
        return {
            "text" => text as String,
            "ref" => reference as String,
            "code" => c,
            "stale" => true
        } as Dictionary;
    }
}
