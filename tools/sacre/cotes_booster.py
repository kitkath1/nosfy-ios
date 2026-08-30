#!/usr/bin/env python3
"""
cotes_booster.py — LA CAPTURE DE LA CARD BOOSTER CONTRE LES COTES DU PLAN (§4).

    python3 tools/sacre/cotes_booster.py tools/sacre/captures/card-b4-HHMMSS.png

Un juge qui affirme ne remplace pas une sonde qui mesure. Ce script ne dit
pas si c'est beau : il dit OÙ SONT LES CHOSES, en points depuis le bord haut
de la card, et les compare au plan. Le verdict esthétique reste à Kathryn.

  · la card : largeur franche (le liseré), hauteur par le ratio 1,40 — le bas
    de la card est du noir quasi pur, un seuil le rognerait (leçon cotes.py)
  · le sachet : par ses pixels ORANGE (R > G + 40) — attendu 48 → 224, 176 de haut
  · les points du mur : combien, et leur clarté (attendu : on les VOIT)
  · la légende, le titre, le sous-titre, Later : les bandes claires du profil
"""
import sys, os
import numpy as np
from PIL import Image

CAP = sys.argv[1] if len(sys.argv) > 1 else None
if not CAP or not os.path.exists(CAP):
    sys.exit("usage: cotes_booster.py <capture.png>")

im = np.asarray(Image.open(CAP).convert("RGB")).astype(float)
H, W = im.shape[:2]
L = im.max(axis=2)
ech = W / 393.0
print(f"capture {W}×{H} px — {ech:.2f} px/pt (iPhone 17 Pro, 393 pt)")

# ⚠️ LA CARD SE CALCULE, ELLE NE SE DÉTECTE PAS : cette pop-up s'ouvre sur la
# HOME, dont le titre blanc traverse le scrim à ~50/255 — un seuil de clarté
# prenait « Hello Kathryn » pour le bord de la card (347 × 486 mesurés pour
# 314 × 440). La card est `min(0,80·W, 332)` de large, ratio 1,40, centrée.
lp = min(0.80 * 393.0, 332.0)
hp = lp * 1.40
x0 = int(round((W - lp * ech) / 2)); x1 = int(round(x0 + lp * ech)) - 1
y0 = int(round((H - hp * ech) / 2)); y1 = int(round(y0 + hp * ech))
# La preuve que le calcul tombe juste : le liseré (1 pt, blanc 0,14) est une
# ligne plus claire que ses deux voisines, sur la colonne du bord gauche.
col = L[y0 + int(60 * ech):y1 - int(60 * ech), x0 - 3:x0 + 4].mean(axis=0)
print(f"\nCARD   : {lp:.0f} × {hp:.0f} pt, bord gauche calculé à x = {x0} px — "
      f"clarté des 7 colonnes autour : {np.round(col).astype(int).tolist()} "
      f"(le liseré = un pic au milieu)")


def pt(y):
    return (y - y0) / ech


carte = im[y0:y1, x0:x1 + 1]
Lc = carte.max(axis=2)

# ── LE SACHET : ses pixels orange ──────────────────────────────────────────
orange = (carte[..., 0] > carte[..., 1] + 40) & (carte[..., 0] > 90)
# la lueur de scène est orange aussi, mais diffuse : on garde les lignes où
# l'orange est FRANC (≥ 6 px sur la ligne)
lig = np.where(orange.sum(axis=1) >= 6)[0]
if len(lig):
    haut, bas = lig.min() / ech, lig.max() / ech
    print(f"SACHET : {haut:.0f} → {bas:.0f} pt (haut de {bas - haut:.0f})   "
          f"(attendu 48 → 224, 176 de haut ; la lueur orange au sol peut "
          f"allonger le bas de quelques pt)")
    cols = np.where(orange.any(axis=0))[0]
    cx = (cols.min() + cols.max()) / 2 / ech
    print(f"         centre x {cx:.0f} pt (attendu {lp / 2:.0f})")

# ── LES POINTS DU MUR : blancs/dorés, petits, hors du sachet ──────────────
zone = Lc[int(20 * ech):int(252 * ech)]
petits = (zone > 70)
if len(lig):
    petits[:, int(cols.min()) - 4:int(cols.max()) + 5] = False   # pas le sachet
from scipy import ndimage as ndi
lab, k = ndi.label(petits)
tailles = np.asarray(ndi.sum(petits, lab, range(1, k + 1))) if k else np.array([0])
print(f"POINTS : {k} taches claires hors sachet dans la zone du mur, taille "
      f"médiane {np.median(tailles) / ech / ech:.1f} pt², max clarté "
      f"{int(zone.max())}/255  (la 1re cuisson : rien de visible)")

# ── L'ENCRE : les bandes claires sous 250 pt ──────────────────────────────
print("\nENCRE (bandes claires, en pt depuis le haut de la card) :")
prof = Lc.mean(axis=1)
bas = prof[int(250 * ech):]
seuil = bas.mean() + 0.6 * bas.std()
dans, debut = False, 0
for i, v in enumerate(bas):
    if v > seuil and not dans:
        dans, debut = True, i
    elif v <= seuil and dans:
        dans = False
        a, b = 250 + debut / ech, 250 + i / ech
        if b - a > 3:
            print(f"   bande {a:6.0f} → {b:6.0f} pt   (haute de {b - a:.0f})")
print("   attendu : légende ≈ 265→279 · titre 312→338 · sous-titre 348→366 · "
      "Later ≈ 392→412 (le texte dans ses 44 pt)")
