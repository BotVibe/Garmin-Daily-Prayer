from __future__ import annotations

import pytest

from dailyverse_lib.parse import parse_verse_body


def test_plain_text_verse_and_reference() -> None:
    body = (
        "Und der HERR wird König sein über die ganze Erde; "
        "an jenem Tag wird der HERR einzig sein und sein Name einzig.\n\n"
        "Sacharja 14:9\n"
    )
    parsed = parse_verse_body(body)
    assert parsed is not None
    assert "HERR" in parsed["text"]
    assert parsed["ref"] == "Sacharja 14:9"


def test_strips_translation_suffix_from_reference() -> None:
    parsed = parse_verse_body("Come to me.\nMatthew 11:28 - NIV\n")
    assert parsed is not None
    assert parsed["ref"] == "Matthew 11:28"
    assert parsed["text"] == "Come to me."


def test_html_wrapper_is_stripped() -> None:
    body = (
        '<div class="dailyVerses bibleText">Peace I leave with you.</div>'
        '<div class="dailyVerses bibleVerse">'
        '<a href="https://dailyverses.net/john/14/27">John 14:27</a></div>'
    )
    parsed = parse_verse_body(body)
    assert parsed is not None
    assert "Peace I leave with you." in parsed["text"]
    assert parsed["ref"] == "John 14:27"


def test_js_unicode_escapes() -> None:
    body = (
        "document.getElementById('x').innerHTML = "
        "'\\u003cdiv\\u003eHello\\u003c/div\\u003e\\u003cdiv\\u003eJohn 3:16\\u003c/div\\u003e';"
    )
    parsed = parse_verse_body(body)
    assert parsed is not None
    assert "Hello" in parsed["text"]
    assert parsed["ref"] == "John 3:16"


def test_empty_and_whitespace_return_none() -> None:
    assert parse_verse_body(None) is None
    assert parse_verse_body("") is None
    assert parse_verse_body("   \n  ") is None


def test_single_line_fallback() -> None:
    parsed = parse_verse_body("Only one line without a clear split")
    assert parsed is not None
    assert parsed["text"]
    assert parsed["ref"] == ""


@pytest.mark.network
def test_live_dailyverses_lut() -> None:
    import urllib.request

    url = "https://dailyverses.net/get/verse?language=lut"
    with urllib.request.urlopen(url, timeout=20) as resp:
        body = resp.read().decode("utf-8", errors="replace")
    parsed = parse_verse_body(body)
    assert parsed is not None
    assert parsed["text"]
    assert parsed["ref"]
