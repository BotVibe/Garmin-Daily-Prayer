"""Pure-Python mirror of verse wrap / scroll helpers used by VerseView."""

from __future__ import annotations

from collections.abc import Callable


def wrap_words(
    text: str,
    max_width: float,
    measure: Callable[[str], float],
) -> list[str]:
    """Word-wrap ``text`` to ``max_width`` using ``measure(string) -> width``.

    Newlines force a break. Words wider than ``max_width`` are kept on their
    own line (rare for Bible verses; matches a simple watch wrap).
    """
    lines: list[str] = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        if not words:
            lines.append("")
            continue
        current = ""
        for word in words:
            trial = word if not current else f"{current} {word}"
            if measure(trial) <= max_width:
                current = trial
            else:
                if current:
                    lines.append(current)
                current = word
        if current or not lines:
            lines.append(current)
    return lines


def needs_scroll(line_count: int, line_height: int, area_height: int) -> bool:
    """True when ``line_count`` lines of ``line_height`` exceed ``area_height``."""
    if line_count <= 0 or line_height <= 0 or area_height <= 0:
        return False
    return line_count * line_height > area_height


def clamp_scroll_offset(offset: int, total_lines: int, visible_lines: int) -> int:
    """Keep the first visible line index in range."""
    if visible_lines <= 0 or total_lines <= 0:
        return 0
    max_offset = max(0, total_lines - visible_lines)
    if offset < 0:
        return 0
    if offset > max_offset:
        return max_offset
    return offset


def page_delta(visible_lines: int) -> int:
    """Lines to move per next/previous page (leave one line of overlap)."""
    if visible_lines <= 1:
        return 1
    return visible_lines - 1


def build_scroll_lines(
    verse_lines: list[str],
    reference_lines: list[str],
) -> tuple[list[str], int]:
    """Concatenate verse + spacer + reference.

    Returns ``(all_lines, ref_start_index)``. The reference starts after a
    blank spacer line so it only appears once the user scrolls to the end.
    """
    lines = list(verse_lines)
    if reference_lines:
        lines.append("")
        ref_start = len(lines)
        lines.extend(reference_lines)
    else:
        ref_start = len(lines)
    return lines, ref_start


def more_content_below(offset: int, total_lines: int, visible_lines: int) -> bool:
    """Whether a scroll-down hint should be shown."""
    if visible_lines <= 0:
        return False
    return offset + visible_lines < total_lines
