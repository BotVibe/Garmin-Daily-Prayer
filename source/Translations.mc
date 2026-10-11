import Toybox.Lang;

//! DailyVerses.net language → translation code catalog.
//! Codes match https://dailyverses.net/get/verse?language=<code>
(:background)
module Translations {

    const RANDOM_CODE as String = "random";

    //! Ordered language ids for menus.
    function languageIds() as Array<String> {
        return [
            "af", "ar", "bn", "zh", "cs", "da", "de", "en", "es", "fa",
            "fi", "fr", "el", "hi", "hu", "it", "mg", "nl", "no", "pl",
            "pt", "ru", "sk", "st", "sv", "ur", "xh", "zu"
        ] as Array<String>;
    }

    //! Human-readable language label key fragment (Lang_<id>).
    function languageLabel(langId as String) as String {
        return langId;
    }

    //! Garmin Connect settings only support numeric list entries, so language and
    //! translation are persisted as catalog positions. The order below is append-only:
    //! inserting in the middle would re-interpret values already stored on a watch.

    function languageIdForIndex(index as Number) as String {
        var ids = languageIds();
        if (index < 0 || index >= ids.size()) {
            return "de";
        }
        return ids[index] as String;
    }

    function indexForLanguageId(langId as String) as Number {
        var ids = languageIds();
        for (var i = 0; i < ids.size(); i++) {
            if ((ids[i] as String).equals(langId)) {
                return i;
            }
        }
        return indexForLanguageId("de");
    }

    //! Settings index 0 is "random"; 1..n walk the catalog in languageIds() order.
    function settingCodeForIndex(index as Number) as String {
        if (index <= 0) {
            return RANDOM_CODE;
        }
        var remaining = index - 1;
        var ids = languageIds();
        for (var i = 0; i < ids.size(); i++) {
            var codes = codesForLanguage(ids[i] as String);
            if (remaining < codes.size()) {
                return codes[remaining] as String;
            }
            remaining -= codes.size();
        }
        return RANDOM_CODE;
    }

    function indexForSettingCode(code as String) as Number {
        if (code.equals(RANDOM_CODE)) {
            return 0;
        }
        var offset = 1;
        var ids = languageIds();
        for (var i = 0; i < ids.size(); i++) {
            var codes = codesForLanguage(ids[i] as String);
            for (var j = 0; j < codes.size(); j++) {
                if ((codes[j] as String).equals(code)) {
                    return offset + j;
                }
            }
            offset += codes.size();
        }
        return 0;
    }

    //! True when the code belongs to the language (never true for "random").
    function isCodeInLanguage(langId as String, code as String) as Boolean {
        var codes = codesForLanguage(langId);
        for (var i = 0; i < codes.size(); i++) {
            if ((codes[i] as String).equals(code)) {
                return true;
            }
        }
        return false;
    }

    //! Translation codes available for a language (never includes "random").
    function codesForLanguage(langId as String) as Array<String> {
        if (langId.equals("af")) {
            return ["afr53"] as Array<String>;
        } else if (langId.equals("ar")) {
            return ["avd", "keh"] as Array<String>;
        } else if (langId.equals("bn")) {
            return ["rovu"] as Array<String>;
        } else if (langId.equals("zh")) {
            return ["cuv", "cuvs"] as Array<String>;
        } else if (langId.equals("cs")) {
            return ["b21", "cep"] as Array<String>;
        } else if (langId.equals("da")) {
            return ["bdan", "da1871"] as Array<String>;
        } else if (langId.equals("de")) {
            return ["elb", "lu12", "lut", "neu"] as Array<String>;
        } else if (langId.equals("en")) {
            return ["esv", "kjv", "nasb", "ncb", "niv", "nkjv", "nlt", "nrsv", "web"] as Array<String>;
        } else if (langId.equals("es")) {
            return ["lbla", "nvi", "rvr60", "rvr95"] as Array<String>;
        } else if (langId.equals("fa")) {
            return ["pcb"] as Array<String>;
        } else if (langId.equals("fi")) {
            return ["kr38", "kr92"] as Array<String>;
        } else if (langId.equals("fr")) {
            return ["bds", "neg79", "sg21"] as Array<String>;
        } else if (langId.equals("el")) {
            return ["tgv"] as Array<String>;
        } else if (langId.equals("hi")) {
            return ["hhbd"] as Array<String>;
        } else if (langId.equals("hu")) {
            return ["uf"] as Array<String>;
        } else if (langId.equals("it")) {
            return ["cei", "lnd", "nr06"] as Array<String>;
        } else if (langId.equals("mg")) {
            return ["mg1865"] as Array<String>;
        } else if (langId.equals("nl")) {
            return ["bb", "bgt", "hsv", "nbg", "nbv"] as Array<String>;
        } else if (langId.equals("no")) {
            return ["b2024"] as Array<String>;
        } else if (langId.equals("pl")) {
            return ["bw1975", "ubg"] as Array<String>;
        } else if (langId.equals("pt")) {
            return ["ara", "arc", "nvi_pt"] as Array<String>;
        } else if (langId.equals("ru")) {
            return ["rst"] as Array<String>;
        } else if (langId.equals("sk")) {
            return ["kat"] as Array<String>;
        } else if (langId.equals("st")) {
            return ["sso89"] as Array<String>;
        } else if (langId.equals("sv")) {
            return ["b2000"] as Array<String>;
        } else if (langId.equals("ur")) {
            return ["urd"] as Array<String>;
        } else if (langId.equals("xh")) {
            return ["xho96"] as Array<String>;
        } else if (langId.equals("zu")) {
            return ["zul59"] as Array<String>;
        }
        return ["niv"] as Array<String>;
    }

    //! Display name for a translation code.
    function codeDisplayName(code as String) as String {
        if (code.equals(RANDOM_CODE)) {
            return "random";
        }
        // Uppercase common forms; special-case NeÜ
        if (code.equals("neu")) {
            return "NeÜ";
        }
        if (code.equals("nvi_pt")) {
            return "NVI_PT";
        }
        var upper = code.toUpper();
        return upper;
    }

    //! Default translation for a language.
    function defaultCode(langId as String) as String {
        var codes = codesForLanguage(langId);
        if (codes.size() > 0) {
            return codes[0] as String;
        }
        return "niv";
    }

    //! Resolve the API language parameter for today.
    //! If setting is random, pick stably for the given dayKey (YYYY-MM-DD).
    function resolveApiCode(langId as String, settingCode as String, dayKey as String) as String {
        if (!settingCode.equals(RANDOM_CODE)) {
            var available = codesForLanguage(langId);
            for (var i = 0; i < available.size(); i++) {
                if ((available[i] as String).equals(settingCode)) {
                    return settingCode;
                }
            }
            return defaultCode(langId);
        }

        var codes = codesForLanguage(langId);
        if (codes.size() == 1) {
            return codes[0] as String;
        }
        // Stable daily pick without depending on String.hashCode availability
        var seed = 0;
        seed += checksum(dayKey);
        seed += checksum(langId);
        if (seed < 0) {
            seed = -seed;
        }
        var idx = seed % codes.size();
        return codes[idx] as String;
    }

    function checksum(text as String) as Number {
        var sum = 7;
        for (var i = 0; i < text.length(); i++) {
            sum = (sum * 31) + letterWeight(text.substring(i, i + 1));
        }
        return sum;
    }

    function letterWeight(ch as String) as Number {
        if (ch.equals("0")) { return 0; }
        if (ch.equals("1")) { return 1; }
        if (ch.equals("2")) { return 2; }
        if (ch.equals("3")) { return 3; }
        if (ch.equals("4")) { return 4; }
        if (ch.equals("5")) { return 5; }
        if (ch.equals("6")) { return 6; }
        if (ch.equals("7")) { return 7; }
        if (ch.equals("8")) { return 8; }
        if (ch.equals("9")) { return 9; }
        if (ch.equals("-")) { return 10; }
        if (ch.equals("a") || ch.equals("A")) { return 11; }
        if (ch.equals("b") || ch.equals("B")) { return 12; }
        if (ch.equals("c") || ch.equals("C")) { return 13; }
        if (ch.equals("d") || ch.equals("D")) { return 14; }
        if (ch.equals("e") || ch.equals("E")) { return 15; }
        if (ch.equals("f") || ch.equals("F")) { return 16; }
        if (ch.equals("g") || ch.equals("G")) { return 17; }
        if (ch.equals("h") || ch.equals("H")) { return 18; }
        if (ch.equals("i") || ch.equals("I")) { return 19; }
        if (ch.equals("j") || ch.equals("J")) { return 20; }
        if (ch.equals("k") || ch.equals("K")) { return 21; }
        if (ch.equals("l") || ch.equals("L")) { return 22; }
        if (ch.equals("m") || ch.equals("M")) { return 23; }
        if (ch.equals("n") || ch.equals("N")) { return 24; }
        if (ch.equals("o") || ch.equals("O")) { return 25; }
        if (ch.equals("p") || ch.equals("P")) { return 26; }
        if (ch.equals("q") || ch.equals("Q")) { return 27; }
        if (ch.equals("r") || ch.equals("R")) { return 28; }
        if (ch.equals("s") || ch.equals("S")) { return 29; }
        if (ch.equals("t") || ch.equals("T")) { return 30; }
        if (ch.equals("u") || ch.equals("U")) { return 31; }
        if (ch.equals("v") || ch.equals("V")) { return 32; }
        if (ch.equals("w") || ch.equals("W")) { return 33; }
        if (ch.equals("x") || ch.equals("X")) { return 34; }
        if (ch.equals("y") || ch.equals("Y")) { return 35; }
        if (ch.equals("z") || ch.equals("Z")) { return 36; }
        return 40 + ch.length();
    }
}
