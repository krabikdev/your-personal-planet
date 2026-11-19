"""Generate all soundtrack and SFX assets procedurally.

Run from the project root:
    python tools/generate_audio.py

The music is a 64 second seamlessly looping ambient piece in A minor,
built from slow warm pads, a sparse music-box melody and a circular
reverb. SFX are short, soft, and slightly dusty to match the art.
"""

from __future__ import annotations

import math
import os
import subprocess
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
TMP = os.path.join(ROOT, "tools", ".audio_tmp")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

rng = np.random.default_rng(20261117)


# --------------------------------------------------------------------------- io
def write_wav(path: str, data: np.ndarray) -> None:
    data = np.asarray(data, dtype=np.float64)
    if data.ndim == 1:
        data = data[:, None]
    peak = float(np.max(np.abs(data)))
    if peak > 0.99:
        data = data / peak * 0.99
    pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as fh:
        fh.setnchannels(data.shape[1])
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes(pcm.tobytes())


def normalize(data: np.ndarray, peak: float = 0.8) -> np.ndarray:
    m = float(np.max(np.abs(data)))
    return data if m < 1e-9 else data / m * peak


# ------------------------------------------------------------------- utilities
def t_axis(duration: float) -> np.ndarray:
    return np.arange(int(duration * SR), dtype=np.float64) / SR


def midi(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def env_ar(n: int, attack: float, release: float, hold: float = 0.0) -> np.ndarray:
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    h = max(0, n - a - r)
    parts = [
        np.linspace(0.0, 1.0, a, endpoint=False) ** 1.4,
        np.ones(h),
        np.linspace(1.0, 0.0, r) ** 1.7,
    ]
    env = np.concatenate(parts)
    if env.size < n:
        env = np.pad(env, (0, n - env.size))
    return env[:n]


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Simple one pole low pass, cutoff may be an array."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    alpha = 1.0 - np.exp(-2.0 * math.pi * cutoff / SR)
    out = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc += alpha[i] * (x[i] - acc)
        out[i] = acc
    return out


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def pan_stereo(x: np.ndarray, pan: float) -> np.ndarray:
    """pan in [-1, 1] -> equal power stereo pair."""
    angle = (pan + 1.0) * math.pi / 4.0
    return np.stack([x * math.cos(angle), x * math.sin(angle)], axis=1)


def place(buf: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0) -> None:
    """Add a mono or stereo sound into a stereo buffer at time `at` (seconds)."""
    start = int(at * SR)
    if sound.ndim == 1:
        sound = np.stack([sound, sound], axis=1)
    n = min(sound.shape[0], buf.shape[0] - start)
    if n <= 0:
        return
    buf[start : start + n] += sound[:n] * gain


# ----------------------------------------------------------------------- music
def music_box(freq: float, duration: float, gain: float) -> np.ndarray:
    t = t_axis(duration)
    out = np.zeros_like(t)
    partials = ((1.0, 1.0), (2.0, 0.32), (3.01, 0.16), (4.97, 0.06))
    for ratio, amp in partials:
        detune = 1.0 + rng.uniform(-0.0015, 0.0015)
        out += amp * np.sin(2.0 * math.pi * freq * ratio * detune * t)
    attack = np.minimum(t / 0.012, 1.0)
    env = attack * np.exp(-t / (duration * 0.33))
    return out * env * gain


def pad_note(freq: float, duration: float, gain: float, attack: float, release: float) -> np.ndarray:
    t = t_axis(duration)
    out = np.zeros_like(t)
    for detune, amp in ((0.9975, 0.5), (1.0, 0.7), (1.0025, 0.5)):
        out += amp * np.sin(2.0 * math.pi * freq * detune * t + rng.uniform(0, math.tau))
    out += 0.18 * np.sin(2.0 * math.pi * freq * 2.0 * t + rng.uniform(0, math.tau))
    out += 0.08 * np.sin(2.0 * math.pi * freq * 3.0 * t + rng.uniform(0, math.tau))
    # slow breathing movement
    out *= 1.0 + 0.10 * np.sin(2.0 * math.pi * 0.055 * t + rng.uniform(0, math.tau))
    return out * env_ar(t.size, attack, release) * gain


def make_ambient_music() -> np.ndarray:
    loop_seconds = 64.0
    crossfade = 2.0
    total = loop_seconds + crossfade
    n = int(total * SR)
    buf = np.zeros((n, 2), dtype=np.float64)

    # A minor, 8 bars x 4 s, dreamy voicings.  MIDI notes.
    progression = [
        [45, 57, 60, 64, 67, 71],   # Am9
        [41, 53, 57, 60, 64, 67],   # Fmaj9
        [48, 55, 59, 62, 67, 69],   # Cmaj9
        [43, 55, 58, 62, 65, 69],   # G6/9
        [38, 50, 53, 57, 60, 64],   # Dm9
        [45, 52, 57, 60, 64, 67],   # Am7
        [41, 53, 57, 60, 64, 69],   # Fmaj7/9
        [40, 52, 55, 59, 62, 67],   # Em9
    ]
    bar = 4.0
    for cycle in range(2):
        for i, chord in enumerate(progression):
            start = cycle * 8 * bar + i * bar
            for j, note in enumerate(chord):
                gain = 0.055 if j == 0 else 0.042
                if j >= 4:
                    gain *= 0.75
                p = pad_note(
                    midi(note + (12 if j >= 4 and cycle == 1 else 0)),
                    bar + 2.4,
                    gain,
                    1.6,
                    2.2,
                )
                place(buf, pan_stereo(p, (j - 2.5) * 0.12), start, 1.0)
            # Low root, very soft
            b = pad_note(midi(chord[0] - 12), bar + 2.6, 0.055, 1.0, 2.4)
            place(buf, pan_stereo(b, 0.0), start)

    # Sparse music-box melody (A minor pentatonic), deterministic but human.
    melody = [76, 72, 69, 76, 79, 76, 72, 69, 67, 69, 72, 74, 76, 79, 81, 79]
    times = [4, 10, 17, 22, 30, 38, 45, 51, 58, 66, 74, 82, 90, 98, 106, 114]
    pans = [-0.3, 0.25, -0.1, 0.4, -0.45, 0.15, 0.3, -0.25, 0.45, -0.4, 0.1, -0.15, 0.35, -0.2, 0.2, 0.0]
    for note, at, pan in zip(melody, times, pans):
        if at >= total - 1.0:
            continue
        s = music_box(midi(note), 5.5, 0.075)
        place(buf, pan_stereo(s, pan), at)

    # Airy noise bed.
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = lowpass(noise, 900.0)
    noise = highpass(noise, 90.0)
    noise *= 0.009 * (0.55 + 0.45 * np.sin(2.0 * math.pi * t / 21.0 + 0.7))
    buf[:, 0] += noise
    buf[:, 1] += lowpass(rng.standard_normal(n), 800.0) * 0.009

    # Circular reverb: the impulse is as long as the loop, so the tail folds
    # naturally into the head and the loop seam stays smooth.
    ti = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-ti / 1.45)[:, None]
    ir[:, 0] = lowpass(ir[:, 0], 4200.0)
    ir[:, 1] = lowpass(ir[:, 1], 3400.0)
    ir = ir / np.sqrt(np.sum(ir**2, axis=0, keepdims=True))
    for ch in range(2):
        dry = buf[:, ch]
        wet = np.fft.irfft(np.fft.rfft(dry) * np.fft.rfft(ir[:, ch]), n=n)
        buf[:, ch] = dry * 0.82 + wet * 0.55

    # Soft low end and loop crossfade.
    for ch in range(2):
        buf[:, ch] = highpass(buf[:, ch], 35.0)

    loop_n = int(loop_seconds * SR)
    fade_n = int(crossfade * SR)
    out = buf[:loop_n].copy()
    fade_in = np.sin(np.linspace(0.0, math.pi / 2.0, fade_n))[:, None]
    fade_out = np.cos(np.linspace(0.0, math.pi / 2.0, fade_n))[:, None]
    out[:fade_n] = buf[:fade_n] * fade_in + buf[loop_n : loop_n + fade_n] * fade_out
    # tiny de-click at the splice
    out[0] *= 0.0
    out = normalize(out, 0.72)
    return out


# ------------------------------------------------------------------------- sfx
def footstep() -> np.ndarray:
    d = 0.22
    t = t_axis(d)
    noise = rng.standard_normal(t.size)
    noise = lowpass(noise, 1400.0)
    env = np.exp(-t / 0.045) * np.minimum(t / 0.004, 1.0)
    body = np.sin(2.0 * math.pi * rng.uniform(78, 108) * t) * np.exp(-t / 0.055) * 0.7
    gravel = highpass(rng.standard_normal(t.size), 2500.0) * np.exp(-t / 0.03) * 0.20
    return normalize(noise * env * 0.5 + body + gravel, 0.4)


def jump_sfx() -> np.ndarray:
    d = 0.55
    t = t_axis(d)
    f = 260.0 * (1.0 + 2.1 * (t / d) ** 0.7)
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    tone = np.sin(phase) * np.exp(-t / 0.24) * 0.4
    noise = rng.standard_normal(t.size)
    noise = lowpass(noise, 2200.0)
    noise *= np.exp(-((t - 0.10) / 0.13) ** 2) * 0.25
    return normalize(tone + noise, 0.45)


def land_sfx() -> np.ndarray:
    d = 0.42
    t = t_axis(d)
    f = 90.0 * np.exp(-t / 0.10) + 42.0
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    thump = np.sin(phase) * np.exp(-t / 0.11) * 0.9
    grit = lowpass(rng.standard_normal(t.size), 1800.0) * np.exp(-t / 0.09) * 0.5
    return normalize(thump + grit, 0.55)


def catch_sfx() -> np.ndarray:
    d = 1.5
    t = t_axis(d)
    out = np.zeros_like(t)
    for i, (note, at) in enumerate(((76, 0.0), (79, 0.10), (83, 0.21), (88, 0.33))):
        s = music_box(midi(note), 1.4, 0.22)
        start = int(at * SR)
        n = min(s.size, out.size - start)
        out[start : start + n] += s[:n]
    shimmer = highpass(rng.standard_normal(t.size), 6000.0) * np.exp(-t / 0.35) * 0.08
    return normalize(out + shimmer, 0.5)


def smear_sfx() -> np.ndarray:
    d = 3.4
    t = t_axis(d)
    noise = rng.standard_normal(t.size)
    noise = lowpass(noise, 1700.0)
    scrapes = 0.55 + 0.45 * np.sin(2.0 * math.pi * 1.35 * t) ** 2
    env = np.minimum(t / 0.25, 1.0) * np.clip((d - t) / 0.4, 0.0, 1.0)
    rumble = np.sin(2.0 * math.pi * 48.0 * t) * 0.18
    return normalize(noise * scrapes * env + rumble, 0.32)


def grow_sfx() -> np.ndarray:
    d = 3.2
    t = t_axis(d)
    f = 62.0 * np.exp(-t / 1.2) + 32.0
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    boom = np.sin(phase) * np.exp(-t / 0.85) * 0.8
    rumble = lowpass(rng.standard_normal(t.size), 420.0) * np.exp(-t / 1.1) * 0.6
    shimmer = np.zeros_like(t)
    for note in (52, 59, 64, 69, 76):
        shimmer += np.sin(2.0 * math.pi * midi(note) * t) * np.exp(-((t - 1.2) / 0.7) ** 2)
    shimmer *= 0.035
    return normalize(boom + rumble + shimmer, 0.62)


def whoosh_sfx() -> np.ndarray:
    d = 3.8
    t = t_axis(d)
    centre = t / d
    sweep = np.sin(np.pi * np.clip(centre, 0.0, 1.0)) ** 1.4
    noise = rng.standard_normal(t.size)
    band = highpass(lowpass(noise, 2400.0), 180.0)
    tone = np.sin(2.0 * math.pi * (110.0 + 90.0 * sweep) * t) * 0.14
    fade = np.minimum(t / 0.25, 1.0) * np.clip((d - t) / 0.45, 0.0, 1.0)
    return normalize((band * 0.55 + tone) * sweep * fade, 0.42)


def ping_sfx() -> np.ndarray:
    d = 2.0
    t = t_axis(d)
    out = np.zeros_like(t)
    for delay, gain in ((0.0, 1.0), (0.22, 0.35), (0.46, 0.15)):
        start = int(delay * SR)
        n = out.size - start
        tt = t[:n]
        s = np.sin(2.0 * math.pi * 880.0 * tt) * np.exp(-tt / 0.45)
        s += 0.3 * np.sin(2.0 * math.pi * 1320.0 * tt) * np.exp(-tt / 0.25)
        out[start:] += s * gain
    return normalize(out, 0.35)


def freeze_sfx() -> np.ndarray:
    d = 4.6
    t = t_axis(d)
    f = 180.0 * np.exp(-t / 2.5) + 38.0
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    drone = (np.sin(phase) + 0.3 * np.sin(phase * 2.01)) * 0.4
    drone *= np.exp(-t / 3.2) * np.minimum(t / 0.4, 1.0)
    crackle = np.zeros_like(t)
    for _ in range(26):
        at = rng.uniform(0.0, d - 0.2)
        ln = int(rng.uniform(0.006, 0.03) * SR)
        start = int(at * SR)
        burst = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln * 0.35)) * rng.uniform(0.05, 0.18)
        crackle[start : start + ln] += highpass(burst, 2500.0)
    wind = lowpass(rng.standard_normal(t.size), 700.0) * 0.07 * np.sin(np.pi * t / d)
    return normalize(drone + crackle + wind, 0.55)


def ui_click() -> np.ndarray:
    d = 0.10
    t = t_axis(d)
    tone = np.sin(2.0 * math.pi * 720.0 * t) * np.exp(-t / 0.015) * 0.3
    noise = highpass(rng.standard_normal(t.size), 3500.0) * np.exp(-t / 0.006) * 0.25
    return normalize(tone + noise, 0.28)


def wind_sfx() -> np.ndarray:
    d = 2.2
    t = t_axis(d)
    noise = lowpass(rng.standard_normal(t.size), 600.0)
    env = np.sin(np.pi * t / d) ** 1.5
    return normalize(noise * env, 0.24)


def sprout_sfx() -> np.ndarray:
    """A soft pop and a rustle as a stalk pushes out of the dust."""
    d = 0.8
    t = t_axis(d)
    f = 150.0 + 320.0 * (1.0 - np.exp(-t / 0.07))
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    pop = np.sin(phase) * np.exp(-((t - 0.06) / 0.075) ** 2) * 0.55
    pop += 0.18 * np.sin(phase * 2.02) * np.exp(-((t - 0.06) / 0.05) ** 2)
    soil = lowpass(rng.standard_normal(t.size), 760.0) * np.exp(-t / 0.2) * 0.5
    rustle = highpass(rng.standard_normal(t.size), 2800.0)
    rustle *= np.exp(-((t - 0.16) / 0.14) ** 2) * 0.10
    return normalize(pop + soil + rustle, 0.42)


def mature_sfx() -> np.ndarray:
    """A small rising chime when the stalk has grown its pumpkin head."""
    d = 2.4
    out = np.zeros(int(d * SR))
    for note, at, gain in ((72, 0.0, 0.9), (76, 0.13, 0.8), (79, 0.26, 0.7), (84, 0.40, 0.55)):
        s = music_box(midi(note), 1.9, 0.2 * gain)
        start = int(at * SR)
        n = min(s.size, out.size - start)
        out[start : start + n] += s[:n]
    shimmer = highpass(rng.standard_normal(out.size), 5200.0) * np.exp(-t_axis(d) / 0.5) * 0.05
    return normalize(out + shimmer, 0.4)


def loop_seam(x: np.ndarray, fade_seconds: float = 0.06) -> np.ndarray:
    """Folds the tail of a sound into its head so it can loop without a click.

    The first samples morph from the discarded tail into the true beginning, so
    the wrap from the last sample back to the first is a continuation of the
    same waveform rather than a jump.
    """
    fade = max(1, int(fade_seconds * SR))
    if x.size <= fade * 2:
        return x
    ramp = np.linspace(0.0, 1.0, fade)
    if x.ndim > 1:
        ramp = ramp[:, None]
    head = x[-fade:] * (1.0 - ramp) + x[:fade] * ramp
    out = x[:-fade].copy()
    out[:fade] = head
    return out


def water_pour_sfx() -> np.ndarray:
    """A quiet, seamlessly looping trickle for the watering can."""
    d = 1.2
    t = t_axis(d)
    noise = rng.standard_normal(t.size)
    body = highpass(lowpass(noise, 2400.0), 500.0)
    body *= 0.55 + 0.18 * np.sin(2.0 * math.pi * 2.0 * t) + 0.10 * np.sin(2.0 * math.pi * 5.0 * t + 1.1)
    gurgle = np.zeros_like(t)
    for at, freq, gain in ((0.10, 620.0, 0.10), (0.38, 810.0, 0.07), (0.71, 540.0, 0.08), (0.97, 900.0, 0.05)):
        gurgle += np.sin(2.0 * math.pi * freq * t) * np.exp(-((t - at) / 0.05) ** 2) * gain
    splash = highpass(rng.standard_normal(t.size), 3800.0) * 0.12
    splash *= 0.5 + 0.5 * np.sin(2.0 * math.pi * 3.0 * t + 0.4)
    out = normalize(body * 0.8 + gurgle + splash, 0.3)
    return loop_seam(out)


def spit_sfx() -> np.ndarray:
    """The little pumpkin head's wet 'ptoo' as the acid leaves its mouth."""
    d = 0.5
    t = t_axis(d)
    f = 120.0 + 520.0 * np.exp(-t / 0.10)
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    mouth = np.sin(phase) * np.exp(-t / 0.09) * 0.6
    spray = highpass(rng.standard_normal(t.size), 1700.0)
    spray *= np.exp(-((t - 0.04) / 0.09) ** 2) * 0.55
    droplet = lowpass(rng.standard_normal(t.size), 900.0) * np.exp(-t / 0.14) * 0.35
    return normalize(mouth + spray + droplet, 0.45)


def acid_hit_sfx() -> np.ndarray:
    """A corrosive pop and hiss where the blob lands on a monster."""
    d = 0.9
    t = t_axis(d)
    pop = np.sin(2.0 * math.pi * 190.0 * t) * np.exp(-t / 0.045) * 0.7
    sizzle = highpass(rng.standard_normal(t.size), 2500.0)
    sizzle *= np.exp(-t / 0.26) * (0.55 + 0.45 * np.sin(2.0 * math.pi * 31.0 * t) ** 2)
    wet = lowpass(rng.standard_normal(t.size), 700.0) * np.exp(-t / 0.12) * 0.4
    return normalize(pop + sizzle * 0.8 + wet, 0.5)


def death_caterpillar_sfx() -> np.ndarray:
    """A soft soggy squelch and settling fuzz: the caterpillar gives up."""
    d = 1.1
    t = t_axis(d)
    f = 70.0 + 210.0 * np.exp(-t / 0.16)
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    squelch = np.sin(phase) * np.exp(-t / 0.20) * 0.7
    fuzz = lowpass(rng.standard_normal(t.size), 1500.0) * np.exp(-t / 0.26) * 0.45
    crumble = highpass(rng.standard_normal(t.size), 3200.0) * np.exp(-t / 0.12) * 0.16
    return normalize(squelch + fuzz + crumble, 0.5)


def death_hydralisk_sfx() -> np.ndarray:
    """A wet rising screech that collapses into a gurgle."""
    d = 1.6
    t = t_axis(d)
    rise = np.minimum(t / 0.35, 1.0)
    fall = np.clip((t - 0.35) / 1.0, 0.0, 1.0)
    f = 300.0 + 470.0 * rise - 250.0 * fall
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    screech = (np.sin(phase) + 0.4 * np.sin(phase * 2.03)) * np.exp(-t / 0.55) * 0.55
    hiss = highpass(rng.standard_normal(t.size), 2600.0) * np.exp(-t / 0.4) * 0.3
    gurgle = lowpass(rng.standard_normal(t.size), 700.0) * np.exp(-t / 0.32) * 0.4
    return normalize(screech + hiss + gurgle, 0.5)


def death_ragnos_sfx() -> np.ndarray:
    """A hulking growl that ends in a heavy body hitting the dust."""
    d = 2.0
    t = t_axis(d)
    f = 40.0 + 100.0 * np.exp(-t / 0.5)
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    growl = np.sin(phase) * np.exp(-t / 0.7) * 0.8
    growl *= 1.0 + 0.3 * np.sin(2.0 * math.pi * 17.0 * t)
    thud = lowpass(rng.standard_normal(t.size), 320.0)
    thud *= np.exp(-((t - 0.55) / 0.22) ** 2) * 0.65
    crack = highpass(rng.standard_normal(t.size), 2400.0)
    crack *= np.exp(-((t - 0.62) / 0.08) ** 2) * 0.18
    return normalize(growl + thud + crack, 0.55)


def death_zodd_sfx() -> np.ndarray:
    """The huge minotaur's last bellow, a long rumble and falling rubble."""
    d = 2.8
    t = t_axis(d)
    f = 26.0 + 80.0 * np.exp(-t / 0.8)
    phase = 2.0 * math.pi * np.cumsum(f) / SR
    bellow = (np.sin(phase) + 0.35 * np.sin(phase * 1.51)) * np.exp(-t / 1.1) * 0.85
    bellow *= 1.0 + 0.25 * np.sin(2.0 * math.pi * 9.0 * t)
    rumble = lowpass(rng.standard_normal(t.size), 220.0)
    rumble *= np.exp(-((t - 0.9) / 0.6) ** 2) * 0.7
    debris = np.zeros_like(t)
    for _ in range(18):
        at = rng.uniform(0.4, d - 0.2)
        ln = int(rng.uniform(0.01, 0.05) * SR)
        start = int(at * SR)
        burst = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln * 0.35))
        debris[start : start + ln] += highpass(burst, 1800.0) * rng.uniform(0.04, 0.14)
    return normalize(bellow + rumble + debris, 0.6)


def main() -> None:
    print("Rendering ambient music (this takes a few seconds)...")
    music = make_ambient_music()
    music_wav = os.path.join(TMP, "ambient_space.wav")
    write_wav(music_wav, music)
    music_ogg = os.path.join(OUT, "ambient_space.ogg")
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error", "-i", music_wav,
            "-c:a", "libvorbis", "-qscale:a", "6", music_ogg,
        ],
        check=True,
    )
    print("  music:", os.path.relpath(music_ogg, ROOT))

    sfx = {
        "footstep_1": footstep(),
        "footstep_2": footstep(),
        "jump": jump_sfx(),
        "land": land_sfx(),
        "catch": catch_sfx(),
        "smear": smear_sfx(),
        "grow": grow_sfx(),
        "whoosh": whoosh_sfx(),
        "ping": ping_sfx(),
        "freeze": freeze_sfx(),
        "ui_click": ui_click(),
        "wind": wind_sfx(),
        "sprout": sprout_sfx(),
        "mature": mature_sfx(),
        "water_pour": water_pour_sfx(),
        "spit": spit_sfx(),
        "acid_hit": acid_hit_sfx(),
        "death_caterpillar": death_caterpillar_sfx(),
        "death_hydralisk": death_hydralisk_sfx(),
        "death_ragnos": death_ragnos_sfx(),
        "death_zodd": death_zodd_sfx(),
    }
    for name, data in sfx.items():
        path = os.path.join(OUT, name + ".wav")
        write_wav(path, normalize(data, 0.85))
        print("  sfx:", os.path.relpath(path, ROOT))

    os.remove(music_wav)
    print("Done.")


if __name__ == "__main__":
    main()
