#!/usr/bin/env python3
"""Builds the game's music cues from Kevin MacLeod's CC-BY 4.0 library.

    python3 tools/fetch_music.py [--cache DIR] [--preview demo.mp3]

Downloads the source MP3s from incompetech.com (into --cache, not the repo),
cuts each cue to a seamless loop and writes assets/audio/music/<cue>.ogg plus
credits.json (shown on the in-game Credits screen).

Looping: for the chosen section, the loop length is the one (within the given
range) where the music just after the loop end best matches the loop start
(spectral self-similarity); the seam is then aligned to the sample by
cross-correlation and crossfaded. Loudness is normalized on the band phone
speakers reproduce, so every cue sounds equally loud on a phone.
"""
import argparse
import json
import subprocess
import tempfile
import urllib.parse
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "music"
SR = 32000
BASE = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/"

## cue -> (track title, section start s, loop length range s)
LOOPS = {
    "menu": ("Tempting Secrets", 12.0, (60, 90)),
    "ayodhya": ("Dhaka", 50.0, (60, 90)),
    "trials_combat": ("Vadodora", 12.0, (50, 80)),
    "forest": ("Hidden Wonders", 6.0, (60, 90)),
    "forest_combat": ("All This", 92.0, (45, 75)),
    "tataka": ("Final Battle of the Dark Wizards", 62.0, (55, 85)),
    "tataka_maya": ("Hitman", 52.0, (45, 75)),
    "bloom": ("Tempting Secrets", 110.0, (40, 60)),
}
## stinger -> (track title, start s, length s): one-shots, faded out.
STINGERS = {
    "sting_reveal": ("Discovery Hit", 0.0, 9.0),
    "sting_blessing": ("The Curtain Rises", 0.0, 14.0),
}
TARGET_DB = -21.0     # loudness above ~200 Hz (what a phone speaker plays)
XFADE = 1.2


def fetch(title, cache: Path) -> Path:
    path = cache / f"{title}.mp3"
    if not path.exists():
        url = BASE + urllib.parse.quote(f"{title}.mp3")
        subprocess.run(["curl", "-sfL", "-m", "300", "-o", str(path), url], check=True)
    return path


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "2", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).T.astype(np.float64)


def features(mono, hop=1024, win=4096):
    """Log band energies per frame (a coarse, timbre-and-harmony fingerprint)."""
    frames = []
    edges = np.geomspace(60, 8000, 33)
    f = np.fft.rfftfreq(win, 1 / SR)
    bands = [(f >= lo) & (f < hi) for lo, hi in zip(edges[:-1], edges[1:])]
    w = np.hanning(win)
    for i in range(0, len(mono) - win, hop):
        s = np.abs(np.fft.rfft(mono[i:i + win] * w)) ** 2
        frames.append([np.log(np.sum(s[b]) + 1e-9) for b in bands])
    F = np.array(frames)
    F -= F.mean(axis=1, keepdims=True)
    return F, hop


def best_loop(x, start, lo, hi, spread=15.0):
    """Searches loop starts within +-spread s of `start` and lengths in [lo, hi]."""
    mono = x.mean(axis=0)
    F, hop = features(mono)
    best, best_s, best_len = -1e9, 0, lo
    win = int(4 * SR / hop)  # compare four seconds after start and after end
    for s in range(max(int((start - spread) * SR / hop), 0), int((start + spread) * SR / hop), 4):
        ref = F[s:s + win]
        rn = np.linalg.norm(ref) + 1e-9
        for L in range(int(lo * SR / hop), int(hi * SR / hop)):
            cand = F[s + L:s + L + win]
            if len(cand) < win:
                break
            score = np.sum(ref * cand) / (rn * (np.linalg.norm(cand) + 1e-9))
            if score > best:
                best, best_s, best_len = score, s, L
    start = best_s * hop / SR
    n = best_len * hop
    # Sample-accurate alignment around the seam.
    a = int(round(start * SR))
    seg = mono[a:a + int(0.5 * SR)]
    search = int(0.03 * SR)
    region = mono[a + n - search:a + n + search + len(seg)]
    corr = np.correlate(region, seg, "valid")
    n += int(np.argmax(corr)) - search
    return a, n, best


def make_loop(x, a, n, seconds=XFADE):
    fade = int(seconds * SR)
    loop = x[:, a:a + n].copy()
    tail = x[:, a + n:a + n + fade]
    ramp = np.sin(np.linspace(0, np.pi / 2, fade)) ** 2
    loop[:, :fade] = loop[:, :fade] * ramp + tail * (1 - ramp)  # what follows the end blends into the start
    return loop


def band_rms_db(x):
    mono = x.mean(axis=0)
    X = np.fft.rfft(mono)
    f = np.fft.rfftfreq(len(mono), 1 / SR)
    X[f < 200] *= 0.05
    y = np.fft.irfft(X, len(mono))
    return 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-12)


def level(x):
    y = x * 10 ** ((TARGET_DB - band_rms_db(x)) / 20)
    peak = np.max(np.abs(y))
    return y * (0.89 / peak) if peak > 0.89 else y


def encode(x, path: Path, codec="ogg"):
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x.T, -1, 1) * 32767).astype("<i2").tobytes())
        args = ["-c:a", "libvorbis", "-q:a", "3"] if codec == "ogg" else ["-c:a", "libmp3lame", "-b:a", "160k"]
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), *args,
                        "-fflags", "+bitexact", "-map_metadata", "-1", str(path)], check=True)


def credit(title):
    return {"title": title, "author": "Kevin MacLeod (incompetech.com)",
            "license": "Creative Commons: By Attribution 4.0 License",
            "license_url": "http://creativecommons.org/licenses/by/4.0/",
            "url": BASE + urllib.parse.quote(f"{title}.mp3")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=str(Path(tempfile.gettempdir()) / "ramayana_music_src"))
    ap.add_argument("--preview", help="also write a listening demo (.mp3)")
    args = ap.parse_args()
    cache = Path(args.cache)
    cache.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    credits, cues = {}, {}
    for cue, (title, start, (lo, hi)) in LOOPS.items():
        x = decode(fetch(title, cache))
        a, n, score = best_loop(x, start, lo, hi)
        # Weaker matches get a longer crossfade so the seam stays smooth.
        loop = level(make_loop(x, a, n, XFADE if score >= 0.7 else 2.5))
        encode(loop, OUT / f"{cue}.ogg")
        cues[cue] = loop
        credits[cue] = credit(title)
        print(f"{cue:14s} {title:34s} {a / SR:6.1f}s +{n / SR:5.1f}s  match={score:.2f}  "
              f"{(OUT / f'{cue}.ogg').stat().st_size // 1024} KB")
    for cue, (title, start, length) in STINGERS.items():
        x = decode(fetch(title, cache))
        seg = x[:, int(start * SR):int((start + length) * SR)].copy()
        fade = int(1.5 * SR)
        seg[:, -fade:] *= np.linspace(1, 0, fade) ** 2
        seg = level(seg)
        encode(seg, OUT / f"{cue}.ogg")
        cues[cue] = seg
        credits[cue] = credit(title)
        print(f"{cue:14s} {title:34s} {length:.1f}s")
    (OUT / "credits.json").write_text(json.dumps(credits, indent=1) + "\n")
    if args.preview:
        order = [("menu", 14), ("ayodhya", 12), ("trials_combat", 14), ("forest", 12), ("forest_combat", 14),
                 ("sting_reveal", 6), ("tataka", 16), ("tataka_maya", 14), ("sting_blessing", 8), ("bloom", 16)]
        fade = int(1.0 * SR)
        out = None
        for cue, sec in order:
            seg = np.tile(cues[cue], (1, 2))[:, :int(sec * SR)].copy()
            if out is None:
                out = seg
                continue
            ramp = np.linspace(0, 1, fade)
            out[:, -fade:] = out[:, -fade:] * (1 - ramp) + seg[:, :fade] * ramp
            out = np.concatenate([out, seg[:, fade:]], axis=1)
        encode(out, Path(args.preview), "mp3")
        print("preview:", args.preview)


if __name__ == "__main__":
    main()
