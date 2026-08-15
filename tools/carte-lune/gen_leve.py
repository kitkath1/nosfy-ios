#!/usr/bin/env python3
"""Le LEVER du booster — le son du tirage hors du sol.

Verdict : le whoop de MoonGlide était « très triste » (le cube du
splash). Ici : un fragment d'arpège MINEUR en clochettes douces —
sol 4, si bémol 4, ré 5 — l'ascension poétique et mélancolique, portée
par un souffle d'air. Trois partiels par cloche, attaque feutrée,
longue traîne. Sortie : Woop/Media/BoosterLeve.wav
"""

import math
import struct
import wave

SR = 44100
DUREE = 1.6
N = int(SR * DUREE)


def cloche(f, t0, amp, decay):
    """Une clochette : partiels 1/2/3, attaque 12 ms, traîne exp."""
    out = [0.0] * N
    debut = int(t0 * SR)
    for i in range(debut, N):
        t = (i - debut) / SR
        att = min(1.0, t / 0.012)
        env = att * math.exp(-t / decay)
        v = (math.sin(2 * math.pi * f * t)
             + 0.38 * math.sin(2 * math.pi * f * 2.01 * t)
             + 0.14 * math.sin(2 * math.pi * f * 2.99 * t))
        out[i] = amp * env * v
    return out


def souffle(t0, duree, amp):
    """Le souffle : bruit adouci (moyenne glissante), enveloppe en cloche."""
    import random
    random.seed(7)
    out = [0.0] * N
    debut = int(t0 * SR)
    fin = min(N, debut + int(duree * SR))
    prev = 0.0
    for i in range(debut, fin):
        t = (i - debut) / (fin - debut)
        env = math.sin(math.pi * t) ** 2
        prev = 0.985 * prev + 0.015 * (random.random() * 2 - 1)
        out[i] = amp * env * prev * 8.0
    return out


# L'arpège de sol mineur qui MONTE — la poésie de l'extraction.
voix = [
    cloche(392.00, 0.00, 0.50, 0.55),   # sol 4
    cloche(466.16, 0.16, 0.44, 0.60),   # si bémol 4
    cloche(587.33, 0.34, 0.36, 0.75),   # ré 5 — la traîne la plus longue
    souffle(0.0, 0.9, 0.10),
]

mix = [sum(v[i] for v in voix) for i in range(N)]
pic = max(abs(x) for x in mix)
gain = 0.28 / pic  # marge large : le son doit rester un murmure
# Fondu de sortie propre sur les 300 dernières ms.
for i in range(N):
    t = i / SR
    fade = min(1.0, (DUREE - t) / 0.3)
    mix[i] *= gain * fade

with wave.open("/Users/kathryn/Desktop/woochoper-ios/Woop/Media/BoosterLeve.wav", "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(
        struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in mix))
print("BoosterLeve.wav écrit")
