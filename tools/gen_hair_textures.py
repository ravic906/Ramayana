#!/usr/bin/env python3
"""Strand textures for the realistic people's beards (and other hair cards).

    python3 tools/gen_hair_textures.py

Writes assets/people/hair/beard_strands.png: RGBA, strands running along V
(top = root, bottom = tip), slightly wavy, each with its own shade; alpha is
the strand coverage, thinning toward the tips. The hair shader takes its
colour per character, so the RGB here is only brightness detail.
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "people" / "hair"
W, H = 512, 512


def strands(seed: int, count: int, width: float, wave: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    img = np.zeros((H, W, 4), np.float32)
    ys = np.arange(H)
    for _ in range(count):
        x0 = rng.uniform(0, W)
        length = rng.uniform(0.55, 1.0) * H
        start = rng.uniform(0, 0.15) * H
        phase = rng.uniform(0, 6.28)
        amp = rng.uniform(0.3, 1.0) * wave
        shade = rng.uniform(0.7, 1.25)
        w = width * rng.uniform(0.6, 1.3)
        for y in ys:
            if y < start or y > start + length:
                continue
            t = (y - start) / length
            x = x0 + np.sin(phase + y * 0.035) * amp + t * rng.normal(0, 0.15)
            a = (1.0 - t ** 2.2) * 0.95
            lo, hi = int(np.floor(x - w)), int(np.ceil(x + w))
            for xi in range(lo, hi + 1):
                d = abs(xi - x) / w
                if d >= 1.0:
                    continue
                cov = a * (1.0 - d * d)
                xx = xi % W
                img[y, xx, 3] = max(img[y, xx, 3], cov)
                img[y, xx, :3] = np.maximum(img[y, xx, :3], shade * 0.5 * (1.0 - 0.35 * t))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    img = strands(7, 900, 1.5, 4.0)
    rgb = np.clip(img[..., :3], 0, 1)
    # Fill the colour under transparent texels too (no dark fringes when filtered).
    rgb[img[..., 3] < 0.01] = 0.45
    out = np.concatenate([rgb, np.clip(img[..., 3:], 0, 1)], axis=-1)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(OUT / "beard_strands.png")
    print("wrote", OUT / "beard_strands.png")


if __name__ == "__main__":
    main()
