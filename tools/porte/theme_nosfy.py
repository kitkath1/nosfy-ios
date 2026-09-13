#!/usr/bin/env python3
"""
LE THÈME DE NOSFY — synthèse (13-09-2026). Plan : tools/porte/PLAN-THEME-NOSFY.md.

« Une petite musique de fond magique mais pas princesse, discrète » — et « moins
flippant que le thème du splash ». Une TEXTURE, pas un morceau : aucune mélodie,
aucun tempo, aucune tierce majeure. Dorien sur la (la sixte majeure éclaire sans
faire princesse), un grave à 110 Hz qui respire (jamais ne gronde), des cristaux
PRESQUE harmoniques (f · 2,0 f · 3,02 f — chauds comme un bol, pas froids comme
une vitre), de l'air, aucun impact.

⚠️ CE SCRIPT VIT DANS LE DÉPÔT. Celui du thème du splash (`moonmusic5.py`) est
perdu avec son scratchpad : on ne peut plus que couper dedans. Un son qu'on ne
peut pas régénérer est un son qu'on ne peut pas retoucher.

LA BOUCLE EST EXACTE PAR CONSTRUCTION : toutes les modulations ont une période qui
divise 24 s, et les traînes des cristaux qui débordent la fin sont REPLIÉES au début.
L'image 0 et l'image 24 s sont la même : la couture n'existe pas.

Usage : theme_nosfy.py <dossier de sortie>   → NosfyTheme-A.wav · -B · -C,
        NosfyTap.wav, NosfyPaillette.wav (48 kHz, 16 bits, stéréo)
"""
import sys, os
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
from scipy.io import wavfile

SR = 48_000
DUREE = 24.0
N = int(SR * DUREE)
T = np.arange(N) / SR

def db(x): return 10 ** (x / 20)

def sinus(f, t, phase=0.0): return np.sin(2 * np.pi * f * t + phase)

def cents(f, c): return f * 2 ** (c / 1200)

def lfo(periode, t, bas, haut, phase=0.0):
    """Une respiration entre bas et haut, période EXACTE (divise 24 s)."""
    assert abs(DUREE / periode - round(DUREE / periode)) < 1e-9, periode
    return bas + (haut - bas) * 0.5 * (1 - np.cos(2 * np.pi * t / periode + phase))

# ── LE BOURDON : la2 + mi3, doux ; une trace de la1 ─────────────────────────
def bourdon(t, periode=12.0):
    resp = lfo(periode, t, 0.72, 1.0)
    s = (sinus(110.0, t) + 0.55 * sinus(165.0, t) + db(-14) * sinus(55.0, t)) * resp
    return s / 2.1

# ── LE PAD : la3 · mi4 · fa#4 · ré5 (dorien), désaccordé, chorusé ──────────
def pad(t):
    notes = [220.0, 329.63, 369.99, 587.33]
    out = np.zeros_like(t)
    for i, f in enumerate(notes):
        ph = i * 1.7
        chorus = lfo(8.0, t, -3.0, 3.0, ph)                # ±3 cents, période 8 s
        fL = cents(f, chorus); fR = cents(f, -chorus)
        amp = lfo(24.0, t, 0.55, 1.0, ph * 0.9)             # chaque voix respire à son heure
        # une fréquence qui bouge : on intègre la phase, sinon ça clique
        phL = 2 * np.pi * np.cumsum(fL) / SR
        phR = 2 * np.pi * np.cumsum(fR) / SR
        out = out + amp * (np.sin(phL) + np.sin(phR)) * (0.9 if i < 2 else 0.6)
    return out / 6.0

# ── LES CRISTAUX : presque harmoniques, attaque 22 ms, longue traîne ────────
def cristal(f0, tau, duree, gliss=0.006, sr=SR):
    n = int(sr * duree); t = np.arange(n) / sr
    env = np.exp(-t / tau)
    att = int(sr * 0.022)
    env[:att] *= 0.5 * (1 - np.cos(np.pi * np.arange(att) / att))   # aucun clic
    fr = f0 * (1 - gliss * t / duree)                                # glissando descendant
    ph = 2 * np.pi * np.cumsum(fr) / sr
    s = np.sin(ph) + 0.5 * np.sin(2.0 * ph) + 0.25 * np.sin(3.02 * ph)
    return s * env / 1.75

def cristaux(nombre, tau_min, tau_max, graine, gain=1.0):
    rng = np.random.default_rng(graine)
    notes = [880.0, 1318.5, 1174.7, 739.99, 987.77, 1479.98]     # la5 mi6 ré6 fa#5 si5 fa#6
    long_n = int(SR * (DUREE + 8.0))
    buf = np.zeros(long_n)
    instants = np.sort(rng.uniform(0.3, DUREE - 0.3, nombre))
    for i, t0 in enumerate(instants):
        f0 = notes[rng.integers(len(notes))]
        tau = rng.uniform(tau_min, tau_max)
        c = cristal(f0, tau, tau * 3.2) * rng.uniform(0.6, 1.0) * gain
        a = int(t0 * SR); b = min(a + len(c), long_n)
        buf[a:b] += c[: b - a]
    # LA RÉVERBÉRATION — une pièce noire : bruit à décroissance exponentielle, 3,2 s
    ir_n = int(SR * 3.2); ir_t = np.arange(ir_n) / SR
    ir = rng.standard_normal(ir_n) * np.exp(-ir_t / 0.9)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = fftconvolve(buf, ir)[:long_n]
    mix = buf * 0.65 + wet * 0.35
    # LE REPLI : ce qui déborde de 24 s revient au début → boucle exacte
    out = mix[:N].copy()
    reste = mix[N:]
    out[: len(reste)] += reste[: N] if len(reste) <= N else reste[:N]
    return out

# ── L'AIR : du bruit haut et doux, qui respire avec le bourdon ──────────────
def air(t, graine, periode=12.0, bas_hz=3000, haut_hz=7000):
    rng = np.random.default_rng(graine + 1000)
    bruit = rng.standard_normal(N)
    sos = butter(2, [bas_hz, haut_hz], btype="band", fs=SR, output="sos")
    b = sosfilt(sos, bruit)
    b /= np.max(np.abs(b)) + 1e-9
    return b * lfo(periode, t, 0.6, 1.0)

def stereo(mono, largeur=0.12):
    """Un léger désaccord gauche/droite par un retard de 9 ms atténué : de l'espace."""
    d = int(SR * 0.009)
    g = mono
    dr = np.concatenate([np.zeros(d), mono[:-d]])
    return np.stack([g + largeur * dr, dr * (1 - largeur) + largeur * g], axis=1)

def normaliser(x, crete_db=-3.0):
    return x / (np.max(np.abs(x)) + 1e-12) * db(crete_db)

def ecrire(chemin, x):
    x = np.clip(x, -1, 1)
    wavfile.write(chemin, SR, (x * 32767).astype(np.int16))

def theme(variante):
    t = T
    if variante == "A":      # chaude — la recette du plan
        n, tmin, tmax, pad_db, air_db, per = 7, 1.2, 2.0, -20, -32, 12.0
    elif variante == "B":    # cristal — plus d'éclats, traînes plus longues, pad −3 dB
        n, tmin, tmax, pad_db, air_db, per = 11, 1.6, 2.6, -23, -32, 12.0
    else:                    # C · brume — moins d'éclats, plus d'air, respiration plus courte
        n, tmin, tmax, pad_db, air_db, per = 4, 1.2, 2.0, -20, -26, 8.0
    mix = (db(-18) * bourdon(t, per)
           + db(pad_db) * pad(t)
           + db(-26) * cristaux(n, tmin, tmax, graine=1309)
           + db(air_db) * air(t, graine=1309, periode=per))
    return normaliser(stereo(mix))

def bruit_tap():
    c = cristal(880.0 * 2, 0.14, 0.45, gliss=0.02)
    return normaliser(stereo(c, 0.05), -12.0)

def bruit_paillette():
    c = cristal(880.0 * 4, 0.36, 1.2, gliss=0.01) + 0.5 * cristal(1318.5 * 4, 0.30, 1.2)
    return normaliser(stereo(c, 0.08), -14.0)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for v in "ABC":
        ecrire(os.path.join(out, f"NosfyTheme-{v}.wav"), theme(v))
        print("écrit", f"NosfyTheme-{v}.wav")
    ecrire(os.path.join(out, "NosfyTap.wav"), bruit_tap())
    ecrire(os.path.join(out, "NosfyPaillette.wav"), bruit_paillette())
    print("écrit NosfyTap.wav · NosfyPaillette.wav")
