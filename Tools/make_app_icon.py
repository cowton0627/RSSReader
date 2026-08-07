"""Regenerate the app icon.

    python3 Tools/make_app_icon.py

Writes a 1024x1024 opaque PNG (the App Store rejects an alpha channel) straight
into the asset catalog. Xcode derives every smaller size from it.

Requires Pillow: python3 -m pip install Pillow
"""

from pathlib import Path

from PIL import Image, ImageDraw

OUTPUT = Path(__file__).resolve().parent.parent / "RSSReader/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

SIZE = 1024
SS = 4                          # supersample, then downscale, for clean edges
S = SIZE * SS

BLUE_LIGHT = (44, 148, 224)     # the header / unread-dot blue, lightened
BLUE_DARK = (14, 74, 124)
WHITE = (255, 255, 255)


def gradient(top, bottom):
    image = Image.new("RGB", (S, S), top)
    draw = ImageDraw.Draw(image)
    for y in range(S):
        t = y / (S - 1)
        draw.line(
            [(0, y), (S, y)],
            fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return image


def rss_mark(draw, origin, radii, stroke, dot_radius, color):
    """The broadcast mark: a dot with quarter arcs sweeping up and to the right."""
    bx, by = origin
    for radius in radii:
        draw.arc(
            [bx - radius, by - radius, bx + radius, by + radius],
            start=270,
            end=360,
            fill=color,
            width=stroke,
        )
        # PIL draws butt ends; cap them by hand so the strokes read as rounded.
        half = stroke / 2
        for cap_x, cap_y in [(bx + radius - half, by), (bx, by - radius + half)]:
            draw.ellipse([cap_x - half, cap_y - half, cap_x + half, cap_y + half], fill=color)

    draw.ellipse(
        [bx - dot_radius, by - dot_radius, bx + dot_radius, by + dot_radius],
        fill=color,
    )


def build():
    image = gradient(BLUE_LIGHT, BLUE_DARK)
    rss_mark(
        ImageDraw.Draw(image),
        origin=(0.30 * S, 0.73 * S),
        radii=[0.27 * S, 0.475 * S],
        stroke=int(0.095 * S),
        dot_radius=0.072 * S,
        color=WHITE,
    )
    return image.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    icon = build()
    assert icon.mode == "RGB", f"icon must have no alpha channel, got {icon.mode}"
    icon.save(OUTPUT)
    print(f"wrote {OUTPUT}")
