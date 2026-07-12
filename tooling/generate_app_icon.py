#!/usr/bin/env python3
"""Build WC26 launcher + in-app icons from the stacked 20/26 logo source."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"
SOURCE = BRANDING / "wc26_logo_source.png"
MASTER = BRANDING / "app_icon.png"
FOREGROUND = BRANDING / "app_icon_foreground.png"
IN_APP = BRANDING / "wc26_logo.png"
SIZE = 1024
IN_APP_SIZE = 256

# Near-black treated as background when extracting the mark.
BG_LUMA_MAX = 28


def _luma(r: int, g: int, b: int) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def load_source() -> Image.Image:
    if not SOURCE.exists():
        raise SystemExit(f"Missing source logo: {SOURCE}")
    return Image.open(SOURCE).convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def extract_mark(src: Image.Image) -> Image.Image:
    """Keep light/gold mark pixels; make near-black background transparent."""
    px = src.load()
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    out_px = out.load()
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if _luma(r, g, b) <= BG_LUMA_MAX:
                continue
            out_px[x, y] = (r, g, b, a)
    return out


def content_bbox(mark: Image.Image) -> tuple[int, int, int, int]:
    alpha = mark.split()[-1]
    bbox = alpha.getbbox()
    if bbox is None:
        raise SystemExit("Logo mark extraction produced an empty image")
    return bbox


def fit_mark(
    mark: Image.Image,
    canvas_size: int,
    *,
    width_ratio: float,
) -> Image.Image:
    left, top, right, bottom = content_bbox(mark)
    cropped = mark.crop((left, top, right, bottom))
    target_w = max(1, int(canvas_size * width_ratio))
    scale = target_w / cropped.size[0]
    target_h = max(1, int(cropped.size[1] * scale))
    resized = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ox = (canvas_size - target_w) // 2
    oy = (canvas_size - target_h) // 2
    canvas.alpha_composite(resized, (ox, oy))
    return canvas


def build_master(src: Image.Image) -> Image.Image:
    """Full launcher icon: black square with stacked 20/26 mark."""
    return src.convert("RGB")


def build_foreground(mark: Image.Image) -> Image.Image:
    """Adaptive-icon foreground with safe-zone padding."""
    # Soft edge so downscales stay crisp.
    return mark.filter(ImageFilter.SMOOTH_MORE)


def main() -> None:
    BRANDING.mkdir(parents=True, exist_ok=True)
    src = load_source()
    mark = extract_mark(src)

    master = build_master(src)
    foreground = build_foreground(fit_mark(mark, SIZE, width_ratio=0.72))
    in_app = fit_mark(mark, IN_APP_SIZE, width_ratio=0.88)

    master.save(MASTER, optimize=True)
    foreground.save(FOREGROUND, optimize=True)
    in_app.save(IN_APP, optimize=True)

    print(f"Wrote {MASTER}")
    print(f"Wrote {FOREGROUND}")
    print(f"Wrote {IN_APP}")


if __name__ == "__main__":
    main()
