#!/usr/bin/env python3
"""
LA MIGRATION, UNE FOIS : lit le livrable v1 (docs/site/index.html, commit 6fbd13f) et
en tire la SOURCE TYPÉE de la v2 :

  docs/site/content/serveur.ts   la carte du serveur (tables, fonctions, règles, edge) — 52 pastilles
  docs/site/content/briques.ts   les briques des autres pages — 62 pastilles
  docs/site/content/mesures.ts   les 22 rangées « à mesurer » de l'accueil (sans état)
  tools/docsite/migration/RAPPORT.md   ce qui a été fait, et ce qu'il faut relire à la main

Règle : UNE pastille de la v1 = UN enregistrement (114 = 114, vérifié à la fin). Aucun
état n'est changé, aucun n'est inventé : l'état vient de la classe p-*, la preuve vient
du texte (fichier:ligne), de la rangée d'accueil qui pointe la pastille (data-src), d'une
table de preuves connues (les migrations qui créent chaque objet), ou reste « à citer ».
"""
import html, json, os, re, subprocess, sys, unicodedata
from html.parser import HTMLParser

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(RACINE, 'docs/site/index.html')
OUT = os.path.join(RACINE, 'docs/site/content')
RAPPORT = os.path.join(RACINE, 'tools/docsite/migration/RAPPORT.md')

PAGE_V2 = {'six': 'serveur', 'carte': 'serveur', 'schema': 'serveur', 'diag': 'serveur', 'flow': 'flow',
           'regles': 'regles', 'forge': 'forge', 'histoire': 'histoire', 'porte': 'porte', 'manege': 'forge'}
COUT = {'⏱️': '1 h', '⏳': '1 j', '🧗': 'chantier'}
EMOJI = re.compile('[\U0001F000-\U0001FAFF☀-➿⬀-⯿️]')

# Les preuves connues de la carte du serveur (lues dans les migrations et les services —
# ANNEXE-TODO-BACKEND.md §1-3). Une ligne sans entrée ici reste « à citer ».
PREUVES = {
    'coin_ledger': ('supabase/migrations/20260828120000_booster_noir.sql', None),
    'user_boosters': ('supabase/migrations/20260828120000_booster_noir.sql', None),
    'reward_rules': ('supabase/migrations/20260828160000_wallet_coffre.sql', None),
    'workouts': ('Woop/Services/SupabaseSync.swift', '113-116'),
    'logged_exercises': ('Woop/Services/SupabaseSync.swift', '113-116'),
    'strength_sets': ('Woop/Services/SupabaseSync.swift', '113-116'),
    'cardio_phases': ('supabase/migrations/20260729120000_woop_schema.sql', None),
    'cards': ('supabase/migrations/20260814180000_cartes_lune.sql', None),
    'user_cards': ('supabase/migrations/20260814180000_cartes_lune.sql', None),
    'syntheses': ('supabase/migrations/0001_init.sql', '77'),
    'booster_progress': ('supabase/migrations/20260828160000_wallet_coffre.sql', '50'),
    'cloturer_seance': ('Woop/Services/SacreServeur.swift', '185'),
    'etat_coffre': ('Woop/Services/SacreServeur.swift', '77'),
    'historique_gains': ('Woop/Services/SacreServeur.swift', '351'),
    'claim_booster': ('Woop/Services/SacreServeur.swift', '297'),
    'ouvrir_booster': ('Woop/Services/SacreServeur.swift', '329'),
    'claim_retour_quotidien': ('Woop/Services/SacreServeur.swift', '143'),
    'reclamer_noeud_chemin': ('Woop/Services/SacreServeur.swift', '278'),
    'noeuds_chemin_reclames': ('Woop/Services/SacreServeur.swift', '380'),
    'poser_faits_seance': ('supabase/migrations/20260830100000_moteur_faits.sql', None),
    'roll_rare': ('supabase/migrations/20260829130000_roll_rare_prive.sql', None),
    'solde_or': ('supabase/migrations/20260828190000_gains_coffre.sql', '25'),
    'regles_annonces': ('supabase/migrations/20260829120000_annonces.sql', '174'),
    'solde_argent': ('Woop/Services/SacreServeur.swift', '99'),
    'claim_booster_legendaire': ('Woop/Services/SacreServeur.swift', '109'),
    'solde_noir': ('supabase/migrations/20260828120000_booster_noir.sql', '191'),
    'forge-card': ('Woop/Services/ForgeServeur.swift', '45'),
    'weekly-synthesis': ('Woop/Services/SynthesisService.swift', '109'),
}
REGLES_PREUVE = {
    'pieces_par_serie': ('supabase/migrations/20260828160000_wallet_coffre.sql', None),
    'prix_booster': ('supabase/migrations/20260828160000_wallet_coffre.sql', None),
    'prix_booster_legendaire': ('supabase/migrations/20260828120000_booster_noir.sql', None),
    'pieces_retour_quotidien': ('supabase/migrations/20260828190000_gains_coffre.sql', None),
    'welcome_absence_jours': ('supabase/migrations/20260830090000_welcome_chaque_connexion.sql', '37-44'),
    'welcome_cooldown_jours': ('supabase/migrations/20260830090000_welcome_chaque_connexion.sql', '37-44'),
    'welcome_max_mois': ('supabase/migrations/20260830090000_welcome_chaque_connexion.sql', '37-44'),
    'top_mesures_muscu': ('supabase/migrations/20260830100000_moteur_faits.sql', None),
    'top_mesures_cardio': ('supabase/migrations/20260830100000_moteur_faits.sql', None),
    'top_fenetre_jours': ('supabase/migrations/20260830100000_moteur_faits.sql', None),
    'top_min_seances': ('supabase/migrations/20260830100000_moteur_faits.sql', None),
    'rare_* (3 clés)': ('supabase/migrations/20260829120000_annonces.sql', '179'),
}
# les 17 clés de rythme viennent de la même migration
for k in ['popups_max_seance', 'reward_monetaire_max_seance', 'video_max_seance', 'notifs_max_seance', 'notif_consomme_budget',
          'ecart_min_series', 'ecart_min_minutes', 'ecart_exige_les_deux', 'bonus_fort / progres / surprise', 'bonus_plafond_seance',
          'meme_fait_max_seance / semaine', 'annonce_une_par_evenement']:
    REGLES_PREUVE[k] = ('supabase/migrations/20260829120000_annonces.sql', '98-151')


# ── un petit DOM ──────────────────────────────────────────────────────────────
class N:
    __slots__ = ('tag', 'attrs', 'children', 'parent', 'text')
    def __init__(self, tag, attrs=None, parent=None):
        self.tag, self.attrs, self.parent, self.children, self.text = tag, dict(attrs or {}), parent, [], None
    def get(self, k, d=None): return self.attrs.get(k, d)
    def cls(self): return (self.attrs.get('class') or '').split()
    def texte(self):
        if self.tag == '#text': return self.text
        return ''.join(c.texte() for c in self.children)
    def walk(self):
        yield self
        for c in self.children: yield from c.walk()
    def find_all(self, pred): return [n for n in self.walk() if n.tag != '#text' and pred(n)]
    def find(self, pred):
        for n in self.walk():
            if n.tag != '#text' and pred(n): return n
    def ancestor(self, pred):
        p = self.parent
        while p is not None:
            if pred(p): return p
            p = p.parent
    def html(self):
        if self.tag == '#text': return html.escape(self.text, quote=False)
        a = ''.join(' %s="%s"' % (k, html.escape(v, quote=True)) for k, v in self.attrs.items())
        inner = ''.join(c.html() for c in self.children)
        if self.tag in VIDE: return '<%s%s>' % (self.tag, a)
        return '<%s%s>%s</%s>' % (self.tag, a, inner, self.tag)

VIDE = {'br', 'img', 'meta', 'link', 'hr', 'input', 'use', 'path', 'stop', 'circle', 'rect', 'line', 'ellipse'}

class P(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = N('#root'); self.cur = self.root
    def handle_starttag(self, tag, attrs):
        n = N(tag, attrs, self.cur); self.cur.children.append(n)
        if tag not in VIDE: self.cur = n
    def handle_startendtag(self, tag, attrs):
        self.cur.children.append(N(tag, attrs, self.cur))
    def handle_endtag(self, tag):
        c = self.cur
        while c is not None and c.tag != tag: c = c.parent
        if c is not None and c.parent is not None: self.cur = c.parent
    def handle_data(self, data):
        t = N('#text', parent=self.cur); t.text = data; self.cur.children.append(t)


# ── utilitaires ───────────────────────────────────────────────────────────────
def slug(t, n=5):
    t = EMOJI.sub('', t); t = unicodedata.normalize('NFKD', t).encode('ascii', 'ignore').decode()
    t = re.sub(r'[^a-zA-Z0-9]+', '-', t).strip('-').lower()
    return '-'.join([p for p in t.split('-') if p][:n])

def propre(t, n=None):
    t = EMOJI.sub('', t or ''); t = re.sub(r'\s+', ' ', t).strip(' .—:·')
    t = t.replace('« ', '« ').replace(' »', ' »')
    if n and len(t) > n:
        t = t[:n - 1].rsplit(' ', 1)[0] + '…'
    return t

def texte_avec_code(n):
    """Le texte d'un nœud, les <code> entre accents graves (le composant les rendra en mono)."""
    if n.tag == '#text': return n.text
    if n.tag == 'code': return '`' + n.texte() + '`'
    if n.tag in ('span',) and 'p' in n.cls(): return ''
    return ''.join(texte_avec_code(c) for c in n.children)

INDEX_FICHIERS = None
def resoudre(basename):
    global INDEX_FICHIERS
    if INDEX_FICHIERS is None:
        out = subprocess.run(['git', 'ls-files'], cwd=RACINE, capture_output=True, text=True).stdout.split('\n')
        out += subprocess.run(['git', 'ls-files', '--others', '--exclude-standard'], cwd=RACINE, capture_output=True, text=True).stdout.split('\n')
        INDEX_FICHIERS = {}
        for f in out:
            if f: INDEX_FICHIERS.setdefault(os.path.basename(f), []).append(f)
    c = INDEX_FICHIERS.get(basename, [])
    if c: return c[0]
    # la v1 abrège les migrations (« annonces.sql » pour 20260829120000_annonces.sql) : suffixe
    cands = [f for b, fs in INDEX_FICHIERS.items() if b.endswith('_' + basename) or b.endswith(basename) for f in fs]
    cands = [f for f in cands if '/migrations/' in f or f.endswith(basename)]
    return cands[0] if len(cands) == 1 else (cands[0] if cands else None)

PREUVE_RE = re.compile(r'([\w./-]+\.(?:swift|sql|md|sh|metal|py|mjs|ts)):(\d+(?:-\d+)?)')
def preuve_depuis(texte):
    """Une preuve lisible dans un texte : fichier:ligne (résolu), sonde, git — sinon None."""
    t = texte or ''
    m = PREUVE_RE.search(t)
    if m:
        f, l = m.group(1), m.group(2)
        chemin = f if os.path.exists(os.path.join(RACINE, f)) else resoudre(os.path.basename(f))
        if chemin: return {'fichier': chemin, 'lignes': l}
        return {'fichier': f, 'lignes': l, '_nonresolu': True}
    if 'sonde' in t.lower():
        m2 = re.search(r'sonde\s+(\d{3})\s*(\[\]|[^·]*)', t)
        if m2: return {'sonde': 'RPC noeuds_chemin_reclames', 'reponse': (m2.group(1) + ' ' + m2.group(2)).strip()}
    if t.strip().startswith('git status'): return {'git': 'status : migrations non suivies (??)'}
    if 'aucun .entitlements' in t: return {'git': 'ls : aucun fichier .entitlements dans le dépôt'}
    return None

def ts_str(s): return json.dumps(s, ensure_ascii=False)

def ts_obj(d, indent=2):
    parts = []
    for k, v in d.items():
        if v is None or v is False: continue
        if isinstance(v, bool): parts.append('%s: %s' % (k, 'true'))
        elif isinstance(v, (int, float)): parts.append('%s: %s' % (k, v))
        elif isinstance(v, dict): parts.append('%s: { %s }' % (k, ', '.join('%s: %s' % (a, 'true' if b is True else ts_str(b)) for a, b in v.items() if not a.startswith('_'))))
        else: parts.append('%s: %s' % (k, ts_str(v)))
    return '  { ' + ', '.join(parts) + ' },'


# ── la lecture ────────────────────────────────────────────────────────────────
def main():
    s = open(SRC, encoding='utf-8').read()
    p = P(); p.feed(s); root = p.root
    sections = {n.get('id'): n for n in root.find_all(lambda n: n.tag == 'section' and 'page' in n.cls())}

    # les rangées de l'accueil : data-src → (titre, preuve, cout, litige)
    rangees = {}; mesures = []
    etat = sections['etat']
    for li in etat.find_all(lambda n: n.tag == 'li' and 'r' in n.cls()):
        t = li.find(lambda n: n.tag == 'span' and 't' in n.cls())
        code = [c for c in li.find_all(lambda n: n.tag == 'code') if c.parent and 'm' in c.parent.cls()]
        c = li.find(lambda n: n.tag == 'span' and 'c' in n.cls())
        titre = propre(texte_avec_code(t), 60)
        preuve_txt = code[-1].texte() if code else ''
        cout = (c.texte().strip() if c else None); cout = cout if cout in ('1 h', '1 j', 'chantier') else None
        rec = {'titre': titre, 'preuve_txt': preuve_txt, 'cout': cout, 'litige': li.get('data-litige') == '1',
               'onglet': li.get('data-onglet'), 'dom': li.get('data-dom')}
        if li.get('data-src'): rangees[li.get('data-src')] = rec
        else: mesures.append(rec)

    serveur, briques, rapport = [], [], {'ids_generes': [], 'aciter': [], 'nonresolu': [], 'tronques': [], 'sans_dom': []}
    vus = set()
    comptes = {}

    for sid, sec in sections.items():
        if sid == 'etat': continue
        for sp in sec.find_all(lambda n: n.tag == 'span' and 'p' in n.cls() and any(c in ('p-ok', 'p-loc', 'p-srv', 'p-abs', 'p-men') for c in n.cls())):
            et = [c for c in sp.cls() if c.startswith('p-') and c != 'p-cx'][0][2:]
            comptes.setdefault(sid, {}).setdefault(et, 0); comptes[sid][et] += 1
            hote = sp.ancestor(lambda n: n.tag in ('tr', 'li', 'summary') or (n.tag == 'p') or (n.tag == 'div' and 'bloc' in n.cls()) or n.tag == 'h3')
            if hote is None: hote = sp.parent
            dom_n = sp.ancestor(lambda n: n.get('data-dom'))
            dom = dom_n.get('data-dom') if dom_n else None
            hid = hote.get('id') if hote is not None else None
            if not hid and hote is not None and hote.tag == 'p':
                # la pastille dans un <p> d'un bloc qui porte l'id
                b = hote.ancestor(lambda n: n.get('id'))
                if b is not None and b.get('id', '').startswith('b-'): hid = b.get('id')
            page = PAGE_V2[sid]
            # coût frère
            cout = None
            for cx in hote.find_all(lambda n: n.tag == 'span' and 'p-cx' in n.cls()) if hote is not None else []:
                e = cx.texte().strip()[:2]
                for k, v in COUT.items():
                    if cx.texte().strip().startswith(k): cout = v
            # pastille dans une table de la carte / du dictionnaire ?
            tds = [c for c in hote.children if c.tag == 'td'] if hote is not None and hote.tag == 'tr' else []
            ths = []
            table = hote.ancestor(lambda n: n.tag == 'table') if hote is not None else None
            if table is not None:
                ths = [propre(t.texte()) for t in table.find_all(lambda n: n.tag == 'th')]
            libelle_pastille = propre(sp.texte())
            note = ''
            rec = {'etat': et, 'page': page, 'domaine': dom, 'cout': cout}
            genre = None; nom = None; quoi = None; valeur = None
            if sid == 'carte' and tds and ths:
                nom = propre(tds[0].texte())
                if ths[0] == 'Table': genre = 'table'; quoi = propre(texte_avec_code(tds[1]), 220)
                elif ths[0] == 'Fonction' and 'Appelée' in ' '.join(ths): genre = 'fonction'; quoi = propre(texte_avec_code(tds[1]), 220)
                elif ths[0] == 'Fonction': genre = 'edge'; quoi = propre(texte_avec_code(tds[1]), 220)
                elif ths[0] == 'Clé': genre = 'regle'; valeur = propre(tds[1].texte()); quoi = propre(texte_avec_code(tds[2]), 160)
                titre = nom if genre != 'regle' else nom
                if libelle_pastille and len(libelle_pastille) > 2: note = libelle_pastille   # « oui », « interne », « non », « jaune »…
            elif sid == 'schema' and hote is not None and hote.tag == 'summary':
                nom = propre(hote.find(lambda n: n.tag == 'b').texte()) if hote.find(lambda n: n.tag == 'b') else ''
                titre = propre(texte_avec_code(hote), 60); genre = 'table'; quoi = 'dictionnaire'
            elif sid == 'schema' and tds:
                nom = propre(tds[0].texte()); genre = 'table'; quoi = propre(texte_avec_code(tds[2]), 200); titre = nom
            elif sid == 'diag' and tds:
                titre = propre(tds[0].texte(), 60); note = propre(texte_avec_code(tds[1]), 160)
            elif tds:
                titre = propre(texte_avec_code(tds[0]), 60)
                note = propre(' — '.join(propre(texte_avec_code(t)) for t in tds[1:] if propre(texte_avec_code(t))), 200)
            else:
                titre = propre(texte_avec_code(hote), 60) if hote is not None else libelle_pastille
                note = propre(texte_avec_code(hote), 220) if hote is not None else ''
            # la rangée d'accueil qui pointe cette pastille : ses titre/preuve/cout/litige priment
            r = rangees.get(hid) if hid else None
            preuve = None; litige = None
            if r:
                titre = r['titre'] or titre
                cout = r['cout'] or cout
                preuve = preuve_depuis(r['preuve_txt'])
                if r['litige']: litige = 'le site et le code se contredisent — à mesurer (voir la note)'
            if preuve is None and hote is not None:
                preuve = preuve_depuis(hote.texte())
            if preuve is None and nom:
                src = PREUVES.get(nom) or REGLES_PREUVE.get(nom)
                if src: preuve = {'fichier': src[0], 'lignes': src[1]} if src[1] else {'fichier': src[0]}
            if preuve is None: preuve = {'aCiter': True}
            # l'id
            if not hid:
                base = {'carte': 'b-' + {'table': 'tb', 'fonction': 'fn', 'regle': 'rg', 'edge': 'ed'}.get(genre or '', 'ca') + '-',
                        'schema': 'b-sc-', 'diag': 'b-dg-', 'six': 'b-six-', 'flow': 'b-fl-', 'regles': 'b-rg-', 'forge': 'b-fo-',
                        'histoire': 'b-st-', 'porte': 'b-po-', 'manege': 'b-mn-'}[sid]
                hid = base + (slug(nom) if nom else slug(titre))
                rapport['ids_generes'].append(hid)
            oid = hid; k = 2
            while hid in vus: hid = '%s-%d' % (oid, k); k += 1
            vus.add(hid)
            if len(titre) > 60: rapport['tronques'].append(hid); titre = propre(titre, 60)
            if 'aCiter' in preuve: rapport['aciter'].append(hid)
            if preuve.get('_nonresolu'): rapport['nonresolu'].append('%s → %s' % (hid, preuve['fichier'])); preuve.pop('_nonresolu')
            if not dom: rapport['sans_dom'].append(hid)
            rec.update({'id': hid, 'titre': titre, 'preuve': preuve})
            if genre: rec.update({'genre': genre, 'nom': nom, 'quoi': quoi, 'valeur': valeur})
            if note and note != titre: rec['note'] = note
            if litige: rec['litige'] = litige
            (serveur if sid in ('carte',) else briques).append(rec)

    # ── écriture ──────────────────────────────────────────────────────────────
    def ordonne(r):
        cle = ['id', 'genre', 'nom', 'titre', 'page', 'domaine', 'etat', 'cout', 'valeur', 'quoi', 'note', 'litige', 'preuve']
        return {k: r.get(k) for k in cle if r.get(k) not in (None, '', False)}

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'serveur.ts'), 'w', encoding='utf-8') as f:
        f.write("import type { Brique } from './types'\n\n/**\n * LA CARTE DU SERVEUR — tables, fonctions, règles, edge functions. Générée UNE fois par\n * tools/docsite/migrer.py depuis la v1, puis tenue À LA MAIN : changer un état ici, c'est\n * le changer partout. Chaque ligne a sa preuve ; « aCiter » est une dette visible.\n */\nexport const SERVEUR: Brique[] = [\n")
        for r in serveur: f.write(ts_obj(ordonne(r)) + '\n')
        f.write(']\n')
    with open(os.path.join(OUT, 'briques.ts'), 'w', encoding='utf-8') as f:
        f.write("import type { Brique } from './types'\n\n/**\n * LES BRIQUES des pages de domaine (et du dictionnaire / des sondes du Serveur). Générées\n * UNE fois par tools/docsite/migrer.py depuis la v1, puis tenues À LA MAIN. Un état ne se\n * déduit pas : il se lit (fichier:ligne) ou se mesure (sonde) — voir la preuve.\n */\nexport const BRIQUES: Brique[] = [\n")
        for r in briques: f.write(ts_obj(ordonne(r)) + '\n')
        f.write(']\n')
    with open(os.path.join(OUT, 'mesures.ts'), 'w', encoding='utf-8') as f:
        f.write("import type { Mesure } from './types'\n\n/**\n * « À MESURER » — ce que le code laisse lire, JAMAIS peint. Une ligne ici devient une\n * brique le jour où on a LU la réponse (une mesure par ligne, commit à part).\n */\nexport const MESURES: Mesure[] = [\n")
        for i, m in enumerate(mesures):
            pv = preuve_depuis(m['preuve_txt']) or {'aCiter': True}
            pv.pop('_nonresolu', None)
            rec = {'id': 'm-' + slug(m['titre'], 4), 'titre': m['titre'], 'page': PAGE_V2.get(m['onglet'], m['onglet']), 'domaine': m['dom'],
                   'lecture': 'inconnu', 'cout': m['cout'], 'preuve': pv}
            f.write(ts_obj({k: v for k, v in rec.items() if v}) + '\n')
        f.write(']\n')

    # ── le rapport ────────────────────────────────────────────────────────────
    tot = {}
    for sid, c in comptes.items():
        for et, n in c.items(): tot[et] = tot.get(et, 0) + n
    os.makedirs(os.path.dirname(RAPPORT), exist_ok=True)
    with open(RAPPORT, 'w', encoding='utf-8') as f:
        f.write('# Rapport de migration v1 → v2 (généré par tools/docsite/migrer.py)\n\n')
        f.write('| onglet v1 | 🟢 | 🟡 | 🔵 | ⚪ | 🔴 | total |\n|---|---|---|---|---|---|---|\n')
        for sid, c in comptes.items():
            f.write('| %s | %d | %d | %d | %d | %d | %d |\n' % (sid, c.get('ok', 0), c.get('loc', 0), c.get('srv', 0), c.get('abs', 0), c.get('men', 0), sum(c.values())))
        f.write('| **total** | %d | %d | %d | %d | %d | **%d** |\n\n' % (tot.get('ok', 0), tot.get('loc', 0), tot.get('srv', 0), tot.get('abs', 0), tot.get('men', 0), sum(tot.values())))
        f.write('serveur.ts : %d · briques.ts : %d · mesures.ts : %d\n\n' % (len(serveur), len(briques), len(mesures)))
        for k, titre in [('ids_generes', 'Ids générés (à relire)'), ('aciter', 'Preuves « à citer » (la dette visible)'),
                         ('nonresolu', 'Preuves fichier:ligne NON résolues dans le dépôt'), ('tronques', 'Titres tronqués à 60'), ('sans_dom', 'Sans domaine')]:
            f.write('## %s — %d\n\n' % (titre, len(rapport[k])))
            for x in rapport[k]: f.write('- `%s`\n' % x)
            f.write('\n')
    print('serveur %d · briques %d · mesures %d · total pastilles %d' % (len(serveur), len(briques), len(mesures), sum(tot.values())))
    print('par état', tot)
    print('→', os.path.relpath(RAPPORT, RACINE))

if __name__ == '__main__':
    main()
