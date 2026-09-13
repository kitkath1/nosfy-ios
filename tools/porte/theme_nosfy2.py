#!/usr/bin/env python3
"""
LE THÈME DE NOSFY — deuxième famille (13-09-2026, soir).

Verdict sur la première (theme_nosfy.py : bourdon + nappe + cristaux) : « j'aime pas du
tout, c'est comme la musique du splash, je veux autre chose carrément ». Elle a raison :
c'était le VOCABULAIRE du splash. Ici, un autre monde — HARMONIQUE, chaud, avec des
accords qu'on reconnaît sans pouvoir les chanter.

  D · TOUCHES — un piano électrique doux (FM à index qui s'éteint), quatre accords à
      septièmes (Amaj7 · F#m7 · Dmaj7 · E7sus), un par 6 s, frappés doucement, un peu de
      bande (passe-bas 5,5 kHz, un souffle). La musique des films Apple : chaude, lente,
      retenue.
  E · PERLES — des cordes pincées feutrées (Karplus-Strong adouci, comme une kalimba
      étouffée), une arpège lente en dorien, avec l'accord de piano loin derrière. Lo-fi.

Boucle exacte de 24 s : les accords tombent sur une grille qui divise 24, les traînes qui
débordent sont repliées au début.

Usage : theme_nosfy2.py <dossier> → NosfyTheme-D.wav · NosfyTheme-E.wav (48 kHz, 16 bits, stéréo)
"""
import sys, os
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt, lfilter
from scipy.io import wavfile

SR = 48_000
DUREE = 24.0
N = int(SR * DUREE)
LONG = int(SR * (DUREE + 8.0))     # avec la place des traînes, repliées ensuite

def db(x): return 10 ** (x / 20)
def midi(n): return 440.0 * 2 ** ((n - 69) / 12)

# ── LE PIANO ÉLECTRIQUE : FM douce, index qui s'éteint, attaque 8 ms ────────
def epiano(f, duree, velocite=1.0, sr=SR):
    n = int(sr * duree); t = np.arange(n) / sr
    env = np.exp(-t / 1.9) * (1 - np.exp(-t / 0.008))
    index = 1.6 * velocite * np.exp(-t / 0.35) + 0.12          # brillant au toucher, puis rond
    mod = np.sin(2 * np.pi * f * t) * index
    s = np.sin(2 * np.pi * f * t + mod) + 0.18 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.6)
    return s * env * velocite

# ── LA CORDE PINCÉE FEUTRÉE : Karplus-Strong par filtre à rétroaction ───────
def perle(f, duree, velocite=1.0, sr=SR, brillance=0.55):
    n = int(sr * duree); N_ = int(round(sr / f))
    rng = np.random.default_rng(int(f * 7))
    exc = rng.uniform(-1, 1, N_)
    sos = butter(2, 2600, btype="low", fs=sr, output="sos")
    exc = sosfilt(sos, exc) * 2.0                              # une excitation feutrée
    x = np.zeros(n); x[:N_] = exc
    a = np.zeros(N_ + 2); a[0] = 1.0; a[N_] = -0.5 * brillance * 0.985; a[N_ + 1] = -0.5 * 0.985
    y = lfilter([1.0], a, x)
    env = np.exp(-np.arange(n) / sr / 1.1)
    return y * env * velocite

def reverb(x, sr=SR, queue=1.8, graine=7):
    rng = np.random.default_rng(graine)
    n = int(sr * queue); t = np.arange(n) / sr
    ir = rng.standard_normal(n) * np.exp(-t / (queue / 3.5))
    sos = butter(1, 4500, btype="low", fs=sr, output="sos")
    ir = sosfilt(sos, ir); ir /= np.sqrt(np.sum(ir ** 2))
    return fftconvolve(x, ir)[: len(x)]

def replier(buf):
    """Ce qui déborde de 24 s revient au début : boucle exacte."""
    out = buf[:N].copy()
    reste = buf[N:]
    out[: len(reste)] += reste[:N]
    return out

def poser(buf, son, t0, sr=SR):
    a = max(0, int(t0 * sr)); b = min(a + len(son), len(buf))   # jamais avant 0 s
    if b > a: buf[a:b] += son[: b - a]

def bande(x, sr=SR, coupe=5500, souffle_db=-52, graine=3):
    sos = butter(2, coupe, btype="low", fs=sr, output="sos")
    y = sosfilt(sos, x)
    rng = np.random.default_rng(graine)
    s = rng.standard_normal(len(y))
    s = sosfilt(butter(2, [800, 6000], btype="band", fs=sr, output="sos"), s)
    return y + db(souffle_db) * s / (np.max(np.abs(s)) + 1e-9)

def stereo(mono, largeur=0.10, sr=SR):
    d = int(sr * 0.011)
    dr = np.concatenate([np.zeros(d), mono[:-d]])
    return np.stack([mono + largeur * dr, dr * (1 - largeur) + largeur * mono], axis=1)

def normaliser(x, crete_db=-3.0):
    return x / (np.max(np.abs(x)) + 1e-12) * db(crete_db)

def ecrire(chemin, x):
    wavfile.write(chemin, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))

# Quatre accords, un par 6 s — chauds, à septièmes, jamais une triade nue.
ACCORDS = [
    [57, 61, 64, 68],        # Amaj7   la3 do#4 mi4 sol#4
    [54, 57, 61, 64],        # F#m7    fa#3 la3 do#4 mi4
    [50, 54, 57, 61],        # Dmaj7   ré3 fa#3 la3 do#4
    [52, 57, 59, 62],        # E7sus   mi3 la3 si3 ré4
]
BASSES = [45, 42, 38, 40]    # la2 fa#2 ré2 mi2

def touches():
    rng = np.random.default_rng(1309)
    buf = np.zeros(LONG)
    for i, (acc, basse) in enumerate(zip(ACCORDS, BASSES)):
        t0 = i * 6.0
        # l'accord, frappé doucement, les notes décalées de quelques dizaines de ms
        for j, n in enumerate(acc):
            poser(buf, epiano(midi(n), 5.5, velocite=rng.uniform(0.55, 0.75)), t0 + j * rng.uniform(0.02, 0.06))
        # une relance plus faible au milieu de l'accord, deux notes seulement
        for n in acc[1:3]:
            poser(buf, epiano(midi(n), 3.5, velocite=0.32), t0 + 3.0 + rng.uniform(0, 0.05))
        # la basse, un sinus rond
        n_b = int(SR * 5.8); tb = np.arange(n_b) / SR
        poser(buf, np.sin(2 * np.pi * midi(basse) * tb) * np.exp(-tb / 3.0) * (1 - np.exp(-tb / 0.02)) * 0.55, t0)
    mix = replier(buf * 0.6 + reverb(buf, queue=1.8) * 0.4)
    return normaliser(stereo(bande(mix)))

def perles():
    rng = np.random.default_rng(2609)
    buf = np.zeros(LONG)
    # l'arpège : dorien sur la (la si do ré mi fa# sol), lente, avec des silences
    gamme = [69, 71, 72, 74, 76, 78, 79, 81, 83, 84]
    grille = np.arange(0, DUREE, 0.75)                   # 32 temps
    for k, t0 in enumerate(grille):
        if rng.uniform() < 0.38: continue                 # les silences font la musique
        n = gamme[int(rng.integers(len(gamme)))]
        poser(buf, perle(midi(n), 1.6, velocite=rng.uniform(0.35, 0.7), brillance=rng.uniform(0.4, 0.7)), t0 + rng.uniform(-0.03, 0.03))
    # loin derrière : l'accord de piano, un seul (Am9), à −22 dB, deux fois
    for t0 in (0.0, 12.0):
        for j, n in enumerate([57, 60, 64, 67, 71]):
            poser(buf, epiano(midi(n), 10.0, velocite=0.22), t0 + j * 0.04)
    mix = replier(buf * 0.55 + reverb(buf, queue=2.2, graine=11) * 0.45)
    return normaliser(stereo(bande(mix, coupe=4800, souffle_db=-48)))


# ── F · FÊTE — la musique de la FIN (13-09 soir : « avec le résultat, un peu plus
#    joyeuse, LET'S GO MARGAUX »). La même matière que D — le piano électrique — mais
#    en MAJEUR ouvert (A · D · E · A, neuvièmes), des arpèges de perles qui MONTENT à
#    chaque accord, et un pouls de basse doux (88 BPM). Joyeux sans être princesse :
#    aucune mélodie, aucun carillon, tout reste feutré. Boucle exacte de 12 s.
ACCORDS_FETE = [
    [57, 61, 64, 71],        # Amaj9   la3 do#4 mi4 si4
    [50, 54, 57, 64],        # Dmaj9   ré3 fa#3 la3 mi4
    [52, 56, 59, 62],        # E7      mi3 sol#3 si3 ré4
    [57, 61, 64, 68],        # Amaj7   la3 do#4 mi4 sol#4
]
BASSES_FETE = [45, 38, 40, 45]
DUREE_FETE = 12.0

def fete():
    rng = np.random.default_rng(4242)
    n_fete = int(SR * DUREE_FETE); long_fete = int(SR * (DUREE_FETE + 6.0))
    buf = np.zeros(long_fete)
    temps = 60.0 / 88.0                                    # 88 BPM
    for i, (acc, basse) in enumerate(zip(ACCORDS_FETE, BASSES_FETE)):
        t0 = i * 3.0
        for j, n in enumerate(acc):                        # l'accord, doux
            poser(buf, epiano(midi(n), 3.2, velocite=rng.uniform(0.5, 0.65)), t0 + j * 0.03)
        # les perles qui MONTENT : l'accord en arpège, deux octaves, huit notes
        montee = [acc[0], acc[1], acc[2], acc[3], acc[0] + 12, acc[1] + 12, acc[2] + 12, acc[3] + 12]
        for k, n in enumerate(montee):
            poser(buf, perle(midi(n), 1.1, velocite=rng.uniform(0.35, 0.55), brillance=0.62), t0 + 0.15 + k * temps / 2)
        # le pouls : la basse sur 1 et 3, ronde
        for b in (0.0, 2 * temps):
            n_b = int(SR * 1.2); tb = np.arange(n_b) / SR
            poser(buf, np.sin(2 * np.pi * midi(basse) * tb) * np.exp(-tb / 0.45) * (1 - np.exp(-tb / 0.01)) * 0.5, t0 + b)
    mix = buf[:n_fete].copy(); reste = (buf * 0.55 + reverb(buf, queue=1.6, graine=5) * 0.45)
    out = reste[:n_fete].copy(); out[: len(reste[n_fete:])] += reste[n_fete:][:n_fete]
    return normaliser(stereo(bande(out, coupe=6500, souffle_db=-54)))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    ecrire(os.path.join(out, "NosfyTheme-D.wav"), touches()); print("écrit NosfyTheme-D.wav (touches)")
    ecrire(os.path.join(out, "NosfyTheme-E.wav"), perles());  print("écrit NosfyTheme-E.wav (perles)")
    ecrire(os.path.join(out, "NosfyFin-F.wav"), fete());      print("écrit NosfyFin-F.wav (fête)")
