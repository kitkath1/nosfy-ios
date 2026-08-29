#!/usr/bin/env python3
"""
cotes.py — LA CAPTURE CONTRE LES COTES DU PLAN (§2.1).

    python3 tools/stop/cotes.py tools/stop/captures/stop-HHMMSS.png

Un juge qui affirme ne remplace pas une sonde qui mesure. Ce script ne dit
pas si c'est beau : il dit OÙ SONT LES CHOSES, en points, et les compare aux
cotes tranchées au plan. Le verdict esthétique reste à Kathryn.

Ce qu'il mesure, sur la card seule (détectée par son liseré sur le noir) :
  - les bords de la card et sa taille (attendu 332 × 480 pt)
  - le centre du mot géant (attendu 112 pt)          ← par la masse claire
  - les pieds de la bête (attendu 268 pt)            ← par le masque cuit
  - la piste du slider (attendu 352 → 414 pt)        ← par sa capsule sombre
  - le titre et le sous-titre (attendu 284 → 334 pt)
  - le lien Cancel (attendu ≈ 420 → 464 pt)
  - LE MOT EST-IL SOMBRE ? (la régression classique : on le « fond » en
    baissant son opacité au lieu de le laisser sombre sous la lampe)
"""
import sys, os
import numpy as np
from PIL import Image

CAP = sys.argv[1] if len(sys.argv) > 1 else None
if not CAP or not os.path.exists(CAP):
    sys.exit("usage: cotes.py <capture.png>")

im = np.asarray(Image.open(CAP).convert("RGB")).astype(float)
H, W = im.shape[:2]
ech = W / 393.0                        # iPhone 17 Pro : 393 pt de large
luma = im.max(axis=2)
print(f"capture {W}×{H} px — {ech:.2f} px/pt (iPhone 17 Pro, 393 pt)")

# ── LA CARD ────────────────────────────────────────────────────────────────
# ⚠️ PAS « le non-noir » : l'ombre de la card est BLANCHE et déborde de ~11 pt
# de chaque côté — mesurée ainsi, la card faisait 354 × 503 au lieu de
# 332 × 480. On cherche le SAUT de clarté (le liseré + le contenu), pas la
# lueur. Seuil sur le maximum d'une colonne / d'une ligne.
def bornes(profil, seuil):
    v = np.where(profil > seuil)[0]
    return v.min(), v.max()


x0, x1 = bornes(luma.max(axis=0), 45)
# ⚠️ La HAUTEUR ne se détecte pas au seuil : le pied de la card est du noir
# quasi pur (le fond meurt à 0), la détection le rognait de 30 pt. La largeur,
# elle, est franche. On déduit donc la hauteur du RATIO du composant — et on
# vérifie que le bord haut détecté tombe bien où le calcul le met.
y0 = bornes(luma.max(axis=1), 45)[0]
y1 = y0 + int(round((x1 - x0 + 1) * 480.0 / 332.0))
lp, hp = (x1 - x0 + 1) / ech, (y1 - y0 + 1) / ech
# ⚠️ La card fait `min(0,80 × largeur d'écran, 332)`. Sur un écran de 393 pt
# (iPhone 17 Pro) cela donne 314, PAS 332 : les cotes du plan étaient écrites
# pour la card PLEINE. Tout ce qui suit la card (la bête, portée par la vidéo)
# rétrécit avec elle ; le TEXTE, lui, garde ses points. C'est là que les deux
# se rencontrent.
attendu_l = min(0.80 * 393, 332)
print(f"\nCARD   : {lp:.0f} × {hp:.0f} pt   (attendu {attendu_l:.0f} × "
      f"{attendu_l * 480 / 332:.0f} sur CE téléphone ; le plan disait 332 × 480)"
      f"   {'OK' if abs(lp - attendu_l) <= 3 else '⚠️ ÉCART'}")
k = lp / 332.0
print(f"         facteur d'échelle vs le plan : {k:.3f} — une cote du plan à "
      f"268 pt tombe ici à {268 * k:.0f} pt")


def pt(y_px):
    """Un y de l'image, en points DEPUIS LE BORD HAUT DE LA CARD."""
    return (y_px - y0) / ech


# ── LE PROFIL VERTICAL de la card, en clarté ──────────────────────────────
carte = luma[y0:y1 + 1, x0:x1 + 1]
prof = carte.mean(axis=1)

# ── LE MOT : la masse claire du tiers haut, pondérée ───────────────────────
# ⚠️ On part SOUS la fente du spot (35 pt) : au-dessus, les pixels les plus
# clairs de la card sont ceux de la LAMPE, pas du mot — la sonde annonçait un
# « centre à 53 pt » qui était le cône, pas le texte.
y_mot0 = int(35 * ech)
haut = carte[y_mot0:int(210 * ech)]
# le mot est ce qui dépasse le fond gris : on mesure sur les PIXELS CLAIRS
seuil = np.percentile(haut, 97)
masse = (haut > seuil)
ys = np.where(masse.any(axis=1))[0]
if len(ys):
    poids = masse.sum(axis=1).astype(float)
    centre = (float((np.arange(len(poids)) * poids).sum() / poids.sum())
              + y_mot0) / ech
    # Le mot est posé en points ABSOLUS (112), il ne suit pas la card.
    print(f"MOT    : centre {centre:.0f} pt, de {(ys.min()+y_mot0)/ech:.0f} à "
          f"{(ys.max()+y_mot0)/ech:.0f} pt   (attendu centre 112, absolu)"
          f"   {'OK' if abs(centre-112) <= 10 else '⚠️ ÉCART'}")

# ── LA BÊTE : par le masque cuit, replacé aux cotes de la card ────────────
MASK = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "..", "..", "Woop", "Assets.xcassets",
                    "stop-bat-masque.imageset", "stop-bat-masque.png")
if os.path.exists(MASK):
    # ⚠️ L'ALPHA, pas la luminance : depuis la correction du 29-08 le masque
    # est en RGBA blanc + alpha. Un `.convert("L")` rendrait 255 partout.
    m = Image.open(MASK).convert("RGBA").resize((x1 - x0 + 1, y1 - y0 + 1))
    dedans = np.asarray(m)[..., 3] < 128
    yb = np.where(dedans.any(axis=1))[0]
    # ⚠️ Les cotes de la bête sont PORTÉES PAR LA VIDÉO : elles suivent la
    # card, donc il faut les comparer à la cote du plan MISE À L'ÉCHELLE (`k`),
    # pas à sa valeur brute — sinon la sonde crie au loup sur tout téléphone
    # plus étroit que 415 pt. Cuisson du 29-08 : pieds 246, haute de 200.
    att_pieds, att_haut = 246 * k, 200 * k
    print(f"BÊTE   : de {yb.min()/ech:.0f} à {yb.max()/ech:.0f} pt "
          f"(pieds), haute de {(yb.max()-yb.min())/ech:.0f} pt"
          f"   (attendu ici {att_pieds:.0f} de pieds, {att_haut:.0f} de haut)"
          f"   {'OK' if abs(yb.max()/ech - att_pieds) <= 6 else '⚠️ ÉCART'}")
    # LE MOT EST-IL SOMBRE ? On le mesure LÀ OÙ LA BÊTE N'EST PAS.
    mur = carte[:int(200 * ech)][~dedans[:int(200 * ech)]]
    print(f"         le mur (hors bête, tiers haut) : médiane "
          f"{np.median(mur):.0f}/255, p99 {np.percentile(mur, 99):.0f}/255 "
          f"— le mot doit être SOMBRE (p99 < 150), révélé par la lampe")

# ── LES BANDES D'ENCRE : les creux et les bosses du profil bas ────────────
print("\nENCRE (les bandes claires du bas, en pt depuis le haut de la card) :")
bas = prof[int(260 * ech):]
seuil_b = bas.mean() + 0.6 * bas.std()
dans, debut = False, 0
for i, v in enumerate(bas):
    if v > seuil_b and not dans:
        dans, debut = True, i
    elif v <= seuil_b and dans:
        dans = False
        a, b = 260 + debut / ech, 260 + i / ech
        if b - a > 4:
            print(f"   bande {a:6.0f} → {b:6.0f} pt   (haute de {b-a:.0f})")
if dans:
    print(f"   bande {260 + debut/ech:6.0f} → {260 + len(bas)/ech:6.0f} pt")
print("   attendu : titre 284→310 · bilan 316→334 · slider 352→414 · "
      "Cancel ≈420→464")
