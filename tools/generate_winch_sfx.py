"""Generate the rope winch loop used while the boy reels himself in.

    python tools/generate_winch_sfx.py

Writes a seamlessly loopable 16-bit mono 44.1 kHz WAV next to the other audio:

    assets/audio/winch.wav

The sound is a small hand winch: a steady one-second ratchet pattern of
fourteen metallic clicks over a quiet mechanical hum, so it can loop for as
long as the boy is pulling himself along the rope.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
DURATION = 1.0
CLICKS = 14
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"


def lowpass(samples: list[float], cutoff: float) -> list[float]:
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    out: list[float] = []
    state = 0.0
    for sample in samples:
        state += alpha * (sample - state)
        out.append(state)
    return out


def noise(count: int) -> list[float]:
    return [random.uniform(-1.0, 1.0) for _ in range(count)]


def add_click(out: list[float], start: float, gain: float, shout: float) -> None:
    begin = int(start * SAMPLE_RATE)
    length = int(0.09 * SAMPLE_RATE)
    grain = lowpass(noise(length), 2600.0)
    for i in range(length):
        index = (begin + i) % len(out)
        t = i / SAMPLE_RATE
        click_env = math.exp(-t * 70.0)
        ring_env = math.exp(-t * 38.0)
        clunk = math.sin(2.0 * math.pi * (150.0 - 60.0 * min(1.0, t * 12.0)) * t)
        ring = math.sin(2.0 * math.pi * 2350.0 * t) + 0.6 * math.sin(2.0 * math.pi * 3180.0 * t)
        out[index] += (
            grain[i] * click_env * 0.55
            + clunk * math.exp(-t * 26.0) * 0.30
            + ring * ring_env * 0.10 * shout
        ) * gain


def make_winch() -> list[float]:
    total = int(DURATION * SAMPLE_RATE)
    out = [0.0] * total
    period = DURATION / CLICKS

    # Ratchet clicks, with a gentle one-second swell so the loop breathes.
    for click in range(CLICKS):
        progress = click / CLICKS
        swell = 0.82 + 0.18 * math.sin(2.0 * math.pi * progress)
        shout = 0.9 + 0.2 * math.sin(2.0 * math.pi * progress * 2.0)
        add_click(out, click * period, swell, shout)

    # Quiet motor hum: integer cycles per loop keep the seam inaudible.
    for i in range(total):
        t = i / SAMPLE_RATE
        hum = math.sin(2.0 * math.pi * 60.0 * t) * 0.055
        hum += math.sin(2.0 * math.pi * 120.0 * t + 0.7) * 0.025
        gear = math.sin(2.0 * math.pi * 14.0 * t) ** 2 * 0.02
        out[i] += hum + gear

    # A thin whirr of the rope running through the drum.
    whirr = lowpass(noise(total), 1800.0)
    for i in range(total):
        t = i / SAMPLE_RATE
        gate = 0.5 + 0.5 * math.sin(2.0 * math.pi * 14.0 * t)
        out[i] += whirr[i] * gate * 0.05

    peak = max(abs(sample) for sample in out) or 1.0
    scale = 0.82 / peak
    return [math.tanh(sample * scale * 1.1) for sample in out]


def write_wav(path: Path, samples: list[float]) -> None:
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767)) for sample in samples
    )
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)


def main() -> None:
    random.seed(20261120)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_wav(OUTPUT_DIR / "winch.wav", make_winch())
    print("Wrote winch.wav to", OUTPUT_DIR)


if __name__ == "__main__":
    main()
