#!/usr/bin/env python3
"""Backward-compatible smoke entrypoint; prefer `pytest` in CI."""

from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from dailyverse_lib.parse import parse_verse_body  # noqa: E402


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
