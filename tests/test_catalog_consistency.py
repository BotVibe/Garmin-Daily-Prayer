from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from dailyverse_lib.catalog import (
    all_translation_codes,
    extract_catalog,
    extract_language_ids,
    language_index,
    setting_code_index,
    setting_codes,
)

ROOT = Path(__file__).resolve().parents[1]
SETTINGS_XML = ROOT / "resources/settings/settings.xml"


def _list_entries(property_key: str) -> list[str]:
    """Values of the listEntry elements of one <setting>, in document order."""
    for setting in ET.parse(SETTINGS_XML).getroot().iter("setting"):
        if setting.attrib.get("propertyKey") == f"@Properties.{property_key}":
            config = setting.find("settingConfig")
            assert config is not None
            return [entry.attrib["value"] for entry in config.findall("listEntry")]
    raise AssertionError(f"settings.xml has no setting for {property_key}")


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
    # Garmin Connect only accepts numeric list values, so the entries are the
    # positions that Translations.languageIdForIndex resolves.
    entries = _list_entries("languageIndex")
    assert entries == [str(i) for i in range(len(extract_language_ids()))]


def test_settings_translation_list_covers_catalog_and_random() -> None:
    entries = _list_entries("translationIndex")
    codes = setting_codes()
    assert entries == [str(i) for i in range(len(codes))]
    # Index 0 is "random"; the rest must be exactly the catalog codes.
    assert codes[0] == "random"
    assert set(codes[1:]) == all_translation_codes()


def test_setting_indices_round_trip() -> None:
    for index, code in enumerate(setting_codes()):
        assert setting_code_index(code) == index
    for index, lang in enumerate(extract_language_ids()):
        assert language_index(lang) == index


def test_generated_settings_xml_is_committed() -> None:
    # tools/gen_settings.py owns settings.xml; a stale file would ship wrong indices.
    sys.path.insert(0, str(ROOT / "tools"))
    import gen_settings

    assert gen_settings.render() == SETTINGS_XML.read_text(encoding="utf-8")


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

    default_lang = extract_language_ids()[int(values["languageIndex"])]
    default_code = setting_codes()[int(values["translationIndex"])]
    assert default_lang in catalog
    assert default_code == "random" or default_code in catalog[default_lang]

    for slot in (1, 2, 3):
        hour = int(values[f"slot{slot}Hour"])
        minute = int(values[f"slot{slot}Minute"])
        assert 0 <= hour <= 23
        assert 0 <= minute <= 59
