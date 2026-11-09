#!/usr/bin/env python3
"""Synthesises Part 1's music in code (no recorded assets needed).

    python3 tools/gen_music.py                     # writes assets/audio/music/*.ogg
    python3 tools/gen_music.py --preview demo.mp3  # also mixes a listening demo

Every track is a set of loop-exact stems that share one tempo and key, so the
game can layer them (the Music autoload blends "explore" and "combat" by fight
intensity). Instruments are modelled simply: tanpura (with a sweeping
"jawari" buzz), bansuri (breath, vibrato and meend glides), santoor/veena
plucks, tabla, mridangam, dhol, deep barrel drums and an "aah" chorus.
Melodies are walked through each raga's notes with a fixed seed.

These are placeholders until the soundtrack is composed and recorded. Needs
numpy and ffmpeg (with libvorbis).
"""
import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 32000
LOOP = 48.0          # seconds per loop (whole rhythmic cycles in every track)
TAIL = 7.0           # decays past the loop end wrap onto its start
SA = 146.83          # tonic (D3) shared by every track
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "music"

RAGAS = {
    # semitones above Sa; "rest" = notes phrases like to end on (nyas).
    "yaman": {"notes": [0, 2, 4, 6, 7, 9, 11], "rest": [0, 4, 7, 11]},
    "malkauns": {"notes": [0, 3, 5, 8, 10], "rest": [0, 5, 3]},
    "bhupali": {"notes": [0, 2, 4, 7, 9], "rest": [0, 4, 7, 9]},
}


def hz(semi, octave=0):
    return SA * 2.0 ** ((semi + 12 * octave) / 12.0)


def tt(sec):
    return np.arange(int(SR * sec)) / SR


def fft_filter(x, lo, hi, soft=0.2):
    """Band-pass with soft edges (lo/hi in Hz; None for open)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    if lo:
        m *= 1 / (1 + np.exp(-(f - lo) / (lo * soft)))
    if hi:
        m *= 1 / (1 + np.exp((f - hi) / (hi * soft)))
    return np.fft.irfft(X * m, len(x))


class Stem:
    """A stereo buffer one loop long, plus a tail that wraps onto the start."""

    def __init__(self):
        self.n = int(LOOP * SR)
        self.buf = np.zeros((2, self.n + int(TAIL * SR)))

    def add(self, x, start, pan=0.0, gain=1.0):
        i = int(round((start % LOOP) * SR))
        x = np.asarray(x) * gain
        j = min(i + len(x), self.buf.shape[1])
        a = (pan + 1) * np.pi / 4
        self.buf[0, i:j] += x[: j - i] * np.cos(a)
        self.buf[1, i:j] += x[: j - i] * np.sin(a)

    def render(self, rms_db=-24.0):
        y = self.buf[:, : self.n].copy()
        y[:, : self.buf.shape[1] - self.n] += self.buf[:, self.n:]
        # Phone speakers can't reproduce deep bass: cut it so the level that
        # remains is what players actually hear.
        y = np.stack([fft_filter(ch, 65, None, 0.15) for ch in y])
        # Loudness as a phone speaker hears it (above ~200 Hz), so every track
        # sounds equally loud whatever its bass content.
        audible = np.stack([fft_filter(ch, 200, None, 0.15) for ch in y])
        rms = np.sqrt(np.mean(audible ** 2)) + 1e-12
        y *= 10 ** (rms_db / 20) / rms
        ceiling = 10 ** (-1.0 / 20)
        if np.max(np.abs(y)) > ceiling * 0.8:
            knee = ceiling * 0.8
            over = np.abs(y) > knee
            y[over] = np.sign(y[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(y[over]) - knee) / (ceiling - knee)))
        return y


# --- Instruments ---------------------------------------------------------------

def pluck(f, dur=1.6, bright=0.6, decay=1.2, nharm=10, inharm=0.0004, rng=None):
    t = tt(dur)
    k = np.arange(1, nharm + 1)[:, None]
    fk = f * k * np.sqrt(1 + inharm * k ** 2)
    keep = (fk[:, 0] < SR * 0.45)
    amp = (bright ** (k - 1)) / np.sqrt(k)
    x = np.sum((amp * np.sin(2 * np.pi * fk * t) * np.exp(-t * (1 + 0.7 * k) / decay))[keep], axis=0)
    x *= np.minimum(t / 0.002, 1.0)
    if rng is not None:
        click = rng.standard_normal(int(0.004 * SR)) * np.linspace(1, 0, int(0.004 * SR)) * 0.15
        x[: len(click)] += click
    return x


def santoor(f, rng, dur=1.8):
    return _mix(pluck(f, dur, 0.72, 1.5, 9, 0.0006, rng), 0.6 * pluck(f * 1.0035, dur, 0.6, 1.3, 7, 0.0006))


def veena(f, rng, dur=1.4):
    return pluck(f, dur, 0.5, 1.1, 14, 0.0002, rng)


def tanpura(f, rng, dur=6.0):
    t = tt(dur)
    k = np.arange(1, 25)[:, None]
    centre = 3 + 12 * (1 - np.exp(-t / 1.4))  # the jawari buzz sweeps upward
    weight = 0.3 + np.exp(-((k - centre) ** 2) / 7.0)
    detune = 1 + rng.uniform(-0.0006, 0.0006, size=(24, 1))
    amp = 1 / k ** 0.8
    x = np.sum(amp * weight * np.sin(2 * np.pi * f * k * detune * t + rng.uniform(0, 6.28, (24, 1)))
               * np.exp(-t / (3.8 / (1 + 0.04 * k))), axis=0)
    return x * np.minimum(t / 0.01, 1.0)


def bansuri(notes, beat, rng, breath=0.05):
    """notes: [(semi, octave, beats)]; a legato phrase with meend and vibrato."""
    total = sum(b for _, _, b in notes) * beat + 0.4
    n = int(total * SR)
    freq = np.zeros(n)
    amp = np.zeros(n)
    pos = 0
    prev = None
    for semi, octave, beats in notes:
        m = int(beats * beat * SR)
        f = hz(semi, octave)
        seg = np.full(m, f)
        if prev is not None:  # meend: glide in from the previous note
            g = min(int(0.09 * SR), m)
            seg[:g] = np.exp(np.linspace(np.log(prev), np.log(f), g))
        local = np.arange(m) / SR
        vib = 1 + 0.011 * np.clip((local - 0.3) / 0.4, 0, 1) * np.sin(2 * np.pi * 5.1 * local)
        freq[pos:pos + m] = seg * vib
        a = np.minimum(local / 0.05, 1.0) * (0.9 + 0.1 * np.exp(-local / 0.3))
        a[-min(int(0.03 * SR), m):] *= 0.85
        amp[pos:pos + m] = a
        pos += m
        prev = f
    freq[pos:] = prev
    amp[pos:] = amp[pos - 1] * np.exp(-np.arange(n - pos) / (0.12 * SR))
    amp[:int(0.08 * SR)] *= np.linspace(0, 1, int(0.08 * SR))
    phase = np.cumsum(2 * np.pi * freq / SR)
    tone = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.07 * np.sin(3 * phase)
    air = fft_filter(rng.standard_normal(n), 1200, 5000) * breath * 6
    return (tone + air) * amp


def membrane(f, decay, harm=(1.0, 0.5, 0.25), ratios=(1, 2, 3), dur=None, bend=0.0):
    dur = dur or decay * 5
    t = tt(dur)
    fcur = f * (1 + bend * np.exp(-t / 0.05))
    phase = np.cumsum(2 * np.pi * fcur / SR)
    x = sum(a * np.sin(r * phase) * np.exp(-t * (1 + i) / decay) for i, (a, r) in enumerate(zip(harm, ratios)))
    return x * np.minimum(t / 0.0015, 1.0)


def noise_hit(rng, dur, lo, hi, decay):
    t = tt(dur)
    return fft_filter(rng.standard_normal(len(t)), lo, hi) * np.exp(-t / decay)


def tabla(bol, rng):
    f = hz(0, 1)  # dayan tuned to Sa

    def na():
        return _mix(membrane(f, 0.16, (1, 0.55, 0.3)), 0.4 * noise_hit(rng, 0.03, 2000, 8000, 0.006))

    def tin():
        return membrane(f, 0.32, (1, 0.25, 0.1)) * 0.8

    def ta():
        return _mix(membrane(f, 0.06, (1, 0.6, 0.4)), 0.5 * noise_hit(rng, 0.02, 2500, 9000, 0.004))

    def ge():
        t = tt(0.9)
        gf = 100 * np.exp(-t / 0.25) + 76  # bayan: the heel bends the pitch down
        return np.sin(np.cumsum(2 * np.pi * gf / SR)) * np.exp(-t / 0.32) * 1.2

    if bol == "dha":
        return _mix(na(), ge())
    if bol in ("dhin", "dhi"):
        return _mix(tin(), ge())
    if bol == "ke":
        return noise_hit(rng, 0.05, 150, 900, 0.015) * 0.8
    if bol == "ti":
        return ta() * 0.7
    return {"na": na, "tin": tin, "ta": ta, "ge": ge}[bol]()


def mridangam(bol, rng):
    f = hz(0, 0) * 1.5
    if bol in ("tha", "thom"):
        tha = membrane(92, 0.12, (1, 0.3), (1, 2)) * 1.3
        return tha if bol == "tha" else _mix(tha, membrane(f, 0.4, (1, 0.3, 0.15)))
    if bol == "nam":
        return _mix(membrane(f, 0.22, (1, 0.6, 0.35), (1, 2.02, 3.01)), 0.3 * noise_hit(rng, 0.02, 2000, 7000, 0.005))
    if bol == "dhi":
        return membrane(f, 0.4, (1, 0.3, 0.15))
    return _mix(membrane(f * 1.4, 0.05, (1, 0.5)), 0.6 * noise_hit(rng, 0.03, 1500, 7000, 0.006))


def dhol(rng, big=False):
    if big:  # the boss's barrel drums
        boom = membrane(62, 0.7, (1, 0.45, 0.2), (1, 2.1, 3.3), dur=2.2, bend=0.55) * 1.6
        return _mix(boom, 0.5 * noise_hit(rng, 0.25, 60, 400, 0.06))
    return _mix(membrane(82, 0.35, (1, 0.4), (1, 2.3), bend=0.35), 0.45 * noise_hit(rng, 0.06, 700, 3500, 0.02))


def chorus(freqs, dur, rng, attack=0.9, release=1.6, wobble=0.0):
    """An "aah" choir chord: band-limited saws through vowel formants."""
    t = tt(dur + release)
    out = np.zeros(len(t))
    formants = ((700, 110, 1.0), (1150, 140, 0.55), (2800, 220, 0.25))
    for f in freqs:
        for cents in (-7, 0, 6):
            fv = f * 2 ** (cents / 1200) * (1 + 0.004 * np.sin(2 * np.pi * rng.uniform(4.5, 5.5) * t))
            if wobble:
                fv *= 2 ** (wobble * np.sin(2 * np.pi * rng.uniform(0.15, 0.3) * t + rng.uniform(0, 6)) / 12)
            phase = np.cumsum(2 * np.pi * fv / SR)
            for k in range(1, int(4500 / f) + 1):
                w = sum(g * np.exp(-((k * f - c) ** 2) / (2 * bw ** 2)) for c, bw, g in formants) + 0.02
                out += w / k * np.sin(k * phase)
    env = np.minimum(t / attack, 1.0) * np.clip((dur + release - t) / release, 0, 1)
    return out * env


def wind(rng, dur):
    t = tt(dur)
    x = fft_filter(rng.standard_normal(len(t)), 180, 900)
    mod = 0.55 + 0.45 * np.sin(2 * np.pi * 0.07 * t) * np.sin(2 * np.pi * 0.023 * t + 1)
    return x * mod


def _mix(a, b):
    n = max(len(a), len(b))
    y = np.zeros(n)
    y[: len(a)] += a
    y[: len(b)] += b
    return y


# --- Composition helpers ---------------------------------------------------------

def scale_range(raga, low_oct=-1, high_oct=1, top=0):
    """All raga notes from low_oct up to Sa of high_oct (+ `top` extra steps)."""
    out = [(s, o) for o in range(low_oct, high_oct) for s in RAGAS[raga]["notes"]]
    out.append((0, high_oct))
    for s in RAGAS[raga]["notes"][1: 1 + top]:
        out.append((s, high_oct))
    return out


def phrase(raga, rng, rng_notes, start_idx, beats_choices, length):
    """A melodic phrase: a stepwise walk ending on a resting note."""
    notes = []
    idx = start_idx
    direction = rng.choice([-1, 1])
    for i in range(length):
        if i < length - 1:
            notes.append((*rng_notes[idx], float(rng.choice(beats_choices))))
            step = int(rng.choice([1, 1, 1, 2, 0], p=[0.35, 0.25, 0.15, 0.15, 0.10]))
            if rng.random() < 0.25:
                direction = -direction
            idx = int(np.clip(idx + direction * step, 0, len(rng_notes) - 1))
            if idx in (0, len(rng_notes) - 1):
                direction = -direction
    rests = [i for i, (s, o) in enumerate(rng_notes) if s in RAGAS[raga]["rest"]]
    end = min(rests, key=lambda r: abs(r - idx))
    notes.append((*rng_notes[end], float(rng.choice([2, 3, 4]))))
    return notes, end


def melody(stem, raga, rng, beat, start, end, gain, pan, beats_choices, gap=(2, 6),
           octave_shift=0, breath=0.05, length=(3, 7)):
    notes = scale_range(raga)
    if octave_shift:
        notes = [(s, o + octave_shift) for s, o in notes]
    idx = len(notes) // 2
    t = start
    while True:
        n = int(rng.integers(length[0], length[1] + 1))
        ph, idx = phrase(raga, rng, notes, idx, beats_choices, n)
        dur = sum(b for _, _, b in ph) * beat
        if t + dur > end:
            break
        stem.add(bansuri(ph, beat, rng, breath), t, pan, gain)
        t += dur + int(rng.integers(gap[0], gap[1] + 1)) * beat
        idx = int(np.clip(idx + rng.integers(-2, 3), 0, len(notes) - 1))


def drone(stem, rng, first_note, cycle=4.0, gain=0.5, octave=-1):
    """Tanpura: first string (Pa or Ma), two Sa, then low Sa, repeating."""
    strings = [hz(first_note, octave), hz(0, octave + 1), hz(0, octave + 1), hz(0, octave)]
    t = 0.0
    i = 0
    while t < LOOP - 0.01:
        stem.add(tanpura(strings[i % 4], rng), t + rng.uniform(0, 0.02), [-0.3, 0.2, 0.3, -0.1][i % 4], gain)
        t += cycle / 4
        i += 1


TEENTAL = "dha dhin dhin dha dha dhin dhin dha dha tin tin ta ta dhin dhin dha".split()
KEHERWA = "dha ge na ti na ke dhi na".split()


def taal(stem, rng, bols, beat, gain, pan=0.0, fills=True, fill_bols=("ti", "ta", "ke", "ta")):
    cycle = len(bols) * beat
    cycles = int(round(LOOP / cycle))
    for c in range(cycles):
        for i, bol in enumerate(bols):
            t = c * cycle + i * beat
            accent = 1.15 if i == 0 else 1.0
            stem.add(tabla(bol, rng), t + rng.uniform(0, 0.006), pan, gain * accent)
            if fills and i >= len(bols) - 4 and c % 2 == 1:  # a quick fill into sam
                stem.add(tabla(fill_bols[i % len(fill_bols)], rng), t + beat / 2, pan, gain * 0.6)


# --- Tracks --------------------------------------------------------------------

def track_menu():
    rng = np.random.default_rng(11)
    s = Stem()
    drone(s, rng, 7, 4.0, 0.45)
    melody(s, "yaman", rng, 0.75, 2.0, LOOP + 2.0, 0.55, 0.1, [1, 2, 2, 3], gap=(3, 6), breath=0.06)
    for k in range(6):  # sparse santoor answers
        t0 = 6 + k * 8.0
        for j, (semi, octv) in enumerate([(0, 1), (4, 1), (7, 1), (11, 1), (2, 2)][: 3 + k % 3]):
            s.add(santoor(hz(semi, octv), rng), t0 + j * 0.19, 0.4, 0.22)
    return {"main": s.render()}


def track_ayodhya():
    rng = np.random.default_rng(21)
    beat = 0.5  # 120 bpm; 6 cycles of teental = 48 s
    ex = Stem()
    drone(ex, rng, 7, 4.0, 0.42)
    melody(ex, "yaman", rng, beat, 1.0, LOOP + 3.0, 0.5, 0.15, [1, 1, 2, 2, 3], gap=(3, 7))
    notes = scale_range("yaman", 0, 2)
    for k in range(12):  # santoor phrases answering the flute
        t0 = 3.0 + k * 4.0
        i0 = int(rng.integers(0, 6))
        for j in range(4):
            semi, octv = notes[min(i0 + j * (1 if k % 2 else 2), len(notes) - 1)]
            ex.add(santoor(hz(semi, octv), rng), t0 + j * beat / 2, -0.35, 0.18)
    cb = Stem()
    taal(cb, rng, TEENTAL, beat, 0.75, -0.1)
    pattern = [(0, 0), (2, 0), (4, 0), (6, 0), (7, 0), (6, 0), (4, 0), (2, 0)]
    for i in range(int(LOOP / (beat / 2))):
        if i % 32 < 28:  # the ostinato breathes before each sam
            semi, octv = pattern[(i + (i // 16) * 2) % 8]
            cb.add(santoor(hz(semi, octv), rng, 1.0), i * beat / 2, 0.35, 0.16 if i % 4 else 0.24)
    for c in range(6):
        cb.add(dhol(rng), c * 16 * beat, 0.0, 0.7)
    return {"explore": ex.render(), "combat": cb.render(-25)}


def track_forest():
    rng = np.random.default_rng(31)
    beat = 60 / 90  # 90 bpm; 9 cycles of keherwa = 48 s
    ex = Stem()
    drone(ex, rng, 5, 6.0, 0.4, octave=-1)
    drone(ex, rng, 5, 8.0, 0.16, octave=0)
    ex.add(wind(rng, LOOP + 2), 0, 0.0, 0.05)
    melody(ex, "malkauns", rng, beat, 4.0, LOOP + 3.0, 0.42, -0.2, [2, 2, 3, 4], gap=(4, 9),
           octave_shift=-1, breath=0.11, length=(2, 5))
    for k in range(6):  # a deep veena note in the dark
        ex.add(veena(hz(0, -1), rng, 3.0), k * 8.0 + 1.0, 0.25, 0.3)
    cb = Stem()
    bols = ["thom", "ta", "nam", "ta", "dhi", "ta", "nam", "tha"]
    cycle = 8 * beat
    for c in range(9):
        for i, bol in enumerate(bols):
            cb.add(mridangam(bol, rng), c * cycle + i * beat + rng.uniform(0, 0.005), -0.15, 0.7)
            if i % 2 == 1:
                cb.add(mridangam("ta", rng), c * cycle + (i + 0.5) * beat, -0.15, 0.35)
        cb.add(dhol(rng), c * cycle, 0.1, 0.8)
        cb.add(dhol(rng), c * cycle + 3.5 * beat, 0.1, 0.5)
    ost = [(0, -1), (3, -1), (5, -1), (3, -1), (0, -1), (10, -2), (0, -1), (8, -2)]
    for i in range(int(LOOP / (beat / 2))):
        semi, octv = ost[i % 8]
        cb.add(veena(hz(semi, octv), rng, 0.9), i * beat / 2, 0.3, 0.22 if i % 2 else 0.3)
    return {"explore": ex.render(), "combat": cb.render(-25)}


def track_tataka():
    rng = np.random.default_rng(41)
    beat = 60 / 140  # 112 beats = 48 s
    boss = Stem()
    drone(boss, rng, 5, 3.43, 0.35, octave=-1)
    bar = 8 * beat
    for b in range(14):
        t0 = b * bar
        for pos in (0, 3, 4.5, 6):
            boss.add(dhol(rng, big=True), t0 + pos * beat, 0.0, 0.6 if pos == 0 else 0.42)
        for i in range(16):  # driving dhol eighths
            boss.add(dhol(rng), t0 + i * beat / 2, 0.2 if i % 2 else -0.2, 0.32 if i % 4 else 0.45)
        if b % 4 == 3:  # tirakita fill
            for i, bol in enumerate(["ti", "ta", "ke", "ta", "ti", "ta", "ke", "dha"]):
                boss.add(tabla(bol, rng), t0 + 4 * beat + i * beat / 2, -0.3, 0.55)
    ost = [(0, -1), (0, -1), (3, -1), (0, -1), (5, -1), (3, -1), (8, -2), (10, -2)]
    for i in range(int(LOOP / (beat / 2))):
        semi, octv = ost[i % 8]
        boss.add(veena(hz(semi, octv), rng, 0.8), i * beat / 2, 0.3, 0.3)
    maya = Stem()  # her illusions: wavering choir, whispers, shivering high plucks
    for k in range(8):
        chord = [hz(0, -1), hz(3, 0), hz(8, 0)] if k % 2 == 0 else [hz(10, -1), hz(5, 0), hz(0, 1)]
        maya.add(chorus(chord, 5.0, rng, attack=2.5, release=1.5, wobble=0.35), k * 6.0, 0.0, 0.5)
        maya.add(fft_filter(rng.standard_normal(int(3 * SR)), 2500, 7000) * np.hanning(int(3 * SR)), k * 6.0 + 2.0,
                 0.6 if k % 2 else -0.6, 0.12)
    for i in range(int(LOOP / (beat / 4))):
        if (i // 8) % 4 == 2:
            semi = [0, 3, 5, 8, 10][(i * 3) % 5]
            maya.add(santoor(hz(semi, 2), rng, 0.6), i * beat / 4, 0.5, 0.12)
    return {"boss": boss.render(-23), "maya": maya.render(-27)}


def track_bloom():
    rng = np.random.default_rng(51)
    beat = 0.5
    s = Stem()
    drone(s, rng, 7, 4.0, 0.35)
    chords = [[0, 4, 7], [2, 7, 9], [9, 12, 16], [7, 12, 14]]
    for k in range(8):
        semis = chords[k % 4]
        s.add(chorus([hz(x, -1 if x < 9 else -1) for x in semis], 5.2, rng), k * 6.0, 0.0, 0.42)
        for i in range(12):  # santoor arpeggio over each chord
            x = semis[i % 3] + 12 * (1 + (i // 3) % 2)
            s.add(santoor(hz(x, 0), rng), k * 6.0 + i * beat, 0.35 if i % 2 else -0.35, 0.13)
    melody(s, "bhupali", rng, beat, 3.0, LOOP + 2.0, 0.45, -0.1, [1, 2, 2, 3], gap=(3, 6))
    return {"main": s.render()}


TRACKS = {"menu": track_menu, "ayodhya": track_ayodhya, "forest": track_forest,
          "tataka": track_tataka, "bloom": track_bloom}


# --- Output ---------------------------------------------------------------------

def write_wav(path, y):
    data = (np.clip(y.T, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def encode(y, out_path, codec):
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        write_wav(wav, y)
        args = ["-c:a", "libvorbis", "-q:a", "4"] if codec == "ogg" else ["-c:a", "libmp3lame", "-b:a", "160k"]
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), *args,
                        "-fflags", "+bitexact", "-map_metadata", "-1", str(out_path)], check=True)


def preview(stems, out_path):
    """A listening demo walking through Part 1 the way the game mixes it."""
    def seg(track, layers, sec, start=0.0):
        n = int(sec * SR)
        i = int(start * SR)
        y = np.zeros((2, n))
        for name, g in layers.items():
            src = np.tile(stems[track][name], 2)
            y += src[:, i:i + n] * g
        return y
    parts = [
        seg("menu", {"main": 1.0}, 16),
        seg("ayodhya", {"explore": 1.0}, 12),
        seg("ayodhya", {"explore": 0.7, "combat": 1.0}, 14, 12),
        seg("forest", {"explore": 1.0}, 12),
        seg("forest", {"explore": 0.7, "combat": 1.0}, 12, 12),
        seg("tataka", {"boss": 1.0}, 12),
        seg("tataka", {"boss": 1.0, "maya": 1.0}, 10, 12),
        seg("bloom", {"main": 1.0}, 18),
    ]
    fade = int(1.5 * SR)
    out = parts[0]
    for p in parts[1:]:
        ramp = np.linspace(0, 1, fade)
        out[:, -fade:] = out[:, -fade:] * (1 - ramp) + p[:, :fade] * ramp
        out = np.concatenate([out, p[:, fade:]], axis=1)
    out *= 0.89 / max(np.max(np.abs(out)), 0.89)
    encode(out, out_path, "mp3" if str(out_path).endswith(".mp3") else "ogg")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="also write a listening demo (.mp3 or .ogg)")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    stems = {}
    for name, fn in TRACKS.items():
        stems[name] = fn()
        for stem, y in stems[name].items():
            path = OUT / f"{name}_{stem}.ogg"
            encode(y, path, "ogg")
            print(f"{path.name}: {y.shape[1] / SR:.1f} s, peak {20 * np.log10(np.max(np.abs(y))):.1f} dBFS, "
                  f"{path.stat().st_size // 1024} KB")
    if args.preview:
        preview(stems, args.preview)
        print("preview:", args.preview)


if __name__ == "__main__":
    main()
