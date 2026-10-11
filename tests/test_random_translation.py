from __future__ import annotations

from dailyverse_lib.catalog import extract_catalog
from dailyverse_lib.random_code import RANDOM_CODE, resolve_api_code


def test_fixed_code_passthrough() -> None:
    assert resolve_api_code("de", "lut", "2026-10-11") == "lut"


def test_invalid_code_falls_back_to_default() -> None:
    catalog = extract_catalog()
    assert resolve_api_code("de", "niv", "2026-10-11", catalog) == catalog["de"][0]


def test_random_is_stable_for_same_day() -> None:
    a = resolve_api_code("de", RANDOM_CODE, "2026-10-11")
    b = resolve_api_code("de", RANDOM_CODE, "2026-10-11")
    assert a == b
    assert a in extract_catalog()["de"]


def test_random_can_differ_across_days() -> None:
    catalog = extract_catalog()
    codes = {
        resolve_api_code("en", RANDOM_CODE, f"2026-01-{day:02d}", catalog)
        for day in range(1, 29)
    }
    # English has many translations; expect more than one pick over a month
    assert len(codes) >= 2


def test_single_translation_language_random() -> None:
    assert resolve_api_code("ru", RANDOM_CODE, "2026-10-11") == "rst"
