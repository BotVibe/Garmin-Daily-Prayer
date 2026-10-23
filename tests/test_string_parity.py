"""Every string id must exist in EN (default), DEU, and FRE — and vice versa."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

STRING_FILES = {
    "en": ROOT / "resources/strings/strings.xml",
    "deu": ROOT / "resources-deu/strings/strings.xml",
    "fre": ROOT / "resources-fre/strings/strings.xml",
}


def _string_ids(path: Path) -> set[str]:
    root = ET.parse(path).getroot()
    return {el.attrib["id"] for el in root.findall("string") if "id" in el.attrib}


def test_string_resource_files_exist() -> None:
    missing = [name for name, path in STRING_FILES.items() if not path.is_file()]
    assert not missing, f"Missing string resource files: {missing}"


def test_string_ids_match_across_en_deu_fre() -> None:
    id_sets = {name: _string_ids(path) for name, path in STRING_FILES.items()}
    base = id_sets["en"]
    assert base, "default (English) strings.xml is empty"
    for name, ids in id_sets.items():
        missing = sorted(base - ids)
        extra = sorted(ids - base)
        assert not missing, f"{name} missing string ids present in EN: {missing}"
        assert not extra, f"{name} has string ids not in EN: {extra}"


def test_no_legacy_resources_eng() -> None:
    assert not (ROOT / "resources-eng").exists()
