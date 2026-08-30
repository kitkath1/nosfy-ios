#!/usr/bin/env python3
"""
Embarque les captures du flow dans docs/site/index.html, entre les marqueurs
<!-- flow:début --> et <!-- flow:fin -->, en data URI (le site est UN fichier).

  python3 tools/docsite/embarquer.py            # écrit
  python3 tools/docsite/embarquer.py --dry-run  # mesure sans écrire

Sources, dans l'ordre du flow : tools/docsite/shots/<nom>.png d'abord (les captures
faites pour le site), sinon la capture connue du dépôt, sinon une case vide « à
capturer ». Chaque image : 300 px de large, JPEG q78 — ≤ 60 Ko, ≤ 700 Ko au total,
sinon on REFUSE (exit 1) : un site de 5 Mo n'est plus un site.
"""
import base64, os, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = os.path.join(RACINE, 'docs/site/index.html')
SHOTS = os.path.join(RACINE, 'tools/docsite/shots')
LARGEUR, QUALITE = 300, 78
MAX_IMAGE, MAX_TOTAL = 60_000, 700_000

# (nom, légende, capture de repli connue dans le dépôt ou None)
FLOW = [
    ('porte',      'La porte',      None),
    ('home',       'Home',          'tools/road/shots/j4-home-serpentin.png'),
    ('chemin',     'Le chemin',     'tools/road/shots/road-2-etats-etape5.png'),
    ('depart',     'Départ',        'tools/road/shots/road-1-branchee.png'),
    ('player',     'Player',        None),
    ('exo',        'Page exo',      None),
    ('stop',       'Stop',          'tools/stop/captures/stop-134059.png'),
    ('bravo',      'Bravo',         None),
    ('story',      'Story',         None),
    ('coffre',     'Le coffre',     None),
    ('booster',    'Booster',       None),
    ('calendrier', 'Calendrier',    None),
    ('profil',     'Profil',        None),
]

def source(nom, repli):
    a = os.path.join(SHOTS, nom + '.png')
    if os.path.exists(a): return a
    if repli and os.path.exists(os.path.join(RACINE, repli)): return os.path.join(RACINE, repli)
    return None

def jpeg(chemin):
    with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as t: sortie = t.name
    subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', str(QUALITE),
                    '--resampleWidth', str(LARGEUR), chemin, '--out', sortie],
                   check=True, capture_output=True)
    data = open(sortie, 'rb').read(); os.unlink(sortie)
    return data

def main():
    dry = '--dry-run' in sys.argv
    figures, total = [], 0
    for nom, legende, repli in FLOW:
        src = source(nom, repli)
        if not src:
            figures.append('<figure class="ecran vide" data-ecran="%s"><img alt="" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"><figcaption>%s · à capturer</figcaption></figure>' % (nom, legende))
            print('  ○ %-11s à capturer' % nom); continue
        data = jpeg(src)
        if len(data) > MAX_IMAGE:
            print('✗ %s : %d o > %d — baisse QUALITE' % (nom, len(data), MAX_IMAGE)); sys.exit(1)
        total += len(data)
        b64 = base64.b64encode(data).decode('ascii')
        figures.append('<figure class="ecran" data-ecran="%s"><img decoding="async" loading="lazy" alt="%s" src="data:image/jpeg;base64,%s"><figcaption>%s</figcaption></figure>' % (nom, legende, b64, legende))
        print('  ● %-11s %6d o  ← %s' % (nom, len(data), os.path.relpath(src, RACINE)))
    if total > MAX_TOTAL:
        print('✗ total %d o > %d' % (total, MAX_TOTAL)); sys.exit(1)
    print('total %d o (%d en base64)' % (total, total * 4 // 3))
    if dry: return
    s = open(SITE, encoding='utf-8').read()
    a, b = s.index('<!-- flow:début -->'), s.index('<!-- flow:fin -->')
    s = s[:a] + '<!-- flow:début -->\n' + '\n'.join(figures) + '\n' + s[b:]
    open(SITE, 'w', encoding='utf-8').write(s)
    print('écrit dans docs/site/index.html (%d o)' % len(s.encode('utf-8')))

if __name__ == '__main__':
    main()
