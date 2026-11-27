"""Draws the FeedTech app icons (green tile, white ear of grain) into web/.

Run from the project root:  python tool/make_icons.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

GREEN = (22, 101, 52, 255)
WHITE = (255, 255, 255, 255)
WEB = Path(__file__).resolve().parent.parent / "web"


def grain(draw: ImageDraw.ImageDraw, cx: float, cy: float, s: float) -> None:
    """An ear of grain centred on (cx, cy); s = overall height."""
    w = s * 0.07
    draw.line([(cx, cy + s * 0.5), (cx, cy - s * 0.32)], fill=WHITE, width=max(2, int(w)))
    kernel_w, kernel_h = s * 0.16, s * 0.27
    for i, dy in enumerate([0.22, 0.0, -0.22]):
        y = cy + dy * s - s * 0.05
        for side in (-1, 1):
            # Each kernel: an ellipse rotated away from the stem.
            k = Image.new("RGBA", (int(kernel_w * 2), int(kernel_h * 2)), (0, 0, 0, 0))
            ImageDraw.Draw(k).ellipse(
                [kernel_w * 0.5, kernel_h * 0.5, kernel_w * 1.5, kernel_h * 1.5], fill=WHITE)
            k = k.rotate(-side * 35, resample=Image.BICUBIC, expand=True)
            x = cx + side * s * 0.13
            draw._image.alpha_composite(k, (int(x - k.width / 2), int(y - k.height / 2)))
    draw.ellipse([cx - kernel_w / 2, cy - s * 0.5, cx + kernel_w / 2, cy - s * 0.5 + kernel_h], fill=WHITE)


def icon(size: int, maskable: bool) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if maskable:  # full bleed; the platform applies its own mask
        d.rectangle([0, 0, size, size], fill=GREEN)
        grain(d, size / 2, size / 2, size * 0.5)
    else:
        d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.22, fill=GREEN)
        grain(d, size / 2, size / 2, size * 0.66)
    return img


if __name__ == "__main__":
    for s in (192, 512):
        icon(s, False).save(WEB / "icons" / f"Icon-{s}.png")
        icon(s, True).save(WEB / "icons" / f"Icon-maskable-{s}.png")
    icon(64, False).save(WEB / "favicon.png")
    print("icons written to", WEB)
