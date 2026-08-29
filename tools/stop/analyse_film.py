#!/usr/bin/env python3
"""
analyse_film.py — LE FILM DU BANC, jugé sur les `pts`, jamais sur les images.

    python3 tools/stop/analyse_film.py tools/stop/films/stop-HHMMSS.mov

Le `recordVideo` du simulateur est **VFR** : compter les images ne dit rien de
la durée. Tout ce qui est temporel se lit donc sur l'horodatage réel de chaque
image (`-show_entries frame=pkt_pts_time`).

Ce qu'il cherche :
  1. LES FLASHS — un saut de clarté brutal entre deux images consécutives.
     C'est le défaut n°1 d'une transition (une vue lourde qui naît, un calque
     qui apparaît avant son masque, un fondu qui repart de zéro).
  2. LES PALIERS — les instants où la card entre et sort, et la DURÉE réelle
     de chaque rampe, comparée à ce que le code annonce (entrée 0,60 s,
     Cancel 0,30 s, sortie du commit 0,42 s après 0,50 s d'attente).
  3. LE TROU NOIR — une image entièrement noire au milieu d'une transition
     (la card démontée avant la fin de sa sortie).
"""
import sys, os, subprocess
import numpy as np

MOV = sys.argv[1] if len(sys.argv) > 1 else None
if not MOV or not os.path.exists(MOV):
    sys.exit("usage: analyse_film.py <film.mov>")

# ── LES HORODATAGES RÉELS ──────────────────────────────────────────────────
pts = subprocess.run(
    ["ffprobe", "-v", "error", "-select_streams", "v:0",
     "-show_entries", "frame=pkt_pts_time", "-of", "csv=p=0", MOV],
    capture_output=True, text=True).stdout.split()
t = np.array([float(x.rstrip(",")) for x in pts if x.rstrip(",")
              not in ("", "N/A")])
dt = np.diff(t)
print(f"{len(t)} images sur {t[-1] - t[0]:.2f} s — cadence apparente "
      f"{len(t) / (t[-1] - t[0]):.1f} img/s")
regime = ("VFR marqué — les durées ci-dessous restent justes, "
          "elles sont lues sur les pts"
          if dt.max() > 3 * np.median(dt) else "régulier")
print(f"intervalle : médian {np.median(dt) * 1000:.1f} ms, "
      f"pire {dt.max() * 1000:.1f} ms  ({regime})")

# ── LES IMAGES, en petit (on juge des masses, pas du détail) ───────────────
LG, HT = 120, 260
raw = subprocess.run(
    ["ffmpeg", "-nostdin", "-v", "error", "-i", MOV,
     "-vf", f"scale={LG}:{HT}", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
    capture_output=True).stdout
n = LG * HT
fr = np.frombuffer(raw, np.uint8)[:len(raw) // n * n].reshape(-1, HT, LG)
m = min(len(fr), len(t))
fr, t = fr[:m], t[:m]
clarte = fr.reshape(m, -1).mean(axis=1)
print(f"clarté moyenne : min {clarte.min():.2f}, max {clarte.max():.2f}")

# ── 1. LES FLASHS ──────────────────────────────────────────────────────────
saut = np.abs(np.diff(clarte))
seuil = max(3.0, 6 * np.median(saut[saut > 0]) if (saut > 0).any() else 3.0)
flashs = np.where(saut > seuil)[0]
if len(flashs):
    print(f"\n⚠️ {len(flashs)} SAUT(S) de clarté > {seuil:.2f} :")
    for i in flashs[:12]:
        print(f"   t={t[i]:6.2f}s  {clarte[i]:6.2f} → {clarte[i+1]:6.2f} "
              f"(Δ {saut[i]:+.2f}) en {(t[i+1]-t[i])*1000:.0f} ms")
else:
    print(f"\nAucun saut de clarté au-dessus de {seuil:.2f} — pas de flash.")

# ── 3. LE TROU NOIR ────────────────────────────────────────────────────────
noires = np.where(clarte < 0.6)[0]
if len(noires):
    print(f"⚠️ {len(noires)} image(s) quasi NOIRE(S) (clarté < 0,6) : "
          f"t = {', '.join(f'{t[i]:.2f}' for i in noires[:8])}")
else:
    print("Aucune image noire — la card ne se démonte jamais avant sa sortie.")

# ── 2. LES PALIERS : montées et descentes ──────────────────────────────────
bas, haut = np.percentile(clarte, 5), np.percentile(clarte, 95)
if haut - bas < 1.0:
    print("\nLa clarté ne bouge presque pas : rien à mesurer "
          "(le banc a-t-il bien reçu -stopAuto ?)")
    sys.exit(0)
seuil_b, seuil_h = bas + 0.1 * (haut - bas), bas + 0.9 * (haut - bas)
etat = np.where(clarte > seuil_h, 1, np.where(clarte < seuil_b, 0, -1))
print(f"\nRAMPES (10 % → 90 % de la course de clarté, lues sur les pts) :")
i = 0
while i < m - 1:
    if etat[i] in (0, 1) and etat[i + 1] == -1:
        depart, val = t[i], etat[i]
        j = i + 1
        while j < m and etat[j] == -1:
            j += 1
        if j < m and etat[j] != val:
            sens = "ENTRÉE " if val == 0 else "SORTIE "
            print(f"   {sens} {t[j] - depart:.3f} s   (de t={depart:.2f} "
                  f"à t={t[j]:.2f})")
        i = j
    else:
        i += 1
print("\nAttendu : ENTRÉE 0,60 s · SORTIE Cancel 0,30 s · "
      "SORTIE après commit 0,42 s (précédée de 0,50 s d'attente).")
