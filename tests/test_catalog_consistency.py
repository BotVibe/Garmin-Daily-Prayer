from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

from dailyverse_lib.catalog import all_translation_codes, extract_catalog, extract_language_ids

ROOT = Path(__file__).resolve().parents[1]


def _string_ids(path: Path) -> set[str]:
    root = ET.parse(path).getroot()
    return {el.attrib["id"] for el in root.findall("string") if "id" in el.attrib}


def test_language_ids_match_catalog_branches() -> None:
    langs = extract_language_ids()
    catalog = extract_catalog()
    assert set(langs) == set(catalog.keys())
    assert len(langs) == len(set(langs))


def test_every_language_has_at_least_one_translation() -> None:
    for lang, codes in extract_catalog().items():
        assert codes, f"{lang} has no translation codes"
        assert "random" not in codes


def test_settings_language_list_matches_catalog() -> None:
    settings = (ROOT / "resources/settings/settings.xml").read_text(encoding="utf-8")
    # First list block is languageId
    lang_block = settings.split('propertyKey="@Properties.languageId"', 1)[1]
    lang_block = lang_block.split('propertyKey="@Properties.translationCode"', 1)[0]
    settings_langs = re.findall(r'listEntry value="([a-z]{2})"', lang_block)
    assert settings_langs == extract_language_ids()


def test_settings_translation_list_covers_catalog_and_random() -> None:
    settings = (ROOT / "resources/settings/settings.xml").read_text(encoding="utf-8")
    code_block = settings.split('propertyKey="@Properties.translationCode"', 1)[1]
    code_block = code_block.split('propertyKey="@Properties.slot1Enabled"', 1)[0]
    settings_codes = set(re.findall(r'listEntry value="([a-z0-9_]+)"', code_block))
    catalog_codes = all_translation_codes()
    assert "random" in settings_codes
    missing = catalog_codes - settings_codes
    assert not missing, f"settings.xml missing translation codes: {sorted(missing)}"
    extra = settings_codes - catalog_codes - {"random"}
    assert not extra, f"settings.xml has unknown codes: {sorted(extra)}"


def test_string_resources_cover_all_languages() -> None:
    langs = extract_language_ids()
    for path in (
        ROOT / "resources/strings/strings.xml",
        ROOT / "resources-eng/strings/strings.xml",
    ):
        ids = _string_ids(path)
        for lang in langs:
            assert f"Lang_{lang}" in ids, f"{path} missing Lang_{lang}"


def test_default_properties_are_valid() -> None:
    props = ET.parse(ROOT / "resources/properties/properties.xml").getroot()
    values = {el.attrib["id"]: (el.text or "").strip() for el in props.findall("property")}
    catalog = extract_catalog()
    assert values["languageId"] in catalog
    assert values["translationCode"] in catalog[values["languageId"]] or values[
        "translationCode"
    ] == "random"
    for slot in (1, 2, 3):
        hour = int(values[f"slot{slot}Hour"])
        minute = int(values[f"slot{slot}Minute"])
        assert 0 <= hour <= 23
        assert 0 <= minute <= 59
