#!/usr/bin/env python3
"""Render store screenshots that follow the on-device layout.

The verse screen itself is captured from the Connect IQ simulator
(store/assets/screenshots/01-verse-de.png) and is not regenerated here.
Menu screens use the system menu, whose typeface is not in the public device
font pack, so those screens are drawn from the real string resources and the
same colours as the app.

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
    inner = int(SIZE * 3 / 10)
    draw.ellipse((inner, inner, SIZE - 1 - inner, SIZE - 1 - inner), fill=TEAL)
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
    # Today's NIV text, the same verse the German simulator capture shows.
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
    shots = {
        "02-settings-de.png": render_menu(
            "Einstellungen",
            [
                ("Sprache", "Deutsch"),
                ("Bibelübersetzung", "LUT"),
                ("Erinnerungen", "08:00"),
            ],
        ),
        "03-language-de.png": render_menu(
            "Sprache",
            [
                ("Deutsch", "✓"),
                ("Englisch", None),
                ("Spanisch", None),
            ],
            selected=0,
        ),
        "04-reminders-de.png": render_menu(
            "Erinnerungen",
            [
                ("Erinnerung 1", "08:00 · An"),
                ("Erinnerung 2", "Aus"),
                ("Erinnerung 3", "Aus"),
            ],
        ),
        "05-verse-en.png": render_verse_en(),
    }
    for name, image in shots.items():
        path = OUT / name
        image.save(path)
        print(f"  {path.relative_to(ROOT)} {image.size}")


if __name__ == "__main__":
    main()
