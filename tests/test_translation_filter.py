from __future__ import annotations

from dailyverse_lib.catalog import extract_catalog, extract_language_ids


def test_every_language_has_at_least_one_translation() -> None:
    catalog = extract_catalog()
    for lang in extract_language_ids():
        assert lang in catalog
        assert len(catalog[lang]) >= 1


def test_default_code_is_first_in_language_list() -> None:
    catalog = extract_catalog()
    # Mirrors Translations.defaultCode
    assert catalog["de"][0] == "elb"
    assert catalog["en"][0] == "esv"


def test_codes_are_not_shared_across_unrelated_languages() -> None:
    """On-watch menus list only codesForLanguage(selected). A German→English
    switch must not keep `lut` selected — AppConfig falls back to defaultCode.
    """
    catalog = extract_catalog()
    assert "lut" in catalog["de"]
    assert "lut" not in catalog["en"]
    assert "niv" in catalog["en"]
    assert "niv" not in catalog["de"]
