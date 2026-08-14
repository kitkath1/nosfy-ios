#!/usr/bin/env python3
"""PoussiereLune.wav — le shimmer de poussière magique, très discret.

La doctrine sonore de la maison : « rien n'est frappé, tout gonfle ». Ici
rien ne frappe : une pluie granulaire de micro-clochettes (sinus 2,4–7 kHz,
extinctions 30–120 ms) dont la densité s'éparpille avec le temps — la
poussière qui se disperse — posée sur un souffle d'air filtré en forme
d'expiration. Stéréo légère (chaque grain a son panoramique).
"""
import numpy as np
import wave

SR = 44100
DUR = 1.8
N = int(SR * DUR)
rng = np.random.default_rng(7)

t = np.arange(N) / SR
out = np.zeros((N, 2), np.float64)

# — Les grains : denses au départ, épars ensuite (la dispersion).
for k in range(84):
    # Position temporelle : tirage biaisé vers le début (x²).
    at = rng.random() ** 2.2 * (DUR - 0.35)
    f = rng.uniform(2400, 7000)
    dur = rng.uniform(0.030, 0.120)
    amp = rng.uniform(0.15, 1.0) ** 2 * 0.11
    pan = rng.uniform(0.15, 0.85)
    i0 = int(at * SR)
    n = int(dur * SR)
    if i0 + n >= N:
        n = N - i0 - 1
    tt = np.arange(n) / SR
    # Attaque 3 ms (jamais un clic), extinction exponentielle.
    env = np.minimum(tt / 0.003, 1.0) * np.exp(-tt / (dur * 0.30))
    g = np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.28)) * env * amp
    # Un souffle d'octave fantôme, très bas : le « magique ».
    g += 0.25 * np.sin(2 * np.pi * f * 2.01 * tt) * env * amp
    out[i0:i0 + n, 0] += g * (1 - pan)
    out[i0:i0 + n, 1] += g * pan

# — Le souffle : bruit passe-haut doux, enveloppe d'expiration (0,6 s).
noise = rng.standard_normal(N)
# Passe-haut simple par différence lissée.
lp = np.copy(noise)
a = 0.92
for i in range(1, N):
    lp[i] = a * lp[i - 1] + (1 - a) * noise[i]
hp = noise - lp
breath_env = np.minimum(t / 0.06, 1.0) * np.exp(-t / 0.42)
breath = hp * breath_env * 0.020
out[:, 0] += breath
out[:, 1] += breath

# — Fondu de fin, normalisation discrète (pic à −24 dBFS ≈ 0,063).
fade = np.minimum(1.0, (DUR - t) / 0.25)
out *= fade[:, None]
out *= 0.063 / np.abs(out).max()

pcm = (out * 32767).astype(np.int16)
with wave.open("PoussiereLune.wav", "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("OK PoussiereLune.wav", pcm.shape, "pic", float(np.abs(out).max()))
