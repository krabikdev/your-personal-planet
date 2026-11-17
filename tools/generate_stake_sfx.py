"""Generate the two stake sounds procedurally so they stay in the repo.

    python tools/generate_stake_sfx.py

Outputs 16-bit mono 44.1 kHz WAV files next to the other game audio:

    assets/audio/stake_plant.wav  - a shovel biting into soil
    assets/audio/stake_pull.wav   - the stake being ripped back out of it

The sound design is deliberately dull and earthy: a low thump for the weight,
a short metallic tick for the shovel head, crumbling grit for the soil and a
little suction sweep on the way out.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"


def lowpass(samples: list[float], cutoff: float) -> list[float]:
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    out: list[float] = []
    state = 0.0
    for sample in samples:
        state += alpha * (sample - state)
        out.append(state)
    return out


def highpass(samples: list[float], cutoff: float) -> list[float]:
    low = lowpass(samples, cutoff)
    return [sample - low_sample for sample, low_sample in zip(samples, low)]


def noise(count: int) -> list[float]:
    return [random.uniform(-1.0, 1.0) for _ in range(count)]


def add_thump(
    out: list[float], start: float, length: float, from_hz: float, to_hz: float, gain: float
) -> None:
    begin = int(start * SAMPLE_RATE)
    total = int(length * SAMPLE_RATE)
    phase = 0.0
    for i in range(total):
        index = begin + i
        if index >= len(out):
            break
        t = i / SAMPLE_RATE
        hz = from_hz + (to_hz - from_hz) * (i / max(total - 1, 1))
        phase += 2.0 * math.pi * hz / SAMPLE_RATE
        envelope = math.exp(-t * 11.0)
        out[index] += math.sin(phase) * envelope * gain


def add_burst(
    out: list[float],
    start: float,
    length: float,
    cutoff: float,
    decay: float,
    gain: float,
    attack: float = 0.004,
) -> None:
    begin = int(start * SAMPLE_RATE)
    total = int(length * SAMPLE_RATE)
    grain = lowpass(noise(total), cutoff)
    for i in range(total):
        index = begin + i
        if index >= len(out):
            break
        t = i / SAMPLE_RATE
        edge = min(1.0, t / attack)
        envelope = edge * math.exp(-t * decay)
        out[index] += grain[i] * envelope * gain


def add_crackle(
    out: list[float], start: float, length: float, count: int, gain: float
) -> None:
    for _ in range(count):
        offset = start + random.uniform(0.0, length)
        begin = int(offset * SAMPLE_RATE)
        total = int(random.uniform(0.006, 0.02) * SAMPLE_RATE)
        decay = random.uniform(90.0, 180.0)
        low_band = lowpass(noise(total), random.uniform(700.0, 2200.0))
        amplitude = gain * random.uniform(0.35, 1.0)
        for i in range(total):
            index = begin + i
            if index >= len(out):
                break
            envelope = math.exp(-(i / SAMPLE_RATE) * decay)
            out[index] += low_band[i] * envelope * amplitude


def add_tick(out: list[float], start: float, hz: float, gain: float) -> None:
    begin = int(start * SAMPLE_RATE)
    total = int(0.05 * SAMPLE_RATE)
    for i in range(total):
        index = begin + i
        if index >= len(out):
            break
        t = i / SAMPLE_RATE
        envelope = math.exp(-t * 70.0)
        out[index] += math.sin(2.0 * math.pi * hz * t) * envelope * gain


def add_sweep(
    out: list[float], start: float, length: float, low_hz: float, high_hz: float, gain: float
) -> None:
    begin = int(start * SAMPLE_RATE)
    total = int(length * SAMPLE_RATE)
    raw = noise(total)
    smooth = 0.0
    for i in range(total):
        index = begin + i
        if index >= len(out):
            break
        t = i / SAMPLE_RATE
        progress = i / max(total - 1, 1)
        cutoff = low_hz + (high_hz - low_hz) * progress
        alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
        smooth += alpha * (raw[i] - smooth)
        shape = math.sin(math.pi * min(1.0, progress * 1.05))
        out[index] += smooth * shape * gain


def finish(samples: list[float], peak: float = 0.86) -> list[float]:
    high = max(abs(sample) for sample in samples) or 1.0
    scale = peak / high
    total = len(samples)
    fade = int(0.012 * SAMPLE_RATE)
    out: list[float] = []
    for i, sample in enumerate(samples):
        value = math.tanh(sample * scale * 1.15)
        if i < fade:
            value *= i / fade
        if i > total - fade:
            value *= max(0.0, (total - i) / fade)
        out.append(value)
    return out


def write_wav(path: Path, samples: list[float]) -> None:
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767)) for sample in samples
    )
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)


def make_plant() -> list[float]:
    duration = 0.85
    out = [0.0] * int(duration * SAMPLE_RATE)

    # The weight of the steel head landing in packed dirt.
    add_thump(out, 0.0, 0.42, 118.0, 46.0, 0.62)
    add_burst(out, 0.0, 0.30, 850.0, 12.0, 0.40)
    add_burst(out, 0.006, 0.18, 2400.0, 26.0, 0.16)
    add_tick(out, 0.002, 1750.0, 0.10)
    add_tick(out, 0.012, 2650.0, 0.05)

    # Soil crumbling away from the blade.
    add_burst(out, 0.018, 0.55, 480.0, 6.0, 0.22)
    add_crackle(out, 0.02, 0.58, 34, 0.55)

    # A small trickle of loose grit settling afterwards.
    add_crackle(out, 0.32, 0.45, 12, 0.18)
    return finish(out)


def make_pull() -> list[float]:
    duration = 0.9
    out = [0.0] * int(duration * SAMPLE_RATE)

    # The stake unsticking with a wet pop.
    add_burst(out, 0.0, 0.20, 900.0, 24.0, 0.42)
    add_thump(out, 0.0, 0.20, 132.0, 78.0, 0.34)
    add_tick(out, 0.004, 1200.0, 0.07)

    # Air and loose earth sucking into the hole as it comes free.
    add_sweep(out, 0.04, 0.46, 260.0, 2100.0, 0.24)
    add_burst(out, 0.02, 0.55, 520.0, 5.0, 0.18)
    add_crackle(out, 0.03, 0.62, 30, 0.5)
    add_crackle(out, 0.42, 0.35, 10, 0.16)

    # Light metallic ring from the freed tip.
    add_tick(out, 0.09, 980.0, 0.08)
    add_tick(out, 0.1, 1480.0, 0.04)
    return finish(out)


def main() -> None:
    random.seed(20261118)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_wav(OUTPUT_DIR / "stake_plant.wav", make_plant())
    # Reseed so the second sound is independent but still reproducible.
    random.seed(20261119)
    write_wav(OUTPUT_DIR / "stake_pull.wav", make_pull())
    print("Wrote stake_plant.wav and stake_pull.wav to", OUTPUT_DIR)


if __name__ == "__main__":
    main()
