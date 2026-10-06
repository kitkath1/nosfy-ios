"""Build 91 : attend le traitement Apple, rattache les consignes de test, relit l'accès interne.

Aucune invitation, aucune revue externe, aucune notification envoyée. Le groupe
interne « Test Kath » a `hasAccessToAllBuilds` : le 91 y arrive tout seul.
Preuves écrites ici même : traitement-91.json, consignes-91.json, acces-91.json.
"""
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstore_connect import APP_ID, request  # noqa: E402

ROOT = Path(__file__).resolve().parent
VERSION_BUILD = '91'
GROUPE_INTERNE = '4883de10-e441-47b9-bdb3-a0df493cef37'  # « Test Kath »
FICHE_81 = json.loads((ROOT.parent / 'testflight-api-2026-09-19/fiche-testflight.json').read_text())

PREAMBULE = {
    'fr-FR': ("Build 91 — LES SÉRIES : LONGUES, CORRIGEABLES, ET UN REPOS À LA FIN.\n\n"
              "1) LA LISTE DES SÉRIES : ajoute-en plus de 10, fais défiler vers le bas et vers le haut. La liste ne "
              "se ferme plus, et « Ajouter une série » reste en bas, toujours visible.\n\n"
              "2) PLUSIEURS PASSAGES SUR LE MÊME EXERCICE : reviens à ta séance puis relance le même exercice. Les "
              "séries continuent (Série 4, 5...), sans relancer l'app. La pop-up compte les séries de CET exercice.\n\n"
              "3) CORRIGER UNE SÉRIE : touche une série faite dans la liste ; ajuste les reps et les kilos, Valider.\n\n"
              "4) LE REPOS APRÈS LA DERNIÈRE SÉRIE, comme partout ; puis la page pour terminer.\n\n"
              "5) LA COULEUR DES FLAMMES : elle se voit aussi pendant le repos, et se choisit dans Réglages.\n\n"
              "À dire surtout : as-tu dû relancer l'app une seule fois ? La pop-up dit-elle le bon nombre ?\n\n"),
    'en-GB': ("Build 91 — SETS: LONG LISTS, EDITABLE, AND A REST AT THE END.\n\n"
              "1) THE SET LIST: add more than 10, scroll down and up. The list no longer closes, and « Add a set » "
              "stays at the bottom, always visible.\n\n"
              "2) SEVERAL PASSES ON THE SAME EXERCISE: go back to your session, then start the same exercise again. "
              "Sets carry on (Set 4, 5...), without restarting the app. The pop-up counts THIS exercise's sets.\n\n"
              "3) EDIT A SET: tap a done set in the list; adjust reps and weight, Log.\n\n"
              "4) A REST AFTER THE LAST SET, like everywhere; then the page to finish.\n\n"
              "5) FLAME COLOUR: it shows during the rest too, and can be chosen in Settings.\n\n"
              "Tell me above all: did you have to restart the app even once? Does the pop-up show the right number?\n\n"),
}


def log(nom, obj):
    (ROOT / nom).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')


def maintenant():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


debut = time.time()
build = None
while time.time() - debut < 90 * 60:
    st, r = request(f'/v1/builds?filter[app]={APP_ID}&filter[version]={VERSION_BUILD}'
                    '&fields[builds]=version,processingState,uploadedDate,expired,usesNonExemptEncryption')
    rows = (r or {}).get('data', []) if st == 200 else []
    build = next((b for b in rows if b['attributes']['version'] == VERSION_BUILD), None)
    etat = build['attributes']['processingState'] if build else 'ABSENT'
    print(f"{datetime.now():%H:%M:%S} build {VERSION_BUILD} : {etat}", flush=True)
    if build and etat == 'VALID':
        break
    if build and etat in ('FAILED', 'INVALID'):
        log('traitement-91.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
        raise SystemExit(f'✗ traitement Apple : {etat}')
    time.sleep(60)
else:
    raise SystemExit('✗ 90 min sans build VALID')
log('traitement-91.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
build_id = build['id']

st, r = request(f'/v1/builds/{build_id}/betaBuildLocalizations')
existantes = {x['attributes']['locale']: x['id'] for x in (r or {}).get('data', [])}
journal = []
for locale, attrs in FICHE_81['betaBuildLocalizations'].items():
    texte = {'whatsNew': (PREAMBULE.get(locale, '') + attrs['whatsNew'])[:4000]}
    if locale in existantes:
        st, r = request('/v1/betaBuildLocalizations/' + existantes[locale], {'data': {
            'type': 'betaBuildLocalizations', 'id': existantes[locale], 'attributes': texte}}, 'PATCH')
    else:
        st, r = request('/v1/betaBuildLocalizations', {'data': {
            'type': 'betaBuildLocalizations', 'attributes': {'locale': locale, **texte},
            'relationships': {'build': {'data': {'type': 'builds', 'id': build_id}}}}}, 'POST')
    journal.append({'locale': locale, 'http': st, 'reponse': r})
    print(f"consignes {locale} : HTTP {st}", flush=True)
st, r = request(f'/v1/builds/{build_id}/betaBuildLocalizations')
relues = {x['attributes']['locale']: x['attributes']['whatsNew'] for x in (r or {}).get('data', [])}
log('consignes-91.json', {'mesure_utc': maintenant(), 'ecriture': journal, 'relecture': relues})
for locale in FICHE_81['betaBuildLocalizations']:
    assert relues.get(locale, '').startswith(PREAMBULE[locale][:40]), f'consigne {locale} non relue'

st, g = request(f'/v1/betaGroups/{GROUPE_INTERNE}/builds?fields[builds]=version&limit=50')
versions = [b['attributes']['version'] for b in (g or {}).get('data', [])]
st2, d = request(f'/v1/builds/{build_id}/buildBetaDetail')
detail = (d or {}).get('data', {}).get('attributes', {})
st3, t = request(f'/v1/betaGroups/{GROUPE_INTERNE}/betaTesters?fields[betaTesters]=state,firstName')
testeurs = [(x['attributes'].get('firstName'), x['attributes'].get('state')) for x in (t or {}).get('data', [])]
log('acces-91.json', {'mesure_utc': maintenant(), 'groupe': 'Test Kath', 'http': [st, st2, st3],
                      'builds_du_groupe': versions, 'etat_build': detail, 'testeurs': testeurs})
print(f"groupe Test Kath : builds {versions} · {detail} · testeurs {testeurs}", flush=True)
print('✅ 91 VALID, consignes rattachées, accès interne relu — RIEN d\'autre envoyé', flush=True)
