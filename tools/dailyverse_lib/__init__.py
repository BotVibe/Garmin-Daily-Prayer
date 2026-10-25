"""Shared helpers used by CI tests and local smoke scripts."""

from .catalog import extract_catalog, extract_language_ids
from .parse import parse_verse_body
from .random_code import resolve_api_code
from .reminder import compute_next_moment
from .verse_layout import (
    build_scroll_lines,
    clamp_scroll_offset,
    more_content_below,
    needs_scroll,
    page_delta,
    wrap_words,
)

__all__ = [
    "extract_catalog",
    "extract_language_ids",
    "parse_verse_body",
    "resolve_api_code",
    "compute_next_moment",
    "wrap_words",
    "needs_scroll",
    "clamp_scroll_offset",
    "page_delta",
    "build_scroll_lines",
    "more_content_below",
]
