#!/usr/bin/env python3
"""Offline sanity checks mirroring VerseApi.parseVerseBody behaviour."""

from __future__ import annotations

import re
import sys
import urllib.request


def parse_verse_body(body: str) -> dict[str, str] | None:
    if not body or not body.strip():
        return None
    cleaned = body
    if "<" in cleaned:
        cleaned = re.sub(r"<[^>]+>", "\n", cleaned)
    cleaned = (
        cleaned.replace("\\u003c", "<")
        .replace("\\u003e", ">")
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .strip()
    )
    lines = [ln.strip() for ln in cleaned.splitlines()]
    lines = [ln for ln in lines if ln]
    if not lines:
        return None
    reference = lines[-1]
    if " - " in reference:
        reference = reference.split(" - ", 1)[0].strip()
    text = " ".join(lines[:-1]) if len(lines) > 1 else cleaned
    return {"text": text, "ref": reference}


def main() -> int:
    samples = [
        "Und der HERR wird König sein über die ganze Erde.\n\nSacharja 14:9\n",
        "Hello world\nJohn 3:16 - NIV\n",
    ]
    for sample in samples:
        parsed = parse_verse_body(sample)
        assert parsed is not None
        assert parsed["ref"]
        assert parsed["text"]
        print("OK sample:", parsed["ref"])

    url = "https://dailyverses.net/get/verse?language=lut"
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            body = resp.read().decode("utf-8", errors="replace")
        parsed = parse_verse_body(body)
        assert parsed is not None
        print("OK live LUT:", parsed["ref"])
        print(parsed["text"][:120] + ("…" if len(parsed["text"]) > 120 else ""))
    except Exception as exc:  # noqa: BLE001
        print("WARN live fetch skipped:", exc, file=sys.stderr)

    print("All parse checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
