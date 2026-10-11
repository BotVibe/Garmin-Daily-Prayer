#!/usr/bin/env python3
"""Render the Daily Verse launcher icons and the Connect IQ Store icon.

Garmin devices ask for different launcher icon sizes (40, 60, 61, 65 and 70
pixels across the supported matrix), so every size is drawn from the same vector
description and supersampled down instead of upscaling a single bitmap.

Outputs:
    resources/drawables/launcher_icon.png          40x40 (base resource)
    resources-icon-<size>/drawables/...            per-device overrides
    store/assets/icons/launcher_icon_<size>.png    copies for the store listing
    store/assets/store_icon_500.png                500x500 store icon

Usage:
    python3 tools/gen_icons.py
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]

# Palette shared with source/BackgroundDrawable.mc so the icon matches the app.
TEAL_DEEP = (12, 28, 36, 255)
TEAL_MID = (18, 52, 64, 255)
CREAM = (232, 220, 196, 255)
CREAM_SHADE = (208, 196, 173, 255)
GOLD = (200, 160, 96, 255)
INK = (150, 141, 124, 255)

SUPERSAMPLE = 8

# Launcher icon sizes required by the products in manifest.xml.
#   40 -> fenix 7 family, fenix 8 Solar, fr255 family, fr955   (base resource)
#   60 -> epix 2 family, fenix 8 43mm, fr265 / fr265s
#   61 -> venu 2S
#   65 -> fenix 8 47mm, fenix 8 Pro 47mm, fr965
#   70 -> venu 2, venu 2 Plus, venu 3, venu 3S
BASE_SIZE = 40
OVERRIDE_SIZES = (60, 61, 65, 70)
STORE_SIZE = 500


def draw_icon(size: int) -> Image.Image:
    """Draw the icon at `size` pixels using a supersampled canvas."""
    work = size * SUPERSAMPLE
    image = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def px(fraction: float) -> float:
        return fraction * work

    # Circular badge, plus a blurred teal glow behind the book for depth.
    draw.ellipse([0, 0, work - 1, work - 1], fill=TEAL_DEEP)

    glow = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_inset = px(0.20)
    glow_draw.ellipse(
        [glow_inset, glow_inset, work - 1 - glow_inset, work - 1 - glow_inset],
        fill=TEAL_MID,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(px(0.075)))
    mask = Image.new("L", (work, work), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, work - 1, work - 1], fill=255)
    image.paste(glow, (0, 0), Image.composite(glow.getchannel("A"), mask, mask))
    draw = ImageDraw.Draw(image)

    # Open book: two pages tilted away from a central spine.
    spine_x = px(0.5)
    top_outer, top_inner = px(0.395), px(0.335)
    bottom_outer, bottom_inner = px(0.640), px(0.690)
    left_edge, right_edge = px(0.165), px(0.835)

    left_page = [
        (left_edge, top_outer),
        (spine_x - px(0.012), top_inner),
        (spine_x - px(0.012), bottom_inner),
        (left_edge, bottom_outer),
    ]
    right_page = [
        (right_edge, top_outer),
        (spine_x + px(0.012), top_inner),
        (spine_x + px(0.012), bottom_inner),
        (right_edge, bottom_outer),
    ]
    draw.polygon(left_page, fill=CREAM)
    draw.polygon(right_page, fill=CREAM_SHADE)

    # Text lines, shortest at the bottom so it reads as a paragraph.
    line_width = max(1, int(px(0.018)))
    for width_fraction, y_fraction in (
        (0.250, 0.460),
        (0.250, 0.520),
        (0.160, 0.580),
    ):
        y_left = px(y_fraction)
        draw.line(
            [
                (spine_x - px(0.040) - px(width_fraction), y_left + px(0.030)),
                (spine_x - px(0.040), y_left),
            ],
            fill=INK,
            width=line_width,
        )
        draw.line(
            [
                (spine_x + px(0.040), y_left),
                (spine_x + px(0.040) + px(width_fraction), y_left + px(0.030)),
            ],
            fill=INK,
            width=line_width,
        )

    # Gold spine plus a bookmark ribbon peeking out of the bottom.
    draw.polygon(
        [
            (spine_x - px(0.022), top_inner - px(0.012)),
            (spine_x + px(0.022), top_inner - px(0.012)),
            (spine_x + px(0.022), bottom_inner + px(0.010)),
            (spine_x - px(0.022), bottom_inner + px(0.010)),
        ],
        fill=GOLD,
    )
    draw.polygon(
        [
            (spine_x - px(0.030), bottom_inner),
            (spine_x + px(0.030), bottom_inner),
            (spine_x + px(0.030), bottom_inner + px(0.085)),
            (spine_x, bottom_inner + px(0.050)),
            (spine_x - px(0.030), bottom_inner + px(0.085)),
        ],
        fill=GOLD,
    )

    return image.resize((size, size), Image.LANCZOS)


DRAWABLES_XML = """<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png" />
</drawables>
"""


def write_icon(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    draw_icon(size).save(path)
    print(f"  {path.relative_to(ROOT)} ({size}x{size})")


def main() -> None:
    print("Launcher icons:")
    base = ROOT / "resources/drawables/launcher_icon.png"
    write_icon(base, BASE_SIZE)

    for size in OVERRIDE_SIZES:
        directory = ROOT / f"resources-icon-{size}" / "drawables"
        write_icon(directory / "launcher_icon.png", size)
        (directory / "drawables.xml").write_text(DRAWABLES_XML, encoding="utf-8")

    print("Store assets:")
    store_icons = ROOT / "store/assets/icons"
    store_icons.mkdir(parents=True, exist_ok=True)
    for size in (BASE_SIZE,) + OVERRIDE_SIZES:
        shutil.copyfile(
            ROOT / ("resources/drawables/launcher_icon.png" if size == BASE_SIZE
                    else f"resources-icon-{size}/drawables/launcher_icon.png"),
            store_icons / f"launcher_icon_{size}.png",
        )
        print(f"  store/assets/icons/launcher_icon_{size}.png ({size}x{size})")

    write_icon(ROOT / "store/assets/store_icon_500.png", STORE_SIZE)


if __name__ == "__main__":
    main()
