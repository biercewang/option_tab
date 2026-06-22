#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
ICONSET = ROOT / ".build" / "AppIcon.iconset"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/Library/Fonts/Avenir Next.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=1 if bold and path.endswith(".ttc") else 0)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        r = round(top[0] * (1 - t) + bottom[0] * t)
        g = round(top[1] * (1 - t) + bottom[1] * t)
        b = round(top[2] * (1 - t) + bottom[2] * t)
        for x in range(size):
            pixels[x, y] = (r, g, b)
    return image.convert("RGBA")


def cubic_point(points: list[tuple[float, float]], t: float) -> tuple[float, float]:
    p0, p1, p2, p3 = points
    u = 1 - t
    x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
    y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
    return x, y


def render_icon(size: int = 1024) -> Image.Image:
    scale = size / 1024
    margin = round(74 * scale)
    radius = round(210 * scale)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    base_box = (margin, margin, size - margin, size - margin)
    base_size = size - margin * 2
    base_mask = rounded_mask(base_size, radius)

    shadow = Image.new("RGBA", (base_size, base_size), (0, 0, 0, 185))
    shadow.putalpha(base_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(28 * scale)))
    canvas.alpha_composite(shadow, (margin, round(margin + 28 * scale)))

    base = vertical_gradient(base_size, (29, 40, 70), (7, 11, 23))
    base.putalpha(base_mask)
    canvas.alpha_composite(base, (margin, margin))

    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rim_draw = ImageDraw.Draw(rim)
    rim_draw.rounded_rectangle(
        base_box,
        radius=radius,
        outline=(255, 255, 255, 48),
        width=round(5 * scale),
    )
    rim_draw.rounded_rectangle(
        (margin + 14 * scale, margin + 14 * scale, size - margin - 14 * scale, size - margin - 14 * scale),
        radius=round(radius * 0.92),
        outline=(88, 232, 208, 26),
        width=round(3 * scale),
    )
    canvas.alpha_composite(rim)

    text_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    text_draw = ImageDraw.Draw(text_layer)
    text = "AG"
    text_font = font(round(342 * scale), bold=True)
    bbox = text_draw.textbbox((0, 0), text, font=text_font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (size - tw) / 2 - round(12 * scale)
    ty = (size - th) / 2 - round(68 * scale)
    text_draw.text((tx + 10 * scale, ty + 14 * scale), text, font=text_font, fill=(0, 0, 0, 92))
    text_draw.text((tx, ty), text, font=text_font, fill=(248, 251, 255, 238))
    canvas.alpha_composite(text_layer)

    path = [
        (228 * scale, 706 * scale),
        (328 * scale, 505 * scale),
        (622 * scale, 849 * scale),
        (804 * scale, 356 * scale),
    ]
    samples = [cubic_point(path, i / 80) for i in range(81)]

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.line(samples, fill=(67, 235, 213, 155), width=round(46 * scale), joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(round(22 * scale)))
    canvas.alpha_composite(glow)

    stroke = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    stroke_draw = ImageDraw.Draw(stroke)
    stroke_draw.line(samples, fill=(70, 240, 220, 255), width=round(22 * scale), joint="curve")
    stroke_draw.line(samples, fill=(169, 255, 242, 255), width=round(8 * scale), joint="curve")
    for idx, point in enumerate([samples[0], samples[28], samples[56], samples[-1]]):
        r = round((18 if idx in (0, 3) else 13) * scale)
        stroke_draw.ellipse(
            (point[0] - r, point[1] - r, point[0] + r, point[1] + r),
            fill=(245, 255, 252, 255),
            outline=(28, 192, 180, 255),
            width=round(5 * scale),
        )
    canvas.alpha_composite(stroke)

    mouse = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mouse_draw = ImageDraw.Draw(mouse)
    mx, my = round(702 * scale), round(202 * scale)
    mw, mh = round(170 * scale), round(238 * scale)
    mouse_draw.rounded_rectangle(
        (mx, my, mx + mw, my + mh),
        radius=round(68 * scale),
        fill=(238, 244, 255, 238),
        outline=(255, 255, 255, 190),
        width=round(5 * scale),
    )
    mouse_draw.line((mx + mw / 2, my + 22 * scale, mx + mw / 2, my + 92 * scale), fill=(19, 29, 55, 210), width=round(5 * scale))
    mouse_draw.line((mx + mw / 2, my + 96 * scale, mx + mw / 2, my + 132 * scale), fill=(19, 29, 55, 70), width=round(3 * scale))
    mouse_draw.rounded_rectangle(
        (mx + mw / 2 + 8 * scale, my + 22 * scale, mx + mw - 20 * scale, my + 92 * scale),
        radius=round(28 * scale),
        fill=(70, 240, 220, 92),
    )
    mouse = mouse.filter(ImageFilter.GaussianBlur(0.25))
    canvas.alpha_composite(mouse)

    shine = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.ellipse(
        (180 * scale, 115 * scale, 790 * scale, 520 * scale),
        fill=(255, 255, 255, 22),
    )
    shine = shine.filter(ImageFilter.GaussianBlur(round(24 * scale)))
    canvas.alpha_composite(shine)

    return canvas


def main() -> None:
    RESOURCES.mkdir(exist_ok=True)
    ICONSET.mkdir(parents=True, exist_ok=True)

    icon = render_icon(1024)
    icon.save(RESOURCES / "AppIcon.png")

    specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for name, output_size in specs:
        resized = icon.resize((output_size, output_size), Image.Resampling.LANCZOS)
        resized.save(ICONSET / name)

    output = RESOURCES / "AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(output)], check=True)
    shutil.rmtree(ICONSET)
    print(output)


if __name__ == "__main__":
    main()
