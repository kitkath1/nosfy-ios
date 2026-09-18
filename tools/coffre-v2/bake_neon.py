#!/usr/bin/env python3
"""LES NÉONS DU SOCLE, SORTIS DU DÉCOR — pour qu'ils changent de couleur.

Verdict du 29-08 : *« tu peux animer dessus des néons qui sont dans le
podium ? »*

⚠️ **CE N'EST PAS UN EFFET, C'EST UN LEVIER — MESURÉ.** Les pixels saturés
(R−B > 40) de `coffre-arche.png` portent **35,9 % de la lumière TOTALE de
l'image**, dont 28,8 % dans la seule bande du socle. Les animer, c'est prendre
la main sur plus d'un tiers de l'image, exactement là où le §23.8 a mesuré que
l'identité s'était effondrée (101 points d'écart entre les pages avec le
spotlight, **23** avec l'arche).

⚠️⚠️ **ET LE POINT QUI DÉCIDE DE TOUT EST UNE SOUSTRACTION.** Superposer un
néon coloré sur l'image intacte, c'est ajouter à de l'orange déjà là : on peut
le SURCHARGER, jamais le faire virer au bleu. Pour qu'un socle devienne froid
sur la page d'argent, **il faut d'abord lui retirer son orange**. Ce script
produit donc deux fichiers :

    coffre-arche.png       l'arche, socle ÉTEINT dans la bande des anneaux
    coffre-arche-neon.png  les anneaux seuls, en niveaux de gris sur noir

Le second se compose en `plusLighter` et se teinte au `colorMultiply` : le
noir n'ajoute rien, le gris ajoute la couleur de la page.

⚠️ **SEULS LES NÉONS DU SOCLE SORTENT.** Ceux de l'arche restent dans la base :
toute la scène qui change de couleur à chaque page serait trop fort. Le décor
garde son identité, l'objet garde la sienne — d'où la bande `BANDE0..BANDE1`,
avec des rampes en cosinus aux deux bouts pour que la soustraction n'ait pas
de frontière.

⚠️ **L'ALPHA EST UNE RAMPE, JAMAIS UN SEUIL.** Un seuil binaire dessine un
escalier sur un dégradé, et tout ici est dégradé — la leçon du détourage
(§18.5), payée quatre fois.

Usage : python3 tools/coffre-v2/bake_neon.py   (après bake_arche.py)
"""

import os
import numpy as np
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(RACINE, "Nosfy", "Media")
SORTIE = os.path.join(RACINE, "tools", "coffre-v2", "vignettes")

# Les anneaux vivent de 0,500 à 0,690 H (mesuré). On prend un peu plus large,
# et on fond aux deux bouts.
BANDE0, BANDE1 = 0.455, 0.735
FONDU = 0.045
# La rampe de saturation : R−B de 18 (rien) à 70 (plein néon).
SAT0, SAT1 = 18.0, 70.0


def cosinus(t):
    return 0.5 - 0.5 * np.cos(np.pi * np.clip(t, 0, 1))


def main():
    src = os.path.join(MEDIA, "coffre-arche.png")
    a = np.asarray(Image.open(src).convert("RGB")).astype(float)
    H, W, _ = a.shape
    R, G, B = a[..., 0], a[..., 1], a[..., 2]

    # ── QUI EST DU NÉON ? une rampe, pas un seuil ──────────────────────
    s = np.clip((R - B - SAT0) / (SAT1 - SAT0), 0, 1)

    # ── ET OÙ ? la bande du socle, fondue aux deux bouts ───────────────
    y = np.arange(H) / H
    bande = np.zeros(H)
    dedans = (y >= BANDE0) & (y <= BANDE1)
    bande[dedans] = 1.0
    m = (y >= BANDE0) & (y < BANDE0 + FONDU)
    bande[m] = cosinus((y[m] - BANDE0) / FONDU)
    m = (y > BANDE1 - FONDU) & (y <= BANDE1)
    bande[m] = cosinus((BANDE1 - y[m]) / FONDU)
    s = s * bande[:, None]

    # ── LE NÉON SEUL : la lumière CHAUDE qu'on retire ──────────────────
    # C'est l'excès du rouge sur le bleu qui fait le liseré ; on le sort en
    # niveaux de gris pour pouvoir le reteindre librement.
    chaud = np.clip(R - B, 0, None) * s
    neon = np.dstack([chaud, chaud, chaud])
    Image.fromarray(np.clip(neon, 0, 255).astype(np.uint8)) \
         .save(os.path.join(MEDIA, "coffre-arche-neon.png"))

    # ── LA BASE : le socle ÉTEINT ──────────────────────────────────────
    # On ramène R et V vers B là où le néon passait : le verre retrouve sa
    # valeur nue, sombre et neutre. C'est ce qui permettra au bleu de gagner
    # sur la page d'argent.
    base = a.copy()
    base[..., 0] = R * (1 - s) + B * s
    base[..., 1] = G * (1 - s) + B * s
    Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).save(src)

    Lb = np.clip(base, 0, 255).max(axis=2)
    La = a.max(axis=2)
    z0, z1 = int(H * 0.50), int(H * 0.70)
    print("coffre-arche.png → base éteinte + coffre-arche-neon.png")
    print("  bande du socle %.3f → %.3f H, fondu %.3f" % (BANDE0, BANDE1, FONDU))
    print("  dans la bande : luminance %.1f → %.1f  (−%.0f %%)"
          % (La[z0:z1].mean(), Lb[z0:z1].mean(),
             100 * (1 - Lb[z0:z1].mean() / max(La[z0:z1].mean(), 1))))
    print("  saturation R−B  %.1f → %.1f"
          % ((a[z0:z1, :, 0] - a[z0:z1, :, 2]).mean(),
             (base[z0:z1, :, 0] - base[z0:z1, :, 2]).mean()))
    print("  hors bande (0,20 → 0,45 H) : R−B %.1f → %.1f  (l'arche NE bouge pas)"
          % ((a[int(H * 0.20):int(H * 0.45), :, 0]
              - a[int(H * 0.20):int(H * 0.45), :, 2]).mean(),
             (base[int(H * 0.20):int(H * 0.45), :, 0]
              - base[int(H * 0.20):int(H * 0.45), :, 2]).mean()))
    print("  néon : %.1f %% de pixels non nuls, L moyenne %.1f"
          % (100 * (chaud > 4).mean(), chaud[chaud > 4].mean()))

    # La planche de verdict : base et néon côte à côte, sur damier pour la
    # base (le noir cache tout, §18.5) et sur gris pour le néon.
    os.makedirs(SORTIE, exist_ok=True)
    duo = Image.new("RGB", (W // 3 * 2 + 30, H // 3), (90, 90, 96))
    duo.paste(Image.open(src).resize((W // 3, H // 3), Image.LANCZOS), (0, 0))
    duo.paste(Image.fromarray(np.clip(neon, 0, 255).astype(np.uint8))
              .resize((W // 3, H // 3), Image.LANCZOS), (W // 3 + 30, 0))
    duo.save(os.path.join(SORTIE, "neon-verdict.png"))
    print("  planche :", os.path.join(SORTIE, "neon-verdict.png"))


if __name__ == "__main__":
    main()
