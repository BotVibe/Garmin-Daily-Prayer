import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

//! Thin accessors for Properties used by foreground and background.
(:background)
module AppConfig {

    const KEY_LANGUAGE as String = "languageIndex";
    const KEY_TRANSLATION as String = "translationIndex";
    //! Read-only display value in Garmin Connect; DailyVerseApp keeps it equal
    //! to the packaged AppVersion string (foreground only).
    const KEY_APP_VERSION as String = "appVersion";

    const DEFAULT_LANGUAGE_ID as String = "de";
    const DEFAULT_TRANSLATION_CODE as String = "lut";

    function getLanguageId() as String {
        var v = Application.Properties.getValue(KEY_LANGUAGE);
        if (v instanceof Number) {
            return Translations.languageIdForIndex(v as Number);
        }
        return DEFAULT_LANGUAGE_ID;
    }

    function setLanguageId(langId as String) as Void {
        Application.Properties.setValue(KEY_LANGUAGE, Translations.indexForLanguageId(langId));
        // Keep translation valid for the new language
        var code = getTranslationCode();
        if (!code.equals(Translations.RANDOM_CODE) && !Translations.isCodeInLanguage(langId, code)) {
            setTranslationCode(Translations.defaultCode(langId));
        }
    }

    function getTranslationCode() as String {
        var langId = getLanguageId();
        var v = Application.Properties.getValue(KEY_TRANSLATION);
        var code = DEFAULT_TRANSLATION_CODE;
        if (v instanceof Number) {
            code = Translations.settingCodeForIndex(v as Number);
        }
        // On-device menus only offer codes for the selected language. Connect
        // Mobile lists every catalog code, so a stale pair can still be stored;
        // treat that as the language default until normalize() persists a fix.
        if (code.equals(Translations.RANDOM_CODE)) {
            return code;
        }
        if (!Translations.isCodeInLanguage(langId, code)) {
            return Translations.defaultCode(langId);
        }
        return code;
    }

    function setTranslationCode(code as String) as Void {
        Application.Properties.setValue(KEY_TRANSLATION, Translations.indexForSettingCode(code));
    }

    //! Garmin Connect lets language and translation be picked independently, so a
    //! mismatched pair can arrive from the phone. Pull it back to a valid pair
    //! and persist the fallback (language default, never a foreign code).
    function normalize() as Void {
        var langId = getLanguageId();
        var v = Application.Properties.getValue(KEY_TRANSLATION);
        var stored = DEFAULT_TRANSLATION_CODE;
        if (v instanceof Number) {
            stored = Translations.settingCodeForIndex(v as Number);
        }
        if (stored.equals(Translations.RANDOM_CODE)) {
            return;
        }
        if (!Translations.isCodeInLanguage(langId, stored)) {
            setTranslationCode(Translations.defaultCode(langId));
        }
    }

    function isSlotEnabled(slot as Number) as Boolean {
        var key = "slot" + slot.toString() + "Enabled";
        var v = Application.Properties.getValue(key);
        if (v instanceof Boolean) {
            return v as Boolean;
        }
        return false;
    }

    function setSlotEnabled(slot as Number, enabled as Boolean) as Void {
        var key = "slot" + slot.toString() + "Enabled";
        Application.Properties.setValue(key, enabled);
    }

    function getSlotHour(slot as Number) as Number {
        var key = "slot" + slot.toString() + "Hour";
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            var n = v as Number;
            if (n < 0) {
                return 0;
            }
            if (n > 23) {
                return 23;
            }
            return n;
        }
        return 8;
    }

    function setSlotHour(slot as Number, hour as Number) as Void {
        var key = "slot" + slot.toString() + "Hour";
        Application.Properties.setValue(key, hour);
    }

    function getSlotMinute(slot as Number) as Number {
        var key = "slot" + slot.toString() + "Minute";
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            var n = v as Number;
            if (n < 0) {
                return 0;
            }
            if (n > 59) {
                return 59;
            }
            return n;
        }
        return 0;
    }

    function setSlotMinute(slot as Number, minute as Number) as Void {
        var key = "slot" + slot.toString() + "Minute";
        Application.Properties.setValue(key, minute);
    }

    function formatSlotTime(slot as Number) as String {
        var h = getSlotHour(slot);
        var m = getSlotMinute(slot);
        return h.format("%02d") + ":" + m.format("%02d");
    }
}
