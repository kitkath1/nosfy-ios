"""Build 83 : attend le traitement Apple, rattache les consignes de test, relit l'accès interne.

Aucune invitation, aucune revue externe, aucune notification envoyée. Le groupe
interne « Test Kath » a `hasAccessToAllBuilds` : le 83 y arrive tout seul.
Preuves écrites ici même : traitement-83.json, consignes-83.json, acces-83.json.
"""
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from appstore_connect import APP_ID, request  # noqa: E402

ROOT = Path(__file__).resolve().parent
VERSION_BUILD = '83'
GROUPE_INTERNE = '4883de10-e441-47b9-bdb3-a0df493cef37'  # « Test Kath »
FICHE_81 = json.loads((ROOT.parent / 'testflight-api-2026-09-19/fiche-testflight.json').read_text())

PREAMBULE = {
    'fr-FR': ("Build 83 — LE LECTEUR DE SÉANCE tient maintenant toute la séance. "
              "Après le Go tu arrives directement dedans : la carte du jour, les cinq "
              "carrés du corps, et ce que Nosfy propose. La page Exercices ne s'ouvre "
              "plus QUE hors séance ; pendant, l'onglet, le galet et le chevron y "
              "ramènent tous. Entre deux écrans, un cercle blanc.\n\n"
              "À regarder en premier : est-ce que tu vois encore la liste des exercices "
              "passer pendant une séance ? est-ce que le téléphone chauffe ?\n\n"),
    'en-GB': ("Build 83 — THE SESSION PLAYER now holds the whole workout. After Go you "
              "land straight in it: the day's card, the five body squares, and what "
              "Nosfy suggests. The Exercises page only opens OUTSIDE a session; during "
              "one, the tab, the pebble and the chevron all lead back to the player. "
              "Between screens, a white circle.\n\n"
              "Look first: do you still see the exercise list flash past during a "
              "session? does the phone get hot?\n\n"),
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
        log('traitement-83.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
        raise SystemExit(f'✗ traitement Apple : {etat}')
    time.sleep(60)
else:
    raise SystemExit('✗ 90 min sans build VALID')
log('traitement-83.json', {'mesure_utc': maintenant(), 'http': st, 'build': build})
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
log('consignes-83.json', {'mesure_utc': maintenant(), 'ecriture': journal, 'relecture': relues})
for locale in FICHE_81['betaBuildLocalizations']:
    assert relues.get(locale, '').startswith(PREAMBULE[locale][:40]), f'consigne {locale} non relue'

st, g = request(f'/v1/betaGroups/{GROUPE_INTERNE}/builds?fields[builds]=version&limit=50')
versions = [b['attributes']['version'] for b in (g or {}).get('data', [])]
st2, d = request(f'/v1/builds/{build_id}/buildBetaDetail')
detail = (d or {}).get('data', {}).get('attributes', {})
st3, t = request(f'/v1/betaGroups/{GROUPE_INTERNE}/betaTesters?fields[betaTesters]=state,firstName')
testeurs = [(x['attributes'].get('firstName'), x['attributes'].get('state')) for x in (t or {}).get('data', [])]
log('acces-83.json', {'mesure_utc': maintenant(), 'groupe': 'Test Kath', 'http': [st, st2, st3],
                      'builds_du_groupe': versions, 'etat_build': detail, 'testeurs': testeurs})
print(f"groupe Test Kath : builds {versions} · {detail} · testeurs {testeurs}", flush=True)
print('✅ 83 VALID, consignes rattachées, accès interne relu — RIEN d\'autre envoyé', flush=True)
