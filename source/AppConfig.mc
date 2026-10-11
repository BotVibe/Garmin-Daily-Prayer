import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

//! Thin accessors for Properties used by foreground and background.
(:background)
module AppConfig {

    function getLanguageId() as String {
        var v = Application.Properties.getValue("languageId");
        if (v instanceof String) {
            return v as String;
        }
        return "de";
    }

    function setLanguageId(langId as String) as Void {
        Application.Properties.setValue("languageId", langId);
        // Keep translation valid for the new language
        var code = getTranslationCode();
        if (!code.equals(Translations.RANDOM_CODE)) {
            var codes = Translations.codesForLanguage(langId);
            var ok = false;
            for (var i = 0; i < codes.size(); i++) {
                if ((codes[i] as String).equals(code)) {
                    ok = true;
                    break;
                }
            }
            if (!ok) {
                setTranslationCode(Translations.defaultCode(langId));
            }
        }
    }

    function getTranslationCode() as String {
        var v = Application.Properties.getValue("translationCode");
        if (v instanceof String) {
            return v as String;
        }
        return "lut";
    }

    function setTranslationCode(code as String) as Void {
        Application.Properties.setValue("translationCode", code);
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
