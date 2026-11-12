#!/usr/bin/env python3
"""Writes the colour grades (3D LUTs, 32^3) used by the scenes' environments.

    python3 tools/make_luts.py

Each grade is a 1024x32 PNG strip (32 slices along blue) imported as a
Texture3D and set as Environment.adjustment_color_correction. Grades are
gentle, film-like: a soft S-curve, cool shadows and warm highlights (split
toning), greens held back so skin and saffron carry the frame.
"""
from pathlib import Path

import numpy as np
from PIL import Image

N = 32
OUT = Path(__file__).resolve().parent.parent / "assets" / "grading"

## name -> (contrast, shadow tint, highlight tint, saturation, green hold, lift)
GRADES = {
    "neutral": (0.0, (0, 0, 0), (0, 0, 0), 1.0, 0.0, 0.0),
    "day_warm": (0.18, (-0.012, 0.0, 0.018), (0.03, 0.012, -0.02), 1.04, 0.10, 0.012),
    "dusk_gold": (0.22, (-0.015, -0.004, 0.03), (0.045, 0.015, -0.03), 1.02, 0.14, 0.015),
    "dawn_pale": (0.12, (0.0, 0.004, 0.022), (0.03, 0.02, -0.006), 0.94, 0.08, 0.02),
    "night_blue": (0.2, (-0.01, 0.0, 0.035), (0.03, 0.01, -0.02), 0.9, 0.12, 0.01),
}


def grade(rgb, contrast, sh, hi, sat, green_hold, lift):
    c = rgb.copy()
    lum = c @ np.array([0.2126, 0.7152, 0.0722])
    # Split toning, weighted by luminance.
    w_hi = np.clip((lum - 0.35) / 0.5, 0, 1)[..., None]
    w_sh = np.clip((0.55 - lum) / 0.5, 0, 1)[..., None]
    c = c + w_sh * np.array(sh) + w_hi * np.array(hi)
    # Soft S-curve around the middle grey.
    x = np.clip(c, 0, 1)
    s = x + contrast * (x - 0.5) * (1 - np.abs(2 * x - 1))
    # Saturation, with greens held back.
    lum = s @ np.array([0.2126, 0.7152, 0.0722])
    s = lum[..., None] + (s - lum[..., None]) * sat
    green = np.clip(s[..., 1] - np.maximum(s[..., 0], s[..., 2]), 0, 1)[..., None]
    s = s - green * green_hold * np.array([0.0, 1.0, 0.0])
    # Lifted blacks (film stock never reaches pure black).
    s = lift + s * (1 - lift)
    return np.clip(s, 0, 1)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    g = np.linspace(0, 1, N)
    b, gg, r = np.meshgrid(g, g, g, indexing="ij")  # [blue, green, red]
    rgb = np.stack([r, gg, b], axis=-1)
    for name, params in GRADES.items():
        out = grade(rgb, *params)
        # Strip: width = N slices * N (red), height = N (green); slice = blue.
        strip = np.concatenate([out[k] for k in range(N)], axis=1)
        Image.fromarray((strip * 255 + 0.5).astype(np.uint8), "RGB").save(OUT / f"{name}.png")
        imp = OUT / f"{name}.png.import"
        imp.write_text(
            '[remap]\n\nimporter="3d_texture"\ntype="CompressedTexture3D"\n\n[params]\n\n'
            "compress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\n"
            "compress/hdr_compression=1\ncompress/channel_pack=0\nmipmaps/generate=false\n"
            "mipmaps/limit=-1\nslices/horizontal=32\nslices/vertical=1\n")
        print(name)


if __name__ == "__main__":
    main()
