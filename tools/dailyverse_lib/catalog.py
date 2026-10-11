"""Extract language/translation catalog from Translations.mc."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRANSLATIONS_MC = ROOT / "source" / "Translations.mc"


def extract_language_ids(source: str | None = None) -> list[str]:
    text = source if source is not None else TRANSLATIONS_MC.read_text(encoding="utf-8")
    match = re.search(
        r"function languageIds\(\)[\s\S]*?return\s*\[([\s\S]*?)\]\s*as Array",
        text,
    )
    if not match:
        raise ValueError("Could not find languageIds() array in Translations.mc")
    return re.findall(r'"([a-z]{2})"', match.group(1))


def extract_catalog(source: str | None = None) -> dict[str, list[str]]:
    """Return langId -> translation codes from codesForLanguage branches."""
    text = source if source is not None else TRANSLATIONS_MC.read_text(encoding="utf-8")
    catalog: dict[str, list[str]] = {}
    for lang, codes_blob in re.findall(
        r'langId\.equals\("([a-z]{2})"\)\)\s*\{\s*return\s*\[([^\]]+)\]',
        text,
    ):
        codes = re.findall(r'"([a-z0-9_]+)"', codes_blob)
        catalog[lang] = codes
    if not catalog:
        raise ValueError("Could not parse codesForLanguage catalog")
    return catalog


def all_translation_codes(catalog: dict[str, list[str]] | None = None) -> set[str]:
    cat = catalog if catalog is not None else extract_catalog()
    out: set[str] = set()
    for codes in cat.values():
        out.update(codes)
    return out
