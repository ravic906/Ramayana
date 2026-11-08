#!/usr/bin/env python3
"""Synthesises the bow sound effects (no recorded assets needed).

    python3 tools/gen_sfx.py   # writes assets/audio/sfx/*.wav

These are prototype sounds. Final audio should be recorded and designed.
"""
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
rng = np.random.default_rng(7)


def write(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(sec, attack=0.002, decay=0.1):
    tt = t(sec)
    return np.minimum(tt / attack, 1.0) * np.exp(-tt / decay)


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def resonator(x, freq, q=30.0):
    # Two-pole resonant filter.
    w = 2 * np.pi * freq / SR
    r = np.exp(-w / (2 * q))
    a1, a2 = -2 * r * np.cos(w), r * r
    y = np.zeros_like(x)
    for i in range(len(x)):
        y[i] = x[i] - a1 * (y[i - 1] if i > 0 else 0) - a2 * (y[i - 2] if i > 1 else 0)
    return y


def karplus(freq, sec, damping=0.996, bright=0.5):
    n = int(SR / freq)
    buf = rng.uniform(-1, 1, n)
    buf = lowpass(buf, bright)
    out = np.zeros(int(SR * sec))
    for i in range(len(out)):
        out[i] = buf[i % n]
        buf[i % n] = damping * 0.5 * (buf[i % n] + buf[(i + 1) % n])
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # Nock: dry wooden click.
    nock = resonator(rng.normal(0, 1, len(t(0.06))) * env(0.06, 0.0005, 0.006), 1800, 8)
    nock += 0.6 * resonator(rng.normal(0, 1, len(t(0.06))) * env(0.06, 0.0005, 0.01), 650, 12)
    write("nock", nock)

    # Creak: stick-slip clicks through a wooden body resonance (seamless 1.2 s loop).
    sec = 1.2
    clicks = np.zeros(int(SR * sec))
    pos = 0
    while pos < len(clicks):
        clicks[pos] = rng.uniform(0.4, 1.0) * rng.choice([-1, 1])
        pos += int(SR / rng.uniform(35, 70))
    creak = resonator(clicks, 210, 25) + 0.5 * resonator(clicks, 470, 30) + 0.25 * resonator(clicks, 1150, 40)
    fade = int(SR * 0.05)
    creak[:fade] *= np.linspace(0, 1, fade)
    creak[-fade:] *= np.linspace(1, 0, fade)
    write("creak_loop", creak, 0.7)

    # Twang: plucked bowstring + low thump of the limbs.
    tw = karplus(98.0, 0.9, 0.9975, 0.6) * np.exp(-t(0.9) / 0.35)
    thump = np.sin(2 * np.pi * 70 * t(0.9)) * env(0.9, 0.001, 0.05)
    snap = rng.normal(0, 1, len(t(0.9))) * env(0.9, 0.0003, 0.004)
    write("twang", tw + 0.8 * thump + 0.5 * snap)

    # Whoosh: band-passed noise that rises and falls.
    n = rng.normal(0, 1, len(t(0.45)))
    sweep = np.sin(np.pi * np.linspace(0, 1, len(n))) ** 2
    write("whoosh", (resonator(n, 900, 3) * 0.6 + lowpass(n, 0.15)) * sweep, 0.6)

    # Impact: thud + crack.
    thud = np.sin(2 * np.pi * 85 * t(0.4) * (1 - 0.3 * t(0.4))) * env(0.4, 0.001, 0.08)
    crack = resonator(rng.normal(0, 1, len(t(0.4))) * env(0.4, 0.0003, 0.012), 2400, 5)
    write("impact", thud + 0.7 * crack)

    # Perfect release: bright inharmonic bell "ting".
    tt = t(1.4)
    bell = sum(a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / d)
               for f, a, d in [(1320, 1.0, 0.6), (2640 * 1.01, 0.5, 0.35), (3960 * 0.995, 0.3, 0.2), (1980, 0.25, 0.5)])
    write("perfect", bell * np.minimum(tt / 0.003, 1.0), 0.6)

    # Heartbeat (lub-dub), loops while Rama holds a full draw.
    hb = np.zeros(int(SR * 0.9))
    for start, amp in [(0.0, 1.0), (0.16, 0.7)]:
        s = int(start * SR)
        beat = np.sin(2 * np.pi * 55 * t(0.18)) * env(0.18, 0.004, 0.05) * amp
        hb[s:s + len(beat)] += beat
    write("heartbeat", hb, 0.8)


if __name__ == "__main__":
    main()
