#!/usr/bin/env python3
"""LE PIANO DU PROFIL (20-09, Kathryn : « un petit bruit de piano joli quand
on arrive sur la page ») — `Nosfy/Media/profil-piano.wav`, SYNTHÉTISÉ ici.

Deux notes douces, une tierce qui monte (mi5 → sol#5), jouées comme deux
doigts posés sur un piano feutré : partiels harmoniques légèrement
inharmoniques (la corde raide d'un piano, B ≈ 2·10⁻⁴), amplitudes en 1/n^1,6,
les aigus qui meurent avant les graves, une attaque de 6 ms avec le petit
« toc » du marteau (bruit filtré), une traîne d'une seconde, la seconde note
un peu plus douce. 44,1 kHz, 16 bits, mono, ≈ 1,7 s, crête à −6 dB.

    python3 tools/profil/piano_profil.py        # écrit Nosfy/Media/profil-piano.wav
"""
import math
import struct
import wave
from pathlib import Path

import numpy as np

SR = 44_100
DUREE = 1.7
B = 2.2e-4                      # inharmonicité de la corde

def note(f0: float, t0: float, gain: float, decay: float) -> np.ndarray:
    n = int(SR * DUREE)
    t = np.arange(n) / SR
    out = np.zeros(n)
    tt = np.clip(t - t0, 0, None)
    actif = (t >= t0).astype(float)
    for k in range(1, 13):
        fk = f0 * k * math.sqrt(1 + B * k * k)
        if fk > SR * 0.45:
            break
        amp = gain / (k ** 1.6)
        # les aigus s'éteignent plus vite : τ décroît avec k
        tau = decay / (1 + 0.55 * (k - 1))
        env = np.exp(-tt / tau)
        # attaque 6 ms (aucun clic)
        att = np.clip(tt / 0.006, 0, 1)
        out += amp * env * att * np.sin(2 * math.pi * fk * tt + 0.3 * k)
    # le « toc » du marteau : un souffle de 12 ms, filtré grave
    rng = np.random.default_rng(7 + int(f0))
    bruit = rng.standard_normal(n) * np.exp(-tt / 0.012) * (tt < 0.05)
    # filtre passe-bas simple (moyenne glissante)
    noyau = np.ones(24) / 24
    bruit = np.convolve(bruit, noyau, mode="same")
    out += 0.12 * gain * bruit
    return out * actif

def main() -> None:
    mi5 = 659.255
    solD5 = 830.609
    son = note(mi5, 0.00, 1.0, 0.55) + note(solD5, 0.16, 0.80, 0.62)
    # fondu de sortie sur les 200 dernières ms
    n = len(son)
    fin = np.ones(n)
    k = int(0.2 * SR)
    fin[-k:] = np.linspace(1, 0, k)
    son *= fin
    son /= np.max(np.abs(son))
    son *= 0.5                      # crête −6 dB : un son doux, jamais un coup
    pcm = (son * 32767).astype("<i2")
    dest = Path(__file__).resolve().parents[2] / "Nosfy" / "Media" / "profil-piano.wav"
    with wave.open(str(dest), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"écrit {dest} ({dest.stat().st_size} o, {DUREE} s)")

if __name__ == "__main__":
    main()
