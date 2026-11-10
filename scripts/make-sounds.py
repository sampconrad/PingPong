"""Generates PingPong/Assets/ping.ogg, pong.ogg and error.ogg: short original tones.

Needs numpy and soundfile (pip install numpy soundfile). Run from the repo root:
    python scripts/make-sounds.py
"""

import numpy as np
import soundfile as sf

RATE = 44100
OUT = "PingPong/Assets/"


def tone(freq, seconds, decay, partials, glide=1.0):
    t = np.arange(int(RATE * seconds)) / RATE
    # The pitch glides from freq * glide down to freq in the first moments.
    f = freq * (1 + (glide - 1) * np.exp(-t * 40))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    wave = sum(amp * np.sin(phase * mult) for mult, amp in partials)
    attack = np.minimum(t / 0.004, 1)
    release = np.minimum((seconds - t) / 0.02, 1)
    return wave * attack * release * np.exp(-t * decay)


def save(name, wave, peak):
    wave = wave / np.abs(wave).max() * peak
    sf.write(OUT + name, wave.astype(np.float32), RATE, format="OGG", subtype="VORBIS")


# Ping: bright and quick, a little bell-like.
save("ping.ogg", tone(1320, 0.5, 9, [(1, 1), (2.01, 0.35), (3.02, 0.12)]), 0.6)
# Pong: lower, rounder and a touch longer, with a small downward bend like a reply.
save("pong.ogg", tone(660, 0.6, 7, [(1, 1), (2, 0.25)], glide=1.12), 0.6)
# Error: two short low blips, the second lower, with a slightly buzzy edge so it reads as "no".
blip = tone(220, 0.12, 14, [(1, 1), (2, 0.6), (3, 0.4), (5, 0.2)])
low = tone(165, 0.18, 12, [(1, 1), (2, 0.6), (3, 0.4), (5, 0.2)])
gap = np.zeros(int(RATE * 0.04))
save("error.ogg", np.concatenate([blip, gap, low]), 0.6)
