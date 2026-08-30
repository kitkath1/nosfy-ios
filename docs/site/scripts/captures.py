#!/usr/bin/env python3
"""
Les captures du site v2 — du dépôt vers `docs/site/public/captures/`, et le manifeste
`docs/site/content/captures.json` que le build lit. Remplace tools/docsite/embarquer.py
(v1 : des data URI collées dans index.html). En v2 c'est l'inliner qui embarque : ce
script ne fait que PRODUIRE les images et DIRE ce qu'il a produit.

  python3 docs/site/scripts/captures.py            # écrit public/captures/ + content/captures.json
  python3 docs/site/scripts/captures.py --dry-run  # mesure seulement, n'écrit rien

Le manifeste est en tête de fichier (FLOW, HERO). Une source, dans l'ordre :
tools/docsite/shots/<nom>.png (la capture faite POUR le site), sinon la capture connue
du dépôt, sinon rien — l'écran est listé `fichier: null` et le site montre « à capturer ».

Sorties (sips pour tout ; PIL seulement si sips refuse un recadrage) :
  public/captures/flow/<nom>.jpg    300 px de large, JPEG q78  — le bandeau du flow
  public/captures/hero/<page>.jpg   480 px de large, JPEG q72  — 2× pour les 240 px CSS du hero
  public/captures/hero/forge.png    480 px, PNG                — le sachet garde son alpha
  content/captures.json
      { flow: [{nom, legende, fichier, largeur, hauteur, source, octets}],
        hero: {page: {fichier, largeur, hauteur, source, octets}} }
  `fichier` est relatif à public/ (« captures/flow/home.jpg ») ; `largeur`/`hauteur`
  sont LUES sur le fichier produit (sips -g), jamais calculées ; tout est null si absent.

Refus (exit 1) : un JPEG > 70 Ko, ou plus de 900 Ko en tout — un site de 5 Mo n'est
plus un site. Deux passes donnent les mêmes octets (sips n'écrit aucune date) : le
livrable reste diffable.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

# ── le manifeste ───────────────────────────────────────────────────────────────

LARGEUR_FLOW, QUALITE_FLOW = 300, 78
LARGEUR_HERO, QUALITE_HERO = 480, 72
MAX_JPEG, MAX_TOTAL = 70_000, 900_000
RATIO_ECRAN = (1206, 2622)          # le format des captures du téléphone (largeur, hauteur)

# (nom, légende, capture de repli connue dans le dépôt ou None) — dans l'ordre du flow
FLOW = [
    ('porte',      'La porte',   None),
    ('home',       'Home',       'tools/road/shots/j4-home-serpentin.png'),
    ('chemin',     'Le chemin',  'tools/road/shots/road-2-etats-etape5.png'),
    ('depart',     'Départ',     'tools/road/shots/road-1-branchee.png'),
    ('player',     'Player',     None),
    ('exo',        'Page exo',   None),
    ('stop',       'Stop',       'tools/stop/captures/stop-134059.png'),
    ('bravo',      'Bravo',      None),
    ('story',      'Story',      None),
    ('coffre',     'Le coffre',  None),
    ('booster',    'Booster',    None),
    ('calendrier', 'Calendrier', None),
    ('profil',     'Profil',     None),
]

# (page, source, geste)
#   source : '@<nom>' = la même capture que l'écran <nom> du flow (avec sa priorité
#            tools/docsite/shots), un chemin depuis la racine du dépôt, ou None = hero noir
#   geste  : 'jpeg' · 'png' (garde l'alpha) · 'jpeg+recadre' (centre au format écran, puis réduit)
HERO = [
    ('flow',     '@home',                                                                    'jpeg'),
    ('regles',   'tools/coffre-v2/ARCHIVE/coffre-v1.jpg',                                    'jpeg'),
    ('forge',    'Woop/Assets.xcassets/booster-orange.imageset/booster-orange.png',          'png'),           # l'objet flotte dans sa couleur
    ('histoire', None,                                                                       'jpeg'),          # aucune capture : hero noir
    ('porte',    'Woop/Assets.xcassets/onb-lune-loop-poster.imageset/onb-lune-loop-poster.jpg', 'jpeg+recadre'),  # 1080×1644 → le centre au format écran
]

# ── les chemins ────────────────────────────────────────────────────────────────

def racine():
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, 'Woop.xcodeproj')):
            return d
        d = os.path.dirname(d)
    sys.exit('✗ racine du dépôt introuvable (pas de Woop.xcodeproj au-dessus de %s)' % __file__)

RACINE = racine()
SITE = os.path.join(RACINE, 'docs', 'site')
PUBLIC = os.path.join(SITE, 'public', 'captures')
MANIFESTE = os.path.join(SITE, 'content', 'captures.json')
SHOTS = os.path.join(RACINE, 'tools', 'docsite', 'shots')

# ── sips ───────────────────────────────────────────────────────────────────────

def sips(*args):
    """sips rend parfois 0 en imprimant « Error: … » : on lit les deux."""
    r = subprocess.run(['sips', *args], capture_output=True, text=True)
    if r.returncode != 0 or 'Error' in r.stdout or 'Error' in r.stderr:
        raise RuntimeError('sips %s\n%s%s' % (' '.join(args), r.stdout, r.stderr))
    return r.stdout

def dims(chemin):
    """Les dimensions RÉELLES du fichier, lues par sips -g."""
    s = sips('-g', 'pixelWidth', '-g', 'pixelHeight', chemin)
    m = {k: int(v) for k, v in re.findall(r'(pixelWidth|pixelHeight): (\d+)', s)}
    return m['pixelWidth'], m['pixelHeight']

def a_alpha(chemin):
    return 'hasAlpha: yes' in sips('-g', 'hasAlpha', chemin)

def reduire(src, out, largeur, fmt, qualite=None):
    """Réduit à `largeur` px de large ; JPEG à `qualite`, ou PNG (l'alpha est gardé)."""
    args = ['-s', 'format', fmt]
    if fmt == 'jpeg':
        args += ['-s', 'formatOptions', str(qualite)]
    sips(*args, '--resampleWidth', str(largeur), src, '--out', out)
    l, h = dims(out)
    if l != largeur:
        raise RuntimeError('%s fait %d px de large au lieu de %d' % (os.path.basename(out), l, largeur))
    if fmt == 'png' and a_alpha(src) and not a_alpha(out):
        raise RuntimeError('%s a perdu son alpha' % os.path.basename(out))
    return l, h

def recadrer(src, out, ratio):
    """Recadre au CENTRE au format `ratio` (l, h), en PNG — sans perte, on réduit après.
    sips d'abord ; si le recadrage ne s'applique pas (il s'est montré capricieux), PIL."""
    L, H = dims(src)
    rl, rh = ratio
    if L * rh > H * rl:                       # trop large : on coupe les côtés
        l, h = round(H * rl / rh), H
    else:                                     # trop haut : on coupe haut et bas
        l, h = L, round(L * rh / rl)
    x, y = (L - l) // 2, (H - h) // 2
    try:
        sips('-s', 'format', 'png', '--cropToHeightWidth', str(h), str(l),
             '--cropOffset', str(y), str(x), src, '--out', out)
        ok = dims(out) == (l, h)
    except RuntimeError:
        ok = False
    if not ok:
        print('  ⚠ sips n\'a pas recadré %s — PIL prend le relais' % os.path.basename(src))
        from PIL import Image
        Image.open(src).crop((x, y, x + l, y + h)).save(out, 'PNG')
        if dims(out) != (l, h):
            raise RuntimeError('recadrage impossible : %s' % src)
    return l, h, x, y

# ── les sources ────────────────────────────────────────────────────────────────

def source_flow(nom, repli):
    for ext in ('png', 'jpg', 'jpeg'):
        a = os.path.join(SHOTS, '%s.%s' % (nom, ext))
        if os.path.exists(a):
            return a
    if repli and os.path.exists(os.path.join(RACINE, repli)):
        return os.path.join(RACINE, repli)
    return None

def source_hero(source):
    if source is None:
        return None
    if source.startswith('@'):
        nom = source[1:]
        repli = dict((n, r) for n, _, r in FLOW).get(nom)
        return source_flow(nom, repli)
    a = os.path.join(RACINE, source)
    return a if os.path.exists(a) else None

# ── la production ──────────────────────────────────────────────────────────────

def n(o):
    return '{:,}'.format(o).replace(',', ' ')

def rel(chemin):
    return os.path.relpath(chemin, RACINE) if chemin else None

def vide(**champs):
    return dict(champs, fichier=None, largeur=None, hauteur=None, source=None, octets=0)

def produire(atelier):
    """Produit tout dans `atelier` ; rend (manifeste, [(chemin dans l'atelier, chemin public)], erreurs)."""
    manifeste = {'flow': [], 'hero': {}}
    fichiers, erreurs, total = [], [], 0

    print('── flow (%d px · JPEG q%d · ≤ %s o chacune)' % (LARGEUR_FLOW, QUALITE_FLOW, n(MAX_JPEG)))
    for nom, legende, repli in FLOW:
        src = source_flow(nom, repli)
        if not src:
            manifeste['flow'].append(vide(nom=nom, legende=legende))
            print('  ○ %-11s %20s' % (nom, 'à capturer'))
            continue
        out = os.path.join(atelier, 'flow', nom + '.jpg')
        l, h = reduire(src, out, LARGEUR_FLOW, 'jpeg', QUALITE_FLOW)
        o = os.path.getsize(out)
        total += o
        if o > MAX_JPEG:
            erreurs.append('flow/%s.jpg : %s o > %s' % (nom, n(o), n(MAX_JPEG)))
        manifeste['flow'].append({'nom': nom, 'legende': legende, 'fichier': 'captures/flow/%s.jpg' % nom,
                                  'largeur': l, 'hauteur': h, 'source': rel(src), 'octets': o})
        fichiers.append((out, os.path.join(PUBLIC, 'flow', nom + '.jpg')))
        print('  ● %-11s %9s o  %4d×%-5d ← %s' % (nom, n(o), l, h, rel(src)))

    print('── hero (%d px · JPEG q%d, ou PNG alpha)' % (LARGEUR_HERO, QUALITE_HERO))
    for page, source, geste in HERO:
        src = source_hero(source)
        if not src:
            manifeste['hero'][page] = vide()
            print('  ○ %-11s %20s' % (page, 'hero noir' if source is None else 'source absente : ' + source))
            continue
        detail = ''
        if geste == 'jpeg+recadre':
            coupe = os.path.join(atelier, 'hero', page + '-coupe.png')
            l, h, x, y = recadrer(src, coupe, RATIO_ECRAN)
            detail = '  (recadré %d×%d à x=%d, y=%d)' % (l, h, x, y)
            src_reduit = coupe
        else:
            src_reduit = src
        ext = 'png' if geste == 'png' else 'jpg'
        out = os.path.join(atelier, 'hero', '%s.%s' % (page, ext))
        l, h = reduire(src_reduit, out, LARGEUR_HERO, 'png' if ext == 'png' else 'jpeg', QUALITE_HERO)
        o = os.path.getsize(out)
        total += o
        if ext == 'jpg' and o > MAX_JPEG:
            erreurs.append('hero/%s.jpg : %s o > %s' % (page, n(o), n(MAX_JPEG)))
        manifeste['hero'][page] = {'fichier': 'captures/hero/%s.%s' % (page, ext), 'largeur': l, 'hauteur': h,
                                   'source': rel(src), 'octets': o}
        fichiers.append((out, os.path.join(PUBLIC, 'hero', '%s.%s' % (page, ext))))
        print('  ● %-11s %9s o  %4d×%-5d ← %s%s' % (page, n(o), l, h, rel(src), detail))

    print('── total %s o (≤ %s) · en base64 ≈ %s o' % (n(total), n(MAX_TOTAL), n(total * 4 // 3)))
    if total > MAX_TOTAL:
        erreurs.append('total %s o > %s' % (n(total), n(MAX_TOTAL)))
    return manifeste, fichiers, erreurs

def ecrire(manifeste, fichiers):
    attendus = set(dest for _, dest in fichiers)
    for sous in ('flow', 'hero'):
        d = os.path.join(PUBLIC, sous)
        os.makedirs(d, exist_ok=True)
        for f in sorted(os.listdir(d)):              # un orphelin = une capture que le manifeste ne connaît plus
            p = os.path.join(d, f)
            if os.path.isfile(p) and p not in attendus:
                os.unlink(p)
                print('  – orphelin retiré : %s' % rel(p))
    for src, dest in fichiers:
        shutil.copyfile(src, dest)
    os.makedirs(os.path.dirname(MANIFESTE), exist_ok=True)
    with open(MANIFESTE, 'w', encoding='utf-8') as f:
        json.dump(manifeste, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print('→ %d fichiers dans %s · %s' % (len(fichiers), rel(PUBLIC), rel(MANIFESTE)))

def main():
    if '-h' in sys.argv or '--help' in sys.argv:
        print(__doc__.strip())
        return
    dry = '--dry-run' in sys.argv
    if not shutil.which('sips'):
        sys.exit('✗ sips introuvable (macOS seulement)')
    atelier = tempfile.mkdtemp(prefix='captures-')
    try:
        os.makedirs(os.path.join(atelier, 'flow'))
        os.makedirs(os.path.join(atelier, 'hero'))
        try:
            manifeste, fichiers, erreurs = produire(atelier)
        except RuntimeError as e:
            sys.exit('✗ %s' % e)
        if erreurs:
            for e in erreurs:
                print('✗ %s' % e)
            print('  → baisse la qualité ou change la source ; rien n\'est écrit')
            sys.exit(1)
        if dry:
            print('dry-run : rien n\'est écrit')
            return
        ecrire(manifeste, fichiers)
    finally:
        shutil.rmtree(atelier, ignore_errors=True)

if __name__ == '__main__':
    main()
