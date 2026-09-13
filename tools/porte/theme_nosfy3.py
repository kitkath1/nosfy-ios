#!/usr/bin/env python3
"""
LA MUSIQUE DE LA FIN — troisième famille (13-09-2026, nuit).

Verdict sur F · fête (theme_nosfy2.py) : « horrible, on dirait un truc chinois ». Elle a
raison, et la cause est un INSTRUMENT, pas une intention : la corde pincée (Karplus-Strong)
en arpèges qui montent sur des accords à neuvièmes — c'est un guzheng, note pour note.
Ici : plus AUCUNE corde pincée, plus aucun arpège de perles. La matière reste le piano
électrique de D (la continuité du film), et la joie vient d'ailleurs — d'un POULS et d'une
NAPPE qui s'ouvre, comme la musique d'un keynote : chaude, en marche, jamais princesse.

  G · ÉLAN   — 100 BPM, I·V·vi·IV en la majeur (A · E · F#m · D) sur 8 mesures (19,2 s) ;
               une nappe de scies désaccordées dont le filtre s'ouvre à chaque accord, le
               piano électrique en frappes courtes sur le temps, une basse ronde en noires,
               un kick feutré sur chaque temps, un souffle sur les contretemps, et le
               « pompage » discret de la nappe sous le kick. La deuxième moitié ajoute la
               nappe une octave plus haut : ça monte sans changer d'accord.
  H · SOLEIL — 84 BPM, I·IV·V·I (A · D · E · A) sur 8 mesures (22,9 s) ; des cuivres de
               synthèse (scies filtrées, vibrato tardif) qui gonflent sur chaque accord,
               le piano électrique en accords brisés (avec la septième — jamais
               pentatonique), basse et kick sur 1 et 3, une caisse claire feutrée sur 2 et 4.
               Plus lent, plus large : l'arrivée.

Boucles exactes : ce qui déborde est replié au début.

Usage : theme_nosfy3.py <dossier> → NosfyFin-G.wav · NosfyFin-H.wav (48 kHz, 16 bits, stéréo)
"""
import sys, os
import numpy as np
from scipy.signal import butter, sosfilt, sosfiltfilt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from theme_nosfy2 import SR, db, midi, epiano, reverb, stereo, normaliser, ecrire, poser

def scie(f, n, sr=SR, plafond=11_000.0):
    """Une scie SANS repliement : additive, harmoniques sous 11 kHz."""
    t = np.arange(n) / sr
    K = max(1, int(plafond / f))
    k = np.arange(1, K + 1)[:, None]
    return (np.sin(2 * np.pi * f * k * t) / k).sum(axis=0) * (2 / np.pi)

def nappe_accord(notes, duree, attaque=0.25, relache=0.5, ouverture=(500, 2600), sr=SR, detune=0.004, vibrato=0.0):
    """Trois scies désaccordées par note, filtre passe-bas qui S'OUVRE sur la durée."""
    n = int(sr * (duree + relache)); t = np.arange(n) / sr
    s = np.zeros(n)
    for m in notes:
        f = midi(m)
        for d in (-detune, 0.0, detune):
            fm = f * (1 + d)
            if vibrato > 0:
                # vibrato qui n'arrive qu'après 0,4 s (un souffle de cuivre)
                prof = vibrato * np.clip((t - 0.4) / 0.6, 0, 1)
                ph = 2 * np.pi * fm * t + prof * fm / 5.5 * np.sin(2 * np.pi * 5.5 * t)
                s += np.sin(ph) * 0.5  # une seule harmonique douce sous le vibrato
                s += scie(fm, n) * 0.5
            else:
                s += scie(fm, n)
    s /= (3 * len(notes))
    env = np.minimum(1, t / attaque) * np.where(t < duree, 1.0, np.exp(-(t - duree) / (relache / 3)))
    # le filtre qui s'ouvre : on mélange deux passe-bas (fermé → ouvert) selon une rampe
    lo = sosfilt(butter(2, ouverture[0], btype="low", fs=sr, output="sos"), s)
    hi = sosfilt(butter(2, ouverture[1], btype="low", fs=sr, output="sos"), s)
    rampe = np.clip(t / max(duree * 0.8, 0.1), 0, 1) ** 1.5
    return (lo * (1 - rampe) + hi * rampe) * env

def kick(sr=SR, f0=105.0, f1=44.0, duree=0.28):
    n = int(sr * duree); t = np.arange(n) / sr
    f = f1 + (f0 - f1) * np.exp(-t / 0.045)
    ph = 2 * np.pi * np.cumsum(f) / sr
    return np.sin(ph) * np.exp(-t / 0.09) * (1 - np.exp(-t / 0.002))

def basse(m, duree, sr=SR, velocite=1.0):
    n = int(sr * duree); t = np.arange(n) / sr
    f = midi(m)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.2)
    s = np.tanh(1.6 * s) / np.tanh(1.6)
    env = (1 - np.exp(-t / 0.006)) * np.where(t < duree - 0.06, 1.0, np.clip((duree - t) / 0.06, 0, 1))
    return s * env * velocite

def souffle(duree, bande=(6000, 12000), sr=SR, graine=0, decroissance=0.03):
    rng = np.random.default_rng(graine)
    n = int(sr * duree); t = np.arange(n) / sr
    s = rng.standard_normal(n)
    s = sosfilt(butter(2, bande, btype="band", fs=sr, output="sos"), s)
    return s / (np.max(np.abs(s)) + 1e-9) * np.exp(-t / decroissance)

def pompage(n, temps, creux=0.72, retour=0.32, sr=SR):
    """La gaine du sidechain : à chaque temps le gain tombe à `creux` et remonte en `retour` s."""
    g = np.ones(n); t = np.arange(n) / sr
    for tb in temps:
        a = int(tb * sr); b = min(n, int((tb + retour) * sr))
        if b <= a: continue
        x = np.clip((t[a:b] - tb) / retour, 0, 1)      # ⚠️ int() tronque : t[a] peut précéder tb d'un échantillon → x < 0 → NaN
        g[a:b] = creux + (1 - creux) * (x ** 1.6)
    return g

def replier_sur(buf, n):
    out = buf[:n].copy(); reste = buf[n:]
    out[: len(reste)] += reste[:n]
    return out

def bande(x, sr=SR, coupe=9000, souffle_db=-58, graine=3):
    y = sosfilt(butter(2, coupe, btype="low", fs=sr, output="sos"), x)
    rng = np.random.default_rng(graine)
    s = sosfilt(butter(2, [800, 6000], btype="band", fs=sr, output="sos"), rng.standard_normal(len(y)))
    return y + db(souffle_db) * s / (np.max(np.abs(s)) + 1e-9)

# ── G · ÉLAN ────────────────────────────────────────────────────────────────
ELAN_ACCORDS = [
    [57, 61, 64, 68],   # Amaj7
    [52, 56, 59, 64],   # E   (mi3 sol#3 si3 mi4)
    [54, 57, 61, 64],   # F#m7
    [50, 54, 57, 61],   # Dmaj7
]
ELAN_BASSES = [45, 40, 42, 38]

def elan():
    bpm = 100.0; temps = 60 / bpm; mesure = 4 * temps
    duree = 8 * mesure                                   # 19,2 s
    n = int(SR * duree); long_ = int(SR * (duree + 4.0))
    nappe = np.zeros(long_); piano = np.zeros(long_); bas = np.zeros(long_); perc = np.zeros(long_)
    rng = np.random.default_rng(1993)
    for mes in range(8):
        acc = ELAN_ACCORDS[mes % 4]; b = ELAN_BASSES[mes % 4]; t0 = mes * mesure
        # la nappe : l'accord tenu une mesure, le filtre qui s'ouvre
        poser(nappe, nappe_accord(acc, mesure, ouverture=(550, 2800)) * 0.9, t0)
        if mes >= 4:                                     # 2e moitié : l'octave au-dessus, loin
            poser(nappe, nappe_accord([m + 12 for m in acc], mesure, ouverture=(900, 3600)) * 0.28, t0)
        # le piano électrique : temps 1 (fort), le « et » de 2 (léger), temps 4 (léger)
        for (tb, v) in ((0.0, 0.62), (1.5 * temps, 0.36), (3.0 * temps, 0.42)):
            for j, m in enumerate(acc):
                poser(piano, epiano(midi(m), 1.6, velocite=v * rng.uniform(0.9, 1.05)), t0 + tb + j * 0.012)
        # la basse : noires, et une croche fantôme avant le temps 3
        for (tb, v, d) in ((0, 0.8, 0.5), (temps, 0.6, 0.5), (2 * temps, 0.8, 0.5), (3 * temps, 0.6, 0.42), (2.5 * temps, 0.35, 0.2)):
            poser(bas, basse(b, d, velocite=v), t0 + tb)
        # le kick, chaque temps ; le souffle sur les contretemps
        for k in range(4):
            poser(perc, kick() * 0.85, t0 + k * temps)
            poser(perc, souffle(0.12, graine=mes * 4 + k) * 0.10, t0 + (k + 0.5) * temps)
    # le pompage sous le kick, sur la nappe et le piano seulement
    battements = [mes * mesure + k * temps for mes in range(8) for k in range(4)]
    g = pompage(long_, battements, creux=0.70, retour=0.30)
    harmo = (nappe * 0.55 + piano * 0.75) * g
    mix = harmo + bas * 0.6 + perc * 0.7
    mix = mix * 0.8 + reverb(harmo, queue=1.4, graine=9) * 0.22
    out = replier_sur(mix, n)
    return normaliser(stereo(bande(out, coupe=9500), largeur=0.14))

# ── H · SOLEIL ──────────────────────────────────────────────────────────────
SOLEIL_ACCORDS = [
    [57, 61, 64, 68],   # A (maj7)
    [50, 54, 57, 62],   # D (add9 → ré fa# la mi)  ← 62 = ré4 : Dmaj
    [52, 56, 59, 62],   # E7
    [57, 61, 64, 69],   # A (octave)
]
SOLEIL_BASSES = [45, 38, 40, 45]

def soleil():
    bpm = 84.0; temps = 60 / bpm; mesure = 4 * temps
    duree = 8 * mesure                                   # ≈ 22,86 s
    n = int(SR * duree); long_ = int(SR * (duree + 4.0))
    cuivres = np.zeros(long_); piano = np.zeros(long_); bas = np.zeros(long_); perc = np.zeros(long_)
    rng = np.random.default_rng(1984)
    for mes in range(8):
        acc = SOLEIL_ACCORDS[(mes // 2) % 4]; b = SOLEIL_BASSES[(mes // 2) % 4]; t0 = mes * mesure
        # les cuivres : deux mesures par accord, ils gonflent (attaque 0,6 s), vibrato tardif
        if mes % 2 == 0:
            poser(cuivres, nappe_accord(acc, 2 * mesure, attaque=0.6, relache=0.8, ouverture=(700, 2200), vibrato=0.006) * 0.9, t0)
            poser(cuivres, nappe_accord([acc[0] - 12], 2 * mesure, attaque=0.6, relache=0.8, ouverture=(300, 900)) * 0.5, t0)
        # le piano : l'accord brisé — fondamentale, tierce, quinte, septième, en croches, puis la tenue
        brise = [acc[0], acc[1], acc[2], acc[3], acc[2], acc[1]]
        for k, m in enumerate(brise):
            poser(piano, epiano(midi(m), 1.3, velocite=(0.55 if k == 0 else 0.4) * rng.uniform(0.9, 1.05)), t0 + k * temps / 2)
        for j, m in enumerate(acc):                      # la tenue sur le temps 4
            poser(piano, epiano(midi(m), 1.8, velocite=0.38), t0 + 3 * temps + j * 0.015)
        # basse et kick sur 1 et 3 ; caisse claire feutrée sur 2 et 4
        for tb in (0.0, 2 * temps):
            poser(bas, basse(b, 0.9, velocite=0.8), t0 + tb)
            poser(perc, kick(f0=95, f1=42, duree=0.32) * 0.8, t0 + tb)
        for tb in (temps, 3 * temps):
            poser(perc, souffle(0.22, bande=(1500, 7000), graine=mes * 2 + int(tb), decroissance=0.06) * 0.16, t0 + tb)
    battements = [mes * mesure + k * temps for mes in range(8) for k in (0, 2)]
    g = pompage(long_, battements, creux=0.78, retour=0.36)
    harmo = (cuivres * 0.6 + piano * 0.7) * g
    mix = harmo + bas * 0.6 + perc * 0.65
    mix = mix * 0.78 + reverb(harmo, queue=1.8, graine=13) * 0.26
    out = replier_sur(mix, n)
    return normaliser(stereo(bande(out, coupe=8500), largeur=0.16))

# ── G2 · ÉLAN DOUCE — sa consigne (13-09, nuit) : « Élan j'imagine, mais MAGIQUE, JOLIE,
#    pas un truc horrible, ni cuivre ». Même harmonie que G, mais : plus de scies (une nappe
#    de TRIANGLES ronds, attaque lente), plus de kick ni de souffle (un CŒUR très doux sur 1
#    et 3), le piano électrique du film en accords + brisés à l'octave, et des ÉTOILES : des
#    notes très hautes du même piano, rares, jetées dans une longue réverbération. Joyeux
#    par l'harmonie et le mouvement, magique par les étoiles, jamais princesse (aucun
#    carillon, aucune mélodie), jamais cuivre. 96 BPM, 8 mesures = 20 s.
def triangle(f, n, sr=SR, plafond=9000.0):
    t = np.arange(n) / sr
    K = max(1, int(plafond / f)); k = np.arange(1, K + 1, 2)[:, None]
    return (np.sin(2 * np.pi * f * k * t) / (k ** 2)).sum(axis=0) * (8 / np.pi ** 2)

def nappe_douce(notes, duree, attaque=0.8, relache=1.2, ouverture=(600, 1500), sr=SR, detune=0.003):
    n = int(sr * (duree + relache)); t = np.arange(n) / sr
    s = np.zeros(n)
    for m in notes:
        f = midi(m)
        for d in (-detune, detune):
            s += triangle(f * (1 + d), n)
    s /= (2 * len(notes))
    env = np.minimum(1, t / attaque) ** 1.4 * np.where(t < duree, 1.0, np.exp(-(t - duree) / (relache / 3)))
    lo = sosfilt(butter(2, ouverture[0], btype="low", fs=sr, output="sos"), s)
    hi = sosfilt(butter(2, ouverture[1], btype="low", fs=sr, output="sos"), s)
    rampe = np.clip(t / max(duree * 0.9, 0.1), 0, 1) ** 1.3
    return (lo * (1 - rampe) + hi * rampe) * env

def elan_douce():
    bpm = 96.0; temps = 60 / bpm; mesure = 4 * temps
    duree = 8 * mesure                                   # 20,0 s
    n = int(SR * duree); long_ = int(SR * (duree + 5.0))
    nappe = np.zeros(long_); piano = np.zeros(long_); bas = np.zeros(long_)
    etoiles = np.zeros(long_); coeur = np.zeros(long_)
    rng = np.random.default_rng(2026)
    for mes in range(8):
        acc = ELAN_ACCORDS[mes % 4]; b = ELAN_BASSES[mes % 4]; t0 = mes * mesure
        poser(nappe, nappe_douce(acc, mesure) * 0.9, t0)
        if mes >= 4:                                     # 2e moitié : l'octave, loin — ça monte
            poser(nappe, nappe_douce([m + 12 for m in acc], mesure, ouverture=(900, 2200)) * 0.22, t0)
        # le piano : l'accord sur 1 (doux), puis un brisé à l'octave sur 2 · 2½ · 3 · 3½
        for j, m in enumerate(acc):
            poser(piano, epiano(midi(m), 2.6, velocite=0.55 * rng.uniform(0.92, 1.05)), t0 + j * 0.014)
        for m, tb in ((acc[0] + 12, 2 * temps), (acc[2] + 12, 2.5 * temps), (acc[1] + 12, 3 * temps), (acc[3] + 12, 3.5 * temps)):
            poser(piano, epiano(midi(m), 1.4, velocite=0.30 * rng.uniform(0.9, 1.1)), t0 + tb)
        # les étoiles : deux ou trois notes très hautes, rares, jamais sur le temps
        for _ in range(int(rng.integers(2, 4))):
            m = acc[int(rng.integers(4))] + 24
            poser(etoiles, epiano(midi(m), 2.2, velocite=0.15), t0 + rng.uniform(0.3, mesure - 0.4))
        # la basse ronde sur 1 et 3 ; le cœur, très doux, aux mêmes temps
        for tb in (0.0, 2 * temps):
            poser(bas, basse(b, 1.15, velocite=0.7), t0 + tb)
            poser(coeur, kick(f0=90, f1=40, duree=0.35) * 0.30, t0 + tb)
    harmo = nappe * 0.5 + piano * 0.75
    mix = harmo + etoiles * 0.7 + bas * 0.55 + coeur * 0.6
    mix = mix * 0.72 + reverb(harmo + etoiles * 1.3, queue=2.4, graine=21) * 0.34
    out = replier_sur(mix, n)
    return normaliser(stereo(bande(out, coupe=9000), largeur=0.18))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    quoi = sys.argv[2] if len(sys.argv) > 2 else "GH"
    if "G" in quoi: ecrire(os.path.join(out, "NosfyFin-G.wav"), elan());        print("écrit NosfyFin-G.wav (élan, 19,2 s)")
    if "H" in quoi: ecrire(os.path.join(out, "NosfyFin-H.wav"), soleil());      print("écrit NosfyFin-H.wav (soleil, 22,9 s)")
    if "2" in quoi: ecrire(os.path.join(out, "NosfyFin-G2.wav"), elan_douce()); print("écrit NosfyFin-G2.wav (élan douce, 20 s)")
