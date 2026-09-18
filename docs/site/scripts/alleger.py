#!/usr/bin/env python3
"""
alleger.py — LES JPEG DU SITE, RÉ-ENCODÉS SANS PERDRE UN PIXEL.

    python3 scripts/alleger.py            # tout public/captures/**/*.jpg, en place
    python3 scripts/alleger.py <fichier>  # un seul

Le 17-09, le livrable a franchi les 2 Mo (2 056 876 o) sous le poids du TEXTE des pages
(la règle de l'inliner : « on baisse la qualité JPEG, jamais le nombre de captures »).
Mesuré avant d'y toucher : les JPEG écrits par `sips` ne sont pas optimisés (tables de
Huffman par défaut, pas de progressif) — les mêmes pixels réécrits par Pillow avec
`optimize` + `progressive` + chroma 4:2:0 pèsent 30 % de moins À QUALITÉ ÉGALE :
511 727 o → ~350 000 o pour les 58 captures, soit ~215 Ko de moins une fois en base64.
C'est donc d'abord une COMPRESSION SANS PERTE de plus (l'entropie), la qualité JPEG
elle-même ne bouge qu'à la marge (QUALITE ci-dessous, sur l'échelle libjpeg).

Idempotent : ré-encoder un fichier déjà allégé ne change (presque) rien. Appelé par
captures.py après chaque `reduire(...)` JPEG, et à la main quand le livrable déborde.
"""
import glob
import io
import os
import sys

from PIL import Image

QUALITE = 60          # libjpeg ; ≈ ce que sips donnait à 66 (flow) / 58 (hero), en plus léger


def alleger(chemin, qualite=QUALITE):
    """Ré-encode `chemin` en place ; rend (avant, après) en octets. Ne touche pas aux PNG."""
    avant = os.path.getsize(chemin)
    im = Image.open(chemin)
    if im.format != 'JPEG':
        return avant, avant
    im = im.convert('RGB')
    b = io.BytesIO()
    im.save(b, 'JPEG', quality=qualite, optimize=True, progressive=True, subsampling=2)
    donnees = b.getvalue()
    if len(donnees) < avant:
        with open(chemin, 'wb') as f:
            f.write(donnees)
    return avant, os.path.getsize(chemin)


def main(argv):
    ici = os.path.dirname(os.path.abspath(__file__))
    fichiers = argv[1:] or sorted(glob.glob(os.path.join(ici, '..', 'public', 'captures', '**', '*.jpg'), recursive=True))
    total_avant = total_apres = 0
    for f in fichiers:
        avant, apres = alleger(f)
        total_avant += avant
        total_apres += apres
        print('  %-52s %7d → %7d o' % (os.path.relpath(f, os.path.join(ici, '..')), avant, apres))
    print('%d JPEG : %d → %d o (%+d)' % (len(fichiers), total_avant, total_apres, total_apres - total_avant))


if __name__ == '__main__':
    main(sys.argv)
