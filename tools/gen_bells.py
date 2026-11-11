#!/usr/bin/env python3
"""Synthesises the forest shrine's three temple bells and a dull wrong-order
clank (inharmonic bell partials with slow decay). Writes assets/audio/sfx/."""
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
# Bell partial ratios (a church/temple bell's hum, prime, tierce, quint, nominal...).
PARTIALS = [(0.5, 0.6, 1.0), (1.0, 1.0, 0.8), (1.19, 0.5, 0.65), (1.5, 0.35, 0.5), (2.0, 0.45, 0.45),
            (2.52, 0.2, 0.35), (3.0, 0.12, 0.3), (4.07, 0.08, 0.22)]


def bell(f0, seconds=3.2):
    t = np.arange(int(SR * seconds)) / SR
    x = np.zeros_like(t)
    for ratio, amp, decay in PARTIALS:
        x += amp * np.exp(-t / (decay * seconds * 0.45)) * np.sin(2 * np.pi * f0 * ratio * t + ratio)
    strike = np.exp(-t * 60.0) * np.random.default_rng(int(f0)).normal(0, 0.15, t.size)
    x = (x + strike) * (1.0 - np.exp(-t * 400.0))
    return x / np.max(np.abs(x)) * 0.8


def clank():
    t = np.arange(int(SR * 0.6)) / SR
    x = np.exp(-t * 14.0) * (np.sin(2 * np.pi * 180 * t) + 0.6 * np.sin(2 * np.pi * 263 * t + 1.0))
    x += np.exp(-t * 80.0) * np.random.default_rng(9).normal(0, 0.4, t.size)
    return x / np.max(np.abs(x)) * 0.6


def write(name, x):
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    for i, f in enumerate([196.0, 293.66, 392.0]):  # earth (low), moon, sun (high)
        write(f"bell_{i + 1}.wav", bell(f))
    write("bell_wrong.wav", clank())
    print("bells written")
