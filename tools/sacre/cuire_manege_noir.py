#!/usr/bin/env python3
"""LA BOÎTE À MUSIQUE DU MANÈGE NOIR — « musique autre, car c'est légendaire » (18-09).

Le manège orange tourne sur `manege-nappe.caf` (2 ch, 48 kHz, Int16, 25 s en
boucle sans couture). Le noir mérite la sienne : plus lente, plus grave, en
mineur — une boîte à musique dans le noir, un bourdon sous elle. Tout est
synthétisé ici (numpy), périodique PAR CONSTRUCTION : les queues des notes
qui dépassent la fin rebouclent au début (addition circulaire), donc aucune
couture.

Recette : la mineur · 24 s (= 24 temps à 60 bpm) · bourdon A1/A2 (sinus + LFO
lent) · celesta (sinus + 2 harmoniques, décroissance 1,8 s) sur un motif
clairsemé de 16 notes, écho à la croche pointée, panoramique par note ·
un souffle d'air filtré très bas. Crête −9 dBFS (le volume de croisière est
réglé dans BoosterAmbience, 0,22 comme le manège).

Sortie : Nosfy/Media/manege-noir.caf (via afconvert), preview tools/sacre/noir/manege-noir.wav
"""
import os, subprocess, wave
import numpy as np

R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR, DUR, BPM = 48000, 24.0, 60
N = int(SR * DUR); t = np.arange(N) / SR
rng = np.random.default_rng(18)

def note_hz(semis_from_a4): return 440.0 * 2 ** (semis_from_a4 / 12)
def circ_add(buf, sig, start):
    """ajoute sig à buf à partir de start (échantillons), en rebouclant."""
    idx = (np.arange(len(sig)) + start) % len(buf)
    np.add.at(buf, idx, sig)

L = np.zeros(N); Rr = np.zeros(N)

# 1. le bourdon — A1 (55 Hz) et A2, respiration lente (période 12 s → 2 par boucle)
lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / 12.0 - np.pi / 2)
bourdon = (0.16 * np.sin(2 * np.pi * 55 * t) + 0.09 * np.sin(2 * np.pi * 110 * t + 0.3)
           + 0.03 * np.sin(2 * np.pi * 165 * t)) * (0.55 + 0.45 * lfo)
L += bourdon; Rr += bourdon

# 2. la celesta — motif en la mineur (A4 C5 E5 D5 B4 G4 …), clairsemé, 16 notes / 24 temps
motif = [(0, 0), (1.5, 3), (3, 7), (4.5, 5), (6, -2), (7.5, 0), (9, 3), (10.5, 12),
         (12, 7), (13.5, 3), (15, 0), (16.5, -5), (18, -2), (19.5, 3), (21, 7), (22.5, 12)]
def celesta(hz, dur=2.2, amp=0.22):
    n = int(SR * dur); tt = np.arange(n) / SR
    env = np.exp(-tt / 0.75) * (1 - np.exp(-tt / 0.004))
    s = (np.sin(2 * np.pi * hz * tt) + 0.35 * np.sin(2 * np.pi * hz * 2 * tt) * np.exp(-tt / 0.35)
         + 0.12 * np.sin(2 * np.pi * hz * 3.01 * tt) * np.exp(-tt / 0.18))
    return amp * env * s
for beat, semis in motif:
    hz = note_hz(semis); start = int(beat * 60 / BPM * SR)
    pan = 0.5 + 0.35 * np.sin(beat * 1.3)          # chaque note a sa place dans la stéréo
    sig = celesta(hz)
    circ_add(L, sig * (1 - pan) ** 0.5, start); circ_add(Rr, sig * pan ** 0.5, start)
    # l'écho : croche pointée (0,75 temps) plus tard, plus doux, de l'autre côté
    echo = celesta(hz, dur=1.6, amp=0.09)
    d = start + int(0.75 * 60 / BPM * SR)
    circ_add(L, echo * pan ** 0.5, d); circ_add(Rr, echo * (1 - pan) ** 0.5, d)

# 3. un souffle très bas (bruit filtré par moyenne glissante longue), à peine là
bruit = rng.standard_normal(N)
k = 400; noyau = np.ones(k) / k
souffle = np.convolve(np.concatenate([bruit[-k:], bruit]), noyau, mode="same")[k:]
souffle *= 0.05 * (0.6 + 0.4 * lfo)
L += souffle; Rr += souffle * 0.9

# 4. couture : fondu croisé de 200 ms entre la fin et le début (ceinture + bretelles)
f = int(0.2 * SR); w = np.linspace(0, 1, f)
for ch in (L, Rr):
    tete = ch[:f].copy(); ch[:f] = tete * w + ch[-f:] * (1 - w); ch[-f:] = ch[-f:] * (1 - w) + tete * w

st = np.stack([L, Rr], axis=1)
st *= (10 ** (-9 / 20)) / np.abs(st).max()
wav = os.path.join(R, "tools", "sacre", "noir", "manege-noir.wav")
with wave.open(wav, "wb") as f_:
    f_.setnchannels(2); f_.setsampwidth(2); f_.setframerate(SR)
    f_.writeframes((st * 32767).astype("<i2").tobytes())
caf = os.path.join(R, "Nosfy", "Media", "manege-noir.caf")
subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16@48000", wav, caf], check=True)
print("manege-noir.caf :", os.path.getsize(caf), "o —", DUR, "s, 48 kHz, 2 ch")
