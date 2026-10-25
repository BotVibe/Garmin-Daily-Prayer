"""Layout / pagination helpers for long verse scrolling."""

from __future__ import annotations

from dailyverse_lib.verse_layout import (
    build_scroll_lines,
    clamp_scroll_offset,
    more_content_below,
    needs_scroll,
    page_delta,
    wrap_words,
)


def _char_width(text: str) -> float:
    """Simple monospace measure: one unit per character."""
    return float(len(text))


def test_wrap_words_respects_max_width() -> None:
    lines = wrap_words("one two three four", max_width=8, measure=_char_width)
    assert lines == ["one two", "three", "four"] or lines == ["one two", "three four"]
    assert all(len(line) <= 8 for line in lines)


def test_wrap_words_preserves_newlines() -> None:
    lines = wrap_words("alpha beta\ngamma", max_width=20, measure=_char_width)
    assert lines == ["alpha beta", "gamma"]


def test_short_verse_does_not_need_scroll() -> None:
    assert needs_scroll(line_count=4, line_height=20, area_height=100) is False


def test_long_verse_needs_scroll() -> None:
    assert needs_scroll(line_count=10, line_height=20, area_height=100) is True


def test_needs_scroll_guards_empty() -> None:
    assert needs_scroll(0, 20, 100) is False
    assert needs_scroll(5, 0, 100) is False
    assert needs_scroll(5, 20, 0) is False


def test_clamp_scroll_offset() -> None:
    assert clamp_scroll_offset(0, 20, 5) == 0
    assert clamp_scroll_offset(-3, 20, 5) == 0
    assert clamp_scroll_offset(100, 20, 5) == 15
    assert clamp_scroll_offset(10, 20, 5) == 10
    assert clamp_scroll_offset(0, 3, 10) == 0


def test_page_delta_leaves_overlap() -> None:
    assert page_delta(1) == 1
    assert page_delta(5) == 4
    assert page_delta(0) == 1


def test_build_scroll_lines_puts_reference_after_verse() -> None:
    lines, ref_start = build_scroll_lines(
        ["Blessed are the meek,", "for they will inherit the earth."],
        ["Matthew 5:5"],
    )
    assert lines[0].startswith("Blessed")
    assert lines[ref_start] == "Matthew 5:5"
    assert lines[ref_start - 1] == ""
    assert "Matthew" not in "".join(lines[:ref_start])


def test_more_content_below_hint() -> None:
    assert more_content_below(0, 12, 5) is True
    assert more_content_below(7, 12, 5) is False
    assert more_content_below(0, 5, 5) is False


def test_full_pagination_walk() -> None:
    """Simulate paging through a long scroll buffer with next/previous."""
    verse = wrap_words(
        "The LORD will be king over the whole earth. "
        "On that day there will be one LORD, and his name the only name. "
        "And the LORD will be king forever and ever.",
        max_width=28,
        measure=_char_width,
    )
    ref = wrap_words("Zechariah 14:9", max_width=28, measure=_char_width)
    lines, ref_start = build_scroll_lines(verse, ref)
    visible = 5
    assert needs_scroll(len(verse), 18, 90) is True or len(lines) > visible

    offset = 0
    seen_ref = False
    guard = 0
    while more_content_below(offset, len(lines), visible):
        offset = clamp_scroll_offset(offset + page_delta(visible), len(lines), visible)
        window = lines[offset : offset + visible]
        if any(i >= ref_start for i in range(offset, min(offset + visible, len(lines)))):
            seen_ref = True
        guard += 1
        assert guard < 50
        assert window
    # After scrolling to the end, the reference is in the last window.
    last = lines[offset : offset + visible]
    assert any("Zechariah" in line for line in last)
    assert seen_ref or any("Zechariah" in line for line in last)


def test_verse_view_uses_system_backlight_not_max() -> None:
    from pathlib import Path

    text = (Path(__file__).resolve().parents[1] / "source" / "VerseView.mc").read_text(
        encoding="utf-8"
    )
    assert "Attention.backlight(true)" in text
    assert "Attention.backlight(1.0)" not in text
    assert "VerseScroll" in text
    assert "scrollBy" in text
