#!/usr/bin/env python3
"""LE CADRE DES LÉGENDAIRES — le même cadre, l'or éteint, l'argent posé.

Kathryn, 28-08 : *« pour les cartes légendaires pas de bordure orangée,
c'est full noir avec un peu de blanc, très très premium — fais un variant
du cadre »*.

`carte-cadre.png` (1086×1448, RGBA, 46 % opaque) est un asset FIXE posé par
`LuneForge.composer` par-dessus l'illustration. Ses 39 854 pixels clairs
sont une braise franche (RVB moyen 168 · 90 · 38, écart R−B de 131) : c'est
elle, la « bordure orangée ».

LA RECETTE — et surtout ce qu'elle ne fait PAS :

- **On garde la FORME au pixel près.** Alpha inchangé, aucun redessin : le
  cadre est mesuré à la fenêtre d'illustration (`fenetre`) et au placement
  des lunes de rareté ; un cadre redessiné, même de trois pixels, décalerait
  l'image sous lui.
- **On neutralise par le CANAL MAX, pas par la luminance.** La luminance
  d'un orange (168·90·38) vaut 107 : elle rendrait un liseré gris sale, à
  moitié éteint. Le canal max garde l'ÉCLAT de la ligne et ne lui retire
  que sa couleur — c'est ce qu'on veut d'un argent.
- **Un cheveu de froid, jamais de bleu** : ×(0,96 · 0,98 · 1,00). Un blanc
  parfaitement neutre sur une nuit chaude tire toujours un peu jaune à
  l'œil ; ce demi-pour-cent le rattrape sans se voir.
- **Le liseré est BAISSÉ à 0,88** (« un peu de blanc ») : à égalité d'éclat
  avec l'ancien or, une ligne blanche crie deux fois plus fort — le blanc
  est la couleur la plus lumineuse qui soit, l'or ne l'était pas.
- **Le corps du cadre perd sa chaleur aussi** (il tirait 19 · 10 · 5) :
  « full noir » veut dire jusque dans les noirs.

Usage :  python3 tools/sacre/bake_cadre_legendaire.py
Sortie : Woop/Media/carte-cadre-legendaire.png
         tools/sacre/noir/preview-cadre-legendaire.png (la planche de verdict)
"""

import os
from PIL import Image
import numpy as np

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(RACINE, "Woop", "Media")
SORTIE = os.path.join(RACINE, "tools", "sacre", "noir")

FROID = np.array([0.96, 0.98, 1.00])   # le cheveu de froid
ECLAT = 0.88                            # « un peu de blanc »
NOIR = 26.0                             # le POINT NOIR (« le fond noir »)


def main():
    src = Image.open(os.path.join(MEDIA, "carte-cadre.png")).convert("RGBA")
    a = np.asarray(src).astype(float)
    rgb, alpha = a[..., :3], a[..., 3:]

    # LE POINT NOIR — « le fond de la card noir ». Le corps du cadre n'est
    # pas noir dans l'asset d'origine : il tire 19 · 10 · 5, un brun très
    # sombre qui, neutralisé, devient un GRIS 17. Sur une page noire, un gris
    # 17 ne se lit pas comme du noir : il se lit comme un voile. On repousse
    # donc le pied de la courbe à zéro (tout ce qui est sous 26 devient noir
    # PLEIN) et on ré-étale ce qui reste — le liseré garde son éclat, le
    # champ de la carte devient vraiment noir.
    neutre = rgb.max(axis=2, keepdims=True)
    neutre = np.clip((neutre - NOIR) * (255.0 / (255.0 - NOIR)), 0, 255)
    argent = neutre * ECLAT * FROID
    sortie = np.concatenate([np.clip(argent, 0, 255), alpha], axis=2)
    out = Image.fromarray(sortie.astype(np.uint8), "RGBA")
    out.save(os.path.join(MEDIA, "carte-cadre-legendaire.png"))

    # La planche de verdict : le cadre sur du noir, comme il vivra.
    os.makedirs(SORTIE, exist_ok=True)
    fond = Image.new("RGB", src.size, (0, 0, 0))
    fond.paste(out, (0, 0), out)
    fond.resize((543, 724), Image.LANCZOS).save(
        os.path.join(SORTIE, "preview-cadre-legendaire.png"))

    m = (alpha[..., 0] > 60) & (rgb.max(axis=2) > 90)
    print("cadre :", os.path.join(MEDIA, "carte-cadre-legendaire.png"))
    print("  braise d'origine : RVB %s (écart R−B %.0f)"
          % (rgb[m].mean(axis=0).round(1), (rgb[m][:, 0] - rgb[m][:, 2]).mean()))
    print("  argent obtenu    : RVB %s (écart R−B %.1f)"
          % (argent[m].mean(axis=0).round(1),
             (argent[m][:, 0] - argent[m][:, 2]).mean()))


if __name__ == "__main__":
    main()
