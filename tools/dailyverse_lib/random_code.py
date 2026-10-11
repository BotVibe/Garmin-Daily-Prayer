"""Mirror of Translations.resolveApiCode / checksum for CI tests."""

from __future__ import annotations

from .catalog import extract_catalog

RANDOM_CODE = "random"

_LETTER_WEIGHT = {
    **{str(i): i for i in range(10)},
    "-": 10,
}
for i, ch in enumerate("abcdefghijklmnopqrstuvwxyz", start=11):
    _LETTER_WEIGHT[ch] = i
    _LETTER_WEIGHT[ch.upper()] = i


def letter_weight(ch: str) -> int:
    if ch in _LETTER_WEIGHT:
        return _LETTER_WEIGHT[ch]
    return 40 + len(ch)


def checksum(text: str) -> int:
    total = 7
    for ch in text:
        total = (total * 31) + letter_weight(ch)
    return total


def resolve_api_code(
    lang_id: str,
    setting_code: str,
    day_key: str,
    catalog: dict[str, list[str]] | None = None,
) -> str:
    cat = catalog if catalog is not None else extract_catalog()
    codes = cat.get(lang_id) or ["niv"]
    default = codes[0]

    if setting_code != RANDOM_CODE:
        return setting_code if setting_code in codes else default

    if len(codes) == 1:
        return codes[0]

    seed = checksum(day_key) + checksum(lang_id)
    if seed < 0:
        seed = -seed
    return codes[seed % len(codes)]
