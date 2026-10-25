#!/usr/bin/env python3
"""Render store screenshots that follow the on-device layout (English UI).

Menu screens use the system menu, whose typeface is not in the public device
font pack, so those screens are drawn from the English string resources and the
same colours as the app. The verse screen is rendered the same way for a
consistent English store pack.

    python3 tools/gen_screenshots.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "store" / "assets" / "screenshots"
SIZE = 390

SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SANS_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

TEAL = (12, 28, 36)
TEAL_RING = (18, 52, 64)
WHITE = (253, 248, 253)
GOLD = (200, 160, 96)
GRAY = (168, 168, 168)
MENU_BG = (0, 0, 0)
MENU_BAR = (28, 28, 30)
SUB = (164, 164, 164)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(SANS_BOLD if bold else SANS, size)


def circle_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask


def finish(image: Image.Image) -> Image.Image:
    framed = Image.new("RGB", image.size, (0, 0, 0))
    return Image.composite(image, framed, circle_mask(image.width))


def verse_background() -> Image.Image:
    """Same construction as source/BackgroundDrawable.mc."""
    image = Image.new("RGB", (SIZE, SIZE), TEAL)
    draw = ImageDraw.Draw(image)
    draw.ellipse((0, 0, SIZE - 1, SIZE - 1), fill=TEAL_RING)
    # BackgroundDrawable: inner disc radius = (r * 3) / 5 with r = SIZE / 2.
    radius = (SIZE // 2) * 3 // 5
    c = SIZE // 2
    draw.ellipse((c - radius, c - radius, c + radius, c + radius), fill=TEAL)
    return image


def wrap(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines: list[str] = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        current = ""
        for word in words:
            trial = word if not current else f"{current} {word}"
            if draw.textlength(trial, font=face) <= width:
                current = trial
            else:
                if current:
                    lines.append(current)
                current = word
        lines.append(current)
    return lines


def draw_centered(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    face: ImageFont.FreeTypeFont,
    y: int,
    fill: tuple[int, int, int],
    gap: int,
) -> int:
    for line in lines:
        box = draw.textbbox((0, 0), line, font=face)
        draw.text(((SIZE - (box[2] - box[0])) / 2, y), line, font=face, fill=fill)
        y += (box[3] - box[1]) + gap
    return y


def render_verse_en() -> Image.Image:
    image = verse_background()
    draw = ImageDraw.Draw(image)
    text = (
        "The LORD will be king over the whole earth. "
        "On that day there will be one LORD, and his name the only name."
    )
    face = font(22)
    lines = wrap(draw, text, face, int(SIZE * 0.78))
    block = len(lines) * 30
    draw_centered(draw, lines, face, (SIZE - block) // 2 - 24, WHITE, 8)
    draw_centered(draw, ["Zechariah 14:9"], font(22), 292, GOLD, 0)
    draw_centered(draw, ["NIV"], font(16), 328, GRAY, 0)
    return finish(image)


LONG_VERSE_EN = (
    "The LORD will be king over the whole earth. "
    "On that day there will be one LORD, and his name the only name. "
    "All the land will be changed into a plain from Geba to Rimmon "
    "south of Jerusalem. But Jerusalem will be raised up and remain "
    "in its place, from the Benjamin Gate to the site of the First Gate, "
    "to the Corner Gate, and from the Tower of Hananel to the royal winepresses. "
    "It will be inhabited; never again will it be destroyed. "
    "Jerusalem will be secure."
)


def render_verse_long_scrolled(*, at_bottom: bool = False, size: int = SIZE) -> Image.Image:
    """Long verse in scroll mode: reference only after the verse text."""
    global SIZE
    old = SIZE
    SIZE = size
    try:
        image = verse_background()
        draw = ImageDraw.Draw(image)
        face = font(18 if size <= 360 else 20)
        width = int(SIZE * 0.76)
        verse_lines = wrap(draw, LONG_VERSE_EN, face, width)
        ref_lines = wrap(draw, "Zechariah 14:9-11", face, width)
        lines: list[tuple[str, tuple[int, int, int]]] = [(ln, WHITE) for ln in verse_lines]
        lines.append(("", WHITE))
        lines.extend((ln, GOLD) for ln in ref_lines)

        top = int(SIZE * 0.18)
        bottom = int(SIZE * 0.84)
        line_h = 26 if size <= 360 else 28
        hint_h = 12
        visible = max(1, (bottom - top - hint_h) // line_h)
        max_off = max(0, len(lines) - visible)
        offset = max_off if at_bottom else 0
        y = top
        for text, fill in lines[offset : offset + visible]:
            if text:
                box = draw.textbbox((0, 0), text, font=face)
                draw.text(((SIZE - (box[2] - box[0])) / 2, y), text, font=face, fill=fill)
            y += line_h

        if offset + visible < len(lines):
            cx = SIZE // 2
            hy = bottom - 4
            draw.line((cx - 5, hy - 6, cx, hy), fill=GRAY, width=2)
            draw.line((cx, hy, cx + 5, hy - 6), fill=GRAY, width=2)

        draw_centered(draw, ["NIV"], font(14), int(SIZE * 0.88), GRAY, 0)
        return finish(image)
    finally:
        SIZE = old


def render_verse_long_reference(*, size: int = SIZE) -> Image.Image:
    """Verse screen with a long reference that wraps (round layout preview)."""
    global SIZE
    old = SIZE
    SIZE = size
    try:
        image = verse_background()
        draw = ImageDraw.Draw(image)
        text = (
            "The LORD will be king over the whole earth. "
            "On that day there will be one LORD, and his name the only name."
        )
        face = font(20 if size <= 360 else 22)
        lines = wrap(draw, text, face, int(SIZE * 0.76))
        block = len(lines) * 28
        draw_centered(draw, lines, face, max(int(SIZE * 0.22), (SIZE - block) // 2 - 40), WHITE, 6)
        ref_face = font(18 if size <= 360 else 20)
        ref_lines = wrap(
            draw,
            "The First Book of Chronicles 29:11-13",
            ref_face,
            int(SIZE * 0.76),
        )
        draw_centered(draw, ref_lines, ref_face, int(SIZE * 0.72), GOLD, 4)
        draw_centered(draw, ["NIV"], font(14), int(SIZE * 0.88), GRAY, 0)
        return finish(image)
    finally:
        SIZE = old


def render_time_picker(hour: int = 9, minute: int = 0) -> Image.Image:
    """Approximate WatchUi.Picker with two NumberFactory columns (hour : minute)."""
    image = Image.new("RGB", (SIZE, SIZE), MENU_BG)
    draw = ImageDraw.Draw(image)
    draw_centered(draw, ["Time"], font(22, bold=True), 42, WHITE, 0)

    # Selection band
    band_top = SIZE // 2 - 28
    band_bot = SIZE // 2 + 28
    draw.rounded_rectangle((48, band_top, SIZE - 48, band_bot), 16, fill=MENU_BAR)

    col_h = SIZE // 2 - 40
    col_m = SIZE // 2 + 40
    face_dim = font(26)
    face_sel = font(36, bold=True)

    def col(cx: int, center_val: int, modulo: int) -> None:
        for delta, face, fill in (
            (-2, face_dim, SUB),
            (-1, face_dim, SUB),
            (0, face_sel, WHITE),
            (1, face_dim, SUB),
            (2, face_dim, SUB),
        ):
            v = (center_val + delta) % modulo
            label = f"{v:02d}"
            box = draw.textbbox((0, 0), label, font=face)
            y = SIZE // 2 + delta * 36 - (box[3] - box[1]) // 2
            draw.text((cx - (box[2] - box[0]) / 2, y), label, font=face, fill=fill)

    col(col_h, hour, 24)
    colon = ":"
    box = draw.textbbox((0, 0), colon, font=face_sel)
    draw.text(
        ((SIZE - (box[2] - box[0])) / 2, SIZE // 2 - (box[3] - box[1]) // 2),
        colon,
        font=face_sel,
        fill=WHITE,
    )
    col(col_m, minute, 60)
    return finish(image)


def render_menu(
    title: str,
    rows: list[tuple[str, str | None]],
    selected: int = 0,
) -> Image.Image:
    """Three rows fit the round glass; further rows would scroll, as on the watch."""
    image = Image.new("RGB", (SIZE, SIZE), MENU_BG)
    draw = ImageDraw.Draw(image)
    draw_centered(draw, [title], font(22, bold=True), 52, WHITE, 0)

    top = 128
    row_h = 74
    label_face = font(22)
    sub_face = font(16)
    for index, (label, subtitle) in enumerate(rows):
        y = top + index * row_h
        if index == selected:
            draw.rounded_rectangle((36, y - 10, SIZE - 36, y + row_h - 18), 18, fill=MENU_BAR)
        draw.text((56, y), label, font=label_face, fill=WHITE)
        if subtitle:
            # A lone check mark sits on the right; other subtitles sit under the label,
            # which is how MenuItem renders them.
            if subtitle == "✓":
                box = draw.textbbox((0, 0), subtitle, font=label_face)
                draw.text((SIZE - 72 - (box[2] - box[0]), y), subtitle, font=label_face, fill=WHITE)
            else:
                draw.text((56, y + 28), subtitle, font=sub_face, fill=SUB)
    return finish(image)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pr_out = ROOT / "store" / "assets" / "pr-screenshots"
    pr_out.mkdir(parents=True, exist_ok=True)

    # Remove legacy German-named store shots so the pack stays English-only.
    for legacy in (
        "01-verse-de.png",
        "02-settings-de.png",
        "03-language-de.png",
        "04-reminders-de.png",
        "05-verse-en.png",
    ):
        path = OUT / legacy
        if path.exists():
            path.unlink()

    shots = {
        "01-verse-en.png": render_verse_en(),
        "02-settings-en.png": render_menu(
            "Settings",
            [
                ("Language", "English"),
                ("Bible translation", "NIV"),
                ("Reminders", "08:00"),
            ],
        ),
        "03-language-en.png": render_menu(
            "Language",
            [
                ("German", None),
                ("English", "✓"),
                ("Spanish", None),
            ],
            selected=1,
        ),
        "04-reminders-en.png": render_menu(
            "Reminders",
            [
                ("Reminder 1", "08:00 · On"),
                ("Reminder 2", "Off"),
                ("Reminder 3", "Off"),
            ],
        ),
        "05-long-verse-scroll-en.png": render_verse_long_scrolled(at_bottom=False, size=SIZE),
    }
    for name, image in shots.items():
        path = OUT / name
        image.save(path)
        print(f"  {path.relative_to(ROOT)} {image.size}")

    pr_shots = {
        "time-picker-390.png": render_time_picker(9, 0),
        "long-reference-360.png": render_verse_long_reference(size=360),
        "long-reference-454.png": render_verse_long_reference(size=454),
        "long-verse-scroll-top-390.png": render_verse_long_scrolled(at_bottom=False, size=390),
        "long-verse-scroll-bottom-390.png": render_verse_long_scrolled(at_bottom=True, size=390),
    }
    for name, image in pr_shots.items():
        path = pr_out / name
        image.save(path)
        print(f"  {path.relative_to(ROOT)} {image.size}")


if __name__ == "__main__":
    main()
