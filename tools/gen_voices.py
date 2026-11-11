#!/usr/bin/env python3
"""Generates the spoken voice lines with Piper (offline neural text-to-speech).

    <venv>/bin/python tools/gen_voices.py --model <dir with en_GB-vctk-medium.onnx>

Needs: pip install piper-tts (in a venv), the en_GB-vctk-medium voice from
https://huggingface.co/rhasspy/piper-voices, numpy and ffmpeg (libvorbis).

Lines come from every data/dialogue/**/*.tres and from in-game call-outs in
code (show_subtitle("Speaker", "...") and lakshmana.say("...")). Each line is
written to assets/audio/voice/<md5("Speaker|text")>.ogg, the same key the
Voice autoload computes, so edited lines simply get new files.

These are placeholder voices until the cast is recorded.
"""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "voice"
SR = 22050

## Speaker -> how to voice them.
##   spk: VCTK speaker; speed: >1 slower; pitch: semitones (shifts formants too,
##   so negative also sounds bigger); reverb: (seconds, wet); extra effects.
CAST = {
    "Rama": {"spk": "p376", "speed": 1.12, "pitch": -0.5, "reverb": (0.5, 0.06)},  # Indian-English, calm
    "Lakshmana": {"spk": "p251", "speed": 1.0, "pitch": 0.0, "reverb": (0.5, 0.05)},  # Indian-English, younger
    "Vishvamitra": {"spk": "p237", "speed": 1.18, "pitch": -1.5, "reverb": (1.4, 0.16)},
    "Vasishtha": {"spk": "p254", "speed": 1.2, "pitch": -1.0, "reverb": (1.2, 0.14)},
    "Dasharatha": {"spk": "p256", "speed": 1.1, "pitch": -1.0, "reverb": (1.0, 0.1)},
    "Herald": {"spk": "p226", "speed": 0.95, "pitch": 0.0, "reverb": (1.6, 0.12)},
    "Tataka": {"spk": "p248", "speed": 1.25, "pitch": -7.0, "reverb": (1.8, 0.22), "demon": True},
    "Narration": {"spk": "p273", "speed": 1.12, "pitch": 3.0, "reverb": (1.5, 0.12), "unison": True},
    "The Astras": {"spk": "p248", "speed": 1.2, "pitch": -2.0, "reverb": (3.0, 0.35), "choir": True},
    "Subahu": {"spk": "p256", "speed": 1.05, "pitch": -3.0, "reverb": (1.6, 0.2), "demon": True},
    "Scribe": {"spk": "p270", "speed": 1.05, "pitch": -0.5, "reverb": (0.8, 0.08)},
    "Sumantra": {"spk": "p260", "speed": 1.0, "pitch": -1.0, "reverb": (0.8, 0.08)},
    "Grandfather": {"spk": "p326", "speed": 1.15, "pitch": -1.0, "reverb": (0.6, 0.06)},
    "Chandu": {"spk": "p273", "speed": 0.95, "pitch": 6.0, "reverb": (0.5, 0.05)},
    "Gardener": {"spk": "p347", "speed": 1.12, "pitch": -0.5, "reverb": (0.6, 0.06)},
    "Maricha": {"spk": "p345", "speed": 1.1, "pitch": -3.5, "reverb": (1.8, 0.24)},
    "Widow": {"spk": "p248", "speed": 1.15, "pitch": -1.0, "reverb": (0.7, 0.07)},
    "Boatman": {"spk": "p360", "speed": 1.05, "pitch": -1.5, "reverb": (0.7, 0.07)},
    "Sumati": {"spk": "p334", "speed": 1.08, "pitch": -1.0, "reverb": (1.0, 0.1)},
    "Weaver": {"spk": "p229", "speed": 1.12, "pitch": -1.0, "reverb": (0.6, 0.06)},
    "Oil-seller": {"spk": "p316", "speed": 1.0, "pitch": -0.5, "reverb": (0.6, 0.06)},
    "Priest": {"spk": "p311", "speed": 1.12, "pitch": -1.0, "reverb": (1.2, 0.12)},
    "Ahalya": {"spk": "p228", "speed": 1.15, "pitch": -0.5, "reverb": (1.3, 0.13)},
    "Gautama": {"spk": "p374", "speed": 1.15, "pitch": -2.0, "reverb": (1.4, 0.15)},
}

## Sanskrit names, spelled the way the English voice should say them
## (subtitles keep the proper spelling).
PRONOUNCE = {
    "Ikshvaku": "Ikshvaaku",
    "Maricha": "Maareecha",
    "Vishvamitra": "Vishwaamitra", "Vasishtha": "Vasishta", "Dasharatha": "Dasharata",
    "Lakshmana": "Lukshmana", "Tataka": "Taataka", "Agneyastra": "Aagnayaastra",
    "Varunastra": "Vaaroonaastra", "Vayavyastra": "Vaayavyaastra", "astras": "aastras",
    "astra": "aastra", "Siddhashrama": "Siddhaashrama", "Kodanda": "Kodunda",
    "Sarayu": "Sarayoo", "Ayodhya": "Uh-yoad-yah", "rakshasas": "raakshasas", "rakshasa": "raakshasa",
    "rakshasi": "raakshasi", "dharma": "dharma", "Kausalya": "Kaushalya", "Raghu": "Ragu",
    "yakshini": "yakshini", "Ahalya": "Ahulyaa", "Sumati": "Sumuti", "Gautama": "Gowtuma", "Vishala": "Vishaalaa",
    "kusumbha": "kusoombha", "Mandara": "Mundaara", "Vasuki": "Vaasuki", "amrita": "umrita", "Diti": "Ditee", "Lava": "Lava", "Kusha": "Kusha", "Mithila": "Mitilaa",
}

TRES_TEXT = re.compile(r'^text = "((?:[^"\\]|\\.)*)"', re.S | re.M)
SUBTITLE = re.compile(r'show_subtitle\(\s*"([^"]+)"\s*,\s*"((?:[^"\\]|\\.)*)"')
LAKSHMANA_SAY = re.compile(r'lakshmana\.say\(\s*"((?:[^"\\]|\\.)*)"')
## Lakshmana's own lines inside lakshmana.gd: say("...").
OWN_SAY = re.compile(r'(?<![.\w])say\(\s*"((?:[^"\\]|\\.)*)"')
## say_lines([["Speaker", "text"], ...]) pairs.
PAIR = re.compile(r'\[\s*"([A-Z][A-Za-z ]+)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\]')


def key(speaker: str, text: str) -> str:
    return hashlib.md5(f"{speaker}|{text}".encode("utf-8")).hexdigest()


def unescape(s: str) -> str:
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


## Delivery per dialogue emotion: (length scale, pitch in semitones). Small
## nudges only; the actors' own reading comes later.
EMOTION_DELIVERY = {
    "grief": (1.13, -0.4), "concern": (1.06, 0.0), "calm": (1.04, 0.0), "reverence": (1.1, -0.3),
    "resolve": (1.0, -0.2), "anger": (0.95, 0.2), "fury": (0.92, 0.4), "joy": (0.96, 0.5),
    "smile": (0.99, 0.3), "wonder": (1.05, 0.3), "pain": (1.05, 0.0),
}
EMOTION_OF = {}


def collect_lines():
    lines = []
    for tres in sorted((ROOT / "data" / "dialogue").rglob("*.tres")):
        m = TRES_TEXT.search(tres.read_text())
        if not m:
            continue
        for row in unescape(m.group(1)).split("\n"):
            parts = (row.strip().split("|", 4) + ["", "", "", "", ""])[:5]   # Speaker|shot|action|text|emotion
            speaker, text = parts[0].strip(), parts[3].strip().replace("\\n", "\n")
            if parts[4].strip():
                EMOTION_OF[(speaker, text)] = parts[4].strip()
            if speaker and text:
                lines.append((speaker, text, tres.stem))
    for gd in sorted(list((ROOT / "kandas").rglob("*.gd")) + list((ROOT / "characters").rglob("*.gd"))):
        src = gd.read_text()
        for speaker, text in SUBTITLE.findall(src):
            lines.append((speaker, unescape(text), gd.stem))
        for text in LAKSHMANA_SAY.findall(src):
            lines.append(("Lakshmana", unescape(text), gd.stem))
        if gd.stem == "lakshmana":
            for text in OWN_SAY.findall(src):
                lines.append(("Lakshmana", unescape(text), gd.stem))
        for speaker, text in PAIR.findall(src):
            if speaker in CAST:
                lines.append((speaker, unescape(text), gd.stem))
    seen, out = set(), []
    for line in lines:
        if (line[0], line[1]) not in seen:
            seen.add((line[0], line[1]))
            out.append(line)
    return out


def tts_text(text: str) -> str:
    t = text.replace("\n", " ").replace("...", ", ").replace("—", ", ")
    for word, say in sorted(PRONOUNCE.items(), key=lambda kv: -len(kv[0])):
        t = re.sub(rf"\b{word}\b", say, t)
        t = re.sub(rf"\b{word.capitalize()}\b", say.capitalize(), t)
    return t


# --- DSP ---------------------------------------------------------------------

def resample(x, factor):
    """Plays x `factor` times faster (pitch and formants up by `factor`)."""
    n = int(len(x) / factor)
    return np.interp(np.arange(n) * factor, np.arange(len(x)), x)


def reverb(x, seconds, wet, seed=3):
    if wet <= 0:
        return x
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-6.9 * t / seconds)
    ir[: int(0.012 * SR)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir ** 2))
    m = len(x) + n
    size = 1 << (m - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:m]
    dry = np.concatenate([x, np.zeros(n)])
    return dry + wet * y * 0.6


def demon(x, growl):
    low = resample(x, 0.5)[: len(x)]
    low = np.pad(low, (0, len(x) - len(low)))
    y = x + 0.55 * low
    y = np.tanh(y * 2.2) / 1.6
    if growl is not None:
        g = growl[: len(y)] * 0.35
        y[: len(g)] += g
    return y


def choir(x):
    up = resample(x, 2 ** (5 / 12))
    dn = resample(x, 2 ** (-7 / 12))
    n = len(x)
    # Keep the timing: stretch each shifted copy back to the original length.
    up = np.interp(np.linspace(0, len(up) - 1, n), np.arange(len(up)), up)
    dn = np.interp(np.linspace(0, len(dn) - 1, n), np.arange(len(dn)), dn)
    return x + 0.6 * up + 0.7 * dn


def unison(x):
    d = int(0.022 * SR)
    twin = np.interp(np.linspace(0, len(x) - 1, len(x)) * (1 - 0.004), np.arange(len(x)), x)
    return x + 0.8 * np.concatenate([np.zeros(d), twin[:-d]])


def trim(x, thresh=0.01):
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    a = max(idx[0] - int(0.03 * SR), 0)
    return x[a:]


def normalize(x, rms_db=-19.0):
    voiced = x[np.abs(x) > 0.02]
    rms = np.sqrt(np.mean(voiced ** 2)) if len(voiced) else 1.0
    y = x * (10 ** (rms_db / 20) / (rms + 1e-9))
    peak = np.max(np.abs(y))
    if peak > 0.89:
        y *= 0.89 / peak
    return y


def encode(x, path):
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "v.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
        codec = ["-c:a", "libmp3lame", "-b:a", "96k"] if str(path).endswith(".mp3") else ["-c:a", "libvorbis", "-q:a", "3"]
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), *codec,
                        "-fflags", "+bitexact", "-map_metadata", "-1", str(path)], check=True)


def load_growl():
    p = ROOT / "assets" / "audio" / "sfx" / "growl.wav"
    if not p.exists():
        return None
    with wave.open(str(p)) as w:
        g = np.frombuffer(w.readframes(w.getnframes()), np.int16) / 32768.0
        return resample(g, w.getframerate() / SR) if w.getframerate() != SR else g


LIPSYNC_FPS = 30


def mouth_envelope(path: Path) -> str:
    """How open the mouth is through a voice line: 30 values a second, each one
    hex digit (0 closed .. f wide), from the speech-band loudness."""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1", "-ar", str(SR),
                          "-af", "highpass=f=180,lowpass=f=3500", "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32)
    hop = SR // LIPSYNC_FPS
    n = max(1, len(x) // hop)
    rms = np.array([np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2) + 1e-12) for i in range(n)])
    db = 20 * np.log10(rms)
    peak = np.percentile(db, 95)
    level = np.clip((db - (peak - 22.0)) / 22.0, 0.0, 1.0) ** 2.0   # 22 dB range; tails and reverb stay shut
    # Lips cannot snap: smooth a little, closing faster than opening is unnatural.
    out, prev = [], 0.0
    for v in level:
        prev = prev + (v - prev) * (0.75 if v > prev else 0.5)
        out.append("0123456789abcdef"[int(round(prev * 15))])
    return "".join(out)


def write_lipsync():
    data = {f.stem: mouth_envelope(f) for f in sorted(OUT.glob("*.ogg"))}
    (OUT / "lipsync.json").write_text(json.dumps(data, indent=0) + "\n")
    print(f"lip sync for {len(data)} lines")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="", help="folder holding en_GB-vctk-medium.onnx(.json)")
    ap.add_argument("--force", action="store_true", help="re-voice lines that already have audio")
    ap.add_argument("--only-containing", default="",
                    help="with --force: re-voice only lines containing one of these comma-separated words")
    ap.add_argument("--preview", help="also write a listening reel (gate scene + Tataka intro) to this .mp3")
    ap.add_argument("--lipsync-only", action="store_true", help="only rebuild lipsync.json from the existing audio")
    args = ap.parse_args()
    if args.lipsync_only:
        write_lipsync()
        return
    from piper import PiperVoice, SynthesisConfig  # noqa: imported here so --help works without piper

    model = Path(args.model) / "en_GB-vctk-medium.onnx"
    voice = PiperVoice.load(str(model))
    ids = json.loads(Path(str(model) + ".json").read_text())["speaker_id_map"]
    growl = load_growl()
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    manifest_path = OUT / "manifest.json"
    old_manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    lines = collect_lines()
    rendered = {}
    for speaker, text, source in lines:
        cast = CAST.get(speaker)
        if cast is None:
            print(f"! no voice cast for {speaker!r}: {text}")
            continue
        k = key(speaker, text)
        words = [w.strip() for w in args.only_containing.split(",") if w.strip()]
        forced = args.force and (not words or any(re.search(r"\b" + re.escape(w), text) for w in words))
        if not forced and not args.preview and (OUT / f"{k}.ogg").exists() and k in old_manifest:
            # Piper's synthesis is not deterministic: keep existing takes stable.
            manifest[k] = old_manifest[k]
            continue
        e_speed, e_pitch = EMOTION_DELIVERY.get(EMOTION_OF.get((speaker, text), ""), (1.0, 0.0))
        r = 2 ** ((cast["pitch"] + e_pitch) / 12)
        cfg = SynthesisConfig(speaker_id=ids[cast["spk"]], length_scale=cast["speed"] * e_speed * r,
                              noise_scale=0.6, noise_w_scale=0.75)
        pcm = b"".join(c.audio_int16_bytes for c in voice.synthesize(tts_text(text), syn_config=cfg))
        x = trim(np.frombuffer(pcm, np.int16) / 32768.0)
        if r != 1.0:
            x = resample(x, r)
        if cast.get("demon"):
            x = demon(x, growl)
        if cast.get("choir"):
            x = choir(x)
        if cast.get("unison"):
            x = unison(x)
        x = reverb(x, *cast["reverb"])
        x = normalize(x)
        encode(x, OUT / f"{k}.ogg")
        manifest[k] = {"speaker": speaker, "text": text, "source": source, "seconds": round(len(x) / SR, 2)}
        rendered.setdefault(source, []).append(x)
        print(f"{k}  {speaker:12s} {len(x) / SR:4.1f}s  {text[:60]}")
    # Remove voice files for lines that no longer exist.
    for f in OUT.glob("*.ogg"):
        if f.stem not in manifest:
            f.unlink()
            imp = f.with_suffix(".ogg.import")
            if imp.exists():
                imp.unlink()
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n")
    print(f"{len(manifest)} lines")
    write_lipsync()
    if args.preview:
        gap = np.zeros(int(0.6 * SR))
        reel = np.concatenate([seg for stem in ("sage_at_gate", "tataka_intro", "forest")
                               for x in rendered.get(stem, []) for seg in (x, gap)])
        encode(reel, Path(args.preview))


if __name__ == "__main__":
    main()
