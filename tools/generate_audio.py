#!/usr/bin/env python3
"""
RE:ZERO — THE DIMENSION OF ENVY
Procedural sound-design generator.

Every sound used by the game is synthesised here (no external samples), so the
project is fully self-contained. These are *placeholders of production quality*:
they are designed to be replaced by recorded foley / voice acting later, using the
exact same file names (see documentation/AUDIO.md).

Usage:  python3 tools/generate_audio.py
Output: assets/audio/{sfx,music,ambience,voice}/*.wav|*.ogg
"""
import os
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RNG = np.random.default_rng(1710)


# --------------------------------------------------------------------------- helpers
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def white(dur):
    return RNG.uniform(-1.0, 1.0, len(t_axis(dur)))


def pink(dur):
    w = white(dur)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, w) * 6.0


def brown(dur):
    w = white(dur)
    out = np.cumsum(w)
    out = signal.lfilter([1, -1], [1, -0.995], out)
    return out / (np.max(np.abs(out)) + 1e-9)


def bp(x, lo, hi, order=2):
    lo = max(lo, 10)
    hi = min(hi, SR / 2 - 100)
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    sos = signal.butter(order, min(f, SR / 2 - 100), btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, f, order=2):
    sos = signal.butter(order, max(f, 10), btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def env_ad(n, attack, decay_curve=4.0):
    a = int(attack * SR)
    e = np.ones(n)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    rest = n - a
    if rest > 0:
        e[a:] = np.exp(-decay_curve * np.linspace(0, 1, rest))
    return e


def fade(x, fin=0.01, fout=0.05):
    n = len(x)
    i = min(int(fin * SR), n // 2)
    o = min(int(fout * SR), n // 2)
    if i > 0:
        x[:i] *= np.linspace(0, 1, i)
    if o > 0:
        x[-o:] *= np.linspace(1, 0, o)
    return x


def reverb(x, size=2.5, wet=0.35, damp=3000):
    n = int(size * SR)
    ir = RNG.normal(0, 1, n) * np.exp(-6.0 * np.linspace(0, 1, n))
    ir = lp(ir, damp)
    ir[0] = 0
    y = signal.fftconvolve(x, ir)
    y = np.concatenate([y, np.zeros(max(0, len(x) + n - len(y)))])[: len(x) + n]
    y = y / (np.max(np.abs(y)) + 1e-9)
    dry = np.concatenate([x, np.zeros(n)])
    dry = dry / (np.max(np.abs(dry)) + 1e-9)
    return dry * (1 - wet) + y * wet


def formant_voice(dur, f0_curve, vowels, breath=0.15):
    """Very small source/filter voice: glottal pulse train + 3 formants."""
    t = t_axis(dur)
    f0 = np.interp(t, np.linspace(0, dur, len(f0_curve)), f0_curve)
    phase = np.cumsum(2 * np.pi * f0 / SR)
    src = signal.sawtooth(phase, 0.15) + breath * RNG.normal(0, 1, len(t))
    # vowel formant table (F1, F2, F3)
    table = {
        "a": (800, 1200, 2600),
        "e": (450, 2000, 2700),
        "i": (300, 2300, 3000),
        "o": (500, 900, 2500),
        "u": (350, 700, 2400),
    }
    out = np.zeros_like(src)
    seg = len(t) // len(vowels)
    for k, v in enumerate(vowels):
        s = k * seg
        e = len(t) if k == len(vowels) - 1 else (k + 1) * seg
        f1, f2, f3 = table[v]
        part = src[max(0, s - 2000): e]
        y = bp(part, f1 * 0.8, f1 * 1.2) * 1.0 + bp(part, f2 * 0.85, f2 * 1.15) * 0.6 + bp(part, f3 * 0.9, f3 * 1.1) * 0.25
        y = y[(s - max(0, s - 2000)):]
        out[s:e] = y[: e - s]
    return out


def mix(a, b):
    n = max(len(a), len(b))
    return np.pad(a, (0, n - len(a))) + np.pad(b, (0, n - len(b)))


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def make_loop(x, xfade=1.5):
    """Cross-fade the tail into the head so the file loops seamlessly."""
    n = int(xfade * SR)
    head = x[:n].copy()
    tail = x[-n:].copy()
    ramp = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * ramp + tail * (1 - ramp)
    return x


def write_wav(rel, x, stereo=None):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if stereo is not None:
        data = np.stack([x, stereo], axis=1)
        ch = 2
    else:
        data = x
        ch = 1
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path


def write_ogg(rel, x, stereo=None):
    wav_rel = rel.replace(".ogg", ".tmp.wav")
    wav = write_wav(wav_rel, x, stereo)
    out = os.path.join(ROOT, rel)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.remove(wav)


# --------------------------------------------------------------------------- ambience
def amb_void_wind():
    d = 32
    t = t_axis(d)
    base = pink(d)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / 11.0) * np.sin(2 * np.pi * t / 4.3 + 1)
    howl = np.zeros_like(t)
    for f, ph in ((180, 0), (243, 1.3), (311, 2.1)):
        fm = f * (1 + 0.08 * np.sin(2 * np.pi * t / (7 + ph)))
        howl += np.sin(np.cumsum(2 * np.pi * fm / SR)) * (0.5 + 0.5 * np.sin(2 * np.pi * t / (9 + ph * 2)))
    l = bp(base, 150, 900) * (0.4 + 0.6 * lfo) + howl * 0.05 * lfo
    r = bp(pink(d), 150, 900) * (0.4 + 0.6 * lfo[::-1]) + howl * 0.05 * lfo[::-1]
    l, r = make_loop(norm(l, 0.6)), make_loop(norm(r, 0.6))
    write_ogg("ambience/amb_void_wind.ogg", l, r)


def amb_drone():
    d = 30
    t = t_axis(d)
    x = np.zeros_like(t)
    for f, a in ((41.2, 1.0), (41.9, 0.8), (61.7, 0.4), (82.4, 0.25), (87.3, 0.15)):
        x += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6))
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * t / 15)
    x += lp(brown(d), 120) * 0.4
    write_ogg("ambience/amb_drone_low.ogg", make_loop(norm(x, 0.7)))


def amb_mansion():
    d = 30
    t = t_axis(d)
    tone = lp(pink(d), 400) * 0.6 + 0.05 * np.sin(2 * np.pi * 50 * t) + 0.03 * np.sin(2 * np.pi * 100 * t)
    # very sparse settling / ticking of the house
    for _ in range(14):
        p = int(RNG.uniform(0.5, d - 1) * SR)
        n = int(0.08 * SR)
        click = bp(white(0.08), 600, 2500) * env_ad(n, 0.001, 30) * RNG.uniform(0.2, 0.6)
        tone[p:p + n] += click
    write_ogg("ambience/amb_mansion_room.ogg", make_loop(norm(tone, 0.5)))


def amb_forest():
    d = 32
    t = t_axis(d)
    wind = bp(pink(d), 300, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0) ** 2)
    leaves = hp(white(d), 3000) * 0.08 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 3.1))
    x = wind + leaves
    for _ in range(6):
        p = int(RNG.uniform(1, d - 3) * SR)
        c = creak_core(RNG.uniform(1.0, 2.0), RNG.uniform(60, 120)) * 0.35
        x[p:p + len(c)] += c
    l = make_loop(norm(x, 0.55))
    r = make_loop(norm(np.roll(x, 9000), 0.55))
    write_ogg("ambience/amb_forest.ogg", l, r)


def amb_throne():
    d = 30
    t = t_axis(d)
    x = np.zeros_like(t)
    for f in (55, 55.6, 82.5, 110.3, 130.8):
        x += np.sin(2 * np.pi * f * t + RNG.uniform(0, 6)) * (0.6 + 0.4 * np.sin(2 * np.pi * t / RNG.uniform(5, 13)))
    x += bp(pink(d), 60, 300) * 0.8
    x = reverb(x, 3.0, 0.5)[: len(t)]
    write_ogg("ambience/amb_throne.ogg", make_loop(norm(x, 0.6)))


# --------------------------------------------------------------------------- music (adaptive layers)
def music_dread():
    d = 40
    t = t_axis(d)
    x = np.zeros_like(t)
    # D minor-ish cluster with very slow swells
    for f in (73.4, 87.3, 110.0, 116.5, 146.8):
        det = f * (1 + RNG.uniform(-0.003, 0.003))
        saw = signal.sawtooth(2 * np.pi * det * t) + signal.sawtooth(2 * np.pi * det * 1.004 * t)
        x += lp(saw, 600) * (0.5 + 0.5 * np.sin(2 * np.pi * t / RNG.uniform(9, 17) + RNG.uniform(0, 6)))
    x = reverb(x, 4.0, 0.6)[: len(t)]
    write_ogg("music/music_dread.ogg", make_loop(norm(x, 0.6), 3))


def music_presence():
    d = 32
    t = t_axis(d)
    x = np.zeros_like(t)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 7.5 * t)
    for f in (233.1, 246.9, 261.6, 349.2, 370.0):
        x += signal.sawtooth(2 * np.pi * f * t * (1 + 0.002 * np.sin(2 * np.pi * 0.3 * t))) * trem
    x = bp(x, 200, 2500)
    x *= 0.5 + 0.5 * np.sin(2 * np.pi * t / 16) ** 2
    x = reverb(x, 3.0, 0.55)[: len(t)]
    write_ogg("music/music_presence.ogg", make_loop(norm(x, 0.5), 2))


def kick(dur=0.5):
    t = t_axis(dur)
    f = 45 + 90 * np.exp(-t * 30)
    return np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t * 7)


def music_chase():
    bpm = 150
    beat = 60 / bpm
    bars = 16
    d = beat * 4 * bars
    t = t_axis(d)
    x = np.zeros_like(t)
    k = kick(0.45)
    pattern = [0, 0.75, 1.5, 2, 2.75, 3.5]
    for bar in range(bars):
        for p in pattern:
            s = int((bar * 4 + p) * beat * SR)
            x[s:s + len(k)] += k[: len(x) - s]
    # pulsing low ostinato
    bass = signal.sawtooth(2 * np.pi * 36.7 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (bpm / 60 * 2) * t)))
    x += lp(bass, 250) * 0.5
    # dissonant string stabs every 2 bars
    for bar in range(0, bars, 2):
        s = int(bar * 4 * beat * SR)
        n = int(beat * 2 * SR)
        tt = np.arange(n) / SR
        stab = sum(signal.sawtooth(2 * np.pi * f * tt) for f in (293.7, 311.1, 440, 466.2))
        stab = bp(stab, 300, 3000) * np.exp(-tt * 3)
        x[s:s + n] += stab[: len(x) - s] * 0.35
    # high anxiety tremolo
    hi = np.sin(2 * np.pi * 1244.5 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 12 * t)) * 0.05
    x += hi
    write_ogg("music/music_chase.ogg", norm(x, 0.85))


def music_lobby():
    """Original slow music-box lullaby, detuned, heavy reverb."""
    notes = [69, 72, 76, 74, 72, 71, 72, 69, 64, 65, 69, 67, 65, 64, 65, 0,
             69, 72, 76, 77, 76, 74, 72, 74, 71, 67, 69, 71, 72, 71, 69, 0]
    step = 0.9
    d = len(notes) * step + 4
    x = np.zeros(int(d * SR))
    for i, n in enumerate(notes):
        if n == 0:
            continue
        f = 440 * 2 ** ((n - 69) / 12) * (1 + RNG.uniform(-0.006, 0.006))
        dur = 2.5
        tt = t_axis(dur)
        tone = (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt * 6)
                + 0.15 * np.sin(2 * np.pi * f * 5.4 * tt) * np.exp(-tt * 12))
        tone *= np.exp(-tt * 2.2)
        s = int(i * step * SR)
        x[s:s + len(tone)] += tone[: len(x) - s] * 0.5
    t = np.arange(len(x)) / SR
    x += 0.15 * np.sin(2 * np.pi * 55 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 10))
    x = reverb(x, 4.5, 0.55)[: len(x)]
    write_ogg("music/music_lobby.ogg", make_loop(norm(x, 0.5), 3))


def music_throne():
    d = 36
    t = t_axis(d)
    choir = np.zeros_like(t)
    for f0 in (110, 130.8, 164.8, 155.6):
        v = formant_voice(d, [f0, f0 * 1.01, f0 * 0.99, f0], ["a", "o", "a", "u"], breath=0.3)
        choir += v * (0.5 + 0.5 * np.sin(2 * np.pi * t / RNG.uniform(6, 11)))
    choir += lp(brown(d), 90) * 0.6
    choir = reverb(choir, 5.0, 0.65)[: len(t)]
    write_ogg("music/music_throne.ogg", make_loop(norm(choir, 0.6), 3))


def music_credits():
    notes = [57, 60, 64, 62, 60, 59, 60, 57, 52, 53, 57, 55, 53, 52, 53, 0] * 2
    step = 1.4
    d = len(notes) * step + 6
    x = np.zeros(int(d * SR))
    for i, n in enumerate(notes):
        if n == 0:
            continue
        f = 440 * 2 ** ((n - 69) / 12)
        tt = t_axis(4)
        tone = (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * f * 2 * tt) * np.exp(-tt * 3)) * np.exp(-tt * 1.2)
        s = int(i * step * SR)
        x[s:s + len(tone)] += tone[: len(x) - s] * 0.4
    t = np.arange(len(x)) / SR
    pad = sum(lp(signal.sawtooth(2 * np.pi * f * t), 500) for f in (110, 130.8, 164.8)) * 0.07
    x += pad
    x = reverb(x, 5, 0.6)[: len(x)]
    write_ogg("music/music_credits.ogg", norm(x, 0.6))


# --------------------------------------------------------------------------- sfx
def creak_core(dur, f0):
    t = t_axis(dur)
    f = f0 * (1 + 0.6 * np.sin(2 * np.pi * t / dur * RNG.uniform(0.6, 1.4)) ** 2)
    pulses = signal.square(np.cumsum(2 * np.pi * f / SR), 0.08)
    y = bp(pulses, 300, 3500) * np.sin(np.pi * t / dur) ** 0.5
    return y


def sfx_creaks():
    for i in range(1, 5):
        d = RNG.uniform(0.8, 2.2)
        y = creak_core(d, RNG.uniform(25, 70))
        y = reverb(y, 1.2, 0.3)
        write_wav(f"sfx/creak_{i}.wav", fade(norm(y, 0.8)))


def footstep(surface, idx):
    d = 0.35
    n = int(d * SR)
    if surface == "wood":
        y = bp(white(d), 120, 2200) * env_ad(n, 0.002, 25) + kick(d) * 0.4
        if RNG.random() < 0.4:
            c = creak_core(0.25, RNG.uniform(60, 120))
            y[: len(c)] += c * 0.05
    elif surface == "stone":
        y = bp(white(d), 400, 5000) * env_ad(n, 0.001, 35) + kick(d) * 0.25
    elif surface == "carpet":
        y = lp(white(d), 900) * env_ad(n, 0.01, 18) * 0.7
    else:  # dirt / forest
        y = bp(white(d), 200, 4000) * env_ad(n, 0.004, 14)
        crunch = hp(white(d), 3000) * (RNG.random(n) > 0.97) * env_ad(n, 0.001, 8)
        y = y + crunch * 0.6
    write_wav(f"sfx/step_{surface}_{idx}.wav", fade(norm(y, 0.8), 0.001, 0.05))


def sfx_doors():
    # open: latch + long creak
    latch = bp(white(0.06), 1500, 6000) * env_ad(int(0.06 * SR), 0.001, 30)
    cr = creak_core(1.3, 40)
    y = np.concatenate([latch, cr * 0.8])
    write_wav("sfx/door_open.wav", fade(norm(reverb(y, 1.0, 0.25), 0.8)))
    # close: thud + latch
    th = kick(0.5) * 0.9 + bp(white(0.5), 80, 800) * env_ad(int(0.5 * SR), 0.002, 12)
    y = np.concatenate([th, latch * 0.8])
    write_wav("sfx/door_close.wav", fade(norm(reverb(y, 1.2, 0.3), 0.8)))
    # slam: very loud thud + rattle
    th = kick(0.9) * 1.0 + bp(white(0.9), 60, 1500) * env_ad(int(0.9 * SR), 0.001, 9)
    rattle = bp(white(0.6), 2000, 7000) * (np.sin(2 * np.pi * 28 * t_axis(0.6)) > 0.3) * env_ad(int(0.6 * SR), 0.0, 6)
    y = np.concatenate([th, rattle * 0.3])
    write_wav("sfx/door_slam.wav", fade(norm(reverb(y, 2.2, 0.4), 0.95)))
    # locked: handle rattle
    n = int(0.5 * SR)
    y = bp(white(0.5), 1500, 7000) * (np.sin(2 * np.pi * 14 * t_axis(0.5)) > 0.6) * env_ad(n, 0.001, 4)
    write_wav("sfx/door_locked.wav", fade(norm(y, 0.7)))


def sfx_flashlight():
    n = int(0.08 * SR)
    y = bp(white(0.08), 2000, 9000) * env_ad(n, 0.0005, 40)
    y += kick(0.08) * 0.2
    write_wav("sfx/flashlight_click.wav", fade(norm(y, 0.6), 0.0005, 0.01))
    # electrical flicker buzz
    d = 1.2
    t = t_axis(d)
    buzz = signal.square(2 * np.pi * 100 * t) * 0.3 + hp(white(d), 4000) * 0.4
    gate = (RNG.random(int(d * 30)) > 0.45).repeat(int(SR / 30) + 1)[: len(t)]
    write_wav("sfx/flicker_buzz.wav", fade(norm(bp(buzz, 100, 6000) * gate, 0.5)))


def sfx_ui():
    tt = t_axis(0.12)
    y = np.sin(2 * np.pi * 880 * tt) * np.exp(-tt * 40) * 0.5 + bp(white(0.12), 3000, 8000) * np.exp(-tt * 60) * 0.2
    write_wav("sfx/ui_hover.wav", fade(norm(y, 0.35), 0.001, 0.02))
    tt = t_axis(0.35)
    y = (np.sin(2 * np.pi * 330 * tt) + 0.5 * np.sin(2 * np.pi * 495 * tt)) * np.exp(-tt * 10)
    write_wav("sfx/ui_click.wav", fade(norm(reverb(y, 1.0, 0.3), 0.45)))


def sfx_items():
    # pickup: soft cloth / glassy
    tt = t_axis(0.5)
    y = bp(white(0.5), 500, 4000) * env_ad(len(tt), 0.02, 10) * 0.6 + np.sin(2 * np.pi * 1320 * tt) * np.exp(-tt * 9) * 0.25
    write_wav("sfx/pickup.wav", fade(norm(y, 0.6)))
    # page turn
    d = 0.6
    y = hp(white(d), 1500) * env_ad(int(d * SR), 0.15, 6) * (0.6 + 0.4 * np.sin(2 * np.pi * 25 * t_axis(d)))
    write_wav("sfx/page.wav", fade(norm(y, 0.5)))
    # book thump
    y = kick(0.4) * 0.7 + bp(white(0.4), 200, 2000) * env_ad(int(0.4 * SR), 0.001, 20)
    write_wav("sfx/book.wav", fade(norm(reverb(y, 1.2, 0.3), 0.7)))
    # candle light
    d = 0.9
    y = bp(white(d), 800, 6000) * env_ad(int(d * SR), 0.005, 5) + lp(white(d), 400) * env_ad(int(d * SR), 0.1, 3) * 0.5
    write_wav("sfx/candle.wav", fade(norm(y, 0.5)))
    # battery click-in
    y = bp(white(0.15), 1000, 8000) * env_ad(int(0.15 * SR), 0.001, 30)
    write_wav("sfx/battery.wav", fade(norm(np.concatenate([y, np.zeros(2000), y * 0.7]), 0.5)))


def bell(f, dur=6.0, inharm=(1, 2.76, 5.4, 8.93), decay=1.0):
    tt = t_axis(dur)
    y = sum(np.sin(2 * np.pi * f * h * tt) * np.exp(-tt * decay * (1 + i * 0.8)) / (i + 1) for i, h in enumerate(inharm))
    return y


def sfx_fragment():
    y = bell(523.25, 5) + bell(783.99, 5) * 0.6 + bell(1046.5, 5, decay=1.5) * 0.4
    y += np.concatenate([np.zeros(int(0.3 * SR)), bell(659.25, 4.7) * 0.5])[: len(y)]
    write_wav("sfx/fragment_chime.wav", fade(norm(reverb(y, 3.5, 0.45), 0.7)))
    # seal insert: deep stone + bell
    th = kick(1.5) * 0.9 + lp(brown(1.5), 200) * 0.5
    y = mix(np.concatenate([th, np.zeros(int(1.0 * SR))]), np.concatenate([np.zeros(int(0.2 * SR)), bell(130.8, 2.3, decay=0.7) * 0.6]))
    write_wav("sfx/seal_insert.wav", fade(norm(reverb(y, 3.0, 0.4), 0.85)))


def sfx_music_box():
    notes = [76, 74, 72, 74, 76, 76, 76, 0, 74, 74, 74, 0, 76, 79, 79]
    step = 0.38
    d = len(notes) * step + 3
    x = np.zeros(int(d * SR))
    for i, n in enumerate(notes):
        if not n:
            continue
        f = 440 * 2 ** ((n - 69) / 12) * (1 - i * 0.002)  # winding down
        tone = bell(f, 2.0, (1, 3.0, 5.2), 2.5)
        s = int(i * step * (1 + i * 0.03) * SR)
        x[s:s + len(tone)] += tone[: len(x) - s]
    write_wav("sfx/music_box.wav", fade(norm(reverb(x, 2.5, 0.4), 0.6)))


def sfx_heart_breath():
    d = 0.7
    n = int(d * SR)
    beat = kick(0.25) * 0.8
    y = np.zeros(n)
    y[: len(beat)] += beat
    s = int(0.22 * SR)
    y[s:s + len(beat)] += beat[: n - s] * 0.6
    write_wav("sfx/heartbeat.wav", fade(norm(lp(y, 160), 0.9), 0.001, 0.05))
    # breathing (in / out), panic
    for name, dur, lo, hi in (("breath_in", 0.9, 400, 3000), ("breath_out", 1.0, 300, 2500)):
        tt = t_axis(dur)
        y = bp(pink(dur), lo, hi) * np.sin(np.pi * tt / dur) ** 1.5
        write_wav(f"sfx/{name}.wav", fade(norm(y, 0.45)))


def whisper(dur, syllables):
    t = t_axis(dur)
    src = pink(dur)
    out = np.zeros_like(src)
    vow = ["a", "e", "i", "o", "u"]
    table = {"a": (800, 1200, 2600), "e": (450, 2000, 2700), "i": (300, 2300, 3000), "o": (500, 900, 2500), "u": (350, 700, 2400)}
    seg = len(t) // syllables
    for k in range(syllables):
        s, e = k * seg, (k + 1) * seg
        f1, f2, f3 = table[vow[RNG.integers(0, 5)]]
        part = src[s:e]
        y = bp(part, f1 * 0.7, f1 * 1.3) + bp(part, f2 * 0.8, f2 * 1.2) * 0.8 + bp(part, f3 * 0.9, f3 * 1.2) * 0.4
        # sibilants
        if RNG.random() < 0.5:
            y += hp(part, 5000) * 0.5 * np.exp(-np.linspace(0, 6, len(part)))
        y *= np.sin(np.pi * np.linspace(0, 1, len(part))) ** 0.7
        out[s:e] = y
    return out


def sfx_whispers():
    for i in range(1, 7):
        d = RNG.uniform(1.4, 2.8)
        y = whisper(d, int(RNG.integers(3, 8)))
        y = reverb(y, 2.0, 0.4)
        write_wav(f"voice/whisper_{i}.wav", fade(norm(y, 0.7)))
    # "Subaru" — three-syllable whisper with the stress pattern su-BA-ru
    d = 1.3
    y = whisper(d, 3)
    y[: int(d * SR / 3)] += hp(white(d / 3), 5000)[: int(d * SR / 3)] * 0.6 * np.exp(-np.linspace(0, 4, int(d * SR / 3)))
    write_wav("voice/whisper_name.wav", fade(norm(reverb(y, 2.5, 0.45), 0.7)))


def sfx_voices():
    # Original Satella: soft sung hum (warm, melancholic)
    for i, (f, vow) in enumerate(((330, ["a", "a", "o"]), (294, ["o", "u", "u"]), (349, ["a", "e", "a"])), 1):
        d = 2.6
        v = formant_voice(d, [f, f * 1.02, f * 0.97, f * 0.94], vow, breath=0.35)
        v *= np.sin(np.pi * t_axis(d) / d) ** 1.2
        v = reverb(v, 3.0, 0.55)
        write_wav(f"voice/satella_soft_{i}.wav", fade(norm(v, 0.55)))
    # Witch: tender low voice
    for i, (f, vow) in enumerate(((210, ["a", "o", "u"]), (190, ["u", "a", "a"])), 1):
        d = 2.2
        v = formant_voice(d, [f, f * 0.9, f * 1.05, f * 0.8], vow, breath=0.5)
        sub = formant_voice(d, [f / 2, f / 2.1, f / 1.9, f / 2.2], vow, breath=0.2) * 0.6
        v = (v + sub) * np.sin(np.pi * t_axis(d) / d)
        v = reverb(v, 2.5, 0.5)
        write_wav(f"voice/witch_low_{i}.wav", fade(norm(v, 0.6)))
    # Witch scream: layered, pitch-falling, distorted
    d = 2.4
    t = t_axis(d)
    curve = [900, 1300, 1100, 700, 380]
    v = formant_voice(d, curve, ["a", "a", "e", "a"], breath=0.8)
    v2 = formant_voice(d, [c * 0.5 for c in curve], ["a", "o", "a", "a"], breath=0.8)
    v3 = formant_voice(d, [c * 1.48 for c in curve], ["i", "e", "a", "a"], breath=0.6)
    s = v + v2 * 0.8 + v3 * 0.5 + bp(white(d), 1500, 7000) * 0.6
    s = np.tanh(s * 3.0) * env_ad(len(t), 0.05, 2.0)
    s = reverb(s, 2.8, 0.4)
    write_wav("voice/witch_scream.wav", fade(norm(s, 0.98)))
    # giggle (short, unstable)
    out = []
    for k in range(5):
        dd = 0.18
        f = 420 - k * 25
        g = formant_voice(dd, [f, f * 1.2, f], ["e", "i"], breath=0.6) * np.sin(np.pi * t_axis(dd) / dd)
        out.append(g)
        out.append(np.zeros(int(0.07 * SR)))
    g = np.concatenate(out)
    write_wav("voice/witch_giggle.wav", fade(norm(reverb(g, 2.0, 0.45), 0.6)))


def sfx_scares():
    # stinger: low boom + high screech cluster
    d = 3.0
    t = t_axis(d)
    boom = kick(2.0) * 1.0
    boom = np.concatenate([boom, np.zeros(len(t) - len(boom))])
    screech = sum(signal.sawtooth(2 * np.pi * f * t * (1 + 0.02 * t)) for f in (1661, 1760, 1864, 2489))
    screech = bp(screech, 1200, 6000) * env_ad(len(t), 0.01, 3.5)
    noise = bp(white(d), 200, 9000) * env_ad(len(t), 0.002, 6)
    y = boom + screech * 0.35 + noise * 0.5
    write_wav("sfx/stinger_1.wav", fade(norm(reverb(np.tanh(y * 1.5), 2.5, 0.35), 0.98)))
    # stinger 2: string-like dissonant cluster swelling
    d = 2.5
    t = t_axis(d)
    cl = sum(signal.sawtooth(2 * np.pi * f * t) for f in (220, 233.1, 246.9, 311.1, 329.6, 659.3, 698.5))
    cl = bp(cl, 150, 5000) * env_ad(len(t), 0.03, 3)
    write_wav("sfx/stinger_2.wav", fade(norm(reverb(cl + kick(d) * 0.8, 2.5, 0.4), 0.95)))
    # violent jumpscare: everything at once
    d = 2.2
    t = t_axis(d)
    y = np.zeros_like(t)
    y += kick(d) * 1.2
    y += np.tanh(bp(white(d), 300, 8000) * 6) * env_ad(len(t), 0.001, 5) * 0.6
    y += sum(np.sin(2 * np.pi * f * t) for f in (1975, 2093, 2217)) * env_ad(len(t), 0.001, 4) * 0.3
    write_wav("sfx/jumpscare_violent.wav", fade(norm(np.tanh(y * 2), 1.0)))
    # thump: deep distant impact
    y = kick(2.0) * 1.0 + lp(brown(2.0), 150) * env_ad(int(2.0 * SR), 0.01, 4) * 0.8
    write_wav("sfx/thump.wav", fade(norm(reverb(y, 3.0, 0.5), 0.9)))
    # whoosh (distortion / teleport)
    d = 1.6
    t = t_axis(d)
    w = pink(d)
    sweep = np.interp(t, [0, d * 0.7, d], [200, 3000, 400])
    y = np.zeros_like(w)
    blk = 1024
    for i in range(0, len(w), blk):
        f = sweep[i]
        y[i:i + blk] = bp(w[max(0, i - 2048): i + blk], f * 0.6, f * 1.6)[-len(w[i:i + blk]):]
    y *= np.sin(np.pi * t / d) ** 2
    write_wav("sfx/whoosh.wav", fade(norm(y, 0.7)))
    # glitch: digital stutter
    d = 0.9
    seg = []
    for _ in range(18):
        L = int(RNG.uniform(0.01, 0.07) * SR)
        kind = RNG.integers(0, 3)
        if kind == 0:
            s = signal.square(2 * np.pi * RNG.uniform(80, 2000) * np.arange(L) / SR) * 0.6
        elif kind == 1:
            s = white(L / SR) * 0.8
        else:
            s = np.zeros(L)
        seg.append(s)
    y = np.concatenate(seg)
    write_wav("sfx/glitch.wav", fade(norm(y, 0.7), 0.001, 0.01))
    # static loop-ish burst
    d = 2.0
    y = bp(white(d), 500, 9000) * (0.6 + 0.4 * (RNG.random(int(d * SR)) > 0.5))
    write_wav("sfx/static.wav", fade(norm(y, 0.5)))
    # tearing (paper/menu ripped from the screen)
    d = 1.1
    t = t_axis(d)
    grit = hp(white(d), 1200) * (RNG.random(len(t)) > 0.6) * np.sin(np.pi * t / d) ** 0.4
    y = grit + bp(white(d), 300, 1500) * env_ad(len(t), 0.05, 2) * 0.5
    write_wav("sfx/tear.wav", fade(norm(y, 0.9)))
    # hand grab: wet-less, cloth/air grab + low hit
    y = bp(white(0.4), 400, 3000) * env_ad(int(0.4 * SR), 0.003, 12) + kick(0.4) * 0.6
    write_wav("sfx/grab.wav", fade(norm(y, 0.85)))
    # glass crack
    d = 1.2
    y = np.zeros(int(d * SR))
    for _ in range(25):
        p = int(RNG.uniform(0, 0.4) * SR)
        L = int(0.05 * SR)
        y[p:p + L] += bp(white(0.05), 3000, 12000) * env_ad(L, 0.0005, 20) * RNG.uniform(0.3, 1.0)
    write_wav("sfx/glass_crack.wav", fade(norm(reverb(y, 1.5, 0.35), 0.8)))
    # clock tick
    y = bp(white(0.03), 2500, 8000) * env_ad(int(0.03 * SR), 0.0005, 30)
    write_wav("sfx/clock_tick.wav", fade(norm(np.concatenate([y, np.zeros(int(0.05 * SR))]), 0.5), 0.0005, 0.01))
    # knock sequence (3 knocks)
    k = kick(0.3) * 0.7 + bp(white(0.3), 150, 1500) * env_ad(int(0.3 * SR), 0.001, 25)
    gap = np.zeros(int(0.25 * SR))
    y = np.concatenate([k, gap, k * 0.9, gap, k * 1.1])
    write_wav("sfx/knock.wav", fade(norm(reverb(y, 1.5, 0.35), 0.8)))
    # distant footsteps sequence (8 steps, receding then stopping)
    seq = []
    for i in range(8):
        d = 0.35
        n = int(d * SR)
        st = bp(white(d), 100, 1500) * env_ad(n, 0.002, 25) + kick(d) * 0.4
        seq.append(st * (1 - i * 0.04))
        seq.append(np.zeros(int(0.42 * SR)))
    y = np.concatenate(seq)
    write_wav("sfx/footsteps_distant.wav", fade(norm(reverb(lp(y, 1800), 2.0, 0.5), 0.6)))
    # running footsteps (Satella chasing) - fast, heavy
    seq = []
    for i in range(10):
        d = 0.2
        n = int(d * SR)
        st = bp(white(d), 80, 2500) * env_ad(n, 0.001, 30) + kick(d) * 0.6
        seq.append(st)
        seq.append(np.zeros(int(0.1 * SR)))
    write_wav("sfx/footsteps_run.wav", fade(norm(reverb(np.concatenate(seq), 1.0, 0.25), 0.8)))
    # shadow hands (writhing, low wet-less swell)
    d = 3.0
    t = t_axis(d)
    y = lp(brown(d), 300) * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * t + np.sin(2 * np.pi * 0.7 * t) * 3))
    y += bp(pink(d), 100, 600) * 0.5
    y *= np.sin(np.pi * t / d)
    write_wav("sfx/shadow_hands.wav", fade(norm(reverb(y, 2.5, 0.4), 0.85)))
    # distortion drone burst (reality bending)
    d = 3.5
    t = t_axis(d)
    f = np.interp(t, [0, d], [40, 25])
    y = signal.sawtooth(np.cumsum(2 * np.pi * f / SR)) + signal.sawtooth(np.cumsum(2 * np.pi * f * 1.5 / SR)) * 0.5
    y = lp(y, 500) * np.sin(np.pi * t / d) + bp(pink(d), 1000, 5000) * 0.2 * np.sin(np.pi * t / d) ** 4
    write_wav("sfx/reality_bend.wav", fade(norm(reverb(y, 3.0, 0.4), 0.85)))


def sfx_return_by_death():
    """The signature Return by Death motif (original): heartbeat collapse into a
    reversed bell swell, a clock that stops, then a glassy rewind."""
    d = 6.0
    t = t_axis(d)
    y = np.zeros_like(t)
    # 1) two heartbeats slowing
    hb = kick(0.3) * 0.9
    for p in (0.0, 0.8, 1.9):
        s = int(p * SR)
        y[s:s + len(hb)] += hb
    # 2) reversed bell swell climaxing at 3.4s
    b = bell(110, 3.0, (1, 2.0, 2.76, 4.1), 0.9) + bell(116.5, 3.0, (1, 2.0, 3.1), 0.9) * 0.7
    rb = b[::-1] * np.linspace(0, 1, len(b)) ** 2
    s = int(0.4 * SR)
    y[s:s + len(rb)] += rb * 0.9
    # 3) impact & clock ticks that stop
    imp = kick(1.5) * 1.0 + bp(white(1.5), 50, 400) * env_ad(int(1.5 * SR), 0.001, 5) * 0.7
    s = int(3.4 * SR)
    y[s:s + len(imp)] += imp[: len(y) - s]
    tick = bp(white(0.03), 2500, 8000) * env_ad(int(0.03 * SR), 0.0005, 30)
    for k, p in enumerate((3.6, 4.1, 4.6, 5.2)):
        s = int(p * SR)
        y[s:s + len(tick)] += tick * (0.6 - k * 0.12)
    y = reverb(y, 4.0, 0.45)
    write_wav("sfx/return_by_death.wav", fade(norm(np.tanh(y * 1.3), 0.95), 0.001, 0.8))
    # rewind / return: glassy reverse shimmer
    d = 2.5
    t = t_axis(d)
    sh = sum(np.sin(2 * np.pi * f * t * (1 + 0.3 * t)) * np.exp(-((t - d * 0.8) ** 2) * 3) for f in (880, 1320, 1760, 2637))
    sh += hp(white(d), 4000) * np.linspace(0, 1, len(t)) ** 3 * 0.3
    sh = reverb(sh, 2.0, 0.5)
    write_wav("sfx/rbd_rewind.wav", fade(norm(sh[::-1], 0.7)))


def main():
    print("Generating ambience…")
    amb_void_wind(); amb_drone(); amb_mansion(); amb_forest(); amb_throne()
    print("Generating music layers…")
    music_dread(); music_presence(); music_chase(); music_lobby(); music_throne(); music_credits()
    print("Generating sfx…")
    sfx_creaks()
    for s in ("wood", "stone", "carpet", "dirt"):
        for i in range(1, 5):
            footstep(s, i)
    sfx_doors(); sfx_flashlight(); sfx_ui(); sfx_items(); sfx_fragment(); sfx_music_box()
    sfx_heart_breath(); sfx_whispers(); sfx_voices(); sfx_scares(); sfx_return_by_death()
    print("Done.")


if __name__ == "__main__":
    main()
