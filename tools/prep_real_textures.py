#!/usr/bin/env python3
"""Packs Poly Haven (CC0) texture sets into mobile-friendly assets for the
Realistic visual style.

    python3 tools/prep_real_textures.py <download_dir>

Expects <key>_diff.jpg, <key>_nor.jpg (OpenGL), <key>_arm.jpg for keys:
sandstone, red, marble, dark (stone array layers 0-3) and paving.
Writes assets/env/real/:
  stone_{albedo,normal,arm}_array.png  512x2048 vertical strips (4 layers)
  paving_{albedo,normal,arm}.jpg        512x512
"""
import sys
from pathlib import Path
from PIL import Image

SIZE = 512
LAYERS = ["sandstone", "red", "marble", "dark"]  # must match the arch region masks
src = Path(sys.argv[1])
out = Path(__file__).resolve().parent.parent / "assets" / "env" / "real"
out.mkdir(parents=True, exist_ok=True)

for kind in ["diff", "nor", "arm"]:
    strip = Image.new("RGB", (SIZE, SIZE * len(LAYERS)))
    for i, key in enumerate(LAYERS):
        im = Image.open(src / f"{key}_{kind}.jpg").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        strip.paste(im, (0, i * SIZE))
    name = {"diff": "albedo", "nor": "normal", "arm": "arm"}[kind]
    strip.save(out / f"stone_{name}_array.png", optimize=True)
    # Courtyard paving uses the clean sandstone blocks set.
    Image.open(src / f"sandstone_{kind}.jpg").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(
        out / f"paving_{name}.jpg", quality=90)
print("ok")
