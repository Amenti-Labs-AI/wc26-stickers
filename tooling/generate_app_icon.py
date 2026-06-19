#!/usr/bin/env python3
"""Build launcher icons from the Amenti Labs logo mark."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"
MASTER = BRANDING / "app_icon.png"
FOREGROUND = BRANDING / "app_icon_foreground.png"
MARK_UI = BRANDING / "amenti_logo_mark.png"
SIZE = 1024

# Amenti brand — emerald mark on deep forest background (#021a14 meta theme).
BG_TOP = (2, 26, 20)
BG_BOTTOM = (1, 10, 8)
MARK = (4, 120, 87, 255)
RING = (255, 255, 255, 28)

# SVG viewBox for logo-mark.svg
MARK_W = 52.0
MARK_H = 42.0


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def gradient_background(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        color = (
            _lerp(BG_TOP[0], BG_BOTTOM[0], t),
            _lerp(BG_TOP[1], BG_BOTTOM[1], t),
            _lerp(BG_TOP[2], BG_BOTTOM[2], t),
        )
        for x in range(size):
            px[x, y] = color
    return img


def render_amenti_mark(size: int, *, width_ratio: float = 0.52) -> Image.Image:
    target_w = int(size * width_ratio)
    scale = target_w / MARK_W
    target_h = max(1, int(MARK_H * scale))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    ox = (size - target_w) / 2
    oy = (size - target_h) / 2

    def pt(x: float, y: float) -> tuple[float, float]:
        return (ox + x * scale, oy + y * scale)

    draw.polygon(
        [pt(26, 12), pt(3, 30), pt(29, 30)],
        fill=MARK,
    )
    draw.polygon(
        [pt(26, 12), pt(35, 30), pt(49, 30)],
        fill=MARK,
    )
    return canvas


def build_master(mark: Image.Image) -> Image.Image:
    base = gradient_background(SIZE)

    vignette = Image.new("L", (SIZE, SIZE), 0)
    vdraw = ImageDraw.Draw(vignette)
    vdraw.ellipse((-120, -120, SIZE + 120, SIZE + 120), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(90))
    base = Image.composite(
        Image.new("RGB", (SIZE, SIZE), (0, 0, 0)),
        base,
        Image.eval(vignette, lambda p: 255 - int(p * 0.22)),
    )

    composed = base.convert("RGBA")
    ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring)
    inset = int(SIZE * 0.08)
    ring_draw.ellipse(
        (inset, inset, SIZE - inset, SIZE - inset),
        outline=RING,
        width=5,
    )
    composed.alpha_composite(ring)
    composed.alpha_composite(mark)
    return composed.convert("RGB")


def build_foreground(mark: Image.Image) -> Image.Image:
    return mark.copy()


def main() -> None:
    BRANDING.mkdir(parents=True, exist_ok=True)

    mark = render_amenti_mark(SIZE, width_ratio=0.50)
    master = build_master(mark)
    foreground = build_foreground(render_amenti_mark(SIZE, width_ratio=0.58))

    master.save(MASTER, optimize=True)
    foreground.save(FOREGROUND, optimize=True)

    ui_mark = render_amenti_mark(256, width_ratio=0.62)
    ui_mark.save(MARK_UI, optimize=True)

    print(f"Wrote {MASTER}")
    print(f"Wrote {FOREGROUND}")
    print(f"Wrote {MARK_UI}")


if __name__ == "__main__":
    main()
