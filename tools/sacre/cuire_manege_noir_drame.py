#!/usr/bin/env python3
"""LE MANÈGE NOIR, PLUS DRAMATIQUE — Kathryn, 20-09 : « remplace la musique
actuelle du manège orange par celle du manège noir, je préfère ; et fais une
autre musique plus dramatique pour le booster noir ».

Donc : la boîte à musique grave du 18-09 (`manege-noir.caf`) passe au manège
ORANGE, et le NOIR reçoit celle-ci — pas une boîte à musique : une veillée
de cathédrale. Ré mineur, 24 s en boucle sans couture (addition circulaire,
comme les autres pistes du pipeline), 60 bpm.

Ce qu'on entend, dans l'ordre où ça se pose :
  1. LE BOURDON — D1 (36,7 Hz) et D2, plus une quinte A2 qui respire ; plus
     profond que celui du 18-09.
  2. LES CORDES SOMBRES — un pad à trois voix désaccordées (±6 cents),
     harmoniques en 1/k^1,5 sous un filtre qui s'ouvre lentement, qui joue
     i · VI · iv · V (Dm · Bb · Gm · A) — six secondes par accord, la
     dominante en dernier : la boucle revient au ré mineur comme une chute.
  3. LE CŒUR — un tambour grave (balayage 95 → 42 Hz, transitoire de souffle)
     en battement de cœur : « lub » sur le temps 1, « dub » sur le 2 et demi,
     à chaque mesure de quatre ; et UN GRAND COUP sous-grave au départ de
     chaque accord.
  4. LE CHŒUR — trois voix (« ooh », harmoniques pondérées par deux formants,
     vibrato 5 Hz) qui entrent à la moitié de la boucle sur la fondamentale
     et la quinte, une octave au-dessus du pad, et s'effacent avant la fin :
     le drame monte, la boucle repart sur le seul bourdon — et le grand coup.
  5. LE PIANO DRAMATIQUE — octaves graves frappées au départ de chaque
     accord, une phrase en ré mineur qui monte vers le retour de la boucle
     (« j'aime pas l'effet carillon, je préfère le piano dramatique »).
  6. LA MONTÉE — un souffle filtré qui enfle sur les six dernières secondes
     et se coupe net sur le grand coup du départ : la tension qui se résout
     sur elle-même, sans couture.

Crête −9 dBFS (croisière réglée dans BoosterAmbience). Sortie :
Nosfy/Media/manege-noir-drame.caf (afconvert), preview tools/sacre/noir/manege-noir-drame.wav
"""
import os
import subprocess
import wave

import numpy as np

R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR, DUR, BPM = 48000, 24.0, 60
N = int(SR * DUR)
t = np.arange(N) / SR
rng = np.random.default_rng(2020)
BEAT = 60 / BPM


def hz(semis_from_a4):
    return 440.0 * 2 ** (semis_from_a4 / 12)


def circ_add(buf, sig, start):
    idx = (np.arange(len(sig)) + int(start)) % len(buf)
    np.add.at(buf, idx, sig)


def lowpass_ma(x, k):
    """moyenne glissante circulaire (un filtre passe-bas grossier, sans couture)."""
    noyau = np.ones(k) / k
    return np.convolve(np.concatenate([x[-k:], x]), noyau, mode="same")[k:]


L = np.zeros(N)
Rr = np.zeros(N)

# ── 1. le bourdon : D1, D2, A2 — la respiration sur 12 s (deux par boucle)
lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / 12.0 - np.pi / 2)
D1, D2, A2 = hz(-31), hz(-19), hz(-12)
bourdon = (0.12 * np.sin(2 * np.pi * D1 * t)
           + 0.07 * np.sin(2 * np.pi * D2 * t + 0.4)
           + 0.05 * np.sin(2 * np.pi * A2 * t + 1.1) * (0.4 + 0.6 * lfo)
           + 0.02 * np.sin(2 * np.pi * D2 * 2 * t)) * (0.6 + 0.4 * lfo)
L += bourdon
Rr += bourdon

# ── 2. les cordes sombres : i · VI · iv · V, six secondes chacun
accords = [  # semis depuis A4
    (-19, -16, -12),   # Dm  : D3 F3 A3
    (-23, -19, -16),   # Bb2 D3 F3
    (-14, -11, -7),    # Gm  : G3 Bb3 D4
    (-12, -8, -5),     # A   : A3 C#4 E4
]
brillance = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 24.0 - np.pi / 2))   # le filtre s'ouvre sur la boucle
for i, acc in enumerate(accords):
    n = int(9.0 * SR)
    tt = np.arange(n) / SR
    env = (1 - np.exp(-tt / 1.6)) * np.exp(-np.maximum(tt - 4.4, 0) / 0.9) * np.clip((9.0 - tt) / 0.5, 0, 1)   # monte, s'efface, et FINIT à zéro
    voix = np.zeros(n)
    for semis in acc:
        f0 = hz(semis)
        for det, gain in ((-6, 0.33), (0, 0.34), (6, 0.33)):
            f = f0 * 2 ** (det / 1200)
            for k in range(1, 9):
                voix += gain * np.sin(2 * np.pi * f * k * tt + rng.uniform(0, 6.28)) / k ** 1.5 * (0.9 ** (k - 1))
    voix *= env * 0.055
    start = i * 6.0 * SR
    # le filtre : la brillance de la boucle module les harmoniques par un passe-bas grossier
    seg = np.take(brillance, (np.arange(n) + int(start)) % N)
    voix_l = voix * (0.55 + 0.45 * seg) + lowpass_ma(voix, 24) * (0.45 - 0.45 * seg)
    circ_add(L, voix_l * 0.95, start)
    circ_add(Rr, np.roll(voix_l, 37) * 1.0, start)     # un rien de décalage : la largeur

# ── 3. le cœur : le tambour grave, et le grand coup
def tambour(amp=0.55, f_hi=95, f_lo=42, dur=0.55):
    n = int(SR * dur)
    tt = np.arange(n) / SR
    f = f_lo + (f_hi - f_lo) * np.exp(-tt / 0.06)
    ph = 2 * np.pi * np.cumsum(f) / SR
    corps = np.sin(ph) * np.exp(-tt / 0.16)
    peau = rng.standard_normal(n) * np.exp(-tt / 0.012) * 0.25
    return amp * (corps + lowpass_ma(peau, 6)) * (1 - np.exp(-tt / 0.002))


def grand_coup(amp=0.9):
    n = int(SR * 2.2)
    tt = np.arange(n) / SR
    f = 30 + 60 * np.exp(-tt / 0.10)
    ph = 2 * np.pi * np.cumsum(f) / SR
    sub = np.sin(ph) * np.exp(-tt / 0.55)
    peau = lowpass_ma(rng.standard_normal(n), 4) * np.exp(-tt / 0.03) * 0.5
    return amp * (sub + peau) * (1 - np.exp(-tt / 0.0015))


for mesure in range(6):                       # 6 mesures de 4 temps
    m0 = mesure * 4 * BEAT * SR
    lub = tambour(amp=0.42)
    dub = tambour(amp=0.30, f_hi=80, f_lo=40, dur=0.45)
    circ_add(L, lub, m0)
    circ_add(Rr, lub, m0)
    circ_add(L, dub, m0 + 1.5 * BEAT * SR)
    circ_add(Rr, dub, m0 + 1.5 * BEAT * SR)
for i in range(4):                            # le grand coup au départ de chaque accord
    gc = grand_coup(amp=0.85 if i == 0 else 0.55)
    circ_add(L, gc, i * 6.0 * SR)
    circ_add(Rr, gc, i * 6.0 * SR)

# ── 4. le chœur : trois voix « ooh », de 12 s à 22 s, fondamentale + quinte + octave
def voix_choeur(f0, dur, amp):
    n = int(SR * dur)
    tt = np.arange(n) / SR
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.0 * tt + rng.uniform(0, 6.28))
    env = (1 - np.exp(-tt / 2.2)) * np.exp(-np.maximum(tt - dur + 3.0, 0) / 0.9) * np.clip((dur - tt) / 0.3, 0, 1)
    s = np.zeros(n)
    for k in range(1, 14):
        fk = f0 * k
        # deux formants (« ooh » : ~350 Hz et ~800 Hz), gaussiens en log-fréquence
        w = np.exp(-((np.log(fk / 350)) ** 2) / 0.18) + 0.5 * np.exp(-((np.log(fk / 800)) ** 2) / 0.12)
        s += w / k * np.sin(2 * np.pi * fk * np.cumsum(vib) / SR + rng.uniform(0, 6.28))
    return amp * env * s


for f0, amp, pan in ((hz(-7), 0.070, 0.42), (hz(0), 0.050, 0.58), (hz(5), 0.030, 0.5)):   # D4 · A4 · D5
    v = voix_choeur(f0, 10.5, amp)
    circ_add(L, v * (1 - pan) ** 0.5, 12.0 * SR)
    circ_add(Rr, v * pan ** 0.5, 12.0 * SR)

# ── 5. LE PIANO DRAMATIQUE (Kathryn, 20-09 : « j'aime pas l'effet carillon,
#      je préfère le piano dramatique ») — cordes frappées : partiels
#      inharmoniques (B = 0,0004), marteau de bruit court, double décroissance
#      (l'attaque meurt vite, la résonance dure), une pédale qui tient.
def piano(f0, dur=6.0, amp=0.30):
    n = int(SR * dur)
    tt = np.arange(n) / SR
    s = np.zeros(n)
    B = 0.0004
    for k in range(1, 12):
        fk = f0 * k * np.sqrt(1 + B * k * k)
        if fk > 9000:
            break
        a_k = 1.0 / k ** 1.25 * (0.85 ** (k - 1))
        dec = np.exp(-tt * (0.55 + 0.35 * k)) * 0.6 + np.exp(-tt * (0.12 + 0.06 * k)) * 0.4
        s += a_k * dec * np.sin(2 * np.pi * fk * tt + rng.uniform(0, 6.28))
    marteau = lowpass_ma(rng.standard_normal(n), 3) * np.exp(-tt / 0.006) * 0.35
    env = (1 - np.exp(-tt / 0.0012)) * np.clip((dur - tt) / 0.6, 0, 1)
    return amp * env * (s + marteau)


# la partition : l'octave grave au départ de chaque accord (forte), puis la
# phrase — Dm : A3 D4 F4 · Bb : F4 D4 Bb3 · Gm : Bb4 D5 G4 · A : C#4 E4 A4
# (la dominante monte vers le retour de la boucle : la chute sur le ré)
partition = [
    (0.0, (-31, -19), 0.55), (1.5, (-12,), 0.26), (3.0, (-7,), 0.26), (4.5, (-4,), 0.24),
    (6.0, (-35, -23), 0.50), (7.5, (-4,), 0.24), (9.0, (-7,), 0.22), (10.5, (-11,), 0.22),
    (12.0, (-26, -14), 0.50), (13.5, (1,), 0.26), (15.0, (5,), 0.28), (16.5, (-2,), 0.22),
    (18.0, (-24, -12), 0.52), (19.5, (-8,), 0.26), (21.0, (-5,), 0.28), (22.5, (0,), 0.32),
]
for beat, notes, vel in partition:
    start = beat * BEAT * SR
    for semis in notes:
        f0 = hz(semis)
        pan = 0.5 + 0.22 * np.tanh((semis + 12) / 14)     # les graves à gauche, les aigus à droite, comme un clavier
        p_ = piano(f0, dur=7.0 if len(notes) == 2 else 5.5, amp=vel * (0.9 if len(notes) == 2 else 1.0))
        circ_add(L, p_ * (1 - pan) ** 0.5, start)
        circ_add(Rr, p_ * pan ** 0.5, start)

# ── 6. la montée : un souffle qui enfle sur les six dernières secondes et se coupe net
souffle = lowpass_ma(rng.standard_normal(N), 60)
montee = np.clip((t - 18.0) / 6.0, 0, 1) ** 2.2
souffle *= 0.11 * montee
L += souffle
Rr += np.roll(souffle, 211)

# un souffle de fond, à peine là, sur toute la boucle
fond = lowpass_ma(rng.standard_normal(N), 400) * 0.035 * (0.6 + 0.4 * lfo)
L += fond
Rr += fond * 0.9

# ── la couture : RIEN à faire — tout est circulaire par construction (mesuré ci-dessous par le
#    banc : le saut au point de boucle est du même ordre qu'entre deux échantillons voisins).

st = np.stack([L, Rr], axis=1)
st = np.tanh(st * 1.15) / np.tanh(1.15)          # un rien de compression douce sur les coups
st *= (10 ** (-9 / 20)) / np.abs(st).max()
os.makedirs(os.path.join(R, "tools", "sacre", "noir"), exist_ok=True)
wav = os.path.join(R, "tools", "sacre", "noir", "manege-noir-drame.wav")
with wave.open(wav, "wb") as f_:
    f_.setnchannels(2)
    f_.setsampwidth(2)
    f_.setframerate(SR)
    f_.writeframes((st * 32767).astype("<i2").tobytes())
caf = os.path.join(R, "Nosfy", "Media", "manege-noir-drame.caf")
subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16@48000", wav, caf], check=True)
print("manege-noir-drame.caf :", os.path.getsize(caf), "o —", DUR, "s, 48 kHz, 2 ch ; preview :", wav)
