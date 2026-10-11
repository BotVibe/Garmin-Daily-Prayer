"""Mirror of VerseApi.parseVerseBody for offline/CI testing."""

from __future__ import annotations

import re


def parse_verse_body(body: str | None) -> dict[str, str] | None:
    if body is None or not body.strip():
        return None

    cleaned = body.strip()

    # verse.js wraps HTML in an innerHTML assignment — prefer the payload string
    for pattern in (
        r"innerHTML\s*=\s*'((?:\\'|[^'])*)'",
        r'innerHTML\s*=\s*"((?:\\"|[^"])*)"',
    ):
        match = re.search(pattern, cleaned)
        if match:
            cleaned = match.group(1)
            break

    cleaned = (
        cleaned.replace("\\u003c", "<")
        .replace("\\u003e", ">")
        .replace("\\u0026", "&")
        .replace('\\"', '"')
        .replace("\\'", "'")
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&quot;", '"')
        .replace("&#39;", "'")
    )

    if "<" in cleaned:
        cleaned = re.sub(r"<[^>]+>", "\n", cleaned)

    lines = []
    for raw in cleaned.splitlines():
        line = raw.strip().strip("'\"`;")
        if line:
            lines.append(line)

    if not lines:
        return None

    reference = lines[-1]
    if " - " in reference:
        reference = reference.split(" - ", 1)[0].strip()

    if len(lines) == 1:
        return {"text": lines[0], "ref": ""}

    text = " ".join(lines[:-1])
    return {"text": text, "ref": reference}
