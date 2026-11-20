"""Hand-painted-style tileable textures for the illustrated look (gate slice).

    python3 tools/gen_painted_textures.py assets/textures/painted

Each texture is centred on mid-grey: 0.5 = no change to the material colour, so the
shader can multiply any albedo by it (see assets/shaders/toon_painted.gdshader).
Brush strokes, veins and carved bands are drawn with wrap-around so every tile is seamless.
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 512
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/textures/painted")


def wrap_draw(img, fn):
    """Calls fn(draw, dx, dy) for the 9 wrapped copies so shapes crossing an edge tile."""
    d = ImageDraw.Draw(img, "RGBA")
    for dx in (-N, 0, N):
        for dy in (-N, 0, N):
            fn(d, dx, dy)


def tile_blur(img, r):
    big = Image.new(img.mode, (N * 3, N * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * N, j * N))
    big = big.filter(ImageFilter.GaussianBlur(r))
    return big.crop((N, N, 2 * N, 2 * N))


def tile_noise(seed, scale):
    """Seamless low-frequency noise in 0..1 by filtering white noise in Fourier space."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((N, N)))
    ky = np.fft.fftfreq(N)[:, None]
    kx = np.fft.fftfreq(N)[None, :]
    k = np.sqrt(kx * kx + ky * ky)
    f *= np.exp(-(k * N / scale) ** 2)
    n = np.real(np.fft.ifft2(f))
    n = (n - n.min()) / (n.max() - n.min() + 1e-9)
    return n


def strokes(img, rng, count, length, width, colours):
    def fn(d, dx, dy, items=[]):
        for x, y, a, l, w, c in items:
            ex, ey = math.cos(a) * l / 2, math.sin(a) * l / 2
            d.line([(x - ex + dx, y - ey + dy), (x + ex + dx, y + ey + dy)], fill=c, width=w)
    items = []
    for _ in range(count):
        items.append((rng.uniform(0, N), rng.uniform(0, N), rng.uniform(-0.5, 0.5) + rng.choice([0, math.pi / 2]),
                      rng.uniform(*length), int(rng.uniform(*width)), rng.choice(colours)))
    wrap_draw(img, lambda d, dx, dy: fn(d, dx, dy, items))


def to_rgb(arr):
    return Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8), "RGB")


def stone(rng):
    """Polished marble: soft painterly mottling, warm lights and cool lows, a few veins."""
    n1, n2 = tile_noise(1, 6), tile_noise(2, 22)
    v = 0.5 + (n1 - 0.5) * 0.16 + (n2 - 0.5) * 0.1
    rgb = np.stack([v + 0.012, v + 0.004, v - 0.01], -1)
    img = to_rgb(rgb)
    strokes(img, rng, 420, (20, 70), (6, 16),
            [(140, 136, 132, 34), (150, 146, 140, 30), (118, 120, 130, 26), (134, 128, 120, 30)])
    img = tile_blur(img, 2.2)
    # Veins: soft blue-grey meanders.
    vein = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    paths = []
    for _ in range(5):
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        a = rng.uniform(0, math.tau)
        pts = []
        for _ in range(60):
            a += rng.uniform(-0.35, 0.35)
            x += math.cos(a) * 9
            y += math.sin(a) * 9
            pts.append((x, y))
        paths.append(pts)
    def draw_veins(d, dx, dy):
        for pts in paths:
            d.line([(p[0] + dx, p[1] + dy) for p in pts], fill=(92, 98, 116, 70), width=2)
    wrap_draw(vein, draw_veins)
    vein = tile_blur(vein, 1.2)
    img.paste(vein, (0, 0), vein)
    return img


def carving(rng):
    """Carved bands: a lotus-petal row over a bead row and a dentil row, lit from above."""
    img = Image.new("RGB", (N, N), (128, 128, 128))
    d = ImageDraw.Draw(img)
    rows = N // 4
    for r in range(4):
        y0 = r * rows
        # Lotus petals (half-ellipses) with a light upper rim and dark lower edge.
        for i in range(8):
            cx = i * N / 8 + N / 16
            box = [cx - 28, y0 + 10, cx + 28, y0 + rows * 0.62]
            d.pieslice([box[0], box[1], box[2], box[3] + 50], 180, 360, fill=(150, 150, 150))
            d.arc([box[0], box[1], box[2], box[3] + 50], 180, 360, fill=(196, 196, 196), width=4)
            d.line([(box[0], box[3] + 25), (box[2], box[3] + 25)], fill=(80, 80, 80), width=4)
            d.line([(cx, box[1] + 10), (cx, box[3] + 20)], fill=(110, 110, 110), width=2)
        # Bead row.
        yb = y0 + rows * 0.72
        for i in range(16):
            cx = i * N / 16 + N / 32
            d.ellipse([cx - 9, yb - 9, cx + 9, yb + 9], fill=(165, 165, 165), outline=(86, 86, 86), width=2)
            d.ellipse([cx - 5, yb - 7, cx + 1, yb - 2], fill=(205, 205, 205))
        # Dentils.
        yd = y0 + rows * 0.86
        for i in range(32):
            cx = i * N / 32
            d.rectangle([cx + 3, yd, cx + N / 32 - 3, yd + 12], fill=(140, 140, 140), outline=(84, 84, 84))
        d.line([(0, y0 + 2), (N, y0 + 2)], fill=(200, 200, 200), width=3)
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    # Painted wash on top so it reads as painted relief, not a photo.
    wash = np.asarray(img).astype(np.float32) / 255.0
    n = tile_noise(5, 10)[..., None]
    wash = wash * (0.92 + 0.16 * n)
    return to_rgb(wash)


def wood(rng):
    """Door leaves: vertical painted grain with panel lines."""
    n = tile_noise(7, 30)
    grain = np.zeros((N, N))
    xs = np.arange(N)[None, :] / N
    for k in range(9):
        f = rng.uniform(6, 22)
        ph = rng.uniform(0, math.tau)
        grain += np.sin(xs * math.tau * round(f) + ph + n * 6.0) * rng.uniform(0.2, 0.6)
    grain = (grain - grain.min()) / (grain.max() - grain.min())
    v = 0.5 + (grain - 0.5) * 0.22 + (n - 0.5) * 0.1
    img = to_rgb(np.stack([v + 0.01, v, v - 0.01], -1))
    d = ImageDraw.Draw(img)
    for x in (0, N // 2):
        d.rectangle([x + 18, 18, x + N // 2 - 18, N - 18], outline=(78, 72, 66), width=6)
        d.rectangle([x + 26, 26, x + N // 2 - 26, N - 26], outline=(176, 168, 158), width=2)
    return img.filter(ImageFilter.GaussianBlur(0.8))


def cloth(rng):
    """Woven cloth with a printed border: fine weave plus gold-ish stripes and dots."""
    yy, xx = np.mgrid[0:N, 0:N]
    weave = 0.5 + 0.05 * np.sin(xx * math.tau / 4) * np.sin(yy * math.tau / 4)
    n = tile_noise(9, 14)
    v = weave + (n - 0.5) * 0.12
    img = to_rgb(np.stack([v, v, v], -1))
    d = ImageDraw.Draw(img)
    for y in (40, 470):
        d.rectangle([0, y, N, y + 22], fill=(196, 190, 170))
        for i in range(16):
            cx = i * N / 16 + 16
            d.ellipse([cx - 5, y + 6, cx + 5, y + 16], fill=(96, 90, 80))
    for i in range(4):
        for j in range(4):
            cx, cy = i * 128 + 64, j * 128 + 64 + 30
            if 70 < cy < 440:
                for k in range(6):
                    a = k * math.tau / 6
                    d.ellipse([cx + math.cos(a) * 12 - 6, cy + math.sin(a) * 12 - 6, cx + math.cos(a) * 12 + 6,
                               cy + math.sin(a) * 12 + 6], fill=(170, 164, 150))
                d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(90, 84, 76))
    return img.filter(ImageFilter.GaussianBlur(0.7))


def gold(rng):
    """Hammered gold: soft dents and a few bright speckles."""
    n = tile_noise(11, 40)
    v = 0.5 + (n - 0.5) * 0.18
    img = to_rgb(np.stack([v, v, v], -1))
    def fn(d, dx, dy, pts=[(rng.uniform(0, N), rng.uniform(0, N)) for _ in range(160)]):
        for x, y in pts:
            d.ellipse([x - 3 + dx, y - 3 + dy, x + 3 + dx, y + 3 + dy], fill=(220, 220, 220, 120))
    wrap_draw(img, fn)
    return tile_blur(img, 1.0)


def ground(rng):
    """Courtyard earth beyond the paving: dusty ochre with grass flecks."""
    n1, n2 = tile_noise(13, 5), tile_noise(14, 28)
    v = 0.5 + (n1 - 0.5) * 0.2 + (n2 - 0.5) * 0.12
    img = to_rgb(np.stack([v, v, v], -1))
    strokes(img, rng, 900, (6, 18), (2, 4), [(110, 140, 90, 60), (150, 150, 120, 50), (100, 96, 90, 40)])
    return tile_blur(img, 1.0)


def main():
    rng = random.Random(3)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in (("stone", stone), ("carving", carving), ("wood", wood), ("cloth", cloth),
                     ("gold", gold), ("ground", ground)):
        fn(rng).save(OUT / f"paint_{name}.png")
        print("wrote", OUT / f"paint_{name}.png")


main()
