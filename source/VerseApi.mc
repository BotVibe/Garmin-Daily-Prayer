import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

//! Fetches and parses the DailyVerses.net plaintext verse endpoint.
module VerseApi {

    //! Non-breaking space, which DailyVerses.net emits around references.
    const NBSP as String = "\u00a0";

    typedef VerseCallback as Method(success as Boolean, text as String?, reference as String?, apiCode as String?, error as String?) as Void;

    class Request {
        private var _callback as VerseCallback;
        private var _apiCode as String;
        private var _langId as String;
        private var _settingCode as String;

        function initialize(langId as String, settingCode as String, callback as VerseCallback) {
            _callback = callback;
            _langId = langId;
            _settingCode = settingCode;
            _apiCode = Translations.resolveApiCode(langId, settingCode, VerseCache.todayKey());
        }

        function start() as Void {
            if (!(Communications has :makeWebRequest)) {
                _callback.invoke(false, null, null, null, "no_comms");
                return;
            }

            var url = "https://dailyverses.net/get/verse";
            var params = {
                "language" => _apiCode
            };
            var options = {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Accept" => "text/plain, text/html, */*"
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            };

            try {
                Communications.makeWebRequest(url, params, options, method(:onReceive));
            } catch (e) {
                _callback.invoke(false, null, null, null, "request_failed");
            }
        }

        function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
            if (responseCode != 200 || data == null) {
                var err = "http_" + responseCode.toString();
                // Negative / transport failures typically mean phone/network unavailable
                if (responseCode < 0) {
                    err = "no_phone";
                }
                _callback.invoke(false, null, null, null, err);
                return;
            }

            var body = data as String;
            var parsed = parseVerseBody(body);
            if (parsed == null) {
                _callback.invoke(false, null, null, null, "parse");
                return;
            }

            var text = parsed["text"] as String;
            var reference = parsed["ref"] as String;
            VerseCache.save(text, reference, _apiCode, _langId, _settingCode);
            _callback.invoke(true, text, reference, _apiCode, null);
        }
    }

    //! Parse plaintext body: verse lines, then reference line.
    function parseVerseBody(body as String) as Dictionary? {
        if (body == null || body.length() == 0) {
            return null;
        }

        var cleaned = unescapeJs(trim(body));
        // Prefer payload inside verse.js innerHTML = '...'
        var payload = extractInnerHtmlPayload(cleaned);
        if (payload != null) {
            cleaned = payload as String;
            cleaned = unescapeJs(cleaned);
        }
        if (cleaned.find("<") != null) {
            cleaned = stripTags(cleaned);
        }
        cleaned = trim(cleaned);

        var lines = splitLines(cleaned);
        if (lines.size() == 0) {
            return null;
        }

        // Last non-empty line is typically the reference (e.g. "Sacharja 14:9")
        var refIdx = lines.size() - 1;
        while (refIdx >= 0 && sanitizeLine(lines[refIdx] as String).length() == 0) {
            refIdx--;
        }
        if (refIdx < 0) {
            return null;
        }

        var reference = sanitizeLine(lines[refIdx] as String);
        // Drop trailing " - ELB" style suffixes if present
        var dash = reference.find(" - ");
        if (dash != null) {
            reference = trim(reference.substring(0, dash as Number) as String);
        }

        var textParts = [] as Array<String>;
        for (var i = 0; i < refIdx; i++) {
            var line = sanitizeLine(lines[i] as String);
            if (line.length() > 0) {
                textParts.add(line);
            }
        }
        if (textParts.size() == 0) {
            // Single-line response: treat entire body as text, unknown ref
            return {
                "text" => cleaned,
                "ref" => ""
            } as Dictionary;
        }

        var text = joinLines(textParts);
        return {
            "text" => text,
            "ref" => reference
        } as Dictionary;
    }

    function extractInnerHtmlPayload(text as String) as String? {
        var marker = "innerHTML";
        var at = text.find(marker);
        if (at == null) {
            return null;
        }
        var from = (at as Number) + marker.length();
        var quoteIdx = -1;
        var quote = "";
        for (var i = from; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals("'") || ch.equals("\"")) {
                quoteIdx = i;
                quote = ch;
                break;
            }
        }
        if (quoteIdx < 0) {
            return null;
        }
        var start = quoteIdx + 1;
        for (var j = start; j < text.length(); j++) {
            var c = text.substring(j, j + 1);
            if (c.equals(quote)) {
                return text.substring(start, j);
            }
        }
        return null;
    }

    function sanitizeLine(line as String) as String {
        var out = trim(line);
        // Strip common JS/string artifacts from verse.js payloads
        while (out.length() > 0) {
            var first = out.substring(0, 1);
            var last = out.substring(out.length() - 1, out.length());
            if (first.equals("'") || first.equals("\"") || first.equals("`") || first.equals(";")) {
                out = trim(out.substring(1, out.length()) as String);
                continue;
            }
            if (last.equals("'") || last.equals("\"") || last.equals("`") || last.equals(";")) {
                out = trim(out.substring(0, out.length() - 1) as String);
                continue;
            }
            break;
        }
        return out;
    }

    //! Monkey C's String has no trim(), so strip surrounding whitespace by hand.
    function trim(text as String) as String {
        var len = text.length();
        var start = 0;
        while (start < len && isWhitespace(text.substring(start, start + 1) as String)) {
            start++;
        }
        var end = len;
        while (end > start && isWhitespace(text.substring(end - 1, end) as String)) {
            end--;
        }
        if (start == 0 && end == len) {
            return text;
        }
        if (start >= end) {
            return "";
        }
        return text.substring(start, end) as String;
    }

    function isWhitespace(ch as String) as Boolean {
        return ch.equals(" ")
            || ch.equals("\n")
            || ch.equals("\r")
            || ch.equals("\t")
            || ch.equals(NBSP);
    }

    function splitLines(text as String) as Array<String> {
        var result = [] as Array<String>;
        var start = 0;
        var len = text.length();
        for (var i = 0; i < len; i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals("\n") || ch.equals("\r")) {
                if (i > start) {
                    result.add(text.substring(start, i));
                } else {
                    result.add("");
                }
                // skip \r\n
                if (ch.equals("\r") && i + 1 < len && text.substring(i + 1, i + 2).equals("\n")) {
                    i++;
                }
                start = i + 1;
            }
        }
        if (start < len) {
            result.add(text.substring(start, len));
        }
        return result;
    }

    function joinLines(parts as Array<String>) as String {
        var out = "";
        for (var i = 0; i < parts.size(); i++) {
            if (i > 0) {
                out += " ";
            }
            out += parts[i] as String;
        }
        return out;
    }

    function stripTags(html as String) as String {
        var out = "";
        var inTag = false;
        for (var i = 0; i < html.length(); i++) {
            var ch = html.substring(i, i + 1);
            if (ch.equals("<")) {
                inTag = true;
                // Insert newline between block-ish closes for structure
                if (i + 2 < html.length()) {
                    var peek = html.substring(i, i + 2);
                    if (peek.equals("</")) {
                        out += "\n";
                    }
                }
            } else if (ch.equals(">")) {
                inTag = false;
            } else if (!inTag) {
                out += ch;
            }
        }
        return out;
    }

    function unescapeJs(text as String) as String {
        var out = text;
        // Common unicode escapes from verse.js
        out = replaceAll(out, "\\u003c", "<");
        out = replaceAll(out, "\\u003e", ">");
        out = replaceAll(out, "\\u0026", "&");
        out = replaceAll(out, "\\\"", "\"");
        out = replaceAll(out, "\\'", "'");
        out = replaceAll(out, "&nbsp;", " ");
        out = replaceAll(out, "&amp;", "&");
        out = replaceAll(out, "&quot;", "\"");
        out = replaceAll(out, "&#39;", "'");
        return out;
    }

    function replaceAll(text as String, from as String, to as String) as String {
        if (from.length() == 0) {
            return text;
        }
        var out = "";
        var i = 0;
        while (i < text.length()) {
            var idx = text.substring(i, text.length()).find(from);
            if (idx == null) {
                out += text.substring(i, text.length());
                break;
            }
            var at = i + (idx as Number);
            out += text.substring(i, at);
            out += to;
            i = at + from.length();
        }
        return out;
    }
}
