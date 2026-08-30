#!/usr/bin/env python3
"""
La palette RÉELLE d'un écran de l'app — pour teinter le hero d'une page de domaine
avec la couleur que l'écran a vraiment, jamais avec une couleur choisie.

  python3 tools/docsite/palette.py                 # les écrans connus → tableau + palette.json
  python3 tools/docsite/palette.py chemin.png …    # d'autres captures

Méthode : réduction à 200 px de large, HSV, on ne garde que la LUMIÈRE COLORÉE
(V > .25 et S > .30 — pas le noir), histogramme de teinte par pas de 10°, et pour le
pas dominant la couleur médiane (H, S, V médians). Loi du plan v2 §3.2 : H et S
mesurés entrent tels quels ; V est posé à 62 pour tous les heros (le seul écart à la
mesure, écrit dans la loi) ; < 1 % de pixels colorés = pas de couleur → hero noir.
"""
import colorsys, json, os, sys
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SORTIE = os.path.join(RACINE, 'tools/docsite/palette.json')
V_HERO = 0.62
SEUIL_COLORE = 1.0   # % de pixels colorés en dessous duquel l'écran est « noir »

ECRANS = [
    ('flow',    'home',           'tools/road/shots/j4-home-serpentin.png'),
    ('chemin',  'chemin (verre)', 'tools/road/shots/road-2-etats-etape5.png'),
    ('chemin',  'chemin (bleu)',  'tools/road/shots/road-3-tresor-ecran5.png'),
    ('depart',  'départ',         'tools/road/shots/road-1-branchee.png'),
    ('stop',    'stop',           'tools/stop/captures/stop-134059.png'),
    ('regles',  'coffre v1',      'tools/coffre-v2/ARCHIVE/coffre-v1.jpg'),
    ('home2',   'home v2',        'tools/home-v2/shots/verdict-piece-noire-page.jpg'),
    ('notifs',  'notifs',         'tools/notifs/captures/v7.png'),
    ('noir',    'booster noir',   'tools/sacre/noir/preview-face.png'),
    ('exo',     'page exo (v1)',  'tools/verre/archives/v1-noir-orange/g9-ferme.png'),
    ('logo',    'logo lune',      'Woop/Media/carte-logo-ref.png'),
    ('forge',   'booster orange', 'Woop/Assets.xcassets/booster-orange.imageset/booster-orange.png'),
    ('porte',   'porte (lune)',   'Woop/Assets.xcassets/onb-lune-loop-poster.imageset/onb-lune-loop-poster.jpg'),
]

def mediane(v):
    v = sorted(v); n = len(v)
    return v[n // 2] if n % 2 else (v[n // 2 - 1] + v[n // 2]) / 2

def hexa(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return '#%02X%02X%02X' % (round(r * 255), round(g * 255), round(b * 255))

def analyser(chemin, vt=0.25, st=0.30):
    im = Image.open(chemin).convert('RGB'); w, h = im.size
    im = im.resize((200, max(1, round(h * 200 / w))), Image.LANCZOS)
    px = list(im.getdata()); tot = len(px); lum = 0.0; noir = 0; pas = {}
    for r, g, b in px:
        R, G, B = r / 255, g / 255, b / 255
        hh, s, v = colorsys.rgb_to_hsv(R, G, B)
        lum += 0.2126 * R + 0.7152 * G + 0.0722 * B
        if v < 0.08: noir += 1
        if v > vt and s > st: pas.setdefault(int(hh * 360) // 10, []).append((hh, s, v))
    teintes = []
    for k, vals in sorted(pas.items(), key=lambda x: -len(x[1]))[:2]:
        hm, sm, vm = mediane([x[0] for x in vals]), mediane([x[1] for x in vals]), mediane([x[2] for x in vals])
        teintes.append({'hex': hexa(hm, sm, vm), 'part': round(100 * len(vals) / tot, 2), 'h': round(hm * 360), 's': round(sm * 100), 'v': round(vm * 100),
                        'hero': hexa(hm, sm, V_HERO)})
    colore = round(100 * sum(len(v) for v in pas.values()) / tot, 2)
    return {'teintes': teintes, 'colore': colore, 'luminance': round(lum / tot, 3), 'noir': round(100 * noir / tot, 1),
            'verdict': 'noir' if colore < SEUIL_COLORE else 'teinte'}

def main():
    cibles = [(os.path.basename(a), a, a) for a in sys.argv[1:]] or ECRANS
    resultat = {}
    print('%-8s %-16s %-9s %-7s %-9s %-8s %-6s %-7s %s' % ('page', 'écran', 'couleur', 'part', 'hero V62', '2e', 'lum', 'noir', 'verdict'))
    for page, nom, rel in cibles:
        chemin = rel if os.path.isabs(rel) else os.path.join(RACINE, rel)
        if not os.path.exists(chemin):
            print('%-8s %-16s absent : %s' % (page, nom, rel)); continue
        r = analyser(chemin); r['fichier'] = rel; resultat[nom] = r
        t1 = r['teintes'][0] if r['teintes'] else None; t2 = r['teintes'][1] if len(r['teintes']) > 1 else None
        print('%-8s %-16s %-9s %-7s %-9s %-8s %-6s %-6s%% %s' % (
            page, nom, t1['hex'] if t1 else '—', ('%.2f%%' % t1['part']) if t1 else '—', t1['hero'] if t1 else '—',
            t2['hex'] if t2 else '—', r['luminance'], r['noir'], r['verdict']))
    with open(SORTIE, 'w') as f: json.dump(resultat, f, ensure_ascii=False, indent=1)
    print('→', os.path.relpath(SORTIE, RACINE))

if __name__ == '__main__':
    main()
