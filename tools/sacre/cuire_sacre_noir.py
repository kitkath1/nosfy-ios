#!/usr/bin/env python3
"""LE SACRE DE LA LÉGENDAIRE — « un truc plus beau, plus légendaire » (18-09).

La carte noire se présente : le manège se tait, LE SACRE monte. Ce n'est plus
une boîte à musique — c'est un chœur. Quatre accords qui s'élèvent (la mineur ·
fa · do · sol : i–VI–III–VII, 6 s chacun, 24 s en boucle sans couture), un
chœur de voix (sinus empilés, légèrement désaccordés, vibrato lent, filtrés
par une enveloppe qui s'ouvre), une basse d'orgue, un scintillement de cloches
en arpège dans l'aigu (le « légendaire » : une pluie d'étoiles), et une houle
lente qui gonfle à chaque accord. Périodique par construction (addition
circulaire des queues), fondu croisé de 250 ms en ceinture.

Sortie : Nosfy/Media/sacre-noir.caf (2 ch · 48 kHz · Int16), preview tools/sacre/noir/sacre-noir.wav
Volume de croisière réglé dans BoosterAmbience (0,30, comme le sacre lune).
"""
import os, subprocess, wave
import numpy as np

R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR, DUR = 48000, 24.0
N = int(SR * DUR); t = np.arange(N) / SR
rng = np.random.default_rng(1809)
def hz(semis): return 440.0 * 2 ** (semis / 12)
def circ_add(buf, sig, start):
    idx = (np.arange(len(sig)) + start) % len(buf); np.add.at(buf, idx, sig)
L = np.zeros(N); Rr = np.zeros(N)

# les quatre accords (demi-tons depuis A4) : Am · F · C · G — en position ouverte, voix serrées au-dessus
accords = [[-24, -12, 0, 3, 7, 12], [-28, -16, -4, 0, 3, 8], [-33, -21, -9, -5, 0, 3], [-26, -14, -2, 2, 5, 9]]
SEG = int(6 * SR)

# 1. le chœur : chaque voix = 3 sinus désaccordés (±6 cents) + vibrato 5,2 Hz, enveloppe qui s'ouvre sur 2,2 s
def voix(f, dur, amp):
    n = int(dur * SR); tt = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * tt + rng.uniform(0, 6.28))
    s = np.zeros(n)
    for det in (-6, 0, 6):
        fr = f * 2 ** (det / 1200) * vib
        s += np.sin(2 * np.pi * np.cumsum(fr) / SR + rng.uniform(0, 6.28))
    # un formant doux : la 2e harmonique à moitié, la 3e au quart
    s += 0.5 * np.sin(2 * np.pi * 2 * f * tt) + 0.25 * np.sin(2 * np.pi * 3 * f * tt)
    env = (1 - np.exp(-tt / 2.2)) * np.where(tt < dur - 1.5, 1, np.exp(-(tt - (dur - 1.5)) / 0.6))
    return amp * env * s / 3.75
for i, acc in enumerate(accords):
    start = i * SEG
    for j, semis in enumerate(acc):
        a = 0.075 if j > 1 else 0.05
        pan = 0.5 + 0.3 * np.sin(j * 1.9 + i)
        v = voix(hz(semis), 7.0, a)          # 7 s : chaque accord déborde d'1 s sur le suivant (legato)
        circ_add(L, v * (1 - pan) ** 0.5, start); circ_add(Rr, v * pan ** 0.5, start)

# 2. la basse d'orgue : fondamentale + octave, tenue, respirée
for i, acc in enumerate(accords):
    f = hz(acc[0]); start = i * SEG; tt = np.arange(SEG) / SR
    env = (1 - np.exp(-tt / 0.8)) * np.where(tt < 5.4, 1, np.exp(-(tt - 5.4) / 0.35))
    b = 0.16 * env * (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * 2 * f * tt))
    circ_add(L, b, start); circ_add(Rr, b, start)

# 3. la pluie d'étoiles : cloches en arpège rapide (double croche à 84 bpm), sur les notes de l'accord, 2 octaves au-dessus
def cloche(f, amp):
    n = int(2.4 * SR); tt = np.arange(n) / SR
    env = np.exp(-tt / 0.9) * (1 - np.exp(-tt / 0.002))
    s = (np.sin(2 * np.pi * f * tt) + 0.6 * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt / 0.3)
         + 0.3 * np.sin(2 * np.pi * f * 5.4 * tt) * np.exp(-tt / 0.12))
    return amp * env * s
pas = 60 / 84 / 4
k = 0
while k * pas < DUR:
    i = int((k * pas) // 6); acc = accords[i]
    if (k % 8) not in (3, 6):                            # respirations dans la pluie
        semis = acc[2 + (k % 4)] + 24
        amp = 0.05 * (0.55 + 0.45 * np.sin(k * 0.37) ** 2)
        pan = 0.5 + 0.42 * np.sin(k * 0.9)
        c = cloche(hz(semis), amp); start = int(k * pas * SR)
        circ_add(L, c * (1 - pan) ** 0.5, start); circ_add(Rr, c * pan ** 0.5, start)
    k += 1

# 4. la houle : un souffle large (bruit filtré) qui gonfle à chaque accord
bruit = rng.standard_normal(N); kk = 300
souffle = np.convolve(np.concatenate([bruit[-kk:], bruit]), np.ones(kk) / kk, mode="same")[kk:]
houle = 0.5 + 0.5 * np.sin(2 * np.pi * t / 6.0 - np.pi / 2)
souffle *= 0.06 * houle ** 2
L += souffle; Rr += souffle * 0.92

# 5. la ceinture : fondu croisé fin/début, 250 ms
f = int(0.25 * SR); w = np.linspace(0, 1, f)
for ch in (L, Rr):
    tete = ch[:f].copy(); ch[:f] = tete * w + ch[-f:] * (1 - w); ch[-f:] = ch[-f:] * (1 - w) + tete * w

st = np.stack([L, Rr], axis=1); st *= (10 ** (-8 / 20)) / np.abs(st).max()
wav = os.path.join(R, "tools", "sacre", "noir", "sacre-noir.wav")
with wave.open(wav, "wb") as f_:
    f_.setnchannels(2); f_.setsampwidth(2); f_.setframerate(SR); f_.writeframes((st * 32767).astype("<i2").tobytes())
caf = os.path.join(R, "Nosfy", "Media", "sacre-noir.caf")
subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16@48000", wav, caf], check=True)
print("sacre-noir.caf :", os.path.getsize(caf), "o —", DUR, "s")
